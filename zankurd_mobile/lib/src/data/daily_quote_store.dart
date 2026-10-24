import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../theme/sahne.dart';
import '../utils/error_reporter.dart';

/// "Gotina rojê / Günün sözü" derleminin tek öğesi.
class DailyQuote {
  const DailyQuote({
    required this.id,
    required this.ku,
    required this.tr,
    required this.source,
    required this.theme,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) => DailyQuote(
    id: json['id'] as String,
    ku: json['ku'] as String,
    tr: json['tr'] as String,
    source: (json['kaynak'] as String?) ?? '',
    theme: (json['tema'] as String?) ?? '',
  );

  final String id;
  final String ku;
  final String tr;
  final String source;
  final String theme;
}

/// Günün sözünü yükler ve seçer.
///
/// ## Seçim kuralı
///
/// Herkes aynı gün aynı sözü görür: indeks, YEREL takvim gününün numarası
/// (yıl-ay-gün alanlarından; UTC kaymasından bağımsız) modulo derlem
/// uzunluğudur. Derlem `id`ye göre sıralanır; dosyadaki sıra değişse de
/// aynı gün aynı söz kalır. Saat kaynağı [SahneClock]tur (testler
/// sabitler); gün değişince bir sonraki çizimde yeni söz seçilir.
class DailyQuoteStore {
  DailyQuoteStore._();

  static const assetPath = 'assets/data/gotin_roje.json';

  static List<DailyQuote>? _cache;
  static Future<List<DailyQuote>>? _pending;

  /// Yüklenmişse derlem (eşzamanlı okuma için), yoksa `null`.
  static List<DailyQuote>? get cached => _cache;

  /// JSON'u BİR kez okur ve önbellekler. Okunamazsa boş liste (kart çizilmez).
  static Future<List<DailyQuote>> load({AssetBundle? bundle}) {
    final cache = _cache;
    if (cache != null) return Future.value(cache);
    return _pending ??= _read(bundle ?? rootBundle);
  }

  static Future<List<DailyQuote>> _read(AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString(assetPath);
      final list = [
        for (final e in jsonDecode(raw) as List<dynamic>)
          DailyQuote.fromJson(e as Map<String, dynamic>),
      ]..sort((a, b) => a.id.compareTo(b.id));
      return _cache = List.unmodifiable(list);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'daily_quote_load');
      return const [];
    } finally {
      _pending = null;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _cache = null;
    _pending = null;
  }

  /// Yerel gün numarası: DST ve saat dilimi etkilemez (alanlar UTC'ye
  /// taşınıp gün farkı alınır).
  static int dayNumber(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;

  /// [quotes]tan [now] gününün sözü; boşsa `null`. Sıralama `id`ye göredir.
  static DailyQuote? pick(List<DailyQuote> quotes, [DateTime? now]) {
    if (quotes.isEmpty) return null;
    final sorted = [...quotes]..sort((a, b) => a.id.compareTo(b.id));
    final day = dayNumber(now ?? SahneClock.now());
    return sorted[day % sorted.length];
  }
}
