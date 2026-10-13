import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/services/question_audio_service.dart';
import 'package:zankurd_mobile/src/services/recorded_clip_catalog.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';
import 'package:zankurd_mobile/src/widgets/lesson_listening_card.dart';

class _FakeSpeaker implements LessonListeningSpeaker {
  _FakeSpeaker({this.available = true, this.only});

  @override
  final bool available;

  /// Doluysa yalnız bu ifadelerin sesi vardır (kısmi kayıt).
  final Set<String>? only;

  @override
  bool availableFor(String text) => available && (only?.contains(text) ?? true);

  @override
  final ValueNotifier<bool> speakingListenable = ValueNotifier(false);

  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    speakingListenable.value = false;
  }
}

const _entries = [
  LearnerLexiconEntry(
    id: 'rojbas',
    termKu: 'Rojbaş',
    meaningTr: 'Günaydın / İyi günler',
    sourceId: 'everyday_1',
  ),
  LearnerLexiconEntry(
    id: 'evarbas',
    termKu: 'Êvarbaş',
    meaningTr: 'İyi akşamlar',
    sourceId: 'everyday_1',
  ),
  LearnerLexiconEntry(
    id: 'sevbas',
    termKu: 'Şevbaş',
    meaningTr: 'İyi geceler',
    sourceId: 'everyday_1',
  ),
];

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('güvenli Kurmancî TTS yoksa dinleme kartı görünmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LessonListeningCard(
          entries: _entries,
          speaker: _FakeSpeaker(available: false),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('lesson-listening-card')), findsNothing);
  });

  testWidgets('önce sesi dinletir, Kurmancî terimi cevaptan önce gizler', (
    tester,
  ) async {
    final speaker = _FakeSpeaker();
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );

    expect(find.byKey(const ValueKey('lesson-listening-card')), findsOneWidget);
    expect(find.text('Rojbaş'), findsNothing);
    expect(find.text('Günaydın / İyi günler'), findsNothing);
    expect(find.text('İyi akşamlar'), findsNothing);
    expect(find.text('İyi geceler'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    expect(speaker.spoken, ['Rojbaş']);
    expect(find.text('Günaydın / İyi günler'), findsOneWidget);
    expect(find.text('İyi akşamlar'), findsOneWidget);
    expect(find.text('İyi geceler'), findsOneWidget);

    await tester.tap(find.text('Günaydın / İyi günler'));
    await tester.pump();
    expect(find.text('Rojbaş'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
  });

  testWidgets('sonraki dinleme öğesi terimi yeniden gizler', (tester) async {
    final speaker = _FakeSpeaker();
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );

    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    await tester.tap(find.text('Günaydın / İyi günler'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lesson-listening-next')));
    await tester.pump();

    expect(find.text('Rojbaş'), findsNothing);
    expect(find.text('Êvarbaş'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    expect(speaker.spoken.last, 'Êvarbaş');
  });

  testWidgets('yanlış cevapta doğru Kurmancî Türkçe çifti açıkça gösterilir', (
    tester,
  ) async {
    final speaker = _FakeSpeaker();
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );

    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    await tester.tap(find.text('İyi akşamlar'));
    await tester.pump();

    expect(find.text('Yanlış'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-listening-term')), findsOneWidget);
    expect(find.text('Rojbaş'), findsOneWidget);
    final answer = tester.widget<Text>(
      find.byKey(const ValueKey('lesson-listening-answer')),
    );
    expect(answer.data, 'Günaydın / İyi günler');
  });

  testWidgets('yalnız kaydı olan öğeler sorulur; TTS yokken de oynat çıkar', (
    tester,
  ) async {
    // Kayıt kataloğu `RecordedFirstLessonListeningSpeaker` ile TTS'siz de
    // `available` verir; kartın işi ifade başına süzmektir.
    final speaker = _FakeSpeaker(only: {'Êvarbaş', 'Şevbaş'});
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );

    expect(find.byKey(const ValueKey('lesson-listening-play')), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    expect(speaker.spoken, ['Êvarbaş']);
    // Kaydı olmayan 'Günaydın' şıklarda çıkmaz.
    expect(find.text('Günaydın / İyi günler'), findsNothing);
  });

  testWidgets('seslendirilebilir öğe ikiden azsa kart görünmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LessonListeningCard(
          entries: _entries,
          speaker: _FakeSpeaker(only: {'Rojbaş'}),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('lesson-listening-card')), findsNothing);
  });

  testWidgets('kayıt var, TTS yok: kart oynat düğmesini gösterir', (
    tester,
  ) async {
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: RecordedClipCatalog.parse(
        jsonEncode([
          for (final text in ['Rojbaş', 'Êvarbaş'])
            {
              'key': kurmanciTextKey(text),
              'text': text,
              'file': '${kurmanciTextKey(text)}.m4a',
              'speaker': 'konuşmacı-1',
              'license': 'CC-BY-4.0',
              'provenance': 'stüdyo kaydı',
            },
        ]),
      ),
      player: NoopVerifiedQuestionAudioPlayer(),
      fallback: _FakeSpeaker(available: false),
    );
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );
    expect(find.byKey(const ValueKey('lesson-listening-play')), findsOneWidget);
  });

  testWidgets('ne kayıt ne TTS: kart görünmez', (tester) async {
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: RecordedClipCatalog.empty,
      player: NoopVerifiedQuestionAudioPlayer(),
      fallback: _FakeSpeaker(available: false),
    );
    await tester.pumpWidget(
      _wrap(LessonListeningCard(entries: _entries, speaker: speaker)),
    );
    expect(find.byKey(const ValueKey('lesson-listening-card')), findsNothing);
  });
}
