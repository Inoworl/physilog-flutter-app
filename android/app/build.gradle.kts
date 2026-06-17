import java.io.File
import java.io.FileInputStream
import java.util.Properties

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

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.inoworl.physilog"
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
        applicationId = "com.inoworl.physilog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "PhysiLog"
    }

    signingConfigs {
        create("release") {
            val envKeystorePath = System.getenv("ANDROID_UPLOAD_KEYSTORE_PATH")
            val envStorePassword = System.getenv("ANDROID_UPLOAD_KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("ANDROID_UPLOAD_KEY_ALIAS")
            val envKeyPassword = System.getenv("ANDROID_UPLOAD_KEY_PASSWORD")

            storeFile = envKeystorePath
                ?.takeIf { it.isNotBlank() }
                ?.let {
                    val candidate = File(it)
                    if (candidate.isAbsolute) candidate else rootProject.file(it)
                }
                ?: keystoreProperties["storeFile"]?.toString()?.let { file(it) }
            storePassword = envStorePassword ?: keystoreProperties["storePassword"]?.toString()
            keyAlias = envKeyAlias ?: keystoreProperties["keyAlias"]?.toString()
            keyPassword = envKeyPassword ?: keystoreProperties["keyPassword"]?.toString()
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
