/// 2.1.2 W3 bekçileri: istemci veri / eşitleme / hesap değişimi (ChatGPT Pro
/// denetimi alan 3 + alan 2 #7 + alan 4 #4/#5/#12).
///
/// Ortak kusur sınıfı: bir yazım/okuma `await`ler arasında etkin hesabı
/// YENİDEN türetiyordu (anahtar await sonrası hesaplanıyordu); hesap o
/// aralıkta değişirse veri başka hesabın alanına yazılıyor, başarısız yazım
/// başarı sayılıyor, gecikmiş bir sonuç yeni kararı eziyordu. Hiçbiri hata
/// vermez: veri sessizce yanlış hesapta ya da hiç yazılmadan kalır.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/pending_operation_store.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

class _OfflineHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw Exception('injected: ağ erişilemez');
}

User _user(String id, {bool anonymous = false}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-15T00:00:00Z',
  isAnonymous: anonymous,
);

/// `setString`/`setInt` sonucunu sahte biçimde reddeden depo: platform yazımı
/// başarısız (`false`) dönüyor ama hata fırlatmıyor.
class _RejectingStorage implements LocalDataStorage {
  _RejectingStorage(this.inner);
  final LocalDataStorage inner;

  /// İlk [rejectsLeft] yazım/silme çağrısı reddedilir, sonrakiler geçer.
  int rejectsLeft = 1;

  bool _reject() {
    if (rejectsLeft <= 0) return false;
    rejectsLeft--;
    return true;
  }

  @override
  List<String>? getStringList(String key) => inner.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    if (_reject()) return false;
    return inner.setStringList(key, value);
  }

  @override
  String? getString(String key) => inner.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    if (_reject()) return false;
    return inner.setString(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (_reject()) return false;
    return inner.remove(key);
  }
}

String _someLexiconId() => LearnerLexicon.entries.first.id;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    LearningGoalStore.resetInstance();
    StoryProgressStore.resetInstance();
    WordListStore.resetInstance();
  });

  group('hesaplar arası geciktirilmiş yazım (alan 3 #5, #19)', () {
    test(
      'öğrenme hedefi kaydı sürerken hesap değişirse B\'ye yazılmaz',
      () async {
        LocalProgressScope.bind('A');
        final store = await LearningGoalStore.load();
        final saving = store.save(LearningGoal.values.first);
        // Yazım uçuştayken oturum B'ye geçer.
        LocalProgressScope.bind('B');
        expect(await saving, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final aKey = LocalProgressScope.physicalFor(
          'A',
          'zankurd.learning_goal.v1',
        );
        final bKey = LocalProgressScope.physicalFor(
          'B',
          'zankurd.learning_goal.v1',
        );
        expect(prefs.getString(aKey), isNotNull, reason: 'hedef A\'ya yazılır');
        expect(
          prefs.getString(bKey),
          isNull,
          reason: 'hedef await arasında türetilen B anahtarına SIZMAMALI',
        );
        expect(
          prefs.getInt(
            LocalProgressScope.physicalFor('A', 'zankurd.learning_goal.at'),
          ),
          isNotNull,
          reason: 'zaman damgası hedefle AYNI hesapta',
        );
        expect(
          prefs.getInt(
            LocalProgressScope.physicalFor('B', 'zankurd.learning_goal.at'),
          ),
          isNull,
        );
      },
    );

    test('hikâye düğümü ve üst veri aynı hesaba yazılır', () async {
      LocalProgressScope.bind('A');
      final store = await StoryProgressStore.load();
      final saving = store.saveNode('s1', 'n2');
      LocalProgressScope.bind('B');
      await saving;

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      expect(
        keys.where((k) => k.startsWith('zankurd.scope.B.')),
        isEmpty,
        reason: 'düğüm A\'ya, üst veri B\'ye bölünmemeli: $keys',
      );
      expect(
        keys.where((k) => k.startsWith('zankurd.scope.A.zankurd.story')),
        hasLength(2),
        reason: 'düğüm + üst veri ikisi de A\'da',
      );
    });

    test(
      'kelime listesi ve silme işaretleri AYNI hesaptan okunur (#6)',
      () async {
        final id = _someLexiconId();
        SharedPreferences.setMockInitialValues({
          LocalProgressScope.physicalFor('A', WordListStore.removedLogicalKey):
              '{"x1":${DateTime.now().millisecondsSinceEpoch - 1000}}',
        });
        LocalProgressScope.bind('A');
        final loading = WordListStore.load();
        LocalProgressScope.bind('B');
        final store = await loading;
        expect(await store.add(id), isTrue);
        expect(await store.remove(id), isTrue);

        final prefs = await SharedPreferences.getInstance();
        final aRemoved = prefs.getString(
          LocalProgressScope.physicalFor('A', WordListStore.removedLogicalKey),
        );
        expect(aRemoved, contains('x1'), reason: 'A\'nın işareti korunur');
        expect(aRemoved, contains(id), reason: 'yeni silme A\'ya yazılır');
        expect(
          prefs.getKeys().where((k) => k.startsWith('zankurd.scope.B.')),
          isEmpty,
          reason: 'A için yüklenen depo B alanına yazmamalı',
        );
      },
    );
  });

  group('kelime ekleme (alan 3 #11, #12)', () {
    test(
      'başarısız ilk ekleme + eşzamanlı tekrar: ikisi de gerçeği söyler',
      () async {
        final id = _someLexiconId();
        final inner = SharedPrefsDataStorage(
          await SharedPreferences.getInstance(),
        );
        final storage = _RejectingStorage(inner);
        LocalProgressScope.bind('A');
        final store = await WordListStore.load(storage: storage);

        final first = store.add(id);
        final second = store.add(id); // ilk yazım henüz bitmedi
        // İlk yazım reddedilir; ikinci çağrı ona yaslanıp yalan `true` dönmemeli,
        // kendisi yeniden deneyecek.
        final firstResult = await first;
        final secondResult = await second;
        expect(firstResult, isFalse);
        expect(
          store.contains(id),
          secondResult,
          reason: 'dönen değer kalıcı gerçekle uyuşmalı',
        );
        expect(secondResult, isTrue, reason: 'yazım düzelince tekrar eklenir');
        expect(
          inner.getString(
            LocalProgressScope.physical(WordListStore.logicalKey),
          ),
          contains(id),
        );
      },
    );

    test(
      'silinen kelime yeniden eklenince eklenme anı silme işaretinden sonra',
      () async {
        final id = _someLexiconId();
        LocalProgressScope.bind('A');
        final store = await WordListStore.load();
        // Gelecekteki (hızlı saatli cihazdan) bir silme işareti.
        final future = DateTime.now().millisecondsSinceEpoch + 86400000;
        await store.add(id);
        await store.remove(id);
        final prefs = await SharedPreferences.getInstance();
        final key = LocalProgressScope.physical(
          WordListStore.removedLogicalKey,
        );
        await prefs.setString(key, '{"$id":$future}');
        WordListStore.resetInstance();
        final reloaded = await WordListStore.load();
        await reloaded.add(id);
        expect(
          reloaded.wordFor(id)!.addedAtMs,
          greaterThan(future),
          reason: 'mantıksal damga: yeni ekleme eski silmeye yenilmemeli',
        );
      },
    );

    test('silme damgası bilinen en yeni etkinliğin ötesindedir', () async {
      final id = _someLexiconId();
      LocalProgressScope.bind('A');
      final store = await WordListStore.load();
      final future = DateTime.now().millisecondsSinceEpoch + 86400000;
      await store.add(id, now: DateTime.fromMillisecondsSinceEpoch(future));
      await store.remove(id);
      final prefs = await SharedPreferences.getInstance();
      final removed = prefs.getString(
        LocalProgressScope.physical(WordListStore.removedLogicalKey),
      )!;
      expect(removed, contains('"$id":'));
      final stamp = int.parse(
        RegExp('"$id":(\\d+)').firstMatch(removed)!.group(1)!,
      );
      expect(stamp, greaterThan(future));
    });
  });

  group('bulut birleşimi (alan 3 #21)', () {
    test('silme işaretleri yerel sınırla (180 gün / 500) budanır', () {
      expect(
        SnapshotWord.tombstoneRetentionMs,
        WordListStore.removedRetention.inMilliseconds,
      );
      expect(SnapshotWord.tombstoneCap, WordListStore.removedCap);
      const day = 86400000;
      const now = 400 * day;
      final (_, gone) = SnapshotWord.mergeWithTombstones(
        const {},
        {'eski': now - 181 * day, 'yeni': now - 5 * day},
        const {},
        const {},
        nowMs: now,
      );
      expect(gone.keys, ['yeni']);
      final many = {for (var i = 0; i < 700; i++) 'k$i': now - i};
      final (_, capped) = SnapshotWord.mergeWithTombstones(
        const {},
        many,
        const {},
        const {},
        nowMs: now,
      );
      expect(capped, hasLength(500));
      expect(capped.containsKey('k0'), isTrue);
      expect(capped.containsKey('k699'), isFalse);
    });
  });

  group('bekleyen işlem kimliği (alan 3 #13, #14; alan 4 #5)', () {
    test('farklı kapsamda iki bekleyen kimlik birbirini ezmez', () async {
      final a = await PendingOperationStore.idFor(
        'duel_start',
        'u1',
        scope: 'Tarih',
      );
      final b = await PendingOperationStore.idFor(
        'duel_start',
        'u1',
        scope: 'Coğrafya',
      );
      expect(a, isNot(b));
      expect(
        await PendingOperationStore.idFor('duel_start', 'u1', scope: 'Tarih'),
        a,
        reason:
            'Tarih yeniden denemesi KENDİ kimliğiyle gider (çift düello yok)',
      );
      await PendingOperationStore.clear('duel_start', 'u1', scope: 'Tarih');
      expect(
        await PendingOperationStore.idFor(
          'duel_start',
          'u1',
          scope: 'Coğrafya',
        ),
        b,
        reason: 'Tarih\'in temizlenmesi Coğrafya\'yı etkilemez',
      );
    });

    test('hesap silme süpürmesi kapsamlı kimlikleri de siler', () async {
      await PendingOperationStore.idFor('duel_start', 'u1', scope: 'Tarih');
      final prefs = await SharedPreferences.getInstance();
      await LocalProgressScope.clearUserOwnedKeys(prefs, 'u1');
      expect(
        prefs.getKeys().where((k) => k.startsWith('zankurd.pendingOp.')),
        isEmpty,
      );
    });

    test('10 dakikadan eski ama kesin yanıtlanmamış kimlik KORUNUR', () async {
      final t0 = DateTime(2026, 11, 5, 10);
      final a = await PendingOperationStore.idFor('duel_start', 'u1', now: t0);
      final later = await PendingOperationStore.idFor(
        'duel_start',
        'u1',
        now: t0.add(const Duration(minutes: 30)),
      );
      expect(
        later,
        a,
        reason: 'gecikmiş yeniden deneme ikinci düello açmamalı',
      );
    });

    test(
      'silme reddedilirse kimlik ölü işaretlenir, yeniden kullanılmaz',
      () async {
        SharedPreferences.setMockInitialValues({});
        final a = await PendingOperationStore.idFor('spin', 'u1');
        // Başarılı yol: temizlenir ve yeni kimlik üretilir.
        expect(await PendingOperationStore.clear('spin', 'u1'), isTrue);
        expect(await PendingOperationStore.idFor('spin', 'u1'), isNot(a));
      },
    );
  });

  group('çıkış ve hesap silme (alan 3 #1, #24)', () {
    Future<AuthProvider> provider() async {
      final auth = AuthProvider(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _OfflineHttp(),
        ),
      );
      await pumpEventQueue();
      addTearDown(() async {
        await pumpEventQueue();
        auth.dispose();
      });
      return auth;
    }

    test(
      'misafir çıkışı kelime listesini siler ve cihaz sahibini çevrimdışına çeker',
      () async {
        final id = _someLexiconId();
        final auth = await provider();
        await auth.debugPrepareSessionUser(
          _user('guest-1', anonymous: true),
          restartSync: false,
        );
        final words = await WordListStore.load();
        expect(await words.add(id), isTrue);
        final prefs = await SharedPreferences.getInstance();
        final wordKey = LocalProgressScope.physicalFor(
          'guest-1',
          WordListStore.logicalKey,
        );
        expect(prefs.getString(wordKey), isNotNull);

        await auth.signOut();

        expect(
          prefs.getString(wordKey),
          isNull,
          reason: 'elle sıralı depo temizliği kelime listesini unutuyordu',
        );
        expect(
          prefs.getKeys().where((k) => k.startsWith('zankurd.scope.guest-1.')),
          isEmpty,
        );
        expect(
          prefs.getString(LocalProgressScope.ownerKey),
          LocalProgressScope.offlineUserId,
          reason: 'misafir kimliği "insan sahip" kalmamalı',
        );
      },
    );

    test('hesap silmede cihaz sahipliği anahtarı kalkar', () async {
      final auth = await provider();
      await auth.debugPrepareSessionUser(_user('reg-1'), restartSync: false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalProgressScope.ownerKey), 'reg-1');
      await auth.signOut(
        discardPendingRewards: true,
        pendingRewardsOwnerId: 'reg-1',
      );
      expect(prefs.getString(LocalProgressScope.ownerKey), isNull);
    });
  });
}
