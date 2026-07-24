import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/error_reporter.dart';

/// Aylık abonelik altyapısı. Kullanıcının aktif `premium` entitlement'ı
/// varsa reklamsız, detaylı istatistik, sınırsız joker gibi özellikler
/// açılır. API anahtarı yoksa tüm premium özellikler kapalı kalır ve
/// uygulama normal akışına devam eder.
///
/// Singleton; [load] çağrısı main() içinde yapılmalıdır.
class PremiumService extends ChangeNotifier {
  PremiumService._(this._prefs);

  static const _activeKey = 'zankurd.premium.lastActiveAt';
  static const _entitlementId = 'premium';

  static PremiumService? _instance;

  final SharedPreferences? _prefs;

  bool _initialized = false;
  bool _isPremium = false;
  bool _purchaseInProgress = false;
  String? _errorMessage;

  static PremiumService? get instance => _instance;

  bool get isInitialized => _initialized;
  bool get isPremium => _isPremium;
  bool get purchaseInProgress => _purchaseInProgress;
  String? get errorMessage => _errorMessage;

  /// Test ortamı veya load() daha çağrılmadan önce UI'ın çökmemesini
  /// sağlayan sahte singleton. RevenueCat yapılmaz, abonelik yok sayılır.
  static PremiumService fallback() {
    final fb = PremiumService._(null);
    fb._initialized = false;
    fb._isPremium = false;
    return fb;
  }

  /// RevenueCat yapılandırması yapılmışsa `configure` çağırır, aksi
  /// halde sessizce devre dışı bırakır (anahtar yoksa debug için mock).
  static Future<PremiumService> load() async {
    if (_instance != null) return _instance!;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium_service prefs');
    }
    final service = PremiumService._(prefs);
    await service._initialize();
    return _instance = service;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final apiKey = AppConfig.revenuecatApiKey;
    if (apiKey.isEmpty) {
      // API anahtarı yoksa debug/test için LOCAL çekirdek uygulanır;
      // satın alma devre dışı, mevcut abonelik SharedPreferences'ten
      // okunur (offline simülasyon).
      _isPremium = false;
      notifyListeners();
      return;
    }

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.error,
      );

      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = null; // vendor UUID — RevenueCat devralır
      await Purchases.configure(configuration);

      final info = await Purchases.getCustomerInfo();
      _isPremium = _hasEntitlement(info.entitlements.all);
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium_service init');
    }
    notifyListeners();
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    final next = _hasEntitlement(info.entitlements.all);
    if (next != _isPremium) {
      _isPremium = next;
      notifyListeners();
    }
  }

  bool _hasEntitlement(Map<String, EntitlementInfo> entitlements) {
    final ent = entitlements[_entitlementId];
    if (ent == null) return false;
    return ent.isActive;
  }

  /// Mevcut offerings listesini getirir. Boş dönerse RevenueCat
  /// tarafında hiçbir ürün tanımlı değil demektir; paywall ekranı
  /// bu durumu bilgilendirme olarak gösterir.
  Future<List<Offering>> fetchOfferings() async {
    if (!AppConfig.hasRevenuecatConfig) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.all.values.toList();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium offerings');
      return const [];
    }
  }

  /// [package] satın alma akışını başlatır; başarılıysa premium aktif olur.
  /// iOS/Android'de native satın alma UI'ını açar.
  Future<bool> purchasePackage(Package package) async {
    if (_purchaseInProgress) return false;
    if (!AppConfig.hasRevenuecatConfig) {
      _errorMessage = 'Satın alma bu build\'de yapılandırılmadı.';
      notifyListeners();
      return false;
    }
    _purchaseInProgress = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await Purchases.purchasePackage(package);
      _isPremium = _hasEntitlement(result.entitlements.all);
      _purchaseInProgress = false;
      notifyListeners();
      return _isPremium;
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'premium purchase',
      );
      _errorMessage = _readableErrorMessage(error);
      _purchaseInProgress = false;
      notifyListeners();
      return false;
    }
  }

  /// Daha önce satın alınmış abonelik varsa entitlement yenilenir.
  Future<void> restorePurchases() async {
    if (!AppConfig.hasRevenuecatConfig) {
      _errorMessage = 'Geri yükleme bu build\'de yapılandırılmadı.';
      notifyListeners();
      return;
    }
    try {
      final info = await Purchases.restorePurchases();
      _isPremium = _hasEntitlement(info.entitlements.all);
      notifyListeners();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'premium restore',
      );
      _errorMessage = _readableErrorMessage(error);
      notifyListeners();
    }
  }

  /// Test amaçlı premium hesabını sıfırlar (debug menüsü için).
  Future<void> resetForDebug() async {
    _isPremium = false;
    _errorMessage = null;
    await _prefs?.remove(_activeKey);
    notifyListeners();
  }

  String _readableErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('userCancelled')) return 'Kullanıcı iptal etti.';
    if (raw.contains('paymentPending')) return 'Ödeme bekleniyor.';
    return 'Satın alma sırasında bir hata oldu.';
  }

  @override
  void dispose() {
    if (AppConfig.hasRevenuecatConfig) {
      try {
        Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdate);
      } catch (_) {}
    }
    super.dispose();
  }
}
