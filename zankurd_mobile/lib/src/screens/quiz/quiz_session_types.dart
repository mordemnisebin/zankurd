part of '../quiz_screen.dart';

// A8 ikinci adım (2026-08-26): duruma dokunmayan özel türler ana dosyadan
// ayrıldı. Hiçbir satırın gövdesi değişmedi; yalnız yeri değişti.
//
// A8 üçüncü adım (2026-08-26): süre ve ödül-nötr solo kararı saf işlev
// oldu. Getter'lar bunları çağırır; 1v1/günlük/bot/oda yolu süresiz
// tercihle kapanamaz.

enum QuizExperience { learning, competition }

/// Ödül üretmeyen tek kişilik tur: süre tercihi yalnız burada geçerlidir.
bool isRewardNeutralSoloQuiz({
  required bool is1v1,
  required bool dailyQuiz,
  required bool botRace,
  required bool practice,
  String? roomId,
}) {
  return !is1v1 && !dailyQuiz && !botRace && (practice || roomId == null);
}

/// Sayaç bu turda işlesin mi?
bool quizUsesTimer({
  required bool enableTimer,
  required bool isLearning,
  required bool untimedPreference,
  required bool rewardNeutralSolo,
}) {
  return enableTimer &&
      !isLearning &&
      !(untimedPreference && rewardNeutralSolo);
}

const _defaultSoloRoomName = 'Hevalên Zanînê';

/// Quiz AppBar başlığı: çevrimiçi oda kodu, özel tur adı, yoksa kategori.
String quizRoundTitle({
  required String? roomId,
  required String roomCode,
  required String roomName,
  required String category,
  required bool isKu,
  required String roomWord,
  required String raceWord,
}) {
  if (roomId != null) return '$roomWord $roomCode';
  final name = roomName.trim();
  if (name.isNotEmpty && name != _defaultSoloRoomName) return name;
  if (category.isEmpty) return raceWord;
  return CategoryNames.localized(category, isKu);
}

/// Multiplayer quiz turlarının ortak faz durumu.
enum _MultiplayerPhase {
  /// Oyuncular cevap veriyor.
  answering,

  /// Cevap verildi, diğer oyuncu bekleniyor.
  waiting,

  /// İki oyuncu da cevapladı veya süre bitti; doğru cevap gösteriliyor.
  reveal,
}

enum _OnlineResultPhase { idle, loading, retryableFailure }

typedef _QuizCoinSettlement = ({
  int coinsAwarded,
  bool rewardQueued,
  bool isDurable,
  String ownerUserId,

  /// Sıfır jeton, günlük tavana varıldığı İÇİN mi?
  ///
  /// Sonuç ekranı bunu ayırt edemezse oyuncuya "+0 jeton" gösterip
  /// sebebini söylemez; sıfır tek başına belirsizdir.
  bool dailyCapReached,
});

class _OpponentAnswer {
  const _OpponentAnswer({required this.name, required this.answer});

  final String name;
  final String answer;
}

class _ResolvedResumeAnswer {
  const _ResolvedResumeAnswer({
    required this.answer,
    required this.questionIndex,
    required this.selectedAnswer,
    required this.correctAnswer,
  });

  final ResumedAnswer answer;
  final int questionIndex;
  final String selectedAnswer;
  final String correctAnswer;
}
