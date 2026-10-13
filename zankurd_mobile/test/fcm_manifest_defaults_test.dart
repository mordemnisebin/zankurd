import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';

/// Arka plandaki FCM iletisinin küçük simge, renk ve kanalı manifestten gelir.
///
/// ## Kusur
///
/// Uygulama arka plandayken `notification` yüklü FCM iletisini Dart değil
/// sistem çizer ve varsayılanları `AndroidManifest.xml`deki üç `meta-data`dan
/// okur. Bunlar yoktu: simge başlatıcı simgesine düşüp bildirimde düz beyaz
/// kare çıkıyor, renk atanmıyor, kanal da "Miscellaneous" yedeğine düşüyordu.
///
/// ## Niçin sessizdi
///
/// Ön plan ve yerel bildirimler kendi simge/renk/kanallarını kodda veriyordu;
/// yalnız arka plan push'u manifeste bakar ve o yol hiçbir testte (ve emülatör
/// dışında hiçbir yerde) sürülmüyor. Yükleme hata vermez, yalnız çirkin görünür.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('manifest FCM varsayılan simge, renk ve kanalını tanımlar', () {
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_color'),
    );
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_channel_id'),
    );
  });

  test('simge ve renk kaynakları gerçekten var', () {
    expect(manifest, contains('@drawable/ic_stat_zankurd'));
    expect(manifest, contains('@color/zk_notification_color'));
    expect(
      File(
        'android/app/src/main/res/drawable-mdpi/ic_stat_zankurd.png',
      ).existsSync(),
      isTrue,
    );
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    expect(colors, contains('name="zk_notification_color"'));
  });

  test('manifestteki kanal kimliği uygulamanın başlangıçta açtığı kanaldır', () {
    expect(
      manifest,
      contains(
        'android:name="com.google.firebase.messaging.default_notification_channel_id"\n'
        '            android:value="${NotificationService.pushChannelId}"',
      ),
    );
    final service = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();
    expect(service, contains('createNotificationChannel('));
  });

  test('R8 kuralları Credential Manager sağlayıcılarını korur', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('-if class androidx.credentials.CredentialManager'));
    expect(
      rules,
      contains('-keep class androidx.credentials.playservices.** { *; }'),
    );
    expect(
      rules,
      contains(
        '-keep class com.google.android.libraries.identity.googleid.** { *; }',
      ),
    );
    expect(rules, contains('-dontwarn com.google.android.play.core.**'));
  });
}
