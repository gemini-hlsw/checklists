package models

import com.novus.salat.dao.{SalatDAO, ModelCompanion}
import com.mongodb.casbah.Imports._
import se.radley.plugin.salat._
import org.joda.time.DateMidnight
import org.bson.types.ObjectId
import play.api.libs.json.{Json, JsString, JsObject, Writes}
import play.api.Play.current
import mongoContext._
import JsonFormatters._

case class Site(id: ObjectId = new ObjectId, site: String, name: String)

object Site extends ModelCompanion[Site, ObjectId] {
  val dao = new SalatDAO[Site, ObjectId](collection = mongoCollection("sites")) {}

  def findSites: Seq[Site] = dao.find(MongoDBObject()).toSeq

  def insertSite(site: Site): Site = site.copy(id = dao.insert(site, WriteConcern.Normal).getOrElse(ObjectId.get()))  // TBD Do proper validation of the error

  implicit object SiteFormat extends Writes[Site] {
    def writes(s: Site) = JsObject(Seq(
      "site" -> JsString(s.site),
      "name" -> JsString(s.name)
    ))
  }

}
