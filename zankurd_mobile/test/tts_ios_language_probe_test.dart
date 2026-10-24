// iOS'ta flutter_tts `getLanguages` dilleri ana iş parçacığında sayıyor ve
// simülatörde her quiz başında uygulamayı kilitledi; iOS'ta Kurmancî ses
// zaten olmadığından sorgu hiç yapılmamalı. Test koşucusu yerel kanalı
// çalıştırmadığı için kilit testlerde görünmüyordu.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TtsService.resetInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          calls.add(call.method);
          if (call.method == 'getLanguages') return <String>['ku-TR'];
          return 1;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TtsService.resetInstance();
  });

  test('iOS: dil sorgusu yapılmaz, Kurmancî ses yok sayılır', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final tts = await TtsService.load();
    expect(calls, isNot(contains('getLanguages')));
    expect(tts.isKurdishAvailable, isFalse);
  });

  test(
    'Android: dil sorgusu yapılır, Kurmancî ses bulunursa kullanılır',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final tts = await TtsService.load();
      expect(calls, contains('getLanguages'));
      expect(tts.isKurdishAvailable, isTrue);
    },
  );
}
