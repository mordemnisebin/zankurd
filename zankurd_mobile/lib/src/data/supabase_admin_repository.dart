import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin.dart';
import 'admin_repository.dart';

/// Yönetim bölümünün GERÇEK deposu: sunucudaki `admin_*` RPC'lerini çağırır
/// (bkz. `supabase/2026-11-12_yonetim_paneli.sql`).
///
/// ## Güven sınırı
///
/// Yetki bu sınıfta DEĞİL sunucudadır: her RPC `auth.uid()` ile `admins`
/// tablosunu denetler, yönetici olmayana 42501 verir. Bu sınıf yalnız
/// çağrıyı yapar ve cevabı modele çevirir; [isAdmin] `true` dönmek hiçbir
/// şeyin kilidini açmaz, yalnız arayüz girişi göstersin diye sorulur.
///
/// ## Hata
///
/// Hiçbir hata yutulmaz ya da sahte başarıya çevrilmez: [isAdmin] dışındaki
/// her çağrı sunucu hatasını fırlatır (ekran "Yapılamadı" der ve rapora
/// yazar). [isAdmin] da fırlatır; [AdminEntryRow] ağ hatasında girişi GİZLER
/// (yönetici olduğu bilinmeyen kimse girişi görmez).
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this.client);

  final SupabaseClient client;

  @override
  bool get isSample => false;

  // ── Biçim yardımcıları ─────────────────────────────────────────────

  static Map<String, dynamic> _map(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  static List<Map<String, dynamic>> _rows(dynamic raw) => raw == null
      ? const []
      : [for (final row in raw as List) Map<String, dynamic>.from(row as Map)];

  static int _int(dynamic v) => v == null ? 0 : (v as num).toInt();

  static String _str(dynamic v) => (v as String?) ?? '';

  static const _letterIndex = {
    'A': 0, 'a': 0, 'B': 1, 'b': 1, 'C': 2, 'c': 2, 'D': 3, 'd': 3, //
  };

  static int _correctIndex(dynamic letter) => _letterIndex[_str(letter)] ?? 0;

  static AdminQuestionItem _questionFrom(
    Map<String, dynamic> row,
    AdminQuestionKind kind,
  ) => AdminQuestionItem(
    id: _str(row['id']),
    kind: kind,
    category: _str(row['category']),
    prompt: _str(row['prompt']),
    options: [
      _str(row['option_a']),
      _str(row['option_b']),
      _str(row['option_c']),
      _str(row['option_d']),
    ],
    correctIndex: _correctIndex(row['correct_option']),
    submitterName: row['submitter_name'] as String?,
    reportCount: _int(row['report_count']),
    reportReason: row['last_reason'] as String?,
  );

  /// Sunucudaki `admin_audit_log.action` → ekran eylemi. Tanınmayanlar
  /// (örn. `notify_pref_set`) "Son işlemler"de listelenmez; `auto_reward_set` ve
  /// `reward_auto_error` listelenir (2.1.2 W8, alan 8 #20).
  static const _auditActions = <String, AdminAuditAction>{
    'suggestion_approve': AdminAuditAction.approve,
    'question_add': AdminAuditAction.approve,
    'suggestion_reject': AdminAuditAction.reject,
    'question_fix': AdminAuditAction.fix,
    'question_retire': AdminAuditAction.retire,
    'question_dismiss': AdminAuditAction.dismiss,
    'contributor_reward': AdminAuditAction.reward,
    'reward_grant': AdminAuditAction.reward,
    'reward_auto': AdminAuditAction.reward,
    'user_warn': AdminAuditAction.warn,
    'user_block': AdminAuditAction.block,
    'user_suspend': AdminAuditAction.suspend,
    'user_lift': AdminAuditAction.lift,
    'auto_reward_set': AdminAuditAction.autoReward,
    'reward_auto_error': AdminAuditAction.autoRewardError,
  };

  static String _kindName(AdminRewardPeriodKind kind) => kind.name;

  // ── Yetki ──────────────────────────────────────────────────────────

  @override
  Future<bool> isAdmin() async {
    final result = await client.rpc<dynamic>('admin_is_admin');
    return result == true;
  }

  // ── Pano ───────────────────────────────────────────────────────────

  @override
  Future<AdminStats> loadStats() async {
    final raw = _map(await client.rpc<dynamic>('admin_get_stats'));
    final modes = raw['mode_usage'] == null
        ? const <String, dynamic>{}
        : _map(raw['mode_usage']);
    return AdminStats(
      totalUsers: _int(raw['total_users']),
      activeToday: _int(raw['active_today']),
      activeWeek: _int(raw['active_week']),
      newToday: _int(raw['new_today']),
      newWeek: _int(raw['new_week']),
      crashesWeek: raw['crashes_week'] == null
          ? null
          : _int(raw['crashes_week']),
      modeUsage: {for (final e in modes.entries) e.key: _int(e.value)},
      pendingSuggestions: _int(raw['pending_suggestions']),
      openReports: _int(raw['open_reports']),
    );
  }

  @override
  Future<List<AdminAuditEntry>> loadRecentActions({int limit = 5}) async {
    // Tanınmayan eylemler süzüleceğinden biraz fazla istenir.
    final rows = _rows(
      await client.rpc<dynamic>(
        'admin_list_audit',
        params: {'p_limit': limit * 3},
      ),
    );
    final entries = <AdminAuditEntry>[];
    for (final row in rows) {
      final action = _auditActions[_str(row['action'])];
      if (action == null) continue;
      final label = row['label'] as String?;
      entries.add(
        AdminAuditEntry(
          action: action,
          target: (label != null && label.isNotEmpty)
              ? label
              : _str(row['target_id']),
          at: DateTime.parse(_str(row['created_at'])).toLocal(),
        ),
      );
      if (entries.length == limit) break;
    }
    return entries;
  }

  // ── Soru yönetimi ──────────────────────────────────────────────────

  @override
  Future<List<AdminQuestionItem>> loadQuestions(AdminQuestionKind kind) async {
    if (kind == AdminQuestionKind.suggestion) {
      final rows = _rows(
        await client.rpc<dynamic>(
          'admin_list_suggestions',
          params: {'p_status': 'pending', 'p_limit': 50},
        ),
      );
      return [for (final r in rows) _questionFrom(r, kind)];
    }
    final rows = _rows(
      await client.rpc<dynamic>(
        'admin_list_reported_questions',
        params: {'p_limit': 50},
      ),
    );
    return [for (final r in rows) _questionFrom(r, kind)];
  }

  @override
  Future<List<String>> loadCategories() async {
    final rows = await client.from('categories').select('name').order('name');
    return [
      for (final row in rows)
        if (_str(row['name']).isNotEmpty) _str(row['name']),
    ];
  }

  @override
  Future<void> addQuestion(AdminNewQuestion question) async {
    await client.rpc<dynamic>(
      'admin_add_question',
      params: {
        'p_category': question.category,
        'p_prompt': question.prompt,
        'p_options': question.options,
        'p_correct': question.correctIndex,
        'p_explanation_ku': question.explanationKu,
        'p_explanation_tr': question.explanationTr,
      },
    );
  }

  @override
  Future<void> approveSuggestion(
    String id, {
    AdminQuestionEdit? edits,
    String? note,
  }) async {
    await client.rpc<dynamic>(
      'admin_review_suggestion',
      params: {
        'p_id': id,
        'p_decision': 'approve',
        'p_note': note,
        'p_edits': edits == null
            ? null
            : {
                'prompt': edits.prompt,
                'options': edits.options,
                'correct': edits.correctIndex,
              },
      },
    );
  }

  @override
  Future<void> rejectSuggestion(String id, {String? note}) async {
    await client.rpc<dynamic>(
      'admin_review_suggestion',
      params: {'p_id': id, 'p_decision': 'reject', 'p_note': note},
    );
  }

  @override
  Future<void> fixQuestion(
    String id,
    AdminQuestionEdit edit, {
    String? note,
  }) async {
    await client.rpc<dynamic>(
      'admin_fix_question',
      params: {
        'p_question_id': id,
        'p_prompt': edit.prompt,
        'p_options': edit.options,
        'p_correct': edit.correctIndex,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> retireQuestion(String id, {String? note}) async {
    await client.rpc<dynamic>(
      'admin_retire_question',
      params: {'p_question_id': id, 'p_note': note},
    );
  }

  @override
  Future<void> dismissQuestionReports(String id) async {
    await client.rpc<dynamic>(
      'admin_dismiss_question_reports',
      params: {'p_question_id': id},
    );
  }

  // ── Katkıcılar ─────────────────────────────────────────────────────

  @override
  Future<List<AdminContributor>> loadContributors() async {
    final rows = _rows(
      await client.rpc<dynamic>(
        'admin_list_contributors',
        params: {'p_limit': 50},
      ),
    );
    return [
      for (final r in rows)
        AdminContributor(
          userId: _str(r['user_id']),
          name: _str(r['name']).isEmpty ? '—' : _str(r['name']),
          suggested: _int(r['suggested']),
          approved: _int(r['approved']),
          rewardedCoins: _int(r['rewarded_coins']),
        ),
    ];
  }

  /// Başarısız (ya da yanıtı kaybolmuş) katkı ödülü istekleri için kalıcı
  /// istek kimliği: AYNI kullanıcı + tutar yeniden denendiğinde AYNI kimlik
  /// gider, sunucu (`admin_reward_contributor/4`, request_id benzersiz) ikinci
  /// kez ödemez ve önceki sonucu döner. Başarıdan sonra kimlik silinir; bilinçli
  /// ikinci ödül yeni kimlikle yeni bir istektir.
  final Map<String, String> _pendingRewardRequests = <String, String>{};

  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<void> rewardContributor(String userId, {required int coins}) async {
    final key = '$userId|$coins';
    final requestId = _pendingRewardRequests.putIfAbsent(key, _newRequestId);
    try {
      await client.rpc<dynamic>(
        'admin_reward_contributor',
        params: {
          'p_user_id': userId,
          'p_coins': coins,
          'p_note': null,
          'p_request_id': requestId,
        },
      );
    } on PostgrestException catch (error) {
      // Sunucuda 4 bağımsız değişkenli imza yoksa (göç henüz uygulanmadı)
      // eski imzaya düş: sunucu aynı yönetici+kullanıcı+tutar için 10 dk'lık
      // dilimde zaten tek ödeme yapar.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      await client.rpc<dynamic>(
        'admin_reward_contributor',
        params: {'p_user_id': userId, 'p_coins': coins},
      );
    }
    _pendingRewardRequests.remove(key);
  }

  // ── Ödüller ────────────────────────────────────────────────────────

  @override
  Future<AdminRewardPeriod> loadRewardPeriod(
    AdminRewardPeriodKind kind, {
    String? periodKey,
  }) async {
    final raw = _map(
      await client.rpc<dynamic>(
        'admin_list_reward_candidates',
        params: {'p_kind': _kindName(kind), 'p_period_key': periodKey},
      ),
    );
    return AdminRewardPeriod(
      kind: kind,
      periodKey: _str(raw['period_key']),
      prevKey: raw['prev_key'] as String?,
      nextKey: raw['next_key'] as String?,
      suggestedCoins: [
        for (final c in (raw['suggested_coins'] as List)) _int(c),
      ],
      candidates: [
        for (final c in _rows(raw['candidates']))
          AdminRewardCandidate(
            rank: _int(c['rank']),
            userId: _str(c['user_id']),
            name: _str(c['name']),
            score: _int(c['score']),
            rewarded: c['rewarded'] == true,
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
    // `granted:false` hata DEĞİL (sunucu ikinci ödül vermez) ama "Kaydedildi"
    // DEMEMELİ: neden ayrı sonuç olarak döner (W8, alan 8 #14). Eski sunucu
    // (W8 göçü öncesi) da aynı biçimi döndürür; gövde yoksa verildi sayılır.
    final reply = await client.rpc<dynamic>(
      'admin_grant_reward',
      params: {
        'p_kind': _kindName(kind),
        'p_period_key': periodKey,
        'p_user_id': userId,
        'p_coins': coins,
      },
    );
    if (reply is Map && reply['granted'] == false) {
      return reply['reason'] == 'rank_already_rewarded'
          ? AdminGrantOutcome.rankTaken
          : AdminGrantOutcome.alreadyRewarded;
    }
    return AdminGrantOutcome.granted;
  }

  @override
  Future<bool> loadAutoReward() async =>
      (await client.rpc<dynamic>('admin_get_auto_reward')) == true;

  @override
  Future<void> setAutoReward(bool enabled) async {
    await client.rpc<dynamic>(
      'admin_set_auto_reward',
      params: {'p_enabled': enabled},
    );
  }

  // ── Kullanıcılar / şikâyetler ──────────────────────────────────────

  @override
  Future<List<AdminUserReport>> loadUserReports() async {
    final rows = _rows(
      await client.rpc<dynamic>(
        'admin_list_user_reports',
        params: {'p_limit': 50},
      ),
    );
    return [
      for (final r in rows)
        AdminUserReport(
          userId: _str(r['user_id']),
          name: _str(r['name']).isEmpty ? '—' : _str(r['name']),
          reportCount: _int(r['open_reports']),
          reason: _str(r['last_reason']),
          state: switch (r['state']) {
            'warned' => AdminUserState.warned,
            'blocked' => AdminUserState.blocked,
            'suspended' => AdminUserState.suspended,
            _ => AdminUserState.ok,
          },
          suspendedDays: _remainingDays(r['until']),
        ),
    ];
  }

  /// Askının kalan gün sayısı (yukarı yuvarlanır); askı yoksa 0.
  static int _remainingDays(dynamic until) {
    if (until is! String) return 0;
    final left = DateTime.parse(until).difference(DateTime.now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  @override
  Future<void> moderateUser(
    String userId,
    AdminUserAction action, {
    int days = 0,
    String? note,
  }) async {
    await client.rpc<dynamic>(
      'admin_moderate_user',
      params: {
        'p_user_id': userId,
        'p_action': action.name,
        'p_days': action == AdminUserAction.suspend ? days : null,
        'p_note': note,
      },
    );
  }

  // ── Bildirim tercihleri ────────────────────────────────────────────

  @override
  Future<Map<AdminNotifyKind, bool>> loadNotifyPrefs() async {
    final raw = _map(await client.rpc<dynamic>('admin_get_notify_prefs'));
    return {
      for (final kind in AdminNotifyKind.values) kind: raw[kind.name] != false,
    };
  }

  @override
  Future<void> setNotifyPref(AdminNotifyKind kind, bool enabled) async {
    await client.rpc<dynamic>(
      'admin_set_notify_pref',
      params: {'p_kind': kind.name, 'p_enabled': enabled},
    );
  }
}
