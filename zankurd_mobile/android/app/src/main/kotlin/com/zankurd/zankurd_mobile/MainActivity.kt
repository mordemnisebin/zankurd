package com.zankurd.app

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
