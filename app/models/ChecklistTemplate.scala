package models

import org.bson.types.ObjectId
import mongoContext._
import com.mongodb.casbah.Imports._
import com.novus.salat.dao._
import se.radley.plugin.salat._
import play.api.Play.current
import play.api.libs.json._
import play.Logger
import org.joda.time.{DateMidnight, DateTime}
import JsonFormatters._

import scalaz._
import Scalaz._

case class CheckChoice(name: String, selected: Boolean)

object CheckChoice {
  val defaultChoices = Seq("done", "not done", "NA", "Ok", "pending", "not Ok")
  val defaultCheckChoices = defaultChoices.map(CheckChoice(_, true))
}

case class CheckTemplate(title: String, position: Int = 0, choices:Seq[CheckChoice] = CheckChoice.defaultCheckChoices, freeText: Boolean = false) {
  def hydrateChecks(defaultChoices:Set[String]):CheckTemplate = if (this.choices.isEmpty) {
      copy(choices = defaultChoices.map(CheckChoice(_, true)).toSeq)
    } else {
      this
    }
}

object CheckTemplate {
  implicit object CheckTemplateFormat extends Format[CheckTemplate] {
    def writes(c: CheckTemplate) = JsObject(Seq(
      "title"    -> JsString(c.title),
      "position" -> JsNumber(c.position),
      "choices"  -> Json.toJson(c.choices.map(x => JsObject(Seq("name" -> JsString(x.name), "selected" -> JsBoolean(x.selected))))),
      "freeText" -> JsBoolean(c.freeText)
    ))

    def reads(json: JsValue) = JsSuccess(CheckTemplate(
      title    = ~(json \ "title").asOpt[String],
      position = ~(json \ "position").asOpt[Int],
      choices  = (json \ "choices").as[Seq[JsObject]].map(o => CheckChoice(~(o \ "name").asOpt[String], ~(o \ "selected").asOpt[Boolean])),
      freeText = ~(json \ "freeText").asOpt[Boolean]
    ))
  }
}

case class CheckTemplateGroup(name:String, title:String, checks: Seq[CheckTemplate], position: Int = 0) {
  def hydrateChecks(choices: Set[String]):CheckTemplateGroup = copy(checks = checks.map(_.hydrateChecks(choices)))
}

object CheckTemplateGroup {
  implicit object ChecklistTemplateGroupFormat extends Format[CheckTemplateGroup] {
    def writes(g: CheckTemplateGroup) = JsObject(Seq(
      "name"     -> JsString(g.name),
      "title"    -> JsString(g.title),
      "checks"   -> Json.toJson(g.checks),
      "position" -> JsNumber(g.position)
    ))

    def reads(json: JsValue) = JsSuccess(CheckTemplateGroup(
      name     = ~(json \ "name").asOpt[String],
      title    = ~(json \ "title").asOpt[String],
      checks   = (json \ "checks").as[Seq[CheckTemplate]],
      position = ~(json \ "position").asOpt[Int]
    ))
  }
}

case class TemplateSettings(key: String, engineers: Set[String], technicians: Set[String], groups: Seq[CheckTemplateGroup])

object TemplateSettings {
  implicit object TemplateSettingsWrites extends Writes[TemplateSettings] {
    def writes(t: TemplateSettings) = JsObject(Seq(
      "key"         -> JsString(t.key),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians),
      "groups"      -> JsArray(t.groups.map(g => g.checks.map(_.freeText).map(JsBoolean)).map(JsArray))
    ))
  }
}

case class ChecklistTemplate(
  id: ObjectId = new ObjectId,
  key: String = "",
  name:String,
  groups: Seq[CheckTemplateGroup],
  colPos:Int = 0,
  rowPos:Int = 0,
  engineers: Set[String] = Set.empty,
  technicians: Set[String] = Set.empty,
  choices: Set[String] = CheckChoice.defaultChoices.toSet,
  sendOnClose: Boolean = false,
  fromEmail: String = "noreply@gemini.edu",
  toEmail: Seq[String] = Seq.empty, 
  subjectText: String = ChecklistTemplate.defaultSubjectText,
  bodyText: String = ChecklistTemplate.defaultBodyText)

object ChecklistTemplate extends ModelCompanion[ChecklistTemplate, ObjectId] {
  val columnCount = 2
  val dao = new SalatDAO[ChecklistTemplate, ObjectId](collection = mongoCollection("checklists_templates")) {}
  val defaultSubjectText = """${templateName} checklist for ${date} closed"""
  val defaultBodyText = """<html><body><p>Checklist ${templateName} was closed, check it at:</br> <a href="${url}"/>${url}</a></p></body></html>"""

  def findTemplates:Seq[ChecklistTemplate] = dao.find(MongoDBObject()).map(hydrateChecks).toSeq

  def findTemplate(key: String):Option[ChecklistTemplate] = dao.findOne(MongoDBObject("key" -> key)).map(hydrateChecks)

  def hydrateChecks(t: ChecklistTemplate):ChecklistTemplate = t.copy(groups = t.groups.map(_.hydrateChecks(t.choices)))

  def saveTemplate(t: ChecklistTemplate) = {
    Logger.info("Save template key:" + t.key)
    val id = findTemplate(t.key).map(_.id).getOrElse(t.id)
    dao.removeById(id, WriteConcern.Normal)
    dao.save(t.copy(id = id))
    t.copy(id = id)
  }

  private def nextPosition(p: TemplateCreationParams):TemplateCreationParams = {
    val count = dao.count(MongoDBObject())
    val row = (count / columnCount)
    p.copy(colPos = (count - (row * columnCount)).toInt, rowPos = row.toInt)
  }

  private def newTemplate(p: TemplateCreationParams):ChecklistTemplate = {
    val t = ChecklistTemplate(key = p.key, name = p.name, groups = Seq.empty, colPos = p.colPos, rowPos = p.rowPos)
    dao.insert(t)
    t
  }

  def createNew(p: TemplateCreationParams):ValidationNEL[String, ChecklistTemplate] = {
    Logger.info("Create new template with parameters " + p)
    findTemplate(p.key).map(_ => ("Template with key already exists").failNel).getOrElse(newTemplate(nextPosition(p)).successNel)
  }

  def updateEngineersNames(key: String, engineers: Seq[String], technicians: Seq[String]) {
    findTemplate(key).map(t => t.copy(engineers = t.engineers ++ engineers, technicians = t.technicians ++ technicians)).filter(t => !t.engineers.forall(engineers.contains) || !t.technicians.forall(technicians.contains)).map(saveTemplate)
  }

  def loadSettings(key: String):Option[TemplateSettings] = {
    findTemplate(key).map(t => TemplateSettings(t.key, t.engineers, t.technicians, t.groups))
  }

  implicit object ChecklistTemplateFormat extends Format[ChecklistTemplate] {
    def writes(t: ChecklistTemplate) = JsObject(Seq(
      "key"         -> JsString(t.key),
      "name"        -> JsString(t.name),
      "colPos"      -> JsNumber(t.colPos),
      "rowPos"      -> JsNumber(t.rowPos),
      "groups"      -> Json.toJson(t.groups),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians),
      "choices"     -> Json.toJson(t.choices),
      "sendOnClose" -> JsBoolean(t.sendOnClose),
      "fromEmail"   -> JsString(t.fromEmail),
      "toEmail"     -> Json.toJson(t.toEmail),
      "subjectText" -> JsString(t.subjectText),
      "bodyText"    -> JsString(t.bodyText)
    ))

    def reads(json: JsValue) = JsSuccess(ChecklistTemplate(
      key         = ~(json \ "key").asOpt[String],
      name        = ~(json \ "name").asOpt[String],
      colPos      = ~(json \ "colPos").asOpt[Int],
      rowPos      = ~(json \ "rowPos").asOpt[Int],
      groups      =  (json \ "groups").as[Seq[CheckTemplateGroup]],
      engineers   =  (json \ "engineers").as[Seq[String]].toSet,
      technicians =  (json \ "technicians").as[Seq[String]].toSet,
      choices     =  (json \ "choices").as[Seq[String]].toSet,
      sendOnClose = ~(json \ "sendOnClose").asOpt[Boolean],
      fromEmail   = ~(json \ "fromEmail").asOpt[String],
      toEmail     =  (json \ "toEmail").as[Seq[String]],
      subjectText =  (json \ "subjectText").asOpt[String] | ChecklistTemplate.defaultSubjectText,
      bodyText    =  (json \ "bodyText").asOpt[String] | ChecklistTemplate.defaultBodyText
    ))
  }
}


case class TemplateCreationParams(key: String, name: String, colPos: Int = 0, rowPos: Int =0)

object TemplateCreationParams {
  implicit object TemplateCreationParamsFormat extends Reads[TemplateCreationParams] {
    def reads(json: JsValue) = JsSuccess(TemplateCreationParams(
      key         = ~(json \ "key").asOpt[String],
      name        = ~(json \ "name").asOpt[String]
    ))
  }
}