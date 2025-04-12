allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // 如果需要依赖 app 模块
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
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