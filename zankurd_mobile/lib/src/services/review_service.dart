import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    } catch (_) {
      preferences = null;
    }
    return _instance = ReviewService._(
      preferences,
      preferences?.getInt(_completedKey) ?? 0,
      preferences?.getBool(_requestedKey) ?? false,
    );
  }

  static void resetInstance() => _instance = null;

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

    final available = await availabilityCheck();
    if (!available) return false;

    await requestReviewFn();
    _requested = true;
    await _preferences?.setBool(_requestedKey, true);
    return true;
  }
}
