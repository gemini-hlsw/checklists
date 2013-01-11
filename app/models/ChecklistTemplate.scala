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

case class CheckTemplate(title: String, position: Int = 0)

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


case class CheckTemplateGroup(name:String, title:String, checks: Seq[CheckTemplate])

object CheckTemplateGroup {
  implicit object ChecklistTemplateGroupFormat extends Format[CheckTemplateGroup] {
    def writes(g: CheckTemplateGroup) = JsObject(Seq(
      "name" -> JsString(g.name),
      "title" -> JsString(g.title),
      "checks" -> Json.toJson(g.checks)
    ))

    def reads(json: JsValue) = CheckTemplateGroup(
      name = (json \ "name").asOpt[String].getOrElse(""),
      title = (json \ "title").asOpt[String].getOrElse(""),
      checks = (json \ "checks").as[Seq[CheckTemplate]]
    )
  }
}

case class ChecklistTemplate(id: ObjectId = new ObjectId, site: String, name:String, groups: Seq[CheckTemplateGroup])

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

  implicit object ChecklistTemplateFormat extends Format[ChecklistTemplate] {
    def writes(t: ChecklistTemplate) = JsObject(Seq(
      "site" -> JsString(t.site),
      "name" -> JsString(t.name),
      "groups" -> Json.toJson(t.groups)
    ))

    def reads(json: JsValue) = ChecklistTemplate(
      site = (json \ "site").asOpt[String].getOrElse(""),
      name = (json \ "name").asOpt[String].getOrElse(""),
      groups = (json \ "groups").as[Seq[CheckTemplateGroup]]
    )
  }
}