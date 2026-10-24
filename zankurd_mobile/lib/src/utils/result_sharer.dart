import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_progress_scope.dart';
import '../l10n/strings.dart';
import '../widgets/share_story_card.dart';
import 'error_reporter.dart';
import 'percent_format.dart';

/// Quiz sonucunu markalı bir kart görseli olarak paylaşır.
///
/// Kart ekran dışında render edilip PNG'ye çevrilir ve share_plus ile
/// paylaşılır. Görsel üretimi herhangi bir nedenle başarısız olursa,
/// güvenli biçimde metin paylaşımına düşülür (her platformda çalışır).
class ResultSharer {
  /// Kullanıcıya özel: aynı cihazda hesap değişince A'nın aldığı ödül B'yi
  /// kilitlemesin (bkz. `LocalProgressScope`).
  static String get _shareRewardDateKey =>
      LocalProgressScope.physical('zankurd.shareReward.lastDate');

  /// Günlük ilk paylaşım ödülü verilebilir mi?
  static Future<bool> canClaimDailyShareReward([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(now ?? DateTime.now());
    final last = prefs.getString(_shareRewardDateKey);
    return last != today;
  }

  /// Günü "ödül alındı" diye işaretler. YALNIZ sunucu ödülü gerçekten
  /// verdikten sonra çağrılır; önce işaretlemek, sunucu isteği düşerse
  /// oyuncuyu gün boyu ödülsüz bırakırdı.
  static Future<void> markDailyShareRewardClaimed([DateTime? now]) =>
      _mark(_shareRewardDateKey, _dateKey(now ?? DateTime.now()));

  static Future<void> _mark(String physicalKey, String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(physicalKey, day);
  }

  /// Devam eden işlemler: "fiziksel anahtar|gün" başına TEK uçuş.
  static final Set<String> _inFlight = <String>{};

  /// Günlük paylaşım ödülünü tek adımda çözer: hak varsa [awardCoins]
  /// çağrılır, miktar > 0 ise gün işaretlenir ve `true` döner. Hata ya da 0
  /// (sunucu vermedi) günü YAKMAZ; sonraki paylaşımda yeniden denenir.
  ///
  /// Kullanıcıya özel anahtar ve gün işlem BAŞINDA sabitlenir: istek sürerken
  /// hesap değişirse işaret yanlış kullanıcıya yazılmaz. Aynı anahtar+gün için
  /// eşzamanlı ikinci çağrı sunucuya gitmeden `false` döner (çift ödül yok).
  static Future<bool> settleDailyShareReward({
    required Future<int> Function() awardCoins,
    DateTime? now,
  }) async {
    final physicalKey = _shareRewardDateKey;
    final day = _dateKey(now ?? DateTime.now());
    final flightKey = '$physicalKey|$day';
    if (!_inFlight.add(flightKey)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(physicalKey) == day) return false;
      final int amount;
      try {
        amount = await awardCoins();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'share_reward_award');
        return false;
      }
      if (amount <= 0) return false;
      await _mark(physicalKey, day);
      return true;
    } finally {
      _inFlight.remove(flightKey);
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<void> share(
    BuildContext context, {
    required bool isKu,
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int bestStreak,
    required String category,
    List<bool> results = const [],
    bool duelWin = false,
  }) async {
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    final text = Tr.forKu(K.resultShareText, isKu, {
      'score': '$score',
      'correct': '$correctCount',
      'total': '$totalQuestions',
      'percent': PercentFormat.value(accuracy, isKu: isKu),
    });

    final overlay = Overlay.maybeOf(context);
    final stars = accuracy >= 80
        ? 3
        : accuracy >= 50
        ? 2
        : 1;
    // Hikâye (1080×1920) ve kare (1080×1080) görsel; ikisi de paylaşılır.
    final images = <Uint8List>[];
    if (overlay != null) {
      for (final format in ShareCardFormat.values) {
        final bytes = await _captureCard(
          overlay,
          ShareStoryCard(
            isKu: isKu,
            format: format,
            scoreText: '$correctCount/$totalQuestions',
            category: category,
            stars: stars,
            duelWin: duelWin,
          ),
        );
        if (bytes != null) images.add(bytes);
      }
    }

    try {
      if (images.isNotEmpty) {
        final names = ['zankurd_story.png', 'zankurd_square.png'];
        final files = [
          for (var i = 0; i < images.length; i++)
            XFile.fromData(images[i], mimeType: 'image/png', name: names[i]),
        ];
        await SharePlus.instance.share(ShareParams(text: text, files: files));
        return;
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'result_share_capture');
      // Görsel paylaşımı başarısız — metne düş.
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Verilen widget'ı ekran dışında render edip PNG byte'larına çevirir.
  static Future<Uint8List?> _captureCard(
    OverlayState overlay,
    Widget card,
  ) async {
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        // Görünür alanın dışında; yine de layout edilip boyanır.
        left: -4000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: boundaryKey, child: card),
        ),
      ),
    );

    try {
      overlay.insert(entry);
      // Kartın layout + paint olması için birkaç frame bekle.
      await Future<void>.delayed(const Duration(milliseconds: 32));
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final image = await renderObject.toImage(pixelRatio: 1);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'result_share_send');
      return null;
    } finally {
      entry.remove();
    }
  }
}
