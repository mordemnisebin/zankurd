import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lobideki yedek yoklama, ikinci oyuncu görülünce kapanmaz.
///
/// ## Kusur
///
/// Oda ekranı realtime'a güvenmiyor, yanına 3 saniyelik bir yoklama
/// koyuyor. Ama yoklamayı durduran koşul şuydu:
///
///     if (playerCount >= 2) { _pausePolling(); return; }
///
/// Niyet yorumda yazıyordu: "Realtime yetersizse host, 2. oyuncuyu
/// polling ile görür." Yani yedek yalnız KATILIMI görmek için
/// tasarlanmıştı ve katılan görülür görülmez kalıcı olarak kapanıyordu.
///
/// Lobide değişen tek şey katılım değil. Hazır durumu da değişiyor ve tam
/// olarak katılımdan SONRA:
///
///   1. `join_room_by_code` oyuncuyu `is_ready = false` ile ekler,
///   2. ev sahibi bu INSERT'i görür → oyuncu sayısı 2 → yoklama kapanır,
///   3. katılan hemen ardından kendi durumunu `set_room_ready(true)` ile
///      bildirir,
///   4. ev sahibi bunu artık yalnız realtime UPDATE ile görebilir.
///
/// `room_players` üzerindeki UPDATE olayları aboneye ulaşmıyordu
/// (bkz. [room_realtime_replica_identity_test]), yani ev sahibi ikinci
/// oyuncuyu sonsuza dek "Li bendê" görüyordu — ekran "Rewşa te di odê de
/// rasterast ji lîstikvanên din re tê nîşandan" diye vaat ederken.
///
/// Kusur tek cihazda görünmüyor: ev sahibi kendi durumunu zaten yerel
/// olarak biliyor. 2026-08-01'de Android ev sahibi ile iOS katılan
/// arasında bulundu; realtime düzeltmesi uygulandıktan SONRA da sürdüğü
/// için kökün burada olduğu anlaşıldı.
///
/// ## Kural
///
/// Yoklama lobide açık kalır; onu durduran tek şey yarışın başlamasıdır
/// (`quizOpened`) ya da açıkça işaretlenmiş pil kısıtıdır.
void main() {
  late String code;

  setUpAll(() {
    code = File('lib/src/screens/room_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');
  });

  test('oyuncu sayısı yoklamayı durdurmuyor', () {
    expect(
      code,
      isNot(contains('if (playerCount >= 2) { _pausePolling();')),
      reason:
          'Yoklama ikinci oyuncu görülünce kapanırsa ev sahibi onun hazır '
          'olduğunu hiç göremez.',
    );
  });

  test('yoklamayı durduran tek koşul yarışın başlaması', () {
    expect(
      code,
      contains(
        'void _syncPollingForLobby(int playerCount) { '
        'if (quizOpened) { _pausePolling(); return; }',
      ),
      reason: 'Lobide yoklama sürmeli.',
    );
  });

  test('pil kısıtı açık bir bayrakla korunuyor', () {
    // Kısıt `_pollTimer`ı null yapıyor; `_syncPollingForLobby` de null
    // gördüğü an yeniden başlatıyor. Bayrak olmadan kısıt ilk gelen
    // realtime olayında geri açılır ve hiç uygulanmaz.
    expect(code, contains('bool _pollThrottled = false;'));
    expect(code, contains('if (_pollTimer == null && !_pollThrottled)'));
    expect(code, contains('_pollThrottled = true; _pausePolling();'));
    expect(
      code,
      contains('_pollThrottled = false;'),
      reason:
          'Kısıt süresi dolunca bayrak inmeli, yoksa yoklama bir daha '
          'hiç başlamaz.',
    );
  });

  test('yarış başlayınca yoklama gerçekten duruyor', () {
    // Kısıt bitince yeniden başlatan gecikmeli geri çağrı, o sırada
    // yarış açılmışsa yoklamayı diriltmemeli.
    expect(code, contains('if (!quizOpened) _startPolling();'));
  });
}
