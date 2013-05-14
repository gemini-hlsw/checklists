import models.{ChecklistTemplate, Site, RegisterJodaDateMidnightConversionHelpers, DatastoreVersion}
import play.api.{Application, GlobalSettings}
import play.extras.iteratees._
import play.api.mvc.WithFilters

import scalaz._
import Scalaz._

object Global extends WithFilters(new GzipFilter) with GlobalSettings {
  override def onStart(app: Application) {
    RegisterJodaDateMidnightConversionHelpers()

    // Write the basic data if missing
    val sites = Site.findSites
    if (sites.isEmpty) {
      (Site(site = "GS", name = "Gemini South") :: Site(site = "GN", name = "Gemini North") :: Nil).map(Site.insertSite)
    }
    val version = DatastoreVersion.findLatest() | DatastoreVersion.store(1)
    println("Store Version: " + version.version)
  }
}
