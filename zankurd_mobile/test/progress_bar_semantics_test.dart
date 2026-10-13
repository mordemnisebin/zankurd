/// İlerleme çubuklarının ekran okuyucu adı.
///
/// Kusur (2026-10-02 erişilebilirlik denetimi): `SahneProgressBar` yalnız
/// DEĞER okur ("2/5", "%65"); neyin ilerlemesi olduğunu `semanticLabel`
/// söyler ve alan isteğe bağlıydı. XP şeridi, seri paneli, görev kartı,
/// konu ustalığı satırı ve ders slayt çubuğu etiketsiz çiziliyordu:
/// TalkBack/VoiceOver kullanan oyuncu çıplak bir "2/5" duyuyordu.
///
/// Sessiz kalma sebebi: çubuk `excludeSemantics: true` ile TEK düğüm olur ve
/// ana düğümle birleşir; `labeledTapTargetGuideline` yalnız dokunulur düğümleri
/// denetler (çubuk dokunulmaz) ve değer-adsız durumu hiçbir kılavuz sormaz.
/// Üstelik çubuk üst düğüme birleştiği için düğüm ağacı taramasıyla da
/// görünmez; bu yüzden bekçi kaynağı tarar.
///
/// Kural: her `SahneProgressBar(` çağrısı ya `semanticLabel:` verir ya da
/// bir `ExcludeSemantics` içindedir (değeri çevreleyen satırın etiketi
/// özetliyorsa; ör. görev satırı, tanıtım sayfası).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('her SahneProgressBar adlıdır ya da ExcludeSemantics içindedir', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('sahne_progress.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('SahneProgressBar(')) continue;
        // Çağrının parantezi kapanana dek metni topla.
        final buffer = StringBuffer();
        var depth = 0;
        var started = false;
        for (var j = i; j < lines.length && j < i + 30; j++) {
          final text = j == i
              ? lines[j].substring(lines[j].indexOf('SahneProgressBar('))
              : lines[j];
          for (final rune in text.runes) {
            final ch = String.fromCharCode(rune);
            if (ch == '(') {
              depth++;
              started = true;
            } else if (ch == ')') {
              depth--;
            }
          }
          buffer.writeln(text);
          if (started && depth <= 0) break;
        }
        final call = buffer.toString();
        final named = call.contains('semanticLabel:');
        final before = lines
            .sublist(i < 4 ? 0 : i - 4, i + 1)
            .any((l) => l.contains('ExcludeSemantics('));
        // Seçenek karoları (`quiz_option_tile`) bütün şıkkı tek düğüme
        // indirir (`excludeSemantics: true`); izleyici yüzdesi şık
        // etiketinin parçası değildir ama düğüm zaten kapalıdır.
        final inExcludingParent = file.path.endsWith('quiz_option_tile.dart');
        if (!named && !before && !inExcludingParent) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Adsız ilerleme çubuğu: semanticLabel verin ya da ExcludeSemantics '
          'içine alın:\n${offenders.join('\n')}',
    );
  });
}
