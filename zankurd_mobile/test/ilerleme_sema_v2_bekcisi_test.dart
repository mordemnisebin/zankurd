/// 2.1.2 veri güvenliği: ilerleme anlık görüntüsü şema sürümü 2.
///
/// Kusurlar (GPT-6 Pro ALAN 5, 2026-11-04) ve niçin sessiz kaldıkları:
///
/// 1. SERİ DONDURMA BAKİYESİ MUTLAK SAYIYDI. İki cihaz aynı sıfır bakiyeden
///    birer jeton satın alınca her ikisi de yerelde `1` yazıyor, bulutta "son
///    damga kazanır" kuralı `1` bırakıyordu: iki ödeme, tek jeton. Tek cihazlı
///    her test (ve elle deneme) geçiyordu; kusur ancak iki cihazın ÇAKIŞAN
///    alımında görünür. Şimdi bakiye cihaz defteridir (`FreezeLedger`).
/// 2. `words` SÜRÜM ARTMADAN EKLENDİ. Alanı bilmeyen v1 istemci bütün görüntüyü
///    yeniden yazıp kelime yedeğini silebilirdi; sunucu yeniyi eskinin ezmesini
///    reddetmiyordu. Sürüm 2'ye çıktı; v1 istemci v2 kaydı ayrıştırmaz (ne
///    birleştirir ne yazar), sunucu tarafı `tool/test_ilerleme_sema_v3_local.mjs`.
/// 3. ÖĞRENME HEDEFİNDE YEREL HER ZAMAN KAZANIYORDU, KELİME SİLME YAYILMIYORDU.
///    Eski hedefi taşıyan cihaz öbür cihazın yeni seçimini geri alıyor; bir
///    cihazda silinen kelime eski cihazın kopyasıyla diriliyordu. Tek cihazda
///    ikisi de doğru görünür.
/// 4. SUNUCU BOYUT REDDİ BÜTÜN YEDEĞİ DURDURUYORDU. Tek büyük yanlış defteri,
///    seri/rozet/kelime yedeğini de engelliyordu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/freeze_ledger.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';

class _Remote implements ProgressRemote {
  _Remote({this.row, this.tooLargeFirst = false});

  RemoteProgress? row;
  bool tooLargeFirst;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<RemoteProgress?> fetch() async => row;

  @override
  Future<bool> save(
    Map<String, dynamic> snapshot, {
    DateTime? expectedUpdatedAt,
  }) async {
    if (tooLargeFirst) {
      tooLargeFirst = false;
      throw const ProgressTooLarge(300000);
    }
    saved.add(snapshot);
    row = RemoteProgress(snapshot: snapshot, updatedAt: DateTime.now());
    return true;
  }
}

Future<ProgressSnapshot> _device(String id, Future<void> Function() act) async {
  SharedPreferences.setMockInitialValues({FreezeLedger.deviceKey: id});
  LocalProgressScope.debugReset();
  LocalProgressScope.bind('user-a');
  StreakStore.resetInstance();
  FreezeLedger.debugReset();
  await act();
  return LocalProgressSnapshot.read(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. seri dondurma bakiyesi: cihaz defteri', () {
    test('KUSUR (v1 mutlak sayı): iki alım tek jeton bırakırdı', () {
      // Defter öncesi kayıtlar hâlâ bu kuralla birleşir; kusurun kendisi.
      const a = SnapshotStreak(freeze: 1, freezeAt: 1000);
      const b = SnapshotStreak(freeze: 1, freezeAt: 2000);
      expect(SnapshotStreak.merge(a, b).freeze, 1);
    });

    test('iki cihaz birer jeton satın alınca ikisi de görünür', () async {
      final a = await _device('dev-a', () async {
        expect(await (await StreakStore.load()).addFreeze(), 1);
      });
      final b = await _device('dev-b', () async {
        expect(await (await StreakStore.load()).addFreeze(), 1);
      });
      expect(SnapshotStreak.merge(a.streak, b.streak).freeze, 2);
      expect(SnapshotStreak.merge(b.streak, a.streak).freeze, 2);
      expect(ProgressSnapshot.merge(a, b).streak.freeze, 2);
    });

    test('birleşim değişmeli, birleşmeli ve idempotent', () async {
      final a = await _device('dev-a', () async {
        await (await StreakStore.load()).addFreeze();
      });
      final b = await _device('dev-b', () async {
        await (await StreakStore.load()).addFreeze();
      });
      final ab = SnapshotStreak.merge(a.streak, b.streak);
      expect(SnapshotStreak.merge(ab, a.streak).toJson(), ab.toJson());
      expect(SnapshotStreak.merge(ab, ab).toJson(), ab.toJson());
      expect(
        SnapshotStreak.merge(b.streak, a.streak).freezeLedger.keys.toSet(),
        ab.freezeLedger.keys.toSet(),
      );
    });

    test('birleşik bakiye yerele yazılır ve mağaza onu okur', () async {
      final a = await _device('dev-a', () async {
        await (await StreakStore.load()).addFreeze();
      });
      final b = await _device('dev-b', () async {
        await (await StreakStore.load()).addFreeze();
      });
      // B cihazına dön: bulut (A) ile birleştirip yaz.
      SharedPreferences.setMockInitialValues({FreezeLedger.deviceKey: 'dev-b'});
      LocalProgressScope.debugReset();
      LocalProgressScope.bind('user-a');
      StreakStore.resetInstance();
      final prefs = await SharedPreferences.getInstance();
      await (await StreakStore.load()).addFreeze();
      final local = LocalProgressSnapshot.read(prefs);
      expect(local.streak.freeze, 1);
      expect(
        await LocalProgressSnapshot.write(
          prefs,
          ProgressSnapshot.merge(local, a),
        ),
        isTrue,
      );
      StreakStore.resetInstance();
      expect((await StreakStore.load()).freezeCount, 2);
      expect(LocalProgressSnapshot.read(prefs).streak.freeze, 2);
      expect(b.streak.freeze, 1);
    });

    test('eşzamanlı harcama: iki cihaz aynı jetonu harcarsa bakiye 0', () async {
      final a = await _device('dev-a', () async {
        final p = await SharedPreferences.getInstance();
        await FreezeLedger.record(p, gained: false, current: 1);
      });
      // Taban 1 ile başlayan iki kopya (eşitlenmiş eski bakiye).
      final b = await _device('dev-b', () async {
        final p = await SharedPreferences.getInstance();
        await FreezeLedger.record(p, gained: false, current: 1);
      });
      final m = SnapshotStreak.merge(a.streak, b.streak);
      expect(m.freeze, 0);
      // Fazla harcama taşmayı değil 0'ı gösterir ve sonraki alım görünür kalır.
      expect(m.freezeLedger.containsKey(SnapshotStreak.absorberId), isTrue);
      final later = SnapshotStreak.merge(
        m,
        SnapshotStreak(
          freezeBase: 1,
          freezeLedger: {
            ...m.freezeLedger,
            'dev-a': const SnapshotFreezeEntry(gained: 1, spent: 1),
          },
        ),
      );
      expect(later.freeze, 1);
    });

    test('üst sınır: üçüncü jeton oluşmaz, sonraki harcama görünür', () {
      const a = SnapshotStreak(
        freezeBase: 1,
        freezeLedger: {'a': SnapshotFreezeEntry(gained: 1)},
      );
      const b = SnapshotStreak(
        freezeBase: 1,
        freezeLedger: {'b': SnapshotFreezeEntry(gained: 1)},
      );
      final m = SnapshotStreak.merge(a, b);
      expect(m.freeze, SnapshotStreak.maxFreeze);
      final spent = SnapshotStreak.merge(
        m,
        SnapshotStreak(
          freezeBase: 1,
          freezeLedger: {
            ...m.freezeLedger,
            'a': const SnapshotFreezeEntry(gained: 1, spent: 1),
          },
        ),
      );
      expect(spent.freeze, 1);
    });

    test('v1 kaydı (defter yok) taban olarak devralınır', () {
      final v1 = ProgressSnapshot.tryParse({
        'v': 1,
        'streak': {'freeze': 1},
      })!;
      expect(v1.streak.freezeBase, isNull);
      const bought = SnapshotStreak(
        freezeBase: 0,
        freezeLedger: {'a': SnapshotFreezeEntry(gained: 1)},
        freeze: 1,
      );
      expect(SnapshotStreak.merge(v1.streak, bought).freeze, 2);
    });

    test('JSON gidiş-dönüşü ve bozuk defter satırları', () {
      const s = SnapshotStreak(
        freezeBase: 1,
        freeze: 2,
        freezeLedger: {'a': SnapshotFreezeEntry(gained: 2, spent: 1)},
      );
      final back = SnapshotStreak.fromJson(s.toJson());
      expect(back.freezeBase, 1);
      expect(back.freezeLedger['a']!.gained, 2);
      expect(back.freeze, 2);
      final bad = SnapshotStreak.fromJson({
        'freezeBase': 1,
        'freezeLedger': {
          'x': [1],
          'y': ['a', 'b'],
          '': [1, 1],
          'z': [-3, 2],
        },
      });
      expect(bad.freezeLedger.keys, ['z']);
      expect(bad.freezeLedger['z']!.gained, 0);
    });

    test('StreakStore.maxFreeze ile görüntü sabiti aynı', () {
      expect(SnapshotStreak.maxFreeze, StreakStore.maxFreeze);
    });

    test('aynı kurulumun kimliği kalıcıdır', () async {
      SharedPreferences.setMockInitialValues({});
      FreezeLedger.debugReset();
      final p = await SharedPreferences.getInstance();
      final id = await FreezeLedger.deviceId(p);
      expect(id, hasLength(12));
      expect(await FreezeLedger.deviceId(p), id);
      expect(p.getString(FreezeLedger.deviceKey), id);
    });
  });

  group('2. şema sürümü', () {
    test('sürüm 2: yazılan görüntü 2, v1 hâlâ okunur, v3 reddedilir', () {
      expect(ProgressSnapshot.currentVersion, 2);
      expect(const ProgressSnapshot(xp: 3).toJson()['v'], 2);
      expect(ProgressSnapshot.tryParse({'v': 1, 'xp': 4})!.xp, 4);
      expect(ProgressSnapshot.tryParse({'v': 2, 'xp': 5})!.xp, 5);
      expect(ProgressSnapshot.tryParse({'v': 3, 'xp': 6}), isNull);
    });
  });

  group('3a. öğrenme hedefi: değişiklik zamanı', () {
    ProgressSnapshot goal(String? g, int? at) =>
        ProgressSnapshot(learningGoal: g, learningGoalAt: at);

    test('KUSUR (zamansız): yerel hep kazanır, eski cihaz yeniyi ezer', () {
      final m = ProgressSnapshot.merge(
        goal('learn_kurmanci', null),
        goal('culture', null),
      );
      expect(m.learningGoal, 'learn_kurmanci');
    });

    test('son seçen kazanır (iki yönde de)', () {
      final eski = goal('learn_kurmanci', 1000);
      final yeni = goal('culture', 2000);
      expect(ProgressSnapshot.merge(eski, yeni).learningGoal, 'culture');
      expect(ProgressSnapshot.merge(yeni, eski).learningGoal, 'culture');
      expect(ProgressSnapshot.merge(yeni, eski).learningGoalAt, 2000);
    });

    test('damgalı, damgasızı yener; ikisi de damgasızsa yerel', () {
      final damgali = goal('culture', 5);
      final damgasiz = goal('learn_kurmanci', null);
      expect(ProgressSnapshot.merge(damgasiz, damgali).learningGoal, 'culture');
      expect(ProgressSnapshot.merge(damgali, damgasiz).learningGoal, 'culture');
      expect(
        ProgressSnapshot.merge(damgasiz, goal('x', null)).learningGoal,
        'learn_kurmanci',
      );
    });

    test('hedef yalnız bir tarafta varsa o alınır', () {
      expect(
        ProgressSnapshot.merge(
          goal(null, null),
          goal('culture', 7),
        ).learningGoal,
        'culture',
      );
    });

    test(
      'LearningGoalStore.save değişiklik zamanını yazar, eşitleme taşır',
      () async {
        SharedPreferences.setMockInitialValues({});
        LocalProgressScope.debugReset();
        LocalProgressScope.bind('user-a');
        LearningGoalStore.resetInstance();
        final store = await LearningGoalStore.load();
        final before = DateTime.now().millisecondsSinceEpoch;
        expect(await store.save(LearningGoal.values.first), isTrue);
        final prefs = await SharedPreferences.getInstance();
        final read = LocalProgressSnapshot.read(prefs);
        expect(read.learningGoal, LearningGoal.values.first.storageKey);
        expect(read.learningGoalAt, greaterThanOrEqualTo(before));

        // Bulutta daha yeni bir seçim varsa yerele yazılır (damgasıyla).
        final remote = ProgressSnapshot(
          learningGoal: LearningGoal.values.last.storageKey,
          learningGoalAt: read.learningGoalAt! + 5000,
        );
        expect(
          await LocalProgressSnapshot.write(
            prefs,
            ProgressSnapshot.merge(read, remote),
          ),
          isTrue,
        );
        final after = LocalProgressSnapshot.read(prefs);
        expect(after.learningGoal, LearningGoal.values.last.storageKey);
        expect(after.learningGoalAt, remote.learningGoalAt);
      },
    );
  });

  group('3b. kelime listesi: silme işaretleri', () {
    SnapshotWord w({int added = 100, int reviewedAt = 0, int reviews = 0}) =>
        SnapshotWord(added: added, reviewedAt: reviewedAt, reviews: reviews);

    test('KUSUR (işaretsiz): bir cihazda silinen kelime geri dirilirdi', () {
      final m = ProgressSnapshot.merge(
        const ProgressSnapshot(),
        ProgressSnapshot(words: {'k': w()}),
      );
      expect(m.words.containsKey('k'), isTrue);
    });

    test('silme, eski kopyayı kaldırır (iki yönde de) ve işaret kalır', () {
      // Damgalar GÜNCEL olmalı: bulut birleşimi 180 günden eski silme
      // işaretlerini budar (alan 3 #21).
      final t = DateTime.now().millisecondsSinceEpoch;
      final silen = ProgressSnapshot(wordsRemoved: {'k': t});
      final eski = ProgressSnapshot(words: {'k': w(added: t - 400)});
      for (final m in [
        ProgressSnapshot.merge(silen, eski),
        ProgressSnapshot.merge(eski, silen),
      ]) {
        expect(m.words, isEmpty);
        expect(m.wordsRemoved, {'k': t});
      }
    });

    test(
      'silindikten SONRA yeniden eklenen ya da tekrar edilen kelime kalır',
      () {
        final silen = const ProgressSnapshot(wordsRemoved: {'k': 500});
        final yeniden = ProgressSnapshot(words: {'k': w(added: 900)});
        final tekrar = ProgressSnapshot(
          words: {'k': w(added: 100, reviewedAt: 800, reviews: 1)},
        );
        for (final other in [yeniden, tekrar]) {
          final m = ProgressSnapshot.merge(silen, other);
          expect(m.words.containsKey('k'), isTrue);
          expect(m.wordsRemoved, isEmpty);
        }
      },
    );

    test('JSON gidiş-dönüşü', () {
      const s = ProgressSnapshot(wordsRemoved: {'k': 5});
      expect(ProgressSnapshot.tryParse(s.toJson())!.wordsRemoved, {'k': 5});
      expect(s.isEmpty, isFalse);
      expect(
        const ProgressSnapshot().toJson().containsKey('wordsGone'),
        isFalse,
      );
    });

    test('WordListStore.remove işaret yazar; add işareti kaldırır', () async {
      SharedPreferences.setMockInitialValues({});
      LocalProgressScope.debugReset();
      LocalProgressScope.bind('user-a');
      WordListStore.resetInstance();
      final id = LearnerLexicon.entries.first.id;
      final store = InMemoryDataStorage();
      final list = await WordListStore.load(storage: store);
      expect(await list.add(id, now: DateTime(2026, 1, 1)), isTrue);
      expect(await list.remove(id), isTrue);
      final key = LocalProgressScope.physical(WordListStore.removedLogicalKey);
      expect(store.getString(key), contains(id));
      expect(await list.add(id), isTrue);
      expect(store.getString(key), isNull);
    });

    test('uçtan uca: bulutta silinen kelime yerelden de kalkar', () async {
      SharedPreferences.setMockInitialValues({});
      LocalProgressScope.debugReset();
      LocalProgressScope.bind('user-a');
      WordListStore.resetInstance();
      final id = LearnerLexicon.entries.first.id;
      final prefs = await SharedPreferences.getInstance();
      final list = await WordListStore.load();
      final added = DateTime.now().subtract(const Duration(days: 60));
      await list.add(id, now: added);
      final local = LocalProgressSnapshot.read(prefs);
      expect(local.words.containsKey(id), isTrue);
      final cloud = ProgressSnapshot(
        wordsRemoved: {
          id: added.add(const Duration(days: 30)).millisecondsSinceEpoch,
        },
      );
      expect(
        await LocalProgressSnapshot.write(
          prefs,
          ProgressSnapshot.merge(local, cloud),
        ),
        isTrue,
      );
      WordListStore.resetInstance();
      expect((await WordListStore.load()).contains(id), isFalse);
      expect(
        LocalProgressSnapshot.read(prefs).wordsRemoved.containsKey(id),
        isTrue,
      );
    });
  });

  group('4. boyut: reddedilen görüntü bölünüp yeniden gönderilir', () {
    test(
      'sunucu boyut reddederse çekirdek (defter sunucudaki) gider',
      () async {
        SharedPreferences.setMockInitialValues({});
        LocalProgressScope.debugReset();
        LocalProgressScope.bind('user-a');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          LocalProgressScope.physical('zankurd.xp.total'),
          120,
        );
        final remote = _Remote(
          row: RemoteProgress(
            snapshot: const ProgressSnapshot(
              mistakes: SnapshotMistakes(ids: {'sunucuda'}),
            ).toJson(),
            updatedAt: DateTime(2026, 1, 1),
          ),
          tooLargeFirst: true,
        );
        final service = ProgressSyncService(
          remote: remote,
          userId: 'user-a',
          preferences: prefs,
        );
        await service.syncNow();
        service.close();
        expect(remote.saved, hasLength(1));
        final core = ProgressSnapshot.tryParse(remote.saved.single)!;
        expect(core.xp, 120);
        expect(core.mistakes.ids, {'sunucuda'});
        expect(ProgressSyncService.oversized, isTrue);
        ProgressSyncService.oversized = false;
      },
    );
  });
}
