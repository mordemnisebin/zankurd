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
    // 2026-08-14: `_offline.markLessonCompleted` yalnız bellek içi bir
    // kümeye ekliyor (SharedPreferences'a bile yazmıyor). Kullanıcı
    // "Ders tamamlandı" görüp çıkıyor, sunucudan okuyan
    // `loadCompletedLessonIds` dersi hâlâ tamamlanmamış gösteriyordu.
    'markLessonCompleted failed',
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

  /// Aynı kusurun `void` dönen kardeşi (2026-08-06 denetimi).
  ///
  /// `updateAvatarIdentity` bool döndürmüyor; başarısızlığı bildirmesinin
  /// tek yolu istisnayı geçirmek. Oysa BÜTÜN istisnaları yutuyordu ve
  /// `avatar_editor_screen._save()` bunu başarı sayıp `pop(true)` ile
  /// kapanıyordu.
  ///
  /// Somut kayıp: mağazadan 600 coine alınan Neon çerçevesi.
  /// `protect_paid_profile_cosmetics` `neon` değerini reddediyordu —
  /// temiz üretim klonunda üretildi: satın alma `success: true`, hemen
  /// ardından `ERROR: Invalid avatar frame`. İstisna burada yutulunca
  /// kullanıcı "kaydedildi" görüyordu. Üstelik `neon` seçili kaldığı
  /// sürece UPDATE'in tamamı iptal olduğu için avatar fotoğrafı, ikonu ve
  /// rengi de sessizce kaydedilemez oluyordu.
  ///
  /// Ayrım bilinçli: **sunucu reddi** (`PostgrestException`) kalıcıdır ve
  /// görünmelidir; ağ kaynaklı geçici hata sessiz kalır, çünkü yerel kopya
  /// zaten yazılmıştır ve çevrimdışı kullanım bozulmamalıdır.
  group('sunucu reddi yutulmuyor', () {
    // 2026-08-14: yazma mantığı `_pushAvatarIdentity` özel yardımcısına
    // taşındı — hem `updateAvatarIdentity` hem de `loadAvatarIdentity`nin
    // bekleyen-değişiklik tekrar deneme yolu onu paylaşır. Bekçi artık
    // metnin `updateAvatarIdentity` içinde iç içe olmasını değil, ortak
    // yardımcının kendisinin doğru davrandığını ve her iki çağıranın onu
    // gerçekten kullandığını ölçer.
    test('_pushAvatarIdentity PostgrestException geçiriyor', () {
      final at = repo.indexOf("reason: 'updateAvatarIdentity rejected'");
      expect(
        at,
        greaterThan(-1),
        reason:
            'Sunucu reddi ayrı yakalanmıyor; ödenen kozmetik yine sessizce '
            'kaybolur',
      );

      final tail = repo.substring(at, at + 400);
      expect(
        tail.substring(0, tail.indexOf('\n    }')),
        contains('rethrow;'),
        reason:
            'Ret çağırana ulaşmazsa ekran yine pop(true) ile başarı gibi '
            'kapanır',
      );

      // Yakalanan tür gerçekten PostgrestException olmalı: düz `catch`
      // yeniden fırlatılırsa çevrimdışı kayıt da hata verirdi.
      final methodStart = repo.indexOf(
        'Future<bool> _pushAvatarIdentity(',
      );
      expect(methodStart, greaterThan(-1));
      expect(
        repo.substring(methodStart, at),
        contains('on PostgrestException catch'),
        reason:
            'Ret düz `catch` ile yakalanıp fırlatılırsa çevrimdışı '
            'kayıt da hata verir',
      );
    });

    test('ağ hatasında çevrimdışı sessizlik korunuyor', () {
      final at = repo.indexOf("reason: 'updateAvatarIdentity failed'");
      expect(at, greaterThan(-1));
      final tail = repo.substring(at, at + 300);
      expect(
        tail.substring(0, tail.indexOf('\n    }')),
        isNot(contains('rethrow;')),
        reason:
            'Geçici ağ hatası da fırlatılırsa çevrimdışı avatar değişikliği '
            'her seferinde hata gösterir — düzeltme fazla geniş uygulanmış',
      );
    });

    test('updateAvatarIdentity ve loadAvatarIdentity ortak yolu kullanır', () {
      expect(
        repo,
        contains('await _pushAvatarIdentity(identity);'),
        reason: 'updateAvatarIdentity artık ortak yardımcıyı çağırmalı',
      );
      expect(
        repo,
        contains('await _pushAvatarIdentity(local);'),
        reason:
            'loadAvatarIdentity, bekleyen bir değişikliği okumadan önce '
            'tekrar göndermeyi denemeli — yoksa sunucudaki eski satır '
            'kullanıcının az önce kaydettiği değişikliği geri getirir',
      );
    });

    test('ekran reddi yerelleştirilmiş metinle gösteriyor', () {
      final editor = File(
        'lib/src/screens/avatar_editor_screen.dart',
      ).readAsStringSync();
      expect(editor, contains('K.saveFailed'));
      // Başarı yolu yalnız istisna ATILMADIĞINDA çalışır.
      expect(editor, contains('Navigator.of(context).pop(true)'));
    });
  });
}
