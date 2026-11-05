/// Yönetim bölümünün (2.2) veri modelleri.
///
/// Bu modeller sunucudaki `admin_*` RPC'lerinin döndürdüğü şekli taşır
/// (bkz. `supabase/2026-11-12_yonetim_paneli.sql`). Yetki ASLA istemcide
/// kararlaştırılmaz: bu sınıflar yalnız gösterilecek veriyi taşır; kimin
/// yönetici olduğuna sunucu karar verir.
library;

/// Panodaki toplam sayılar. Kişisel veri yok; yalnız sayaçlar.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeToday,
    required this.activeWeek,
    required this.newToday,
    required this.newWeek,
    required this.crashesWeek,
    required this.modeUsage,
    required this.pendingSuggestions,
    required this.openReports,
  });

  final int totalUsers;
  final int activeToday;
  final int activeWeek;
  final int newToday;
  final int newWeek;

  /// Haftalık çökme sayısı. Sunucuda çökme kaydı yoktur (Crashlytics); `null`
  /// = bilinmiyor, arayüz "—" gösterir. Uydurma 0 YAZILMAZ.
  final int? crashesWeek;

  /// Mod anahtarı (`solo`, `room`, `duel`, `tournament`, `contest`) → bu
  /// hafta oynanan oyun sayısı.
  final Map<String, int> modeUsage;

  /// Bekleyen oyuncu önerisi sayısı.
  final int pendingSuggestions;

  /// Açık soru bildirimi + oyuncu şikâyeti sayısı.
  final int openReports;
}

/// Panelden eklenen yeni soru (sunucu `admin_add_question` doğrular).
class AdminNewQuestion {
  const AdminNewQuestion({
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanationKu,
    this.explanationTr,
  });

  /// Var olan kategori adı (sunucu eşler; yoksa reddeder).
  final String category;
  final String prompt;

  /// Dört dolu, birbirinden farklı şık (A–D).
  final List<String> options;
  final int correctIndex;
  final String? explanationKu;
  final String? explanationTr;
}

/// Soru kuyruğundaki kayıt: oyuncu önerisi ya da bildirilen soru.
enum AdminQuestionKind { suggestion, reported }

class AdminQuestionItem {
  const AdminQuestionItem({
    required this.id,
    required this.kind,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.submitterName,
    this.reportCount = 0,
    this.reportReason,
  });

  final String id;
  final AdminQuestionKind kind;
  final String category;
  final String prompt;

  /// Dört şık (A–D).
  final List<String> options;
  final int correctIndex;

  /// Yalnız öneride: öneren oyuncunun adı.
  final String? submitterName;

  /// Yalnız bildirilen soruda.
  final int reportCount;
  final String? reportReason;

  String get correctAnswer => options[correctIndex];

  AdminQuestionItem copyWith({
    String? prompt,
    List<String>? options,
    int? correctIndex,
  }) => AdminQuestionItem(
    id: id,
    kind: kind,
    category: category,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    submitterName: submitterName,
    reportCount: reportCount,
    reportReason: reportReason,
  );
}

/// Moderatörün bir soruda yaptığı düzeltme (metin, şıklar, doğru şık).
class AdminQuestionEdit {
  const AdminQuestionEdit({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;

  /// Dört şık (A–D).
  final List<String> options;
  final int correctIndex;
}

/// Soru öneren bir oyuncunun katkı özeti.
class AdminContributor {
  const AdminContributor({
    required this.userId,
    required this.name,
    required this.suggested,
    required this.approved,
    this.rewardedCoins = 0,
  });

  final String userId;
  final String name;
  final int suggested;
  final int approved;

  /// Bu oyuncuya katkısı için şimdiye dek verilen toplam jeton.
  final int rewardedCoins;

  AdminContributor withReward(int coins) => AdminContributor(
    userId: userId,
    name: name,
    suggested: suggested,
    approved: approved,
    rewardedCoins: rewardedCoins + coins,
  );
}

/// Ödül dönemi: günün yarışması ya da haftalık sıralama.
enum AdminRewardPeriodKind { daily, weekly }

class AdminRewardCandidate {
  const AdminRewardCandidate({
    required this.rank,
    required this.userId,
    required this.name,
    required this.score,
    this.rewarded = false,
  });

  final int rank;
  final String userId;
  final String name;
  final int score;

  /// Bu dönem için ödül zaten verildi (sunucu aynı kişiye ikinci kez
  /// vermez).
  final bool rewarded;

  AdminRewardCandidate markRewarded() => AdminRewardCandidate(
    rank: rank,
    userId: userId,
    name: name,
    score: score,
    rewarded: true,
  );
}

/// `admin_grant_reward` sonucu. Sunucu ikinci ödül vermeyi HATA saymaz; ama
/// ekran "Kaydedildi" demesin diye sonuç ayrı tutulur (2.1.2 W8, alan 8 #14).
enum AdminGrantOutcome {
  /// Ödül bu çağrıda verildi.
  granted,

  /// Aynı kişiye aynı dönem için ödül daha önce verilmişti; yeni kayıt yok.
  alreadyRewarded,

  /// Aynı dönemde aynı derece başka birine verilmişti (ör. 1. kısıtlanınca
  /// sıradaki 1. oldu); yeni kayıt yok.
  rankTaken,
}

class AdminRewardPeriod {
  const AdminRewardPeriod({
    required this.kind,
    required this.periodKey,
    required this.candidates,
    required this.suggestedCoins,
    this.prevKey,
    this.nextKey,
  });

  final AdminRewardPeriodKind kind;

  /// Gün için `2026-11-12`, hafta için haftanın başlangıç günü
  /// (`2026-11-09`, pazartesi).
  final String periodKey;
  final List<AdminRewardCandidate> candidates;

  /// Sıraya göre önerilen jeton: indeks 0 → 1. sıra.
  final List<int> suggestedCoins;

  /// Bir önceki dönemin anahtarı (geçmiş dönem seçimi); her zaman vardır.
  final String? prevKey;

  /// Bir sonraki TAMAMLANMIŞ dönemin anahtarı; bu dönem en son tamamlanan
  /// dönemse `null` (bitmemiş dönem ödüllendirilemez).
  final String? nextKey;
}

/// Bir oyuncunun moderasyon durumu.
enum AdminUserState { ok, warned, blocked, suspended }

enum AdminUserAction { warn, block, suspend, lift }

class AdminUserReport {
  const AdminUserReport({
    required this.userId,
    required this.name,
    required this.reportCount,
    required this.reason,
    this.state = AdminUserState.ok,
    this.suspendedDays = 0,
  });

  final String userId;
  final String name;
  final int reportCount;

  /// En son şikâyetin nedeni (oyuncunun yazdığı serbest metin).
  final String reason;
  final AdminUserState state;
  final int suspendedDays;

  AdminUserReport withState(AdminUserState next, {int days = 0}) =>
      AdminUserReport(
        userId: userId,
        name: name,
        reportCount: reportCount,
        reason: reason,
        state: next,
        suspendedDays: days,
      );
}

/// Denetim günlüğünün istemciye dönen kısa görünümü.
enum AdminAuditAction {
  approve,
  reject,
  fix,
  retire,
  dismiss,
  reward,
  warn,
  block,
  suspend,
  lift,

  /// Otomatik ödül anahtarı açıldı/kapandı.
  autoReward,

  /// Otomatik ödül bir kişide hata verdi (sunucu `reward_auto_error`).
  autoRewardError,
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.action,
    required this.target,
    required this.at,
  });

  final AdminAuditAction action;

  /// Etkilenen kaydın kısa adı (soru metninin başı ya da oyuncu adı).
  final String target;
  final DateTime at;
}

/// Anlık bildirim türleri (sunucuda `admin_notify_prefs.kind`).
enum AdminNotifyKind { suggestion, report }
