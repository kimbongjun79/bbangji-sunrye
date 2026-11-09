import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 서명 키는 저장소 밖(keys/, .gitignore)에 둔다. 카카오 키 해시가 이 키에 묶여 있어 debug·release 모두 같은 키로 서명한다.
val keyProperties = Properties().apply {
    val f = rootProject.file("../../keys/key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.bbangji.bbangji_sunrye"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bbangji.sunrye"
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 카카오맵 SDK는 ARM 전용. 다른 플러그인의 x86 라이브러리가 섞이면 x86 기기·에뮬레이터가 x86_64를 고르고
    // 카카오·Flutter 라이브러리를 못 찾는다. ARM만 담으면 x86_64 에뮬레이터는 ARM 변환으로 실행한다.
    packaging {
        jniLibs {
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
        }
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("app") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        val signing = signingConfigs.findByName("app") ?: signingConfigs.getByName("debug")
        debug {
            signingConfig = signing
        }
        release {
            signingConfig = signing
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
