allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// zego_express_engine compiles against Android 31, older than its own AndroidX
// dependencies need; build it against the same SDK as the app.
subprojects {
    if (name == "zego_express_engine") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> { compileSdk = 36 }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
