import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/favorite_mutation_service.dart';

const _question = QuizQuestion(
  id: 'fav-1',
  category: 'Ziman',
  prompt: 'Pirs?',
  answers: ['a', 'b'],
  correctAnswer: 'a',
  explanation: '',
);

class _RecordingRepository extends MockZanKurdRepository {
  final calls = <bool>[];

  @override
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite) {
    calls.add(favorite);
    return Future.value(favorite);
  }
}

class _FailingRepository extends MockZanKurdRepository {
  @override
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite) =>
      Future.error(StateError('ağ yok'));
}

/// Servis testsizdi (2026-10-25 altyapı taraması). Sözleşme: başarıda depo
/// sonucu döner; hatada hata YİNE fırlatılır ki ekran başarı göstermesin.
void main() {
  test('başarıda depo sonucunu döndürür', () async {
    final repository = _RecordingRepository();
    final result = await FavoriteMutationService.setFavorite(
      repository: repository,
      question: _question,
      favorite: true,
    );
    expect(result, isTrue);
    expect(repository.calls, [true]);
  });

  test('hatada hatayı yeniden fırlatır (sahte başarı yok)', () async {
    await expectLater(
      FavoriteMutationService.setFavorite(
        repository: _FailingRepository(),
        question: _question,
        favorite: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
