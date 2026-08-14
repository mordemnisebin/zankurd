import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({required this.records, required this.room, super.key});

  final List<AnswerRecord> records;
  final GameRoom room;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isFlashcardMode = false;

  @override
  Widget build(BuildContext context) {
    final correct = widget.records.where((r) => r.isCorrect).length;
    final wrong = widget.records
        .where((r) => !r.isCorrect && !r.isUnanswered)
        .length;
    final empty = widget.records.where((r) => r.isUnanswered).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.t(K.answersTitle))),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: widget.records.isEmpty
              ? AppEmptyState(
                  icon: AppIcons.squareCheck,
                  title: context.t(K.answersEmptyTitle),
                  message: context.t(K.answersEmptyBody),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  children: [
                    ScreenIdentityHeader(
                      title: context.t(K.summaryTitle),
                      subtitle: context.t(K.reviewSummaryLine, {
                        'correct': '$correct',
                        'wrong': '$wrong',
                        'empty': '$empty',
                      }),
                      accent: AppTheme.cyan,
                      icon: AppIcons.squareCheck,
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryStrip(correct: correct, wrong: wrong, empty: empty),
                    const SizedBox(height: 12),
                    // View Mode Toggle Switcher
                    Center(
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(context.t(K.listView)),
                            icon: const Icon(AppIcons.barsStaggered, size: 16),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(context.t(K.flashcards)),
                            icon: const Icon(AppIcons.layerGroup, size: 16),
                          ),
                        ],
                        selected: {_isFlashcardMode},
                        onSelectionChanged: (Set<bool> selection) {
                          setState(() {
                            _isFlashcardMode = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isFlashcardMode)
                      _FlashcardView(records: widget.records)
                    else
                      for (var i = 0; i < widget.records.length; i++) ...[
                        _ReviewCard(record: widget.records[i], index: i),
                        if (i != widget.records.length - 1)
                          const SizedBox(height: 14),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.correct,
    required this.wrong,
    required this.empty,
  });

  final int correct;
  final int wrong;
  final int empty;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            color: AppTheme.correct,
            icon: AppIcons.circleCheck,
            value: '$correct',
            label: context.t(K.correct),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.wrong,
            icon: AppIcons.circleXmark,
            value: '$wrong',
            label: context.t(K.wrong),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.gold,
            icon: AppIcons.hourglass,
            value: '$empty',
            label: context.t(K.blank),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.record, required this.index});

  final AnswerRecord record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = record.isCorrect;
    final bool isUnanswered = record.isUnanswered;
    // Yazılmış açıklama > override > şablon eleme > kural motoru.
    //
    // Burası doğrudan kural motoruna gidiyordu ve sorunun elle yazılmış
    // Kurmancî açıklamasını hiç görmüyordu: Kurmancî turda özet
    // "Şirove: <Türkçe cümle>" gösteriyordu. Motor yedektir, kaynak
    // değil (2026-07-27).
    final isKu = context.isKu;
    final authored = isKu ? record.explanationKu : record.explanationTr;
    final String explanationText =
        (authored != null &&
            authored.trim().isNotEmpty &&
            !isTemplateExplanation(authored))
        ? authored
        : resolveRawExplanation(
            id: record.id,
            explanation: record.explanation,
            isKu: isKu,
          );

    final Color headerColor;
    final IconData headerIcon;
    final String headerText;

    if (isUnanswered) {
      headerColor = AppTheme.gold;
      headerIcon = AppIcons.circleQuestion;
      headerText = context.t(K.blankBadge);
    } else if (isCorrect) {
      headerColor = AppTheme.correct;
      headerIcon = AppIcons.circleCheck;
      headerText = context.t(K.correctBadge);
    } else {
      headerColor = AppTheme.wrong;
      headerIcon = AppIcons.circleXmark;
      headerText = context.t(K.wrongBadge);
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Başlık şeridinin zemini rengin kendi %14'lük tonu; ham
                // renk orada okunmuyordu ("DOĞRU" 2.59:1, "YANLIŞ" 3.13:1).
                Icon(
                  headerIcon,
                  color: AppColors.onAccentTint(context, headerColor),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: TextStyle(
                    color: AppColors.onAccentTint(context, headerColor),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgOf(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.t(K.questionIndex, {'index': '${index + 1}'}),
                    style: TextStyle(
                      color: AppTheme.textSubColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: record.imageUrl!.startsWith('asset://')
                        ? Image.asset(
                            record.imageUrl!.replaceFirst('asset://', ''),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          )
                        : CachedNetworkImage(
                            // Gözden geçirme kartı küçük; tam çözünürlük
                            // belleğe açmak gereksiz (2026-07-31).
                            memCacheWidth: 720,
                            imageUrl: record.imageUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: double.infinity,
                              height: 180,
                              color: AppTheme.surfaceHiColor(context),
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brand.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: double.infinity,
                              height: 180,
                              color: AppTheme.surfaceHiColor(context),
                              alignment: Alignment.center,
                              child: Icon(
                                AppIcons.image,
                                color: AppTheme.textMutedColor(context),
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  record.prompt,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ...record.answers.map((answer) {
                  final isThisSelected = answer == record.selectedAnswer;
                  final isThisCorrect = answer == record.correctAnswer;

                  final Color bgColor;
                  final Color textColor;
                  IconData? icon;

                  if (isThisCorrect) {
                    bgColor = AppTheme.correct.withValues(alpha: 0.14);
                    // Ham yeşil kendi %14'lük tonunda 2.59:1 ölçüldü;
                    // doğru şık silik görünüyordu (2026-07-27).
                    textColor = AppColors.onAccentTint(
                      context,
                      AppTheme.correct,
                    );
                    icon = AppIcons.check;
                  } else if (isThisSelected) {
                    bgColor = AppTheme.wrong.withValues(alpha: 0.14);
                    textColor = AppColors.onAccentTint(context, AppTheme.wrong);
                    icon = AppIcons.xmark;
                  } else {
                    bgColor = AppTheme.surfaceHiColor(context);
                    textColor = AppTheme.textMutedColor(context);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: icon != null
                            ? textColor
                            : AppTheme.borderColor(context),
                        width: icon != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            answer,
                            style: TextStyle(
                              color: icon != null
                                  ? textColor
                                  : AppTheme.textSubColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, color: textColor, size: 20),
                        ],
                      ],
                    ),
                  );
                }),
                if (explanationText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.violet.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.lightbulb,
                          color: AppColors.onAccentTint(
                            context,
                            AppTheme.violet,
                          ),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            explanationText,
                            style: TextStyle(
                              color: AppTheme.textSubColor(context),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardView extends StatefulWidget {
  const _FlashcardView({required this.records});

  final List<AnswerRecord> records;

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  void _nextCard() {
    if (_currentIndex < widget.records.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) return const SizedBox.shrink();
    final record = widget.records[_currentIndex];
    final isKu = context.isKu;
    final explanationText = isKu
        ? (record.explanationKu ?? record.explanation)
        : (record.explanationTr ?? record.explanation);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.records.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                Tr.forKu(_isFlipped ? K.flashcardBack : K.flashcardFront, isKu),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSubColor(context),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _isFlipped = !_isFlipped),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final rotate = Tween(begin: math.pi, end: 0.0).animate(animation);
              return AnimatedBuilder(
                animation: rotate,
                child: child,
                builder: (context, child) {
                  final isUnder = (ValueKey(_isFlipped) != child?.key);
                  var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                  tilt *= isUnder ? -1.0 : 1.0;
                  final value = isUnder
                      ? math.min(rotate.value, math.pi / 2)
                      : rotate.value;
                  return Transform(
                    transform: Matrix4.rotationY(value)..setEntry(3, 2, tilt),
                    alignment: Alignment.center,
                    child: child,
                  );
                },
              );
            },
            child: _isFlipped
                ? _buildBackCard(context, record, explanationText)
                : _buildFrontCard(context, record),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _currentIndex > 0 ? _prevCard : null,
              icon: const Icon(AppIcons.arrowLeft, size: 16),
              label: Text(context.t(K.back)),
            ),
            OutlinedButton.icon(
              onPressed: _currentIndex < widget.records.length - 1
                  ? _nextCard
                  : null,
              icon: const Icon(AppIcons.arrowRight, size: 16),
              label: Text(context.t(K.next)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrontCard(BuildContext context, AnswerRecord record) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  // Kategori kimliği veri katmanında Kurmancî sabittir
                  // (bkz. `CategoryNames`); Türkçe turda ham "Ziman" gibi
                  // çevrilmeden basılıyordu (2026-08-14 denetimi).
                  CategoryNames.localized(record.category, context.isKu),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cyan,
                  ),
                ),
              ),
              const Icon(AppIcons.layerGroup, size: 18, color: AppTheme.cyan),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            record.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.arrowsRotate, size: 14, color: AppTheme.cyan),
              const SizedBox(width: 6),
              Text(
                context.t(K.cevabiGormekIcinDokun),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(
    BuildContext context,
    AnswerRecord record,
    String explanationText,
  ) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.correct.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.circleCheck,
                color: AppTheme.correct,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.t(K.dogruCevap),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.correct,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.correct.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.correct.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              record.correctAnswer,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
          if (explanationText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  AppIcons.lightbulb,
                  color: AppTheme.violet,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  // Aynı kusur: Kurmancî yuvada Türkçe kelime yanına
                  // ilişiktirilmişti ("Ravahî / Açıklama:").
                  context.t(K.aciklama),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.violet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              explanationText,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSubColor(context),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
