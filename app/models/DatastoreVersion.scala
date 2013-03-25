package models

import com.novus.salat.dao.{SalatDAO, ModelCompanion}
import com.mongodb.casbah.Imports._
import se.radley.plugin.salat._
import play.api.Play.current
import mongoContext._

case class DatastoreVersion(id: ObjectId = new ObjectId, version: Int)

object DatastoreVersion extends ModelCompanion[DatastoreVersion, ObjectId] {
  lazy val dao = new SalatDAO[DatastoreVersion, ObjectId](collection = mongoCollection("datastore_version")) {}

  def findLatest():Option[DatastoreVersion] =
    //dao.findOne(MongoDBObject()).toList.max(v:DatastoreVersion => v.version).headOption
    dao.findOne(MongoDBObject()).toList.headOption

  def store(version: Int):DatastoreVersion = {
    val datastoreVersion = DatastoreVersion(version = version)
    dao.insert(datastoreVersion)
    datastoreVersion
  }

}
