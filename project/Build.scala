import sbt._
import Keys._
import PlayProject._

object ApplicationBuild extends Build {
  val emberOptions = SettingKey[Seq[String]]("ember-options")
  val emberEntryPoints = SettingKey[PathFinder]("ember-entry-points")

  def EmberCompiler(ember: String, handlebars: String) = {
    val compiler = new EmberCompiler(ember, handlebars)
    AssetsCompiler("ember-handlebars",
    (_ ** "*.handlebars"),
    emberEntryPoints, {
      (name, min) => "javascripts/" + name + ".pre" + (if (min) ".min.js" else ".js")
    }, {
      (handlebarsFile, options) =>
        val (jsSource, dependencies) = compiler.compileDir(handlebarsFile, options)
        // Any error here would be because of Handlebars, not the developer;
        // so we don't want compilation to fail.
        import scala.util.control.Exception._
        val minified = catching(classOf[CompilationException])
          .opt(play.core.jscompile.JavascriptCompiler.minify(jsSource, Some(handlebarsFile.getName)))
        (jsSource, minified, dependencies)
    },
    emberOptions
    )
  }

  val appName = "checklists"
  val appVersion = "1.0-SNAPSHOT"

  val appDependencies = Seq(
    "org.mozilla" % "rhino" % "1.7R4",
    "se.radley" %% "play-plugins-salat" % "1.1",
    "org.scalaz" %% "scalaz-core" % "6.0.4"
  )

  val main = PlayProject(appName, appVersion, appDependencies, mainLang = SCALA).settings(
    resolvers += "sgodbillon" at "https://bitbucket.org/sgodbillon/repository/raw/master/snapshots/",
    emberEntryPoints <<= (sourceDirectory in Compile)(base => base / "assets" / "templates"),
    emberOptions := Seq.empty[String],
    routesImport += "se.radley.plugin.salat.Binders._",
    templatesImport += "org.bson.types.ObjectId",

    resourceGenerators in Compile <+= EmberCompiler(ember = "ember-1.0.0-pre.2.for-rhino.js", handlebars = "handlebars-1.0.rc.1.js"),
    coffeescriptOptions := Seq("native", "/opt/local/bin/coffee -p")
  )

}
