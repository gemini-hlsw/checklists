package controllers

import play.api.mvc.{Controller, Action}
import models._
import com.novus.salat._
import mongoContext._
import play.api.libs.json._
import play.api.data._
import play.api.data.Forms._

import scalaz._
import Scalaz._

object Api extends Controller {
  def sites = Action {
    Ok(Json.toJson(Site.findSites)).as(JSON)
  }

  val keyValidationForm = Form(
    single(
      "key" -> text
    )
  )

  def validateKey = Action { implicit request =>
    keyValidationForm.bindFromRequest.fold(
      formWithErrors =>
        BadRequest,
      key => {// binding success, you get the actual value 
        ChecklistTemplate.findTemplate(key).map(t => Ok(JsString(key + " already exist"))).getOrElse(Ok(JsBoolean(true))).as(JSON)
      }
    )
  }

  def templates = Action {
    Ok(Json.toJson(ChecklistTemplate.findTemplates.sortBy(t => (t.colPos, t.rowPos)))).as(JSON)
  }

  def template(key: String) = Action {
    Ok(Json.toJson(ChecklistTemplate.findTemplate(key))).as(JSON)
  }

  def templateSettings(site: String) = Action {
    ChecklistTemplate.loadSettings(site).map(t => Ok(Json.toJson(t)).as(JSON)).getOrElse(NotFound)
  }

  def newTemplate(key: String) = Action { implicit request =>
    request.body.asJson.map(_.as[TemplateCreationParams]).map(ChecklistTemplate.createNew).map(println)
    Ok
  }

  def saveTemplate(key: String) = Action { implicit request =>
    request.body.asJson.map(_.as[ChecklistTemplate]).map(ChecklistTemplate.saveTemplate).map(t => Ok(Json.toJson(t)).as(JSON)).getOrElse(NotFound)
  }

  def checkList(key:String, date:String) = Action {
    Checklist.findOrCreate(key, JsonFormatters.fmt.parseDateTime(date).toDateMidnight).map(c => Ok(Json.toJson(c)).as(JSON)).getOrElse(NotFound)
  }

  def saveCheckList(key:String, date:String) = Action { implicit request =>
    val result = request.body.asJson.map(_.as[Checklist]).map(Checklist.saveChecklist)
    result match {
      case Some(Right(c)) => Ok(Json.toJson(c)).as(JSON)
      case Some(Left(e))  => NotAcceptable(Json.toJson(e)).as(JSON)
      case None           => BadRequest
    }
  }

  def checkListReport(key:String, year: Int, month: Int) = Action {
    ChecklistReport.summarizePeriod(key, year, month).map(c => Ok(Json.toJson(c)).as(JSON)).getOrElse(NotFound)
  }

  def availableMonths(key: String) = Action {
    val availability = ChecklistReport.findAvailableMonths(key).map {
      case (y, m) => JsObject(Seq("year" -> JsNumber(y), "months" -> Json.toJson(m)))
    }
    Ok(Json.toJson(availability)).as(JSON)
  }

}
