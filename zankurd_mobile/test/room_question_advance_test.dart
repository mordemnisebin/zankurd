import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RLS'nin koruduğu tabloya doğrudan yazan istemci kodu, hatayı yutar.
///
/// ## Kusur
///
/// Oda maçında 1. sorudan sonraki hiçbir cevap sunucuya kaydedilmiyordu.
/// Her cevapta "Cevap gönderilemedi. Lütfen tekrar dene." çıkıyor, tekrar
/// denemek de işe yaramıyordu; on soruluk maçın dokuzu boşa gidiyordu.
///
/// Sebep üç dosyanın kesişimindeydi ve hiçbiri tek başına yanlış değildi:
///
///   1. `2026-07-22` göçü `"Hosts can update their own rooms"` politikasını
///      kaldırdı — ev sahibi `rooms` satırını serbestçe yazamamalı.
///   2. `2026-07-29` göçü `player_answers` üzerine, cevabın soru indeksinin
///      `rooms.current_question_index` ile eşleşmesini şart koşan bir
///      tetikleyici koydu — ileri sorunun cevabı önceden gönderilememeli.
///   3. `quiz_screen.dart` sorudan soruya geçerken hâlâ
///      `client.from('rooms').update(...)` yapıyordu.
///
/// 1. madde 3.'yü engelliyor ama **hata vermiyor**: PostgREST'te `select`
/// istenmeyen bir `update`, RLS yüzünden sıfır satır eşleşse bile 204
/// döner. İstemci ilerlettiğini sanıyor, indeks 0'da kalıyor, 2. sorudan
/// sonraki her cevabı 2. maddedeki tetikleyici reddediyor.
///
/// 2026-08-01'de Android ev sahibi ile iOS katılan arasında gerçek bir oda
/// maçı oynanırken bulundu. Tek cihazda görünmez: oda maçı iki oyuncusuz
/// başlamıyor.
///
/// ## Kural
///
/// Çok oyunculu durum değişiklikleri tablo yazımıyla değil RPC ile
/// yapılır. RPC yetkisizlikte hata döndürür; sessiz başarı kusuru aynı
/// biçimde geri gelemez.
void main() {
  late String quizScreen;
  late String supabaseRepository;

  setUpAll(() {
    quizScreen = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    supabaseRepository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
  });

  test('soru ilerletme RPC ile yapılıyor', () {
    final quizCollapsed = quizScreen.replaceAll(RegExp(r'\s+'), ' ');
    final repositoryCollapsed = supabaseRepository.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    expect(
      quizCollapsed,
      contains('widget.repository.advanceRoomQuestion('),
      reason: 'Ekran durum yazımını depo sözleşmesine devretmeli.',
    );
    expect(
      repositoryCollapsed,
      contains("client.rpc( 'advance_room_question'"),
      reason: 'İlerletme sunucu yetkisiyle çalışan bir fonksiyona ait.',
    );
  });

  test('istemci artık rooms tablosuna doğrudan yazmıyor', () {
    // Yorumlar kusuru ismen anlatıyor; kural koda bakmalı.
    final code = quizScreen
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(
      code,
      isNot(contains(".from('rooms') .update(")),
      reason:
          'RLS bu yazımı sessizce yutuyordu; ilerletme RPC üzerinden '
          'gitmeli.',
    );
    expect(
      code,
      isNot(contains("current_question_index': nextIndex")),
      reason: 'Eski, sessizce başarısız olan yazım geri gelmiş.',
    );
  });

  test('göç fonksiyonu oda üyeliği ve expected-index CAS ile sınırlı', () {
    final migration = File(
      'supabase/2026-08-02_multiplayer_session_hardening.sql',
    ).readAsStringSync();

    expect(migration, contains('function public.advance_room_question'));
    expect(
      migration,
      contains('security definer'),
      reason:
          'Ev sahibi `rooms` üzerinde geniş yazma hakkı kazanmamalı; '
          'yalnız tek sütun tek yönde değişmeli.',
    );
    expect(
      migration,
      contains('set search_path = public'),
      reason: 'Tanımlayıcı yetkili fonksiyon çağıranın arama yolunu almamalı.',
    );
    expect(migration, contains('p_expected_question_index integer'));
    expect(migration, contains('join public.room_players rp'));
    expect(
      migration,
      contains('rp.player_id = v_uid'),
      reason: 'İlerletme oda üyesiyle sınırlı olmalı.',
    );
    expect(
      migration,
      isNot(contains('and r.host_id = v_uid')),
      reason: 'Host-only advance, guest failover CAS sözleşmesini bozar.',
    );
    expect(
      migration,
      contains("and r.status = 'active'"),
      reason: 'Bitmiş ya da lobideki oda ilerletilememeli.',
    );
    expect(
      migration,
      contains('for update of r'),
      reason:
          'Oda satırı kilidi olmadan iki istemcinin CAS tekrarları yarışabilir.',
    );
    expect(
      migration,
      contains(
        'coalesce(r.current_question_index, 0) = p_expected_question_index',
      ),
      reason: 'İlerletme beklenen indeksle atomik CAS yapmalı.',
    );
    expect(
      migration,
      contains(
        'revoke all on function public.advance_room_question(uuid, integer)',
      ),
    );
  });

  test('hiçbir istemci dosyası korunan oda tablolarına doğrudan yazmıyor', () {
    // Deseni genelleştir: `rooms` ve `room_players` üzerindeki yazma
    // politikaları bilerek kaldırıldı. Bu tablolara doğrudan `update`
    // eden her satır aynı sessiz başarıyı yeniden üretir.
    final offenders = <String>[];
    final pattern = RegExp(
      r"\.from\(\s*'(rooms|room_players)'\s*\)\s*\.update\(",
      dotAll: true,
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final code = entity
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (pattern.hasMatch(code)) offenders.add(entity.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosya(lar) RLS korumalı bir oda tablosuna doğrudan yazıyor; '
          'engellenirse hata almadan sessizce başarısız olur:\n'
          '${offenders.join("\n")}',
    );
  });
}
