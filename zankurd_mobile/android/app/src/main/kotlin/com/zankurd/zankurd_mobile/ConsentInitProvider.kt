package com.zankurd.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri

/**
 * Hata raporu rızasını Firebase'den ÖNCE uygular (2026-10-29, Opus+Astra).
 *
 * `FirebaseInitProvider` (initOrder 100) Crashlytics'i Activity'den, hatta
 * Application.onCreate'ten önce başlatır; 2.1.1+41 ve öncesinde SDK'ya KALICI
 * yazılmış `true`, manifest'teki `false` varsayılanını ezer ve bekleyen çökme
 * raporlarının gönderimi Activity açılmadan (arka plan başlangıcı dahil)
 * başlayabilirdi. Bu sağlayıcı daha yüksek initOrder ile önce çalışır ve
 * kullanıcı hata raporlarına açıkça `true` demediyse Crashlytics'in kendi
 * kalıcı ayarını (`com.google.firebase.crashlytics` /
 * `firebase_crashlytics_collection_enabled`) `false` yazar. Açma yalnız
 * Dart'ta (Ayarlar > Hata raporları) `setCrashlyticsCollectionEnabled(true)`.
 */
class ConsentInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        val context = context ?: return false
        try {
            val flutter = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val crash = if (flutter.contains("flutter.zankurd.crashReportsConsent")) {
                flutter.getBoolean("flutter.zankurd.crashReportsConsent", false)
            } else {
                flutter.getBoolean("flutter.zankurd.analyticsConsent", false)
            }
            if (!crash) {
                context.getSharedPreferences("com.google.firebase.crashlytics", Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("firebase_crashlytics_collection_enabled", false)
                    .commit()
            }
        } catch (_: Throwable) {
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
