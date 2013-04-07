package models

import com.novus.salat.dao.{SalatDAO, ModelCompanion}
import com.mongodb.casbah.Imports._
import se.radley.plugin.salat._
import org.joda.time.DateMidnight
import play.api.libs.json._
import play.api.Play.current
import play.Logger
import mongoContext._
import JsonFormatters._
import scala.collection.immutable.TreeMap
import play.api.libs.concurrent.Akka
import org.fusesource.scalate._
import org.fusesource.scalate.support.StringTemplateSource

import scalaz._
import Scalaz._

case class Check(description:String, status: Option[String], comment: Option[String], choices: Seq[String] = CheckChoice.defaultChoices, freeText: Boolean = false) {
  def merge(that:Check): Check = Check(this.description, status.orElse(that.status), comment.orElse(that.comment), this.choices, this.freeText)
}

object Check {
  def newFromTemplate(t: CheckTemplate):Check =
    Check(t.title, None, None, t.choices.filter(_.selected).map(_.name), t.freeText)

  implicit object CheckFormat extends Format[Check] {
    def writes(c: Check) = JsObject(Seq(
      "description" -> JsString(c.description),
      "status"      -> JsString(~c.status),
      "comment"     -> JsString(~c.comment),
      "choices"     -> Json.toJson(c.choices),
      "freeText"    -> Json.toJson(c.freeText)
    ))

    def reads(json: JsValue) = Check(
      ~(json \ "description").asOpt[String],
       (json \ "status").asOpt[String].filter(_.nonEmpty),
       (json \ "comment").asOpt[String].filter(_.nonEmpty),
       (json \ "choices").as[Seq[String]],
      ~(json \ "freeText").asOpt[Boolean]
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

case class Checklist(id: ObjectId = new ObjectId, key: String, name: String, closed: Boolean = false, date:DateMidnight, groups: Seq[CheckGroup], engineers: Seq[String] = Seq.empty, technicians: Seq[String] = Seq.empty)

object Checklist extends ModelCompanion[Checklist, ObjectId] {
  lazy val dao = new SalatDAO[Checklist, ObjectId](collection = mongoCollection("checklists")) {}
  val emailRegex = """(\w+)@([\w\.]+)""".r
  val engine = new TemplateEngine

  def newFromTemplate(t:ChecklistTemplate, date: DateMidnight): Checklist =
    Checklist(key = t.key, name = t.name, date = date, groups = t.groups.map(CheckGroup.newFromTemplate(_)))

  def findOrCreate(key:String, date:DateMidnight):Option[Checklist] = findChecklist(key, date).orElse(ChecklistTemplate.findTemplate(key).map(newFromTemplate(_, date)))

  def findChecklist(key:String, date:DateMidnight):Option[Checklist] =
    dao.findOne(MongoDBObject("key" -> key, "date" -> date))

  def findChecklistRange(key:String, from:DateMidnight, to:DateMidnight):Seq[Checklist] =
    dao.find(MongoDBObject("key" -> key, "date" -> MongoDBObject("$gte" -> from, "$lte" -> to))).toList

  def findDates(key: String):Seq[DateMidnight] = {
    val fields = MongoDBObject("date" -> 1)
    dao.find(MongoDBObject("key" -> key)).sort(orderBy = MongoDBObject("date" -> -1)).collect {
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

  def mailChecklistCompletion(c: Checklist) {
    def buildSubjectText(t:ChecklistTemplate):String = {
      val params = Map("templateName" -> t.name, "templateKey" -> t.key, "date" -> JsonFormatters.fmt.print(c.date))
      engine.layout(new StringTemplateSource("subject.ssp", """
        <%@ val date: String %>
        <%@ val templateName: String %>
        <%@ val templateKey: String %>""" + t.subjectTemplate), params)
    }

    def buildBodyText(t:ChecklistTemplate):String = {
      val host = current.configuration.getString("site.url").getOrElse("http://localhost:9000")
      var url = host + "/#/" + t.key + "/" + JsonFormatters.fmt.print(c.date)

      val params = Map("templateName" -> t.name, "templateKey" -> t.key, "url" -> url, "date" -> JsonFormatters.fmt.print(c.date))
      engine.layout(new StringTemplateSource("body.ssp", """
        <%@ val date: String %>
        <%@ val templateName: String %>
        <%@ val url: String %>
        <%@ val templateKey: String %>""" + t.bodyTemplate), params)
    }

    ChecklistTemplate.findTemplate(c.key).filter(_.sendOnClose).foreach { t =>
      var destinations = t.toEmail.filter(emailRegex.findFirstIn(_).isDefined)
      if (destinations.size > 0 && emailRegex.findFirstIn(t.fromEmail).isDefined) {
        import com.typesafe.plugin._
        val mail = use[MailerPlugin].email

        mail.setSubject(buildSubjectText(t))
        mail.addRecipient(destinations: _*)
        mail.addFrom(t.fromEmail)
        mail.setReplyTo(t.fromEmail)
        mail.sendHtml(buildBodyText(t))
      }
    }
  }

  def saveChecklist(t:Checklist):Either[ErrorCode, Checklist] = {
    findOrCreate(t.key, t.date).map { cl =>
      cl.closed match {
        case false => {
          val merged:Checklist = mergeLists(t)(cl)
          dao.update(MongoDBObject("_id" -> merged.id), merged, true, false, WriteConcern.Normal)

          ChecklistTemplate.updateEngineersNames(t.key, t.engineers, t.technicians)
          if (t.closed) {
            Akka.future {
              try {
               mailChecklistCompletion(t)
              } catch {
                case e:Exception =>Logger.error(e.getMessage)
              }
            }
          }
          Right(merged)
        }
        case true => Left(ErrorCode.ChecklistClosed)
    }}.getOrElse(Left(ErrorCode.NotFound))
  }

  implicit object ChecklistFormat extends Format[Checklist] {
    def writes(c: Checklist) = JsObject(Seq(
      "key"        -> JsString(c.key),
      "name"        -> JsString(c.name),
      "closed"      -> JsBoolean(c.closed),
      "date"        -> Json.toJson(c.date),
      "groups"      -> Json.toJson(c.groups),
      "engineers"   -> Json.toJson(c.engineers),
      "technicians" -> Json.toJson(c.technicians)
    ))

    def reads(json: JsValue) = Checklist(
      key        = (json \ "key").asOpt[String].getOrElse(""),
      name        = (json \ "name").asOpt[String].getOrElse(""),
      closed      = (json \ "closed").asOpt[Boolean].getOrElse(false),
      date        = (json \ "date").asOpt[DateMidnight].getOrElse(DateMidnight.now()),
      groups      = (json \ "groups").as[Seq[CheckGroup]],
      engineers   = (json \ "engineers").as[Seq[String]],
      technicians = (json \ "technicians").as[Seq[String]]
    )
  }
}

case class ChecklistReportSummary(checklist: Checklist) {
  val base = Map.empty[Option[String], Int]

  lazy val grouped = {
    val g = for {
      g <- checklist.groups
      ch <- g.checks.groupBy(_.status)
    } yield (ch._1, ch._2.size)
    g.foldLeft(base)((a, b) => a + (b._1 -> (b._2 + ~a.get(b._1))))
  }
}

object ChecklistReportSummary {
   implicit object ChecklistReportSummaryWrites extends Writes[ChecklistReportSummary] {
    override def writes(summary: ChecklistReportSummary) = JsObject(Seq(
      "status" -> JsObject(summary.grouped.map {
        case (s, c) => s.getOrElse("none") -> JsNumber(c)
      }.toList),
      "closed" -> JsBoolean(summary.checklist.closed),
      "date" -> JsString(JsonFormatters.fmt.print(summary.checklist.date)),
      "key" -> JsString(summary.checklist.key),
      "checklist" -> Json.toJson(summary.checklist)
    ))
  }
}

case class ChecklistReport(key: String, name: String, checklists: Seq[Checklist]) {
  def startDate:Option[DateMidnight] = checklists.headOption.map(_.date)
  def untilDate:Option[DateMidnight] = checklists.lastOption.map(_.date)
  def summary:Seq[ChecklistReportSummary] = for {
      c <- checklists
    } yield ChecklistReportSummary(c)
}

object ChecklistReport {
  def summarizePeriod(key: String, year: Int, month:Int):Option[ChecklistReport] = {
    val from = new DateMidnight(year, month, 1)
    val to = new DateMidnight(year, month, from.dayOfMonth.getMaximumValue)
    val checklists = Checklist.findChecklistRange(key, from, to)
    some(ChecklistReport(key, ~checklists.headOption.map(_.name), checklists))
  }

  def findAvailableMonths(key: String):Seq[(Int, Seq[String])] = {
    val r = for {
      y <- Checklist.findDates(key).groupBy(_.getYear).toSeq
    } yield (y._1, y._2.groupBy(_.monthOfYear.getAsText).keys.toSeq)
    r.reverse.toSeq
  }

  implicit object ChecklistReportWrites extends Writes[ChecklistReport] {
    override def writes(report: ChecklistReport) = JsObject(Seq(
      "key"        -> JsString(report.key),
      "name"       -> JsString(report.name),
      "from"       -> Json.toJson(report.startDate),
      "to"         -> Json.toJson(report.untilDate),
      "summary"    -> Json.toJson(report.summary)
    ))
  }
}