pluginManagement {
<<<<<<< HEAD
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

=======
>>>>>>> d0fa69273906ca67a483ad0e4f4d6a6956ab1b1b
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

<<<<<<< HEAD
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

include(":app")
=======
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "sports_league_app"
include(":app")

apply(from: "${System.getenv("FLUTTER_ROOT")}/packages/flutter_tools/gradle/app_plugin_loader.gradle")
>>>>>>> d0fa69273906ca67a483ad0e4f4d6a6956ab1b1b
