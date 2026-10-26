import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/data_export.dart';

/// "İlerleme verilerimi dışa aktar" (2026-10-27).
///
/// Bekçi: dosya geçerli JSON'dur; ilerleme, kayıtlı kelimeler ve biten
/// dersler içindedir; hesap kimliği ya da e-posta gibi kişisel tanımlayıcı
/// dosyaya sızmaz (yalnız öğrenme verisi sözü).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dışa aktarma geçerli JSON ve yalnız öğrenme verisi', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.offline.completedLessonIds': ['ders_2', 'ders_1'],
      'zankurd.auth.email': 'gizli@example.com',
    });
    final bytes = await DataExport.build(now: DateTime.utc(2026, 10, 27));
    final text = utf8.decode(bytes);
    final data = jsonDecode(text) as Map<String, dynamic>;

    expect(data['app'], 'ZanKurd');
    expect(data['exportedAt'], '2026-10-27T00:00:00.000Z');
    expect(data['progress'], isA<Map<String, dynamic>>());
    expect(data['savedWords'], isA<List<dynamic>>());
    expect(data['completedLessons'], ['ders_1', 'ders_2']);
    expect(text, isNot(contains('gizli@example.com')));
    expect(text.toLowerCase(), isNot(contains('email')));
  });
}
