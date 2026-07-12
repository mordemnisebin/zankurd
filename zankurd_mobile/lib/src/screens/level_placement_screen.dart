import 'package:flutter/material.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../services/placement_scoring.dart';
import '../theme/app_theme.dart';

/// Kısa, baskısız seviye belirleme sınavı.
///
/// Süre, skor, joker, coin veya yarışma baskısı yoktur; ses de yoktur.
/// Kullanıcı istediğinde "Şimdilik geç" diyebilir. Sonuç [PlacementStore]'a
/// sürümlü olarak yazılır ve öğrenme yolundaki önerilen başlangıç noktasını
/// belirler. Yarıda kapatılırsa hiçbir veri yazılmaz (bozulma olmaz).
class LevelPlacementScreen extends StatefulWidget {
  const LevelPlacementScreen({
    required this.repository,
    this.onFinished,
    this.questionCount = 12,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Sınav bittiğinde belirlenen seviye; "Şimdilik geç" ile null döner.
  final void Function(PlacementLevel? level)? onFinished;
  final int questionCount;

  @override
  State<LevelPlacementScreen> createState() => _LevelPlacementScreenState();
}

class _LevelPlacementScreenState extends State<LevelPlacementScreen> {
  late final List<QuizQuestion> _questions;
  final List<PlacementItem> _answers = [];
  int _index = 0;
  PlacementResult? _result;

  @override
  void initState() {
    super.initState();
    _questions = PlacementScoring.selectQuestions(
      widget.repository.questions,
      count: widget.questionCount,
    );
  }

  @visibleForTesting
  QuizQuestion get currentQuestionForTest => _questions[_index];

  void _answer(QuizQuestion question, String choice) {
    _answers.add(
      PlacementItem(
        difficulty: question.difficulty,
        correct: choice == question.correctAnswer,
      ),
    );
    if (_index + 1 >= _questions.length) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    final result = PlacementScoring.evaluate(
      _answers,
      totalQuestions: _questions.length,
    );
    final store = await PlacementStore.load();
    await store.saveResult(result.level);
    if (mounted) setState(() => _result = result);
  }

  Future<void> _skip() async {
    final store = await PlacementStore.load();
    await store.markSkipped();
    widget.onFinished?.call(null);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      appBar: AppBar(
        title: Text(ku ? 'Asta xwe diyar bike' : 'Seviyeni belirle'),
        actions: [
          if (_result == null)
            TextButton(
              key: const ValueKey('placement-skip'),
              onPressed: _skip,
              child: Text(ku ? 'Niha derbas be' : 'Şimdilik geç'),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: _questions.isEmpty
              ? _buildUnavailable(context, ku)
              : (_result != null
                    ? _buildResult(context, ku, _result!)
                    : _buildQuestion(context, ku)),
        ),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context, bool ku) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          ku
              ? 'Ji bo naha pirs tune. Tu dikarî dûre biceribînî.'
              : 'Şimdilik soru yok. Daha sonra deneyebilirsin.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, bool ku) {
    final question = _questions[_index];
    final progress = (_index + 1) / _questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ku
                    ? 'Pirs ${_index + 1}/${_questions.length}'
                    : 'Soru ${_index + 1}/${_questions.length}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.borderColor(
                    context,
                  ).withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.playGreen),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              Text(
                question.prompt,
                style: AppTypography.heading1.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final answer in question.displayAnswers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _AnswerButton(
                    label: answer,
                    onTap: () => _answer(question, answer),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, bool ku, PlacementResult result) {
    final level = result.level;
    final (icon, tint) = switch (level) {
      PlacementLevel.destpek => (Icons.eco_rounded, AppTheme.playGreen),
      PlacementLevel.navin => (Icons.trending_up_rounded, AppTheme.gold),
      PlacementLevel.pesketi => (
        Icons.workspace_premium_rounded,
        AppTheme.brandOrange,
      ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.16),
                border: Border.all(
                  color: tint.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(icon, color: tint, size: 40),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              ku ? 'Asta te' : 'Seviyen',
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ku ? level.labelKu : level.labelTr,
              key: const ValueKey('placement-result-level'),
              style: AppTypography.display.copyWith(color: tint),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ku
                  ? '${result.correctCount}/${result.totalCount} rast'
                  : '${result.correctCount}/${result.totalCount} doğru',
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _resultHint(ku, level),
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('placement-continue'),
                onPressed: () {
                  widget.onFinished?.call(level);
                  Navigator.of(context).maybePop();
                },
                child: Text(ku ? 'Dest pê bike' : 'Başla'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultHint(bool ku, PlacementLevel level) {
    return switch (level) {
      PlacementLevel.destpek =>
        ku
            ? 'Em ê ji bingehê dest pê bikin. Ne xem e, gav bi gav!'
            : 'Temellerden başlayacağız. Merak etme, adım adım!',
      PlacementLevel.navin =>
        ku
            ? 'Bingeha te baş e. Em ê hînê pêş de bibin.'
            : 'Temelin iyi. Biraz daha ileri götüreceğiz.',
      PlacementLevel.pesketi =>
        ku
            ? 'Zana! Em ê rasterast mijarên pêşketî pêşniyar bikin.'
            : 'Harika! Doğrudan ileri konuları önereceğiz.',
    };
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceHiColor(context),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodyLarge.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
