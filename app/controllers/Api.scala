package controllers

import play.api.mvc.{Controller, Action}
import models._
import com.novus.salat._
import mongoContext._
import play.api.libs.json.{Json, JsNumber, JsString, JsObject}

object Api extends Controller {
  def sites = Action {
    Ok(Json.toJson(Site.findSites)).as(JSON)
  }

  def templates = Action {
    Ok(Json.toJson(ChecklistTemplate.findTemplates)).as(JSON)
  }

  def template(site: String) = Action {
    Ok(Json.toJson(ChecklistTemplate.findTemplate(site))).as(JSON)
  }

  def templateSettings(site: String) = Action {
    ChecklistTemplate.loadSettings(site).map(t => Ok(Json.toJson(t)).as(JSON)).getOrElse(NotFound)
  }

  def saveTemplate(site: String) = Action { implicit request =>
    request.body.asJson.map(_.as[ChecklistTemplate]).map(ChecklistTemplate.saveTemplate).map(t => Ok(Json.toJson(t)).as(JSON)).getOrElse(NotFound)
  }

  def checkList(site:String, date:String) = Action {
    Checklist.findOrCreate(site, JsonFormatters.fmt.parseDateTime(date).toDateMidnight).map(c => Ok(Json.toJson(c)).as(JSON)).getOrElse(NotFound)
  }

  def saveCheckList(site:String, date:String) = Action { implicit request =>
    val result = request.body.asJson.map(_.as[Checklist]).map(Checklist.saveChecklist)
    result match {
      case Some(Right(c)) => Ok(Json.toJson(c)).as(JSON)
      case Some(Left(e))  => NotAcceptable(Json.toJson(e)).as(JSON)
      case None           => BadRequest
    }
  }

  def checkListReport(site:String, year: Int, month: Int) = Action {
    ChecklistReport.summarizePeriod(site, year, month).map(c => Ok(Json.toJson(c)).as(JSON)).getOrElse(NotFound)
  }

  def availableMonths(site: String) = Action {
    val availability = ChecklistReport.findAvailableMonths(site).map {
      case (y, m) => JsObject(Seq("year" -> JsNumber(y), "months" -> Json.toJson(m)))
    }
    Ok(Json.toJson(availability)).as(JSON)
  }

}
