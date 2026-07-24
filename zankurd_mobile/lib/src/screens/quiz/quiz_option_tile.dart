import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';

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
        ? ', doğru cevap'
        : wrong
        ? ', yanlış'
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('shake_$wrong'),
              duration: const Duration(milliseconds: 300),
              tween: Tween<double>(begin: 0.0, end: wrong ? 1.0 : 0.0),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: isCompact ? AppSpacing.xs : AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                              '${(audiencePercent! * 100).round()}%',
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
                                  child: Text(
                                    '$name 👀',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
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

  // Renk körü erişilebilirliği: her şık harf rengine ek olarak benzersiz
  // bir şekil taşır (A=daire, B=kare, C=üçgen, D=elmas).
  static const shapeIcons = [
    Icons.circle_outlined,
    Icons.square_outlined,
    Icons.change_history, // üçgen
    Icons.diamond_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    final fg = stateActive ? stateColor : (idleColor ?? AppTheme.brand);

    final idle = !stateActive;
    final badgeBg = idle ? fg : Colors.white;
    final badgeFg = idle ? Colors.white : fg;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: idle
            ? [
                BoxShadow(
                  color: fg.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(letter, style: AppTypography.heading2.copyWith(color: badgeFg)),
          Positioned(
            top: 2,
            right: 2,
            child: Icon(
              shapeIcons[index % shapeIcons.length],
              size: 8,
              color: badgeFg.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
