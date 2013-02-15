package controllers

import play.api.mvc._

object Application extends Controller {
  
  def index = Action {
    Ok(views.html.checklists())
  }
  def test = Action {
    Ok(views.html.test())
  }

  def about = Action {
    Ok(views.html.about())
  }
  
}