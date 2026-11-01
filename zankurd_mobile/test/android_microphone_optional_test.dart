// Bekçi: Android manifestinde mikrofon isteğe bağlı kalmalı.
//
// Kusur (build 42, 2026-10-30): telaffuz atölyesi için eklenen RECORD_AUDIO
// izni, Play'de `android.hardware.microphone` özelliğini örtük olarak ZORUNLU
// yapar. Play Console yalnız yükleme sırasında "21 cihaz artık desteklenmiyor"
// uyarısı verdi; derleme, testler ve uygulama sorunsuz olduğundan kusur sessiz
// kaldı ve mikrofonsuz tabletler uygulamayı göremez oldu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RECORD_AUDIO varsa mikrofon required=false olarak bildirilir', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    if (!manifest.contains('android.permission.RECORD_AUDIO')) return;
    expect(
      RegExp(
        r'<uses-feature\s+android:name="android\.hardware\.microphone"\s+'
        r'android:required="false"\s*/>',
      ).hasMatch(manifest),
      isTrue,
    );
  });
}
