import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_audio_service.dart';
import 'package:zankurd_mobile/src/services/tts_service.dart';

QuizQuestion _question({String id = 'q1', String? audioUrl}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'Silav, tu çawa yî?',
  answers: const ['Baş im', 'Na'],
  correctAnswer: 'Baş im',
  explanation: 'Silavdan sonra hal hatır sorulur.',
  audioUrl: audioUrl,
);

class _FakeTts implements QuestionAudioTts {
  _FakeTts({required this.available});

  @override
  final bool available;

  final ValueNotifier<bool> notifier = ValueNotifier(false);
  final spoken = <String>[];
  int stopCalls = 0;

  @override
  bool get isPlaying => notifier.value;

  @override
  ValueListenable<bool> get playingListenable => notifier;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    notifier.value = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    notifier.value = false;
  }
}

class _FakeVerifiedPlayer implements VerifiedQuestionAudioPlayer {
  _FakeVerifiedPlayer({this.throwOnPlay = false});

  final bool throwOnPlay;
  final ValueNotifier<bool> notifier = ValueNotifier(false);
  final played = <VerifiedQuestionAudioClip>[];
  int stopCalls = 0;

  @override
  bool get isPlaying => notifier.value;

  @override
  ValueListenable<bool> get playingListenable => notifier;

  @override
  Future<void> play(VerifiedQuestionAudioClip clip) async {
    played.add(clip);
    if (throwOnPlay) throw StateError('injected verified audio failure');
    notifier.value = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    notifier.value = false;
  }

  @override
  void dispose() {
    notifier.dispose();
  }
}

void main() {
  group('QuestionAudioResolver', () {
    test('doğrulanmış insan sesi TTS desteğinden önce gelir', () {
      final clip = VerifiedQuestionAudioClip(
        questionId: 'q1',
        source: 'assets/audio/verified/q1.mp3',
        location: VerifiedAudioLocation.asset,
        provenance: 'ZanKurd studio recording',
        license: 'owned',
      );
      final resolver = QuestionAudioResolver(
        catalog: VerifiedQuestionAudioCatalog([clip]),
      );

      final selection = resolver.resolve(
        _question(),
        kurmanjiTtsAvailable: true,
      );

      expect(selection.kind, QuestionAudioKind.verifiedNative);
      expect(selection.clip, same(clip));
    });

    test('doğrulanmış kayıt yoksa Kurmancî TTS geri düşüşüdür', () {
      final resolver = QuestionAudioResolver(
        catalog: VerifiedQuestionAudioCatalog.empty,
      );

      final selection = resolver.resolve(
        _question(),
        kurmanjiTtsAvailable: true,
      );

      expect(selection.kind, QuestionAudioKind.kurmanjiTts);
      expect(selection.clip, isNull);
    });

    test('doğrulanmış kayıt ve Kurmancî TTS yoksa ses kullanılamaz', () {
      final resolver = QuestionAudioResolver(
        catalog: VerifiedQuestionAudioCatalog.empty,
      );

      final selection = resolver.resolve(
        _question(),
        kurmanjiTtsAvailable: false,
      );

      expect(selection.kind, QuestionAudioKind.unavailable);
      expect(selection.clip, isNull);
    });

    test('tek başına audioUrl doğrulanmış insan sesi sayılmaz', () {
      final resolver = QuestionAudioResolver(
        catalog: VerifiedQuestionAudioCatalog.empty,
      );

      final selection = resolver.resolve(
        _question(audioUrl: 'https://example.test/unverified.mp3'),
        kurmanjiTtsAvailable: false,
      );

      expect(selection.kind, QuestionAudioKind.unavailable);
    });
  });

  test('doğrulanmış kayıt boş köken veya lisansla oluşturulamaz', () {
    expect(
      () => VerifiedQuestionAudioClip(
        questionId: 'q1',
        source: 'assets/audio/verified/q1.mp3',
        location: VerifiedAudioLocation.asset,
        provenance: ' ',
        license: 'owned',
      ),
      throwsArgumentError,
    );
    expect(
      () => VerifiedQuestionAudioClip(
        questionId: 'q1',
        source: 'assets/audio/verified/q1.mp3',
        location: VerifiedAudioLocation.asset,
        provenance: 'ZanKurd studio recording',
        license: ' ',
      ),
      throwsArgumentError,
    );
  });

  group('QuestionAudioService', () {
    testWidgets('boş doğrulanmış ses kataloğu native audio plugin başlatmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const ttsChannel = MethodChannel('flutter_tts');
      const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var audioGlobalCalls = 0;
      messenger.setMockMethodCallHandler(ttsChannel, (call) async {
        if (call.method == 'getLanguages') return <String>[];
        return 1;
      });
      messenger.setMockMethodCallHandler(audioGlobalChannel, (call) async {
        audioGlobalCalls++;
        return null;
      });
      addTearDown(() {
        TtsService.resetInstance();
        messenger.setMockMethodCallHandler(audioGlobalChannel, null);
      });

      final service = await QuestionAudioService.load(
        catalog: VerifiedQuestionAudioCatalog.empty,
      );
      addTearDown(service.dispose);

      await tester.pump();

      expect(service.canPlay(_question()), isFalse);
      expect(audioGlobalCalls, 0);
    });

    test('doğrulanmış kaydı oynatır ve TTS çağırmaz', () async {
      final clip = VerifiedQuestionAudioClip(
        questionId: 'q1',
        source: 'assets/audio/verified/q1.mp3',
        location: VerifiedAudioLocation.asset,
        provenance: 'ZanKurd studio recording',
        license: 'owned',
      );
      final tts = _FakeTts(available: true);
      final player = _FakeVerifiedPlayer();
      final service = QuestionAudioService(
        resolver: QuestionAudioResolver(
          catalog: VerifiedQuestionAudioCatalog([clip]),
        ),
        tts: tts,
        verifiedPlayer: player,
      );

      await service.toggle(_question());

      expect(player.played, [clip]);
      expect(tts.spoken, isEmpty);
      expect(service.isPlaying, isTrue);
      service.dispose();
    });

    test('kayıt yoksa Kurmancî TTS ile soru metnini söyler', () async {
      final tts = _FakeTts(available: true);
      final player = _FakeVerifiedPlayer();
      final service = QuestionAudioService(
        resolver: QuestionAudioResolver(
          catalog: VerifiedQuestionAudioCatalog.empty,
        ),
        tts: tts,
        verifiedPlayer: player,
      );

      await service.toggle(_question());

      expect(tts.spoken, ['Silav, tu çawa yî?']);
      expect(player.played, isEmpty);
      expect(service.isPlaying, isTrue);
      service.dispose();
    });

    test('doğrulanmış kayıt runtime hatasında Kurmancî TTSye düşer', () async {
      final clip = VerifiedQuestionAudioClip(
        questionId: 'q1',
        source: 'assets/audio/verified/q1.mp3',
        location: VerifiedAudioLocation.asset,
        provenance: 'ZanKurd studio recording',
        license: 'owned',
      );
      final tts = _FakeTts(available: true);
      final player = _FakeVerifiedPlayer(throwOnPlay: true);
      final service = QuestionAudioService(
        resolver: QuestionAudioResolver(
          catalog: VerifiedQuestionAudioCatalog([clip]),
        ),
        tts: tts,
        verifiedPlayer: player,
      );

      await service.toggle(_question());

      expect(player.played, [clip]);
      expect(tts.spoken, ['Silav, tu çawa yî?']);
      expect(service.isPlaying, isTrue);
      service.dispose();
    });

    test('ses yoksa canPlay false ve toggle sessiz no-op olur', () async {
      final tts = _FakeTts(available: false);
      final player = _FakeVerifiedPlayer();
      final service = QuestionAudioService(
        resolver: QuestionAudioResolver(
          catalog: VerifiedQuestionAudioCatalog.empty,
        ),
        tts: tts,
        verifiedPlayer: player,
      );

      expect(service.canPlay(_question()), isFalse);
      await service.toggle(_question());

      expect(tts.spoken, isEmpty);
      expect(player.played, isEmpty);
      expect(service.isPlaying, isFalse);
      service.dispose();
    });

    test('çalarken toggle iki kaynağı da durdurur', () async {
      final tts = _FakeTts(available: true)..notifier.value = true;
      final player = _FakeVerifiedPlayer();
      final service = QuestionAudioService(
        resolver: QuestionAudioResolver(
          catalog: VerifiedQuestionAudioCatalog.empty,
        ),
        tts: tts,
        verifiedPlayer: player,
      );

      await service.toggle(_question());

      expect(tts.stopCalls, 1);
      expect(player.stopCalls, 1);
      expect(service.isPlaying, isFalse);
      service.dispose();
    });
  });
}
