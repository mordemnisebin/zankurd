import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Uygulama içi mağaza değerlendirmesini doğru anda, bir kez ister.
///
/// Tetikleyici: en az [_minQuizzes] quiz tamamlandıktan sonra, skoru
/// [_minAccuracy] (yüzde) ve üzeri olan bir quizde — daha önce istenmemişse.
class ReviewService {
  ReviewService._(this._preferences, this._completedQuizzes, this._requested);

  static const _completedKey = 'zankurd.review.completedQuizzes';
  static const _requestedKey = 'zankurd.review.requested';
  static const _minQuizzes = 5;
  static const _minAccuracy = 70;

  static ReviewService? _instance;

  /// Test'lerde mağaza çağrısını taklit etmek için enjekte edilebilir.
  static Future<bool> Function() availabilityCheck = () =>
      InAppReview.instance.isAvailable();
  static Future<void> Function() requestReviewFn = () =>
      InAppReview.instance.requestReview();

  /// Test'lerde mağaza sayfasını açma çağrısını taklit etmek için enjekte edilebilir.
  static Future<void> Function() openStoreListingFn = () =>
      InAppReview.instance.openStoreListing();

  final SharedPreferences? _preferences;
  int _completedQuizzes;
  bool _requested;

  int get completedQuizzes => _completedQuizzes;
  bool get alreadyRequested => _requested;

  static Future<ReviewService> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'review_service');
      preferences = null;
    }
    return _instance = ReviewService._(
      preferences,
      preferences?.getInt(_completedKey) ?? 0,
      preferences?.getBool(_requestedKey) ?? false,
    );
  }

  static void resetInstance() => _instance = null;

  /// Kullanıcı "Değerlendir" bağlantısına dokununca mağaza sayfasını açar.
  /// [requestReview]'dan farklı olarak koşulsuz olarak mağaza listesini açar.
  static Future<void> openStoreListing() => openStoreListingFn();

  /// Belirli bir quiz skoruyla değerlendirme istenmeli mi? (yan etkisiz)
  bool shouldRequest({required int accuracyPercent}) {
    if (_requested) return false;
    if (_completedQuizzes < _minQuizzes) return false;
    return accuracyPercent >= _minAccuracy;
  }

  /// Quiz tamamlandığında çağrılır. Sayaç artar; koşullar uygunsa
  /// mağaza değerlendirmesi istenir ve bir daha istenmemek üzere işaretlenir.
  /// Değerlendirme istendiyse true döner.
  Future<bool> recordQuizCompletion({required int accuracyPercent}) async {
    _completedQuizzes += 1;
    await _preferences?.setInt(_completedKey, _completedQuizzes);

    if (!shouldRequest(accuracyPercent: accuracyPercent)) return false;

    // Mağaza değerlendirmesi bir iyileştirmedir, turun parçası değil.
    //
    // `availabilityCheck` ve `requestReviewFn` platform kanalına iner
    // (InAppReview) ve desteklenmeyen cihazda, mağaza uygulaması yokken
    // ya da Play Services eksikken fırlatabilir. İkisi de korumasızdı ve
    // çağıran `quiz_result_screen._recordProgress` zincirinin ortasında
    // duruyordu: buradan kaçan bir istisna XP'yi, görev bildirimlerini,
    // rozetleri ve seviye atlama diyaloğunu birden düşürüyordu — çünkü
    // hepsini gösteren `setState` bu satırın ALTINDAYDI (2026-07-31).
    //
    // İstek başarısız olursa yalnız istek kaybolur; `_requested` de
    // işaretlenmez, bir sonraki uygun turda yeniden denenir.
    try {
      final available = await availabilityCheck();
      if (!available) return false;
      await requestReviewFn();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'in_app_review request');
      return false;
    }

    _requested = true;
    await _preferences?.setBool(_requestedKey, true);
    return true;
  }
}
