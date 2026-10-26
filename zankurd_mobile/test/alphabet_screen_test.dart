import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/kurmanci_alphabet.dart';
import 'package:zankurd_mobile/src/screens/alphabet_screen.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/services/recorded_clip_catalog.dart';

import 'support/widget_test_helpers.dart';

/// Alfabe ve sesler (2026-10-27).
///
/// Bekçi: Hawar'ın 31 harfi eksiksiz ve sıralı; Türkçeden farklı okunan
/// dokuz harfte ipucu var; paketli ses kataloğuyla her harfin örnek
/// kelimesi o harfle başlar ve sesi vardır (sessiz örnek düğme gösterip
/// çalmazdı); satıra dokunmak örneği çalar, kaplumbağa yavaş çalar.
class _FakeSpeaker implements LessonListeningSpeaker {
  final spoken = <String>[];
  final slows = <bool>[];

  @override
  bool get available => true;

  @override
  bool availableFor(String text) => true;

  @override
  ValueListenable<bool> get speakingListenable => ValueNotifier(false);

  @override
  Future<void> speak(String text, {bool slow = false}) async {
    spoken.add(text);
    slows.add(slow);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  test('31 harf sıralı; ipucu yalnız farklı okunan dokuz harfte', () {
    expect(
      kurmanciAlphabet.map((l) => l.letter).join(),
      'abcçdeêfghiîjklmnopqrsştuûvwxyz',
    );
    expect(
      [
        for (final l in kurmanciAlphabet)
          if (l.hintKey != null) l.letter,
      ].join(),
      'eêiîquûwx',
    );
  });

  test('paketli seslerle her harfin sesli, o harfi taşıyan örneği var', () {
    final catalog = RecordedClipCatalog.parse(
      File('assets/audio/ku/index.json').readAsStringSync(),
    );
    final missing = <String>[];
    for (final letter in kurmanciAlphabet) {
      final example = alphabetExampleFor(
        letter.letter,
        (text) => catalog.clipForText(text) != null,
      );
      if (example == null) {
        missing.add(letter.letter);
        continue;
      }
      expect(example.termKu.toLowerCase(), contains(letter.letter));
      expect(example.termKu, isNot(contains(' ')));
    }
    expect(missing, isEmpty, reason: 'Örneksiz harfler: $missing');
  });

  testWidgets('dokununca örnek çalar, kaplumbağa yavaş çalar', (tester) async {
    final speaker = _FakeSpeaker();
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: AlphabetScreen(speaker: speaker),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('alphabet-letter-a'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('alphabet-slow-a')));
    await tester.pump();

    expect(speaker.spoken, hasLength(2));
    expect(speaker.spoken.first.toLowerCase(), startsWith('a'));
    expect(speaker.slows, [false, true]);
    // Telaffuz atölyesi alfabeden de açılır.
    expect(find.byKey(const ValueKey('alphabet-mic-a')), findsOneWidget);
  });
}
