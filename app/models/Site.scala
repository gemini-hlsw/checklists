package models

/**
 * Created with IntelliJ IDEA.
 * User: cquiroz
 * Date: 12/10/12
 * Time: 11:24 AM
 * To change this template use File | Settings | File Templates.
 */
case class Site(id: ObjectId = new ObjectId, site:String, name: String, date: DateMidnight = new DateMidnight())
