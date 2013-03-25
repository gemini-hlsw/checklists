package models

import org.bson.types.ObjectId
import mongoContext._
import com.mongodb.casbah.Imports._
import com.novus.salat.dao._
import se.radley.plugin.salat._
import play.api.Play.current
import play.api.libs.json._
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

    def reads(json: JsValue) = CheckTemplate(
      title    = ~(json \ "title").asOpt[String],
      position = ~(json \ "position").asOpt[Int],
      choices  = (json \ "choices").as[Seq[JsObject]].map(o => CheckChoice(~(o \ "name").asOpt[String], ~(o \ "selected").asOpt[Boolean])),
      freeText = ~(json \ "freeText").asOpt[Boolean]
    )
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

    def reads(json: JsValue) = CheckTemplateGroup(
      name     = ~(json \ "name").asOpt[String],
      title    = ~(json \ "title").asOpt[String],
      checks   = (json \ "checks").as[Seq[CheckTemplate]],
      position = ~(json \ "position").asOpt[Int]
    )
  }
}

case class ChecklistTemplate(id: ObjectId = new ObjectId, site: String, key: String = "", name:String, groups: Seq[CheckTemplateGroup], engineers: Set[String] = Set.empty, technicians: Set[String] = Set.empty, choices: Set[String] = CheckChoice.defaultChoices.toSet)

case class TemplateSettings(site: String, engineers: Set[String], technicians: Set[String], groups: Seq[CheckTemplateGroup])

object TemplateSettings {
  implicit object TemplateSettingsWrites extends Writes[TemplateSettings] {
    def writes(t: TemplateSettings) = JsObject(Seq(
      "site"        -> JsString(t.site),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians),
      "groups"     -> JsArray(t.groups.map(g => g.checks.map(_.freeText).map(JsBoolean)).map(JsArray))
    ))
  }
}

object ChecklistTemplate extends ModelCompanion[ChecklistTemplate, ObjectId] {
  val dao = new SalatDAO[ChecklistTemplate, ObjectId](collection = mongoCollection("checklists_templates")) {}

  def findTemplates:Seq[ChecklistTemplate] = dao.find(MongoDBObject()).map(hydrateChecks).toSeq
  def findTemplate(key: String):Option[ChecklistTemplate] = dao.findOne(MongoDBObject("key" -> key)).map(hydrateChecks)
  def hydrateChecks(t: ChecklistTemplate):ChecklistTemplate = t.copy(groups = t.groups.map(_.hydrateChecks(t.choices)))

  def saveTemplate(t: ChecklistTemplate) = {
    val id = findTemplate(t.key).map(_.id).getOrElse(t.id)
    dao.removeById(id, WriteConcern.Normal)
    dao.save(t.copy(id = id))
    t.copy(id = id)
  }

  def updateEngineersNames(site: String, engineers: Seq[String], technicians: Seq[String]) {
    findTemplate(site).map(t => t.copy(engineers = t.engineers ++ engineers.toSet, technicians = t.technicians ++ technicians.toSet)).map(saveTemplate)
  }

  def loadSettings(site: String):Option[TemplateSettings] = {
    findTemplate(site).map(t => TemplateSettings(t.site, t.engineers, t.technicians, t.groups))
  }

  implicit object ChecklistTemplateFormat extends Format[ChecklistTemplate] {
    def writes(t: ChecklistTemplate) = JsObject(Seq(
      "site"        -> JsString(t.site),
      "key"         -> JsString(t.key),
      "name"        -> JsString(t.name),
      "groups"      -> Json.toJson(t.groups),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians),
      "choices"     -> Json.toJson(t.choices)
    ))

    def reads(json: JsValue) = ChecklistTemplate(
      site        = ~(json \ "site").asOpt[String],
      key         = ~(json \ "key").asOpt[String],
      name        = ~(json \ "name").asOpt[String],
      groups      = (json \ "groups").as[Seq[CheckTemplateGroup]],
      engineers   = (json \ "engineers").as[Seq[String]].toSet,
      technicians = (json \ "technicians").as[Seq[String]].toSet,
      choices     = (json \ "choices").as[Seq[String]].toSet
    )
  }
}
