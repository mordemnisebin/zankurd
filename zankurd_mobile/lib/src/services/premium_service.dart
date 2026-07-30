import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import '../utils/error_reporter.dart';

/// Satın alma akışının sonucu. `bool` yeterli değildi: iptal ile hata,
/// ve askıdaki ödeme ile başarısızlık aynı şeye indirgeniyordu.
enum PurchaseOutcome {
  success,
  cancelled,

  /// "Ask to Buy" / aile onayı bekleniyor.
  pending,
  failed,

  /// Zaten devam eden bir satın alma var.
  inProgress,
}

enum RestoreOutcome { restored, nothingFound, failed }

/// RevenueCat hesap geçişlerini sıraya koyar. Hızlı çıkış/giriş sırasında
/// yavaş tamamlanan eski bir çağrının yeni hesabı ezmesini önler.
class PremiumIdentityQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> schedule(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }
}

/// Aylık abonelik altyapısı. Kullanıcının aktif `premium` entitlement'ı
/// varsa reklamsız, detaylı istatistik, sınırsız joker gibi özellikler
/// açılır. API anahtarı yoksa tüm premium özellikler kapalı kalır ve
/// uygulama normal akışına devam eder.
///
/// Singleton; [load] çağrısı main() içinde yapılmalıdır.
class PremiumService extends ChangeNotifier {
  PremiumService._();

  static const _entitlementId = 'premium';

  static PremiumService? _instance;

  bool _initialized = false;
  bool _configured = false;
  bool _isPremium = false;
  bool _purchaseInProgress = false;
  String? _errorMessage;
  String? _infoMessage;
  String? _linkedUserId;
  final PremiumIdentityQueue _identityQueue = PremiumIdentityQueue();

  static PremiumService? get instance => _instance;

  bool get isInitialized => _initialized;
  bool get isPremium => _isPremium;
  bool get purchaseInProgress => _purchaseInProgress;

  /// Kullanıcıya hata olarak gösterilecek mesaj. Satın almanın kullanıcı
  /// tarafından iptal edilmesi hata DEĞİLDİR ve burada görünmez.
  String? get errorMessage => _errorMessage;

  /// Hata olmayan ama kullanıcıya geri bildirim gereken durumlar:
  /// "geri yüklenecek abonelik bulunamadı", "ödeme onay bekliyor" gibi.
  String? get infoMessage => _infoMessage;

  /// RevenueCat'e bağlı olan Supabase kullanıcı kimliği (varsa).
  String? get linkedUserId => _linkedUserId;

  void clearMessages() {
    if (_errorMessage == null && _infoMessage == null) return;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Test ortamı veya load() daha çağrılmadan önce UI'ın çökmemesini
  /// sağlayan sahte singleton. RevenueCat yapılmaz, abonelik yok sayılır.
  static PremiumService fallback() {
    final fb = PremiumService._();
    fb._initialized = false;
    fb._isPremium = false;
    return fb;
  }

  /// RevenueCat yapılandırması yapılmışsa `configure` çağırır, aksi
  /// halde sessizce devre dışı bırakır (anahtar yoksa satın alma kapalı).
  static Future<PremiumService> load() async {
    if (_instance != null) return _instance!;
    final service = PremiumService._();
    await service._initialize();
    return _instance = service;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final apiKey = AppConfig.revenuecatApiKey;
    if (apiKey.isEmpty) {
      // API anahtarı yoksa satın alma tamamen devre dışıdır; uygulama
      // ücretsiz akışında çalışmaya devam eder.
      _isPremium = false;
      notifyListeners();
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

      // appUserID başlangıçta null (anonim) kalır; oturum açıldığında
      // [logInUser] ile Supabase kullanıcı kimliğine bağlanır. Bağlama
      // olmadan abonelik cihaza yapışır ve aynı cihazda giriş yapan farklı
      // kullanıcılar aynı entitlement'ı paylaşır.
      final configuration = PurchasesConfiguration(apiKey)..appUserID = null;
      await Purchases.configure(configuration);
      _configured = true;

      final info = await Purchases.getCustomerInfo();
      _isPremium = _hasEntitlement(info.entitlements.all);
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium_service init');
    }
    notifyListeners();
  }

  /// RevenueCat müşterisini Supabase kullanıcısına bağlar.
  ///
  /// Böylece abonelik cihaza değil hesaba ait olur: kullanıcı cihaz
  /// değiştirdiğinde entitlement taşınır, aynı cihazda başka bir hesaba
  /// geçildiğinde ise devralınmaz.
  Future<void> logInUser(String userId) => _identityQueue.schedule(() async {
    if (!_configured || userId.isEmpty) return;
    if (_linkedUserId == userId) return;
    try {
      final result = await Purchases.logIn(userId);
      _linkedUserId = userId;
      _applyEntitlement(_hasEntitlement(result.customerInfo.entitlements.all));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium logIn');
    }
  });

  /// Oturum kapanışında RevenueCat kimliğini bırakır ve premium durumunu
  /// sıfırlar. Aksi halde sonraki kullanıcı önceki aboneliği devralır.
  Future<void> logOutUser() => _identityQueue.schedule(() async {
    _linkedUserId = null;
    if (!_configured) {
      _applyEntitlement(false);
      return;
    }
    try {
      final info = await Purchases.logOut();
      _applyEntitlement(_hasEntitlement(info.entitlements.all));
    } catch (error, stack) {
      // Zaten anonim kullanıcıdaysa logOut hata döndürebilir; premium
      // durumunu yine de düşürmek güvenli taraftır.
      ErrorReporter.record(error, stack, reason: 'premium logOut');
      _applyEntitlement(false);
    }
  });

  void _applyEntitlement(bool next) {
    if (next == _isPremium) return;
    _isPremium = next;
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
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    if (_purchaseInProgress) return PurchaseOutcome.inProgress;
    if (!AppConfig.hasRevenuecatConfig) {
      _errorMessage = 'Satın alma bu build\'de yapılandırılmadı.';
      notifyListeners();
      return PurchaseOutcome.failed;
    }
    _purchaseInProgress = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _isPremium = _hasEntitlement(result.customerInfo.entitlements.all);
      _purchaseInProgress = false;
      notifyListeners();
      return _isPremium ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } catch (error, stack) {
      final code = _errorCode(error);
      _purchaseInProgress = false;

      // İptal bir hata değildir: kullanıcı vazgeçti, ekranda kırmızı bir
      // mesaj görmemeli ve Crashlytics'e gürültü gitmemeli.
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        notifyListeners();
        return PurchaseOutcome.cancelled;
      }

      // "Ask to Buy" / aile onayı: satın alma askıda, başarısız değil.
      // Entitlement onay gelince listener üzerinden düşer.
      if (code == PurchasesErrorCode.paymentPendingError) {
        _infoMessage =
            'Ödemen onay bekliyor. Onaylandığında premium otomatik açılacak.';
        notifyListeners();
        return PurchaseOutcome.pending;
      }

      // Ürün zaten aktifse bu bir hata değil, geri yükleme durumudur.
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        await restorePurchases();
        return _isPremium ? PurchaseOutcome.success : PurchaseOutcome.failed;
      }

      ErrorReporter.record(error, stack, reason: 'premium purchase');
      _errorMessage = _readableErrorMessage(code);
      notifyListeners();
      return PurchaseOutcome.failed;
    }
  }

  /// Daha önce satın alınmış abonelik varsa entitlement yenilenir.
  ///
  /// Geri yüklenecek bir şey bulunmadığında da kullanıcıya geri bildirim
  /// verilir; aksi halde buton çalışmıyormuş gibi görünür (App Store
  /// inceleme reddi gerekçesi).
  Future<RestoreOutcome> restorePurchases() async {
    if (!AppConfig.hasRevenuecatConfig) {
      _errorMessage = 'Geri yükleme bu build\'de yapılandırılmadı.';
      notifyListeners();
      return RestoreOutcome.failed;
    }
    _errorMessage = null;
    _infoMessage = null;
    try {
      final info = await Purchases.restorePurchases();
      _isPremium = _hasEntitlement(info.entitlements.all);
      if (!_isPremium) {
        _infoMessage = 'Bu hesapta geri yüklenecek aktif abonelik bulunamadı.';
      }
      notifyListeners();
      return _isPremium ? RestoreOutcome.restored : RestoreOutcome.nothingFound;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'premium restore');
      _errorMessage = _readableErrorMessage(_errorCode(error));
      notifyListeners();
      return RestoreOutcome.failed;
    }
  }

  /// Test amaçlı premium hesabını sıfırlar (debug menüsü için).
  Future<void> resetForDebug() async {
    _isPremium = false;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  PurchasesErrorCode _errorCode(Object error) {
    if (error is PlatformException) {
      return PurchasesErrorHelper.getErrorCode(error);
    }
    return PurchasesErrorCode.unknownError;
  }

  String _readableErrorMessage(PurchasesErrorCode code) {
    return switch (code) {
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError =>
        'Bağlantı kurulamadı. İnterneti kontrol edip tekrar dene.',
      PurchasesErrorCode.storeProblemError =>
        'Mağazaya ulaşılamadı. Biraz sonra tekrar dene.',
      PurchasesErrorCode.purchaseNotAllowedError =>
        'Bu cihazda satın alma izni kapalı görünüyor.',
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        'Bu paket şu anda satışta değil.',
      PurchasesErrorCode.receiptAlreadyInUseError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
        'Bu abonelik başka bir hesapta kullanılıyor.',
      _ => 'Satın alma sırasında bir hata oldu.',
    };
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
