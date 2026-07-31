import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Göç dosyaları arasında sessiz üzerine yazma olmaz.
///
/// ## Kusur
///
/// `supabase/` hem tarihli (`2026-07-22_...sql`) hem tarihsiz
/// (`submit_answer_function.sql`) dosyalar taşıyor. Tarihli dosyalar
/// rakamla başladığı için alfabetik sıralamada başa, tarihsiz eski
/// dosyalar sona düşüyor.
///
/// Klasörü sırayla çalıştıran biri — ya da yeni bir kurulum — 2026-07-22
/// tarihli sertleştirilmiş `submit_answer` sürümünün ÜZERİNE tarihsiz eski
/// sürümü yazıyordu. Eski sürüm `set search_path` taşımıyor, doğru cevabı
/// doğrudan `questions`'tan okuyor ve sorunun o odaya ait olduğunu
/// doğrulamıyor. Yani bir sertleştirme, dosya adlandırmasından ötürü
/// sessizce geri alınabiliyordu (2026-07-31 denetimi).
///
/// Bu bekçi kuralı sabitler: **bir fonksiyon hem tarihli hem tarihsiz bir
/// dosyada tanımlıysa, tarihsiz olan aşılmıştır ve `archive/`e taşınmalıdır.**
void main() {
  final migrations = Directory('supabase')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList();

  bool isDated(File file) => RegExp(r'/\d{4}-\d{2}-\d{2}_').hasMatch(file.path);

  // `or replace` BİLEREK opsiyonel.
  //
  // İlk yazımda desen yalnız `create or replace function` arıyordu ve tam
  // bu yüzden `leaderboard_period_rpc.sql`i aşılmamış sandı:
  // `2026-07-29_release_readiness_hardening.sql` `get_leaderboard`ı
  // `drop function` + düz `create function` ile yeniden tanımlıyor
  // (imza değiştiği için `or replace` kullanılamaz). Bekçinin kendi kör
  // noktasıydı; 2026-08-01'de dört dosya arşive alınırken bulundu.
  Set<String> functionsIn(File file) => RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+public\.([a-z_0-9]+)',
    caseSensitive: false,
  ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toSet();

  test('göç klasörü boş değil', () {
    expect(migrations, isNotEmpty, reason: 'Bekçi kör kalmasın.');
    expect(migrations.any(isDated), isTrue);
  });

  test('aşılmış tarihsiz göçler arşive taşındı', () {
    final dated = <String>{};
    for (final file in migrations.where(isDated)) {
      dated.addAll(functionsIn(file));
    }

    final offenders = <String>[];
    for (final file in migrations.where((file) => !isDated(file))) {
      final overlap = functionsIn(file).intersection(dated);
      if (overlap.isEmpty) continue;
      offenders.add('${file.uri.pathSegments.last} → ${overlap.join(", ")}');
    }

    // 2026-08-01: liste BOŞALDI.
    //
    // Dört dosya "tek kaynak oldukları bir şey var" diye bekliyordu.
    // Desen düzeltilince (bkz. `functionsIn`) üçünün zaten tamamen aşılmış
    // olduğu görüldü; geriye yalnız iki gerçek benzersizlik kaldı ve ikisi
    // de çözüldü:
    //
    //   • `spin_wheel_history` tablosunu tarihli
    //     `2026-07-06_spin_wheel_backend.sql` de kuruyor.
    //   • `start_room_game` yalnız iki tarihsiz dosyada vardı; korumalı
    //     sürüm `2026-08-01_start_room_game_hardening.sql`e alındı.
    //
    // Bu liste YALNIZ KISALABİLİR. Yeni bir ad eklemek, aşılmış bir göçün
    // sessizce geri konulduğu anlamına gelir.
    const knownPending = <String>{};

    final unexpected = offenders
        .where((entry) => !knownPending.any(entry.startsWith))
        .toList();

    expect(
      unexpected,
      isEmpty,
      reason:
          'Tarihsiz bir göç, tarihli bir göçün tanımladığı fonksiyonu '
          'yeniden tanımlıyor. Alfabetik sırada tarihsiz olan SONRA gelir '
          've sertleştirmeyi sessizce geri alır. Dosyayı '
          'supabase/archive/ altına taşıyın:\n${unexpected.join("\n")}',
    );
  });

  test('arşiv klasörü niçinini belgeliyor', () {
    final readme = File('supabase/archive/README.md');
    expect(readme.existsSync(), isTrue);
    final text = readme.readAsStringSync();
    expect(text, contains('UYGULAMAYIN'));
    expect(
      text,
      contains('Uygulama sırası dosya adındaki tarihtir'),
      reason: 'Kural okunabilir yerde yazılı olmalı.',
    );
  });

  test('arşivlenen göçler artık ana klasörde değil', () {
    for (final gone in [
      'supabase/submit_answer_function.sql',
      'supabase/clamp_submit_answer_response_ms.sql',
    ]) {
      expect(
        File(gone).existsSync(),
        isFalse,
        reason: '$gone sertleştirilmiş submit_answer ı geri alıyordu.',
      );
    }
    expect(
      File('supabase/archive/submit_answer_function.sql').existsSync(),
      isTrue,
      reason: 'Tarihçe silinmedi, yalnız uygulama yolundan çıkarıldı.',
    );
  });

  test('sertleştirilmiş submit_answer search_path taşıyor', () {
    // Aşılmış sürümün ayırt edici eksiği buydu.
    final hardened = File(
      'supabase/2026-07-22_multiplayer_integrity_hardening.sql',
    ).readAsStringSync();
    expect(hardened, contains('set search_path'));
  });

  test('turnuva skoru sunucuda sınırlanıyor', () {
    // 2026-07-31 denetiminin tek kritik güvenlik bulgusu: istemcinin
    // bildirdiği skor üst sınırsız kabul ediliyordu, yani `p_score =
    // 2147483647` her maçı kazanıp sınırsız coin bastırıyordu.
    final file = File('supabase/2026-07-31_tournament_score_authority.sql');
    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();
    expect(
      source,
      contains('least(v_score'),
      reason: 'Skor tavanı yoksa coin basma yolu yeniden açılır.',
    );
    expect(source, contains('questions_per_match'));
    expect(
      source,
      contains('advance_tournament'),
      reason: 'Süresi dolan maç bir sonraki turu kurmazsa turnuva kilitlenir.',
    );
  });
}
