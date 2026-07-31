import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Elle yazılmış oda kodu, gösterilen koda birebir eşit olmak zorunda
/// değildir.
///
/// ## Kusur
///
/// Oda kodu kullanıcıya `ZK-X8WY` diye gösteriliyor. Katılma alanı ise
/// yalnızca `trim().toUpperCase()` yapıp RPC'ye gönderiyordu. Tireyi
/// atlayan (`zkx8wy`), araya boşluk koyan (`ZK X8WY`) ya da yalnızca son
/// dört karakteri yazan (`X8WY`) kullanıcı "Bu kodla oda bulunamadı"
/// görüyordu — oda açıkken ve kodu doğru okumuşken.
///
/// Ekranın altyazısı da yanlıştı: "6 haneli oda kodu" diyordu, oysa kod
/// `ZK-` öneki + 4 karakter, yani 7 karakter. Kullanıcıyı en baştan yanlış
/// uzunlukta bir şey aramaya itiyordu.
///
/// Kusur test edilemiyordu çünkü hiçbir test insanın *yazacağı* biçimi
/// denemiyordu; hepsi `generateRoomCode`un çıktısını doğrudan geri
/// veriyordu. 2026-08-01'de iki gerçek cihaz arasında oda kurulup
/// katılınırken bulundu.
void main() {
  test('insanın yazabileceği her biçim kanonik koda çevrilir', () {
    for (final typed in [
      'ZK-X8WY',
      'zk-x8wy',
      'ZKX8WY',
      'zkx8wy',
      'ZK X8WY',
      ' zk x8wy ',
      'X8WY',
      'x8wy',
      'ZK–X8WY', // uzun tire: kopyala-yapıştırda oluşur
    ]) {
      expect(
        normalizeRoomCode(typed),
        'ZK-X8WY',
        reason: '"$typed" yazan kullanıcı odayı bulamıyor',
      );
    }
  });

  test('üretilen kod normalleştirmeden geçince değişmez', () {
    // Kanonik biçim sabit noktadır; yoksa biçimlendirici alanı her tuşta
    // yeniden yazar ve imleç zıplar.
    for (var i = 0; i < 200; i++) {
      final code = generateRoomCode();
      expect(normalizeRoomCode(code), code);
    }
  });

  test('boş girdi öneki tek başına döndürmez', () {
    // 'ZK-' göndermek RPC'ye anlamsız bir sorgu atar; boş kalmalı ki
    // form doğrulaması devreye girsin.
    for (final blank in ['', '   ', '-', 'ZK', 'zk', 'ZK-', '!!!']) {
      expect(normalizeRoomCode(blank), '');
    }
  });

  test('karakter tahmini yapılmaz', () {
    // `0`ı `O`, `1`i `I` yapmak cazip ama yanlış: üretim alfabesi bu
    // ikilileri hiç kullanmadığı için düzeltilecek bir şey yok, ama
    // düzeltme yapılırsa kullanıcı başkasının odasına düşebilir.
    expect(normalizeRoomCode('ZK-0O1I'), 'ZK-0O1I');
  });

  test('katılma yolu normalleştiriciden geçer', () {
    // Bekçi kör kalmasın: fonksiyon var olup çağrılmazsa kusur geri gelir.
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(
      repository,
      contains("'p_code': normalizeRoomCode(code)"),
      reason: 'joinOnlineRoom ham kodu göndermemeli',
    );
    expect(
      repository,
      isNot(contains("'p_code': code.trim().toUpperCase()")),
      reason: 'eski, normalleştirmeyen hâl geri gelmiş',
    );

    final playHub = File(
      'lib/src/screens/play_hub_screen.dart',
    ).readAsStringSync();
    expect(
      playHub,
      contains('_RoomCodeInputFormatter'),
      reason: 'alan yazarken kanonik biçimi göstermeli',
    );
  });

  test('altyazı kodun gerçek biçimini anlatır', () {
    final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
    expect(
      strings,
      isNot(contains('6 haneli oda kodu')),
      reason: 'kod 7 karakter; "6 haneli" hiçbir zaman doğru değildi',
    );
    expect(
      strings,
      isNot(contains('Koda odeyê ya 6 tîpî')),
      reason: 'Kurmancî altyazı da aynı yanlış uzunluğu söylüyordu',
    );
  });
}
