import 'package:flutter/material.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../services/placement_scoring.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
        title: Text(context.t(K.placementTitle)),
        actions: [
          if (_result == null)
            TextButton(
              key: const ValueKey('placement-skip'),
              onPressed: _skip,
              child: Text(context.t(K.placementSkip)),
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
          context.t(K.placementNoQuestions),
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
                context.t(K.placementProgress, {
                  'index': '${_index + 1}',
                  'total': '${_questions.length}',
                }),
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
              // Soru düz metin olarak duruyordu: ekran renksiz kalıyor ve
              // uygulamanın quiz/hikâye kartlarıyla aynı dili konuşmuyordu
              // (2026-07-27). Sınav da bir sorudur; kartı da öyle olmalı.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppTheme.playGreen.withValues(alpha: 0.07),
                    AppTheme.surfaceHiColor(context),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppTheme.playGreen.withValues(alpha: 0.26),
                  ),
                ),
                child: Text(
                  question.prompt,
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (index, answer) in question.displayAnswers.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _AnswerButton(
                    index: index,
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
      PlacementLevel.destpek => (AppIcons.leaf, AppTheme.playGreen),
      PlacementLevel.navin => (AppIcons.arrowTrendUp, AppTheme.gold),
      PlacementLevel.pesketi => (AppIcons.medal, AppTheme.brand),
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
              context.t(K.placementYourLevel),
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
              context.t(K.placementScore, {
                'correct': '${result.correctCount}',
                'total': '${result.totalCount}',
              }),
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
                child: Text(context.t(K.start)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultHint(bool ku, PlacementLevel level) {
    final key = switch (level) {
      PlacementLevel.destpek => K.placementAdviceBasic,
      PlacementLevel.navin => K.placementAdviceMid,
      PlacementLevel.pesketi => K.placementAdviceAdvanced,
    };
    return Tr.forKu(key, ku);
  }
}

/// Sınav şıkkı — quiz şıklarıyla aynı dili konuşur.
///
/// Harf rozeti quizdekiyle aynı nötr tonu kullanır: renk burada da bir
/// ipucu taşımamalı (bkz. `answer_option_color_semantics_test`).
class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.index,
    required this.label,
    required this.onTap,
  });

  final int index;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + (index % 26));
    return Material(
      color: AppTheme.surfaceColor(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.8),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.answerOptionColors[index % 4],
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  letter,
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
