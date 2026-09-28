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
// Plugins pin their own compileSdk, and file_picker still ships 34 while the
// lifecycle plugin it depends on demands 36. Raising it here rather than
// waiting for the plugin to catch up, because the alternative is dropping
// in-app document upload.
//
// Must sit above the evaluationDependsOn(":app") block below: that one
// forces evaluation, and afterEvaluate cannot be registered after it.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            val android = ext as com.android.build.gradle.BaseExtension
            if (android.compileSdkVersion?.removePrefix("android-")
                    ?.toIntOrNull()?.let { it < 36 } == true) {
                android.compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
