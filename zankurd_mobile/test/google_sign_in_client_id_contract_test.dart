import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';

/// iOS Google girişi aynı istemci kimliğinin üç ayrı yerde tutulmasına
/// dayanır ve üçü ayrı ayrı elle yazılır:
///
/// 1. `AppConfig.googleIosClientId` — SDK'ya `initialize` sırasında verilir.
/// 2. `ios/Runner/Info.plist` — Google'ın geri dönüş şeması, kimliğin
///    **ters çevrilmiş** hâli (`com.googleusercontent.apps.<kısım>`).
/// 3. `lib/firebase_options.dart` — Firebase yapılandırmasındaki
///    `iosClientId`.
///
/// ## Niçin bekçi gerekiyor
///
/// Üçü tutmazsa derleme geçer, testler geçer, uygulama açılır — ama Google
/// girişi *çalışma anında* sessizce kırılır: sağlayıcı ekranı açılır, giriş
/// tamamlanır, iOS uygulamayı geri çağıramaz. Tam olarak `Info.plist`teki
/// eksik `com.zankurd.app` şemasının 2026-07-27'de yarattığı kusurun aynısı;
/// o kusur da hiçbir testin bakmadığı bir yerde durduğu için aylarca yaşadı.
///
/// Bekçi kimliğin *değerini* sabitlemez (proje taşınabilir); üç kaynağın
/// birbiriyle **tutarlılığını** sabitler.
void main() {
  const suffix = '.apps.googleusercontent.com';

  test('iOS istemci kimliği Google formatındadır', () {
    expect(
      AppConfig.googleIosClientId,
      endsWith(suffix),
      reason: 'iOS istemci kimliği Google istemci kimliği biçiminde değil.',
    );
    expect(AppConfig.googleWebClientId, endsWith(suffix));
  });

  test(
    'Info.plist ters çevrilmiş iOS kimliğini geri dönüş şeması olarak taşır',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final reversed =
          'com.googleusercontent.apps.'
          '${AppConfig.googleIosClientId.replaceAll(suffix, '')}';

      expect(
        plist,
        contains('<string>$reversed</string>'),
        reason:
            'Info.plist\'teki Google geri dönüş şeması AppConfig\'teki iOS '
            'istemci kimliğiyle eşleşmiyor; iOS Google girişi sessizce kırılır.',
      );
    },
  );

  test('Firebase yapılandırması aynı iOS istemci kimliğini kullanır', () {
    final options = File('lib/firebase_options.dart').readAsStringSync();

    expect(
      options,
      contains(AppConfig.googleIosClientId),
      reason:
          'firebase_options.dart\'taki iosClientId AppConfig\'teki değerden '
          'ayrışmış.',
    );
  });

  // Uygulama içi native akış geri dönüş beklemez, ama parola sıfırlama ve
  // e-posta doğrulama hâlâ bu şemayla döner. 2026-07-27'de iOS tarafında hiç
  // kayıtlı olmadığı için düşmüştü.
  test('uygulamanın kendi geri dönüş şeması Info.plist\'te durur', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>com.zankurd.app</string>'));
  });
}
