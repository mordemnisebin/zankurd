import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Elle yazılmış oda kodu, gösterilen koda birebir eşit olmak zorunda
/// değildir.
///
/// ## Kusur
///
/// Oda kodu kullanıcıya `ZK-ABCDEF0123` diye gösteriliyor. Katılma alanı ise
/// yalnızca `trim().toUpperCase()` yapıp RPC'ye gönderiyordu. Tireyi
/// atlayan (`zkabcdef0123`), araya boşluk koyan (`ZK ABCDEF0123`) ya da
/// yalnızca soneki yazan (`ABCDEF0123`) kullanıcı "Bu kodla oda bulunamadı"
/// görüyordu — oda açıkken ve kodu doğru okumuşken.
///
/// Ekranın altyazısı da "6 haneli oda kodu" diyordu. Tarihsel biçim 7,
/// güncel 40-bit biçim 13 karakter; bu ifade hiçbir sürümde doğru değildi.
///
/// Kusur test edilemiyordu çünkü hiçbir test insanın *yazacağı* biçimi
/// denemiyordu; hepsi `generateRoomCode`un çıktısını doğrudan geri
/// veriyordu. 2026-08-01'de iki gerçek cihaz arasında oda kurulup
/// katılınırken bulundu.
void main() {
  test('insanın yazabileceği her biçim kanonik koda çevrilir', () {
    for (final typed in [
      'ZK-ABCDEF0123',
      'zk-abcdef0123',
      'ZKABCDEF0123',
      'zkabcdef0123',
      'ZK ABCDEF0123',
      ' zk abcdef0123 ',
      'ABCDEF0123',
      'abcdef0123',
      'ZK–ABCDEF0123', // uzun tire: kopyala-yapıştırda oluşur
    ]) {
      expect(
        normalizeRoomCode(typed),
        'ZK-ABCDEF0123',
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
    expect(normalizeRoomCode('ZK-0O1IABCDEF'), 'ZK-0O1IABCDEF');
  });

  test('geçiş süresinde tarihsel dört karakterli lobiye katılım korunur', () {
    expect(isCanonicalRoomCode('ZK-X8WY'), isFalse);
    expect(isSupportedRoomCode('ZK-X8WY'), isTrue);
    expect(isSupportedRoomCode('x8wy'), isTrue);
    expect(isCanonicalRoomCode('ZK-ABCDEF0123'), isTrue);
    expect(isCanonicalRoomCode('zk-abcdef0123'), isFalse);
    expect(isCanonicalRoomCode('ABCDEF0123'), isFalse);
    expect(isSupportedRoomCode('zk-abcdef0123'), isTrue);
    expect(isSupportedRoomCode('ZK-ABCDEF0123'), isTrue);
    expect(isSupportedRoomCode('ZK-NOT-A-CODE'), isFalse);
  });

  test('ZK ile başlayan tarihsel sonek önek sanılıp kaybolmaz', () {
    expect(normalizeRoomCode('ZKAB'), 'ZK-ZKAB');
    expect(formatRoomCodeInput('ZKAB'), 'ZKAB');
    expect(isSupportedRoomCode('ZKAB'), isTrue);
    expect(normalizeRoomCode('ZK-ZKAB'), 'ZK-ZKAB');
    expect(formatRoomCodeInput('ZKX8WY'), 'ZK-X8WY');
  });

  test('fazla karakter başka bir oda koduna sessizce kesilmez', () {
    expect(formatRoomCodeInput('ZK-ABCDEF01234'), 'ZK-ABCDEF01234');
    expect(isCanonicalRoomCode('ZK-ABCDEF01234'), isFalse);
    expect(isSupportedRoomCode('ZK-ABCDEF01234'), isFalse);
  });

  test('katılma yolu normalleştiriciden geçer', () {
    // Bekçi kör kalmasın: fonksiyon var olup çağrılmazsa kusur geri gelir.
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(
      repository,
      contains("'p_code': normalizedCode"),
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
      reason: 'güncel kod 13 karakter; "6 haneli" hiçbir zaman doğru değildi',
    );
    expect(
      strings,
      isNot(contains('Koda odeyê ya 6 tîpî')),
      reason: 'Kurmancî altyazı da aynı yanlış uzunluğu söylüyordu',
    );
  });
}
