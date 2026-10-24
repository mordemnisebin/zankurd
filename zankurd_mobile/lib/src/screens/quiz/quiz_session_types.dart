part of '../quiz_screen.dart';

// A8 ikinci adım (2026-08-26): duruma dokunmayan özel türler ana dosyadan
// ayrıldı. Hiçbir satırın gövdesi değişmedi; yalnız yeri değişti.
//
// A8 üçüncü adım (2026-08-26): süre ve ödül-nötr solo kararı saf işlev
// oldu. Getter'lar bunları çağırır; 1v1/günlük/bot/oda yolu süresiz
// tercihle kapanamaz.

enum QuizExperience { learning, competition }

/// Sözlük dokunuşu açık mı? Başkasıyla puan yarışılan hiçbir akışta açılmaz;
/// bkz. `_lexiconTapAllowed` ve `test/lexicon_lookup_test.dart`.
bool lexiconTapAllowedFor({
  required bool learning,
  required bool practice,
  required bool is1v1,
  required bool botRace,
  required bool dailyQuiz,
  required bool contest,
  required bool versus,
}) {
  if (is1v1 || botRace || dailyQuiz || contest || versus) return false;
  return learning || practice;
}

/// Soru altındaki açılır Türkçe çeviri: rakibin olmadığı her tek kişilik
/// turda açık (konu karosundan açılan normal tur dahil; sözlük dokunuşu orada
/// kapalı olduğu için ona bağlanmadı). Düello, bot yarışı, günün soruları,
/// yarışma ve çevrimiçi oda kapalıdır: orada çeviri başkasına karşı ipucudur.
bool translationRevealAllowedFor({
  required bool is1v1,
  required bool botRace,
  required bool dailyQuiz,
  required bool contest,
  required bool versus,
  required bool onlineRoom,
}) => !(is1v1 || botRace || dailyQuiz || contest || versus || onlineRoom);

/// Yanlış cevaptan HEMEN sonra doğru cevap + açıklama gösterilsin mi?
///
/// Kural [translationRevealAllowedFor] ile AYNIDIR ve bilerek ona bağlı:
/// rakibin olmadığı her tek kişilik tur (solo, öğrenme, alıştırma). Düello,
/// bot yarışı, günün turu, yarışma ve çevrimiçi odada KAPALIDIR — orada
/// cevap, rakibe karşı puanlanan bir turun içindedir ve anında açıklama
/// hem ritmi keser hem de (sunucu cevabı gizlediği odalarda) cevabı sızdırır.
/// Kuralı ikiye bölmek, çeviri açıkken açıklamanın kapalı kalması gibi
/// tutarsız bir ürün çıkarırdı; bekçi: `test/wrong_answer_insight_test.dart`.
bool instantExplanationAllowedFor({
  required bool is1v1,
  required bool botRace,
  required bool dailyQuiz,
  required bool contest,
  required bool versus,
  required bool onlineRoom,
}) => translationRevealAllowedFor(
  is1v1: is1v1,
  botRace: botRace,
  dailyQuiz: dailyQuiz,
  contest: contest,
  versus: versus,
  onlineRoom: onlineRoom,
);

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
  String? crowdTitle,
}) {
  if (roomId != null) return '$roomWord $roomCode';
  final name = roomName.trim();
  // Depo, kalabalık odayı 'crowd', ikili odayı '1vs1' diye adlandırır
  // (`_roomDisplayName`): bunlar KİMLİKTİR, başlık değil. Sonuç ekranının
  // tepesinde "crowd • 10 soru" diye ham basılıyordu (2026-10-21 iki
  // simülatör turu). Kalabalık odası dilindeki adıyla, ikili oda genel
  // "yarış" sözüyle çizilir.
  if (name == 'crowd' && crowdTitle != null) return crowdTitle;
  final isSlug = name == 'crowd' || name == '1vs1';
  if (name.isNotEmpty && name != _defaultSoloRoomName && !isSlug) return name;
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
