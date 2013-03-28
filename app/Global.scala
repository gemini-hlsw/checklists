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
    val version = DatastoreVersion.findLatest() | DatastoreVersion.store(1)
    println("Store Version: " + version.version)
  }
}
