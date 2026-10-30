import 'dart:math';

import 'player.dart';
import '../game/reveal_timing.dart';

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
    this.revealClock,
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

  /// Null: göç uygulanmamış sunucu; eski beş saniyelik sözleşme.
  final ServerRevealClock? revealClock;
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
    this.newHostId,
  });

  final String status;
  final String reason;
  final String? forfeitedBy;

  /// Kalabalık lobide host çıkınca sunucunun devrettiği yeni host
  /// (`reason: 'host_transferred'`); başka durumda `null`.
  final String? newHostId;

  bool get completed => status == 'finished' && reason == 'completed';
  bool get hostTransferred => reason == 'host_transferred';
}

/// Oyuncu kalabalık odadan düşürüldü: `mark_room_client_ready` süre dolunca
/// hazır olmayanı `left_at` ile oyundan çıkarır ve ona `status: 'left'` döner.
/// Oyun diğerleriyle sürer; bu oyuncunun odada yapacağı bir şey kalmadı.
class RoomMemberLeftException implements Exception {
  const RoomMemberLeftException();

  @override
  String toString() => 'RoomMemberLeftException: player left the room';
}

/// `get_room_answer_progress` sonucu: mevcut soruyu kaç aktif oyuncunun
/// cevapladığı (yalnız sayılar; kim olduğu ya da seçtiği şık sızmaz).
///
/// [questionIndex] cevabın geldiği soruyu söyler: istemci başka bir sorudaysa
/// (cevap yolda geç kaldı) sayıyı göstermez.
class RoomAnswerProgress {
  const RoomAnswerProgress({
    required this.questionIndex,
    required this.answered,
    required this.active,
  });

  final int questionIndex;
  final int answered;
  final int active;

  /// Sunucu cevabından; eksik ya da tipi bozuk alan `null` (sayaç gizlenir,
  /// oyun etkilenmez).
  static RoomAnswerProgress? tryParse(Object? json) {
    if (json is! Map) return null;
    final index = json['question_index'];
    final answered = json['answered'];
    final active = json['active'];
    if (index is! num || answered is! num || active is! num) return null;
    if (active < 1 || answered < 0) return null;
    return RoomAnswerProgress(
      questionIndex: index.toInt(),
      answered: answered.toInt().clamp(0, active.toInt()),
      active: active.toInt(),
    );
  }
}

/// `touch_matchmaking` RPC'sinin sonucu.
enum MatchmakingTouchStatus {
  /// Kuyruk satırı yenilendi, hâlâ rakip bekleniyor.
  waiting,

  /// Eşleşme olmuş; [MatchmakingTouch.roomId] dolu.
  matched,

  /// Sunucu açıkça söyledi: ne oda ne bekleyen satır var (satır bayat diye
  /// silinmiş olabilir); bekleyen istemci kuyruğa yeniden girmeli.
  none,

  /// RPC yok ya da cevap tanınmadı; istemci eski yolda kalır, yeniden girmez.
  unknown,
}

/// Bekleyen oyuncunun kalp atışı + eşleşme yoklaması sonucu.
class MatchmakingTouch {
  const MatchmakingTouch.waiting()
    : status = MatchmakingTouchStatus.waiting,
      roomId = null,
      opponentName = null;

  const MatchmakingTouch.none()
    : status = MatchmakingTouchStatus.none,
      roomId = null,
      opponentName = null;

  const MatchmakingTouch.unknown()
    : status = MatchmakingTouchStatus.unknown,
      roomId = null,
      opponentName = null;

  const MatchmakingTouch.matched({
    required String this.roomId,
    this.opponentName,
  }) : status = MatchmakingTouchStatus.matched;

  /// Sunucu cevabından tipli sonuç. Tanınmayan ya da eksik cevap [none]
  /// sayılır: yoklama yalnız bir emniyet yoludur, ekranı çökertmemeli.
  factory MatchmakingTouch.fromJson(Object? json) {
    if (json is! Map) return const MatchmakingTouch.unknown();
    switch (json['status']) {
      case 'waiting':
        return const MatchmakingTouch.waiting();
      case 'matched':
        final roomId = json['room_id'];
        if (roomId is! String || roomId.trim().isEmpty) {
          return const MatchmakingTouch.unknown();
        }
        final opponent = json['opponent_name'];
        return MatchmakingTouch.matched(
          roomId: roomId,
          opponentName: opponent is String ? opponent : null,
        );
      case 'none':
        return const MatchmakingTouch.none();
      default:
        return const MatchmakingTouch.unknown();
    }
  }

  final MatchmakingTouchStatus status;
  final String? roomId;
  final String? opponentName;
}

/// Eski (2026-10-18 öncesi) oda kodu öneki. Yeni kodlar önek taşımaz.
const roomCodePrefix = 'ZK-';
const roomCodeSuffixLength = 10;

/// Yeni oda kodunun uzunluğu: 6 rakam (örn. 482913). Sesli söylenir,
/// "482 913" diye gruplanıp gösterilir. 13 karakterlik `ZK-` + onaltılık
/// kod test kullanıcılarına söylenemiyordu.
const roomCodeLength = 6;
const _legacyRoomCodeSuffixLength = 4;
const _roomCodePrefixLetterLength = 2;

final _canonicalRoomCodePattern = RegExp(r'^[1-9][0-9]{5}$');
final _legacyHexRoomCodePattern = RegExp(r'^ZK-[0-9A-F]{10}$');
final _legacyRoomCodePattern = RegExp(r'^ZK-[A-HJ-NP-Z2-9]{4}$');
final _digitsOnlyPattern = RegExp(r'^[0-9]+$');
final _joinLinkPattern = RegExp(r'/join/([^/?#\s]+)', caseSensitive: false);

/// Yapıştırılan `https://www.zankurd.com/join/482913` bağlantısından kodu
/// çıkarır; bağlantı değilse girdiyi olduğu gibi verir.
String _extractRoomCodeFromLink(String input) {
  final match = _joinLinkPattern.firstMatch(input);
  return match == null ? input : match.group(1)!;
}

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

/// Yalnız rakamlardan oluşan girdi yeni (6 haneli) koddur; tek istisna 10
/// rakamdır: o, soneki yalnız rakamdan ibaret eski `ZK-` onaltılık kodudur.
bool _isNumericRoomCodeInput(String compact) =>
    compact.isNotEmpty &&
    _digitsOnlyPattern.hasMatch(compact) &&
    compact.length != roomCodeSuffixLength;

/// Yeni oda kodunu üretir: 6 rakam, ilk hane 1-9.
///
/// Canlı oda oluşturma yetkili SQL RPC'sinde yapılır (`create_online_room_v2`);
/// bu üretici yalnız yerel depo ve test kabuğu içindir. Biçim sunucuyla aynı.
String generateRoomCode([Random? random]) {
  final rng = random ?? Random.secure();
  final first = 1 + rng.nextInt(9);
  final rest = List.generate(roomCodeLength - 1, (_) => rng.nextInt(10)).join();
  return '$first$rest';
}

/// Elle yazılmış bir oda kodunu sunucunun beklediği biçime çevirir.
///
/// Yeni kod 6 rakamdır; kullanıcı onu "482 913", "482-913" ya da
/// `zankurd.com/join/482913` bağlantısı olarak yazıp yapıştırabilir: bu
/// biçimlerin hepsi `482913` olur. Eski odalardaki `ZK-ABCDEF0123` kodu
/// da çalışır: tireyi atlayan, küçük harfle yazan ya da yalnız soneki
/// yazan kullanıcı yine kanonik `ZK-…` biçimine çevrilir.
///
/// Ayıklama yalnızca biçimseldir: harf/rakam dışını atar, büyütür ve açık
/// ayraçla ya da tam önekli uzunlukla belirlenen `ZK` önekini kaldırır.
/// Karakter *düzeltmez* — `0`ı `O` yapmak gibi bir tahmin yanlış odaya
/// sokabilirdi.
String normalizeRoomCode(String input) {
  final source = _extractRoomCodeFromLink(input);
  final compact = source.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (_isNumericRoomCodeInput(compact)) return compact;
  if (compact == 'ZK') return '';
  final hasPrefix =
      _hasExplicitRoomCodePrefix(source) ||
      _hasCompleteCompactRoomCodePrefix(compact);
  final body = hasPrefix
      ? compact.substring(_roomCodePrefixLetterLength)
      : compact;
  if (body.isEmpty) return '';
  return '$roomCodePrefix$body';
}

/// Metin alanında girişi gösterim biçimine taşır.
///
/// Rakam girişi 6 haneye kesilir ve "482 913" diye gruplanır (boşluk yalnız
/// gösterim; `normalizeRoomCode` onu atar). Harf içeren (eski `ZK-…`) giriş
/// kesilmeden kanonik eski biçime çekilir: `Z`, `ZK`, `ZK-` ara durumları
/// korunur, önek çoğaltılmaz.
String formatRoomCodeInput(String input) {
  final source = _extractRoomCodeFromLink(input);
  final upper = source.toUpperCase();
  final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact.isEmpty) return '';
  if (_isNumericRoomCodeInput(compact)) {
    return displayRoomCode(
      compact.length > roomCodeLength
          ? compact.substring(0, roomCodeLength)
          : compact,
    );
  }
  if (compact == 'Z') return 'Z';
  if (compact == 'ZK') {
    return _hasExplicitRoomCodePrefix(source) ? roomCodePrefix : 'ZK';
  }
  final hasPrefix =
      _hasExplicitRoomCodePrefix(source) ||
      _hasCompleteCompactRoomCodePrefix(compact);
  if (hasPrefix) {
    return '$roomCodePrefix${compact.substring(_roomCodePrefixLetterLength)}';
  }
  if (compact.startsWith('ZK')) return compact;
  return '$roomCodePrefix$compact';
}

/// Kodu ekranda göstermek için gruplar: `482913` -> `482 913`. 6 haneye
/// ulaşmamış kısmi girişi ve eski `ZK-…` kodlarını olduğu gibi bırakır
/// (kısmi giriş için ilk üç hane + kalan gruplanır).
String displayRoomCode(String code) {
  if (!_digitsOnlyPattern.hasMatch(code) || code.length <= 3) return code;
  return '${code.substring(0, 3)} ${code.substring(3)}';
}

/// Yeni oda üretim sözleşmesini doğrular (6 rakam).
bool isCanonicalRoomCode(String input) {
  return _canonicalRoomCodePattern.hasMatch(input);
}

/// Kullanıcının esnek yazımını normalize ettikten sonra JOIN kapısının
/// desteklediği biçimlerden birine uyup uymadığını doğrular: yeni 6 rakam,
/// eski `ZK-` + 10 onaltılık, ya da tarihsel dört karakterli.
///
/// Dört haneli eski biçim yalnız JOIN için kabul edilir; yeni kod üretimine
/// geri dönmez.
bool isSupportedRoomCode(String input) {
  final normalized = normalizeRoomCode(input);
  return _canonicalRoomCodePattern.hasMatch(normalized) ||
      _legacyHexRoomCodePattern.hasMatch(normalized) ||
      _legacyRoomCodePattern.hasMatch(normalized);
}

class GameRoom {
  static const allowedSecondsPerQuestion = [10, 15, 20, 30, 45, 60];
  static const allowedEntryFees = [0, 25, 50, 100];
  static const allowedQuestionCounts = [5, 10, 15];
  static const allowedDurations = [10, 15, 20, 30];
  static const defaultSecondsPerQuestion = 20;

  /// Özel odanın izinli kapasiteleri (sunucudaki `create_online_room` ile
  /// aynı küme). 2 = bugünkü iki kişilik oda; daha fazlası kalabalık oda.
  static const allowedMaxPlayers = [2, 4, 8, 16, 30, 50];

  /// Oda kurma sayfasında önceden seçili kapasite.
  static const defaultCrowdCapacity = 8;

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
    this.maxPlayers = 2,
    this.isCustom = false,
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

  /// Odanın kapasitesi (`rooms.max_players`). Hızlı eşleşme odası hep 2.
  final int maxPlayers;

  /// Kodla katılınan özel oda mı (`rooms.is_custom`). Eşleşme odası değil.
  final bool isCustom;

  /// Kalabalık oda = özel oda VE kapasite > 2. Sunucu yalnız bunlara yeni
  /// kuralları uygular (host başlatır, ayrılan oyunu bitirmez, sıralı
  /// sonuç); eşleşme odası ve 2 kişilik özel oda bugünkü 1v1 yolunda kalır.
  bool get isCrowd => isCustom && maxPlayers > 2;

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
    int? maxPlayers,
    bool? isCustom,
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
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
