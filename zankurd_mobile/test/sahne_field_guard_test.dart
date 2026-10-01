import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Girdi alanı bekçisi.
///
/// 2026-09-30'da dört bağımsız denetçi aynı kusuru buldu: giriş ekranları
/// pahlı Şahnê alanını, ad kapısı / ayarlar / soru öneri formu / sözlük ve
/// arkadaş araması ise Material'in yuvarlak (12 px) kutusunu kullanıyordu;
/// etiket ve yer tutucu renkleri de formdan forma değişiyordu. Sessiz kalırdı:
/// her ekran tek tek "çalışıyor", ikisi yan yana durunca uygulama iki ayrı
/// tasarım diliyle konuşuyor.
///
/// Kural: uygulamanın metin girdisi, arama kutusu ve açılır listesi
/// `lib/src/widgets/sahne/sahne_field.dart` içindeki `SahneField` /
/// `SahneField.search` / `SahneDropdownField`tır. Başka hiçbir dosya ham
/// `TextField`, `TextFormField`, `DropdownButton(FormField)`, `DropdownMenu`,
/// `SearchBar`, `Autocomplete`, `InputDecoration(...)` ya da yuvarlak
/// `OutlineInputBorder` yazmaz. Yeni bir girdi gerekiyorsa önce SahneField'a
/// gereken seçenek eklenir.
void main() {
  const shared = 'lib/src/widgets/sahne/sahne_field.dart';
  final forbidden = <String, RegExp>{
    'TextField': RegExp(r'\bTextField\('),
    'TextFormField': RegExp(r'\bTextFormField\('),
    'DropdownButton': RegExp(r'\bDropdownButton(FormField)?(<[^>(]*>)?\('),
    'DropdownMenu': RegExp(r'\bDropdownMenu\('),
    'SearchBar': RegExp(r'\bSearchBar\('),
    'Autocomplete': RegExp(r'\bAutocomplete(<[^>(]*>)?\('),
    'InputDecoration': RegExp(r'\bInputDecoration\('),
    'OutlineInputBorder': RegExp(r'\bOutlineInputBorder\('),
    'UnderlineInputBorder': RegExp(r'\bUnderlineInputBorder\('),
  };

  /// Yorum satırlarını at: açıklamalar `TextField`'dan söz edebilir.
  String code(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('ham girdi widget\'ı yalnız ortak SahneField dosyasında geçer', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == shared) continue;
      final source = code(entity.readAsStringSync());
      forbidden.forEach((name, pattern) {
        if (pattern.hasMatch(source)) offenders.add('$path -> $name');
      });
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Girdiler SahneField / SahneField.search / SahneDropdownField ile '
          'çizilir (sahne_field.dart). Ham widget kullanan dosyalar:\n'
          '${offenders.join('\n')}',
    );
  });

  test('ortak alanın çerçevesi pahlı, yuvarlak kutu yok', () {
    final source = code(File(shared).readAsStringSync());
    expect(source, contains('BeveledRectangleBorder'));
    expect(source, isNot(contains('OutlineInputBorder')));
    expect(source, isNot(contains('BorderRadius.circular')));
    // Odak Agir, hata Şaş: ham renk değil belirteç.
    expect(source, contains('t.actTx'));
    expect(source, contains('t.errTx'));
    expect(source, isNot(contains('Color(0x')));
  });

  test('temada yuvarlak girdi çerçevesi bırakılmadı', () {
    final theme = code(File('lib/src/theme/app_theme.dart').readAsStringSync());
    expect(theme, isNot(contains('OutlineInputBorder')));
  });
}
