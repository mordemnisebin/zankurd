import 'dart:math';

import 'player.dart';

enum RoomStatus { lobby, active, finished }

/// Sunucuda daha önce yanıtlanmış bir oda sorusunun geri yükleme kaydı.
///
/// Doğru seçenek özellikle taşınır: çok oyunculu soruların cevapları ilk
/// yüklemede istemciden gizlenir ve süreç yeniden açıldığında sonuç görünümü
/// yalnız bu yetkili kayıtla yeniden kurulabilir.
class ResumedAnswer {
  const ResumedAnswer({
    required this.questionId,
    required this.questionIndex,
    required this.selectedOptionKey,
    required this.correctOptionKey,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.responseMs,
    this.explanation,
    this.explanationKu,
    this.explanationTr,
  });

  final String questionId;
  final int questionIndex;
  final String selectedOptionKey;
  final String correctOptionKey;
  final bool isCorrect;
  final int pointsAwarded;
  final int responseMs;
  final String? explanation;
  final String? explanationKu;
  final String? explanationTr;
}

/// Henüz sunucu tarafından açılmamış mevcut soru cevabı.
///
/// Bu model bilerek doğruluk, puan ve açıklama taşımaz. İki oyuncu da
/// cevaplayana (veya sunucu süresi dolana) kadar istemci yalnız kendi seçimini
/// geri yükleyebilir.
class ResumedPendingAnswer {
  const ResumedPendingAnswer({
    required this.questionId,
    required this.questionIndex,
    required this.selectedOptionKey,
    required this.responseMs,
  });

  final String questionId;
  final int questionIndex;
  final String selectedOptionKey;
  final int responseMs;
}

/// Aktif bir çevrimiçi odanın yeniden başlatma için gereken yetkili durumu.
class RoomResumeSnapshot {
  RoomResumeSnapshot({
    required this.room,
    required this.currentQuestionIndex,
    required this.ownScore,
    required this.streak,
    required this.bestStreak,
    required this.correctCount,
    required this.wrongCount,
    required List<ResumedAnswer> answers,
    this.pendingAnswer,
    required this.serverNow,
    required this.questionStartedAt,
    required this.deadline,
    required this.remainingMs,
  }) : answers = List.unmodifiable(answers);

  final GameRoom room;
  final int currentQuestionIndex;
  final int ownScore;
  final int streak;
  final int bestStreak;
  final int correctCount;
  final int wrongCount;
  final List<ResumedAnswer> answers;
  final ResumedPendingAnswer? pendingAnswer;
  final DateTime serverNow;
  final DateTime? questionStartedAt;
  final DateTime? deadline;
  final int remainingMs;
}

/// Sunucuda eksiksiz tamamlanmış bir 1v1 maçın kalıcı sonuç snapshot'ı.
///
/// Aktif oda resume verisinden ayrıdır: yalnız terminal indeks, iki oyuncunun
/// kesin skoru ve kullanıcının tüm reveal edilmiş cevaplarıyla kurulabilir.
class RoomResultSnapshot {
  RoomResultSnapshot({
    required this.room,
    required this.ownPlayerId,
    required List<String> questionIds,
    required List<ResumedAnswer> answers,
    required this.winnerId,
    required this.endedReason,
    required this.forfeitedBy,
    required this.finishedAt,
  }) : questionIds = List.unmodifiable(questionIds),
       answers = List.unmodifiable(answers);

  final GameRoom room;
  final String ownPlayerId;
  final List<String> questionIds;
  final List<ResumedAnswer> answers;
  final String? winnerId;
  final String endedReason;
  final String? forfeitedBy;
  final DateTime finishedAt;
}

/// Bitmiş oda ile rakip terkinden doğan hükmen bitişi ayıran küçük model.
class RoomEndState {
  const RoomEndState({
    required this.status,
    required this.endedReason,
    required this.forfeitedBy,
  });

  final RoomStatus status;
  final String? endedReason;
  final String? forfeitedBy;
}

/// `leave_room` transactionının sunucuda kesinleşmiş ham sonucu.
class RoomLeaveOutcome {
  const RoomLeaveOutcome({
    required this.status,
    required this.reason,
    required this.forfeitedBy,
  });

  final String status;
  final String reason;
  final String? forfeitedBy;

  bool get completed => status == 'finished' && reason == 'completed';
}

const roomCodePrefix = 'ZK-';
const roomCodeSuffixLength = 10;
const roomCodeLength = 13;
const _legacyRoomCodeSuffixLength = 4;
const _roomCodePrefixLetterLength = 2;

final _canonicalRoomCodePattern = RegExp(r'^ZK-[0-9A-F]{10}$');
final _legacyRoomCodePattern = RegExp(r'^ZK-[A-HJ-NP-Z2-9]{4}$');

bool _hasExplicitRoomCodePrefix(String input) {
  final upper = input.trimLeft().toUpperCase();
  return upper.length > _roomCodePrefixLetterLength &&
      upper.startsWith('ZK') &&
      !RegExp(r'[A-Z0-9]').hasMatch(upper[_roomCodePrefixLetterLength]);
}

bool _hasCompleteCompactRoomCodePrefix(String compact) {
  if (!compact.startsWith('ZK')) return false;
  final length = compact.length - _roomCodePrefixLetterLength;
  return length == roomCodeSuffixLength ||
      length == _legacyRoomCodeSuffixLength;
}

/// Sunucudaki sözleşmeyle aynı 40-bit oda kodunu üretir.
///
/// Canlı oda oluşturma yetkili SQL RPC'sinde yapılır; bu üretici yalnız yerel
/// depo ve test kabuğu içindir. Yine de iki yolun biçimi ayrışmasın diye aynı
/// `ZK-` + 10 büyük onaltılık karakter sözleşmesini uygular.
String generateRoomCode([Random? random]) {
  const alphabet = '0123456789ABCDEF';
  final rng = random ?? Random.secure();
  final suffix = List.generate(
    roomCodeSuffixLength,
    (_) => alphabet[rng.nextInt(alphabet.length)],
  ).join();
  return '$roomCodePrefix$suffix';
}

/// Elle yazılmış bir oda kodunu `generateRoomCode`un ürettiği biçime çevirir.
///
/// Kod kullanıcıya `ZK-ABCDEF0123` diye gösterilir ama insan onu tireyi atlayarak,
/// küçük harfle ya da araya boşluk koyarak yazar. Katılma alanı bir zamanlar
/// yalnızca `trim().toUpperCase()` yapıyordu; `zkx8wy` yazan kişi "oda
/// bulunamadı" görüyordu — oda oradayken. Kusur 2026-08-01'de iki gerçek
/// cihaz arasında oda kurulup katılınırken bulundu.
///
/// Ayıklama yalnızca biçimseldir: harf/rakam dışını atar, büyütür ve açık
/// ayraçla ya da tam önekli uzunlukla belirlenen `ZK` önekini kaldırır.
/// Tarihsel dört karakterli alfabe `ZK` ile başlayabildiği için kısa bir
/// `ZKAB` girdisi önek sanılmaz. Karakter *düzeltmez* — `0`ı `O` yapmak gibi
/// bir tahmin yanlış odaya sokabilirdi.
String normalizeRoomCode(String input) {
  final compact = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact == 'ZK') return '';
  final hasPrefix =
      _hasExplicitRoomCodePrefix(input) ||
      _hasCompleteCompactRoomCodePrefix(compact);
  final body = hasPrefix
      ? compact.substring(_roomCodePrefixLetterLength)
      : compact;
  if (body.isEmpty) return '';
  return '$roomCodePrefix$body';
}

/// Metin alanında hem önekli hem yalnız sonekli karakter karakter girişi
/// kanonik gösterime taşır. `normalizeRoomCode('Z')` doğrudan çağrı için
/// `ZK-Z` üretirken bu yardımcı `Z`, `ZK` ve `ZK-` ara durumlarını özellikle
/// korur; böylece biçimlendirici kullanıcının yazdığı öneki çoğaltmaz.
String formatRoomCodeInput(String input) {
  final upper = input.toUpperCase();
  final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact.isEmpty) return '';
  if (compact == 'Z') return 'Z';
  if (compact == 'ZK') {
    return _hasExplicitRoomCodePrefix(input) ? roomCodePrefix : 'ZK';
  }
  final hasPrefix =
      _hasExplicitRoomCodePrefix(input) ||
      _hasCompleteCompactRoomCodePrefix(compact);
  if (hasPrefix) {
    return '$roomCodePrefix${compact.substring(_roomCodePrefixLetterLength)}';
  }
  if (compact.startsWith('ZK')) return compact;
  return '$roomCodePrefix$compact';
}

/// Yeni oda üretim sözleşmesini doğrular.
bool isCanonicalRoomCode(String input) {
  return _canonicalRoomCodePattern.hasMatch(input);
}

/// Kullanıcının esnek yazımını normalize ettikten sonra JOIN kapısının
/// geçiş süresinde desteklediği biçimlerden birine uyup uymadığını doğrular.
///
/// Yeni odalar yalnız 10 haneli onaltılık biçimde üretilir. Dört haneli eski
/// biçim, canlı geçişin uygulandığı ve 24 saatlik oda temizliği sonrasında
/// eski aktif lobi kalmadığı ayrıca doğrulanana kadar yalnız JOIN için kabul
/// edilir; yeni kod üretimine geri dönmez.
bool isSupportedRoomCode(String input) {
  final normalized = normalizeRoomCode(input);
  return _canonicalRoomCodePattern.hasMatch(normalized) ||
      _legacyRoomCodePattern.hasMatch(normalized);
}

class GameRoom {
  static const allowedSecondsPerQuestion = [10, 15, 20, 30, 45, 60];
  static const allowedEntryFees = [0, 25, 50, 100];
  static const allowedQuestionCounts = [5, 10, 15];
  static const allowedDurations = [10, 15, 20, 30];
  static const defaultSecondsPerQuestion = 20;

  const GameRoom({
    this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.players,
    required this.status,
    this.questionCount = 10,
    this.secondsPerQuestion = defaultSecondsPerQuestion,
    this.entryFee = 0,
    this.hostId,
  });

  final String? id;
  final String name;
  final String code;
  final String category;
  final List<Player> players;
  final RoomStatus status;
  final int questionCount;
  final int secondsPerQuestion;
  final int entryFee;
  final String? hostId;

  GameRoom copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    List<Player>? players,
    RoomStatus? status,
    int? questionCount,
    int? secondsPerQuestion,
    int? entryFee,
    String? hostId,
  }) {
    return GameRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      players: players ?? this.players,
      status: status ?? this.status,
      questionCount: questionCount ?? this.questionCount,
      secondsPerQuestion: secondsPerQuestion ?? this.secondsPerQuestion,
      entryFee: entryFee ?? this.entryFee,
      // DİKKAT: `?? this.hostId` deseni `hostId`i TEMİZLEYEMEZ. Null
      // geçmek alanı boşaltmaz, eski değeri korur.
      //
      // Bugün bu güvenlidir ve bilerek böyle bırakılıyor: hiçbir çağrı
      // yeri null geçmiyor (`grep 'hostId: null'` boş) ve Supabase yolunda
      // `hostId` her zaman doluyor — `createRoom` onu `auth.currentUser.id`
      // ile, `createOnlineRoom` sunucudan dönen değerle set ediyor. 2026-07-31
      // denetiminde "oda sahipliği düşerse herkes kendini host sanır"
      // iddiası bu yüzden çürütüldü.
      //
      // Ama gizli bir tuzak: ileride sahipliği devretmek ya da boşaltmak
      // gerekirse bu satır sessizce eski sahibi korur ve iki istemci
      // birbirini host sanabilir. O gün geldiğinde çözüm null geçmek değil,
      // ayrı bir `clearHost` bayrağı ya da sentinel değerdir.
      hostId: hostId ?? this.hostId,
    );
  }
}
