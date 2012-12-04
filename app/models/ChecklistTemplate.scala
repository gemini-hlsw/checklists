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

case class Site(id: ObjectId = new ObjectId, site:String, name: String, date: DateMidnight = new DateMidnight())

object Site extends ModelCompanion[Site, ObjectId] {
  val dao = new SalatDAO[Site, ObjectId](collection = mongoCollection("sites")) {}

  def findSites:Seq[Site] = dao.find(MongoDBObject()).toSeq

  def insertSite(site:Site):Site = site.copy(id = dao.insert(site, WriteConcern.Normal).getOrElse(ObjectId.get())) // TBD Do proper validation of the error

  implicit object SiteFormat extends Writes[Site] {
    def writes(s: Site) = JsObject(Seq(
      "site" -> JsString(s.site),
      "name" -> JsString(s.name),
      "date" -> Json.toJson(s.date)
    ))
  }
}

case class CheckTemplate(title:String)

object CheckTemplate {
  implicit object CheckTemplateFormat extends Format[CheckTemplate] {
    def writes(c: CheckTemplate) = JsObject(Seq(
      "title" -> JsString(c.title)
    ))

    def reads(json: JsValue) = CheckTemplate(
      title = (json \ "title").asOpt[String].getOrElse("")
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

case class Check(description:String, status: Option[String], comment: Option[String]) {
  def merge(that:Check): Check = Check(this.description, status.orElse(that.status), comment.orElse(that.comment))
}

object Check {
  def newFromTemplate(t: CheckTemplate):Check=
    Check(t.title, None, None)

  implicit object CheckFormat extends Format[Check] {
    def writes(c: Check) = JsObject(Seq(
      "description" -> JsString(c.description),
      "status" -> JsString(c.status.getOrElse("")),
      "comment" -> JsString(c.comment.getOrElse(""))
    ))

    def reads(json: JsValue) = Check(
      (json \ "description").asOpt[String].getOrElse(""),
      (json \ "status").asOpt[String].filter(_.nonEmpty),
      (json \ "comment").asOpt[String].filter(_.nonEmpty)
    )
  }
}

case class CheckGroup(name:String, title:String, checks: Seq[Check])

object CheckGroup {
  def newFromTemplate(g: CheckTemplateGroup):CheckGroup =
    CheckGroup(g.name, g.title, g.checks.map(Check.newFromTemplate))

  implicit object CheckGroupFormat extends Format[CheckGroup] {
    def writes(g: CheckGroup) = JsObject(Seq(
      "name" -> JsString(g.name),
      "title" -> JsString(g.title),
      "checks" -> Json.toJson(g.checks)
    ))

    def reads(json: JsValue) = CheckGroup(
      (json \ "name").asOpt[String].getOrElse(""),
      (json \ "title").asOpt[String].getOrElse(""),
      (json \ "checks").as[Seq[Check]]
    )
  }
}

case class Checklist(id: ObjectId = new ObjectId, site: String, name: String, date:DateMidnight, groups: Seq[CheckGroup])

object Checklist extends ModelCompanion[Checklist, ObjectId] {
  lazy val dao = new SalatDAO[Checklist, ObjectId](collection = mongoCollection("checklists")) {}

  def newFromTemplate(t:ChecklistTemplate, date: DateMidnight): Checklist =
    Checklist(site = t.site, name = t.name, date = date, groups = t.groups.map(CheckGroup.newFromTemplate(_)))

  def findOrCreate(site:String, date:DateMidnight):Option[Checklist] = findChecklist(site, date).orElse(ChecklistTemplate.findTemplate(site).map(newFromTemplate(_, date)))

  def findChecklist(site:String, date:DateMidnight):Option[Checklist] = dao.findOne(MongoDBObject("site" -> site, "date" -> date))

  def mergeChecks(newChecks:Seq[Check], oldChecks:Seq[Check]):Seq[Check] = {
    for {
      nc <- newChecks
      oc <- oldChecks
      if (nc.description == oc.description)
    } yield nc.merge(oc)
  }

  def mergeLists(newCL:Checklist)(oldCL:Checklist):Checklist = {
    val cl = newCL.copy(id = oldCL.id)
    val mergedGroups = for {
      og <- oldCL.groups
      ng <- cl.groups
      if (og.name == ng.name)
    } yield ng.copy(checks = mergeChecks(ng.checks, og.checks))
    cl.copy(groups = mergedGroups)
  }

  def saveChecklist(t:Checklist):Checklist = {
    val merged = findChecklist(t.site, t.date).map(mergeLists(t)).getOrElse(t)
    dao.update(MongoDBObject("_id" -> merged.id), merged, true, false, WriteConcern.Normal)
    merged
  }

  implicit object ChecklistFormat extends Format[Checklist] {
    def writes(c: Checklist) = JsObject(Seq(
      "site" -> JsString(c.site),
      "name" -> JsString(c.name),
      "date" -> Json.toJson(c.date),
      "groups" -> Json.toJson(c.groups)
    ))

    def reads(json: JsValue) = Checklist(
      site = (json \ "site").asOpt[String].getOrElse(""),
      name = (json \ "name").asOpt[String].getOrElse(""),
      date = (json \ "date").asOpt[DateMidnight].getOrElse(DateMidnight.now()),
      groups = (json \ "groups").as[Seq[CheckGroup]]
    )
  }
}
