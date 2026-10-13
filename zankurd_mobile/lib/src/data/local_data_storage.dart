import 'package:shared_preferences/shared_preferences.dart';

/// Yerel anahtar-değer ve liste depolama soyutlaması.
///
/// SharedPreferences, bellek-içi sahte (mock) depolar veya ileride
/// eklenecek SQLite/Drift yerel tabloları bu arayüz üzerinden çalışır.
abstract interface class LocalDataStorage {
  List<String>? getStringList(String key);

  /// true yalnızca depo yazımı kabul ettiğinde döner.
  Future<bool> setStringList(String key, List<String> value);

  String? getString(String key);
  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);
}

/// [SharedPreferences] tabanlı varsayılan yerel depo uygulayıcısı.
class SharedPrefsDataStorage implements LocalDataStorage {
  SharedPrefsDataStorage(this._preferences);

  final SharedPreferences? _preferences;

  @override
  List<String>? getStringList(String key) {
    return _preferences?.getStringList(key);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    final preferences = _preferences;
    if (preferences == null) return false;
    return preferences.setStringList(key, value);
  }

  @override
  String? getString(String key) {
    return _preferences?.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final preferences = _preferences;
    if (preferences == null) return false;
    return preferences.setString(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    final preferences = _preferences;
    if (preferences == null) return false;
    return preferences.remove(key);
  }
}

/// Testler ve çevrimdışı/desteksiz ortamlar için bellek-içi depo.
class InMemoryDataStorage implements LocalDataStorage {
  final Map<String, dynamic> _data = {};

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is List<String>) return List.unmodifiable(value);
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = List<String>.from(value);
    return true;
  }

  @override
  String? getString(String key) {
    final value = _data[key];
    if (value is String) return value;
    return null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }
}
