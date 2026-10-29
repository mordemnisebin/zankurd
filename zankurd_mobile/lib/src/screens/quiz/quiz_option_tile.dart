import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';
import '../../theme/app_icons.dart';
import '../../utils/percent_format.dart';
import '../../utils/player_identity.dart';
import '../../widgets/lexicon_lookup.dart';
import '../../widgets/sahne/sahne.dart';
import 'quiz_fit.dart';

/// Şık çubuğunun en az yüksekliği (tur 8: 52 → 56; 2026-10-28 tur 2 R3:
/// 60 — baş parmak hedefi ve dengeli soru sahnesi).
const double quizOptionMinHeight = 60;

/// Şık çubuğu — Şahnê'nin "8 · Şık çubuğu" bileşeni (maketteki `.sh-ans`).
///
/// ## Görünüm
///
/// * Varsayılan: Kulis (`s2`) zemin, M pah; solda 36'lık RENKSİZ harf karosu
///   (Ray, `s3`), metin Gövde 16/700. En az 52 boy, içerikle büyür; metin
///   kırpılmaz.
/// * Kontrol ediliyor (gerilim tutuşu): zemin aynı, Halka 2 birincil metin
///   renginde. Sonuç açıklanmadan RENK YOK — renk cevabı ele verirdi.
/// * Doğru: Rast dolgusu soldan sağa tarar (240 ms), Halka 2 Rast metni,
///   harf karosu Rast, sağda ✓.
/// * Yanlış seçim: sakin şarap dolgusu ([SahneVayColors.optionWrongFill]),
///   Halka 2 Şaş metni, harf karosu Şaş, sağda ✗. Vay 2A (2026-10-29):
///   135° kırmızı çapraz TARAMA KALKTI — Astra "açıkça kötü görünen" dedi;
///   ekranı ağırlaştırıyor, uyarı levhası gibi okunuyordu. Durum ✗ + söz +
///   halka ile zaten üç kanaldan verilir.
/// * Boşta ve kontrol hâlinde şık KABARTMALIDIR (vay 2A, Quiz Planet/Kahoot
///   derinliği): üstte ince ışık, altta 2 px koyu taban ([SahneEmbossPainter]).
/// * Sönük (açıklanınca ötekiler, ya da 50/50 ile elenen): Perde (`s1`) +
///   üçüncül metin, 160 ms'de söner. Opaklık değil ton.
///
/// Durum hiçbir zaman yalnız renkle verilmez: ✓/✗ ikonu ve ekran okuyucu
/// sözü ("A: yaşam, Doğru") her zaman birliktedir.
///
/// ## Niçin harf karosu renksiz
///
/// Eskiden her harfin kendi rengi vardı (A mavi, B yeşil…). Yeşil harfli
/// şık "doğru" gibi okunuyordu: renk, cevaptan önce bir ipucu taşıyordu
/// (bkz. `answer_option_color_semantics_test`). Şahnê'de cevaptan önce
/// hiçbir şıkta renk yoktur.
///
/// ## Hareket
///
/// Tarama ve sönme "hareketi azalt" açıkken anında olur (yalnız renk ve
/// şekil değişir). Basınca 2 px çöker (`SahnePressSink`).
class QuizOptionTile extends StatelessWidget {
  const QuizOptionTile({
    required this.index,
    required this.answer,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
    this.firstAttemptWrong = false,
    this.suspense = false,
    this.audiencePercent,
    this.opponentNamesWhoSelected,
    this.isCompact = false,
    this.fixedHeight,
    this.optionCount = 4,
    this.dimmed = false,
    this.tone,
    super.key,
  });

  /// Görünüm sırası — A/B/C/D harfi.
  final int index;
  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback? onTap;
  final bool firstAttemptWrong;

  /// Gerilim tutuşu: sonuç henüz açıklanmadı. Seçilen şık "kontrol
  /// ediliyor" hâlinde bekler, yanlış hâli uygulanmaz.
  final bool suspense;
  final double? audiencePercent;
  final List<String>? opponentNamesWhoSelected;

  /// Dar düzen: dikey iç boşluk bir basamak daralır (yazı küçülmez).
  final bool isCompact;

  /// Şıkka ayrılan en az yükseklik. Verilirse çubuk en az bu boyu alır;
  /// içerik uzunsa yine büyür (taşma olmaz).
  final double? fixedHeight;

  /// Sorudaki toplam şık sayısı (eski API; görünümü etkilemez).
  final int optionCount;

  /// Açıklanmada seçilmeyen ve doğru olmayan şıklar ya da elenen şık:
  /// sönük (Perde + üçüncül metin).
  final bool dimmed;

  /// Soru sahnesinin konu tonu: boştaki şıkta dolgu ve kenar ona doğru ölçülü
  /// kayar. Doğru/yanlış/kontrol/sönük durumları değişmez; harf renksizdir.
  final SahneCategoryTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final wrong =
        (!suspense && selected && !correct && disabled) || firstAttemptWrong;
    final isChecking = selected && (suspense || !disabled);
    final reducedMotion =
        ReducedMotionProvider.isReducedIn(context) ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    final _OptionState state = correct
        ? _OptionState.correct
        : wrong
        ? _OptionState.wrong
        : isChecking
        ? _OptionState.checking
        : dimmed
        ? _OptionState.dimmed
        : _OptionState.idle;

    final letter = String.fromCharCode(65 + (index % 26));
    final stateHint = correct
        ? ', ${context.t(K.correct)}'
        : wrong
        ? ', ${context.t(K.wrong)}'
        : '';

    // Taranan dolgu: Rast ya da Şaş. Tarama yalnız durum değişince oynar
    // (anahtar duruma bağlı); hareketi azaltta hemen tamdır.
    final Color? fill = switch (state) {
      _OptionState.correct => t.okFill,
      _OptionState.wrong => SahneVayColors.optionWrongFill,
      _ => null,
    };
    final tn = tone;
    final Color base = state == _OptionState.dimmed
        ? t.optionDimFill
        : (tn != null && state == _OptionState.idle
              ? t.optionFillFor(tn)
              : t.optionFill);
    final Color ring = switch (state) {
      _OptionState.correct => t.okTx,
      _OptionState.wrong => t.errTx,
      _OptionState.checking => t.tx,
      _OptionState.idle => tn == null ? t.optionEdge : t.optionEdgeFor(tn),
      _ => Colors.transparent,
    };
    final double ringWidth = state == _OptionState.idle ? 1 : SahneRing.r2;
    // 2026-10-29 son kurul tur 2 (C, Terra + Sol): cevaptan sonra seçilmeyen
    // şıkların yazısı koyu sahnede sönük okunuyordu (üçüncül gri). Sönüklüğü
    // YÜZEY taşır ([SahneTokens.optionDimFill], kenar yok, taban gölgesi
    // yok); yazı ikincil mürekkebe çıkar: iki temada da ≥ 4,5:1 ve hâlâ
    // boştaki şıkkın tam beyazından ayrı (bekçi: `son_kurul_test` tur 2).
    final Color textColor = state == _OptionState.dimmed ? t.tx2 : t.tx;
    final Color letterBg = switch (state) {
      _OptionState.correct => t.okTx,
      _OptionState.wrong => t.errTx,
      _OptionState.dimmed => t.optionLetterFill,
      _ => t.optionLetterFill,
    };
    final Color letterFg = switch (state) {
      _OptionState.correct => t.onOk,
      _OptionState.wrong => t.errTint,
      // Tur 2 (C): harf de ikincil mürekkep; gündüz Ray üstünde üçüncül
      // 4,2:1 kalıyordu.
      _OptionState.dimmed => t.tx2,
      _ => t.tx,
    };

    final fit = QuizFitScope.of(context);
    final vPad = fit.isNominal
        ? (isCompact ? QuizFit.shortOptionVPad : fit.optionVPad)
        : fit.optionVPad;
    final minHeight = fit.isNominal ? quizOptionMinHeight : fit.optionMinHeight;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(SahneSpace.x2, vPad, SahneSpace.x3, vPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LetterTile(
                letter: letter,
                background: letterBg,
                color: letterFg,
                // Doğru/yanlış işareti harf karosunun YERİNE geçer (eskiden
                // sağda 44 pt'lik ayrı bir yuvaydı): şık metni cevaptan sonra
                // daralıp ek satıra kırılmaz, çubuklar yerinden oynamaz.
                reducedMotion: reducedMotion,
                markIcon: switch (state) {
                  _OptionState.correct => AppIcons.check,
                  _OptionState.wrong => AppIcons.xmark,
                  _ => null,
                },
                markKey: switch (state) {
                  _OptionState.correct => const ValueKey('correct_icon'),
                  _OptionState.wrong => const ValueKey('wrong_icon'),
                  _ => null,
                },
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: ConstrainedBox(
                  // a11y-tap-target: noninteractive — şık metninin hizalama
                  // tabanı; dokunma hedefi tüm şık kutusudur (en az 52).
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      answer,
                      style: SahneType.bodyStrong.copyWith(
                        color: textColor,
                        height: fit.optionLineHeight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (audiencePercent != null) ...[
            const SizedBox(height: SahneSpace.x2),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 48),
              child: SahneProgressBar(
                value: audiencePercent!.clamp(0.0, 1.0),
                tone: SahneProgressTone.gold,
                trailing: context.percentRatio(audiencePercent!),
              ),
            ),
          ],
        ],
      ),
    );

    final tile0 = Semantics(
      button: true,
      enabled: !disabled,
      selected: selected,
      label: '$letter: $answer$stateHint',
      onTap: disabled ? null : onTap,
      excludeSemantics: true,
      child: SahnePressSink(
        enabled: !disabled,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('option-sweep-${state.name}'),
          tween: Tween(begin: fill == null || reducedMotion ? 1 : 0, end: 1),
          duration: reducedMotion ? Duration.zero : SahneMotion.answerReveal,
          curve: Curves.easeOutCubic,
          builder: (context, sweep, child) {
            final raised =
                state == _OptionState.idle || state == _OptionState.checking;
            // Vay 2A: boştaki şığın altında 3 px keskin koyu taban (oyun
            // tuşu derinliği); açıklanınca taban kalkar, şık "basılmış" olur.
            return DecoratedBox(
              key: const ValueKey('quiz-option-base'),
              decoration: ShapeDecoration(
                shape: SahneShape.m,
                shadows: raised
                    ? [
                        BoxShadow(
                          color: SahneVayColors.black.withValues(alpha: 0.34),
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : const [],
              ),
              child: DecoratedBox(
                // Halka, dolgunun ÜSTÜNDE: içe çizilir, tarama altından geçer.
                position: DecorationPosition.foreground,
                decoration: ShapeDecoration(
                  shape: SahneShape.withSide(
                    SahneShape.m,
                    ring,
                    width: ringWidth,
                  ),
                ),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: SahneShape.m),
                  child: AnimatedContainer(
                    duration: reducedMotion || fill != null
                        ? Duration.zero
                        : SahneMotion.fade,
                    curve: Curves.easeOut,
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: fixedHeight == null
                          ? minHeight
                          : (fixedHeight! < minHeight
                                ? minHeight
                                : fixedHeight!),
                    ),
                    decoration: BoxDecoration(
                      color: base,
                      gradient: fill == null
                          ? null
                          : _sweepGradient(fill, base, sweep),
                    ),
                    child: CustomPaint(
                      key: const ValueKey('quiz-option-face'),
                      painter:
                          state == _OptionState.idle ||
                              state == _OptionState.checking
                          ? const SahneEmbossPainter(
                              shape: SahneShape.m,
                              style: SahneEmbossStyle(night: true),
                            )
                          : null,
                      // Saydam Material dolgunun ÜSTÜNDE: dokunma dalgası
                      // zeminin altında kalıp görünmez olmasın.
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: disabled ? null : onTap,
                          customBorder: SahneShape.m,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: content,
        ),
      ),
    );
    // Rakibin seçtiği şıkkın adı çubuğun ÜST kenarına asılı rozettir: eskiden
    // çubuğun içine ek satır açıyor, cevaptan sonra altındaki bütün şıklar
    // aşağı kayıyordu (yer baştan ayrılmaz).
    final names = opponentNamesWhoSelected;
    final tile = names == null || names.isEmpty
        ? tile0
        : Stack(
            clipBehavior: Clip.none,
            children: [
              tile0,
              PositionedDirectional(
                top: -10,
                end: SahneSpace.x3,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: SahneSpace.x1,
                  children: [
                    for (final name in names)
                      _OpponentMark(name: name, tokens: t),
                  ],
                ),
              ),
            ],
          );
    // Doğru cevapta kısa ödül sekmesi (tasarım oylaması 2026-10-22, 19/19
    // EVET): YALNIZ oyuncunun seçtiği şık doğruysa bir kez %4 büyüyüp
    // döner; hareketi azaltta yok. Anahtar duruma bağlı: aynı soruda
    // yeniden çizim tekrar oynatmaz.
    if (!(selected && state == _OptionState.correct) || reducedMotion) {
      return tile;
    }
    return TweenAnimationBuilder<double>(
      key: const ValueKey('quiz-option-correct-bounce'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      builder: (context, v, child) => Transform.scale(
        // 0 → 1 → 0 yarım sinüs: 1.00 → 1.04 → 1.00.
        scale: 1 + 0.04 * math.sin(v * math.pi),
        child: child,
      ),
      child: tile,
    );
  }

  /// Soldan sağa tarama: [p] kadarı dolgu, kalanı zemin. Keskin durak —
  /// yumuşak geçişli bir degrade değil, bir silme çizgisi.
  static LinearGradient _sweepGradient(Color fill, Color base, double p) {
    final edge = p.clamp(0.0, 1.0);
    return LinearGradient(
      colors: [fill, fill, base, base],
      stops: [0, edge, edge, 1],
    );
  }
}

enum _OptionState { idle, checking, correct, wrong, dimmed }

/// 36'lık harf karosu (M pah). Cevaptan önce renksiz.
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.background,
    required this.color,
    this.markIcon,
    this.markKey,
    this.reducedMotion = false,
  });

  final String letter;
  final Color background;
  final Color color;
  final IconData? markIcon;
  final Key? markKey;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: SahneMotion.fade,
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: background, shape: SahneShape.m),
      // İşaret belirirken yumuşak geçer; hareketi azalt açıkken anında.
      child: AnimatedSwitcher(
        duration: reducedMotion ? Duration.zero : SahneMotion.answerReveal,
        child: markIcon != null
            ? Icon(markIcon, key: markKey, size: 22, color: color)
            : MediaQuery.withNoTextScaling(
                key: const ValueKey('letter'),
                // Harf karonun içine sığmalı: %200 yazıda 36'lık karodan
                // taşardı. Harf tek başına anlam taşımaz; ekran okuyucu
                // "A: …" der.
                child: Text(
                  letter,
                  style: SahneType.button.copyWith(color: color),
                ),
              ),
      ),
    );
  }
}

/// Rakibin seçtiği şıkta adı: Perde üstünde küçük S pahlı etiket + göz.
class _OpponentMark extends StatelessWidget {
  const _OpponentMark({required this.name, required this.tokens});

  final String name;
  final SahneTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: tokens.s1, shape: SahneShape.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x2,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Uzun isim %200'de rozet genişliğini aşmasın.
            Flexible(
              child: Text(
                context.playerDisplayName(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SahneType.captionStrong.copyWith(color: tokens.tx),
              ),
            ),
            const SizedBox(width: SahneSpace.x1),
            Icon(AppIcons.eye, size: 12, color: tokens.tx2),
          ],
        ),
      ),
    );
  }
}

/// Soru metni — Şahnê'de soru sahnenin kendisinde durur (maketteki
/// `.sh-q`): Soru 24/30 (2026-10-19; eskiden Başlık 28/32), birincil metin.
///
/// ## Boy kuralı
///
/// Metin dört satırı aşarsa Manşet 22/28'e iner. Karar KARAKTER SAYISIYLA
/// değil, metnin gerçek genişlikte ÖLÇÜLMESİYLE verilir (`TextPainter`,
/// kullanıcının yazı ölçeğiyle): aynı uzunlukta bir soru dar telefonda beş,
/// tablette iki satır tutar. Eski karakter eşikleri (60/110/160) bunu
/// ayıramıyordu. Quiz ve seviye belirleme aynı kuralı kullanır.
///
/// Aile ölçümde AÇIKÇA yazılır: `TextPainter` temayı görmez; ailesiz bir
/// biçim sistem yazı tipine düşer ve ekranda Bricolage çizilirken ölçüm
/// başka bir tiple yapılırdı (`painter_font_test` bu kuralın bekçisidir).
class QuizQuestionPrompt extends StatelessWidget {
  const QuizQuestionPrompt(
    this.text, {
    super.key,
    this.forceHeadline = false,
    this.titleLineBudget = maxTitleLines,
    this.lexicon = LexiconTapPolicy.off,
  });

  final String text;

  /// Sözlük için dokunulabilir sözcükler (yalnız öğrenme modunda açık).
  final LexiconTapPolicy lexicon;

  /// Telefon-yatay gibi dar dikey alanda hep Manşet 22.
  final bool forceHeadline;

  /// Soru 24/30'da en çok bu kadar satır.
  static const int maxTitleLines = 3;

  /// Bu soruda Soru 24/30'a izin verilen en çok satır.
  ///
  /// Düelloda üstteki puan kartı (~120 pt) şıkların bütçesinden yer yer.
  /// 2026-09-30 canlı: dört satırlık soru + dört şıkta D şıkkı alt perdenin
  /// arkasına düşüyordu; düelloda sınır 3 satıra iner, uzun soru Manşet
  /// 22/28'e geçer (yaklaşık 40 pt kazanç). Varsayılan [maxTitleLines].
  final int titleLineBudget;

  /// [text]'in [maxWidth] genişlikte alacağı biçem.
  static TextStyle styleFor(
    BuildContext context,
    String text,
    double maxWidth, {
    bool forceHeadline = false,
    int titleLineBudget = maxTitleLines,
    double? lineHeight,
  }) {
    final t = SahneTokens.of(context);
    final headline = SahneType.headline.copyWith(color: t.tx);
    if (forceHeadline || !maxWidth.isFinite || maxWidth <= 0) return headline;
    final title = SahneType.question.copyWith(
      color: t.tx,
      letterSpacing: -0.24,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: title.copyWith(
          fontFamily: SahneType.display,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines > titleLineBudget ? headline : title;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = QuizFitScope.of(context);
        final style = styleFor(
          context,
          text,
          constraints.maxWidth,
          forceHeadline: forceHeadline,
          titleLineBudget: titleLineBudget,
          lineHeight: fit.promptLineHeight,
        ).copyWith(height: fit.promptLineHeight);
        return lexicon.enabled
            ? LexiconText(text, style: style, policy: lexicon)
            : Text(text, style: style);
      },
    );
  }
}
