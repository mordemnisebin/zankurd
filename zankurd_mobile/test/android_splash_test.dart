// Android açılış ekranı bekçisi (2026-10-19).
//
// Tester: "Android açılış ekranı çok kaba, kötü". Neden: `values-v31` yoktu;
// Android 12+ sistem açılış API'si varsayılan tema zeminini ve başlatıcı
// simgesini daireye kırparak gösteriyor, sonra Flutter'ın ilk karesine
// renk atlıyordu. Ayrıca yerel zemin eski #E9EDF6 kalmıştı, Flutter ise
// `AppTheme.lightBg` (#F4F6FA) çiziyordu. Bu test XML'i ayrıştırıp
// zeminlerin Flutter'la aynı, simgenin var olduğunu ve karanlıkta
// beyaz zemin çakmadığını sabitler.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

const _res = 'android/app/src/main/res';

String _read(String p) => File('$_res/$p').readAsStringSync();

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _color(String name) {
  final m = RegExp(
    '<color name="$name">(#[0-9A-Fa-f]{6})</color>',
  ).firstMatch(_read('values/colors.xml'));
  expect(m, isNotNull, reason: '$name colors.xml içinde yok');
  return m!.group(1)!.toUpperCase();
}

String _item(String xml, String style, String item) {
  final s = RegExp(
    '<style name="$style".*?</style>',
    dotAll: true,
  ).firstMatch(xml);
  expect(s, isNotNull, reason: '$style yok');
  final m = RegExp('<item name="$item">(.*?)</item>').firstMatch(s!.group(0)!);
  expect(m, isNotNull, reason: '$style/$item yok');
  return m!.group(1)!;
}

void main() {
  test('yerel açılış renkleri Flutter ilk karesiyle aynı', () {
    expect(_color('zk_splash_bg'), _hex(AppTheme.lightBg.toARGB32()));
    expect(_color('zk_splash_bg_dark'), _hex(AppTheme.bg.toARGB32()));
  });

  for (final (dir, bg) in [
    ('values-v31', 'zk_splash_bg'),
    ('values-night-v31', 'zk_splash_bg_dark'),
  ]) {
    test('$dir: sistem açılış ekranı marka zemini ve geçerli simge', () {
      final xml = _read('$dir/styles.xml');
      expect(
        _item(xml, 'LaunchTheme', 'android:windowSplashScreenBackground'),
        '@color/$bg',
      );
      expect(
        _item(
          xml,
          'LaunchTheme',
          'android:windowSplashScreenIconBackgroundColor',
        ),
        '@color/$bg',
      );
      final icon = _item(
        xml,
        'LaunchTheme',
        'android:windowSplashScreenAnimatedIcon',
      );
      expect(icon, startsWith('@drawable/'));
      final f = File('$_res/drawable/${icon.substring(10)}.xml');
      expect(f.existsSync(), isTrue);
      expect(f.readAsStringSync(), contains('android:insetLeft'));
      expect(
        _item(xml, 'NormalTheme', 'android:windowBackground'),
        '@color/$bg',
      );
    });
  }

  test('NormalTheme karanlıkta beyaz/sistem zemini kullanmaz', () {
    for (final p in ['values/styles.xml', 'values-night/styles.xml']) {
      expect(
        _item(_read(p), 'NormalTheme', 'android:windowBackground'),
        startsWith('@color/zk_splash_bg'),
      );
    }
    expect(
      _item(
        _read('values-night/styles.xml'),
        'NormalTheme',
        'android:windowBackground',
      ),
      '@color/zk_splash_bg_dark',
    );
  });
}
