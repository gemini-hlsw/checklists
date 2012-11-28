package models

import org.specs2.mutable.Specification
import org.joda.time.DateMidnight

import scalaz._
import Scalaz._

class ChecklistSpec extends Specification {
  val checks1 = Check("check1", None, None) :: Check("check2", Some("done"), Some("comment")) :: Nil
  val groups1 = CheckGroup("name", "title", checks1) :: Nil

  val checks2 = Check("check1", Some("done"), Some("comment")) :: Check("check2", None, None) :: Nil
  val groups2 = CheckGroup("name", "title", checks2) :: Nil

  val checks3 = Check("check1", Some("done"), Some("comment")) :: Check("check2", Some("done"), Some("comment")) :: Nil
  val groups3 = CheckGroup("name", "title", checks3) :: Nil

  "A Checklists" should {
    "be unchanged when merged with itself" in {
      val cl1 =  Checklist(site = "GS", name = "GS", date = DateMidnight.now(), groups = groups1)
      Checklist.mergeLists(cl1)(cl1) must beEqualTo(cl1)
    }
    "be unchanged when merged with one identical" in {
      val cl1 =  Checklist(site = "GS", name = "GS", date = DateMidnight.now(), groups = groups1)
      val cl2 =  Checklist(site = "GS", name = "GS", date = DateMidnight.now(), groups = groups1)
      Checklist.mergeLists(cl1)(cl2) must beEqualTo(cl2)
    }
    "merge with another" in {
      val cl1 =  Checklist(site = "GS", name = "GS", date = DateMidnight.now(), groups = groups1)
      val cl2 =  Checklist(site = "GS", name = "GS", date = DateMidnight.now(), groups = groups2)

      val cl3 =  Checklist(id = cl2.id, site = "GS", name = "GS", date = DateMidnight.now(), groups = groups3)

      Checklist.mergeLists(cl1)(cl2) must beEqualTo(cl3)
    }
  }

  "A Check list" should {
    "merge with itself" in {
      Checklist.mergeChecks(checks1, checks1) must beEqualTo(checks1)
    }
    "merge with another" in {
      Checklist.mergeChecks(checks1, checks2) must beEqualTo(checks3)
    }
  }

  "A Check" should {
    "merge with itself if empty" in {
      val c = Check("check1", None, None)
      c.merge(c) must beEqualTo(c)
    }
    "merge with itself if with status" in {
      val c = Check("check1", Some("done"), None)
      c.merge(c) must beEqualTo(c)
    }
    "merge with itself if with comment" in {
      val c = Check("check1", Some("done"), Some("comment"))
      c.merge(c) must beEqualTo(c)
    }
    "merge with other if all none" in {
      val c1 = Check("check1", None, None)
      val c2 = Check("check1", None, None)
      c1.merge(c2) must beEqualTo(c1)
    }
    "merge with other if mine are defined preserving mine" in {
      val c1 = Check("check1", Some("done"), None)
      val c2 = Check("check1", None, None)
      c1.merge(c2) must beEqualTo(c1)

      val c3 = Check("check1", None, Some("comment"))
      c3.merge(c2) must beEqualTo(c3)

      val c4 = Check("check1", Some("done"), Some("comment"))
      c4.merge(c2) must beEqualTo(c4)
    }
    "merge with other if mine are not defined using theirs" in {
      val c1 = Check("check1", None, None)
      val c2 = Check("check1", Some("done"), None)
      c1.merge(c2) must beEqualTo(c2)

      val c3 = Check("check1", None, Some("comment"))
      c1.merge(c3) must beEqualTo(c3)

      val c4 = Check("check1", Some("done"), Some("comment"))
      c1.merge(c4) must beEqualTo(c4)
    }
    "merge mixed" in {
      val c1 = Check("check1", None, Some("comment"))
      val c2 = Check("check1", Some("done"), None)

      val c3 = Check("check1", Some("done"), Some("comment"))

      c1.merge(c2) must beEqualTo(c3)
    }
    "merge with conflicts" in {
      val c1 = Check("check1", Some("done"), None)
      val c2 = Check("check1", Some("not done"), Some("comment"))

      val c3 = Check("check1", Some("done"), Some("comment"))

      c1.merge(c2) must beEqualTo(c3)
    }
  }
}
