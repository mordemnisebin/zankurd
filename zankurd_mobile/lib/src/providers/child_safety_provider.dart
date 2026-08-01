import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Çocuk modu açıkken sosyal etkileşim ve dışa paylaşım kapılarını yönetir.
class ChildSafetyProvider extends ChangeNotifier {
  ChildSafetyProvider({bool initialEnabled = false})
    : _enabled = initialEnabled;

  static const _storageKey = 'zankurd.childSafetyEnabled';

  bool _enabled;

  bool get enabled => _enabled;

  bool get allowFriendSearch => !_enabled;

  bool get allowExternalShare => !_enabled;

  static Future<ChildSafetyProvider> load() async {
    var enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_storageKey) ?? false;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'child_safety_load');
    }
    return ChildSafetyProvider(initialEnabled: enabled);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'child_safety_persist');
    }
  }
}
