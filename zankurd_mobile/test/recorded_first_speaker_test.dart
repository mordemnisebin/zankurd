import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/services/question_audio_service.dart';
import 'package:zankurd_mobile/src/services/recorded_clip_catalog.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

/// Ses seçim sırasının bekçisi: kayıt > TTS > yok.
///
/// ## Kusur
///
/// Yalnız TTS'e bağlı seslendirme, cihazda `ku` sesi olmadığından (iPhone ve
/// çoğu Android) hiçbir kullanıcıda çalmıyordu. Kayıt varsa TTS yokken de
/// çalmalı; kayıt çalınamazsa TTS'e düşmeli; ikisi de yoksa düğme çıkmamalı.
class _FakeTts implements LessonListeningSpeaker {
  _FakeTts({required this.available});

  @override
  final bool available;
  final List<String> spoken = [];
  int stops = 0;

  @override
  bool availableFor(String text) => available;

  @override
  final ValueNotifier<bool> speakingListenable = ValueNotifier(false);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;
}

class _FakePlayer implements VerifiedQuestionAudioPlayer {
  _FakePlayer({this.fail = false});
  final bool fail;
  final List<VerifiedQuestionAudioClip> played = [];

  @override
  bool get isPlaying => false;

  @override
  final ValueNotifier<bool> playingListenable = ValueNotifier(false);

  @override
  Future<void> play(VerifiedQuestionAudioClip clip) async {
    if (fail) throw StateError('çözücü hatası');
    played.add(clip);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

RecordedClipCatalog _catalog(List<String> texts) => RecordedClipCatalog.parse(
  jsonEncode([
    for (final text in texts)
      {
        'key': kurmanciTextKey(text),
        'text': text,
        'file': '${kurmanciTextKey(text)}.m4a',
        'speaker': 'konuşmacı-1',
        'license': 'CC-BY-4.0',
        'provenance': 'stüdyo kaydı',
      },
  ]),
);

void main() {
  test('kayıt varken TTS yoksa da kullanılabilir ve kayıt çalınır', () async {
    final tts = _FakeTts(available: false);
    final player = _FakePlayer();
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: _catalog(['Rojbaş']),
      player: player,
      fallback: tts,
    );

    expect(speaker.available, isTrue);
    expect(speaker.availableFor('Rojbaş'), isTrue);
    expect(speaker.availableFor('rojbaş!'), isTrue);
    expect(speaker.availableFor('Êvarbaş'), isFalse);

    await speaker.speak('Rojbaş');
    expect(player.played.single.source, endsWith('.m4a'));
    expect(tts.spoken, isEmpty);
  });

  test('kayıt yoksa TTS kullanılır', () async {
    final tts = _FakeTts(available: true);
    final player = _FakePlayer();
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: _catalog(['Rojbaş']),
      player: player,
      fallback: tts,
    );

    expect(speaker.availableFor('Êvarbaş'), isTrue);
    await speaker.speak('Êvarbaş');
    expect(tts.spoken, ['Êvarbaş']);
    expect(player.played, isEmpty);
  });

  test('ne kayıt ne TTS: kullanılamaz ve konuşmaz', () async {
    final tts = _FakeTts(available: false);
    final player = _FakePlayer();
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: RecordedClipCatalog.empty,
      player: player,
      fallback: tts,
    );

    expect(speaker.available, isFalse);
    expect(speaker.availableFor('Rojbaş'), isFalse);
    await speaker.speak('Rojbaş');
    expect(tts.spoken, isEmpty);
    expect(player.played, isEmpty);
  });

  test('kayıt çalınamazsa TTS varsa ona düşer', () async {
    final tts = _FakeTts(available: true);
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: _catalog(['Rojbaş']),
      player: _FakePlayer(fail: true),
      fallback: tts,
    );

    await speaker.speak('Rojbaş');
    expect(tts.spoken, ['Rojbaş']);
  });

  test('kayıt çalınamaz ve TTS de yoksa sessiz kalır, çökmez', () async {
    final tts = _FakeTts(available: false);
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: _catalog(['Rojbaş']),
      player: _FakePlayer(fail: true),
      fallback: tts,
    );

    await speaker.speak('Rojbaş');
    expect(tts.spoken, isEmpty);
  });
}
