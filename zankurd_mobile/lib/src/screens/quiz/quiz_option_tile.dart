import 'dart:math';

import 'package:flutter/material.dart';

import '../../providers/reduced_motion_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../utils/percent_format.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';

/// Tek bir cevap şıkkı kartı (A/B/C/D rozeti + cevap metni).
///
/// Gerilim tutuşu (suspense), seyirci yüzdesi ve rakip seçim göstergesi
/// gibi tüm görsel durumları kendi içinde yönetir.
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

  /// Görünüm sırası — A/B/C/D rozeti ve şık rengi için kullanılır.
  final int index;
  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;
  final bool firstAttemptWrong;

  /// Gerilim tutuşu: sonuç henüz açıklanmadı. Seçilen şık "kontrol
  /// ediliyor" (accent) stilinde bekler, yanlış stili uygulanmaz.
  final bool suspense;
  final double? audiencePercent;
  final List<String>? opponentNamesWhoSelected;
  final bool isCompact;

  /// Şıkka AYRILAN yükseklik.
  ///
  /// Verildiğinde kutu tam bu boyu alır ve dikey dolgu hesaplanmaz: yükseklik
  /// artık ekran boyu kademelerinden değil, karta gerçekten kalan alanın
  /// şıklara eşit bölünmesinden gelir. Amaç her sorunun şıklarıyla birlikte
  /// ekrana tam oturması (2026-08-16 kararı).
  final double? fixedHeight;

  /// Sorudaki toplam şık sayısı.
  ///
  /// İki şıklı sorularda (doğru/yanlış) kart ekranın yarısını boş
  /// bırakıyordu: dört şıklı sorular alanı doldururken iki şıklı olanlar
  /// ortada küçük bir kutu gibi kalıyordu (2026-07-27, simülatörde).
  final int optionCount;

  /// Şık düğmesinin dikey dolgusu.
  ///
  /// Kısa ekranda (isCompact) dar kalır — orada sorun yer darlığıdır.
  /// Uzun ekranda kademeli açılır; 850 pt üstü cihazlarda en geniş hâlini
  /// alır.
  ///
  /// İki şıklı soruda bir kademe daha açılır: hem boşluğun bir kısmını
  /// kapatır hem dokunma hedefini büyütür.
  ///
  /// 2026-08-16: burada bir zamanlar "boşluğu tamamen kapatmaz — bunun için
  /// kartın kendisinin uzaması gerekir, o ayrı bir iş" notu vardı. İki şey
  /// birden bulundu: kart gerçekten uzamıyordu (düzeltildi,
  /// `_buildQuestionPanel`in `minHeight`i) VE bu kademelerin hiçbiri
  /// çalışmıyordu, çünkü `isCompact` gövde yüksekliğine yanlış eşikle
  /// bakıp her iPhone'u "dar ekran" ilan ediyordu; akış daima yukarıdaki
  /// `AppSpacing.xs`e düşüyordu.
  ///
  /// Kademeler bilerek BÜYÜTÜLMEDİ. Simülatörde denendi: dolgu bir kademe
  /// açılınca ders modunda cevaptan sonra açılan açıklama paneli ekranın
  /// dışında kalıyor ve oyuncu doğru cevabın niçin doğru olduğunu görmek
  /// için kaydırmak zorunda kalıyordu. Cevap öncesi kalan boşluk kusur
  /// değil, o panelin yeri.
  double _verticalPadding(BuildContext context) {
    // SE (667pt) gibi kısa ekranlarda dört uzun şık + soru kartı sığmıyor,
    // D şıkkı kesik kalıyordu (2026-09-05, canlı gezinti: kesik karta iki
    // dokunuş boşa gitti). Bir kademe daraltma ~32pt kazandırır.
    if (isCompact) return AppSpacing.xxs;
    final height = MediaQuery.sizeOf(context).height;
    final roomy = optionCount <= 2;
    if (height >= 850) return roomy ? AppSpacing.xl + 12 : AppSpacing.lg;
    if (height >= 780) return roomy ? AppSpacing.xl : AppSpacing.md;
    return roomy ? AppSpacing.lg : AppSpacing.sm;
  }

  /// Reveal'de seçilmeyen ve doğru olmayan şıklar: %40 opaklık +
  /// disabled görünüm; renk yalnız doğru/yanlış anlamı taşsın.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final wrong =
        (!suspense && selected && !correct && disabled) || firstAttemptWrong;
    final isChecking = selected && (suspense || !disabled);

    final optionColor = AppTheme.answerOptionColors[index % 4];

    // Idle: açık kart + renkli sol kimlik (TRT/Pirs okunurluğu).
    // Reveal: doğru/yanlış gradyan. Seçim beklerken marka gradyanı.
    final isLight = AppTheme.isLight(context);
    final Gradient gradient = correct
        ? AppTheme.correctGradient
        : wrong
        ? AppTheme.wrongGradient
        : isChecking
        ? AppTheme.accentGradient
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isLight
                ? const [Color(0xFFFFFFFF), Color(0xFFF7F4EE)]
                : [
                    AppTheme.surfaceHiColor(context),
                    AppTheme.surfaceColor(context),
                  ],
          );

    final Color borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : isChecking
        ? AppTheme.brand
        : optionColor.withValues(alpha: isLight ? 0.45 : 0.55);

    final textColor = correct || wrong || isChecking
        ? Colors.white
        : AppTheme.textPrimaryColor(context);

    // 3D Gölge rengi
    final Color shadowColor = correct
        ? const Color(0xFF009E6A)
        : wrong
        ? const Color(0xFFD61A4C)
        : isChecking
        ? AppTheme.brand
        : AppTheme.borderColor(context);

    final isPressed = selected;
    final letter = String.fromCharCode(65 + (index % 26));
    final stateActive = correct || wrong || isChecking;
    final stateHint = correct
        ? ', ${context.t(K.correct)}'
        : wrong
        ? ', ${context.t(K.wrong)}'
        : '';

    // Varsayılan olarak Flutter web/erişilebilirlik ağacı bu düğümü kardeş
    // şıklarla tek bir node'a birleştirebiliyor (bkz. 2026-07-04 keşif turu:
    // otomasyon/ekran okuyucu tek şıkkı ayırt edemiyordu). button+label+
    // excludeSemantics ile her şık kendi bağımsız, tıklanabilir semantik
    // düğümünü alır.
    return Semantics(
      button: true,
      enabled: !disabled,
      selected: selected,
      label: '$letter: $answer$stateHint',
      onTap: disabled ? null : onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: (dimmed ? 0.4 : 1.0).clamp(0.0, 1.0),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.only(
            top: isPressed ? 4 : 0,
            bottom: isPressed ? 0 : 4,
          ),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(18),
            // "Hareketi azalt" açıkken sarsıntı ve zıplama uygulanmaz.
            //
            // Sağlayıcı ve ayar zaten vardı ama bu iki animasyon onu hiç
            // okumuyordu (2026-08-02 denetimi). Tercihi açan kullanıcı
            // uygulamanın en çok gördüğü ekranda yine sallanan kartlarla
            // karşılaşıyordu. Doğru/yanlış bilgisi renk, ikon ve
            // semantik metinle zaten taşınıyor; hareket yalnız süstü.
            child: TweenAnimationBuilder<double>(
              key: ValueKey('shake_$wrong'),
              duration: const Duration(milliseconds: 300),
              tween: Tween<double>(
                begin: 0.0,
                end: (wrong && !ReducedMotionProvider.isReducedIn(context))
                    ? 1.0
                    : 0.0,
              ),
              builder: (context, t, child) {
                if (!wrong) return child!;
                final shake = sin(t * 4 * pi) * (1.0 - t) * 4.0;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: child,
                );
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey('bounce_$correct'),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                tween: Tween<double>(begin: correct ? 0.95 : 1.0, end: 1.0),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  // Dikey dolgu ekranın boyuna göre açılır.
                  //
                  // Sabit dolguyla kart doğal yüksekliğinde kalıyor ve uzun
                  // ekranlarda soru + şıklar ortada yüzen küçük bir blok
                  // gibi duruyordu; altta ve üstte geniş boş bantlar
                  // kalıyordu (2026-07-27, canlı gezinti). Yükseklik arttıkça
                  // şıklar da büyür: hem ekran dolar hem dokunma hedefi
                  // genişler.
                  // ALT SINIR, sabit yükseklik değil.
                  //
                  // Sabit `height` verildiğinde içerik ayrılan boydan uzun
                  // olduğunda kutu taşıyordu: çok oyunculu odada şıkkın
                  // altına seyirci yüzdesi/rakip rozeti eklenince
                  // "RenderFlex overflowed by 26 pixels" çıkıyordu
                  // (2026-08-16, room_lobby_test). Alt sınır hem alanı
                  // doldurur hem taşmayı imkânsız kılar: içerik uzunsa kutu
                  // büyür, toplam ekranı aşarsa kaydırma emniyet supabı
                  // devreye girer.
                  constraints: fixedHeight == null
                      ? null
                      : BoxConstraints(minHeight: fixedHeight!),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: fixedHeight != null
                        ? AppSpacing.xs
                        : _verticalPadding(context),
                  ),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 2.0),
                    boxShadow: isPressed
                        ? (correct
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : [])
                        : [
                            if (correct)
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            BoxShadow(
                              color: shadowColor.withValues(alpha: 0.28),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                              spreadRadius: -2,
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _OptionBadge(
                            index: index,
                            stateActive: stateActive,
                            stateColor: borderColor,
                            idleColor: optionColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              answer,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLarge.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: isCompact ? 15 : 17,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: correct
                                ? const Icon(
                                    AppIcons.circleCheck,
                                    key: ValueKey('correct_icon'),
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : wrong
                                ? const Icon(
                                    AppIcons.circleXmark,
                                    key: ValueKey('wrong_icon'),
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('empty_icon'),
                                  ),
                          ),
                        ],
                      ),
                      if (audiencePercent != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                                child: LinearProgressIndicator(
                                  value: audiencePercent!.clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.24,
                                  ),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              context.percentRatio(audiencePercent!),
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (opponentNamesWhoSelected != null &&
                          opponentNamesWhoSelected!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: opponentNamesWhoSelected!
                              .map(
                                (name) => Container(
                                  margin: const EdgeInsets.only(
                                    left: AppSpacing.xxs,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  // Göz emojisi ikonla değişti: Rubik emoji
                                  // taşımıyor, o karakter sistem yazı tipine
                                  // düşüyordu (2026-07-26).
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTypography.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        AppIcons.eye,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ), // Column
                ), // AnimatedContainer
              ), // bounce TweenAnimationBuilder
            ), // shake TweenAnimationBuilder
          ), // InkWell
        ), // AnimatedPadding
      ), // Opacity
    );
  }
}

// ─── Şık rozeti (A/B/C/D) ────────────────────────────────────────────────────

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({
    required this.index,
    required this.stateActive,
    required this.stateColor,
    this.idleColor,
  });

  final int index;
  final bool stateActive;
  final Color stateColor;
  // Idle durumda rozet içindeki harf rengi (şıkkın kimlik rengi).
  final Color? idleColor;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    final fg = stateActive ? stateColor : (idleColor ?? AppTheme.brand);

    final idle = !stateActive;
    final badgeBg = idle ? fg : Colors.white;
    final badgeFg = idle ? Colors.white : fg;

    // Rozet artık yuvarlatılmış kare değil, elmas: Rengîn geometrisi
    // kategori ambleminde ve şık indeksinde aynı dili konuşur. Harf
    // döndürülmez — yalnız zemin döner, yoksa "A" yan yatar.
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.7853981633974483, // 45°
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
                boxShadow: idle
                    ? [
                        BoxShadow(
                          color: fg.withValues(alpha: 0.30),
                          blurRadius: 7,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          // Rozette bir zamanlar harfin üstüne 8 px'lik bir şekil ikonu
          // biniyordu (renk körü ayrımı için). 34 px'lik rozette o boyut bir
          // işaret değil bir leke: harfin tepesine oturuyor ve "A" bozuk bir
          // karakter gibi görünüyordu (2026-07-27, canlı gezinti).
          //
          // Şekil kaldırıldı; ayrımı harfin kendisi taşıyor. A/B/C/D renkten
          // bağımsızdır, evrenseldir ve ekran okuyucuya da aynı adla gider —
          // yani erişilebilirlik kaybı yok, okunaklılık kazancı var.
          Text(letter, style: AppTypography.heading2.copyWith(color: badgeFg)),
        ],
      ),
    );
  }
}
