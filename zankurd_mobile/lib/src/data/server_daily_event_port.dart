import '../models/quiz_question.dart';

/// Günün yarışmasının SUNUCU-YETKİLİ akışı (2026-11-16_rekabet_sunum.sql).
///
/// ## Kusur
///
/// Eski akışta sunucu günün 10 gerçek soru kimliğini veriyordu; istemci
/// kimlikleri yerel bankayla eşleyip `correctAnswer`ı pakette buluyor ve
/// değiştirilmiş bir istemci 10 doğruyu sunumdan önce, saniyeler içinde
/// gönderebiliyordu. Süre de sunucuda ölçülmüyordu (ChatGPT Pro denetimi,
/// alan 1 #3 / alan 2 #4).
///
/// ## Kural
///
/// * Oturumu sunucu yaratır ya da kaldığı yerden döndürür ([DailyEventSession]);
///   soru kimliği/içeriği dönmez.
/// * Her soru SUNULDUĞU ANDA sunucudan gelir ([DailyEventPresent]); gerçek
///   kimlik ve doğru şık YOKTUR.
/// * Cevabı sunucu değerlendirir; doğru şık, gerçek kimlik ve açıklama
///   cevaptan SONRA döner ([DailyEventAnswer]).
/// * Süreyi sunucu ölçer (sunum -> cevap, soru başına 20 sn + 5 sn ağ payı).
abstract interface class ServerDailyEventPort {
  /// Günün oturumunu açar ya da devam ettirir. `null`: sunucuda yeni yol yok
  /// (göç uygulanmamış; çağıran eski yola düşer). Ağ/sunucu hatası fırlatır.
  Future<DailyEventSession?> startServerDailyEvent();

  /// Sıradaki soruyu sunar (aynı indeks tekrar çağrılırsa sunum saati
  /// SIFIRLANMAZ; [DailyEventPresent.elapsedMs] kalan süreyi anlatır).
  Future<DailyEventPresent> presentServerDailyQuestion(
    String roundId,
    int index,
  );

  /// Cevabı gönderir ve sunucunun hükmünü alır. Yeniden gönderim güvenlidir
  /// (aynı indeks ilk cevabı döndürür, ikinci puan üretmez).
  Future<DailyEventAnswer> answerServerDailyQuestion({
    required String roundId,
    required int index,
    required String choice,
  });

  /// Bitmiş turun sonucunu oturumun başladığı güne yazar. Geçici hatada
  /// yeniden dener; kalıcı red/vazgeçişte `false`.
  Future<bool> submitServerDailyResult(String roundId);

  /// Son [loadDailyEventQuestions] listesi sunucunun resmî listesinden mi
  /// geldi? `false`: yerel yedek (sonuç sıralamaya YAZILMAZ; antrenman).
  bool get lastDailyEventListWasOfficial;
}

/// `start_verified_daily_v2` yanıtı.
class DailyEventSession {
  const DailyEventSession({
    required this.available,
    this.roundId = '',
    this.day = '',
    this.total = 10,
    this.answered = 0,
    this.correct = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completed = false,
    this.expired = false,
    this.submitted = false,
    this.elapsedMs = 0,
    this.resumed = false,
    this.reason = '',
  });

  /// Sunucunun `available: false` gerekçesi (`before_cutover`: resmî yarışma
  /// henüz başlamadı; boşsa yok/bilinmiyor).
  final String reason;

  /// Resmî yarışma henüz açılmadı (ağ/sunucu hatası DEĞİL).
  bool get beforeCutover => !available && reason == 'before_cutover';

  /// Resmî yarışma bugün açık mı (geçiş gününden önce `false`).
  final bool available;
  final String roundId;
  final String day;
  final int total;
  final int answered;
  final int correct;
  final int currentStreak;
  final int bestStreak;
  final bool completed;
  final bool expired;
  final bool submitted;
  final int elapsedMs;
  final bool resumed;

  /// Oyuna devam edilebilir: bitmemiş ve süresi dolmamış.
  bool get playable => available && !completed && !expired;

  factory DailyEventSession.fromJson(Map<String, dynamic> json) {
    int n(String key, [int fallback = 0]) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return DailyEventSession(
      available: json['available'] == true,
      roundId: json['round_id'] as String? ?? '',
      day: json['day'] as String? ?? '',
      total: n('total', 10),
      answered: n('answered'),
      correct: n('correct'),
      currentStreak: n('current_streak'),
      bestStreak: n('best_streak'),
      completed: json['completed'] == true,
      expired: json['expired'] == true,
      submitted: json['submitted'] == true,
      elapsedMs: n('elapsed_ms'),
      resumed: json['resumed'] == true,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// `present_verified_daily_question` yanıtı: doğru şıksız içerik + sunucu saati.
class DailyEventPresent {
  const DailyEventPresent({
    required this.question,
    required this.elapsedMs,
    this.limitMs = 20000,
  });

  final QuizQuestion question;

  /// Sunumdan bu yana sunucuda geçen süre (devam edilen soruda > 0).
  final int elapsedMs;
  final int limitMs;

  factory DailyEventPresent.fromJson(Map<String, dynamic> json) {
    final raw = json['question'];
    if (raw is! Map) {
      throw const FormatException('Daily present has no question.');
    }
    return DailyEventPresent(
      question: QuizQuestion.fromServerRow(Map<String, dynamic>.from(raw)),
      elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
      limitMs: (json['limit_ms'] as num?)?.toInt() ?? 20000,
    );
  }
}

/// `answer_verified_daily_question` yanıtı: hüküm + cevaptan SONRA açılan alanlar.
class DailyEventAnswer {
  const DailyEventAnswer({
    required this.isCorrect,
    required this.correctOption,
    required this.questionId,
    required this.answered,
    required this.correct,
    required this.completed,
    this.alreadyAnswered = false,
    this.explanation,
    this.explanationKu,
    this.explanationTr,
  });

  final bool isCorrect;
  final String correctOption;
  final String questionId;
  final int answered;
  final int correct;
  final bool completed;
  final bool alreadyAnswered;
  final String? explanation;
  final String? explanationKu;
  final String? explanationTr;

  factory DailyEventAnswer.fromJson(Map<String, dynamic> json) {
    final option = json['correct_option'] as String?;
    if (option == null || !const {'A', 'B', 'C', 'D'}.contains(option)) {
      throw const FormatException('Daily answer has no valid correct option.');
    }
    return DailyEventAnswer(
      isCorrect: json['is_correct'] == true,
      correctOption: option,
      questionId: json['question_id'] as String? ?? '',
      answered: (json['answered'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      alreadyAnswered: json['already_answered'] == true,
      explanation: json['explanation'] as String?,
      explanationKu: json['explanation_ku'] as String?,
      explanationTr: json['explanation_tr'] as String?,
    );
  }
}

/// Oyun ekranına verilen sunucu-yetkili günlük tur bağlamı.
class ServerDailyRound {
  const ServerDailyRound({
    required this.port,
    required this.session,
    required this.firstElapsedMs,
  });

  final ServerDailyEventPort port;
  final DailyEventSession session;

  /// Devam edilen sorunun sunucuda geçen süresi (yeni soruda ~0).
  final int firstElapsedMs;

  String get roundId => session.roundId;
}
