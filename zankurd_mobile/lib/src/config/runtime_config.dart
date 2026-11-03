import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Sunucudan okunan çalışma ayarı: asgari/son sürüm, bakım iletisi ve
/// riskli özellikler için kapatma anahtarları (`public.app_runtime_config`,
/// bkz. `supabase/2026-11-04_uzak_ayar.sql`).
///
/// ## Niçin var
///
/// 10 bin+ kullanıcı öncesi denetimde (olcek_*) iki boşluk görüldü: özellik
/// bayrakları DERLEME-ZAMANI sabitiydi (`feature_flags.dart`), yani canlıda
/// sorun çıkaran bir özelliği kapatmak yeni sürüm + mağaza incelemesi
/// demekti; ve eski sürümleri zorla yükseltmenin yolu yoktu.
///
/// ## Sözleşme (bozulmaması gereken)
///
/// * Varsayılan [RuntimeConfig.defaults]: HER ŞEY AÇIK, zorunlu güncelleme
///   YOK. Sunucu ulaşılamazsa, tablo henüz yoksa ya da cevap bozuksa
///   uygulama bugünkü gibi çalışır; uzak ayar yalnız KAPATIR/yükseltir.
/// * Açılışı ASLA bekletmez: önbellek tek `SharedPreferences` okumasıdır,
///   ağ isteği arka planda yürür ve hatası yutulup raporlanır.
/// * Bayrak = derleme-zamanı sabit VE uzak anahtar (bkz. `FeatureGate`).
@immutable
class RuntimeConfig {
  const RuntimeConfig({
    this.minSupportedBuildIos = 0,
    this.minSupportedBuildAndroid = 0,
    this.latestBuildIos = 0,
    this.latestBuildAndroid = 0,
    this.maintenanceMessageTr,
    this.maintenanceMessageKu,
    this.asyncDuel = true,
    this.tournament = true,
    this.crowdRooms = true,
    this.chat = true,
    this.pushV2 = true,
    this.shareChallenge = true,
    this.streakRescue = true,
  });

  /// Sunucuya hiç ulaşılamamış cihazın değeri: her şey açık, güncelleme yok.
  static const defaults = RuntimeConfig();

  final int minSupportedBuildIos;
  final int minSupportedBuildAndroid;
  final int latestBuildIos;
  final int latestBuildAndroid;
  final String? maintenanceMessageTr;
  final String? maintenanceMessageKu;
  final bool asyncDuel;
  final bool tournament;
  final bool crowdRooms;
  final bool chat;
  final bool pushV2;
  final bool shareChallenge;
  final bool streakRescue;

  /// Tablo satırından (PostgREST JSON'u) kurar. Eksik/yanlış tipli alan
  /// varsayılana düşer: bozuk bir satır uygulamayı kapatmamalı.
  factory RuntimeConfig.fromJson(Map<String, dynamic> json) {
    int intOf(String key) {
      final value = json[key];
      if (value is int && value >= 0) return value;
      if (value is num && value >= 0) return value.toInt();
      return 0;
    }

    bool boolOf(String key) {
      final value = json[key];
      return value is bool ? value : true;
    }

    String? textOf(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return RuntimeConfig(
      minSupportedBuildIos: intOf('min_supported_build_ios'),
      minSupportedBuildAndroid: intOf('min_supported_build_android'),
      latestBuildIos: intOf('latest_build_ios'),
      latestBuildAndroid: intOf('latest_build_android'),
      maintenanceMessageTr: textOf('maintenance_message_tr'),
      maintenanceMessageKu: textOf('maintenance_message_ku'),
      asyncDuel: boolOf('async_duel_enabled'),
      tournament: boolOf('tournament_enabled'),
      crowdRooms: boolOf('crowd_rooms_enabled'),
      chat: boolOf('chat_enabled'),
      pushV2: boolOf('push_v2_enabled'),
      shareChallenge: boolOf('share_challenge_enabled'),
      streakRescue: boolOf('streak_rescue_enabled'),
    );
  }

  Map<String, dynamic> toJson() => {
    'min_supported_build_ios': minSupportedBuildIos,
    'min_supported_build_android': minSupportedBuildAndroid,
    'latest_build_ios': latestBuildIos,
    'latest_build_android': latestBuildAndroid,
    'maintenance_message_tr': maintenanceMessageTr,
    'maintenance_message_ku': maintenanceMessageKu,
    'async_duel_enabled': asyncDuel,
    'tournament_enabled': tournament,
    'crowd_rooms_enabled': crowdRooms,
    'chat_enabled': chat,
    'push_v2_enabled': pushV2,
    'share_challenge_enabled': shareChallenge,
    'streak_rescue_enabled': streakRescue,
  };

  /// Bu platformdaki asgari build (0 = sınır yok). Web'de sınır yoktur.
  int minBuildFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => minSupportedBuildIos,
    TargetPlatform.android => minSupportedBuildAndroid,
    _ => 0,
  };

  int latestBuildFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => latestBuildIos,
    TargetPlatform.android => latestBuildAndroid,
    _ => 0,
  };

  /// [build] asgarinin altında mı? Build bilinmiyorsa (`null`/0) HAYIR:
  /// emin olunamayan cihaz kilitlenmez.
  bool requiresUpdate(int? build, TargetPlatform platform) {
    if (build == null || build <= 0 || kIsWeb) return false;
    final min = minBuildFor(platform);
    return min > 0 && build < min;
  }

  /// [build] son sürümün altında mı (yumuşak öneri)?
  bool hasNewerBuild(int? build, TargetPlatform platform) {
    if (build == null || build <= 0 || kIsWeb) return false;
    final latest = latestBuildFor(platform);
    return latest > 0 && build < latest;
  }

  String? maintenanceMessage({required bool isKu}) => isKu
      ? (maintenanceMessageKu ?? maintenanceMessageTr)
      : (maintenanceMessageTr ?? maintenanceMessageKu);
}

/// Tabloyu okuyan işlev; testler ve `main()` kendi okuyucusunu verir.
typedef RuntimeConfigFetcher = Future<Map<String, dynamic>?> Function();

/// [RuntimeConfig]'in sahibi: önbellekten yükler, arka planda tazeler.
class RuntimeConfigService extends ChangeNotifier {
  RuntimeConfigService({
    RuntimeConfig initial = RuntimeConfig.defaults,
    this.fetcher,
    this.staleAfter = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _value = initial,
       _clock = clock ?? DateTime.now {
    current = initial;
  }

  /// Önbellek anahtarı (JSON) ve son başarılı okuma zamanı.
  static const cacheKey = 'zankurd.runtimeConfig.v1';

  /// Bağlamı olmayan katmanların (ör. `FeatureGate`) okuduğu tek boğaz
  /// noktası; [AnalyticsConsentProvider.isEnabled] ile aynı desen. Her değişimde
  /// güncellenir. Testler `RuntimeConfigService.debugReset()` ile sıfırlar.
  static RuntimeConfig current = RuntimeConfig.defaults;

  @visibleForTesting
  static void debugReset() => current = RuntimeConfig.defaults;

  RuntimeConfigFetcher? fetcher;
  final Duration staleAfter;
  final DateTime Function() _clock;

  RuntimeConfig _value;
  DateTime? _lastAttempt;
  Future<void>? _inFlight;
  bool _disposed = false;

  RuntimeConfig get value => _value;

  /// Önbellekten yükler; hata ya da yokluk = varsayılan. Ağa GİTMEZ.
  static Future<RuntimeConfigService> load({
    RuntimeConfigFetcher? fetcher,
    Duration staleAfter = const Duration(minutes: 15),
  }) async {
    var initial = RuntimeConfig.defaults;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          initial = RuntimeConfig.fromJson(decoded);
        }
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'runtime_config_cache_load');
    }
    return RuntimeConfigService(
      initial: initial,
      fetcher: fetcher,
      staleAfter: staleAfter,
    );
  }

  /// Son DENEMEDEN bu yana [staleAfter] geçtiyse tazeler (öne dönüşte çağrılır).
  Future<void> refreshIfStale() {
    final last = _lastAttempt;
    if (last != null && _clock().difference(last) < staleAfter) {
      return _inFlight ?? Future<void>.value();
    }
    return refresh();
  }

  /// Sunucudan okur; aynı anda tek istek. Hata sessizdir: eski değer kalır.
  Future<void> refresh() {
    final running = _inFlight;
    if (running != null) return running;
    final fetch = fetcher;
    if (fetch == null) return Future<void>.value();
    _lastAttempt = _clock();
    final future = _refresh(fetch).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _refresh(RuntimeConfigFetcher fetch) async {
    try {
      final row = await fetch().timeout(const Duration(seconds: 8));
      if (row == null) return;
      final next = RuntimeConfig.fromJson(row);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(next.toJson()));
      } catch (_) {}
      _apply(next);
    } catch (_) {
      // Ağ yok, tablo yok ya da zaman aşımı: eski değer geçerli. Bu normal
      // bir durumdur (çevrimdışı oyun), hata raporu gürültüsü üretmez.
    }
  }

  void _apply(RuntimeConfig next) {
    if (_disposed) return;
    _value = next;
    current = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
