import '../models/admin.dart';
import 'admin_repository.dart';

/// Yönetim bölümünün SAHTE deposu (2.2 maket aşaması).
///
/// Bellekte yaşar; hiçbir şey sunucuya gitmez. Ekran turu ve widget
/// testleri bunu kullanır; üretimde sağlayıcı kaydedilmez, yani yönetim
/// girişi hiç görünmez. Veri uydurmadır — gerçek oyuncu adı değil.
class MockAdminRepository implements AdminRepository {
  /// [admin] `false` → [isAdmin] `false` döner (giriş görünmemeli).
  /// [empty] `true` → bütün listeler boş (boş durum çizimleri).
  MockAdminRepository({this.admin = true, this.empty = false}) {
    if (!empty) _seed();
  }

  final bool admin;
  final bool empty;

  final List<AdminQuestionItem> _suggestions = [];
  final List<AdminQuestionItem> _reported = [];
  final List<AdminContributor> _contributors = [];
  final List<AdminUserReport> _userReports = [];
  final List<AdminAuditEntry> _audit = [];
  final Set<String> _rewardedKeys = {};
  bool _autoReward = false;
  final Map<AdminNotifyKind, bool> _notify = {
    AdminNotifyKind.suggestion: true,
    AdminNotifyKind.report: true,
  };

  /// Testler için: yapılan işlem sayısı.
  int get auditCount => _audit.length;

  void _seed() {
    _suggestions.addAll(const [
      AdminQuestionItem(
        id: 's1',
        kind: AdminQuestionKind.suggestion,
        category: 'Dîrok',
        prompt: 'Şerefname kê nivîsandiye?',
        options: ['Şerefxanê Bidlîsî', 'Ehmedê Xanî', 'Melayê Cizîrî', 'Feqî'],
        correctIndex: 0,
        submitterName: 'Rojda',
      ),
      AdminQuestionItem(
        id: 's2',
        kind: AdminQuestionKind.suggestion,
        category: 'Ziman',
        prompt: 'Peyva «ax» bi Tirkî çi ye?',
        options: ['toprak', 'su', 'ateş', 'hava'],
        correctIndex: 0,
        submitterName: 'Baran',
      ),
      AdminQuestionItem(
        id: 's3',
        kind: AdminQuestionKind.suggestion,
        category: 'Çand',
        prompt: 'Newroz di kîjan mehê de tê pîrozkirin?',
        options: ['Adar', 'Gulan', 'Tîrmeh', 'Çile'],
        correctIndex: 0,
        submitterName: 'Dilan',
      ),
    ]);
    _reported.addAll(const [
      AdminQuestionItem(
        id: 'r1',
        kind: AdminQuestionKind.reported,
        category: 'Cografya',
        prompt: 'Çiyayê herî bilind ê Kurdistanê kîjan e?',
        options: [
          'Çiyayê Agirî',
          'Çiyayê Cûdî',
          'Çiyayê Sîpan',
          'Çiyayê Qendîl',
        ],
        correctIndex: 1,
        reportCount: 4,
        reportReason: 'Doğru şık yanlış görünüyor',
      ),
      AdminQuestionItem(
        id: 'r2',
        kind: AdminQuestionKind.reported,
        category: 'Ziman',
        prompt: 'Peyva «roj» bi Tirkî çi ye?',
        options: ['gün / güneş', 'ay', 'yıl', 'yıldız'],
        correctIndex: 0,
        reportCount: 2,
        reportReason: 'İki şık doğru olabilir',
      ),
    ]);
    _contributors.addAll(const [
      AdminContributor(
        userId: 'u-rojda',
        name: 'Rojda',
        suggested: 14,
        approved: 11,
        rewardedCoins: 200,
      ),
      AdminContributor(
        userId: 'u-baran',
        name: 'Baran',
        suggested: 9,
        approved: 5,
      ),
      AdminContributor(
        userId: 'u-dilan',
        name: 'Dilan',
        suggested: 4,
        approved: 4,
      ),
    ]);
    _userReports.addAll(const [
      AdminUserReport(
        userId: 'u-x1',
        name: 'Oyuncu4821',
        reportCount: 3,
        reason: 'Uygunsuz ad',
      ),
      AdminUserReport(
        userId: 'u-x2',
        name: 'Hêvî',
        reportCount: 1,
        reason: 'Sohbette küfür',
        state: AdminUserState.warned,
      ),
    ]);
    _audit.addAll([
      AdminAuditEntry(
        action: AdminAuditAction.approve,
        target: 'Newroz di kîjan…',
        at: DateTime(2026, 11, 12, 9, 40),
      ),
      AdminAuditEntry(
        action: AdminAuditAction.reward,
        target: 'Rojda',
        at: DateTime(2026, 11, 11, 21, 5),
      ),
      AdminAuditEntry(
        action: AdminAuditAction.warn,
        target: 'Hêvî',
        at: DateTime(2026, 11, 11, 18, 22),
      ),
    ]);
  }

  void _log(AdminAuditAction action, String target) {
    _audit.insert(
      0,
      AdminAuditEntry(action: action, target: target, at: DateTime.now()),
    );
  }

  String _short(String text) =>
      text.length <= 24 ? text : '${text.substring(0, 22)}…';

  @override
  bool get isSample => true;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<AdminStats> loadStats() async => AdminStats(
    totalUsers: empty ? 0 : 1284,
    activeToday: empty ? 0 : 96,
    activeWeek: empty ? 0 : 412,
    newToday: empty ? 0 : 7,
    newWeek: empty ? 0 : 63,
    crashesWeek: null,
    modeUsage: empty
        ? const {}
        : const {
            'solo': 1830,
            'room': 640,
            'duel': 512,
            'tournament': 48,
            'contest': 301,
          },
    pendingSuggestions: _suggestions.length,
    openReports:
        _reported.length +
        _userReports.where((r) => r.state == AdminUserState.ok).length,
  );

  @override
  Future<List<AdminAuditEntry>> loadRecentActions({int limit = 5}) async =>
      _audit.take(limit).toList();

  @override
  Future<List<AdminQuestionItem>> loadQuestions(AdminQuestionKind kind) async =>
      List.of(kind == AdminQuestionKind.suggestion ? _suggestions : _reported);

  @override
  Future<List<String>> loadCategories() async => const [
    'Dîrok',
    'Ziman',
    'Çand',
    'Cografya',
    'Cîhan',
    'Edebiyat',
    'Muzîk',
    'Sînema',
    'Siyaset',
    'Teknolojî',
    'Paradîgma',
  ];

  /// Testler için: eklenen yeni sorular.
  final List<AdminNewQuestion> added = [];

  @override
  Future<void> addQuestion(AdminNewQuestion question) async {
    added.add(question);
    _log(AdminAuditAction.approve, _short(question.prompt));
  }

  AdminQuestionItem _take(List<AdminQuestionItem> list, String id) {
    final index = list.indexWhere((q) => q.id == id);
    if (index < 0) throw StateError('Kayıt yok: $id');
    return list.removeAt(index);
  }

  @override
  Future<void> approveSuggestion(
    String id, {
    AdminQuestionEdit? edits,
    String? note,
  }) async {
    final q = _take(_suggestions, id);
    final c = _contributors.indexWhere((c) => c.name == q.submitterName);
    if (c >= 0) {
      final old = _contributors[c];
      _contributors[c] = AdminContributor(
        userId: old.userId,
        name: old.name,
        suggested: old.suggested,
        approved: old.approved + 1,
        rewardedCoins: old.rewardedCoins,
      );
    }
    _log(AdminAuditAction.approve, _short(q.prompt));
  }

  @override
  Future<void> rejectSuggestion(String id, {String? note}) async {
    final q = _take(_suggestions, id);
    _log(AdminAuditAction.reject, _short(q.prompt));
  }

  @override
  Future<void> fixQuestion(
    String id,
    AdminQuestionEdit edit, {
    String? note,
  }) async {
    final index = _reported.indexWhere((q) => q.id == id);
    if (index < 0) {
      throw StateError('Kayıt yok: $id');
    }
    _reported.removeAt(index);
    _log(AdminAuditAction.fix, _short(edit.prompt));
  }

  @override
  Future<void> retireQuestion(String id, {String? note}) async {
    final q = _take(_reported, id);
    _log(AdminAuditAction.retire, _short(q.prompt));
  }

  @override
  Future<void> dismissQuestionReports(String id) async {
    final q = _take(_reported, id);
    _log(AdminAuditAction.dismiss, _short(q.prompt));
  }

  @override
  Future<List<AdminContributor>> loadContributors() async =>
      List.of(_contributors);

  @override
  Future<void> rewardContributor(String userId, {required int coins}) async {
    final index = _contributors.indexWhere((c) => c.userId == userId);
    if (index < 0) throw StateError('Katkıcı yok: $userId');
    _contributors[index] = _contributors[index].withReward(coins);
    _log(AdminAuditAction.reward, _contributors[index].name);
  }

  @override
  Future<AdminRewardPeriod> loadRewardPeriod(
    AdminRewardPeriodKind kind, {
    String? periodKey,
  }) async {
    final daily = kind == AdminRewardPeriodKind.daily;
    // Maket: son tamamlanan dönem + bir önceki (geçmiş dönem seçimini gösterir).
    final lastKey = daily ? '2026-11-12' : '2026-11-09';
    final prevOfLast = daily ? '2026-11-11' : '2026-11-02';
    final key = periodKey ?? lastKey;
    final isLast = key == lastKey;
    final names = daily
        ? const ['Berfin', 'Diyar', 'Rojîn']
        : const ['Rojda', 'Baran', 'Dilan'];
    final scores = daily ? const [980, 910, 860] : const [5240, 4980, 4410];
    return AdminRewardPeriod(
      kind: kind,
      periodKey: key,
      prevKey: isLast ? prevOfLast : null,
      nextKey: isLast ? null : lastKey,
      suggestedCoins: daily ? const [500, 300, 100] : const [1000, 600, 300],
      candidates: empty
          ? const []
          : [
              for (var i = 0; i < 3; i++)
                AdminRewardCandidate(
                  rank: i + 1,
                  userId: 'u-${names[i].toLowerCase()}',
                  name: names[i],
                  score: scores[i],
                  rewarded: _rewardedKeys.contains(
                    '${kind.name}:$key:u-${names[i].toLowerCase()}',
                  ),
                ),
            ],
    );
  }

  @override
  Future<AdminGrantOutcome> grantReward(
    AdminRewardPeriodKind kind,
    String periodKey, {
    required String userId,
    required int coins,
  }) async {
    final key = '${kind.name}:$periodKey:$userId';
    // Sunucu da ikinci kez vermez ve nedeni açıkça döndürür.
    if (!_rewardedKeys.add(key)) return AdminGrantOutcome.alreadyRewarded;
    _log(AdminAuditAction.reward, userId.replaceFirst('u-', ''));
    return AdminGrantOutcome.granted;
  }

  @override
  Future<bool> loadAutoReward() async => _autoReward;

  @override
  Future<void> setAutoReward(bool enabled) async => _autoReward = enabled;

  @override
  Future<List<AdminUserReport>> loadUserReports() async =>
      List.of(_userReports);

  @override
  Future<void> moderateUser(
    String userId,
    AdminUserAction action, {
    int days = 0,
    String? note,
  }) async {
    final index = _userReports.indexWhere((r) => r.userId == userId);
    if (index < 0) throw StateError('Oyuncu yok: $userId');
    final old = _userReports[index];
    final (state, audit) = switch (action) {
      AdminUserAction.warn => (AdminUserState.warned, AdminAuditAction.warn),
      AdminUserAction.block => (AdminUserState.blocked, AdminAuditAction.block),
      AdminUserAction.suspend => (
        AdminUserState.suspended,
        AdminAuditAction.suspend,
      ),
      AdminUserAction.lift => (AdminUserState.ok, AdminAuditAction.lift),
    };
    _userReports[index] = old.withState(state, days: days);
    _log(audit, old.name);
  }

  @override
  Future<Map<AdminNotifyKind, bool>> loadNotifyPrefs() async => Map.of(_notify);

  @override
  Future<void> setNotifyPref(AdminNotifyKind kind, bool enabled) async {
    _notify[kind] = enabled;
  }
}
