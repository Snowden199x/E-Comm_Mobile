import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    // Kotlin is compiled by AGP's built-in Kotlin support (see android/gradle.properties).
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key is not committed. Without it (fresh clone), release builds fall
// back to the shared debug key so `flutter run --release` still works during
// development.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "vendoph.rider"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent public identity of the app. Changing it later creates a new app
        // in Google Play and on every phone that already installed it.
        applicationId = "vendoph.rider"
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

        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("vendoDebug")
        }
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("vendoDebug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
