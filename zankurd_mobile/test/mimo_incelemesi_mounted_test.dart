// MiMo incelemesi (2026-10-17): iki `await` sonrası `setState` kusuru.
//
// Kusur: `RoomScreen._startGameHost` `startGame` beklemesinden sonra, ekran
// kapanmış olsa bile `_navigateToQuiz()`ı çağırıyordu; o da ilk satırda
// `setState` yapıyordu. `QuizResultScreen._checkNotifPrompt` de
// `shouldShow()` beklemesinden sonra `mounted` bakmadan `setState` yapıyordu.
// Sessiz kaldılar: ikisi de bir `try/catch` içinde (`ErrorReporter.record` /
// boş `catch`) olduğundan "setState() called after dispose" hatası
// yutuluyor, ekranda ya da testte hiçbir iz bırakmıyordu; widget testiyle de
// gözlenemez (iki yol da aynı görünür sonucu verir), bu yüzden kaynak bekçisi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _body(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: signature);
  return source.substring(start, start + 900);
}

void main() {
  test('startGame beklemesinden sonra mounted bakılır', () {
    final src = File('lib/src/screens/room_screen.dart').readAsStringSync();
    final host = _body(src, 'Future<void> _startGameHost()');
    expect(
      RegExp(
        r'await widget\.repository\.startGame\(room\);\s+if \(!mounted\) return;\s+_navigateToQuiz\(\);',
      ).hasMatch(host),
      isTrue,
    );
    final nav = _body(src, 'Future<void> _navigateToQuiz()');
    expect(nav.contains('if (!mounted || quizOpened) return;'), isTrue);
  });

  test('bildirim kartı shouldShow beklemesinden sonra mounted bakar', () {
    final src = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final body = _body(src, 'Future<void> _checkNotifPrompt()');
    expect(
      RegExp(
        r'await policy\.shouldShow\(\);\s+if \(!mounted\) return;\s+if \(show\)',
      ).hasMatch(body),
      isTrue,
    );
  });
}
