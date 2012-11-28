import models.{Site, RegisterJodaDateMidnightConversionHelpers}
import play.api.{Application, GlobalSettings}

object Global extends GlobalSettings {
  override def onStart(app: Application) {
    RegisterJodaDateMidnightConversionHelpers()

    // Write tha basic data if missing
    val sites = Site.findSites
    if (sites.isEmpty) {
      (Site(site = "GS", name = "Gemini South") :: Site(site = "GN", name = "Gemini North") :: Nil).map(Site.insertSite)
    }
  }
}
