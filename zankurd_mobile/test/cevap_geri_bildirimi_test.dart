import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/services/answer_feedback.dart';

/// Cevap anının ses + titreşimi her modda aynı (Opus–Astra kapışması U18,
/// 2026-10-29).
///
/// Kusur: sırayla düello cevapta hiç ses/titreşim vermiyordu; ana soru
/// ekranı veriyordu. Seviye sınavı hiçbir geri bildirim vermiyordu. Ses
/// testlerde çalınmadığı ve simülatörde çoğu zaman kapalı olduğu için fark
/// edilmedi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> haptics;
  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        });
  });

  Future<void> pumpAndFire(
    WidgetTester tester, {
    required bool correct,
    SoundProvider? sound,
  }) async {
    late BuildContext ctx;
    final child = Builder(
      builder: (c) {
        ctx = c;
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      sound == null
          ? child
          : ChangeNotifierProvider<SoundProvider>.value(
              value: sound,
              child: child,
            ),
    );
    playAnswerFeedback(ctx, correct: correct);
  }

  testWidgets('doğru: orta titreşim + doğru sesi (tek)', (tester) async {
    final sound = _RecordingSound();
    await pumpAndFire(tester, correct: true, sound: sound);
    expect(sound.played, ['correct']);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('yanlış: titreşim + yanlış sesi (tek)', (tester) async {
    final sound = _RecordingSound();
    await pumpAndFire(tester, correct: false, sound: sound);
    expect(sound.played, ['wrong']);
    expect(haptics, hasLength(1));
  });

  testWidgets('ses sağlayıcısı yoksa kırılmaz, titreşim yine verilir', (
    tester,
  ) async {
    await pumpAndFire(tester, correct: true);
    expect(haptics, hasLength(1));
  });

  test('sırayla düello cevabı işlerken geri bildirimi çağırır', () {
    final src = File(
      'lib/src/screens/async_duel/async_duel_play_screen.dart',
    ).readAsStringSync();
    final handler = src.substring(
      src.indexOf('Future<void> _handleAnswerResponse'),
    );
    final body = handler.substring(0, handler.indexOf('\n  }\n'));
    expect(
      'playAnswerFeedback(context, correct: response.correct)'.allMatches(body),
      hasLength(1),
    );
  });

  test(
    'seviye sınavı nötr seçim titreşimi verir, doğru/yanlış sesi vermez',
    () {
      final src = File(
        'lib/src/screens/level_placement_screen.dart',
      ).readAsStringSync();
      final answer = src.substring(src.indexOf('void _answer('));
      final body = answer.substring(0, answer.indexOf('\n  }\n'));
      expect(body, contains('AppHaptics.selection()'));
      expect(body, isNot(contains('playCorrect')));
      expect(body, isNot(contains('playAnswerFeedback')));
    },
  );
}

class _RecordingSound extends SoundProvider {
  final played = <String>[];

  @override
  Future<void> playCorrect() async => played.add('correct');

  @override
  Future<void> playWrong() async => played.add('wrong');
}
