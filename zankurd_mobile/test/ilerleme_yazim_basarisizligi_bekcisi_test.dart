/// Jeton defteri ve kelime silme işaretlerinde YAZIM BAŞARISIZLIĞI.
///
/// Kusur: `FreezeLedger.record` iki yazımın (taban, defter) sonucunu
/// denetlemiyordu; taban yazılıp defter reddedilirse `addFreeze` başarı sayıp
/// jeton veriyor, sonraki okumada jeton kayboluyordu. `WordListStore._write`
/// önce silme işaretini sonra listeyi yazıyordu; ikinci yazım reddedilirse
/// işaret diskte kalıyor, sonraki eşitlemede kelime siliniyordu.
///
/// Niçin sessizdi: bellek sahte deposu her yazımı kabul eder; yalnız
/// `setString == false` döndüren bir depo kusuru gösterir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/freeze_ledger.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore(this.values);

  final Map<String, Object> values;
  final failing = <String>{};

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failing.contains(key)) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

/// Yalnız belirli anahtarı reddeden bellek deposu.
class _FailingStorage extends InMemoryDataStorage {
  final failing = <String>{};

  @override
  Future<bool> setString(String key, String value) async =>
      failing.contains(key) ? false : super.setString(key, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform original;

  setUp(() {
    original = SharedPreferencesStorePlatform.instance;
    LocalProgressScope.debugReset();
    LocalProgressScope.bind('user-a');
    StreakStore.resetInstance();
    WordListStore.resetInstance();
    FreezeLedger.debugReset();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });

  test(
    'defter yazımı reddedilirse addFreeze başarı saymaz ve taban geri alınır',
    () async {
      final disk = _FailingStore({});
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = disk;
      final prefs = await SharedPreferences.getInstance();
      disk.failing.add('flutter.${FreezeLedger.ledgerKey}');

      final store = await StreakStore.load();
      await expectLater(store.addFreeze(), throwsStateError);
      expect(store.freezeCount, 0);
      expect(disk.values.containsKey('flutter.${FreezeLedger.baseKey}'), false);
      expect(prefs.getInt(FreezeLedger.baseKey), isNull);
      expect(FreezeLedger.effective(prefs, fallback: 0), 0);

      // Yazım düzelince aynı işlem tek jeton verir (çift sayım yok).
      disk.failing.clear();
      expect(await store.addFreeze(), 1);
      expect(FreezeLedger.effective(prefs, fallback: 0), 1);
    },
  );

  test('taban yazımı reddedilirse de başarı sayılmaz', () async {
    final disk = _FailingStore({});
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    await SharedPreferences.getInstance();
    disk.failing.add('flutter.${FreezeLedger.baseKey}');
    final store = await StreakStore.load();
    await expectLater(store.addFreeze(), throwsStateError);
    expect(store.freezeCount, 0);
  });

  test(
    'kelime listesi yazımı reddedilirse silme işareti diskte kalmaz',
    () async {
      final storage = _FailingStorage();
      final list = await WordListStore.load(storage: storage);
      final id = LearnerLexicon.entries.first.id;
      expect(await list.add(id, now: DateTime(2026, 1, 1)), isTrue);

      final markerKey = LocalProgressScope.physical(
        WordListStore.removedLogicalKey,
      );
      storage.failing.add(list.physicalKey);
      expect(await list.remove(id), isFalse);
      // Bellek geri alındı, diskte işaret YOK (eski değer geri yazıldı).
      expect(list.contains(id), isTrue);
      expect(storage.getString(markerKey), isNull);
      expect(storage.getString(list.physicalKey), contains(id));

      // Yazım düzelince silme normal çalışır.
      storage.failing.clear();
      expect(await list.remove(id), isTrue);
      expect(storage.getString(markerKey), contains(id));
    },
  );

  test('işaret yazımı reddedilirse kelime listesi de değişmez', () async {
    final storage = _FailingStorage();
    final list = await WordListStore.load(storage: storage);
    final id = LearnerLexicon.entries.first.id;
    await list.add(id, now: DateTime(2026, 1, 1));
    final markerKey = LocalProgressScope.physical(
      WordListStore.removedLogicalKey,
    );
    storage.failing.add(markerKey);
    expect(await list.remove(id), isFalse);
    expect(list.contains(id), isTrue);
    expect(storage.getString(list.physicalKey), contains(id));
  });
}
