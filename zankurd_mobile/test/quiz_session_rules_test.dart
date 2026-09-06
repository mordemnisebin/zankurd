import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

/// Quiz süre ve ödül-nötr solo ayrımı `_QuizScreenState` getter'larındaydı.
/// Taşınmadan önce bekçi yoktu: bir 1v1 turu süresiz tercihle sayaçsız
/// kalırsa test yeşil durur, yarış bozulurdu.
void main() {
  test('oda, 1v1, günlük ve bot turu ödül-nötr solo sayılmaz', () {
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: true,
        dailyQuiz: false,
        botRace: false,
        practice: true,
        roomId: null,
      ),
      isFalse,
    );
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: false,
        dailyQuiz: true,
        botRace: false,
        practice: false,
        roomId: null,
      ),
      isFalse,
    );
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: false,
        dailyQuiz: false,
        botRace: true,
        practice: false,
        roomId: null,
      ),
      isFalse,
    );
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: false,
        dailyQuiz: false,
        botRace: false,
        practice: false,
        roomId: 'room-1',
      ),
      isFalse,
    );
  });

  test('çalışma veya çevrimdışı oda ödül-nötr solodur', () {
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: false,
        dailyQuiz: false,
        botRace: false,
        practice: true,
        roomId: 'room-1',
      ),
      isTrue,
    );
    expect(
      isRewardNeutralSoloQuiz(
        is1v1: false,
        dailyQuiz: false,
        botRace: false,
        practice: false,
        roomId: null,
      ),
      isTrue,
    );
  });

  test('öğrenme ve ödüllü tur süresiz tercihi yok sayar', () {
    expect(
      quizUsesTimer(
        enableTimer: true,
        isLearning: true,
        untimedPreference: true,
        rewardNeutralSolo: true,
      ),
      isFalse,
    );
    expect(
      quizUsesTimer(
        enableTimer: true,
        isLearning: false,
        untimedPreference: true,
        rewardNeutralSolo: false,
      ),
      isTrue,
    );
    expect(
      quizUsesTimer(
        enableTimer: true,
        isLearning: false,
        untimedPreference: true,
        rewardNeutralSolo: true,
      ),
      isFalse,
    );
    expect(
      quizUsesTimer(
        enableTimer: false,
        isLearning: false,
        untimedPreference: false,
        rewardNeutralSolo: false,
      ),
      isFalse,
    );
  });

  test('tur başlığı oda kodunu, özel adı veya kategoriyi seçer', () {
    expect(
      quizRoundTitle(
        roomId: 'r1',
        roomCode: 'AB12',
        roomName: 'Günün dersi',
        category: 'Ziman',
        isKu: false,
        roomWord: 'Oda',
        raceWord: 'Yarış',
      ),
      'Oda AB12',
    );
    expect(
      quizRoundTitle(
        roomId: null,
        roomCode: '',
        roomName: 'Günün dersi',
        category: 'Ziman',
        isKu: false,
        roomWord: 'Oda',
        raceWord: 'Yarış',
      ),
      'Günün dersi',
    );
    expect(
      quizRoundTitle(
        roomId: null,
        roomCode: '',
        roomName: 'Hevalên Zanînê',
        category: 'Ziman',
        isKu: false,
        roomWord: 'Oda',
        raceWord: 'Yarış',
      ),
      'Dil',
    );
    expect(
      quizRoundTitle(
        roomId: null,
        roomCode: '',
        roomName: '',
        category: '',
        isKu: true,
        roomWord: 'Ode',
        raceWord: 'Pêşbaz',
      ),
      'Pêşbaz',
    );
  });
}
