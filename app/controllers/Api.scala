package controllers

import play.api.mvc.{Controller, Action}
import models._
import com.novus.salat._
import mongoContext._
import play.api.libs.json.Json

object Api extends Controller {
  def sites = Action {
    Ok(Json.toJson(Site.findSites)).as(JSON)
  }

  def templates = Action {
    Ok(Json.toJson(ChecklistTemplate.findTemplates)).as(JSON)
  }

  def checkList(site:String, date:String) = Action {
    Checklist.findOrCreate(site, JsonFormatters.fmt.parseDateTime(date).toDateMidnight).map(c => Ok(Json.toJson(c)).as(JSON)).getOrElse(NotFound)
  }

  def saveCheckList(site:String, date:String) = Action { implicit request =>
    request.body.asJson.map(_.as[Checklist]).map(Checklist.saveChecklist)
    Ok
  }
}
