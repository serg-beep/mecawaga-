import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")
if (releaseKeyPropertiesFile.exists()) {
    releaseKeyPropertiesFile.inputStream().use(releaseKeyProperties::load)
}
val releaseStoreFilePath = releaseKeyProperties.getProperty("storeFile")
val releaseSigningConfigured = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { !releaseKeyProperties.getProperty(it).isNullOrBlank() } &&
    !releaseStoreFilePath.isNullOrBlank() &&
    rootProject.file(releaseStoreFilePath).exists()
val configuredApplicationId = providers.gradleProperty("mecawagaApplicationId")
    .orElse("com.example.mecawaga")
    .get()

android {
    namespace = "com.example.mecawaga"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = configuredApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.create("release").apply {
                storeFile = rootProject.file(
                    releaseStoreFilePath ?: "upload-keystore.jks",
                )
                storePassword = releaseKeyProperties.getProperty("storePassword") ?: ""
                keyAlias = releaseKeyProperties.getProperty("keyAlias") ?: ""
                keyPassword = releaseKeyProperties.getProperty("keyPassword") ?: ""
            }
        }
    }
}

tasks.configureEach {
    if (
        name == "validateSigningRelease" ||
        name == "bundleRelease" ||
        name == "assembleRelease"
    ) {
        doFirst {
            check(releaseSigningConfigured) {
                "Release signing is not configured. Create android/key.properties using android/key.properties.example."
            }
            check(configuredApplicationId != "com.example.mecawaga") {
                "Replace the example applicationId with the production package registered in Firebase."
            }
            val productionOptions = rootProject.file("../lib/firebase_options_prod.dart")
            check(productionOptions.exists()) {
                "Configure Firebase production with flutterfire configure before release."
            }
            val optionsText = productionOptions.readText()
            check(!optionsText.contains("PROD_")) {
                "Firebase production options still contain placeholder values."
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
