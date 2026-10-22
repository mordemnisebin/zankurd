/// Ders slaytı kelime kartları ve harf karoları (2026-10-22).
///
/// ## Neyi korur, niçin sessiz kalırdı
///
/// Slaytlar "• spî: beyaz" madde listesiydi; iki tasarım denetçisi bunu
/// uygulamanın en metin baskın yeri saydı. Biri içeriği yeniden düz
/// `LexiconText`e çevirirse hiçbir test kırılmaz, ekran metin duvarına
/// döner. Bu bekçi kartların, renk lekesinin ve harf karolarının çizildiğini
/// ve METNİN kaybolmadığını (terim + anlam ikisi de ekranda) doğrular.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/widgets/lesson_vocab_tiles.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';

import 'support/widget_test_helpers.dart';

class _Speaker implements LessonListeningSpeaker {
  final spoken = <String>[];
  @override
  bool get available => true;
  @override
  bool availableFor(String text) => true;
  @override
  ValueListenable<bool> get speakingListenable => ValueNotifier(false);
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

Finder _lexiconText(String part) =>
    find.byWidgetPredicate((w) => w is LexiconText && w.text.contains(part));

void main() {
  Future<void> pump(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SingleChildScrollView(child: LessonContentBlocks(text: text)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('madde çiftleri kelime kartı olur, renk adı leke taşır', (
    tester,
  ) async {
    await pump(tester, 'Rengên bingehîn:\n\n• spî: beyaz\n• sor: kırmızı');
    expect(find.byKey(const ValueKey('lesson-vocab-tiles')), findsOneWidget);
    expect(find.text('spî'), findsOneWidget);
    expect(find.text('beyaz'), findsOneWidget);
    expect(find.text('sor'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-vocab-swatch')), findsNWidgets(2));
    expect(_lexiconText('Rengên bingehîn'), findsOneWidget);
  });

  testWidgets('renk olmayan terimde leke yok, soru işaretli terim bölünmez', (
    tester,
  ) async {
    await pump(tester, '• Hûn çawa ne?: Nasılsınız?');
    expect(find.text('Hûn çawa ne?'), findsOneWidget);
    expect(find.text('Nasılsınız?'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-vocab-swatch')), findsNothing);
  });

  testWidgets('tek harflerden oluşan satır harf karosu olur', (tester) async {
    await pump(
      tester,
      'Alfabe:\n\nA B C Ç D E Ê F G H\n\nHeşt tîp dengdêr in.',
    );
    expect(find.byKey(const ValueKey('lesson-letter-tiles')), findsOneWidget);
    expect(find.text('Ç'), findsOneWidget);
    expect(_lexiconText('Heşt tîp'), findsOneWidget);
  });

  // Kurul 2. tur: kartın tamamı dokununca terim seslenir.
  testWidgets('kelime kartına dokununca terim seslenir', (tester) async {
    final speaker = _Speaker();
    LessonAudio.overrideForTesting(speaker);
    addTearDown(() => LessonAudio.overrideForTesting(null));
    await pump(tester, '• spî: beyaz');
    await tester.tap(find.byKey(const ValueKey('lesson-vocab-tile')));
    await tester.pump();
    expect(speaker.spoken, ['spî']);
  });
}
