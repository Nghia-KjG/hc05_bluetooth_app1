plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hc05_bluetooth_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required for libraries (e.g., ota_update) that need desugaring support
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.hc05_bluetooth_app"
        minSdkVersion(24)
        // Google Play requires targetSdkVersion 33 or higher as of 2025.
        // Bump to 33 to meet Play Store requirements.
        targetSdkVersion(33)
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
    // Add minimal hutool core for dependencies required by `bluetoothlibrary` AAR
    // (previously used `hutool-all` which pulled in many desktop/server-only dependencies)
    implementation("cn.hutool:hutool-core:5.8.25")
    // Desugaring library needed for ota_update (Java 8+ APIs on older Android)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}