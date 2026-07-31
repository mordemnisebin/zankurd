import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/player.dart';

/// "Hazırım" anahtarı sunucunun bildiğini gösterir, kendi varsayımını değil.
///
/// ## Kusur
///
/// `room_screen.dart` odaya giren herkes için `bool ready = true` ile
/// başlıyordu. Ev sahibinde bu doğruydu — `createOnlineRoom`, oyuncuyu
/// `is_ready: true` ile ekliyor. Ama `join_room_by_code` katılanı
/// `is_ready = false` ile ekliyor. Sonuç, katılan oyuncu için:
///
///   * kendi ekranında "Hazırım" anahtarı AÇIK,
///   * oyuncu listesinde kendi satırında "Bekliyor",
///   * ev sahibinde yarış başlatılamıyor,
///   * ve çıkış yolu (anahtarı kapatıp yeniden açmak) hiçbir yerde yazmıyor.
///
/// Kusur tek cihazda hiç görünmüyor: oda kuran kişi uyuşmazlığı yaşamıyor,
/// ve testlerin hiçbiri ikinci bir istemciyle katılmıyordu. 2026-08-01'de
/// Android emülatöründen oda kurulup iOS simülatöründen katılınca bulundu.
///
/// ## Düzeltme iki taraflı
///
/// 1. Ekran artık gerçeği okuyor: elle dokunulmadıysa anahtar, oyuncunun
///    sunucudaki satırından besleniyor.
/// 2. Katılma yolu varsayılanı sunucuya bildiriyor, böylece katılan da ev
///    sahibi gibi hazır başlıyor — ekranla veritabanı aynı şeyi söylüyor.
void main() {
  test('hazır durumu tek bir sabitle karşılaştırılıyor', () {
    // Durum serbest bir gösterim dizesi olduğu için ('Bot', 'Cevapladı',
    // '—' de olabilir) hazırlık bilgisi bu dizenin bir değeri. Yazım iki
    // dosyada ayrı ayrı duruyorsa biri değişince diğeri sessizce yanlış
    // cevap verir.
    expect(Player.readyState, 'Hazır');

    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(
      repository,
      isNot(contains("state: ready ? 'Hazır'")),
      reason: 'Depo kendi dizesini yazmamalı, sabiti kullanmalı.',
    );
    expect(repository, contains('Player.readyState'));
  });

  test('anahtar koşulsuz açık başlamıyor', () {
    final screen = File(
      'lib/src/screens/room_screen.dart',
    ).readAsStringSync();
    // Yorumlar kararın *niçin*ini anlatırken eski hâli ismen anıyor;
    // kural koda bakmalı, yoksa bekçi kendi açıklamasına takılır.
    final code = screen
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code,
      isNot(contains('bool ready = true')),
      reason:
          'Sabit varsayılan, katılan oyuncuda sunucuyla çelişiyordu; '
          'durum oyuncunun kendi satırından okunmalı.',
    );
    final collapsed = code.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      collapsed,
      contains('me.state == Player.readyState'),
      reason: 'Anahtar sunucudaki gerçek durumdan beslenmeli.',
    );
    expect(
      collapsed,
      contains('_readyOverride'),
      reason:
          'Kullanıcı elle dokunduğunda dediği geçmeli; yoksa gelen her '
          'akış güncellemesi seçimini geri alır.',
    );
  });

  test('katılan oyuncu varsayılan durumunu sunucuya bildiriyor', () {
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final join = repository.substring(
      repository.indexOf('Future<GameRoom> joinOnlineRoom'),
    );
    final body = join.substring(0, join.indexOf('\n  @override'));
    expect(
      body,
      contains('updateReady(joined, true)'),
      reason:
          'Aksi hâlde katılan, ekranın gösterdiğinin tersine sunucuda '
          'hazır değil.',
    );
    expect(
      body,
      contains('joinOnlineRoom ready sync failed'),
      reason:
          'Bildirim düşerse oda yine açılmalı; sessiz yutulmamalı ama '
          'katılmayı da engellememeli.',
    );
  });
}
