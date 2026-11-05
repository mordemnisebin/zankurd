import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/admin.dart';

/// Yönetim bölümünün veri kapısı (2.2).
///
/// ## Güven sınırı
///
/// Yetki ASLA istemcide verilmez. Gerçek uygulama sunucudaki `admin_*`
/// RPC'lerini çağırır; her RPC `auth.uid()` ile `admins` tablosunu kontrol
/// eder ve yönetici değilse hata verir (bkz.
/// `supabase/2026-11-12_yonetim_paneli.sql`). Buradaki [isAdmin] yalnız
/// ARAYÜZÜN girişi göstermesi içindir; `true` döndürmek hiçbir şeyin
/// kilidini açmaz — sunucu her işlemde yeniden sorar.
///
/// Ekranlar yalnız bu arayüzü bilir. Üretimde uygulama
/// `SupabaseAdminRepository`dir (sunucu RPC'leri); `MockAdminRepository`
/// yalnız testte ve ekran turunda kullanılır.
abstract class AdminRepository {
  /// `true` = veri uydurmadır (maket/ekran turu); ekran "değişiklikler
  /// sunucuya gitmez" notunu yalnız bu durumda gösterir.
  bool get isSample;

  /// Oturumdaki hesap yönetici mi? (`admin_is_admin()`; yönetici
  /// olmayana hata değil `false` döner.)
  Future<bool> isAdmin();

  Future<AdminStats> loadStats();
  Future<List<AdminAuditEntry>> loadRecentActions({int limit = 5});

  Future<List<AdminQuestionItem>> loadQuestions(AdminQuestionKind kind);

  /// Yeni soru formundaki kategori seçenekleri (kategori adları).
  Future<List<String>> loadCategories();

  /// Doğrudan onaylı yeni soru ekler; sunucu doğrular (`admin_add_question`).
  Future<void> addQuestion(AdminNewQuestion question);

  /// [edits] verilirse öneri düzeltilmiş hâliyle onaylanır.
  Future<void> approveSuggestion(
    String id, {
    AdminQuestionEdit? edits,
    String? note,
  });
  Future<void> rejectSuggestion(String id, {String? note});
  Future<void> fixQuestion(String id, AdminQuestionEdit edit, {String? note});
  Future<void> retireQuestion(String id, {String? note});
  Future<void> dismissQuestionReports(String id);

  Future<List<AdminContributor>> loadContributors();
  Future<void> rewardContributor(String userId, {required int coins});

  Future<AdminRewardPeriod> loadRewardPeriod(AdminRewardPeriodKind kind);
  Future<void> grantReward(
    AdminRewardPeriodKind kind,
    String periodKey, {
    required String userId,
    required int coins,
  });
  Future<bool> loadAutoReward();
  Future<void> setAutoReward(bool enabled);

  Future<List<AdminUserReport>> loadUserReports();
  Future<void> moderateUser(
    String userId,
    AdminUserAction action, {
    int days = 0,
    String? note,
  });

  Future<Map<AdminNotifyKind, bool>> loadNotifyPrefs();
  Future<void> setNotifyPref(AdminNotifyKind kind, bool enabled);

  /// Bağlamdan depoyu okur; sağlayıcı yoksa `null` (izole widget testleri
  /// ve yönetici olmayan üretim yapısı kırılmaz — giriş hiç görünmez).
  static AdminRepository? maybeOf(BuildContext context) {
    try {
      return Provider.of<AdminRepository>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
