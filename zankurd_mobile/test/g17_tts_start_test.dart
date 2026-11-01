import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/services/question_audio_service.dart';
import 'package:zankurd_mobile/src/services/recorded_clip_catalog.dart';
import 'package:zankurd_mobile/src/services/tts_service.dart';
import 'package:zankurd_mobile/src/widgets/lesson_listening_card.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

import 'support/widget_test_helpers.dart';

class _BrokenRecording extends NoopVerifiedQuestionAudioPlayer {
  int calls = 0;
  @override
  Future<void> play(VerifiedQuestionAudioClip clip, {double rate = 1}) async {
    calls++;
    throw StateError('recording failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var outcome = 'exception';
  var calls = 0;
  Completer<Object?>? response;

  Future<void> event(String method) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, 'failure'),
      ),
      (_) {},
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    outcome = 'exception';
    calls = 0;
    response = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLanguages') return ['ku'];
      if (call.method != 'speak') return 1;
      calls++;
      switch (outcome) {
        case 'exception':
          throw PlatformException(code: 'tts_failure');
        case 'reject':
          return 0;
        case 'error':
          await event('speak.onError');
        case 'cancel':
          await event('speak.onCancel');
        case 'complete':
          await event('speak.onComplete');
        case 'start':
          await event('speak.onStart');
        case 'pending':
          return (response = Completer<Object?>()).future;
      }
      return 1;
    });
  });
  tearDown(() {
    TtsService.resetInstance();
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final failure in [
    'exception',
    'reject',
    'error',
    'cancel',
    'complete',
    'silent',
    'pending',
  ]) {
    testWidgets(
      'G17: $failure dinlendi sayılmaz; sahte adaptör testi gerçek TTS hatasını gizliyordu',
      (tester) async {
        outcome = failure;
        final service = await TtsService.load();
        final speaker = TtsLessonListeningSpeaker(service);
        expect(speaker.available, isTrue);
        bool? result;
        unawaited(speaker.speak('Rojbaş').then((value) => result = value));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(result, isFalse);
        expect(service.isSpeaking, isFalse);
      },
    );
  }

  testWidgets(
    'G17: kabul tek başına başarı değildir; başlangıç olayı eski testlerde sınanmıyordu',
    (tester) async {
      outcome = 'silent';
      final service = await TtsService.load();
      bool? result;
      unawaited(
        TtsLessonListeningSpeaker(
          service,
        ).speak('Rojbaş').then((value) => result = value),
      );
      await tester.pump();
      expect(result, isNull);
      await event('speak.onStart');
      await tester.pump();
      expect(result, isTrue);
      expect(service.isSpeaking, isTrue);
      await event('speak.onComplete');
      expect(service.isSpeaking, isFalse);
    },
  );

  testWidgets(
    'G17: boş veya sessiz istek başarı değildir; eski adaptör koşulsuz true dönüyordu',
    (tester) async {
      final service = await TtsService.load();
      final speaker = TtsLessonListeningSpeaker(service);
      expect(await speaker.speak('  '), isFalse);
      await service.setVolume(0);
      expect(await speaker.speak('Rojbaş'), isFalse);
      await service.setEnabled(false);
      expect(await speaker.speak('Rojbaş'), isFalse);
      expect(calls, 0);
    },
  );

  testWidgets(
    'G17: geç motor yanıtı ve iptal başarı değildir; yalnız anlık yanıt sınanıyordu',
    (tester) async {
      outcome = 'pending';
      final service = await TtsService.load();
      bool? result;
      unawaited(
        TtsLessonListeningSpeaker(
          service,
        ).speak('Rojbaş').then((value) => result = value),
      );
      await tester.pump();
      await service.stop();
      response!.complete(1);
      await event('speak.onStart');
      await tester.pump();
      expect(result, isFalse);
      expect(service.isSpeaking, isFalse);
    },
  );

  for (final recordedFirst in [false, true]) {
    testWidgets(
      'G17: kayıt geri düşüşü=$recordedFirst TTS hatasında şıklar kilitli; yalnız sahte speaker sınanıyordu',
      (tester) async {
        final fallback = TtsLessonListeningSpeaker(await TtsService.load());
        final recording = _BrokenRecording();
        final speaker = recordedFirst
            ? RecordedFirstLessonListeningSpeaker(
                catalog: RecordedClipCatalog.parse(
                  jsonEncode([
                    {
                      'key': kurmanciTextKey('Rojbaş'),
                      'text': 'Rojbaş',
                      'file': 'rojbas.m4a',
                      'speaker': 'test',
                      'license': 'CC0',
                      'provenance': 'test',
                    },
                  ]),
                ),
                player: recording,
                fallback: fallback,
              )
            : fallback;
        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: LessonListeningCard(
                entries: const [
                  LearnerLexiconEntry(
                    id: 'rojbas',
                    termKu: 'Rojbaş',
                    meaningTr: 'Günaydın',
                    sourceId: 'everyday_1',
                  ),
                  LearnerLexiconEntry(
                    id: 'evarbas',
                    termKu: 'Êvarbaş',
                    meaningTr: 'İyi akşamlar',
                    sourceId: 'everyday_1',
                  ),
                ],
                speaker: speaker,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
        await tester.pump();
        expect(calls, 1);
        expect(recording.calls, recordedFirst ? 1 : 0);
        expect(
          find.byKey(const ValueKey('lesson-listening-option-rojbas')),
          findsNothing,
        );
        expect(
          find.text('Seslendirme bu cihazda kullanılamıyor.'),
          findsOneWidget,
        );
        outcome = 'start';
        await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('lesson-listening-option-rojbas')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
