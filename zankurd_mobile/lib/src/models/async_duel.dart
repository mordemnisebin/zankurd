import 'public_profile.dart';
import 'quiz_question.dart';

/// Sırayla düellodaki oyuncunun rolü.
///
/// Düelloyu açan `creator`dır; açık bekleyen bir düelloya sonradan katılan
/// (ve aynı 7 soruyu oynayan) `opponent`dır. Sunucu bu ayrımı `start_async_duel`
/// RPC'sinin `role` alanıyla bildirir; istemci soruları hangi bağlamda
/// gösterdiğini (ör. "Rakip bekleniyor" mu, yoksa anında karşılaştırma mı)
/// bu değere göre seçer.
enum AsyncDuelRole { creator, opponent }

/// `list_my_async_duels` özetindeki düello durumu.
///
/// `open`: yalnız açan oynadı, rakip henüz katılmadı.
/// `matched`: bir rakip katıldı (oynamayı bitirmiş olabilir ya da olmayabilir).
/// `completed`: iki taraf da bitirdi, sonuç kesinleşti.
/// `expired`: 48 saatlik süre doldu ve rakip hiç çıkmadı.
enum AsyncDuelStatus { open, matched, completed, expired }

/// Bitmiş bir düellonun kazananı — daima ÇAĞIRANIN bakış açısından.
enum AsyncDuelOutcome { win, loss, draw }

AsyncDuelRole _asyncDuelRoleFromJson(Object? value) {
  return switch (value) {
    'creator' => AsyncDuelRole.creator,
    'opponent' => AsyncDuelRole.opponent,
    _ => throw FormatException('Bilinmeyen async duel rolü: $value'),
  };
}

AsyncDuelStatus _asyncDuelStatusFromJson(Object? value) {
  return switch (value) {
    'open' => AsyncDuelStatus.open,
    'matched' => AsyncDuelStatus.matched,
    'completed' => AsyncDuelStatus.completed,
    'expired' => AsyncDuelStatus.expired,
    _ => throw FormatException('Bilinmeyen düello durumu: $value'),
  };
}

AsyncDuelOutcome _asyncDuelOutcomeFromJson(Object? value) {
  return switch (value) {
    'win' => AsyncDuelOutcome.win,
    'loss' => AsyncDuelOutcome.loss,
    'draw' => AsyncDuelOutcome.draw,
    _ => throw FormatException('Bilinmeyen düello sonucu: $value'),
  };
}

/// `answer_async_duel` cevabındaki gömülü `result` nesnesi öncesinde
/// `status` alanını `waiting`/`completed`e ayırır. Sözleşmedeki bu iki
/// değerin dışında bir şey gelirse (şema kayması) sessizce yutmak yerine
/// fırlatır — yanlış bir "bekleniyor" göstermek, hatadan kötüdür.
bool _asyncDuelResultIsWaiting(Object? status) {
  return switch (status) {
    'waiting' => true,
    'completed' => false,
    _ => throw FormatException('Bilinmeyen düello sonuç durumu: $status'),
  };
}

/// `start_async_duel(p_category) returns jsonb` RPC'sinin istemci karşılığı.
///
/// [questions] daima gizli cevapla gelir (`QuizQuestion.hasHiddenAnswer`):
/// sunucu doğru şıkkı yalnız `answer_async_duel` cevaplandıktan sonra
/// açıklar — oda maçlarıyla birebir aynı sözleşme (bkz.
/// `QuizQuestion.fromServerRow`). Şık sırası (A, B, C, D) sunucudaki
/// sırayla korunur; `index` alanı 0..6 arası soru sırasını, `question_ids`
/// dizisiyle aynı sırayı temsil eder.
class AsyncDuelStart {
  AsyncDuelStart({
    required this.duelId,
    required this.role,
    this.opponentName,
    this.opponentId,
    this.invitedId,
    this.opponentProfile,
    this.invitedProfile,
    required this.expiresAt,
    required List<QuizQuestion> questions,
    this.challengeCode,
    this.invitedName,
    this.answeredCount = 0,
    this.alreadyFinished = false,
  }) : questions = List.unmodifiable(questions);

  final String duelId;
  final AsyncDuelRole role;

  /// Yalnız [role] `opponent` iken dolu: düelloyu açanın adı.
  final String? opponentName;

  /// Rakibin / davet edilenin kimliği (`2026-10-21_oyuncu_kimligi.sql`
  /// sonrası dolar; öncesinde null ve ekran baş harfe düşer) ve depo
  /// tarafından tamamlanan herkese açık profilleri (fotoğraf, kod).
  final String? opponentId;
  final String? invitedId;
  final PublicProfile? opponentProfile;
  final PublicProfile? invitedProfile;

  final DateTime expiresAt;
  final List<QuizQuestion> questions;

  /// Yalnız `create_async_duel_challenge` yanıtında dolu: paylaşılacak
  /// `D…` bağlantı kodu ([JoinDeepLink.isChallengeCode]).
  final String? challengeCode;

  /// Yalnız arkadaşa meydan okumada dolu: davet edilen arkadaşın adı.
  final String? invitedName;

  /// Yalnız `accept_async_duel_challenge` yeniden açılışında anlamlı:
  /// benim bu düelloda sunucunun onayladığı cevap sayım. Oyun ekranı kaldığı
  /// sorudan sürer (baştan sorup 'Already answered' almaz).
  final int answeredCount;

  /// Yeniden açılan düelloda 7 sorumu zaten bitirmişim: oyun ekranı
  /// açılmaz, sonuç listesine gidilir.
  final bool alreadyFinished;

  factory AsyncDuelStart.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List;
    return AsyncDuelStart(
      duelId: json['duel_id'] as String,
      role: _asyncDuelRoleFromJson(json['role']),
      opponentName: json['opponent_name'] as String?,
      opponentId: json['opponent_id'] as String?,
      invitedId: json['invited_id'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      questions: rawQuestions
          .map(
            (row) => QuizQuestion.fromServerRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      challengeCode: json['challenge_code'] as String?,
      invitedName: json['invited_name'] as String?,
      answeredCount: (json['answered'] as num?)?.toInt() ?? 0,
      alreadyFinished: json['finished'] as bool? ?? false,
    );
  }

  /// Herkese açık profilleri tamamlanmış kopya (ad boşsa profildeki ad).
  AsyncDuelStart withProfiles({
    PublicProfile? opponent,
    PublicProfile? invited,
  }) => AsyncDuelStart(
    duelId: duelId,
    role: role,
    opponentName: opponentName ?? opponent?.displayName,
    opponentId: opponentId,
    invitedId: invitedId,
    opponentProfile: opponent ?? opponentProfile,
    invitedProfile: invited ?? invitedProfile,
    expiresAt: expiresAt,
    questions: questions,
    challengeCode: challengeCode,
    invitedName: invitedName ?? invited?.displayName,
    answeredCount: answeredCount,
    alreadyFinished: alreadyFinished,
  );
}

/// Oyun ekranının düelloyu NASIL başlattığı.
///
/// * [random]: `start_async_duel` — bekleyen açık düelloya katıl ya da yeni
///   rastgele düello aç (eski davranış).
/// * [createChallenge]: `create_async_duel_challenge` — bağlantı (arkadaş
///   verilmediyse) ya da seçilen arkadaş için taze bir meydan okuma.
/// * [acceptChallenge]: `accept_async_duel_challenge` — `/join/D…`
///   bağlantısındaki ya da gelen kutusundaki kodla meydan okumayı kabul et.
/// * [resume]: `resume_my_async_duel` — yarım bırakılan düelloya kaldığı
///   sorudan devam (gelen kutusundaki "Berdewam bike" satırı).
enum AsyncDuelEntryKind { random, createChallenge, acceptChallenge, resume }

class AsyncDuelEntry {
  const AsyncDuelEntry.random({this.category})
    : kind = AsyncDuelEntryKind.random,
      friendId = null,
      code = null,
      duelId = null;

  const AsyncDuelEntry.createChallenge({this.category, this.friendId})
    : kind = AsyncDuelEntryKind.createChallenge,
      code = null,
      duelId = null;

  const AsyncDuelEntry.acceptChallenge(String this.code)
    : kind = AsyncDuelEntryKind.acceptChallenge,
      category = null,
      friendId = null,
      duelId = null;

  const AsyncDuelEntry.resume(String this.duelId)
    : kind = AsyncDuelEntryKind.resume,
      category = null,
      friendId = null,
      code = null;

  final AsyncDuelEntryKind kind;
  final String? category;
  final String? friendId;
  final String? code;
  final String? duelId;
}

/// Meydan okuma RPC'lerinin sunucu hata metinlerinin istemci sınıflaması
/// (`supabase/2026-10-13_friend_challenge.sql` başlığındaki HATA SÖZLEŞMESİ).
///
/// Oyuncuya her biri için dürüst ve ayrı bir metin gösterilir
/// ([asyncDuelChallengeErrorKey]); [other] bağlantı/sunucu gibi geçici
/// hatalardır ve yeniden denenebilir.
enum AsyncDuelChallengeError {
  notFound,
  own,
  taken,
  expired,
  notForYou,
  notReady,
  notAFriend,
  tooMany,
  noQuestions,
  other,
}

/// [error] içindeki sunucu hata metnine göre sınıf. Metin, PostgREST'in
/// `message` alanında olduğu gibi gelir (`toString()` onu taşır).
AsyncDuelChallengeError classifyAsyncDuelChallengeError(Object error) {
  final text = error.toString();
  if (text.contains('Challenge not found')) {
    return AsyncDuelChallengeError.notFound;
  }
  if (text.contains('Own challenge')) return AsyncDuelChallengeError.own;
  if (text.contains('Challenge already taken')) {
    return AsyncDuelChallengeError.taken;
  }
  if (text.contains('Challenge expired') || text.contains('Duel expired')) {
    return AsyncDuelChallengeError.expired;
  }
  if (text.contains('Challenge not for you')) {
    return AsyncDuelChallengeError.notForYou;
  }
  if (text.contains('Challenge not ready')) {
    return AsyncDuelChallengeError.notReady;
  }
  if (text.contains('Not a friend')) return AsyncDuelChallengeError.notAFriend;
  if (text.contains('Too many open duels')) {
    return AsyncDuelChallengeError.tooMany;
  }
  if (text.contains('No questions')) return AsyncDuelChallengeError.noQuestions;
  return AsyncDuelChallengeError.other;
}

/// Bu hata yeniden denemekle düzelmez (bağlantı artık geçersiz/başkasının):
/// ekran "Yeniden dene" yerine yalnız "Kapat" gösterir.
bool asyncDuelChallengeErrorIsTerminal(AsyncDuelChallengeError error) {
  return switch (error) {
    AsyncDuelChallengeError.notFound ||
    AsyncDuelChallengeError.own ||
    AsyncDuelChallengeError.taken ||
    AsyncDuelChallengeError.expired ||
    AsyncDuelChallengeError.notForYou ||
    AsyncDuelChallengeError.notAFriend => true,
    _ => false,
  };
}

/// PostgREST bir RPC'yi bulamadığında (`PGRST202`, HTTP 404) ya da
/// Postgres fonksiyonu tanımadığında (`42883`) true. Meydan okuma
/// göçü uygulanmamış sunucuda giriş noktaları bu sinyalle gizlenir.
bool isMissingRpcError(Object error) {
  final text = error.toString();
  return text.contains('PGRST202') ||
      text.contains('42883') ||
      text.contains('Could not find the function');
}

/// `answer_async_duel` RPC'sinin tek bir cevap için döndürdüğü sonuç.
///
/// [finished] son (7.) soru cevaplandığında `true` olur; o durumda
/// [result] dolar. Ondan önce [result] daima `null`dır — ara adımlarda
/// rakibin durumu istemciye hiç sızmaz.
class AsyncDuelAnswer {
  const AsyncDuelAnswer({
    required this.correct,
    required this.correctOption,
    required this.answered,
    required this.total,
    required this.finished,
    this.result,
  });

  final bool correct;
  final String correctOption;
  final int answered;
  final int total;
  final bool finished;
  final AsyncDuelResult? result;

  factory AsyncDuelAnswer.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return AsyncDuelAnswer(
      correct: json['correct'] as bool,
      correctOption: json['correct_option'] as String,
      answered: (json['answered'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      finished: json['finished'] as bool,
      result: rawResult == null
          ? null
          : AsyncDuelResult.fromJson(
              Map<String, dynamic>.from(rawResult as Map),
            ),
    );
  }
}

/// Düellonun son sorusu cevaplandığında ortaya çıkan karşılaştırma.
///
/// [waiting] true iken rakip henüz bitirmemiştir: [opponentCorrect],
/// [opponentMs] ve [outcome] hâlâ `null`dır — "Rakip bekleniyor" ekranı bu
/// alanı okur. Rakip de bitirdiğinde (ya da bu cevap zaten bitmiş bir
/// rakibe katılan taraftan geldiğinde) [waiting] `false`e döner ve dördü
/// birden dolar.
class AsyncDuelResult {
  const AsyncDuelResult({
    required this.waiting,
    required this.myCorrect,
    required this.myMs,
    this.opponentCorrect,
    this.opponentMs,
    this.outcome,
  });

  final bool waiting;
  final int myCorrect;
  final int myMs;
  final int? opponentCorrect;
  final int? opponentMs;
  final AsyncDuelOutcome? outcome;

  factory AsyncDuelResult.fromJson(Map<String, dynamic> json) {
    final rawOutcome = json['outcome'];
    return AsyncDuelResult(
      waiting: _asyncDuelResultIsWaiting(json['status']),
      myCorrect: (json['my_correct'] as num).toInt(),
      myMs: (json['my_ms'] as num).toInt(),
      opponentCorrect: (json['opponent_correct'] as num?)?.toInt(),
      opponentMs: (json['opponent_ms'] as num?)?.toInt(),
      outcome: rawOutcome == null
          ? null
          : _asyncDuelOutcomeFromJson(rawOutcome),
    );
  }
}

/// `list_my_async_duels`teki tek bir satır — "Düellolarım" kutusunun
/// gösterdiği özet.
///
/// [myCorrect] yalnız ÇAĞIRAN kendi 7 sorusunu bitirdiyse dolar;
/// [opponentCorrect] yalnız rakip bitirdiyse dolar. İkisi de dolana kadar
/// [outcome] `null` kalır.
class AsyncDuelSummary {
  const AsyncDuelSummary({
    required this.duelId,
    required this.status,
    required this.role,
    this.opponentName,
    this.opponentId,
    this.invitedId,
    this.opponentProfile,
    this.invitedProfile,
    this.categoryName,
    this.myCorrect,
    this.opponentCorrect,
    this.outcome,
    required this.createdAt,
    this.completedAt,
    required this.seen,
    this.challengeCode,
    this.incomingChallenge = false,
    this.invitedName,
  });

  final String duelId;
  final AsyncDuelStatus status;
  final AsyncDuelRole role;
  final String? opponentName;

  /// Bkz. [AsyncDuelStart.opponentId]; sunucu SQL'i uygulanmadıysa null.
  final String? opponentId;
  final String? invitedId;
  final PublicProfile? opponentProfile;
  final PublicProfile? invitedProfile;
  final String? categoryName;
  final int? myCorrect;
  final int? opponentCorrect;
  final AsyncDuelOutcome? outcome;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Bu satırın "sonuç hazır" rozeti için görülüp görülmediği
  /// (`mark_async_duel_seen`).
  final bool seen;

  /// Meydan okuma bağlantı kodu: benim açtığım meydan okumada (yeniden
  /// paylaşmak için) ya da bana gelen kabul edilmemiş meydan okumada (kabul
  /// etmek için) dolu; başkasının kodu sunucudan hiç dönmez.
  final String? challengeCode;

  /// Bana gelen, henüz kabul etmediğim arkadaş meydan okuması ("Sıra sende").
  final bool incomingChallenge;

  /// Yalnız ben yaratıcıysam: davet ettiğim arkadaşın adı (bağlantı
  /// meydan okumasında null).
  final String? invitedName;

  /// Turumu BİTİRMEDİM ve düello hâlâ açık/eşleşmiş: gelen kutusu satırına
  /// dokunmak sonuç değil oyunu açar ([AsyncDuelEntry.resume]).
  ///
  /// Eskiden böyle bir düello ölü bir "Yarım kaldı" satırıydı: süresi dolana
  /// dek hiçbir yerden devam edilemiyor, 5'lik açık-düello sınırında yer
  /// tutuyordu. Süresi dolmuş (`expired`) ve bana gelen kabul edilmemiş
  /// meydan okuma ([incomingChallenge]) kapsam dışıdır.
  bool get canResume =>
      myCorrect == null &&
      !incomingChallenge &&
      (status == AsyncDuelStatus.open || status == AsyncDuelStatus.matched);

  /// Benim açtığım, kimsenin katılmadığı ve turumu bitirdiğim açık düello:
  /// geri çekilebilir ([ZanKurdRepository.cancelAsyncDuel]).
  bool get canCancel =>
      role == AsyncDuelRole.creator &&
      status == AsyncDuelStatus.open &&
      opponentName == null &&
      myCorrect != null;

  /// Benim açtığım, henüz kimsenin almadığı bağlantı meydan okuması (yeniden
  /// paylaşılabilir).
  bool get isWaitingLinkChallenge =>
      role == AsyncDuelRole.creator &&
      challengeCode != null &&
      invitedName == null &&
      opponentName == null &&
      status == AsyncDuelStatus.open;

  factory AsyncDuelSummary.fromJson(Map<String, dynamic> json) {
    final rawOutcome = json['outcome'];
    final rawCompletedAt = json['completed_at'];
    return AsyncDuelSummary(
      duelId: json['duel_id'] as String,
      status: _asyncDuelStatusFromJson(json['status']),
      role: _asyncDuelRoleFromJson(json['role']),
      opponentName: json['opponent_name'] as String?,
      opponentId: json['opponent_id'] as String?,
      invitedId: json['invited_id'] as String?,
      categoryName: json['category_name'] as String?,
      myCorrect: (json['my_correct'] as num?)?.toInt(),
      opponentCorrect: (json['opponent_correct'] as num?)?.toInt(),
      outcome: rawOutcome == null
          ? null
          : _asyncDuelOutcomeFromJson(rawOutcome),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: rawCompletedAt == null
          ? null
          : DateTime.parse(rawCompletedAt as String),
      seen: json['seen'] as bool,
      challengeCode: json['challenge_code'] as String?,
      incomingChallenge: json['incoming_challenge'] as bool? ?? false,
      invitedName: json['invited_name'] as String?,
    );
  }

  /// Herkese açık profilleri tamamlanmış kopya.
  AsyncDuelSummary withProfiles({
    PublicProfile? opponent,
    PublicProfile? invited,
  }) => AsyncDuelSummary(
    duelId: duelId,
    status: status,
    role: role,
    opponentName: opponentName ?? opponent?.displayName,
    opponentId: opponentId,
    invitedId: invitedId,
    opponentProfile: opponent ?? opponentProfile,
    invitedProfile: invited ?? invitedProfile,
    categoryName: categoryName,
    myCorrect: myCorrect,
    opponentCorrect: opponentCorrect,
    outcome: outcome,
    createdAt: createdAt,
    completedAt: completedAt,
    seen: seen,
    challengeCode: challengeCode,
    incomingChallenge: incomingChallenge,
    invitedName: invitedName ?? invited?.displayName,
  );
}
