plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val isGoogleServicesEnabledBuild =
    gradle.startParameter.taskNames.none { taskName ->
        taskName.contains("Mock", ignoreCase = true)
    }

if (isGoogleServicesEnabledBuild) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.physilog.physi_log"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.physilog.physi_log"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "PhysiLog"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    flavorDimensions += listOf("env")
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "PhysiLog Dev"
        }
        create("prod") {
            dimension = "env"
            // Prod uses the default applicationId / label.
        }
        create("mock") {
            dimension = "env"
            applicationIdSuffix = ".mock"
            manifestPlaceholders["appLabel"] = "PhysiLog Mock"
        }
    }
}

flutter {
    source = "../.."
}
