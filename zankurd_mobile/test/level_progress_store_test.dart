import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  test('oynanan seviye kalıcı işaretlenir', () async {
    final store = await LevelProgressStore.load();
    expect(store.isPlayed('Ziman', 'reziman', 1), isFalse);

    await store.markPlayed('Ziman', 'reziman', 1);
    expect(store.isPlayed('Ziman', 'reziman', 1), isTrue);
    // Aynı kategori/alt-kategori ayrımı korunur.
    expect(store.isPlayed('Ziman', 'peyvnasi', 1), isFalse);
    expect(store.isPlayed('Dîrok', 'reziman', 1), isFalse);
  });

  test('alt kategorisiz seviye ayrı anahtar kullanır', () async {
    final store = await LevelProgressStore.load();
    await store.markPlayed('Ziman', null, 2);
    expect(store.isPlayed('Ziman', null, 2), isTrue);
    expect(store.isPlayed('Ziman', 'reziman', 2), isFalse);
  });

  test('tekrar işaretleme mükerrer kayıt üretmez', () async {
    final store = await LevelProgressStore.load();
    await store.markPlayed('Muzîk', null, 3);
    await store.markPlayed('Muzîk', null, 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('zankurd.level.played'), hasLength(1));
  });
}
