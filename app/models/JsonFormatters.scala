package models

import play.api.libs.json.{JsString, JsNumber, JsValue, Format}
import org.joda.time.{DateMidnight, DateTime}
import org.joda.time.format.DateTimeFormat

object JsonFormatters {
  implicit object JodaDateFormat extends Format[DateTime] {
    def reads(json: JsValue) = new DateTime(json.as[String])

    def writes(date: DateTime) = JsNumber(date.getMillis)
  }

  implicit object DateMidnightFormat extends Format[DateMidnight] {
    val fmt = DateTimeFormat.forPattern("yyyyMMdd")
    def reads(json: JsValue) = json.asOpt[String].map(fmt.parseDateTime).map(_.toDateMidnight).getOrElse(DateMidnight.now())

    def writes(date: DateMidnight) = JsString(fmt.print(date))
  }

}
