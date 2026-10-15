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
// onnxruntime 插件模块自身编译在 android-33，而其 AAR 元数据要求 34+；
// 在其评估完成后覆写 compileSdk。注意必须先注册该回调，
// 再 evaluationDependsOn(":app")（后者会连带评估插件子项目）。
subprojects {
    if (project.name == "onnxruntime") {
        afterEvaluate {
            project.extensions
                .findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.apply { compileSdk = 34 }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
