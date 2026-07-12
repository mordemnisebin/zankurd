import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  test('varsayılan: seviye yok ve ilk kullanımda sorulur', () async {
    final store = await PlacementStore.load();
    expect(store.level, isNull);
    expect(store.completed, isFalse);
    expect(store.shouldPrompt, isTrue);
  });

  test('sonuç kaydedilir ve kalıcı olur', () async {
    final store = await PlacementStore.load();
    await store.saveResult(PlacementLevel.navin);
    expect(store.level, PlacementLevel.navin);
    expect(store.completed, isTrue);
    expect(store.shouldPrompt, isFalse);

    PlacementStore.resetInstance();
    final reloaded = await PlacementStore.load();
    expect(reloaded.level, PlacementLevel.navin);
    expect(reloaded.shouldPrompt, isFalse);
  });

  test('şimdilik geç: sorulmaz ama seviye boş kalır', () async {
    final store = await PlacementStore.load();
    await store.markSkipped();
    expect(store.shouldPrompt, isFalse);
    expect(store.level, isNull);

    PlacementStore.resetInstance();
    final reloaded = await PlacementStore.load();
    expect(reloaded.shouldPrompt, isFalse);
    expect(reloaded.level, isNull);
  });

  test('kayıtlı sonuç varken tekrar açılmaz', () async {
    final store = await PlacementStore.load();
    await store.saveResult(PlacementLevel.pesketi);
    expect(store.shouldPrompt, isFalse);
  });

  test(
    'yeniden sınav: geç işareti temizlenir, yeni sonuç yazılabilir',
    () async {
      final store = await PlacementStore.load();
      await store.markSkipped();
      expect(store.shouldPrompt, isFalse);

      await store.saveResult(PlacementLevel.destpek);
      expect(store.level, PlacementLevel.destpek);

      // Yeniden sınav sonrası yeni sonuç öncekini ezer.
      await store.saveResult(PlacementLevel.pesketi);
      expect(store.level, PlacementLevel.pesketi);
    },
  );

  test('bozuk/eksik veri güvenli varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.placement.v1.level': 'saçmalık',
    });
    PlacementStore.resetInstance();
    final store = await PlacementStore.load();
    expect(store.level, isNull);
    expect(store.shouldPrompt, isTrue);
  });
}
