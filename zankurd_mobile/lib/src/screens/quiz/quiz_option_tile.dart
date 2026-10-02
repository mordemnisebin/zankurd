import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';
import '../../theme/app_icons.dart';
import '../../utils/percent_format.dart';
import '../../utils/player_identity.dart';
import '../../widgets/sahne/sahne.dart';

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
/// * Yanlış seçim: Şaş dolgusu + 135° çapraz tarama, Halka 2 Şaş metni,
///   harf karosu Şaş, sağda ✗.
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
      _OptionState.wrong => t.errFill,
      _ => null,
    };
    final Color base = state == _OptionState.dimmed ? t.s1 : t.s2;
    final Color ring = switch (state) {
      _OptionState.correct => t.okTx,
      _OptionState.wrong => t.errTx,
      _OptionState.checking => t.tx,
      _ => Colors.transparent,
    };
    final Color textColor = state == _OptionState.dimmed ? t.tx3 : t.tx;
    final Color letterBg = switch (state) {
      _OptionState.correct => t.okTx,
      _OptionState.wrong => t.errTx,
      _OptionState.dimmed => t.s2,
      _ => t.s3,
    };
    final Color letterFg = switch (state) {
      _OptionState.correct => t.onOk,
      _OptionState.wrong => t.errTint,
      _OptionState.dimmed => t.tx3,
      _ => t.tx,
    };

    final vPad = isCompact ? SahneSpace.x1 : SahneSpace.x2;
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
                      style: SahneType.bodyStrong.copyWith(color: textColor),
                    ),
                  ),
                ),
              ),
              _StatusMark(
                state: state,
                reducedMotion: reducedMotion,
                tokens: t,
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
          if (opponentNamesWhoSelected != null &&
              opponentNamesWhoSelected!.isNotEmpty) ...[
            const SizedBox(height: SahneSpace.x2),
            // Rakip rozetleri `Wrap`: 2-3 uzun isim ya da %200 yazıda alt
            // satıra iner, yatay taşmaz (bkz. large_text_overflow_test).
            Wrap(
              alignment: WrapAlignment.end,
              spacing: SahneSpace.x1,
              runSpacing: SahneSpace.x1,
              children: [
                for (final name in opponentNamesWhoSelected!)
                  _OpponentMark(name: name, tokens: t),
              ],
            ),
          ],
        ],
      ),
    );

    return Semantics(
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
            return DecoratedBox(
              // Halka, dolgunun ÜSTÜNDE: içe çizilir, tarama altından geçer.
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: SahneShape.withSide(
                  SahneShape.m,
                  ring,
                  width: SahneRing.r2,
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
                        ? 52
                        : (fixedHeight! < 52 ? 52 : fixedHeight!),
                  ),
                  decoration: BoxDecoration(
                    color: base,
                    gradient: fill == null
                        ? null
                        : _sweepGradient(fill, base, sweep),
                  ),
                  child: CustomPaint(
                    painter: state == _OptionState.wrong
                        ? _HatchPainter(t.errTx.withValues(alpha: 0.18))
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
            );
          },
          child: content,
        ),
      ),
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
  });

  final String letter;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: SahneMotion.fade,
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: background, shape: SahneShape.m),
      child: MediaQuery.withNoTextScaling(
        // Harf karonun içine sığmalı: %200 yazıda 36'lık karodan taşardı.
        // Harf tek başına anlam taşımaz; ekran okuyucu "A: …" der.
        child: Text(letter, style: SahneType.button.copyWith(color: color)),
      ),
    );
  }
}

/// Sağdaki durum işareti: doğruda ✓, yanlışta ✗; yoksa yer tutmaz.
class _StatusMark extends StatelessWidget {
  const _StatusMark({
    required this.state,
    required this.reducedMotion,
    required this.tokens,
  });

  final _OptionState state;
  final bool reducedMotion;
  final SahneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (state) {
      _OptionState.correct => Padding(
        key: const ValueKey('correct_icon'),
        padding: const EdgeInsetsDirectional.only(start: SahneSpace.x2),
        child: SizedBox.square(
          dimension: 36,
          child: Icon(AppIcons.check, size: 24, color: tokens.tx),
        ),
      ),
      _OptionState.wrong => Padding(
        key: const ValueKey('wrong_icon'),
        padding: const EdgeInsetsDirectional.only(start: SahneSpace.x2),
        child: SizedBox.square(
          dimension: 36,
          child: Icon(AppIcons.xmark, size: 24, color: tokens.errTx),
        ),
      ),
      _ => const SizedBox.shrink(key: ValueKey('empty_icon')),
    };
    return AnimatedSwitcher(
      duration: reducedMotion ? Duration.zero : SahneMotion.answerReveal,
      child: mark,
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

/// Yanlış seçimin çapraz taraması: 135°, 4 px şerit, 12 px adım
/// (maketteki `repeating-linear-gradient(135deg, …)`). Tek dolu yol;
/// bulanıklık ya da katman yok.
class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 12.0;
    const band = 4.0;
    final path = Path();
    // 135°: şeritler sol üstten sağ alta iner; kaydırma yatayda yapılır.
    for (var x = -size.height; x < size.width + step; x += step) {
      path
        ..moveTo(x, 0)
        ..lineTo(x + band, 0)
        ..lineTo(x + band + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

/// Soru metni — Şahnê'de soru sahnenin kendisinde durur (maketteki
/// `.sh-q`): Başlık 28/32, birincil metin.
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
  });

  final String text;

  /// Telefon-yatay gibi dar dikey alanda hep Manşet 22.
  final bool forceHeadline;

  /// Başlık 28/32'de en çok bu kadar satır.
  static const int maxTitleLines = 4;

  /// Bu soruda Başlık 28/32'ye izin verilen en çok satır.
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
  }) {
    final t = SahneTokens.of(context);
    final headline = SahneType.headline.copyWith(color: t.tx);
    if (forceHeadline || !maxWidth.isFinite || maxWidth <= 0) return headline;
    final title = SahneType.title.copyWith(color: t.tx, letterSpacing: -0.28);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: title.copyWith(fontFamily: SahneType.display),
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
      builder: (context, constraints) => Text(
        text,
        style: styleFor(
          context,
          text,
          constraints.maxWidth,
          forceHeadline: forceHeadline,
          titleLineBudget: titleLineBudget,
        ),
      ),
    );
  }
}
