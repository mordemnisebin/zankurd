import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PresenceGateway {
  Future<bool> loadVisibility();
  Future<void> setVisibility(bool visible);
  Future<void> touch();
}

class SupabasePresenceGateway implements PresenceGateway {
  SupabasePresenceGateway(this.client);

  final SupabaseClient client;

  @override
  Future<bool> loadVisibility() async =>
      await client.rpc<bool>('get_presence_visibility');

  @override
  Future<void> setVisibility(bool visible) async {
    await client.rpc<void>(
      'set_presence_visibility',
      params: {'p_visible': visible},
    );
  }

  @override
  Future<void> touch() async {
    await client.rpc<void>('touch_presence');
  }
}

/// Hesaba bağlı, açık rızalı varlık. Misafir de gerçek auth oturumudur.
/// Yerel tercihi sunucuya geri yazmaz; her turda sunucudan yeniden okur.
/// Eski göç / bağlantı hatasında varsayılan kapalı, hata sessizdir.
class PresenceController extends ChangeNotifier with WidgetsBindingObserver {
  PresenceGateway? _gateway;
  String? _userId;
  Timer? _timer;
  bool _foreground = false;
  bool _observing = false;
  bool _disposed = false;
  bool _enabled = false;
  bool _ready = false;
  bool _saving = false;
  int _generation = 0;
  int? _pollGeneration;

  bool get enabled => _enabled;
  bool get ready => _ready;
  bool get canChange => _ready && !_saving && _userId != null;
  static const _timeout = Duration(seconds: 10);

  void bind(PresenceGateway gateway, {required String? userId}) {
    _gateway = gateway;
    if (!_observing) {
      try {
        final binding = WidgetsBinding.instance;
        _foreground = binding.lifecycleState == AppLifecycleState.resumed;
        binding.addObserver(this);
        _observing = true;
      } catch (_) {
        // Binding henüz yoksa ön planda olduğumuzu varsayma.
      }
    }
    _reset(userId);
  }

  void updateSession(String? userId) {
    if (_userId != userId) _reset(userId);
  }

  void _reset(String? userId) {
    _generation++;
    _userId = userId;
    _enabled = false;
    _ready = false;
    _saving = false;
    _restart();
    _notify();
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && _userId != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_foreground || _userId == null || _gateway == null) {
      return;
    }
    unawaited(_pulse());
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_pulse());
    });
  }

  Future<void> _pulse() async {
    final generation = _generation;
    final gateway = _gateway;
    if (!_current(generation) ||
        !_foreground ||
        _saving ||
        gateway == null ||
        _pollGeneration == generation) {
      return;
    }
    _pollGeneration = generation;
    try {
      final visible = await gateway.loadVisibility().timeout(_timeout);
      if (!_current(generation) || !_foreground || _saving) return;
      _enabled = visible;
      _ready = true;
      _notify();
      if (visible) await gateway.touch().timeout(_timeout);
    } catch (_) {
      // İstemci yoklaması öğrenme/yarış akışını ve hata raporlarını kirletmez.
    } finally {
      if (_pollGeneration == generation) _pollGeneration = null;
    }
  }

  /// Kapatma isteği başladığı anda yeni kalp atışları durur. Sunucunun
  /// onayı gelmeden UI başarı göstermez; zaman aşımı da başarısızlıktır.
  Future<bool> setEnabled(bool enabled) async {
    final gateway = _gateway;
    if (!canChange || gateway == null) return false;
    final generation = ++_generation; // Önceki okuma sonucu tercihi ezmesin.
    _saving = true;
    _timer?.cancel();
    _notify();
    var saved = false;
    try {
      await gateway.setVisibility(enabled).timeout(_timeout);
      if (!_current(generation)) return false;
      _enabled = enabled;
      saved = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_current(generation)) {
        _saving = false;
        _notify();
        // Yazma başarısızsa hemen kalp atışı yollama. Sonraki tur tercihi
        // yeniden okur; kapanma ağda gerçekleşmiş olabilir.
        if (saved) {
          _restart();
        } else if (_foreground) {
          _timer = Timer.periodic(const Duration(minutes: 2), (_) {
            unawaited(_pulse());
          });
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    // Arka plana geçişten önce başlayan okuma dönüşte touch başlatamaz.
    // Yazma nesli korunur: kullanıcı tercihi yaşam döngüsünden bağımsızdır.
    if (!_saving) _generation++;
    _restart();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
