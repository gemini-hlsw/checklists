package models

import com.novus.salat.dao.{SalatDAO, ModelCompanion}
import com.mongodb.casbah.Imports._
import se.radley.plugin.salat._
import org.joda.time.DateMidnight
import play.api.libs.json._
import play.api.Play.current
import mongoContext._
import JsonFormatters._
import scala.collection.immutable.TreeMap

import scalaz._
import Scalaz._

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

case class Checklist(id: ObjectId = new ObjectId, site: String, name: String, closed: Boolean = false, date:DateMidnight, groups: Seq[CheckGroup])

object Checklist extends ModelCompanion[Checklist, ObjectId] {
  lazy val dao = new SalatDAO[Checklist, ObjectId](collection = mongoCollection("checklists")) {}

  def newFromTemplate(t:ChecklistTemplate, date: DateMidnight): Checklist =
    Checklist(site = t.site, name = t.name, date = date, groups = t.groups.map(CheckGroup.newFromTemplate(_)))

  def findOrCreate(site:String, date:DateMidnight):Option[Checklist] = findChecklist(site, date).orElse(ChecklistTemplate.findTemplate(site).map(newFromTemplate(_, date)))

  def findChecklist(site:String, date:DateMidnight):Option[Checklist] =
    dao.findOne(MongoDBObject("site" -> site, "date" -> date))

  def findChecklistRange(site:String, from:DateMidnight, to:DateMidnight):Seq[Checklist] = {
    dao.find(MongoDBObject("site" -> site, "date" -> MongoDBObject("$gte" -> from, "$lte" -> to))).toList
  }

  def findDates():Seq[DateMidnight] = {
    val fields = MongoDBObject("date" -> 1)
    dao.find(MongoDBObject("site" -> "GS")).sort(orderBy = MongoDBObject("date" -> -1)).collect {
      case c:Checklist => c.date
    }.toList
  }

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

  def saveChecklist(t:Checklist):Either[ErrorCode, Checklist] = {
    findOrCreate(t.site, t.date).map { cl =>
      cl.closed match {
        case false => {
          val merged:Checklist = mergeLists(t)(cl)
          dao.update(MongoDBObject("_id" -> merged.id), merged, true, false, WriteConcern.Normal)
          Right(merged)
        }
        case true => Left(ErrorCode.ChecklistClosed)
    }}.getOrElse(Left(ErrorCode.NotFound))
  }

  implicit object ChecklistFormat extends Format[Checklist] {
    def writes(c: Checklist) = JsObject(Seq(
      "site"   -> JsString(c.site),
      "name"   -> JsString(c.name),
      "closed" -> JsBoolean(c.closed),
      "date"   -> Json.toJson(c.date),
      "groups" -> Json.toJson(c.groups)
    ))

    def reads(json: JsValue) = Checklist(
      site   = (json \ "site").asOpt[String].getOrElse(""),
      name   = (json \ "name").asOpt[String].getOrElse(""),
      closed = (json \ "closed").asOpt[Boolean].getOrElse(false),
      date   = (json \ "date").asOpt[DateMidnight].getOrElse(DateMidnight.now()),
      groups = (json \ "groups").as[Seq[CheckGroup]]
    )
  }
}

case class ChecklistReportSummary(checklist: Checklist) {
  lazy val grouped = for {
    g <- checklist.groups
    ch <- g.checks.groupBy(_.status)
  } yield (ch._1, ch._2.size)
}

object ChecklistReportSummary {
   implicit object ChecklistReportSummaryWrites extends Writes[ChecklistReportSummary] {
    override def writes(summary: ChecklistReportSummary) = JsObject(Seq(
      "status" -> JsObject(summary.grouped.map {
        case (s, c) => s.getOrElse("none") -> JsNumber(c)
      }),
      "closed" -> JsBoolean(summary.checklist.closed),
      "date" -> JsString(JsonFormatters.fmt.print(summary.checklist.date)),
      "checklist" -> Json.toJson(summary.checklist)
    ))
  }
}

case class ChecklistReport(site: String, checklists: Seq[Checklist]) {
  def startDate:Option[DateMidnight] = checklists.headOption.map(_.date)
  def untilDate:Option[DateMidnight] = checklists.lastOption.map(_.date)
  def summary:Seq[ChecklistReportSummary] = for {
      c <- checklists
    } yield ChecklistReportSummary(c)
}

object ChecklistReport {
  def summarizePeriod(site: String, year: Int, month:Int):Option[ChecklistReport] = {
    val from = new DateMidnight(year, month, 1)
    val to = new DateMidnight(year, month, from.dayOfMonth.getMaximumValue)
    val checklists = Checklist.findChecklistRange(site, from, to)
    some(ChecklistReport(site, checklists))
  }

  def findAvailableMonths():Seq[(Int, Seq[String])] = {
    val r = for {
      y <- Checklist.findDates.groupBy(_.getYear).toSeq
    } yield (y._1, y._2.groupBy(_.monthOfYear.getAsText).keys.toSeq)
    r.reverse.toSeq
  }

  implicit object ChecklistReportWrites extends Writes[ChecklistReport] {
    override def writes(report: ChecklistReport) = JsObject(Seq(
      "site"       -> JsString(report.site),
      "from"       -> Json.toJson(report.startDate),
      "to"         -> Json.toJson(report.untilDate),
      "summary"    -> Json.toJson(report.summary)
    ))
  }
}