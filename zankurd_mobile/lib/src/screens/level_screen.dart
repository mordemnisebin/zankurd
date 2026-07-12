import 'package:flutter/material.dart';

import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_level.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'quiz_screen.dart';
import '../config/subcategory_config.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({
    required this.repository,
    required this.category,
    this.subCategory,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;
  final String? subCategory;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  bool _loading = false;
  Set<int> _playedLevels = const {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = await LevelProgressStore.load();
    if (!mounted) return;
    setState(() {
      _playedLevels = {
        for (var n = 1; n <= 5; n++)
          if (store.isPlayed(widget.category, widget.subCategory, n)) n,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final levels = widget.repository.levelsForCategory(widget.category);
    final catIndex = widget.repository.categories.indexOf(widget.category);
    final gradient = AppTheme.categoryGradient(catIndex >= 0 ? catIndex : 0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            // Üstte status bar payı bırakılmaz; hero en üste kadar uzanır.
            padding: EdgeInsets.zero,
            children: [
              _CategoryHero(
                category: widget.category,
                subCategory: widget.subCategory,
                gradient: gradient,
                isKu: ku,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: _LevelPath(
                  levels: levels,
                  disabled: _loading,
                  isKu: ku,
                  playedLevels: _playedLevels,
                  onOpen: _openLevel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLevel(QuizLevel level) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: level.category,
        difficultyMin: level.difficultyMin,
        difficultyMax: level.difficultyMax,
        subCategory: widget.subCategory,
        limit: level.questionCount,
      );
      if (!mounted) return;
      final room = widget.repository
          .createRoom(category: level.category)
          .copyWith(
            name:
                '${level.category} ${level.number}. ${context.isKu ? "Ast" : "Seviye"}',
            questionCount: questions.length,
          );
      final result = await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
          ),
        ),
      );
      // Yoldaki düğümü yalnız quiz gerçekten bitince işaretle: sonuç ekranı
      // skor haritasıyla döner; yarıda bırakma null döner ve tik almamalı.
      if (result is Map) {
        final store = await LevelProgressStore.load();
        await store.markPlayed(
          widget.category,
          widget.subCategory,
          level.number,
        );
      }
      await _loadProgress();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'level questions load failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu
                ? 'Pirsên vê astê neyên barkirin.'
                : 'Bu seviyenin soruları yüklenemedi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.category,
    this.subCategory,
    required this.gradient,
    required this.isKu,
  });

  final String category;
  final String? subCategory;
  final LinearGradient gradient;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final color1 = Colors.white.withValues(alpha: 0.08);
    final color2 = Colors.white.withValues(alpha: 0.03);

    String title = CategoryNames.localized(category, isKu);
    String subtitle = isKu
        ? 'Ji hêsan ber bi dijwar ve, xalên xwe bicivîne.'
        : 'Kolaydan zora doğru ilerle, puan topla.';

    if (subCategory != null) {
      final list = SubcategoryConfig.subcategories[category] ?? const [];
      final sub = list.firstWhere(
        (element) => element.id == subCategory,
        orElse: () => const SubcategoryInfo(
          id: '',
          nameKu: '',
          nameTr: '',
          descriptionKu: '',
          descriptionTr: '',
        ),
      );
      if (sub.id.isNotEmpty) {
        title = isKu
            ? '${CategoryNames.localized(category, isKu)} · ${sub.nameKu}'
            : '${CategoryNames.localized(category, isKu)} · ${sub.nameTr}';
        subtitle = isKu ? sub.descriptionKu : sub.descriptionTr;
      }
    }

    return Hero(
      tag: 'category_hero_${category}_$subCategory',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          height: 200 + topInset,
          decoration: BoxDecoration(
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Soft Glow 1
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [color1, color1.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // Soft Glow 2
              Positioned(
                left: -50,
                bottom: -50,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [color2, color2.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // Dekoratif daire
              Positioned(
                right: 20,
                bottom: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kademe rengi: her seviyenin yol üzerindeki kimliği.
Color _levelColor(int n) => switch (n) {
  1 => AppTheme.correct,
  2 => const Color(0xFF2B5C8F),
  3 => AppTheme.gold,
  4 => AppTheme.primaryGradientStart,
  _ => AppTheme.violet,
};

/// Seviyeleri düz liste yerine serpantin bir öğrenme yolunda gösterir:
/// düğümler sağa-sola salınır, aralarını kademe-renkli kesikli patika bağlar.
class _LevelPath extends StatelessWidget {
  const _LevelPath({
    required this.levels,
    required this.disabled,
    required this.isKu,
    required this.playedLevels,
    required this.onOpen,
  });

  final List<QuizLevel> levels;
  final bool disabled;
  final bool isKu;
  final Set<int> playedLevels;
  final ValueChanged<QuizLevel> onOpen;

  /// Yoldaki "sıradaki" düğüm: oynanmamış ilk seviye.
  int? get _nextNumber {
    for (final level in levels) {
      if (!playedLevels.contains(level.number)) return level.number;
    }
    return null;
  }

  static const _rowHeight = 150.0;
  static const _nodeSize = 76.0;
  static const _xFractions = [0.26, 0.74, 0.30, 0.70, 0.34];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = [
          for (var i = 0; i < levels.length; i++)
            Offset(
              width * _xFractions[i % _xFractions.length],
              i * _rowHeight + _nodeSize / 2,
            ),
        ];
        return SizedBox(
          height: levels.length * _rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PathPainter(
                      centers: centers,
                      colors: [
                        for (final level in levels) _levelColor(level.number),
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < levels.length; i++)
                Positioned(
                  left: (centers[i].dx - 90).clamp(0.0, width - 180),
                  top: i * _rowHeight,
                  width: 180,
                  child: _LevelNode(
                    level: levels[i],
                    disabled: disabled,
                    isKu: isKu,
                    played: playedLevels.contains(levels[i].number),
                    isNext: levels[i].number == _nextNumber,
                    onTap: () => onOpen(levels[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Yol üzerindeki tek seviye düğümü: gradyan daire + başlık/yıldız etiketi.
class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.disabled,
    required this.isKu,
    required this.played,
    required this.isNext,
    required this.onTap,
  });

  final QuizLevel level;
  final bool disabled;
  final bool isKu;

  /// Bu seviye daha önce oynandı (altın halka + tik rozeti).
  final bool played;

  /// Yolda sıradaki seviye (güçlü parıltı — "buradan devam et").
  final bool isNext;
  final VoidCallback onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(widget.level.number);
    final isFinal = widget.level.number >= 5;

    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: widget.level.title,
      child: GestureDetector(
        onTapDown: widget.disabled
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.disabled
            ? null
            : (_) {
                setState(() => _pressed = false);
                widget.onTap();
              },
        onTapCancel: widget.disabled
            ? null
            : () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color,
                          Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.24),
                            color,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: widget.played
                            ? AppTheme.gold
                            : Colors.white.withValues(
                                alpha: widget.isNext ? 0.9 : 0.55,
                              ),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: widget.isNext ? 0.32 : 0.20,
                          ),
                          blurRadius: widget.isNext ? 16 : 10,
                          offset: const Offset(0, 5),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: isFinal
                        ? const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 34,
                          )
                        : Text(
                            '${widget.level.number}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                  ),
                  if (widget.played)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.level.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DifficultyStars(
                          filled: widget.level.difficultyMax.clamp(1, 5),
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.level.questionCount} ${widget.isKu ? "pirs" : "soru"}',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Düğüm merkezlerini kademe-renkli, kesikli S-kavisleriyle bağlar.
class _PathPainter extends CustomPainter {
  _PathPainter({required this.centers, required this.colors});

  final List<Offset> centers;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final midY = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          colors[i],
          colors[i + 1],
          0.5,
        )!.withValues(alpha: 0.55);
      _drawDashed(canvas, path, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 12.0;
    const gap = 9.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dash).clamp(0.0, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.centers != centers || oldDelegate.colors != colors;
}

/// Zorluğu metin yerine 5'li yıldız dizisiyle gösterir.
class _DifficultyStars extends StatelessWidget {
  const _DifficultyStars({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1.5),
            child: Icon(
              i <= filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13,
              color: i <= filled
                  ? color
                  : AppTheme.textMutedColor(context).withValues(alpha: 0.45),
            ),
          ),
      ],
    );
  }
}
