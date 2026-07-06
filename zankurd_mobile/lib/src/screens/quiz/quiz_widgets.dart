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
              const SizedBox(width: 8),
              Text(
                context.s('Skora zindî', 'Canlı skor'),
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 10),
          PlayerAvatar(
            radius: 14,
            photoUrl: player.avatarUrl,
            iconId: player.avatarIcon,
            colorHex: player.avatarColor,
            frameId: player.avatarFrame,
            displayName: player.name,
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
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
  const _QuestionImage({required this.url});

  final String url;

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
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _QuestionImageFallback(),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _QuestionImageFallback(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isLandscapeTablet
          ? SizedBox(width: double.infinity, height: maxHeight, child: image)
          : AspectRatio(aspectRatio: 16 / 9, child: image),
    );
  }
}

class _QuestionImageFallback extends StatelessWidget {
  const _QuestionImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceHiColor(context),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.textMutedColor(context),
        size: 36,
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

  /// Gerilim tutuşu: cevap seçildi ama sonuç henüz açıklanmadı.
  /// True iken doğru/yanlış renkleri gizlenir; seçilen şık "kontrol
  /// ediliyor" (accent) stilinde bekler.
  final bool suspense;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          promptText,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontSize: promptFontSize,
            fontWeight: FontWeight.w700,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 14),
        for (final (index, answer) in question.displayAnswers.indexed)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: hiddenAnswers.contains(answer) ? 0.25 : 1,
            child: IgnorePointer(
              ignoring: hiddenAnswers.contains(answer),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAnswerButton(index, answer),
              ),
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
    final button = _AnswerButton(
      index: index,
      answer: answer,
      selected: selectedAnswer == answer,
      correct: revealed && answer == question.correctAnswer,
      disabled: answered || answer == firstAttemptAnswer,
      firstAttemptWrong: !answered && answer == firstAttemptAnswer,
      suspense: suspense,
      audiencePercent: audiencePoll?[answer],
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
    required this.progress,
    required this.coinBalance,
  });

  final int score;
  final int streak;
  final String progress;
  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Pûan', 'Puan'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: streak),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Rêz', 'Seri'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: context.s('Pirs', 'Soru'), value: progress),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: coinBalance),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: 'Coin', value: '$value'),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${player.score} pts',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
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
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  children: [
                    Text(
                      progress,
                      style: TextStyle(
                        color: AppTheme.textSubColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
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
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${opponent.score} pts',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
            const SizedBox(height: 8),
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
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
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
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 12,
            ),
          ),
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

  // A/B/C/D rozetleriyle eşleşen kenarlık renkleri
  static const _badgePalette = [
    Color(0xFFE94560), // A — kırmızı
    Color(0xFF2563EB), // B — mavi
    Color(0xFF10B981), // C — yeşil
    Color(0xFFD97706), // D — koyu amber (WCAG kontrast için)
  ];

  @override
  Widget build(BuildContext context) {
    final wrong =
        (!suspense && selected && !correct && disabled) || firstAttemptWrong;
    final isChecking = selected && (suspense || !disabled);

    final badgeColor = _badgePalette[index % _badgePalette.length];

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

    final Color borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : isChecking
        ? AppTheme.accent
        : badgeColor.withValues(alpha: 0.40);

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
        ? const Color(0xFFFF6B6B)
        : badgeColor;

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
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(
          top: isPressed ? 4 : 0,
          bottom: isPressed ? 0 : 4,
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2.0),
              boxShadow: isPressed
                  ? []
                  : [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.30),
                        offset: const Offset(0, 4),
                        blurRadius: 0,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        answer,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: correct
                          ? const Icon(
                              Icons.check_circle_outline,
                              key: ValueKey('correct_icon'),
                              color: Colors.white,
                            )
                          : wrong
                          ? const Icon(
                              Icons.cancel_outlined,
                              key: ValueKey('wrong_icon'),
                              color: Colors.white,
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_icon')),
                    ),
                  ],
                ),
                if (audiencePercent != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
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
                      const SizedBox(width: 8),
                      Text(
                        '${(audiencePercent! * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  /// TRT tarzı çok-renkli şıklar: A kırmızı, B mavi, C yeşil, D amber.
  static const _palette = [
    Color(0xFFE94560),
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    final base = _palette[index % _palette.length];
    final bg = stateActive ? Colors.white : base;
    final fg = stateActive ? stateColor : Colors.white;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: stateActive
            ? null
            : [
                BoxShadow(
                  color: base.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        letter,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 17),
      ),
    );
  }
}

// ─── Küçük etiket ────────────────────────────────────────────────────────────

class _QuizQuestionIconBadge extends StatelessWidget {
  const _QuizQuestionIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('quiz-question-icon-badge'),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.accentGradient,
        boxShadow: AppTheme.elevatedShadow(AppTheme.accent),
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

class _WildcardButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final baseColor = type.themeColor;

    final opacity = (isEnabled || isActive)
        ? 1.0
        : cantAfford
        ? 0.45
        : 0.35;

    final borderColor = isActive
        ? AppTheme.accent
        : cantAfford
        ? AppTheme.wrong.withValues(alpha: 0.5)
        : isEnabled
        ? baseColor.withValues(alpha: 0.75)
        : AppTheme.borderColor(context);

    final bgColor = isActive
        ? AppTheme.accent.withValues(alpha: 0.15)
        : cantAfford
        ? AppTheme.wrong.withValues(alpha: 0.05)
        : isEnabled
        ? baseColor.withValues(alpha: 0.12)
        : null;

    final iconColor = isActive
        ? AppTheme.accent
        : cantAfford
        ? AppTheme.wrong
        : isEnabled
        ? baseColor
        : AppTheme.textMutedColor(context);

    return Opacity(
      opacity: opacity,
      child: OutlinedButton(
        onPressed: isEnabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 50),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: isEnabled ? 0.16 : 0.10),
              ),
              child: Icon(
                cantAfford ? Icons.lock_outline : type.icon,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${type.coinCost}c',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
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
        const Color(0xFF4CAF50), // Green
        (progress - 0.5) * 2,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFF44336), // Red
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
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: _TimerPainter(progress: progress, color: color),
                    ),
                    Text(
                      '$seconds',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: visible
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
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context).withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.correct,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isKu ? 'Bersiva rast' : 'Doğru cevap',
                            style: const TextStyle(
                              color: AppTheme.correct,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            question.correctAnswer,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: AppTheme.borderColor(context),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 14,
                                color: AppTheme.textSubColor(context),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  isKu ? 'Şîrove' : 'Açıklama',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textSubColor(context),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            question.getLocalizedExplanation(isKu),
                            style: TextStyle(
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
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
