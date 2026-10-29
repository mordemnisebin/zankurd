import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';
import 'zan_mascot.dart';

/// Bütün soru sahnelerinin ORTAK parçaları (2026-10-28, jüri K6 / K6+).
///
/// Kusur: ders, yarışma, düello ve seviye belirleme sahneyi ayrı ayrı
/// kuruyordu; üst bant konunun rengine boyanıyordu (turkuaz, yeşil, mor…),
/// soru metni boş gradyanın ortasında yüzüyordu, cevaptan sonra yalnız
/// turuncu bir "Sonraki" vardı. Jüri (ChatGPT + Argon + Opus): "aynı
/// uygulamada dört soru ekranı gibi". Karar: tek lacivert sahne, mod üstte
/// tek küçük çip, soru açık bir yüzeyde, cevaptan sonra alttan geri bildirim
/// şeridi (doğru yeşil, yanlış kırmızı; başlık + ≤1 satır + "Sonraki").
///
/// Üç parça burada durur ki dört ekran aynı görünümü TEK yerden alsın.

/// Soru bloğunun üstündeki boşluk: ilk öğe üst çubuğun hemen altından
/// başlar (ekranın ≈ %25–40'ında soru görünür; üstte büyük boş alan yok).
const double quizStageTopGap = SahneSpace.x4;

/// Soru ekranlarında (ders, yarış, günün turu, oda, sırayla düello, seviye
/// belirleme) soru + şıklar grubunun dengeli yerleşim oranı (bkz.
/// `SahneStageScroll.balance`): boş alanın bu kadarı grubun üstünde kalır.
///
/// 2026-10-29 son kurul tur 2 (B, Astra + Sol + Terra): grup cevaptan sonra
/// artık yerinde kalır (`holdBalance`). Ama genel oran (`sahneQuestionBalance`
/// 0.36) üstte ~76 pt boşluk bırakınca 390×844'te yanlış cevabın açıklama
/// kartı perdenin arkasına düşüyor, gövde onu göstermek için kayıyordu: soru
/// yine yerinden oynuyordu. Duolingo'daki gibi grup daha yukarıda başlar
/// (Sol: "ilerleme çizgisiyle soru kartı arasındaki geniş boşluk"); kart
/// şıkların altında kayma olmadan görünür. Grup yine başlığa yapışmaz
/// (R3: dikey merkezi kullanılabilir alanın %30–55'inde) ve Y3 gereği her
/// soru ekranında AYNI orandır.
const double quizQuestionBalance = 0.12;

/// Üst çubuktaki tek küçük mod çipi ("Yarış", "Ders", "Düello"...).
class QuizModeChip extends StatelessWidget {
  const QuizModeChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('quiz-mode-chip'),
      decoration: ShapeDecoration(
        color: t.s2,
        shape: StadiumBorder(side: BorderSide(color: t.optionEdge)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x3,
          vertical: 2,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SahneType.caption.copyWith(
            color: t.tx,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Sorunun açık yüzeyi: koyu sahnede açık kart, içinde gündüz belirteçleri
/// (koyu metin). Okunurluk için TEK karar: soru metni her modda aynı
/// kartta, ≥ 4,5:1 (beyaz zemin üstünde `#0E1433`, ≈ 16:1).
class QuizPromptCard extends StatelessWidget {
  const QuizPromptCard({
    super.key,
    required this.child,
    this.padding = SahneSpace.x4,
  });

  final Widget child;

  /// İç boşluk; soru sığdırma kademesinde (`QuizFit.promptPad`) daralır.
  final double padding;

  @override
  Widget build(BuildContext context) {
    const day = SahneTokens.day;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(extensions: [day]),
      // Vay 2A (2026-10-29): kart sahneden KALKAR — koyu yumuşak gölge
      // (y=6, %30) ve altta 3 px koyu taban; düz beyaz levha gibiydi
      // (Astra: "kartlar fazla düz", Quiz Planet derinliği).
      child: Container(
        key: const ValueKey('quiz-prompt-card'),
        padding: EdgeInsets.all(padding),
        decoration: ShapeDecoration(
          color: day.s1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SahneShape.lValue),
            side: BorderSide(color: day.edge),
          ),
          shadows: [
            BoxShadow(
              color: SahneVayColors.black.withValues(alpha: 0.30),
              offset: const Offset(0, 6),
              blurRadius: 14,
            ),
            BoxShadow(
              color: SahneVayColors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Cevaptan sonra alttan gelen geri bildirim şeridi (Duolingo deseni):
/// doğru yeşil, yanlış kırmızı. Başlık + en çok 1 satır açıklama + aynı
/// şeritte eylem ("Sonraki").
///
/// Durum yalnız renkle verilmez: ikon (✓/✗) ve başlık sözü birliktedir.
///
/// Vay 2A (2026-10-29, Duolingo deseni + VAY B4): şeridin solunda mini
/// maskot (doğruda sevinen, yanlışta teselli eden; 52 px, dekoratif). Yanlış
/// şerit tuğla kırmızısı yerine sakin şarap tonu
/// ([SahneVayColors.feedbackWrongFill]); büyük kırmızı panel ekranı
/// ağırlaştırıyordu (Astra). Büyük yazıda maskot düşer (yer metnindir).
class QuizFeedbackStrip extends StatelessWidget {
  const QuizFeedbackStrip({
    super.key,
    required this.correct,
    required this.action,
    this.detail,
    this.animate = true,
    this.inlineAction = true,
    this.compactRow = false,
    this.timedOut = false,
    this.ratingPrompt,
    this.semanticDetail,
  });

  /// Şerit her cevapta aynı boyda kalsın diye açıklama satırı yazılmaz
  /// (bkz. `_feedbackDetail`).
  static const bool fixedHeight = true;

  /// `false`: giriş animasyonu yok (alt perdenin boyunu ölçen görünmez ikiz).
  final bool animate;

  /// `true`: eylem düğmesi başlığın YANINDA (tek satır, ≈76 pt); `false`
  /// (üç düğmeli zorluk puanı): düğmeler başlığın altında tam genişlikte.
  final bool inlineAction;

  /// `true`: maskot ve başlık yazısı düşer, yalnız ✓/✗ + tam genişlikte eylem
  /// (çok oyunculuda "Rakip bekleniyor…" etiketi dar yuvada iki satıra sarıp
  /// alt perdeyi uzatıyordu).
  final bool compactRow;

  /// Süre dolduysa başlık "Yanlış" değil "Süre doldu" der.
  final bool timedOut;

  /// Zorluk puanı soruluyorsa başlığa eklenen soru ("Bu soru nasıldı?").
  final String? ratingPrompt;

  /// Yalnız ekran okuyucuya giden ek cümle (görünür satır eklemez).
  final String? semanticDetail;

  final bool correct;

  /// En çok tek satır (taşarsa üç nokta); tam metin ekran okuyucuda bütündür.
  final String? detail;

  /// Şeritteki eylem (genelde "Sonraki" düğmesi).
  final Widget action;

  /// Mini maskotun genişliği.
  static const double mascotSize = 52;

  /// Şeridin dolgusu: doğru Rast, yanlış sakin şarap.
  static Color feedbackFill(SahneTokens t, {required bool correct}) =>
      correct ? t.okFill : SahneVayColors.feedbackWrongFill;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fill = feedbackFill(t, correct: correct);
    final verdict = context.t(
      correct ? K.correct : (timedOut ? K.sureDoldu : K.wrong),
    );
    // Tur 1 (I10, 2026-10-29): alıştırmada doğrudan sonra "Zor / Orta /
    // Kolay" açıklamasızdı; başlık soruyu da sorar. Tek satır, sığmazsa
    // küçülür (şeridin boyu değişmez).
    final title = ratingPrompt == null ? verdict : '$verdict · $ratingPrompt';
    final reduce = sahneMotionReduced(context);
    // Büyük yazıda (≥ %130) açıklama satırı düşer: şerit tek başına ekranın
    // üçte biriydi ve sorunun açıklama kartını kaydırma alanından itiyordu
    // (`quiz_stage_scroll_test`). Söz ekran okuyucuda bütündür.
    final largeText =
        compactRow || MediaQuery.textScalerOf(context).scale(14) > 17.0;
    final strip = Semantics(
      container: true,
      liveRegion: true,
      label: semanticDetail ?? (detail == null ? title : '$title. $detail'),
      child: Container(
        key: animate
            ? ValueKey(
                correct ? 'quiz-feedback-correct' : 'quiz-feedback-wrong',
              )
            : null,
        padding: const EdgeInsets.all(SahneSpace.x3),
        decoration: ShapeDecoration(color: fill, shape: SahneShape.l),
        child: largeText
            ? Row(
                // Büyük yazıda başlık satırı düşer: ✓/✗ + renk + eylem tek
                // satırda (söz ekran okuyucuda bütün).
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      correct ? AppIcons.check : AppIcons.xmark,
                      size: 24,
                      color: t.tx,
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(child: action),
                ],
              )
            : inlineAction
            ? Row(
                // Tek satır (2026-10-29, soru sığma): maskot + başlık solda,
                // eylem sağda. Eskiden başlık ve düğme üst üste iki satırdı
                // (≈110 pt); alt perde kısaldıkça soru ve şıklar ekranda
                // daha çok yer bulur.
                children: [
                  ExcludeSemantics(
                    child: ZanMascot(
                      key: animate
                          ? const ValueKey('quiz-feedback-mascot')
                          : null,
                      pose: correct ? ZanPose.correct : ZanPose.wrong,
                      size: 44,
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Flexible(
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            correct ? AppIcons.check : AppIcons.xmark,
                            size: 22,
                            color: t.tx,
                          ),
                          const SizedBox(width: SahneSpace.x1),
                          Flexible(
                            // Tek satır, sığmazsa küçülür: iki satıra
                            // sarsa şerit uzar, alt perde oynar.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                title,
                                key: animate
                                    ? const ValueKey('quiz-feedback-title')
                                    : null,
                                maxLines: 1,
                                style: SahneType.bodyStrong.copyWith(
                                  color: t.tx,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(flex: 2, child: action),
                ],
              )
            : Row(
                // Maskot şeridin solunda, başlık + eylem sütununun yanında
                // (Duolingo: karakter düğmenin yanında).
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ZanMascot(
                        key: animate
                            ? const ValueKey('quiz-feedback-mascot')
                            : null,
                        pose: correct ? ZanPose.correct : ZanPose.wrong,
                        size: mascotSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              Icon(
                                correct ? AppIcons.check : AppIcons.xmark,
                                size: 22,
                                color: t.tx,
                              ),
                              const SizedBox(width: SahneSpace.x2),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    title,
                                    key: animate
                                        ? const ValueKey('quiz-feedback-title')
                                        : null,
                                    maxLines: 1,
                                    style: SahneType.bodyStrong.copyWith(
                                      color: t.tx,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (detail != null && detail!.trim().isNotEmpty) ...[
                          const SizedBox(height: SahneSpace.x1),
                          ExcludeSemantics(
                            child: Text(
                              detail!.trim(),
                              key: const ValueKey('quiz-feedback-detail'),
                              maxLines: 3,
                              style: SahneType.caption.copyWith(color: t.tx),
                            ),
                          ),
                        ],
                        const SizedBox(height: SahneSpace.x3),
                        action,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    if (reduce || !animate) return strip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      // Yalnız solma: eskiden 24 pt aşağıdan kayarak geliyordu; "cevaptan
      // sonra hiçbir öğe yer değiştirmesin" (2026-10-29).
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: strip,
    );
  }
}

/// Pasif "Sonraki": düz soluk dolguya ek olarak görünür çerçeve; "bir düğme
/// ama henüz değil" okunur (eskiden kenarsız koyu blok, etiketsiz bir şerit
/// gibiydi).
class QuizInactiveButtonFrame extends StatelessWidget {
  const QuizInactiveButtonFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Container(
      foregroundDecoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          side: BorderSide(color: t.tx3, width: 1.5),
        ),
      ),
      child: child,
    );
  }
}

/// Alt perdenin boyunu SABİT tutar: joker dizisi, pasif "Sonraki", geri
/// bildirim şeridi, "Çift cevap" ipucu satırı ve joker bakiyesi (dört çip /
/// tek sönük satır) aynı [height] içinde durur. Yükseklik DURUM değil
/// YAPILANDIRMADAN (yazı ölçeği, mod) hesaplanır ([quizDockHeight]); bir durum
/// ayrılan yüksekliği aşarsa taşma hatası verir ve bekçi
/// (`soru_sigma_test`, "alt perde") yakalar. Eskiden en uzun durumun boyu
/// "görünmez ikizle" ölçülüyordu; gerçek çocuk ikizden büyük olunca perde
/// uzuyor, gövde daralıyor, soru yerinden oynuyordu (2026-10-29).
class QuizStableDockHeight extends StatelessWidget {
  const QuizStableDockHeight({
    super.key,
    required this.child,
    required this.height,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Sabit kutu; OverflowBox YOK (aşan kısım dokunma almazdı). Hesap
    // doğruysa içerik zaten sığar (ölçek 1). Yazı tipi metriği hesaptan
    // sapar da içerik kutuyu aşarsa FittedBox onu kutunun İÇİNE küçültür:
    // dokunma hedefi ve görünüm kutuda kalır, alt perde uzamaz. Sapma
    // bekçide ölçülür (`soru_sigma_ek_test`: içerik ≤ ayrılan yükseklik).
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: c.maxWidth, child: child),
        ),
      ),
    );
  }
}

/// Alt perdenin ayrılan yüksekliği: GERÇEK genişlik, yazı ölçeği ve etiket
/// metinleriyle HESAPLANIR (durum ölçülmez).
///
/// * şerit: 12 + 12 iç boşluk + düğme; düğme = en az 52, etiket kaç satıra
///   sarıyorsa o kadar (satır · 24 · ölçek + 24). Etiketler en geniş eylem
///   yuvasında ölçülür; alıştırmada başlık + üç zorluk düğmesi;
/// * joker bloğu: bakiye satırı + 8 + çip; çip = 66 (+ büyük yazıda) ve
///   etiket görünürse etiketin satırları (≤ 2).
double quizDockHeight(
  TextScaler base, {
  required bool practice,
  required bool jokerCapable,
  required double screenWidth,
  required bool shortScreen,
  required bool compactRow,
  required List<String> actionLabels,
  required List<String> ratingLabels,
  required List<String> jokerLabels,
}) {
  final s = base.scale(16) / 16;
  final dockWidth = (screenWidth - 2 * SahneSpace.page).clamp(0.0, 800.0);
  final inner = dockWidth - 24;

  int lines(String text, TextStyle style, double width) {
    if (width <= 4) return 1;
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontFamily: style.fontFamily),
      ),
      textDirection: TextDirection.ltr,
      textScaler: base,
    )..layout(maxWidth: width);
    final n = p.computeLineMetrics().length;
    p.dispose();
    return n < 1 ? 1 : n;
  }

  double buttonHeight(List<String> texts, double actionWidth) {
    // Düğme iç genişliği: 12'şer yan boşluk + ok/ikon yuvası (≈ 28).
    final textWidth = actionWidth - 24 - 28;
    var maxLines = 1;
    for (final t in texts) {
      final n = lines(t, SahneType.button, textWidth);
      if (n > maxLines) maxLines = n;
    }
    final h = maxLines * base.scale(24) + 24;
    return h > 52 ? h : 52;
  }

  final largeText = base.scale(14) > 17.0;
  final double strip;
  if (practice) {
    // Başlık satırı + 12 + üç eşit düğme (8'er aralık).
    final rating = buttonHeight(ratingLabels, (inner - 16) / 3);
    strip = 24 + base.scale(26) + 12 + rating;
  } else if (compactRow || largeText) {
    // [✓/✗ ikonu 24 + 8] + tam genişlik eylem.
    strip = 24 + buttonHeight(actionLabels, inner - 32);
  } else {
    // Maskot 44 + 8 + başlık (≤ 1/3) + 12; eylem kalanın 2/3'ü.
    strip = 24 + buttonHeight(actionLabels, (inner - 64) * 2 / 3);
  }

  var jokers = 0.0;
  if (jokerCapable) {
    final showLabel = !shortScreen && base.scale(14) < 18.2;
    final chipWidth = (dockWidth - 3 * 8) / 4;
    var labelLines = 1;
    if (showLabel) {
      for (final l in jokerLabels) {
        final n = lines(
          l,
          SahneType.caption.copyWith(height: 1.15),
          chipWidth - 8,
        );
        if (n > labelLines) labelLines = n;
      }
      if (labelLines > 2) labelLines = 2;
    }
    final chip =
        66 +
        60 * (s - 1).clamp(0.0, 0.35) +
        (showLabel ? 2 + labelLines * base.scale(13.8) : 0);
    jokers = base.scale(20) + 8 + chip + 2;
  }
  return strip > jokers ? strip : jokers;
}

/// Sahnenin ÜSTÜNDE, yerleşimi itmeden beliren kısa bildirim (kurul C31).
///
/// 2026-10-29 kurul (Astra/Terra/Sol 3/3): yarım kalan soruya dönüşte
/// "süre işlemeye devam ediyor" bilgisi ekranın en altında küçük bir
/// SnackBar'daydı; oyuncu soruya bakarken görmüyor, dönüşte 4 sn kaldığını
/// sayaçtan ancak fark ediyordu. Bildirim artık soru alanının üstünde, sayaç
/// ikonuyla ve kehribar tonla belirir; kaplama katmanında çizildiği için
/// soru ve şıklar yerinden oynamaz (kayma kuralı). [duration] sonunda ya da
/// [QuizStageNotice.dismiss] ile kalkar.
class QuizStageNotice {
  QuizStageNotice._(this._entry);

  final OverlayEntry _entry;
  Timer? _timer;
  bool _removed = false;

  static const key = ValueKey('quiz-stage-top-notice');

  static QuizStageNotice? show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return null;
    final top = MediaQuery.paddingOf(context).top + 72;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: top,
        left: SahneSpace.page,
        right: SahneSpace.page,
        child: IgnorePointer(
          child: Semantics(
            liveRegion: true,
            child: Material(
              type: MaterialType.transparency,
              child: Builder(
                builder: (context) {
                  final t = SahneTokens.of(context);
                  return DecoratedBox(
                    key: key,
                    decoration: ShapeDecoration(
                      color: t.goldTint,
                      shape: SahneShape.withSide(
                        SahneShape.m,
                        t.goldTx,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SahneSpace.x4,
                        vertical: SahneSpace.x3,
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.clock, size: 22, color: t.goldTx),
                          const SizedBox(width: SahneSpace.x3),
                          Expanded(
                            child: Text(
                              message,
                              style: SahneType.bodyStrong.copyWith(
                                color: t.goldTx,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final notice = QuizStageNotice._(entry);
    overlay.insert(entry);
    notice._timer = Timer(duration, notice.dismiss);
    return notice;
  }

  void dismiss() {
    _timer?.cancel();
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}
