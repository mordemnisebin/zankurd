import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/quiz_level.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
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
    final levels = widget.repository.levelsForCategory(widget.category);

    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            _CategoryHero(category: widget.category),
            const SizedBox(height: 16),
            for (final level in levels) ...[
              _LevelTile(
                level: level,
                disabled: _loading,
                onTap: () => _openLevel(level),
              ),
              const SizedBox(height: 10),
            ],
          ],
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
            name: '${level.category} ${level.number}. Seviye',
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu seviyenin soruları yüklenemedi.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: AppTheme.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_outlined, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            category,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kolaydan zora doğru ilerle, puan topla ve liderliğe yüksel.',
            style: TextStyle(color: Color(0xFFE6F1EB), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.disabled,
    required this.onTap,
  });

  final QuizLevel level;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _levelColor(level.number),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${level.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level.questionCount} soru · Zorluk ${level.difficultyLabel}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(int number) {
    return switch (number) {
      1 => AppTheme.green,
      2 => const Color(0xFF4059AD),
      3 => const Color(0xFFBD7B2B),
      4 => AppTheme.red,
      _ => AppTheme.brown,
    };
  }
}
