import 'package:flutter/foundation.dart';

/// Açılış adımlarının zaman aşımı / hatası. `bootStep` yutmaz; buraya yazar.
///
/// 2026-09-06: soru bankası 8 sn'de bitmezse `bootStepVoid` boş fallback
/// ile devam ediyor ve kullanıcıya hiçbir şey söylemiyordu. Ana ekran
/// boş kategorilerle açılıyordu.
class BootDiagnostics extends ChangeNotifier {
  BootDiagnostics();

  static final BootDiagnostics instance = BootDiagnostics();

  final List<String> _failures = [];

  List<String> get failures => List.unmodifiable(_failures);

  bool get hasFailures => _failures.isNotEmpty;

  void recordFailure(String reason) {
    _failures.add(reason);
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _failures.clear();
    notifyListeners();
  }
}
