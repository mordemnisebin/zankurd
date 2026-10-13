import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quiz dinleme akışı yalnız QuestionAudioService üzerinden gider', () {
    final quiz = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    final widgets = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(quiz, contains("services/question_audio_service.dart"));
    expect(quiz, contains('QuestionAudioService? _questionAudioService'));
    expect(quiz, contains('QuestionAudioService.load()'));
    expect(quiz, contains('_questionAudioService?.canPlay(question) ?? false'));
    expect(quiz, isNot(contains('TtsService.instance')));

    expect(widgets, contains('ValueListenable<bool> listeningListenable'));
    expect(widgets, isNot(contains('TtsService.instance')));
  });
}
