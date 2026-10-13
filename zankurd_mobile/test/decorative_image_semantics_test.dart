/// Süs görsellerin ekran okuyucudan saklanması.
///
/// Kusur (2026-10-02 erişilebilirlik denetimi): `Image`/`Image.asset`
/// varsayılanı "görsel" işaretli, ADSIZ bir düğüm üretir. Ders slaytının
/// görseli, tur özeti görseli, oyuncu fotoğrafı ve marka işareti süstü ama
/// kapatılmamıştı: TalkBack/VoiceOver bunlarda "görsel" diye durup hiçbir
/// şey söylemiyordu. Görselin anlam taşıdığı tek yer soru görselidir ve onun
/// kendi `alt` betimlemesi vardır (bkz. `question_image_semantics_test`).
///
/// Sessiz kaldı çünkü hiçbir kılavuz adsız, dokunulmaz düğümü sormaz.
///
/// Kural: lib altındaki her `Image(`, `Image.asset(`, `Image.network(` ve
/// `CachedNetworkImage(` ya `excludeFromSemantics: true` verir, ya
/// `semanticLabel:` taşır, ya da yakınında (önceki 20 satır) bir
/// `ExcludeSemantics(` / `Semantics(` sarmalayıcısı vardır.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('her görsel ya süs olarak saklanır ya da adlandırılır', () {
    final call = RegExp(
      r'(?<![\w.])(Image|Image\.asset|Image\.network|CachedNetworkImage)\(',
    );
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      // Soru görseli tek anlam taşıyan görseldir: `alt` betimlemesini
      // görseli kurduktan SONRA sarar ve kendi bekçisi vardır
      // (`question_image_semantics_test`).
      if (file.path.endsWith('quiz/quiz_widgets.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('///')) {
          continue;
        }
        if (!call.hasMatch(line)) continue;
        // Çağrı gövdesi: parantez kapanana dek (en çok 40 satır).
        final body = StringBuffer();
        var depth = 0;
        var started = false;
        for (var j = i; j < lines.length && j < i + 40; j++) {
          final text = j == i
              ? line.substring(call.firstMatch(line)!.start)
              : lines[j];
          for (final ch in text.split('')) {
            if (ch == '(') {
              depth++;
              started = true;
            } else if (ch == ')') {
              depth--;
            }
          }
          body.writeln(text);
          if (started && depth <= 0) break;
        }
        final text = body.toString();
        final before = lines
            .sublist(i < 20 ? 0 : i - 20, i + 1)
            .any(
              (l) =>
                  l.contains('ExcludeSemantics(') || l.contains('Semantics('),
            );
        if (!text.contains('excludeFromSemantics: true') &&
            !text.contains('semanticLabel:') &&
            !before) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Görsel süs ise excludeFromSemantics: true / ExcludeSemantics, '
          'anlam taşıyorsa semanticLabel verin:\n${offenders.join('\n')}',
    );
  });
}
