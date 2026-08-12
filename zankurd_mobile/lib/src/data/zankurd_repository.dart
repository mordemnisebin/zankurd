import 'dart:typed_data';

import '../models/avatar_identity.dart';
import '../models/contest.dart';
import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/room_message.dart';
import '../models/tournament.dart';

/// Seri dondurma tahsilatının sonucu.
///
/// [charged] ile [alreadyCharged] ayrı tutulur çünkü çağıranın kararı
/// buna bağlıdır: idempotent yolda cevabı kaybolan bir istek güvenle
/// tekrarlanabilir, eski yolda tekrarlanamaz.
enum StreakFreezeChargeOutcome {
  /// Ücret bu çağrıda tahsil edildi.
  charged,

  /// Aynı anahtarla daha önce tahsil edilmişti; yeni hareket oluşmadı.
  alreadyCharged,

  /// Bakiye yetersiz.
  insufficient,

  /// Çağrı başarısız oldu (ağ/sunucu). Tahsil edilip edilmediği BİLİNMİYOR.
  failed,
}

class StreakFreezeChargeResult {
  const StreakFreezeChargeResult({
    required this.outcome,
    required this.idempotent,
  });

  final StreakFreezeChargeOutcome outcome;

  /// Sunucu tarafı idempotent yol kullanıldı mı.
  ///
  /// `false` ise (göç henüz uygulanmamış, eski `spend_coins` yolu) belirsiz
  /// kalan bir tahsilat ASLA tekrarlanmamalıdır.
  final bool idempotent;

  bool get succeeded =>
      outcome == StreakFreezeChargeOutcome.charged ||
      outcome == StreakFreezeChargeOutcome.alreadyCharged;
}

abstract class ZanKurdRepository {
  List<String> get categories;
  List<QuizQuestion> get questions;
  String? get currentUserId;

  /// Oda sorularında doğru cevap yalnız yanıt RPC'sinden sonra açıklanıyorsa
  /// true. Doğru cevaba bağlı istemci jokerleri bu modda kullanılamaz.
  bool get usesServerHiddenAnswers;

  Future<void> ensureProfile();
  Future<String> getProfileName();

  /// Oyuncunun kendi kodu (ör. `4F7K`) — benzersiz ve değişmez.
  ///
  /// Adlar benzersiz değil: ad vermek isteğe bağlı ve iki dilli bir
  /// toplulukta kültürel bir seçim. Arkadaş eklerken iki "Berfin"i ayıran
  /// tek şey bu koddur, o yüzden oyuncunun kendi kodunu görebilmesi ve
  /// paylaşabilmesi gerekir (2026-07-28).
  ///
  /// Sunucuya ulaşılamıyorsa ya da profil kod atanmadan önce açıldıysa
  /// null döner; arayüz o durumda kodu hiç göstermez.
  Future<String?> getPlayerTag();
  Future<void> updateProfileName(String name);
  Future<void> deleteMyAccount();
  Future<LeaderboardEntry?> getPlayerStats();

  /// Öğrenme/tek kişilik akışların çevrimdışı kategori listesi.
  Future<List<String>> loadCategories();

  /// Çevrimiçi eşleştirmede sunucunun gerçekten desteklediği kategoriler.
  ///
  /// Ağ veya sunucu hatası sahte bir yerel listeye düşmemeli; çağıran ekran
  /// hatayı görünür biçimde ele alır.
  Future<List<String>> loadMatchmakingCategories();

  /// Kategori adına göre onaylı soru sayısı (kategori kartlarında gösterim).
  /// Başarısızlıkta boş map döner; UI statik metne düşer.
  Future<Map<String, int>> loadCategoryQuestionCounts();
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  });
  List<QuizLevel> levelsForCategory(String category);
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  });
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room);

  /// Aynı gün içinde herkese aynı soru setini verir (tarih tohumlu seçim).
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10});

  GameRoom createRoom({String category = 'Ziman'});
  GameRoom joinRoom(String code);
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
  });
  Future<GameRoom> joinOnlineRoom(String code);

  /// Sunucudaki odanın tek ve yetkili snapshot'ını oyuncularıyla yükler.
  ///
  /// Hızlı eşleştirme yalnız `room_id` döndürür; istemci bu kimliği
  /// yerel `createRoom` kabuğuna yapıştırmamalıdır. Kod, ev sahibi,
  /// kategori, durum, soru/süre ayarları ve oyuncu kimlikleri bu metottan
  /// birlikte gelir.
  Future<GameRoom> loadRoomSnapshot(String roomId);

  /// Oyuncunun en son aktif/lobi çevrimiçi odasını geri yükler.
  /// Aktif üyelik yoksa null; RPC veya şema hataları çağırana iletilir.
  Future<RoomResumeSnapshot?> loadMyResumableRoom();

  /// Kullanıcının henüz onaylamadığı en yeni eksiksiz maç sonucunu yükler.
  Future<RoomResultSnapshot?> loadMyPendingRoomResult();

  /// Yalnız verilen odanın henüz onaylanmamış eksiksiz sonucunu yükler.
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room);

  /// Terminal sonuç gösterildikten sonra makbuzu idempotent biçimde yazar.
  Future<void> acknowledgeRoomResult(GameRoom room);

  /// İstemcinin aktif oda sorularını yüklediğini sunucu bariyerine bildirir.
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room);

  /// Beklenen indeksle CAS ilerletir; bitiş atomikse resume null dönebilir.
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  });

  /// Çevrimiçi odadan sunucunun yetkili çıkış sözleşmesiyle ayrılır.
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room);

  Future<List<Player>> loadRoomPlayers(GameRoom room);
  Future<RoomStatus> loadRoomStatus(GameRoom room);
  Future<RoomEndState> loadRoomEndState(GameRoom room);

  Stream<List<Player>> subscribeRoomPlayers(GameRoom room);
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room);
  Future<void> updateReady(GameRoom room, bool isReady);
  Future<void> startGame(GameRoom room);
  Future<void> finishGame(GameRoom room);
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  });
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite);

  /// Sorunun oyuncunun favorilerinde olup olmadığını döner.
  Future<bool> isFavoriteQuestion(QuizQuestion question);
  Future<void> reportQuestion(QuizQuestion question, String reason);
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  });
  Future<List<QuizQuestion>> loadFavoriteQuestions();
  Future<int> loadCoinBalance();

  /// Oyuncunun coin bakiyesinden [amount] kadar düşer.
  /// Bakiye yeterli değilse false, başarılıysa true döner.
  Future<bool> spendCoins(int amount, String reason);

  /// Seri dondurma ücretini IDEMPOTENT biçimde tahsil eder.
  ///
  /// [idempotencyKey] değişmez olmalıdır (sonuç makbuzunun kimliği). Aynı
  /// anahtarla ikinci çağrı yeni bir coin hareketi yaratmaz; ilk çekimi
  /// bildirir. Cevabı kaybolan bir istek bu sayede güvenle tekrarlanabilir
  /// — düz [spendCoins] ile bu mümkün değildir, çünkü `streak_freeze`
  /// sunucuda dedup anahtarı taşımaz ve her çağrı yeni bir satır yazar.
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  });

  /// Belirli bir ürün kimliğinin daha önce satın alınıp alınmadığını kontrol eder.
  Future<bool> hasPurchased(String itemId);

  /// Günlük görev ödülünü talep eder; kazanılan miktarı döner.
  ///
  /// Miktarı sunucu tarifesi belirler ([missionKey] üzerinden);
  /// [fallbackReward] yalnızca çevrimdışı/mock modda kullanılır.
  Future<int> claimMissionReward({
    required String missionKey,
    required int fallbackReward,
  });

  /// Turnuva şampiyonluğu ödülünü talep eder (sunucuda günde 1 kez).
  Future<int> claimTournamentReward();

  /// Günlük çark: bugün çevrilebilir mi?
  Future<bool> canSpinToday();

  /// Günlük çark ödülünü coin olarak yazar, kazanılan miktarı döner.
  ///
  /// Gerçek backend bu miktarı sunucuda belirlemelidir; istemci yalnızca
  /// dönen miktara göre animasyonu hedefler.
  Future<int> awardSpinCoins();
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  });

  /// Kazanılan XP'yi SUNUCUYA bildirir ve sunucudaki güncel toplamı döner.
  ///
  /// ## Niçin var
  ///
  /// XP iki yerde yaşıyordu ve yalnız biri gerçekti. Cihazdaki `XPStore`
  /// seviye ve ilerleme çubuğunu besliyordu; `profiles.xp` ise sıralamanın,
  /// toplam puanın ve lig rozetinin kaynağı. İkincisine hiçbir zaman
  /// yazılmadı: `award_xp_delta` RPC'si 2026-07-25'te yazıldı, iki test
  /// SQL dosyasında VARLIĞINI doğruladı ve hiçbir istemci kodu onu çağırmadı.
  ///
  /// Ölçüldü (2026-08-12, üretim yedeğinin yerel klonu): 21 profilin
  /// hiçbirinde `xp > 0` yok. Yani `get_leaderboard`ın `total_score`u herkes
  /// için sıfır, profil ekranındaki «Sıralama» ve «Toplam Puan» her oyuncuda
  /// «—», lig rozeti hiç açılmıyor. Sıralama özelliğinin verisi yoktu.
  ///
  /// Miktarı sunucu belirler: RPC çağrı başına 2000, günde 20000 ile
  /// sınırlar. İstemci yalnız bildirir.
  ///
  /// Bu çağrı oyuncuyu BEKLETMEZ ve hata fırlatmaz: XP'nin cihazdaki hâli
  /// zaten yazılmıştır, sunucu yazımı en iyi çabadır.
  Future<int> awardXp(int delta);

  /// Oyuncunun görsel kimliğini (avatar/çerçeve/unvan) yükler.
  Future<AvatarIdentity> loadAvatarIdentity();

  /// Görsel kimliği kalıcılaştırır (kozmetik; ekonomiye dokunmaz).
  Future<void> updateAvatarIdentity(AvatarIdentity identity);

  /// Avatar fotoğrafını yükler ve erişilebilir URL'ini döner.
  Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType);

  /// Oyuncunun avatar fotoğrafını **depodan** siler.
  ///
  /// 2026-08-02 denetimine kadar böyle bir yol yoktu: "fotoğrafı kaldır"
  /// yalnız `profiles.avatar_url` sütununu boşaltıyordu, nesne ise herkese
  /// açık `avatars` kovasında tahmin edilebilir bir yolda
  /// (`{user_id}/avatar.jpg`) kalmaya devam ediyordu. Kullanıcı fotoğrafını
  /// kaldırdığını sanıyor, dosya ise erişilebilir kalıyordu.
  ///
  /// Uygulama hem `.jpg` hem `.png` uzantısını siler: yükleme uzantıyı
  /// içerik türünden seçtiği için önce PNG sonra JPG yükleyen bir kullanıcı
  /// aksi hâlde eski nesneyi yetim bırakırdı.
  ///
  /// Sessizce başarısız olmaz; çağıran hatayı görebilsin diye fırlatır.
  Future<void> deleteAvatarPhoto();

  /// Bugünün contest/etkinlik temesini yükler (varsa).
  Future<Contest?> loadTodayContest();

  /// Quiz bitişi sonrası skor kaydeder ve katılım reward'ı verir.
  Future<ContestEntry?> submitContestEntry({
    required String contestId,
    required int correctCount,
  });

  /// Rank reward'ını ve rozeti talep eder.
  Future<Map<String, dynamic>?> claimContestReward(String contestId);

  /// Contest leaderboard'unu (top N) yükler.
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  });

  /// Kullanıcının kazandığı contest rozetlerini yükler.
  Future<List<UserContestBadge>> loadUserContestBadges();

  /// Kategori ders listesini yükler.
  Future<List<Lesson>> loadLessonsByCategory(String category);

  /// Ders ayrıntısını ve slaytlarını yükler.
  Future<Map<String, dynamic>?> loadLesson(String lessonId);

  /// Dersin slaytlarını yükler.
  Future<List<LessonSlide>> loadLessonSlides(String lessonId);

  /// Dersi tamamlandı olarak işaretler.
  Future<bool> markLessonCompleted(String lessonId);

  /// Kullanıcının tamamladığı ders id'lerini döndürür.
  Future<Set<String>> loadCompletedLessonIds();

  /// Arkadaş ekleme isteği gönder.
  Future<bool> addFriend(String friendId, String friendName);

  /// Arkadaş isteğini kabul et.
  Future<bool> acceptFriendRequest(String requestId);

  /// Arkadaş isteğini reddet.
  Future<bool> rejectFriendRequest(String requestId);

  /// Görünen ada göre oyuncu ara (arkadaş ekleme akışı).
  Future<List<PlayerSearchResult>> searchPlayers(String query);

  /// Arkadaş listesini yükle.
  Future<List<Friend>> loadFriends();

  /// Arkadaş liderlik tablosu (skora göre sıralı).
  Future<List<Friend>> loadFriendsLeaderboard();

  /// Bekleyen arkadaş isteklerini yükle.
  Future<List<FriendRequest>> loadPendingFriendRequests();

  /// Oda sohbet mesajı gönder.
  Future<void> sendRoomMessage({required String roomId, required String text});

  /// Oda sohbet mesajlarını canlı dinle.
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId);

  /// Oda sohbet mesajlarını tek seferlik yükle.
  Future<List<RoomMessage>> loadRoomMessages(String roomId);

  // ─── Sohbet moderasyonu (Apple 1.2 / Google Play UGC) ───────────────
  //
  // Kullanıcı üretimi içerik barındıran uygulamalarda içerik bildirme ve
  // kullanıcı engelleme zorunludur. 2026-07-31'e kadar depoda ikisi de
  // yoktu; sohbet o sırada hiçbir ekranda mount edilmediği için canlı bir
  // risk değildi. Sohbet geri getirilirken bunlar birlikte geldi.

  /// Bir mesajı moderasyona bildirir.
  ///
  /// Bildirim sunucuda kayda geçer; içerik kaldırma kararı istemcide
  /// verilmez. Bildiren kullanıcı için mesaj hemen gizlenir.
  Future<bool> reportRoomMessage({
    required String messageId,
    required String reason,
  });

  /// Bir oyuncuyu engeller: mesajları bundan sonra gösterilmez.
  Future<bool> blockPlayer(String playerId);

  /// Engeli kaldırır.
  Future<bool> unblockPlayer(String playerId);

  /// Engellenen oyuncu kimlikleri.
  Future<Set<String>> loadBlockedPlayerIds();

  /// Engellenen oyuncuları ADLARIYLA getirir.
  ///
  /// [loadBlockedPlayerIds] yalnız kimlik döner; engeli kaldırmak isteyen
  /// kullanıcıya UUID listesi göstermek işe yaramaz. 2026-08-02'ye kadar
  /// engeli kaldırmanın hiçbir arayüz yolu yoktu: `unblockPlayer` depoda
  /// duruyordu ama tek bir çağıranı bile yoktu — kullanıcı birini
  /// engelledikten sonra kararını geri alamıyordu.
  Future<List<PlayerSearchResult>> loadBlockedPlayers();

  /// Bir oyuncunun PROFİLİNİ (avatar fotoğrafı + görünen ad) moderasyona
  /// bildirir.
  ///
  /// 2026-08-02 denetimine kadar yalnız sohbet MESAJI bildirilebiliyordu
  /// (`reportRoomMessage`). Oysa avatar fotoğrafı da bir görsel UGC
  /// yüzeyidir ve liderlikte, eşleştirmede, odada ve turnuva tablosunda
  /// yabancılara gösterilir; onu bildirmenin hiçbir yolu yoktu. Apple
  /// Guideline 1.2 ve Play UGC politikası bu yüzeyi de kapsar.
  Future<bool> reportPlayerProfile({
    required String playerId,
    required String reason,
  });

  /// Günlük görev tamamlamasını sunucuya senkronize et.
  Future<bool> syncMissionCompletion(
    String missionKey,
    int coinReward,
    int xpReward,
  );

  /// Analytics event'ini sunucuya kaydet.
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  );

  /// Turnuva ilerlemesini sunucuya kaydet.
  Future<bool> saveTournamentProgress(
    String stage,
    int userScore,
    int opponentScore,
    List<String> botWinners,
  );

  Future<Map<String, dynamic>> joinMatchmaking(String categoryName);
  Future<Map<String, dynamic>> cancelMatchmaking();
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue();
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId);
  Future<void> sendRoomBroadcast(String roomId, Map<String, dynamic> payload);

  /// Gerçek oyunculu turnuvaya katıl.
  ///
  /// `null` dönerse sunucu tarafı kullanılamıyor demektir: migration henüz
  /// uygulanmamış ya da cihaz çevrimdışı. O durumda ekran eski bot
  /// benzetimine düşer. Bunu bir bayrakla değil dönüş değeriyle söylemek
  /// önemli: "sunucu mu, benzetim mi" sorusunu tahmin etmek (oda kimliğine
  /// bakmak gibi) sahte depoyu sunucu sanmaya yol açıyordu (2026-07-26).
  Future<TournamentBracket?> joinRealTournament();

  /// Gerçek turnuvanın güncel şeması; yoksa `null`.
  Future<TournamentBracket?> loadRealTournamentBracket();

  /// Turnuvaya katıl: bracket oluştur ve ilk rakip belirle.
  Future<TournamentBracket> joinTournament();

  /// Turnuva durumunu yükle.
  Future<TournamentBracket?> loadTournamentBracket();

  /// Turnuva maçında cevaplar gönder ve kazananı belirle.
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  });

  /// Turnuva sıralamasını yükle (top 16).
  Future<List<TournamentStandings>> loadTournamentStandings({int limit = 16});

  /// Turnuva ödülünü talep et (şampiyonluk).
  Future<int> claimTournamentChampionReward();

  /// Kullanıcı tarafından önerilen soruyu Supabase 'suggested_questions'
  /// tablosuna kaydeder. Onaylandıktan sonra soru havuzuna eklenir.
  Future<bool> submitSuggestedQuestion({
    required String category,
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    String? explanation,
    int difficulty = 3,
  });
}
