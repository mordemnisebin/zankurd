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

// Play Console 31 Ağustos 2026'dan sonra targetSdk 36'nın altındaki yeni
// yayın sürümlerini kabul etmiyor.
//
// `flutter.targetSdkVersion` bugün 36 döndürüyor (Flutter 3.44.7,
// FlutterExtension.kt:34), yani zorunluluk şu an karşılanıyor — ama ÖRTÜK
// olarak: değer bizim değil, kurulu Flutter sürümünün kararı. Daha eski bir
// Flutter ile alınan bir release sessizce 35'e düşer ve bunu ancak Play
// Console reddedince öğreniriz. Bu, derleme zamanında yakalanabilecek bir
// hatayı yayın zamanına erteler.
//
// Değerler bu yüzden açıkça yazılır; alttaki kontrol, kurulu Flutter'ın
// varsayımın gerisine düşmesi hâlinde derlemeyi durdurur.
// Yükseltirken önce cihazda Android 16 davranış değişikliklerini doğrula:
// zorunlu edge-to-edge çizim, bildirim ve ön plan servis kısıtları.
val zankurdCompileSdk = 36
val zankurdTargetSdk = 36
val zankurdMinSdk = 24

if (flutter.targetSdkVersion < zankurdTargetSdk) {
    throw GradleException(
        "Kurulu Flutter targetSdk ${flutter.targetSdkVersion} veriyor; bu proje " +
            "$zankurdTargetSdk gerektiriyor (Play 2026-08-31 zorunluluğu). " +
            "Flutter'ı güncelleyin.",
    )
}

android {
    namespace = "com.zankurd.app"
    compileSdk = zankurdCompileSdk
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.zankurd.app"
        // Sürümler yukarıda açıkça sabitlendi; gerekçesi orada yazılı.
        minSdk = zankurdMinSdk
        targetSdk = zankurdTargetSdk
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
            // Native crash'ler sembolsüz geliyordu: AAB üç ABI için
            // libflutter.so/libapp.so taşıyor ama sembol tablosu
            // yapılandırılmamıştı, dolayısıyla Play Console "debug symbols
            // yüklenmedi" uyarısı veriyor ve engine/plugin çökmeleri
            // okunamaz yığınlarla ulaşıyordu (2026-08-01 denetimi, P2-003).
            // FULL, sembolleri doğrudan bundle'a koyar; Play yüklemede
            // ayıklar, indirilen APK'nın boyutu değişmez.
            ndk {
                debugSymbolLevel = "FULL"
            }
            // R8 ile kod küçültme + kaynak temizleme (AAB boyutunu düşürür).
            // Kurallar proguard-rules.pro'da; eklentilerin (Firebase, Supabase,
            // RevenueCat, flutter_tts, bildirimler) sınıfları korunur.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
