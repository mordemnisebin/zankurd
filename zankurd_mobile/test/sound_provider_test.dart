import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SoundProvider', () {
    test('varsayılan olarak ses açık', () async {
      final provider = await SoundProvider.load();
      expect(provider.enabled, isTrue);
    });

    test('toggle() sesi kapatır', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      expect(provider.enabled, isFalse);
    });

    test('iki kez toggle() sonra ses açık', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      provider.toggle();
      expect(provider.enabled, isTrue);
    });

    test('toggle() SharedPreferences\'e false yazar', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('zankurd.sound.enabled'), isFalse);
    });

    test('load() SharedPreferences\'ten false okur', () async {
      SharedPreferences.setMockInitialValues({'zankurd.sound.enabled': false});
      final provider = await SoundProvider.load();
      expect(provider.enabled, isFalse);
    });
  });
}
