plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vendo_buyer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.vendo_buyer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Committed on purpose. Google Sign-In and Firebase tie an Android OAuth client
        // to the signing certificate's SHA-1, so every machine and every collaborator
        // must sign local builds with the same key or sign-in fails with
        // DEVELOPER_ERROR. This is a public, debug-only key (alias androiddebugkey,
        // password android); the shared file lives in ../android-keys of the repo.
        create("vendoDebug") {
            storeFile = rootProject.file("../../android-keys/vendo-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("vendoDebug")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signed with the shared debug key for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("vendoDebug")
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
