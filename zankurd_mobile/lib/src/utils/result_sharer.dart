import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_progress_scope.dart';
import '../models/answer_record.dart';
import 'join_deep_link.dart';
import 'round_words.dart';
import '../l10n/strings.dart';
import '../widgets/share_story_card.dart';
import 'error_reporter.dart';
import 'percent_format.dart';
import 'number_format.dart';

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
    final today = _dateKey(now ?? _istanbulNow());
    final last = prefs.getString(_shareRewardDateKey);
    return last != today;
  }

  /// Günü "ödül alındı" diye işaretler. YALNIZ sunucu ödülü gerçekten
  /// verdikten sonra çağrılır; önce işaretlemek, sunucu isteği düşerse
  /// oyuncuyu gün boyu ödülsüz bırakırdı.
  static Future<void> markDailyShareRewardClaimed([DateTime? now]) =>
      _mark(_shareRewardDateKey, _dateKey(now ?? _istanbulNow()));

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
  }) async =>
      await settleDailyShareRewardAmount(awardCoins: awardCoins, now: now) > 0;

  /// [settleDailyShareReward] ile aynı, ama sunucunun GERÇEKTEN verdiği
  /// miktarı döner (0 = verilmedi). Bildirim metni bu miktarı yazar; sabit
  /// "+25" sunucu başka miktar verirse yalan söylerdi.
  static Future<int> settleDailyShareRewardAmount({
    required Future<int> Function() awardCoins,
    DateTime? now,
  }) async {
    final physicalKey = _shareRewardDateKey;
    final day = _dateKey(now ?? _istanbulNow());
    final flightKey = '$physicalKey|$day';
    if (!_inFlight.add(flightKey)) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(physicalKey) == day) return 0;
      final int amount;
      try {
        amount = await awardCoins();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'share_reward_award');
        return 0;
      }
      if (amount <= 0) return 0;
      await _mark(physicalKey, day);
      return amount;
    } finally {
      _inFlight.remove(flightKey);
    }
  }

  /// Sunucu günü İstanbul (kalıcı UTC+3) takvimidir. Yerel gün kullanılırsa
  /// farklı saat diliminde önceki sunucu gününde alınmış ödül, yeni sunucu günü
  /// başladıktan sonra da yerel gün değişmediği için RPC'ye ulaşmadan
  /// engelleniyordu.
  static DateTime _istanbulNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 3));

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Paylaşım gerçekten yapıldıysa true. `dismissed` (kullanıcı iptal etti)
  /// false döner; `unavailable` (iOS bazı sürümlerde sonucu bildirmez, web vb.)
  /// true sayılır: sonuç bilinemeyen platformda ödülü kesmek sürekli
  /// "ödül yok" demek olurdu, o yüzden kullanıcı lehine.
  static Future<bool> share(
    BuildContext context, {
    required bool isKu,
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int bestStreak,
    required String category,
    List<bool> results = const [],
    bool duelWin = false,
    List<AnswerRecord> records = const [],

    /// Tur bir meydan okuma koduna bağlıysa (`D…`, [JoinDeepLink.isChallengeCode])
    /// metne "skorumu geç" bağlantısı girer; yoksa uygulama bağlantısı.
    String? challengeCode,
  }) async {
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    // Kod normalleştirmesi (büyük harf) `JoinDeepLink.shareUrl` içindedir.
    final challengeUrl = JoinDeepLink.isChallengeCode(challengeCode)
        ? JoinDeepLink.shareUrl(challengeCode!)
        : null;
    // `challengeShareText` "ji 7 pirsan" sabitini taşır (yalnız sırayla düello);
    // serbest turda yalan olurdu, o yüzden normal metne bağlantı eklenir.
    final baseText = Tr.forKu(shareTextKey(), isKu, {
      'score': groupThousands(score),
      'correct': groupThousands(correctCount),
      'total': groupThousands(totalQuestions),
      'percent': PercentFormat.value(accuracy, isKu: isKu),
    });
    final text = challengeUrl != null ? '$baseText $challengeUrl' : baseText;
    final words = [
      for (final e in learnedWordsForRound(records))
        (ku: e.termKu, tr: e.meaningTr),
    ];
    // iPad paylaşım sayfası bir çıkış noktası ister; yoksa PlatformException.
    Rect? origin;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }

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
            scoreText:
                '${groupThousands(correctCount)}/${groupThousands(totalQuestions)}',
            category: category,
            stars: stars,
            duelWin: duelWin,
            words: words,
            linkText: challengeUrl != null
                ? challengeUrl.replaceFirst('https://www.', '')
                : ShareStoryCard.siteLink,
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
        final result = await SharePlus.instance.share(
          ShareParams(text: text, files: files, sharePositionOrigin: origin),
        );
        return statusCounts(result.status);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'result_share_capture');
      // Görsel paylaşımı başarısız — metne düş.
    }
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
      return statusCounts(result.status);
    } catch (error, stack) {
      // Metin yolu da düşerse çağıran (`shareResult`) yakalamıyor; işlenmemiş
      // istisna yerine "paylaşılmadı" döner, ödül de verilmez.
      ErrorReporter.record(error, stack, reason: 'result_share_text');
      return false;
    }
  }

  /// Paylaşım metninin anahtarı: iOS'ta App Store, diğerlerinde Play Store.
  /// Tek "Play Store'da" metni iOS oyuncusunun paylaştığı davette yanlış
  /// mağazayı gösteriyordu.
  @visibleForTesting
  static String shareTextKey([TargetPlatform? platform]) =>
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
      ? K.resultShareTextIos
      : K.resultShareText;

  /// Ödüle sayılan paylaşım durumu (bekçi testi bunu doğrudan sınar).
  @visibleForTesting
  static bool statusCounts(ShareResultStatus status) =>
      status != ShareResultStatus.dismissed;

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
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'result_share_send');
      return null;
    } finally {
      entry.remove();
    }
  }
}
