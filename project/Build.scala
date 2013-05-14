import com.ketalo.EmberJsKeys
import sbt._
import Keys._
import play.Project._

object ApplicationBuild extends Build with EmberJsKeys {
  val appName = "checklists"
  val appVersion = "1.0-SNAPSHOT"

  val appDependencies = Seq(
    "se.radley" % "play-plugins-salat_2.10" % "1.2",
    "com.novus" %% "salat" % "1.9.2-SNAPSHOT",
    "org.scalaz" %% "scalaz-core" % "6.0.4",
    "com.typesafe" %% "play-plugins-mailer" % "2.1.0",
    "org.fusesource.scalate" %% "scalate-wikitext" % "1.6.1",
    "org.fusesource.scalate" %% "scalate-page" % "1.6.1"
  )

  val main = play.Project(appName, appVersion, appDependencies).settings(
    resolvers += "sgodbillon" at "https://bitbucket.org/sgodbillon/repository/raw/master/snapshots/",
    resolvers += "Sonatype snapshots" at "http://oss.sonatype.org/content/repositories/snapshots/",
    emberJsVersion := "1.0.0-pre.2",
    routesImport += "se.radley.plugin.salat.Binders._",
    templatesImport += "org.bson.types.ObjectId"

    //coffeescriptOptions := Seq("native", "/opt/local/bin/coffee -p")
  )

}
