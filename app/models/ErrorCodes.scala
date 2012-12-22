package models

import play.api.libs.json.{JsString, Writes, JsObject}

case class ErrorCode(message: String)

object ErrorCode {
  val ChecklistClosed = ErrorCode("Checklist is already closed")
  val NotFound        = ErrorCode("Checklist not found")

  implicit object ErrorCodeWrites extends Writes[ErrorCode] {
    def writes(e: ErrorCode) = JsObject(Seq(
      "error" -> JsString(e.message)
    ))
  }
}