package models

import com.mongodb.casbah.commons.conversions.MongoConversionHelper
import org.scala_tools.time.Imports._
import org.bson.{BSON, Transformer}
import org.joda.time.DateMidnight

object RegisterJodaDateMidnightConversionHelpers extends JodaDateMidnightHelpers {
  def apply() = {
    log.debug("Registering  Joda Date Time Scala Conversions.")
    super.register()
  }
}

object DeregisterJodaDateMidnightConversionHelpers extends JodaDateMidnightHelpers {
  def apply() = {
    log.debug("Unregistering Joda Date Time Scala Conversions.")
    super.unregister()
  }
}

trait JodaDateMidnightHelpers extends JodaDateMidnightSerializer with JodaDateMidnightDeserializer

trait JodaDateMidnightSerializer extends MongoConversionHelper {

  private val encodeType = classOf[DateMidnight]
  /** Encoding hook for MongoDB To be able to persist JodaDateMidnight DateMidnight to MongoDB */
  private val transformer = new Transformer {
    log.trace("Encoding a JodaDateMidnight DateMidnight.")

    def transform(o: AnyRef): AnyRef = o match {
      case d: DateMidnight => d.toDate // Return a JDK Date object which BSON can encode
      case _ => o
    }

  }

  override def register() {
    log.debug("Hooking up Joda DateMidnight serializer.")
    /** Encoding hook for MongoDB To be able to persist JodaDateMidnight DateMidnight to MongoDB */
    BSON.addEncodingHook(encodeType, transformer)
    super.register()
  }

  override def unregister() {
    log.debug("De-registering Joda DateMidnight serializer.")
    BSON.removeEncodingHooks(encodeType)
    super.unregister()
  }
}

trait JodaDateMidnightDeserializer extends MongoConversionHelper {

  private val encodeType = classOf[java.util.Date]
  private val transformer = new Transformer {
    log.trace("Decoding JDK Dates .")

    def transform(o: AnyRef): AnyRef = o match {
      case jdkDate: java.util.Date => new DateMidnight(jdkDate)
      case d: DateMidnight => d
      case _ => o
    }
  }

  override def register() {
    log.debug("Hooking up Joda DateMidnight deserializer")
    /** Encoding hook for MongoDB To be able to read JodaDateMidnight DateMidnight from MongoDB's BSON Date */
    BSON.addDecodingHook(encodeType, transformer)
    super.register()
  }

  override def unregister() {
    log.debug("De-registering Joda DateMidnight deserializer.")
    BSON.removeDecodingHooks(encodeType)
    super.unregister()
  }
}

