package models

import play.api.libs.json._
import org.joda.time.{DateMidnight, DateTime}
import org.joda.time.format.DateTimeFormat

object JsonFormatters {
  val fmt = DateTimeFormat.forPattern("yyyyMMdd")

  implicit object JodaDateFormat extends Format[DateTime] {
    def reads(json: JsValue) = JsSuccess(new DateTime(json.as[String]))

    def writes(date: DateTime) = JsNumber(date.getMillis)
  }

  implicit object DateMidnightFormat extends Format[DateMidnight] {
    def reads(json: JsValue) = JsSuccess(json.asOpt[String].map(fmt.parseDateTime).map(_.toDateMidnight).getOrElse(DateMidnight.now()))

    def writes(date: DateMidnight) = JsString(fmt.print(date))
  }

}
