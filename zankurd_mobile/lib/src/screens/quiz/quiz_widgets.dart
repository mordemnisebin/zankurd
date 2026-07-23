part of '../quiz_screen.dart';

// ─── Canlı skor tablosu ──────────────────────────────────────────────────────

class _LiveScoreboard extends StatelessWidget {
  const _LiveScoreboard({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final shown = sortedPlayers.take(4).toList();
    // 2026-07-23 M25b: aynı skor tablosunda hash çakışması varsa
    // round-robin ile çözülür (bkz. leaderboard_screen.dart ile aynı desen).
    final colorOverrides = resolveAvatarColors(
      shown.map(
        (p) =>
            (id: p.id ?? p.name, displayName: p.name, colorHex: p.avatarColor),
      ),
    );

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.chartColumn, color: AppTheme.gold),
              const SizedBox(width: AppSpacing.xs),
              Text(
                context.s('Skora zindî', 'Canlı skor'),
                style: AppTypography.heading2.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < shown.length; i++)
            _LiveScoreRow(
              rank: i + 1,
              player: shown[i],
              colorOverride: colorOverrides[shown[i].id ?? shown[i].name],
            ),
        ],
      ),
    );
  }
}

class _LiveScoreRow extends StatelessWidget {
  const _LiveScoreRow({
    required this.rank,
    required this.player,
    this.colorOverride,
  });

  final int rank;
  final Player player;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          PlayerAvatar(
            radius: 14,
            photoUrl: player.avatarUrl,
            iconId: player.avatarIcon,
            colorHex: player.avatarColor,
            frameId: player.avatarFrame,
            displayName: player.name,
            colorOverride: colorOverride,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${player.score}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Soru görseli ────────────────────────────────────────────────────────────

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({
    required this.url,
    this.isCompact = false,
    this.onReady,
  });

  final String url;
  final bool isCompact;
  final VoidCallback? onReady;

  void _notifyReady() {
    final callback = onReady;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = url.startsWith('asset://')
        ? url.replaceFirst('asset://', '')
        : null;
    final size = MediaQuery.sizeOf(context);
    final isLandscapeTablet = size.width >= 700 && size.width > size.height;
    final maxHeight = isLandscapeTablet
        ? (size.height * 0.24).clamp(84.0, 150.0)
        : double.infinity;

    final image = assetPath == null
        ? Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) _notifyReady();
              return child;
            },
            errorBuilder: (context, error, stackTrace) =>
                const _QuestionImageFallback(),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) _notifyReady();
              return child;
            },
            errorBuilder: (context, error, stackTrace) =>
                const _QuestionImageFallback(),
          );

    final double? forcedHeight = isCompact
        ? (size.height * 0.15).clamp(60.0, 100.0)
        : null;
    // Portre düzende 16/9 çerçeve dar ama uzun görsellerde büyük boş
    // alan bırakıyordu; yüksekliği ekranın %30'u ile sınırla.
    final portraitHeight = min(
      size.width * 9 / 16,
      size.height * 0.30,
    ).clamp(120.0, 260.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: (isLandscapeTablet || forcedHeight != null)
          ? SizedBox(
              width: double.infinity,
              height: forcedHeight ?? maxHeight,
              child: image,
            )
          : SizedBox(
              width: double.infinity,
              height: portraitHeight,
              child: image,
            ),
    );
  }
}

/// Görsel yüklenemediğinde gösterilen standart geri dönüş yüzeyi:
/// ikon + kısa mesaj; boş gri kutu yerine temalı, sınırlı panel.
class _QuestionImageFallback extends StatelessWidget {
  const _QuestionImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.image,
            color: AppTheme.textMutedColor(context),
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            context.s('Wêne nehat barkirin', 'Görsel yüklenemedi'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTextAndAnswers extends StatelessWidget {
  const _QuestionTextAndAnswers({
    required this.promptText,
    required this.promptFontSize,
    required this.question,
    required this.selectedAnswer,
    required this.answered,
    required this.hiddenAnswers,
    required this.firstAttemptAnswer,
    required this.showExplanation,
    required this.suspense,
    required this.onAnswer,
    this.audiencePoll,
    this.opponentSelectedAnswers,
    this.isCompact = false,
    this.answerAreaKey,
  });

  final String promptText;
  final double promptFontSize;
  final QuizQuestion question;
  final String selectedAnswer;
  final bool answered;
  final Set<String> hiddenAnswers;
  final String firstAttemptAnswer;
  final Map<String, double>? audiencePoll;
  final bool showExplanation;
  final Map<String, String>? opponentSelectedAnswers;
  final bool isCompact;

  /// Quiz turu için cevap alanını hedef gösteren GlobalKey.
  final GlobalKey? answerAreaKey;

  /// Gerilim tutuşu: cevap seçildi ama sonuç henüz açıklanmadı.
  /// True iken doğru/yanlış renkleri gizlenir; seçilen şık "kontrol
  /// ediliyor" (accent) stilinde bekler.
  final bool suspense;
  final ValueChanged<String> onAnswer;

  /// Soru metnini seslendirmek için isteğe bağlı callback.

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                promptText,
                style: AppTypography.heading2.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: promptFontSize,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.sm),
        Container(
          key: answerAreaKey,
          child: LayoutBuilder(
            builder: (context, areaConstraints) {
              // Landscape (844x390 gibi): dikey alan kıt — 4 şık 2x2
              // grid'e girer, Piştre butonu ekranda kalır.
              final answers = question.displayAnswers;
              final twoColumn =
                  isCompact &&
                  areaConstraints.maxWidth >= 520 &&
                  answers.length == 4;

              Widget item(int index, String answer) {
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: hiddenAnswers.contains(answer) ? 0.25 : 1,
                  child: IgnorePointer(
                    ignoring: hiddenAnswers.contains(answer),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isCompact ? AppSpacing.xxs : AppSpacing.xs,
                      ),
                      child: _buildAnswerButton(index, answer),
                    ),
                  ),
                );
              }

              if (!twoColumn) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, answer) in answers.indexed)
                      item(index, answer),
                  ],
                );
              }

              final itemWidth = (areaConstraints.maxWidth - AppSpacing.xs) / 2;
              return Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final (index, answer) in answers.indexed)
                    SizedBox(width: itemWidth, child: item(index, answer)),
                ],
              );
            },
          ),
        ),
        _ExplanationBox(
          question: question,
          isKu: context.isKu,
          visible: showExplanation,
        ),
      ],
    );
  }

  /// Tek bir şık butonu üretir; gerilim tutuşu sırasında doğru/yanlış
  /// renkleri gizler, yanlış açıklanan şıkkı sarsıntıyla sarar.
  Widget _buildAnswerButton(int index, String answer) {
    final revealed = answered && !suspense;
    final List<String> opps = [];
    if (revealed && opponentSelectedAnswers != null) {
      opponentSelectedAnswers!.forEach((name, ans) {
        if (ans == answer) {
          opps.add(name);
        }
      });
    }

    final button = QuizOptionTile(
      index: index,
      answer: answer,
      selected: selectedAnswer == answer,
      correct: revealed && answer == question.correctAnswer,
      disabled: answered || answer == firstAttemptAnswer,
      firstAttemptWrong: !answered && answer == firstAttemptAnswer,
      suspense: suspense,
      audiencePercent: audiencePoll?[answer],
      opponentNamesWhoSelected: opps,
      isCompact: isCompact,
      // Reveal'de renk yalnız anlam taşır: doğru yeşil, seçilen yanlış
      // kırmızı; geri kalan şıklar soluk/disabled görünür.
      dimmed:
          revealed &&
          answer != question.correctAnswer &&
          selectedAnswer != answer,
      onTap: () => onAnswer(answer),
    );
    final isWrongSelected =
        revealed &&
        answer == selectedAnswer &&
        answer != question.correctAnswer;
    if (isWrongSelected) {
      return ShakeWrapper(trigger: 1, child: button);
    }
    return button;
  }
}

// ─── Üst skor başlığı ────────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.streak,
    required this.coinBalance,
  });

  final int score;
  final int streak;
  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    // Dalga 5: 3 ayrı kart yerine tek kompakt chip satırı — kazanılan
    // dikey alan soru paneline kalır. Anlam ikon+tooltip ile taşınır.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ScoreChip(
          tooltip: context.s('Pûan', 'Puan'),
          icon: AppIcons.trophy,
          iconColor: AppTheme.gold,
          value: '$score',
        ),
        const SizedBox(width: AppSpacing.xs),
        // Seri kutlaması: 2+ seride her artışta chip "pop" yapar,
        // alev dolu ikona döner — quiz içi mikro-ödül anı.
        TweenAnimationBuilder<double>(
          key: ValueKey('streak-pop-$streak'),
          tween: Tween(begin: streak >= 2 ? 1.3 : 1.0, end: 1.0),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: _ScoreChip(
            tooltip: context.s('Rêz', 'Seri'),
            icon: streak >= 2 ? AppIcons.fire : AppIcons.fire,
            iconColor: streak >= 2
                ? AppTheme.gold
                : AppTheme.textMutedColor(context),
            value: streak >= 2 ? 'x$streak' : '$streak',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ScoreChip(
          tooltip: context.s('Coin', 'Kredi'),
          icon: AppIcons.coins,
          iconColor: AppTheme.gold,
          value: '$coinBalance',
        ),
      ],
    );
  }
}

/// Kompakt üst-bar metriği: ikon + değer, anlam tooltip'te.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHiColor(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              maxLines: 1,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuelScoreHeader extends StatelessWidget {
  const _DuelScoreHeader({
    required this.player,
    required this.opponent,
    required this.progress,
  });

  final Player player;
  final Player opponent;
  final String progress;

  @override
  Widget build(BuildContext context) {
    // 2026-07-23 M25b: sadece 2 oyuncu olsa da hash çakışması mümkün
    // (iki isim aynı palet dilimine düşebilir) — aynı desenle çözülür.
    final colorOverrides = resolveAvatarColors([
      (
        id: player.id ?? player.name,
        displayName: player.name,
        colorHex: player.avatarColor,
      ),
      (
        id: opponent.id ?? opponent.name,
        displayName: opponent.name,
        colorHex: opponent.avatarColor,
      ),
    ]);
    final playerColor = colorOverrides[player.id ?? player.name];
    final opponentColor = colorOverrides[opponent.id ?? opponent.name];

    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Player info
              Expanded(
                child: Row(
                  children: [
                    PlayerAvatar(
                      radius: 16,
                      photoUrl: player.avatarUrl,
                      iconId: player.avatarIcon,
                      colorHex: player.avatarColor,
                      frameId: player.avatarFrame,
                      displayName: player.name,
                      colorOverride: playerColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${player.score} pts',
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // VS & Progress
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  children: [
                    Text(
                      progress,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'VS',
                      style: AppTypography.caption.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              // Opponent info
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            opponent.name,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${opponent.score} pts',
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    PlayerAvatar(
                      radius: 16,
                      photoUrl: opponent.avatarUrl,
                      iconId: opponent.avatarIcon,
                      colorHex: opponent.avatarColor,
                      frameId: opponent.avatarFrame,
                      displayName: opponent.name,
                      colorOverride: opponentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (player.streak > 0 || opponent.streak > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (player.streak > 0)
                  Row(
                    children: [
                      const Icon(AppIcons.fire, color: Colors.orange, size: 14),
                      Text(
                        'x${player.streak}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                if (opponent.streak > 0)
                  Row(
                    children: [
                      Text(
                        'x${opponent.streak}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(AppIcons.fire, color: Colors.orange, size: 14),
                    ],
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Küçük etiket ────────────────────────────────────────────────────────────

class _QuizQuestionIconBadge extends StatelessWidget {
  const _QuizQuestionIconBadge({required this.icon, this.gradient});

  final IconData icon;

  /// Kategori gradyanı verilirse rozet o kimliği taşır.
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppTheme.accentGradient;
    return Container(
      key: const ValueKey('quiz-question-icon-badge'),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: g,
        boxShadow: AppTheme.elevatedShadow(g.colors.first),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textSubColor(context),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Cevap Açıklama Kutusu (Explanation Box) ──────────────────────────────────

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({
    required this.question,
    required this.isKu,
    required this.visible,
  });

  final QuizQuestion question;
  final bool isKu;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    // Şablon/boş açıklamada kutu hiç açılmaz (getLocalizedExplanation '' döner).
    final explanationText = question.getLocalizedExplanation(isKu);
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: visible && explanationText.isNotEmpty
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(
                    AppRadius.md,
                  ), // AppRadius.lg
                  border: Border.all(
                    color: AppTheme.correct.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          AppIcons.lightbulb,
                          color: AppTheme.correct,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isKu ? 'Bersivên rast' : 'Doğru cevap',
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.correct,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                question.correctAnswer,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.bookOpen,
                                    size: 14,
                                    color: AppTheme.textSubColor(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isKu
                                          ? 'Şîrove · Zana'
                                          : 'Açıklama · Zana',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: AppTheme.textSubColor(context),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                explanationText,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTheme.textSubColor(context),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

// ─── Multiplayer Bekleme Overlay ────────────────────────────────────────────

class _MultiplayerWaitingOverlay extends StatelessWidget {
  const _MultiplayerWaitingOverlay({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHiColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppTheme.brand.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isKu ? 'Bersiva te hat qeydkirin' : 'Cevabın kaydedildi',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isKu
                        ? 'Li benda hevrik tê bendewarî...'
                        : 'Diğer oyuncu bekleniyor...',
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.hourglassStart,
              color: AppTheme.brand.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reveal Countdown ──────────────────────────────────────────────────────

class _RevealCountdown extends StatelessWidget {
  const _RevealCountdown({required this.seconds, required this.isKu});

  final int seconds;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.forward,
              color: AppTheme.textSubColor(context),
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isKu ? 'Pirsa nû: ${seconds}s' : 'Sonraki soru: ${seconds}s',
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turnuva maçı üst bandı: tur + rakip bilgisi (salt görüntü, state'e girmez).
class _VersusBanner extends StatelessWidget {
  const _VersusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.trophy, size: 16, color: AppTheme.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSubColor(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1v1 online eşleşmede karşı taraf henüz bu ekrana ulaşmadığında
/// gösterilir; soru sayacının erken başlamasını görsel olarak da
/// engeller (dokunuşları yutar).
class _OpponentWaitingOverlay extends StatelessWidget {
  const _OpponentWaitingOverlay({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: AppTheme.bg.withValues(alpha: 0.82),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.gold),
              const SizedBox(height: 16),
              Text(
                isKu ? 'Li benda hevrikê ye...' : 'Rakip bekleniyor...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
