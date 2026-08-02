import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sunucuya yazılamayan işlemler kullanıcıya "başarılı" diyordu
/// (2026-08-02 denetimi).
///
/// `SupabaseZanKurdRepository` hata yolunda `_offline`a düşüyor. Bu OKUMA
/// için doğru ve değerli bir karardır — ağ yokken soru/kategori göstermek
/// uygulamayı ayakta tutar. Ama bazı YAZMA çağrılarının mock karşılığı
/// gövdesizdi, düpedüz `return true`:
///
/// ```dart
/// Future<bool> addFriend(String friendId, String friendName) async {
///   return true;   // hiçbir şey saklanmıyor
/// }
/// ```
///
/// Sonuç: kullanıcı "istek gönderildi" görüyor, istek hiçbir zaman gitmiyor
/// ve hiçbir yere de kuyruklanmıyor. `SyncManager` yalnız quiz ödülünü
/// kuyruklar (`queueQuizReward`) ve depo ona hiç dokunmuyor — yani yeniden
/// deneme de yok. Kayıp sessiz ve kalıcı.
///
/// Arayüz zaten doğru yazılmıştı: `K.requestFailed`, `K.acceptFailed`,
/// `K.rejectFailed` metinleri vardı ama HİÇ GÖRÜNMÜYORDU, çünkü depo hep
/// `true` dönüyordu. Kusur arayüzde değil, deponun verdiği cevaptaydı.
///
/// Bu bekçi listeyi sabitler: aşağıdaki yazma çağrıları başarısızlıkta
/// mock'un sahte `true`suna düşemez.
void main() {
  late String repo;

  setUpAll(() {
    repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
  });

  /// Yerel karşılığı OLMAYAN, yalnız sunucuda anlamı olan yazımlar.
  ///
  /// Buraya bir ad eklemek "bu çağrı başarısız olduğunda kullanıcıya
  /// yalan söylenmemeli" demektir.
  const serverOnlyWrites = <String>[
    'addFriend failed',
    'acceptFriendRequest failed',
    'rejectFriendRequest failed',
    'saveTournamentProgress failed',
  ];

  for (final reason in serverOnlyWrites) {
    test('$reason — hata yolunda sahte başarı dönmüyor', () {
      final at = repo.indexOf("reason: '$reason'");
      expect(at, greaterThan(-1), reason: '$reason hata kaydı bulunamadı');

      // Hata kaydından sonraki catch kuyruğu: bir sonraki metoda kadar.
      final tail = repo.substring(at, at + 1400);
      final catchTail = tail.substring(0, tail.indexOf('\n  }'));

      expect(
        catchTail,
        isNot(contains('return _offline.')),
        reason:
            '$reason başarısızken _offline\'a düşüyor; mock karşılığı '
            'gövdesiz `return true` olduğu için kullanıcı sahte başarı '
            'görür ve işlem sessizce kaybolur',
      );
      expect(
        catchTail,
        contains('return false;'),
        reason: '$reason başarısızlığı çağırana bildirilmiyor',
      );
    });
  }

  test('okuma yollarındaki çevrimdışı geri düşüş KORUNUYOR', () {
    // Bu düzeltmenin fazla geniş uygulanması, uygulamayı ağ yokken
    // kullanılamaz hâle getirirdi. Çevrimdışı okuma değerli bir
    // özelliktir ve kalmalıdır.
    for (final read in [
      'loadAvatarIdentity failed',
      'loadTodayContest failed',
    ]) {
      final at = repo.indexOf("reason: '$read'");
      if (at < 0) continue;
      final tail = repo.substring(at, at + 800);
      expect(
        tail.substring(0, tail.indexOf('\n  }')),
        contains('_offline.'),
        reason:
            '$read için çevrimdışı geri düşüş kaldırılmış — düzeltme fazla '
            'geniş uygulanmış, çevrimdışı kullanım bozulur',
      );
    }
  });

  test('arayüz başarısızlığı gerçekten gösteriyor', () {
    final friends = File(
      'lib/src/screens/friends_screen.dart',
    ).readAsStringSync();
    for (final key in ['requestFailed', 'acceptFailed', 'rejectFailed']) {
      expect(
        friends,
        contains('K.$key'),
        reason:
            'depo artık false dönüyor ama arayüzde $key karşılığı yok; '
            'kullanıcı bu kez de sessiz bir hiçlik görür',
      );
    }
  });
}
