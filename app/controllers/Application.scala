package controllers

import play.api.mvc._

object Application extends Controller {
  
  def index = Action {
    Ok(views.html.checklists())
  }

  def about = Action {
    Ok(views.html.about())
  }
  
}