import 'package:flutter/material.dart';

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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    for (final level in levels) ...[
                      _LevelCard(
                        level: level,
                        disabled: _loading,
                        isKu: ku,
                        onTap: () => _openLevel(level),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
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
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
          ),
        ),
      );
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
                color: gradient.colors.first.withValues(alpha: 0.25),
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

class _LevelCard extends StatefulWidget {
  const _LevelCard({
    required this.level,
    required this.disabled,
    required this.isKu,
    required this.onTap,
  });

  final QuizLevel level;
  final bool disabled;
  final bool isKu;
  final VoidCallback onTap;

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  bool _isPressed = false;

  Color _badgeColor(int n) => switch (n) {
    1 => AppTheme.correct,
    2 => const Color(0xFF2B5C8F),
    3 => AppTheme.gold,
    4 => AppTheme.primaryGradientStart,
    _ => AppTheme.violet,
  };

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(widget.level.number);

    return GestureDetector(
      onTapDown: widget.disabled
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.disabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            },
      onTapCancel: widget.disabled
          ? null
          : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16), // AppRadius.lg
            border: Border.all(
              color: _isPressed
                  ? badgeColor.withValues(alpha: 0.4)
                  : AppTheme.borderColor(context).withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
              if (_isPressed)
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.level.number}',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.level.title,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.level.questionCount} ${widget.isKu ? "pirs" : "soru"} · ${widget.isKu ? "Zehmetî" : "Zorluk"} ${widget.level.difficultyLabel}',
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: badgeColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
