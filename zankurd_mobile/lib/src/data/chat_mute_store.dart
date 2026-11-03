import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "Sustur": benim cihazımda bir oyuncunun oda/lobi mesajlarını ve tepkilerini
/// gizler. Sunucuya hiçbir şey yazılmaz — engelleme ([blockPlayer]) ve
/// bildirme sunucu kaydıdır, susturma yalnız benim görünümümdür ve geri
/// alınabilir.
///
/// Hesap başına saklanır (`chat_muted_v1_<kullanıcı kimliği>`): aynı cihazda
/// hesap değiştirince bir hesabın susturduğu öteki hesapta gizli kalmasın.
/// Kimlik yoksa (oturum açılmamış) yalnız bellekte tutulur, diske yazılmaz.
class ChatMuteStore extends ChangeNotifier {
  ChatMuteStore();

  /// Uygulama genelinde tek örnek; testler kendi örneğini kurar.
  static final ChatMuteStore instance = ChatMuteStore();

  static const String keyPrefix = 'chat_muted_v1_';

  String? _userId;
  Set<String> _ids = <String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get mutedIds => Set.unmodifiable(_ids);

  bool isMuted(String? senderId) => senderId != null && _ids.contains(senderId);

  Future<void>? _loading;
  String? _loadingFor;

  /// Hesabın listesini diskten okur. Aynı hesap için tekrar çağrı ucuzdur
  /// ve süren okumayı paylaşır.
  Future<void> load(String? userId) {
    if (_loaded && _userId == userId) return Future<void>.value();
    final inFlight = _loading;
    if (inFlight != null && _loadingFor == userId) return inFlight;
    _loadingFor = userId;
    final run = _load(userId).whenComplete(() {
      _loading = null;
      _loadingFor = null;
    });
    _loading = run;
    return run;
  }

  Future<void> _load(String? userId) async {
    _userId = userId;
    _loaded = false;
    _ids = <String>{};
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _ids = (prefs.getStringList('$keyPrefix$userId') ?? const <String>[])
            .toSet();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'chat_mute_load');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Durumu tersine çevirir ve YENİ durumu (`true` = susturuldu) döndürür.
  /// Liste henüz okunmadıysa önce okunur: menü açıldığı andaki bayat durum
  /// değil, eylem anındaki gerçek durum esas alınır.
  Future<bool> toggle(String senderId, {required String? userId}) async {
    await load(userId);
    final next = !isMuted(senderId);
    await setMuted(senderId, next);
    return next;
  }

  Future<void> setMuted(String senderId, bool muted) async {
    final changed = muted ? _ids.add(senderId) : _ids.remove(senderId);
    if (!changed) return;
    notifyListeners();
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$keyPrefix$userId', _ids.toList()..sort());
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'chat_mute_save');
    }
  }
}
