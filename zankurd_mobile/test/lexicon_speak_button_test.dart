import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_speak_button.dart';

/// Ses düğmesinin yalnız ses VARKEN çizildiğinin bekçisi: ses yokken sözlük
/// ve kelime balonu bugünkü hâliyle aynı kalmalı.
class _Speaker implements LessonListeningSpeaker {
  _Speaker(this.playable);
  final Set<String> playable;
  final List<String> spoken = [];

  @override
  bool get available => playable.isNotEmpty;

  @override
  bool availableFor(String text) => playable.contains(text);

  @override
  final ValueNotifier<bool> speakingListenable = ValueNotifier(false);

  @override
  Future<void> speak(String text, {bool slow = false}) async =>
      spoken.add(text);

  @override
  Future<void> stop() async {}
}

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  tearDown(() => LessonAudio.overrideForTesting(null));

  testWidgets('ses yokken düğme yer kaplamaz', (tester) async {
    await tester.pumpWidget(
      _wrap(LexiconSpeakButton(text: 'Rojbaş', speaker: _Speaker({}))),
    );
    expect(find.byKey(const ValueKey('lexicon-speak')), findsNothing);
  });

  testWidgets('ses varken düğme çıkar ve ifadeyi seslendirir', (tester) async {
    final speaker = _Speaker({'Rojbaş'});
    await tester.pumpWidget(
      _wrap(LexiconSpeakButton(text: 'Rojbaş', speaker: speaker)),
    );
    await tester.tap(find.byKey(const ValueKey('lexicon-speak')));
    expect(speaker.spoken, ['Rojbaş']);
  });

  testWidgets('sözlük listesinde yalnız sesi olan madde düğme alır', (
    tester,
  ) async {
    LessonAudio.overrideForTesting(_Speaker({'Rojbaş'}));
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LearnerLexiconScreen(initialQuery: 'Rojbaş'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lexicon-speak')), findsOneWidget);
  });

  testWidgets('sözlükte ses yokken düğme yok', (tester) async {
    LessonAudio.overrideForTesting(_Speaker({}));
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LearnerLexiconScreen(initialQuery: 'Rojbaş'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lexicon-speak')), findsNothing);
  });

  testWidgets('kelime balonunda ses varken düğme çıkar', (tester) async {
    LessonAudio.overrideForTesting(_Speaker({'Rojbaş'}));
    const entry = LearnerLexiconEntry(
      id: 'rojbas',
      termKu: 'Rojbaş',
      meaningTr: 'Günaydın / İyi günler',
      sourceId: 'everyday_1',
    );
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLexiconEntrySheet(context, entry),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lexicon-entry-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('lexicon-speak')), findsOneWidget);
  });
}
