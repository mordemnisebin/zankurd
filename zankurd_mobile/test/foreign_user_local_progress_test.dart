import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

/// Sunucu tarafında bir oturumun yerini BAŞKA bir kullanıcı aldığında
/// yerel ilerleme (XP/streak/mistake/rozet/...) eski kullanıcıdan yeni
/// kullanıcıya sessizce devrediyordu.
///
/// ## Kusur
///
/// `XPStore` gibi yerel store'lar SharedPreferences'ta GLOBAL anahtarlarla
/// tutulur (`zankurd.xp.total`), kullanıcıya özel değil. `AuthProvider`ın
/// `onAuthStateChange` dinleyicisi yalnız `SyncManager.restart()`ı
/// tetikliyordu; hiçbir yerde "bu, ÖNCEKİ oturumdan farklı bir kullanıcı
/// mı?" sorusu sorulmuyordu. `signOut()` bu store'ları temizliyordu, ama
/// aktif bir oturumun üzerine `signInWithPassword` ile farklı bir hesaba
/// girildiğinde (GoTrue oturumu doğrudan değiştirir, ara bir `signedOut`
/// olayı hiç gelmez) `signOut()` hiç çağrılmıyordu. Paylaşılan bir
/// cihazda ikinci kullanıcı, birincinin XP'sini/serisini/rozetlerini
/// devralmış oluyordu (2026-08-14 denetimi).
///
/// ## Bekçinin tuttuğu üç şey
///
/// 1. Cihazın son sahibinden FARKLI bir kullanıcı kendi alanında 0 görür.
///    Eski hesabın anahtarı silinmez; o hesap geri dönünce durur.
/// 2. AYNI kullanıcının normal yeniden girişinde ilerleme SİLİNMEZ.
/// 3. Kayıtlı insan sahip yokken ilk gerçek kullanıcı genel anahtarı
///    devralır; ilerleme silinmez.
void main() {
  User user(String id) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-08-14T00:00:00Z',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    XPStore.resetInstance();
    BadgeService.resetInstance();
  });

  test(
    'cihazın önceki sahibinden farklı kullanıcı yerel XP\'yi temizler',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.localProgress.deviceOwnerUserId': 'user-old',
        'zankurd.xp.total': 500,
        'zankurd.badges.unlocked': <String>['perfect_game'],
      });
      final provider = AuthProvider.test();

      await provider.debugResetLocalProgressIfForeignUser(user('user-new'));

      XPStore.resetInstance();
      final xp = await XPStore.load();
      expect(xp.totalXP, 0, reason: 'önceki kullanıcının XP\'si devretmemeli');

      BadgeService.resetInstance();
      final badges = await BadgeService.load();
      expect(
        badges.unlockedBadges,
        isEmpty,
        reason: 'önceki kullanıcının rozetleri yeni hesaba devretmemeli',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.localProgress.deviceOwnerUserId'),
        'user-new',
      );
    },
  );

  test('aynı kullanıcının yeniden girişinde ilerleme SİLİNMEZ', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.localProgress.deviceOwnerUserId': 'user-a',
      'zankurd.xp.total': 500,
    });
    final provider = AuthProvider.test();

    await provider.debugResetLocalProgressIfForeignUser(user('user-a'));

    XPStore.resetInstance();
    final xp = await XPStore.load();
    expect(
      xp.totalXP,
      500,
      reason: 'aynı kullanıcının kendi ilerlemesi silinmemeli',
    );
  });

  test(
    'kayıtlı bir cihaz sahibi yokken (özellik yeni eklendi) mevcut ilerleme silinmez, yalnız sahip kaydedilir',
    () async {
      SharedPreferences.setMockInitialValues({'zankurd.xp.total': 500});
      final provider = AuthProvider.test();

      await provider.debugResetLocalProgressIfForeignUser(user('user-a'));

      XPStore.resetInstance();
      final xp = await XPStore.load();
      expect(
        xp.totalXP,
        500,
        reason:
            'zaten oturum açmış kullanıcının ilerlemesi ilk okumada silinmemeli',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.localProgress.deviceOwnerUserId'),
        'user-a',
      );
    },
  );

  test(
    'hesap değişince eski kullanıcının XP\'si silinmez ve geri dönünce durur',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.localProgress.deviceOwnerUserId': 'user-old',
        'zankurd.xp.total': 500,
      });
      final provider = AuthProvider.test();

      await provider.debugResetLocalProgressIfForeignUser(user('user-new'));
      XPStore.resetInstance();
      expect((await XPStore.load()).totalXP, 0);

      await provider.debugResetLocalProgressIfForeignUser(user('user-old'));
      XPStore.resetInstance();
      expect(
        (await XPStore.load()).totalXP,
        500,
        reason: 'eski hesabın XP\'si kendi alanında durmalı',
      );
    },
  );

  test('hedef ve makbuz da yabancı kullanıcıya devredilmez', () async {
    // 2026-09: `_clearLocalProgressStores` 11 store temizliyordu ama
    // öğrenme hedefi ve tur makbuzu listede yoktu — aynı cihazda
    // kullanıcı değişince hedef/makbuz sessizce devrediyordu.
    SharedPreferences.setMockInitialValues({
      'zankurd.localProgress.deviceOwnerUserId': 'user-old',
    });
    final prefs = await SharedPreferences.getInstance();

    final goalStore = await LearningGoalStore.load();
    await goalStore.save(LearningGoal.learnKurmanci);

    final receipts = QuizResultProgressReceiptStore(prefs);
    await receipts.write(
      userId: 'user-old',
      roomId: 'room-1',
      receipt: const QuizResultReceipt(
        stage: QuizResultReceiptStage.pendingUserDecision,
      ),
    );

    final provider = AuthProvider.test();
    await provider.debugResetLocalProgressIfForeignUser(user('user-new'));

    LearningGoalStore.resetInstance();
    final goal = await LearningGoalStore.load();
    expect(
      goal.goal,
      isNull,
      reason: 'önceki kullanıcının hedefi yeni hesaba devretmemeli',
    );

    final reread = await QuizResultProgressReceiptStore(
      prefs,
    ).read(userId: 'user-old', roomId: 'room-1');
    expect(
      reread?.stage,
      QuizResultReceiptStage.pendingUserDecision,
      reason: 'eski hesabın makbuzu diskte kalmalı',
    );
    final foreignRead = await QuizResultProgressReceiptStore(
      prefs,
    ).read(userId: 'user-new', roomId: 'room-1');
    expect(
      foreignRead,
      isNull,
      reason: 'önceki turun makbuzu yeni hesaba devretmemeli',
    );
  });

  test(
    'taşınma bittiyse sahipsiz çevrimdışı yazım genel anahtara dönmez',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalProgressScope.migratedKey: 'user-old',
      });
      final prefs = await SharedPreferences.getInstance();

      await LocalProgressScope.activateOffline(prefs);

      expect(LocalProgressScope.activeUserId, LocalProgressScope.offlineUserId);
      expect(
        LocalProgressScope.physical('zankurd.xp.total'),
        LocalProgressScope.physicalFor(
          LocalProgressScope.offlineUserId,
          'zankurd.xp.total',
        ),
      );
    },
  );

  test('çıkış yalnız aktif kullanıcının XP anahtarını siler', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'),
      40,
    );
    await prefs.setInt(
      LocalProgressScope.physicalFor('user-b', 'zankurd.xp.total'),
      70,
    );
    LocalProgressScope.bind('user-a');
    final provider = AuthProvider.test();

    await provider.signOut();

    expect(
      prefs.getInt(
        LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'),
      ),
      isNull,
    );
    expect(
      prefs.getInt(
        LocalProgressScope.physicalFor('user-b', 'zankurd.xp.total'),
      ),
      70,
    );
  });
}
