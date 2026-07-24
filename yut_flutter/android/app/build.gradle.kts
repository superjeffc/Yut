plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jeffreychan.yunnori"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jeffreychan.yunnori"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val localOfficialKs = file("/home/superjeffreyc_cs/AndroidStuff")
            val ciOfficialKs = file("official_upload.keystore")
            val ciDebugKs = file("ci_debug.keystore")

            val envKsPass = System.getenv("KEYSTORE_PASSWORD") ?: ""
            val envKeyAlias = System.getenv("KEY_ALIAS") ?: ""
            val envKeyPass = System.getenv("KEY_PASSWORD") ?: ""

            if (localOfficialKs.exists() && envKsPass.isNotEmpty()) {
                storeFile = localOfficialKs
                storePassword = envKsPass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            } else if (ciOfficialKs.exists() && envKsPass.isNotEmpty()) {
                storeFile = ciOfficialKs
                storePassword = envKsPass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            } else if (ciDebugKs.exists()) {
                storeFile = ciDebugKs
                storePassword = "androiddebugkey"
                keyAlias = "androiddebugkey"
                keyPassword = "androiddebugkey"
            } else {
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
