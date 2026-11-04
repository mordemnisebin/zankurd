// ignore_for_file: depend_on_referenced_packages
// R10 (GPT-6 Pro alan 5) yerel depolama, eşitleme ve hesap geçişi bekçileri.
//
// Her kusur SESSİZDİ: hiçbiri istisna fırlatmaz, ekranda hata göstermez.
//
// 1) A->B geçişinde göç / sahip anahtarı yazımı başarısız olunca `bind(B)`
//    atlanıyordu; B oturumu A'nın yerel kapsamını okuyup yazıyordu.
// 2) Genel anahtar göçünün hedef hesabı ancak SONUNDA kaydediliyordu; yarıda
//    kalan göçten sonra gelen B, kalan anahtarları alıp misafir ilerlemesini
//    iki hesaba bölüyordu.
// 3) Göç listesi bekleyen avatar değişikliğini ve rozet tarihlerini
//    kapsamıyordu; ilk göçü geçmiş kurulumlar için ikinci geçiş yoktu.
// 4) Misafir çıkışı `clearAll` çağırıyor, kayıtlı A'nın bekleyen tahsilat
//    makbuzlarını da siliyordu.
// 5) Hesap silme yalnız elle sıralı depoları temizliyordu; kelime listesi,
//    ders kümeleri, favoriler, sohbet susturma vb. kalıyordu.
// 6) Yaş beyanı cihaz geneliydi: A "13+" dedikten sonra B soru görmeden
//    sosyal yüzeye girebiliyordu.
// 7) Seri birleştirmesi `current`'ı yalnız son günü yeni olan cihazdan alıyor,
//    kesintisiz birleşmiş takvim 7 yerine 1 gösteriyordu.
// 8) Boyut ölçüsü karakter sayısıydı; sunucu jsonb metninin UTF-8 baytını sayar.
// 9) Ders `markSynced` bekleyeni önce siliyor, sonucu denetlemiyordu;
//    `cacheServer` eski yanıtla yeni tamamlamayı ezebiliyordu.
// 10) Tek bozuk günlük girdisi / bozuk `nextReview` bütün kurtarmayı / tekrar
//    planını durduruyordu.
// 11) Kelime yazımı reddedilince bellekte "kaydedildi" kalıyordu; tema /
//    hareket / süresiz mod yazımı da sonuç denetlemeden bellekte kalıyordu.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:zankurd_mobile/src/data/age_gate_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/lesson_completion_store.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/result_progress_journal.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';

class _FailingWriteStore extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAll() async => {};

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;

  @override
  Future<bool> remove(String key) async => true;
}

class _RejectingStorage extends InMemoryDataStorage {
  @override
  Future<bool> setString(String key, String value) async => false;
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-04T00:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    MistakeStore.resetInstance();
    WordListStore.resetInstance();
    AgeGate.debugSet(null);
  });

  tearDown(() {
    LocalProgressScope.debugReset();
    AgeGate.debugSet(AgeDeclaration.adult);
  });

  group('A->B geçişi kapalı başarısız olur', () {
    test('göç / sahip yazımı reddedilince B, A kapsamında KALMAZ', () async {
      LocalProgressScope.bind('user-a');
      SharedPreferencesStorePlatform.instance = _FailingWriteStore();
      SharedPreferences.resetStatic();
      final provider = AuthProvider.test();
      final ready = await provider.debugResetLocalProgressIfForeignUser(
        _user('user-b'),
      );
      expect(ready, isFalse);
      expect(
        LocalProgressScope.activeUserId,
        'user-b',
        reason: 'B oturumu A\'nın yerel alanını okuyup yazmamalı',
      );
    });
  });

  group('genel anahtar göçü', () {
    test(
      'göç niyeti kalıcıdır: yarım göçten sonra gelen B hedefi değiştirmez',
      () async {
        SharedPreferences.setMockInitialValues({
          LocalProgressScope.migratingKey: 'user-a',
          'zankurd.xp.total': 70,
          'zankurd.scope.user-a.zankurd.streak.current': 3,
        });
        final prefs = await SharedPreferences.getInstance();
        final ok = await LocalProgressScope.migrateLegacy(
          prefs,
          incomingUserId: 'user-b',
        );
        expect(ok, isTrue);
        expect(prefs.getInt('zankurd.scope.user-a.zankurd.xp.total'), 70);
        expect(prefs.getInt('zankurd.scope.user-b.zankurd.xp.total'), isNull);
        expect(prefs.getString(LocalProgressScope.migratedKey), 'user-a');
        expect(prefs.getString(LocalProgressScope.migratingKey), isNull);
      },
    );

    test(
      'avatar, bekleyen bayrak ve rozet tarihleri ikinci geçişle taşınır',
      () async {
        SharedPreferences.setMockInitialValues({
          LocalProgressScope.migratedKey: 'user-a',
          'zankurd.avatarIdentity': '{"icon_id":"roj"}',
          'zankurd.avatarIdentity.dirtyPending': true,
          'zankurd.badges.unlockedAt': '{"x":1}',
        });
        final prefs = await SharedPreferences.getInstance();
        expect(
          await LocalProgressScope.migrateLegacy(
            prefs,
            incomingUserId: 'user-b',
          ),
          isTrue,
        );
        expect(
          prefs.getString('zankurd.scope.user-a.zankurd.avatarIdentity'),
          '{"icon_id":"roj"}',
        );
        expect(
          prefs.getBool(
            'zankurd.scope.user-a.zankurd.avatarIdentity.dirtyPending',
          ),
          isTrue,
        );
        expect(prefs.containsKey('zankurd.avatarIdentity'), isFalse);
        expect(prefs.containsKey('zankurd.badges.unlockedAt'), isFalse);
      },
    );
  });

  group('hesap temizliği', () {
    test('sahipsiz çıkış kayıtlı hesabın makbuzunu SİLMEZ', () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_result_progress_receipt.user-a:room-1': 'x',
      });
      final prefs = await SharedPreferences.getInstance();
      LocalProgressScope.bind(LocalProgressScope.offlineUserId);
      await QuizResultProgressReceiptStore.clearForActiveUser(prefs);
      expect(
        prefs.containsKey('zankurd.quiz_result_progress_receipt.user-a:room-1'),
        isTrue,
      );
    });

    test('hesap silme yalnız silinen hesabın TÜM kayıtlarını siler', () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.scope.user-a.zankurd.wordList.v1': '{}',
        'zankurd.scope.user-a.zankurd.offline.syncedLessonIds': ['l1'],
        'zankurd.scope.user-a.zankurd.avatarIdentity.dirtyPending': true,
        'zankurd.scope.user-a.zankurd.offline.favoriteQuestionIds': ['q1'],
        'chat_muted_v1_user-a': ['p1'],
        'zankurd.quiz_result_progress_receipt.user-a:r': 'x',
        'zankurd.scope.user-b.zankurd.wordList.v1': '{"keep":1}',
        'chat_muted_v1_user-b': ['p2'],
      });
      final prefs = await SharedPreferences.getInstance();
      await LocalProgressScope.clearUserOwnedKeys(prefs, 'user-a');
      expect(
        prefs.getKeys().where((k) => k.contains('user-a')),
        isEmpty,
        reason: 'silinen hesabın hiçbir kaydı kalmamalı',
      );
      expect(
        prefs.getKeys(),
        contains('zankurd.scope.user-b.zankurd.wordList.v1'),
      );
      expect(prefs.getKeys(), contains('chat_muted_v1_user-b'));
    });
  });

  group('yaş beyanı hesaba bağlı', () {
    test('A\'nın yetişkin beyanı B\'ye geçmez; çocuk beyanı kalır', () async {
      await AgeGate.bindUser('user-a');
      await AgeGate.declare(AgeDeclaration.adult);
      await AgeGate.bindUser('user-a');
      expect(await AgeGate.load(), AgeDeclaration.adult);

      await AgeGate.bindUser('user-b');
      expect(AgeGate.declaration, isNull);
      expect(await AgeGate.load(), isNull);

      await AgeGate.declare(AgeDeclaration.minor);
      await AgeGate.bindUser('user-c');
      expect(await AgeGate.load(), AgeDeclaration.minor);
    });

    test('girişten önceki beyanı ilk görünen hesap devralır', () async {
      await AgeGate.bindUser(null);
      await AgeGate.declare(AgeDeclaration.adult);
      await AgeGate.bindUser('guest-1');
      expect(await AgeGate.load(), AgeDeclaration.adult);
    });
  });

  group('birleştirme ve boyut', () {
    test('kesintisiz birleşmiş oynama zinciri seriyi KISALTMAZ', () {
      final base = {'2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04'};
      final a = SnapshotStreak(
        current: 5,
        best: 5,
        lastDay: '2026-11-05',
        playedDays: {...base, '2026-11-05'},
      );
      final b = SnapshotStreak(
        current: 1,
        best: 4,
        lastDay: '2026-11-06',
        playedDays: {'2026-11-06'},
      );
      final merged = SnapshotStreak.merge(a, b);
      expect(merged.current, 6);
    });

    test('boyut jsonb metin gösteriminin UTF-8 baytıdır', () {
      expect(ProgressSnapshot.serverBytes({'a': 'ı'}), 11);
      expect(
        ProgressSnapshot.serverBytes({'a': 'ı'}),
        greaterThan(jsonEncode({'a': 'ı'}).length),
      );
    });
  });

  group('ders ve günlük', () {
    test(
      'markSynced eşitlenmişi yazar, bekleyeni düşer; cacheServer birleştirir',
      () async {
        LocalProgressScope.bind('user-a');
        expect(await LessonCompletionStore.addPending('l1'), isTrue);
        await LessonCompletionStore.markSynced('l1');
        expect(await LessonCompletionStore.loadLocal(), {'l1'});
        // Onaydan önce başlamış eski okuma geç döner: yeni tamamlama silinmez.
        await LessonCompletionStore.cacheServer(<String>{});
        expect(await LessonCompletionStore.loadLocal(), {'l1'});
      },
    );

    test(
      'bozuk günlük girdisi karantinaya alınır, sağlamlar kurtarılır',
      () async {
        SharedPreferences.setMockInitialValues({
          'ns.bad': '{not json',
          'ns.good': jsonEncode({
            'values': {'target.xp': 9},
            'result': {},
            'done': false,
          }),
        });
        final prefs = await SharedPreferences.getInstance();
        await ResultProgressJournal.recover(
          preferences: prefs,
          namespace: 'ns',
        );
        expect(prefs.getInt('target.xp'), 9);
        expect(prefs.containsKey('ns.bad'), isFalse);
        expect(prefs.getString('zankurd.quarantine.ns.bad'), '{not json');
      },
    );

    test('bozuk nextReview tekrar planını durdurmaz', () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.mistakeQuestionIds': ['q1'],
        'zankurd.mistakeMetadata': jsonEncode({
          'q1': {'nextReview': 'tomorrow'},
        }),
      });
      final store = await MistakeStore.load();
      expect(store.isReadyForReview('q1'), isTrue);
      expect(store.readyIdsMostOverdueFirst, ['q1']);
    });
  });

  group('yazım sonucu denetlenir', () {
    test('reddedilen kelime kaydı bellekte "kaydedildi" kalmaz', () async {
      final id = LearnerLexicon.entries.first.id;
      final store = await WordListStore.load(storage: _RejectingStorage());
      expect(await store.add(id), isFalse);
      expect(store.contains(id), isFalse);
      expect(await store.toggle(id), isFalse);
    });

    test('tema yazımı reddedilirse önceki temaya dönülür', () async {
      SharedPreferencesStorePlatform.instance = _FailingWriteStore();
      SharedPreferences.resetStatic();
      final provider = ThemeProvider(initialMode: ThemeMode.dark);
      await provider.setMode(ThemeMode.light);
      expect(provider.mode, ThemeMode.dark);
    });

    test('hareket azaltma yazımı reddedilirse önceki değere dönülür', () async {
      SharedPreferencesStorePlatform.instance = _FailingWriteStore();
      SharedPreferences.resetStatic();
      final provider = ReducedMotionProvider();
      await provider.setUserReduce(true);
      expect(provider.userReduce, isFalse);
    });
  });
}
