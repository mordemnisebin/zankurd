import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUp(() {
    SharedPreferences.resetStatic();
    PlacementStore.resetInstance();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
    PlacementStore.resetInstance();
  });

  for (final rejectedMethod in [
    'journal',
    'level',
    'skipped',
    'updatedAt',
    'commit',
  ]) {
    for (final throwsOnWrite in [false, true]) {
      test(
        'saveResult $rejectedMethod '
        '${throwsOnWrite ? "istisnasında" : "false sonucunda"} başarı göstermez',
        () async {
          final storage = <String, Object>{
            'flutter.zankurd.placement.v1.skipped': true,
            'flutter.zankurd.placement.v1.updatedAt': 42,
          };
          var rejectWrite = true;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'getAll') return Map.of(storage);
                final args = Map<String, Object?>.from(call.arguments as Map);
                final key = args['key'] as String;
                final stage = key.endsWith('.pending')
                    ? (call.method == 'remove' ? 'commit' : 'journal')
                    : key.split('.').last;
                if (rejectWrite && stage == rejectedMethod) {
                  if (throwsOnWrite) {
                    throw PlatformException(code: 'injected-write-failure');
                  }
                  return false;
                }
                if (call.method == 'remove') {
                  storage.remove(key);
                } else {
                  storage[key] = args['value']!;
                }
                return true;
              });
          final store = await PlacementStore.load();

          await expectLater(
            store.saveResult(PlacementLevel.navin),
            throwsA(
              throwsOnWrite ? isA<PlatformException>() : isA<StateError>(),
            ),
          );
          expect(store.level, isNull);
          expect(store.completed, isFalse);
          expect(store.skipped, isTrue);
          SharedPreferences.resetStatic();
          PlacementStore.resetInstance();
          final reloaded = await PlacementStore.load();
          expect(reloaded.level, isNull);
          expect(reloaded.completed, isFalse);
          expect(reloaded.skipped, isTrue);
          final prefs = await SharedPreferences.getInstance();
          final snapshot = LocalProgressSnapshot.read(prefs);
          expect(snapshot.placementLevel, isNull);
          expect(snapshot.placementSkipped, isTrue);
          expect(snapshot.placementUpdatedAt, 42);

          rejectWrite = false;
          await reloaded.saveResult(PlacementLevel.navin);
          expect(reloaded.level, PlacementLevel.navin);
          expect(reloaded.skipped, isFalse);
          expect(storage['flutter.zankurd.placement.v1.level'], 'navin');
          expect(
            storage['flutter.zankurd.placement.v1.updatedAt'],
            greaterThan(42),
          );
          expect(LocalProgressSnapshot.read(prefs).placementLevel, 'navin');
        },
      );
    }
  }
  test(
    'commit onayı beklenirken eşitleme önceki placement durumunu okur',
    () async {
      final commitStarted = Completer<void>();
      final allowCommit = Completer<void>();
      final storage = <String, Object>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAll') return Map.of(storage);
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String;
            if (call.method == 'remove' && key.endsWith('.pending')) {
              commitStarted.complete();
              await allowCommit.future;
            }
            if (call.method == 'remove') {
              storage.remove(key);
            } else {
              storage[key] = args['value']!;
            }
            return true;
          });
      final store = await PlacementStore.load();
      final saving = store.saveResult(PlacementLevel.navin);
      await commitStarted.future;
      final prefs = await SharedPreferences.getInstance();
      expect(store.completed, isFalse);
      expect(LocalProgressSnapshot.read(prefs).placementLevel, isNull);
      expect(LocalProgressSnapshot.read(prefs).placementUpdatedAt, isNull);
      allowCommit.complete();
      await saving;
      expect(store.completed, isTrue);
      expect(LocalProgressSnapshot.read(prefs).placementLevel, 'navin');
    },
  );

  test('commit ve reload birlikte başarısızsa önceki sonuç korunur', () async {
    final storage = <String, Object>{};
    var rejectCommit = true;
    var rejectRead = false;
    var writesAfterFailure = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAll') {
            if (rejectRead) {
              throw PlatformException(code: 'reload-unavailable');
            }
            return Map.of(storage);
          }
          if (rejectRead) writesAfterFailure++;
          final args = Map<String, Object?>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (rejectCommit &&
              call.method == 'remove' &&
              key.endsWith('.pending')) {
            rejectRead = true;
            return false;
          }
          if (call.method == 'remove') {
            storage.remove(key);
          } else {
            storage[key] = args['value']!;
          }
          return true;
        });
    final store = await PlacementStore.load();
    await expectLater(
      store.saveResult(PlacementLevel.navin),
      throwsA(isA<PlatformException>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(LocalProgressSnapshot.read(prefs).placementLevel, isNull);
    expect(LocalProgressSnapshot.read(prefs).placementUpdatedAt, isNull);
    PlacementStore.resetInstance();
    final reloaded = await PlacementStore.load();
    expect(reloaded.completed, isFalse);

    // Disk uzlaştırılamıyorsa sonraki yazım yeni işlem başlatamaz.
    await expectLater(
      reloaded.saveResult(PlacementLevel.pesketi),
      throwsA(isA<PlatformException>()),
    );
    expect(writesAfterFailure, 0);
    expect(LocalProgressSnapshot.read(prefs).placementLevel, isNull);

    rejectRead = false;
    rejectCommit = false;
    await reloaded.saveResult(PlacementLevel.pesketi);
    expect(reloaded.level, PlacementLevel.pesketi);
    expect(LocalProgressSnapshot.read(prefs).placementLevel, 'pesketi');
    expect(
      storage.containsKey('flutter.zankurd.placement.v1.pending'),
      isFalse,
    );
  });

  test('preferences açılamazsa sonuç kaydı başarı göstermez', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'storage-unavailable');
        });
    final store = await PlacementStore.load();
    await expectLater(store.saveResult(PlacementLevel.navin), throwsStateError);
    expect(store.completed, isFalse);
  });

  test(
    'yarım kalan yerel placement yazımı sonraki sync ile tamamlanabilir',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.placement.v1.level': 'navin',
        'zankurd.placement.v1.updatedAt': 100,
        'zankurd.placement.v1.pending':
            '{"level":null,"skipped":true,"updatedAt":42}',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(LocalProgressSnapshot.read(prefs).placementLevel, isNull);
      expect(
        await LocalProgressSnapshot.write(
          prefs,
          const ProgressSnapshot(
            placementLevel: 'pesketi',
            placementUpdatedAt: 200,
          ),
        ),
        isTrue,
      );
      PlacementStore.resetInstance();
      expect((await PlacementStore.load()).level, PlacementLevel.pesketi);
      expect(LocalProgressSnapshot.read(prefs).placementUpdatedAt, 200);
      expect(prefs.containsKey('zankurd.placement.v1.pending'), isFalse);
    },
  );
}
