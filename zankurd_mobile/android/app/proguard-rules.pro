# ZanKurd — R8/ProGuard keep kuralları (release minify için)
# Flutter'ın kendi kuralları AGP tarafından otomatik uygulanır; buradakiler
# reflection/plugin sınıflarının yanlışlıkla silinmesini önler.

# ── Flutter çekirdek ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Firebase / Crashlytics / Analytics ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# Crashlytics stack trace çözümlemesi için satır bilgisini koru
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# ── RevenueCat (purchases_flutter) ──
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ── flutter_local_notifications (Gson + zamanlanmış bildirimler) ──
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Credential Manager / Google ile giriş (google_sign_in 7) ──
# google_sign_in 7 Android'de androidx.credentials üzerinden çalışır;
# oynatma servisi sağlayıcıları reflection ile yüklenir, R8 bunları
# "kullanılmıyor" sanıp silerse release derlemesinde giriş sessizce
# çalışmaz (debug'da çalışır). Android belgelerinin önerdiği kural.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
# Flutter'ın Play Core (deferred components) başvuruları; kullanmıyoruz.
-dontwarn com.google.android.play.core.**

# ── Supabase / OkHttp / Ktor (ağ katmanı) ──
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn io.ktor.**
-dontwarn kotlinx.**

# ── flutter_tts ──
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.fluttertts.**

# ── Genel: enum values() reflection ──
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
