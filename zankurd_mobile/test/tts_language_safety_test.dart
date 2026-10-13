import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];
  var languages = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'getLanguages' ? languages : 1;
        });
  });
  tearDown(() {
    TtsService.resetInstance();
  });

  test(
    'Soranî veya Türkçe sesi Kurmancî desteği sayılmaz ve konuşmaz',
    () async {
      languages = ['ckb-IQ', 'tr-TR'];
      final service = await TtsService.load();
      expect(service.isKurdishAvailable, isFalse);
      await service.speak('Silav');
      expect(calls.where((call) => call.method == 'speak'), isEmpty);
    },
  );

  test(
    'geçersiz eski ses tercihi yerine kurulu Kurmancî sesi seçilir',
    () async {
      SharedPreferences.setMockInitialValues({'zankurd.tts.language': 'tr-TR'});
      languages = ['tr-TR', 'ku_TR'];
      final service = await TtsService.load();
      expect(service.isKurdishAvailable, isTrue);
      expect(service.activeLanguage, 'ku_TR');
      await service.speak('Silav');
      expect(calls.where((call) => call.method == 'speak'), hasLength(1));
    },
  );

  test('kurulu bölgesel Kurmancî sesi korunur', () async {
    languages = ['ku-SY'];
    final service = await TtsService.load();
    expect(service.activeLanguage, 'ku-SY');
    expect(service.isKurdishAvailable, isTrue);
  });
}
