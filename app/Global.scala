import models.{ChecklistTemplate, Site, RegisterJodaDateMidnightConversionHelpers, DatastoreVersion}
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
    val version = DatastoreVersion.findLatest() | DatastoreVersion.store(1)
    println("Store Version: " + version.version)
    /*version.version match {
      case 1 => {
        if (templates.size === 2) {
          //db.temp.update({}, {$set:{ "key": ""}}, false, true)
          /*println("Upgrade the templates")
          templates.foreach(_.match {
            case _ =>
          })*/
        }
        DatastoreVersion.store(version=2)
      case _ =>
    }*/
  }
}
