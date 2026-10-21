import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Uygulama içi mağaza değerlendirmesini doğru anda, bir kez ister.
///
/// Tetikleyici: en az [_minQuizzes] quiz tamamlandıktan, en az [_minDays]
/// FARKLI günde oynandıktan sonra, son turun skoru [_minAccuracy] (yüzde) ve
/// üzeriyse — daha önce istenmemişse.
///
/// İstek turun tamamlanmasında DEĞİL, oyuncu sonuç ekranından ana sayfaya
/// dönerken ([requestIfDue]) yapılır. Eskiden ilk 5/5 kısa testin hemen
/// ardından, sonuç ekranı henüz okunurken iOS puanlama penceresi çıkıp öğrenme
/// akışını kesiyordu (2026-10-21 simülatör düğme turu); ilk oturumdaki
/// kullanıcı henüz uygulamanın değerini görmemişti.
class ReviewService {
  ReviewService._(
    this._preferences,
    this._completedQuizzes,
    this._requested,
    this._days,
  );

  static const _completedKey = 'zankurd.review.completedQuizzes';
  static const _requestedKey = 'zankurd.review.requested';
  static const _daysKey = 'zankurd.review.days';
  static const _minQuizzes = 3;
  static const _minDays = 2;
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
  final Set<String> _days;

  /// Son tamamlanan turun doğruluğu (yalnız bellekte; istek anında okunur).
  int _lastAccuracy = 0;

  int get completedQuizzes => _completedQuizzes;
  bool get alreadyRequested => _requested;
  int get distinctDays => _days.length;

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
      <String>{...?preferences?.getStringList(_daysKey)},
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
    if (_days.length < _minDays) return false;
    return accuracyPercent >= _minAccuracy;
  }

  /// Quiz tamamlandığında çağrılır: yalnız SAYAR (tur sayısı, farklı gün,
  /// son doğruluk). Pencere burada açılmaz; bkz. [requestIfDue].
  Future<void> recordQuizCompletion({
    required int accuracyPercent,
    DateTime? now,
  }) async {
    _completedQuizzes += 1;
    _lastAccuracy = accuracyPercent;
    final d = now ?? DateTime.now();
    _days.add(
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}',
    );
    await _preferences?.setInt(_completedKey, _completedQuizzes);
    await _preferences?.setStringList(_daysKey, _days.toList());
  }

  /// Oyuncu sonuç ekranından ana sayfaya döndüğünde çağrılır: koşullar
  /// uygunsa mağaza değerlendirmesi istenir ve bir daha istenmemek üzere
  /// işaretlenir. Değerlendirme istendiyse true döner.
  Future<bool> requestIfDue() async {
    if (!shouldRequest(accuracyPercent: _lastAccuracy)) return false;
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
