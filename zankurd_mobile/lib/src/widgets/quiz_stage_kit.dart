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
    final title = context.t(
      correct ? K.correct : (timedOut ? K.sureDoldu : K.wrong),
    );
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
    // OverflowBox: içerik ayrılan boyu aşarsa (ölçü yazı tipi
    // gerçek metrikleri taşımayan testler) hata fırlatmaz ve alt perde
    // UZAMAZ; aşma bekçide ölçülür (`soru_sigma_ek_test`, "alt perde").
    return SizedBox(
      height: height,
      child: OverflowBox(
        alignment: Alignment.center,
        // a11y-tap-target: noninteractive — yerleşim kutusu, dokunma hedefi
        // değil (içindeki düğmeler kendi 48'lik kutusunu taşır).
        minHeight: 0,
        maxHeight: double.infinity,
        child: child,
      ),
    );
  }
}

/// Alt perdenin ayrılan yüksekliği.
///
/// * şerit: 12 + 12 iç boşluk + 52'lik düğme (alıştırmada başlık + düğme);
/// * joker bloğu: bakiye satırı + 8 + çipler (96, büyük yazıda +50·(ölçek−1));
///
double quizDockHeight(
  TextScaler base, {
  required bool practice,
  required bool jokerCapable,
  required double width,
  required bool shortScreen,
}) {
  final s = base.scale(16) / 16;
  // Düğme: en az 52; tek satır etiket 24·ölçek + 24 dikey boşluk.
  final button = base.scale(24) + 24 > 52 ? base.scale(24) + 24 : 52.0;
  final strip = practice ? 24 + base.scale(26) + 12 + button : 24 + button;
  // Etiketli çipler dar genişlikte iki satıra sarar (≈ 124); etiketsiz
  // (kısa ekran / büyük yazı) çipler ≈ 100.
  final labels = !shortScreen && s < 1.3;
  final jokers = jokerCapable
      ? (labels ? 124 : 100) + 40 * (s - 1).clamp(0.0, 0.3)
      : 0.0;
  return strip > jokers ? strip : jokers;
}
