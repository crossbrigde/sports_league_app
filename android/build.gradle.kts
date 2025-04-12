plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0"
}

android {
    namespace = "com.example.sports_league_app_new"
    compileSdk = 33
    ndkVersion = "25.2.9519653"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.sports_league_app_new"
        minSdk = 21
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
    compileSdkVersion = 33
    ndkVersion = "25.2.9519653"
    minSdkVersion = 21
    targetSdkVersion = 33
    versionCode = 1
    versionName = "1.0"
}