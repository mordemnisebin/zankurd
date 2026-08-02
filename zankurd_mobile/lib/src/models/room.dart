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

/// Karışması zor karakterlerden (I/O/0/1 yok) 4 haneli oda kodu üretir.
/// 32^4 ≈ 1M kombinasyon; saat milisaniyesine dayalı eski üretim yalnızca
/// 1000 farklı kod verdiğinden çakışma kaçınılmazdı.
String generateRoomCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random();
  final suffix = List.generate(
    4,
    (_) => alphabet[rng.nextInt(alphabet.length)],
  ).join();
  return 'ZK-$suffix';
}

/// Elle yazılmış bir oda kodunu `generateRoomCode`un ürettiği biçime çevirir.
///
/// Kod kullanıcıya `ZK-X8WY` diye gösterilir ama insan onu tireyi atlayarak,
/// küçük harfle ya da araya boşluk koyarak yazar. Katılma alanı bir zamanlar
/// yalnızca `trim().toUpperCase()` yapıyordu; `zkx8wy` yazan kişi "oda
/// bulunamadı" görüyordu — oda oradayken. Kusur 2026-08-01'de iki gerçek
/// cihaz arasında oda kurulup katılınırken bulundu.
///
/// Ayıklama yalnızca biçimseldir: harf/rakam dışını atar, büyütür, varsa
/// baştaki `ZK` önekini kaldırır ve kanonik hâli yeniden kurar. Karakter
/// *düzeltmez* — `0`ı `O` yapmak gibi bir tahmin yanlış odaya sokabilirdi;
/// üretim alfabesi zaten o ikilileri hiç kullanmıyor.
String normalizeRoomCode(String input) {
  var body = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (body.startsWith('ZK')) body = body.substring(2);
  if (body.isEmpty) return '';
  return 'ZK-$body';
}

class GameRoom {
  static const allowedSecondsPerQuestion = [20, 30, 45, 60];
  static const defaultSecondsPerQuestion = 30;

  const GameRoom({
    this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.players,
    required this.status,
    required this.questionCount,
    this.secondsPerQuestion = defaultSecondsPerQuestion,
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
