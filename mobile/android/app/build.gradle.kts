plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.armstrang.verbarium"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.armstrang.verbarium"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // One fixed key for every test build: Android only accepts an update signed with the same key.
        // The key is public (it lives in this repo), so it is for test builds only, never for Google Play.
        create("sideload") {
            storeFile = rootProject.file("../../keystore/verbarium.jks")
            storePassword = "verbariumkunci"
            keyAlias = "verbarium"
            keyPassword = "verbariumkunci"
        }
        // The Google Play upload key. Only CI has it: keystore/upload.jks.enc is decrypted there with the secret
        // VERBARIUM_UPLOAD_PASSWORD, and the AAB for Play is built with VERBARIUM_PLAY=1. Google re-signs the app.
        val upload = rootProject.file("../../keystore/upload.jks")
        val pw = System.getenv("VERBARIUM_UPLOAD_PASSWORD")
        if (upload.exists() && !pw.isNullOrEmpty()) {
            create("upload") {
                storeFile = upload
                storePassword = pw
                keyAlias = "upload"
                keyPassword = pw
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (System.getenv("VERBARIUM_PLAY") == "1") signingConfigs.getByName("upload")
            else signingConfigs.getByName("sideload")
        }
        debug {
            signingConfig = signingConfigs.getByName("sideload")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.android.billingclient:billing:8.0.0")
}

flutter {
    source = "../.."
}
