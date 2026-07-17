import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  test('Initial state: 0 XP is Level 1', () async {
    final store = await XPStore.load();
    expect(store.totalXP, 0);
    expect(store.currentLevel, 1);
    expect(store.xpInCurrentLevel, 0);
    expect(store.xpNeededForNextLevel, 1000);
    expect(store.levelProgress, 0.0);
  });

  test('xpRequiredForLevel calculates correct thresholds', () {
    expect(XPStore.xpRequiredForLevel(1), 0);
    expect(XPStore.xpRequiredForLevel(2), 1000);
    expect(XPStore.xpRequiredForLevel(3), 2500);
    expect(XPStore.xpRequiredForLevel(4), 4500);
    expect(XPStore.xpRequiredForLevel(5), 7000);
    expect(XPStore.xpRequiredForLevel(6), 10000);
  });

  test('calculateLevel maps XP to correct level', () {
    expect(XPStore.calculateLevel(-5), 1);
    expect(XPStore.calculateLevel(0), 1);
    expect(XPStore.calculateLevel(500), 1);
    expect(XPStore.calculateLevel(999), 1);
    expect(XPStore.calculateLevel(1000), 2);
    expect(XPStore.calculateLevel(2499), 2);
    expect(XPStore.calculateLevel(2500), 3);
    expect(XPStore.calculateLevel(4499), 3);
    expect(XPStore.calculateLevel(4500), 4);
    expect(XPStore.calculateLevel(6999), 4);
    expect(XPStore.calculateLevel(7000), 5);
    expect(XPStore.calculateLevel(9999), 5);
    expect(XPStore.calculateLevel(10000), 6);
  });

  test('addXP adds XP correctly and returns level-up status', () async {
    final store = await XPStore.load();

    // Add XP within Level 1
    bool leveledUp = await store.addXP(400);
    expect(leveledUp, isFalse);
    expect(store.totalXP, 400);
    expect(store.currentLevel, 1);
    expect(store.levelProgress, 0.4);

    // Add XP to trigger Level Up
    leveledUp = await store.addXP(700); // Total 1100 -> Level 2
    expect(leveledUp, isTrue);
    expect(store.totalXP, 1100);
    expect(store.currentLevel, 2);
    expect(store.xpInCurrentLevel, 100); // 1100 - 1000
    expect(store.xpNeededForNextLevel, 1500); // 2500 - 1000
    expect(store.levelProgress, closeTo(100 / 1500, 0.0001));
  });

  test('addXP rejects zero or negative amounts', () async {
    final store = await XPStore.load();
    bool leveledUp = await store.addXP(0);
    expect(leveledUp, isFalse);
    expect(store.totalXP, 0);

    leveledUp = await store.addXP(-50);
    expect(leveledUp, isFalse);
    expect(store.totalXP, 0);
  });

  test('loadForTest initializes with correct value', () async {
    final store = await XPStore.loadForTest(5000);
    expect(store.totalXP, 5000);
    expect(store.currentLevel, 4);
  });

  test('clear resets XP values in memory and preferences', () async {
    final store = await XPStore.load();
    await store.addXP(500);
    expect(store.totalXP, 500);

    await store.clear();
    expect(store.totalXP, 0);

    XPStore.resetInstance();
    final reloaded = await XPStore.load();
    expect(reloaded.totalXP, 0);
  });
}

