import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-08-14 denetimi: eski bir bulgu listesi "kapıda girilen ad bir
/// sonraki ekrana taşınmıyor" diyordu. Kodu okumak akışı doğru gösteriyordu
/// (`_save()` `updateProfileName`i `await` ettikten SONRA `onCompleted`i
/// çağırıyor) ama statik okuma gerçek zamanlama/veri akışını KANITLAMAZ —
/// bu yüzden burada uçtan uca doğrulandı: kapıda ad girilip kaydedilir,
/// AYNI depo instance'ıyla açılan `HomeScreen` başlıkta YENİ adı (eski
/// varsayılan adı DEĞİL) gösteriyor mu kontrol edilir.
///
/// Sonuç: KUSUR YOK, iddia doğrulanmadı — bu test bunu kalıcı olarak
/// sabitler (bir regresyon bekçisi, bir düzeltme değil).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kapıda girilen ad, hemen ardından açılan ana ekrana geçer', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    var completed = false;

    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: repository,
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Rojîn',
    );
    await tester.tap(find.text('Oyuna başla'));
    // `pumpAndSettle` yerine sınırlı bir `pump`: gerçek uygulamada
    // `onCompleted` AppShell'i yeniden çizip bu ekranı ağaçtan söker,
    // bu yüzden `_saving` durumu (ve onun döngüsel yükleme animasyonu)
    // hiç yerleşmeye fırsat bulmaz. Bu izole testte ekran BİLEREK
    // mount'ta kalıyor (henüz HomeScreen'e geçmedik) — `pumpAndSettle`
    // o yüzden hiç bitmeyen bir animasyonda sonsuza dek bekler.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(completed, isTrue);
    // Depo YAZILDI mı — kapının kendi sözleşmesi.
    expect(await repository.getProfileName(), 'Rojîn');

    // Kapı kapanınca AppShell'in yaptığı şeyin aynısı: HomeScreen AYNI
    // depo instance'ıyla açılır. Ad hemen görünmeli, "ZanKurd Oyuncusu"
    // değil.
    await tester.pumpWidget(
      testShell(child: HomeScreen(repository: repository)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Rojîn'), findsOneWidget);
    expect(find.textContaining('ZanKurd Oyuncusu'), findsNothing);
  });
}
