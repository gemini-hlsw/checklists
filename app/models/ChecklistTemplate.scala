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

case class CheckTemplate(title: String, position: Int = 0, choices:Seq[StatusChoice] = Seq.empty)

object CheckTemplate {
  implicit object CheckTemplateFormat extends Format[CheckTemplate] {
    def writes(c: CheckTemplate) = JsObject(Seq(
      "title" -> JsString(c.title),
      "position" -> JsNumber(c.position)
    ))

    def reads(json: JsValue) = CheckTemplate(
      title    = ~(json \ "title").asOpt[String],
      position = ~(json \ "position").asOpt[Int]
    )
  }
}

case class StatusChoice(name: String)

object StatusChoice {
  val defaultChoices = Seq(StatusChoice(""), StatusChoice("done"), StatusChoice("not done"), StatusChoice("NA"), StatusChoice("Ok"), StatusChoice("pending"), StatusChoice("not Ok"))

  implicit object StatusChoiceFormat extends Format[StatusChoice] {
    def writes(c: StatusChoice) = JsObject(Seq(
      "choice" -> JsString(c.name)
    ))

    def reads(json: JsValue) = StatusChoice(
      name = ~(json \ "name").asOpt[String]
    )
  }
}

case class CheckTemplateGroup(name:String, title:String, checks: Seq[CheckTemplate], position: Int = 0)

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

case class ChecklistTemplate(id: ObjectId = new ObjectId, site: String, name:String, groups: Seq[CheckTemplateGroup], engineers: Set[String] = Set.empty, technicians: Set[String] = Set.empty)

case class TemplateSettings(site: String, engineers: Set[String], technicians: Set[String])

object TemplateSettings {
  implicit object TemplateSettingsWrites extends Writes[TemplateSettings] {
    def writes(t: TemplateSettings) = JsObject(Seq(
      "site"        -> JsString(t.site),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians)
    ))
  }
}

object ChecklistTemplate extends ModelCompanion[ChecklistTemplate, ObjectId] {
  val dao = new SalatDAO[ChecklistTemplate, ObjectId](collection = mongoCollection("checklists_templates")) {}

  def findTemplates:Seq[ChecklistTemplate] = dao.find(MongoDBObject()).toSeq
  def findTemplate(site: String):Option[ChecklistTemplate] = dao.findOne(MongoDBObject("site" -> site))

  def saveTemplate(t: ChecklistTemplate) = {
    val id = findTemplate(t.site).map(_.id).getOrElse(t.id)
    dao.removeById(id, WriteConcern.Normal)
    dao.save(t.copy(id = id))
    t.copy(id = id)
  }

  def updateEngineersNames(site: String, engineers: Seq[String], technicians: Seq[String]) {
    findTemplate(site).map(t => t.copy(engineers = t.engineers ++ engineers.toSet, technicians = t.technicians ++ technicians.toSet)).map(saveTemplate)
  }

  def loadSettings(site: String):Option[TemplateSettings] = {
    findTemplate(site).map(t => TemplateSettings(t.site, t.engineers, t.technicians))
  }

  implicit object ChecklistTemplateFormat extends Format[ChecklistTemplate] {
    def writes(t: ChecklistTemplate) = JsObject(Seq(
      "site"        -> JsString(t.site),
      "name"        -> JsString(t.name),
      "groups"      -> Json.toJson(t.groups),
      "engineers"   -> Json.toJson(t.engineers),
      "technicians" -> Json.toJson(t.technicians)
    ))

    def reads(json: JsValue) = ChecklistTemplate(
      site        = ~(json \ "site").asOpt[String],
      name        = ~(json \ "name").asOpt[String],
      groups      = (json \ "groups").as[Seq[CheckTemplateGroup]],
      engineers   = (json \ "engineers").as[Seq[String]].toSet,
      technicians = (json \ "technicians").as[Seq[String]].toSet
    )
  }
}
