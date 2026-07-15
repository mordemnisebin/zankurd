import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val requiredReleaseSigningFields =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningProblems = buildList {
    if (!keystorePropertiesFile.isFile) {
        add("android/key.properties")
    } else {
        addAll(
            requiredReleaseSigningFields.filter { field ->
                keystoreProperties.getProperty(field).isNullOrBlank()
            },
        )

        val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()
        if (!storeFilePath.isNullOrEmpty() && !rootProject.file(storeFilePath).isFile) {
            add("storeFile (keystore file not found)")
        }
    }
}
val isReleaseTaskRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

if (isReleaseTaskRequested && releaseSigningProblems.isNotEmpty()) {
    throw GradleException(
        "Release signing configuration is missing or incomplete. " +
            "Expected android/key.properties with non-empty fields: " +
            "storeFile, storePassword, keyAlias, keyPassword; storeFile must point to an existing keystore. " +
            "Missing or invalid: ${releaseSigningProblems.joinToString()}. " +
            "Use a debug build for development (for example, flutter build apk --debug). " +
            "The release build was stopped for security and will not fall back to debug signing.",
    )
}

android {
    namespace = "com.zankurd.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.zankurd.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningProblems.isEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
