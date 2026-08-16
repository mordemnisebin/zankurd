import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ekran turu (`tool/screenshots/screen_tour_test.dart`) gerçekten *bütün*
/// ekranları bassın ve dosya adları çakışmasın.
///
/// ## Kusur
///
/// Tur 76 kare üretiyordu ve `CLAUDE.md` onu "bütün ana ekranlar" diye tarif
/// ediyordu. 2026-08-16 taramasında dördü hiç açılmıyordu: `AppShell` (alt
/// gezinme çubuğunu gösteren tek yüzey), `LearnHomeScreen`,
/// `PasswordRecoveryScreen` ve `RoomResultRecoveryScreen`. Ayrıca iki numara
/// iki kez verilmişti — `71_favorites`/`71_splash` ve
/// `72_image_credits`/`72_splash_dark` — yani klasördeki sıra, turun sırasını
/// artık anlatmıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Tur bir `flutter test` dosyası; geçmesi "76 kare yazıldı" demek, "hiçbir
/// ekran atlanmadı" demek değil. Eksikliği ancak `lib/src/screens/` ile
/// turdaki listeyi elle karşılaştıran biri görebilirdi ve kimse görmedi.
/// Bu bekçi o karşılaştırmayı otomatik yapar: yeni bir ekran eklendiğinde
/// tura girmeden testler kırmızıya döner.
String _screenClassName(String fileName) {
  return fileName
      .replaceAll('.dart', '')
      .split('_')
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

void main() {
  final tour = File(
    'tool/screenshots/screen_tour_test.dart',
  ).readAsStringSync();

  test('her ekran turda en az bir kez açılır', () {
    // Alt klasörler (`screens/quiz/`, `screens/home/`, `screens/profile/`)
    // ekran değil, ekranların parçalarıdır; turda kendi başlarına açılmazlar.
    final screens =
        Directory('lib/src/screens')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .where((name) => name.endsWith('.dart'))
            .toList()
          ..sort();

    final missing = screens
        .where((file) => !tour.contains(_screenClassName(file)))
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'Bu ekranlar turda hiç açılmıyor, yani görünüşleri hiç '
          'ölçülmüyor: ${missing.join(', ')}',
    );
  });

  test('iki kare aynı numarayı taşımaz', () {
    final names = RegExp(
      r"_shoot\(\s*t\s*,\s*'([^']+)'",
    ).allMatches(tour).map((match) => match.group(1)!).toList();

    expect(names, isNotEmpty, reason: 'Turdan hiç kare adı okunamadı.');

    final byPrefix = <String, List<String>>{};
    for (final name in names) {
      final prefix = name.split('_').first;
      byPrefix.putIfAbsent(prefix, () => []).add(name);
    }

    final collisions = byPrefix.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}: ${entry.value.join(' / ')}')
        .toList();

    expect(
      collisions,
      isEmpty,
      reason:
          'Aynı numarayı taşıyan kareler klasörde yan yana düşüp turun '
          'sırasını bozuyor: ${collisions.join('; ')}',
    );
  });

  test('kare adları benzersizdir', () {
    final names = RegExp(
      r"_shoot\(\s*t\s*,\s*'([^']+)'",
    ).allMatches(tour).map((match) => match.group(1)!).toList();

    expect(
      names.toSet().length,
      names.length,
      reason: 'Aynı ada iki kez basılırsa ikinci kare birincisini eziyor.',
    );
  });

  // Ürünün ASIL dili Kurmancî — temiz kurulumda uygulama Kurmancî açılıyor.
  // Tur ise neredeyse tamamen Türkçe basıyordu; eklenen ilk Kurmancî karesi
  // anında bir kırpma kusuru buldu (joker etiketleri). Kurmancî metinler
  // Türkçeden düzenli olarak uzun, yani taşma önce orada görünür.
  test('düzeni zorlayan karelerin Kurmancî ikizi var', () {
    for (final shot in [
      '_competition_question_ku',
      '_lesson_answered_ku',
      '_sign_in_ku',
      '_name_gate_ku',
      '_settings_ku_dark',
    ]) {
      expect(
        tour,
        contains(shot),
        reason:
            'Kurmancî ikizi «$shot» turdan düşmüş; kırpma kusurları önce '
            'Kurmancî\'de görünür.',
      );
    }
  });

  // Soru anı ürünün kalbi; turun onu yalnız tek bir hâlde basması, geri
  // bildirimin yarısını ölçüsüz bırakıyordu.
  test('soru anı doğru, yanlış ve Kurmancî hâlleriyle basılır', () {
    for (final shot in [
      '_lesson_answered',
      '_lesson_wrong_answer',
      '_competition_question_ku',
    ]) {
      expect(
        tour,
        contains(shot),
        reason: 'Soru anının «$shot» hâli turdan düşmüş.',
      );
    }
  });
}
