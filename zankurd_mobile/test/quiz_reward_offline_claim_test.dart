import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Sunucu 0 verdi" ile "sunucuya ulaşılamadı" aynı şey değildir.
///
/// ## Kusur
///
/// Tur bitince coin `awardQuizCoins` ile isteniyor. Eskiden yalnız dönen
/// miktara bakılıyordu:
///
///     if (amount <= 0) { ...kuyruğa al, "çevrimdışı" göster... }
///
/// Sunucu düşük skora meşru olarak 0 coin verdiğinde — 10 soruda 2 doğru
/// gibi — sonuç ekranı "Bağlantı yok — ödülün kaydedildi, bağlanınca
/// verilecek." yazıyordu. Bağlantı vardı ve tur zaten sunucuda işlenmişti.
///
/// İki ayrı zarar:
///
///   1. Kullanıcıya yanlış tanı konuyor — ödülünü alamadığını, suçlunun
///      da interneti olduğunu sanıyor.
///   2. Aynı tur `SyncManager` kuyruğuna giriyor. Senkron çalışınca aynı
///      tur için ikinci kez ödül isteniyor.
///
/// Kusur testte görünmüyordu çünkü testlerdeki sahte depo hep pozitif
/// miktar döndürüyordu; 0 dönen yol hiç koşulmamıştı. 2026-08-01'de iki
/// cihazlı canlı bir oda maçının sonuç ekranında bulundu.
///
/// ## Kural
///
/// Kuyruğa alma ve "çevrimdışı" mesajı YALNIZ çağrı fırlatınca devreye
/// girer. Başarılı bir çağrının döndürdüğü 0, gerçek bir cevaptır.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
  });

  test('kuyruk yalnız çağrı başarısız olunca devreye giriyor', () {
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');

    expect(
      code,
      contains('var awardFailed = false;'),
      reason: 'Başarısızlık, miktardan ayrı izlenmeli.',
    );
    expect(
      code,
      contains('awardFailed = true;'),
      reason: 'catch bloğu bayrağı kaldırmalı.',
    );
    expect(
      code,
      contains('if (awardFailed) {'),
      reason: 'Kuyruk kararı bayrağa bakmalı.',
    );
    expect(
      code,
      isNot(contains('if (amount <= 0) {')),
      reason:
          'Miktara bakan eski koşul geri gelmiş: sunucunun meşru 0 yanıtı '
          'yeniden "çevrimdışı" sayılır ve tur ikinci kez kuyruğa girer.',
    );
  });

  test('başarısızlık sessizce yutulmuyor', () {
    expect(
      source,
      contains("reason: 'awardQuizCoins failed'"),
      reason:
          'Gerçek bir başarısızlık çökme raporuna düşmezse kuyruk niçin '
          'doldu hiç anlaşılmaz.',
    );
  });

  test('_rewardQueued yalnız kuyruk gerçekten dolunca doğru', () {
    // Sonuç ekranındaki "bağlanınca verilecek" satırı bu bayrağa bakıyor.
    final code = source.replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('_rewardQueued = true;'));
    final persistedQueue = code.indexOf('await sync.queueQuizReward(');
    final successFlag = persistedQueue < 0
        ? -1
        : code.indexOf('_rewardQueued = true;', persistedQueue);
    expect(
      persistedQueue,
      greaterThanOrEqualTo(0),
      reason: 'Sonuç ekranı gösterilmeden önce kuyruk diske yazılmalı.',
    );
    expect(
      successFlag,
      greaterThan(persistedQueue),
      reason: 'Bayrak yalnız kalıcı kuyruk yazımı başarıyla bitince açılmalı.',
    );
    expect(
      code,
      contains('_rewardQueued = false;'),
      reason: 'queueQuizReward fırlatırsa bayrak geri alınmalı.',
    );
  });

  test('claim sırasında değişen hesap adına kuyruk yazılmaz', () {
    final code = source.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      code,
      contains(
        "final rewardOwnerId = widget.repository.currentUserId?.trim() ?? '';",
      ),
      reason: 'Ödül isteği başındaki kullanıcı kimliği sabitlenmeli.',
    );
    expect(
      code,
      contains('currentOwnerId != rewardOwnerId'),
      reason: 'Kuyruk yazımından önce aynı kullanıcının kaldığı doğrulanmalı.',
    );
  });
}
