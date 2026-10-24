import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Seviye yalnız %60 doğruyla geçilir (2026-10-15).
///
/// ## Kusur
///
/// Seviye ekranı, quiz bir sonuç haritasıyla bittiği anda seviyeyi
/// "oynandı" yazıyordu: 0/10 bitiren oyuncu da altın yıldız alıyor ve bir
/// sonraki seviyenin kilidini açıyordu. Yol, ustalık yerine devam etme
/// düğmesine dönüşmüştü.
///
/// ## Niçin sessiz kaldı
///
/// Depo testleri "markPlayed kalıcı mı" diye bakıyordu, ekran testleri
/// quiz'e hiç girmiyordu; skorun işlendiği tek satır hiçbir testin yoluna
/// düşmüyordu.
///
/// ## Bekçi
///
/// Eşik depoda tek yerde durur; geçilmeyen tur yalnız "denendi" olur (yıldız
/// ve kilit açma yok); eşik öncesi kayıtlar geçilmiş kalır; ekran sonucu
/// `recordResult` ile işler, doğrudan `markPlayed` ile değil.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  test('eşik: 10 soruda 6 doğru geçer, 5 geçmez', () {
    expect(LevelProgressStore.passes(6, 10), isTrue);
    expect(LevelProgressStore.passes(5, 10), isFalse);
    expect(LevelProgressStore.passes(0, 10), isFalse);
    expect(LevelProgressStore.passes(3, 5), isTrue);
    expect(LevelProgressStore.passes(2, 5), isFalse);
  });

  test('geçilmeyen tur denendi yazılır, geçildi yazılmaz', () async {
    final store = await LevelProgressStore.load();
    final passed = await store.recordResult(
      'Ziman',
      'reziman',
      1,
      correct: 0,
      total: 10,
    );
    expect(passed, isFalse);
    expect(store.isPlayed('Ziman', 'reziman', 1), isFalse);
    expect(store.isAttempted('Ziman', 'reziman', 1), isTrue);
  });

  test('geçen tur seviyeyi açar', () async {
    final store = await LevelProgressStore.load();
    final passed = await store.recordResult(
      'Ziman',
      'reziman',
      1,
      correct: 7,
      total: 10,
    );
    expect(passed, isTrue);
    expect(store.isPlayed('Ziman', 'reziman', 1), isTrue);
  });

  test(
    'eşik öncesi kaydedilmiş seviye geçilmiş kalır, düşük tur onu almaz',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.level.played': <String>['Ziman|reziman|1'],
      });
      LevelProgressStore.resetInstance();
      final store = await LevelProgressStore.load();
      expect(store.isPlayed('Ziman', 'reziman', 1), isTrue);

      await store.recordResult('Ziman', 'reziman', 1, correct: 1, total: 10);

      expect(store.isPlayed('Ziman', 'reziman', 1), isTrue);
    },
  );

  test(
    'ekran sonucu recordResult ile işler ve geçilmedi iletisi iki dilde var',
    () {
      final source = File(
        'lib/src/screens/level_screen.dart',
      ).readAsStringSync();
      expect(source, contains('recordResult('));
      expect(source, isNot(contains('store.markPlayed(')));
      for (final language in AppLanguage.values) {
        final text = Tr.of(K.levelNotPassed, language, {'p0': '60'});
        expect(text, contains('60'));
        expect(text, isNot(contains('{p0}')));
      }
      expect(
        Tr.of(K.levelNotPassed, AppLanguage.ku, {'p0': '60'}),
        isNot(matches(RegExp('[ığöü]'))),
      );
    },
  );
}
