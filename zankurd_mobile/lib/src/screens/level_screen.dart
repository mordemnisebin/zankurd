import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_level.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'quiz_screen.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({
    required this.repository,
    required this.category,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: ListView(
            children: [
              _CategoryHero(
                category: widget.category,
                gradient: gradient,
                isKu: ku,
                onBack: () => Navigator.of(context).pop(),
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
        MaterialPageRoute(
          builder: (_) => QuizScreen(
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
    required this.gradient,
    required this.isKu,
    required this.onBack,
  });

  final String category;
  final LinearGradient gradient;
  final bool isKu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  CategoryNames.localized(category, isKu),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isKu
                      ? 'Ji hêsan ber bi dijwar ve, xalên xwe bicivîne.'
                      : 'Kolaydan zora doğru ilerle, puan topla.',
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
    );
  }
}

class _LevelCard extends StatelessWidget {
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

  Color _badgeColor(int n) => switch (n) {
    1 => AppTheme.correct,
    2 => const Color(0xFF4059AD),
    3 => AppTheme.gold,
    4 => AppTheme.accent,
    _ => AppTheme.violet,
  };

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(level.number);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                '${level.number}',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w900,
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
                    level.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${level.questionCount} ${isKu ? "pirs" : "soru"} · ${isKu ? "Zehmetî" : "Zorluk"} ${level.difficultyLabel}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
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
    );
  }
}
