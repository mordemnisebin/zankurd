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
                  fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
              fontWeight: FontWeight.w900,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: assetPath == null
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
              ),
      ),
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
              fontWeight: FontWeight.w900,
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
    required this.answer,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
    this.firstAttemptWrong = false,
    this.audiencePercent,
  });

  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;
  final bool firstAttemptWrong;
  final double? audiencePercent;

  @override
  Widget build(BuildContext context) {
    final wrong = (selected && !correct && disabled) || firstAttemptWrong;
    final color = correct
        ? AppTheme.correct.withValues(alpha: 0.15)
        : wrong
        ? AppTheme.wrong.withValues(alpha: 0.15)
        : AppTheme.surfaceColor(context).withValues(alpha: 0.72);
    final borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : AppTheme.borderColor(context);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: selected ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      answer,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (correct)
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.correct,
                    ),
                  if (wrong)
                    const Icon(Icons.cancel_outlined, color: AppTheme.wrong),
                ],
              ),
              if (audiencePercent != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: audiencePercent!.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: AppTheme.borderColor(context),
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(audiencePercent! * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Küçük etiket ────────────────────────────────────────────────────────────

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
          fontWeight: FontWeight.w900,
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
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (isEnabled || isActive) ? 1.0 : 0.35,
      child: OutlinedButton(
        onPressed: isEnabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive
              ? AppTheme.accent.withValues(alpha: 0.15)
              : null,
          side: isActive
              ? const BorderSide(color: AppTheme.accent)
              : BorderSide(color: AppTheme.borderColor(context)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 16),
            const SizedBox(height: 2),
            Text(
              '${type.coinCost}c',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
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
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
                        fontWeight: FontWeight.w900,
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
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
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
                      color: AppTheme.gold,
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
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            question.correctAnswer,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w900,
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
                              Text(
                                isKu ? 'Şîrove' : 'Açıklama',
                                style: TextStyle(
                                  color: AppTheme.textSubColor(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
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
