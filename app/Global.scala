import models.{ChecklistTemplate, Site, RegisterJodaDateMidnightConversionHelpers}
import play.api.{Application, GlobalSettings}

import scalaz._
import Scalaz._

object Global extends GlobalSettings {
  override def onStart(app: Application) {
    RegisterJodaDateMidnightConversionHelpers()

    // Write the basic data if missing
    val sites = Site.findSites
    if (sites.isEmpty) {
      (Site(site = "GS", name = "Gemini South") :: Site(site = "GN", name = "Gemini North") :: Nil).map(Site.insertSite)
    }
    val templates = ChecklistTemplate.findTemplates
    if (templates.isEmpty) {
      (ChecklistTemplate(site = "GS", key = "", name = "Gemini South", groups = Nil) :: ChecklistTemplate(site = "GN", key = "", name = "Gemini North", groups = Nil) :: Nil).map(ChecklistTemplate.saveTemplate)
    }
    if (templates.size === 2) {
      println("Upgrade the templates")
    }
  }
}
