part of '../quiz_screen.dart';

// ─── Canlı skor tablosu ──────────────────────────────────────────────────────

class _LiveScoreboard extends StatelessWidget {
  const _LiveScoreboard({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_outlined, color: AppTheme.gold),
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
          for (var i = 0; i < sortedPlayers.take(4).length; i++)
            _LiveScoreRow(rank: i + 1, player: sortedPlayers[i]),
        ],
      ),
    );
  }
}

class _LiveScoreRow extends StatelessWidget {
  const _LiveScoreRow({required this.rank, required this.player});

  final int rank;
  final Player player;

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
            Icons.image_not_supported_outlined,
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

    final button = _AnswerButton(
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

class _TimeoutNotice extends StatelessWidget {
  const _TimeoutNotice({required this.isKu, required this.correctAnswer});

  final bool isKu;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    // Süre dolduğunda şıklar zaten kilitlenir (answered=true); bu bant
    // geri bildirimi netleştirir: süre bitti + doğru cevap görünür.
    final label = isKu
        ? 'Dem qediya! Bersiva rast: $correctAnswer'
        : 'Süre doldu! Doğru cevap: $correctAnswer';
    return Semantics(
      key: const ValueKey('quiz-timeout-notice'),
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.wrong.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppTheme.wrong.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.timer_off_outlined,
                color: AppTheme.wrong,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          icon: Icons.emoji_events_outlined,
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
            icon: streak >= 2
                ? Icons.local_fire_department
                : Icons.local_fire_department_outlined,
            iconColor: streak >= 2
                ? AppTheme.gold
                : AppTheme.textMutedColor(context),
            value: streak >= 2 ? 'x$streak' : '$streak',
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ScoreChip(
          tooltip: context.s('Coin', 'Kredi'),
          icon: Icons.monetization_on_outlined,
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
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 14,
                      ),
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
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 14,
                      ),
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

// ─── Cevap butonu ────────────────────────────────────────────────────────────

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
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
  /// disabled görünüm; renk yalnız doğru/yanlış anlamı taşısın.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final wrong =
        (!suspense && selected && !correct && disabled) || firstAttemptWrong;
    final isChecking = selected && (suspense || !disabled);

    // Gradient belirleme
    final Gradient gradient = correct
        ? AppTheme.correctGradient
        : wrong
        ? AppTheme.wrongGradient
        : isChecking
        ? AppTheme.accentGradient
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceColor(context).withValues(alpha: 0.98),
              AppTheme.surfaceHiColor(context).withValues(alpha: 0.88),
            ],
          );

    // Dinlenme halinde nötr kenarlık: dört şıkkın dört ayrı renkte
    // çerçevesi paneli karmaşıklaştırıyordu (Pirs referansı: sakin beyaz
    // satırlar, renk yalnız rozette ve durum geri bildiriminde).
    final Color borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : isChecking
        ? AppTheme.brandGreen
        : AppTheme.borderColor(context);

    // Metin rengi
    final Color textColor = (correct || wrong || isChecking)
        ? Colors.white
        : AppTheme.textPrimaryColor(context);

    // 3D Gölge rengi
    final Color shadowColor = correct
        ? const Color(0xFF009E6A)
        : wrong
        ? const Color(0xFFD61A4C)
        : isChecking
        ? AppTheme.brandGreen
        : Colors.black;

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
        opacity: dimmed ? 0.4 : 1.0,
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
                                    Icons.check_circle_outline,
                                    key: ValueKey('correct_icon'),
                                    color: Colors.white,
                                    size: 28,
                                  )
                                : wrong
                                ? const Icon(
                                    Icons.cancel_outlined,
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
  });

  final int index;

  /// Buton bir durumda (doğru/yanlış/seçili) ise rozet beyaza döner.
  final bool stateActive;
  final Color stateColor;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    // Dalga 5: dinlenme halinde dört rozet dört doygun renk taşıyordu;
    // renk yalnız reveal'de anlam taşısın diye tüm rozetler nötr gri
    // outline. Durum aktifken rozet beyaza dönüp durum rengini verir.
    final bg = stateActive ? Colors.white : Colors.transparent;
    final fg = stateActive ? stateColor : AppTheme.textMutedColor(context);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: stateActive
            ? null
            : Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Text(letter, style: AppTypography.heading2.copyWith(color: fg)),
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

// ─── Joker butonu ────────────────────────────────────────────────────────────

class _WildcardButton extends StatefulWidget {
  const _WildcardButton({
    required this.type,
    required this.isKu,
    required this.isEnabled,
    required this.isActive,
    required this.onTap,
    this.cantAfford = false,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isActive;
  final bool cantAfford;
  final VoidCallback onTap;

  @override
  State<_WildcardButton> createState() => _WildcardButtonState();
}

class _WildcardButtonState extends State<_WildcardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.type.themeColor;

    final opacity = (widget.isEnabled || widget.isActive)
        ? 1.0
        : widget.cantAfford
        ? 0.45
        : 0.35;

    final borderColor = widget.isActive
        ? AppTheme.brandGreen
        : widget.cantAfford
        // Kilitli joker "hata" değil; kırmızı yerine nötr tema rengi.
        ? AppTheme.borderColor(context)
        : widget.isEnabled
        ? baseColor.withValues(alpha: 0.75)
        : AppTheme.borderColor(context);

    final bgColor = widget.isActive
        ? AppTheme.brandGreen.withValues(alpha: 0.15)
        : widget.cantAfford
        ? AppTheme.surfaceHiColor(context).withValues(alpha: 0.4)
        : widget.isEnabled
        ? baseColor.withValues(alpha: 0.12)
        : null;

    final iconColor = widget.isActive
        ? AppTheme.brandGreen
        : widget.cantAfford
        ? AppTheme.textMutedColor(context)
        : widget.isEnabled
        ? baseColor
        : AppTheme.textMutedColor(context);

    return Tooltip(
      message: widget.type.label(widget.isKu),
      child: GestureDetector(
        onTapDown: widget.isEnabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.isEnabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: widget.isEnabled
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: opacity,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              constraints: const BoxConstraints(minHeight: 36),
              decoration: BoxDecoration(
                color: bgColor ?? Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withValues(
                          alpha: widget.isEnabled ? 0.16 : 0.10,
                        ),
                      ),
                      child: Icon(
                        widget.cantAfford
                            ? Icons.lock_outline
                            : widget.type.icon,
                        size: 12,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Ad + fiyat tek satırda: uzun joker adları ("Pirsê
                    // Biguhere") iki satıra düşüp taşırıyordu.
                    Text(
                      '${widget.type.label(widget.isKu)} · ${widget.type.coinCost}c',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        height: 1.0,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dairesel Sayaç (Circular Timer) ──────────────────────────────────────────

class _CircularTimer extends StatefulWidget {
  const _CircularTimer({
    required this.animation,
    required this.maxSeconds,
    required this.isPaused,
    super.key,
  });

  final Animation<double> animation;
  final int maxSeconds;
  final bool isPaused;

  @override
  State<_CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends State<_CircularTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.animation.addListener(_handleAnimationTick);
  }

  @override
  void didUpdateWidget(covariant _CircularTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused) {
      _pulseController.stop();
    }
  }

  void _handleAnimationTick() {
    final value = widget.animation.value;
    final seconds = (value * widget.maxSeconds).ceil();
    final shouldPulse = seconds <= 5 && seconds > 0 && !widget.isPaused;

    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimationTick);
    _pulseController.dispose();
    super.dispose();
  }

  Color _getTimerColor(double progress) {
    if (progress > 0.5) {
      return Color.lerp(
        const Color(0xFFFFC107), // Amber
        AppTheme.brandGreen, // Green
        (progress - 0.5) * 2,
      )!;
    } else {
      return Color.lerp(
        AppTheme.wrong, // Red
        const Color(0xFFFFC107), // Amber
        progress * 2,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final progress = widget.animation.value;
        final seconds = (progress * widget.maxSeconds).ceil();
        final color = _getTimerColor(progress);

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            final isAlert = seconds <= 5 && seconds > 0 && !widget.isPaused;
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isAlert
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: _TimerPainter(progress: progress, color: color),
                    ),
                    Text(
                      '$seconds',
                      style: AppTypography.bodyMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        shadows: isAlert
                            ? [
                                Shadow(
                                  color: color.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimerPainter extends CustomPainter {
  _TimerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 2, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
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
                          Icons.lightbulb_outline,
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
                                isKu ? 'Bersiva rast' : 'Doğru cevap',
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
                                    Icons.menu_book_outlined,
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
            color: AppTheme.brandGreen.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.brandGreen,
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
              Icons.hourglass_top_rounded,
              color: AppTheme.brandGreen.withValues(alpha: 0.6),
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
              Icons.skip_next_rounded,
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
          const Icon(
            Icons.emoji_events_outlined,
            size: 16,
            color: AppTheme.accent,
          ),
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
