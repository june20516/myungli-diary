import groovy.json.JsonSlurper
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 로그인 제공자 공개 식별자(결정 A81). Dart(--dart-define-from-file)와 같은 파일을 읽습니다.
// 값이 비면 어떤 링크와도 맞지 않는 자리 값을 넣어 manifest가 늘 유효하게 합니다.
@Suppress("UNCHECKED_CAST")
val authConfig = JsonSlurper().parse(file("../../config/auth.json")) as Map<String, String>

fun authValue(key: String): String = authConfig[key]?.trim().orEmpty()

// release 업로드 키(결정 A94). 저장소 밖 보관 폴더(D98, docs/local-values.md K1)에서 읽습니다.
// 파일이 없으면 release도 debug 키로 서명합니다(로컬 확인용, Play에 올릴 수 없음).
val localValuesDir =
    System.getenv("MYUNGLI_LOCAL_DIR")?.takeIf { it.isNotBlank() }
        ?: "${System.getProperty("user.home")}/.config/myungli"
val uploadKeyFile = file("$localValuesDir/app/shared/key.properties")
val uploadKey: Properties? =
    if (uploadKeyFile.isFile) {
        Properties().apply { uploadKeyFile.inputStream().use { load(it) } }
    } else {
        null
    }

android {
    namespace = "app.myungli.diary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications(아침 알림 채널)가 요구합니다.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.myungli.diary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Patrol E2E: instrumentation 실행기와 테스트마다 앱 데이터 초기화
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
        val kakaoKey = authValue("KAKAO_NATIVE_APP_KEY")
        manifestPlaceholders["kakaoScheme"] =
            if (kakaoKey.isEmpty()) "kakao-unconfigured" else "kakao$kakaoKey"
        manifestPlaceholders["appLinkHost"] =
            authValue("APP_LINK_HOST").ifEmpty { "unconfigured.invalid" }
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        if (uploadKey != null) {
            create("upload") {
                storeFile = uploadKeyFile.parentFile.resolve(uploadKey.getProperty("storeFile"))
                storePassword = uploadKey.getProperty("storePassword")
                keyAlias = uploadKey.getProperty("keyAlias")
                keyPassword = uploadKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (uploadKey != null) {
                    signingConfigs.getByName("upload")
                } else {
                    logger.warn("업로드 키가 없어 release를 debug 키로 서명합니다: $uploadKeyFile")
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
