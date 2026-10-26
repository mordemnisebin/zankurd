import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/app_haptics.dart';

/// Titreşim ayarı (2026-10-27).
///
/// Bekçi: ayar kapalıyken hiçbir dokunsal çağrı platforma gitmez; ayar
/// kalıcıdır (yeniden açılışta okunur); kayıt yoksa varsayılan açıktır.
/// Ekranlar `HapticFeedback`i doğrudan çağırmaz, yoksa ayar delinir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add('$call');
          return null;
        });
  });

  test('kayıt yoksa açık; kapalıyken platforma çağrı gitmez', () async {
    SharedPreferences.setMockInitialValues({});
    await AppHaptics.load();
    expect(AppHaptics.enabled, isTrue);
    AppHaptics.medium();
    expect(calls, hasLength(1));

    await AppHaptics.setEnabled(false);
    AppHaptics.selection();
    AppHaptics.light();
    AppHaptics.medium();
    AppHaptics.heavy();
    AppHaptics.vibrate();
    expect(calls, hasLength(1));
  });

  test('ayar kalıcıdır', () async {
    SharedPreferences.setMockInitialValues({});
    await AppHaptics.setEnabled(false);
    await AppHaptics.setEnabled(true);
    await AppHaptics.setEnabled(false);
    // Yeniden açılış:
    await AppHaptics.load();
    expect(AppHaptics.enabled, isFalse);
    await AppHaptics.setEnabled(true);
  });

  test('ekranlar HapticFeedback\'i doğrudan çağırmaz', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('services/app_haptics.dart')) continue;
      if (entity.readAsStringSync().contains('HapticFeedback.')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
