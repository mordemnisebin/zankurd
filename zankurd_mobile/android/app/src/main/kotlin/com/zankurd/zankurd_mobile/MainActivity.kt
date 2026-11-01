package com.zankurd.app

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import android.os.Build
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.zankurd.app/notification_settings").setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
            } else {
                try {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"))
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enforceMeasurementConsent()
        super.onCreate(savedInstanceState)
    }

    /**
     * Ölçüm rızası Dart'tan ÖNCE uygulanır (2026-10-29, Opus+Astra kararı).
     *
     * Manifest'teki `*_collection_enabled=false` yalnız varsayılandır; 2.1.1+41
     * ve öncesinde rıza varsayılan açıktı ve `setAnalyticsCollectionEnabled(true)`
     * / `setCrashlyticsCollectionEnabled(true)` SDK'ya KALICI yazıldı. Yükseltilen
     * kurulumda bu kalıcı değer manifest'i ezer ve Flutter motoru açılmadan
     * oturum olayları / bekleyen çökme raporları gidebilirdi. Kullanıcı açıkça
     * `true` saklamadıysa burada kapatılır; açma yalnız Dart'ta (Ayarlar).
     *
     * Firebase sınıfları uygulama modülünün derleme yolunda değil (FlutterFire
     * eklentileri `implementation` ile bağlar); bu yüzden yansıma ile çağrılır,
     * sınıf yoksa sessizce geçilir.
     */
    private fun enforceMeasurementConsent() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val analytics = prefs.getBoolean("flutter.zankurd.analyticsConsent", false)
        val crash = if (prefs.contains("flutter.zankurd.crashReportsConsent")) {
            prefs.getBoolean("flutter.zankurd.crashReportsConsent", false)
        } else {
            analytics
        }
        if (!analytics) {
            try {
                val cls = Class.forName("com.google.firebase.analytics.FirebaseAnalytics")
                val instance = cls.getMethod("getInstance", Context::class.java).invoke(null, this)
                cls.getMethod("setAnalyticsCollectionEnabled", Boolean::class.javaPrimitiveType)
                    .invoke(instance, false)
            } catch (_: Throwable) {
            }
        }
        if (!crash) {
            try {
                val cls = Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")
                val instance = cls.getMethod("getInstance").invoke(null)
                cls.getMethod("setCrashlyticsCollectionEnabled", Boolean::class.javaPrimitiveType)
                    .invoke(instance, false)
            } catch (_: Throwable) {
            }
        }
    }
}
