# Bildirim Entegrasyonu — Cihaz Adımları

Bu belge, push/yerel bildirimlerin gerçekten cihazda tetiklenmesi için kalan
adımları açıklar. Dart tarafındaki **zamanlama beyni hazır** ve test edilmiş
durumda; eksik olan native paket + platform yapılandırması.

## Şu an hazır olanlar (kod tarafı, test edilmiş)

- `NotificationService` — ayarlar (aç/kapat, saat), `SharedPreferences` ile kalıcı
- `NotificationService.nextFireTime({from})` — bir sonraki bildirim anını hesaplar (4 test)
- `NotificationService.nextFireAt` — hesaplanan an kalıcı saklanır; native katman bunu okur
- `supabase/add_fcm_token.sql` — `profiles.fcm_token` kolonu + `set_fcm_token` RPC

## Yerel bildirim (cihaz içi zamanlama) — `flutter_local_notifications`

1. **Paket ekle** (`pubspec.yaml`):
   ```yaml
   flutter_local_notifications: ^18.0.1
   timezone: ^0.9.4
   ```
2. **Android** (`android/app/src/main/AndroidManifest.xml`): `POST_NOTIFICATIONS`,
   `SCHEDULE_EXACT_ALARM` izinleri + receiver tanımı (paket README'sine göre).
3. **iOS** (`ios/Runner/AppDelegate.swift`): bildirim izni isteği.
4. **Bağlama**: `NotificationService._scheduleDaily()` içinde `nextFireAt`
   değerini `zonedSchedule(...)` ile işletim sistemine ver:
   ```dart
   await plugin.zonedSchedule(
     0,
     baslik,            // "Pêşbirka rojê li benda te ye!"
     govde,
     tz.TZDateTime.from(nextFireAt!, tz.local),
     details,
     matchDateTimeComponents: DateTimeComponents.time, // her gün tekrar
   );
   ```
5. **Build doğrulama**: `flutter build apk` (önce `TMP/TEMP=C:\src\tmp` ayarla).

## Uzaktan push (FCM) — `firebase_messaging`

1. **Paket ekle**: `firebase_messaging: ^15.2.4` (firebase_core zaten var).
2. **Migration uygula**: `supabase/add_fcm_token.sql` çalıştır.
3. **Token kaydı**: uygulama açılışında `FirebaseMessaging.instance.getToken()`
   → `repository` üzerinden `set_fcm_token` RPC'ye yaz.
4. **Sunucu tetikleyici**: Supabase Edge Function veya cron — günlük 09:00 quiz,
   20:00 streak uyarısı (bkz. yol planı Eksen 3c tablosu).
5. **Play Store**: bildirimler **opt-in** olmalı; açık kullanıcı onayı al.

## Neden bu turda native eklenmedi?

`flutter_local_notifications` ve `firebase_messaging` native yapılandırma
gerektirir ve APK build'i bu ortamda doğrulanamaz. Yanlış config kullanıcının
build'ini bozabileceği için, "hatasız" ilke gereği yalnızca tam doğrulanabilir
(analyze + test yeşil) Dart zamanlama mantığı + SQL migration teslim edildi.
