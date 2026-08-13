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
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
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

  test('oda ekranı açılışta durumu sunucuya geri yazmıyor', () {
    // `initState` bir zamanlar `updateReady(room, ready)` çağırıyordu ve
    // `ready` sabit `true` olduğu sürece zararsızdı. `ready` sunucudan
    // beslenmeye başlayınca aynı satır kendi kuyruğunu ısırdı: ekran
    // açıldığında `room.players` hâlâ katılış anındaki listedir, orada
    // katılan `is_ready = false`, yani çağrı `joinOnlineRoom`un yazdığı
    // `true`yu hemen siliyordu.
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final initState = screen.substring(
      screen.indexOf('void initState()'),
      screen.indexOf('void _startSubscriptions()'),
    );
    expect(
      initState.replaceAll(RegExp(r'//[^\n]*'), ''),
      isNot(contains('updateReady(')),
      reason:
          'Açılışta yazma, giriş yolunun yazdığı durumu eziyor; ev sahibi '
          'katılanı hep "Li bendê" görür.',
    );
  });

  test('katılma yolu hazır durumunu kendiliğinden açmıyor', () {
    // ## Kararın değiştiği yer
    //
    // 2026-08-01'de bu bekçi TERSİNİ tutuyordu: `joinOnlineRoom`
    // `updateReady(joined, true)` çağırmalıydı. O gün çözülen sorun
    // gerçekti — ekran anahtarı açık gösterirken sunucu "hazır değil"
    // diyordu — ama iki ayrı çare aynı anda uygulanmıştı: (1) ekranın
    // gerçeği okuması, (2) sunucuya zorla `true` yazılması. Uyuşmazlığı
    // çözen (1)'di; (2) ayrı ve istenmeyen bir davranış getirdi.
    //
    // 2026-08-13 iki cihazlı denetiminde uygulama sahibi bildirdi: odaya
    // sonradan giren oyuncu "Hazırım"a HİÇ dokunmadan hazır sayılıyor ve
    // ev sahibi, öteki daha ekranı okumadan yarışı başlatabiliyor.
    // "Hazırım" bir onaydır; onayı katılan kişi verir.
    //
    // 2026-08-01'in asıl kazanımı yukarıdaki testlerde duruyor ve
    // dokunulmadı: anahtar hâlâ sunucudaki satırdan besleniyor,
    // `initState` hâlâ durumu geri yazmıyor. Eski kilitlenme (açık anahtar
    // + "Bekliyor" satırı) bu yüzden geri gelemez.
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final join = repository.substring(
      repository.indexOf('Future<GameRoom> joinOnlineRoom'),
    );
    final body = join
        .substring(0, join.indexOf('\n  @override'))
        .replaceAll(RegExp(r'//[^\n]*'), '');
    expect(
      body,
      isNot(contains('updateReady(')),
      reason:
          'Katılma yolu hazır durumunu sunucuya yazıyor. Bu, odaya yeni '
          'giren oyuncuyu onayı olmadan hazır sayar ve ev sahibi yarışı '
          'o daha ekranı görmeden başlatabilir.',
    );
  });

  test('ev sahibi ile katılan farklı varsayılanla başlıyor', () {
    // Kırpışmanın önü bu satırla kesiliyor: liste henüz gelmemişken anahtar
    // koşulsuz `true` derse, katılanın ekranı bir an "hazır" gösterip sonra
    // kapanır — hazır olmadığı hâlde hazır sandıran bir an. Varsayılan role
    // bağlı olmalı.
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final code = screen
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(
      code,
      contains('if (me == null) return _isHost;'),
      reason:
          'Liste gelmeden önceki varsayılan role bağlı olmalı: odayı kuran '
          'hazır, katılan değil.',
    );
  });

  test('başlatma kapısı hem sayıyı hem hazırlığı arıyor', () {
    // Sunucu da aynı iki koşulu uygular (`start_room_game`: "Exactly two
    // players are required" ve "All players must be ready"). İstemcideki
    // kapı sunucununkiyle aynı kalmalı, yoksa oyuncu etkin görünen bir
    // düğmeye basıp sunucudan hata yer.
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final code = screen.replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('room.players.length >= 2 && allPlayersReady'));
  });

  test('kapalı düğmenin sebebi ekranda yazıyor', () {
    // Katılan artık hazır başlamadığı için ev sahibi bir süre kapalı düğme
    // görecek. Sebebi yazılmazsa bu, 2026-08-01'de şikâyet edilen "çıkış
    // yolu hiçbir yerde yazmıyor" durumunun ev sahibi tarafına taşınmış
    // hâli olur.
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final code = screen.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      code,
      contains('room.players.length >= 2 && !allPlayersReady'),
      reason: 'Bekleme durumu ayrıca hesaplanmalı ki mesaj gösterilebilsin.',
    );
    expect(
      code,
      contains('ready ? K.waitingOpponentReady : K.tapReadyToStart'),
      reason:
          'Mesaj role göre değişmeli: hazır olmayan kişiye ne yapacağı, '
          'ötekine niçin beklediği söylenmeli.',
    );
  });
}
