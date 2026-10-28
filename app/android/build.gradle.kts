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
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_line_sdk 2.7.2는 AGP 9 이상이면 내장 Kotlin이 있다고 보고 kotlin-android를 적용하지
// 않습니다. 이 앱은 android.builtInKotlin=false라 그대로면 플러그인의 Kotlin 소스가 컴파일되지
// 않아(GeneratedPluginRegistrant가 FlutterLineSdkPlugin을 찾지 못함) 이 라이브러리에만
// 적용합니다. Java 1.8로 컴파일하므로 Kotlin 대상도 1.8로 맞춥니다.
// 또 compileSdk 33을 고정해 두어 함께 쓰는 androidx(34 이상 요구)의 AAR 검사에 걸리므로, 평가가
// 끝난 뒤 앱과 같은 compileSdk로 맞춥니다(targetSdk·minSdk는 그대로).
subprojects {
    if (name == "flutter_line_sdk") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                }
            }
        }
        afterEvaluate {
            val appCompileSdk = project(":app")
                .extensions.getByType<com.android.build.api.dsl.ApplicationExtension>()
                .compileSdk
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = appCompileSdk
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
