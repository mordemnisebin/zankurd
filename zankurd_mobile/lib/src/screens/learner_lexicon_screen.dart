import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state.dart';
import '../widgets/zk_back_button.dart';

class LearnerLexiconScreen extends StatefulWidget {
  const LearnerLexiconScreen({super.key});

  @override
  State<LearnerLexiconScreen> createState() => _LearnerLexiconScreenState();
}

class _LearnerLexiconScreenState extends State<LearnerLexiconScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final results = LearnerLexicon.search(_query);

    return Scaffold(
      appBar: zkAppBar(context, title: Text(context.t(K.lexiconTitle))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.lexiconSubtitle),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('lexicon-search-field'),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.t(K.lexiconSearchHint),
                      prefixIcon: const Icon(AppIcons.magnifyingGlass),
                      filled: true,
                      fillColor: AppTheme.surfaceColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                          color: AppTheme.borderColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                          color: AppTheme.borderColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.t(K.lexiconCount, {'count': '${results.length}'}),
                    key: const ValueKey('lexicon-result-count'),
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? AppEmptyState(
                      key: const ValueKey('lexicon-empty-state'),
                      icon: AppIcons.magnifyingGlass,
                      title: context.t(K.lexiconEmptyTitle),
                      message: context.t(K.lexiconEmptyBody),
                    )
                  : ListView.separated(
                      key: const ValueKey('lexicon-results-list'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.xl,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppTheme.borderColor(
                          context,
                        ).withValues(alpha: 0.55),
                      ),
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        final source = LearnerLexicon.sourceFor(entry);
                        final sourceTitle = isKu
                            ? source.titleKu
                            : source.titleTr;
                        final category = isKu
                            ? source.categoryKu
                            : source.categoryTr;
                        final sourceText =
                            '${context.t(K.lexiconSource)}: $sourceTitle';
                        final categoryText =
                            '${context.t(K.lexiconCategory)}: $category';

                        return Semantics(
                          container: true,
                          label:
                              '${entry.termKu}. ${entry.meaningTr}. '
                              '$sourceText. $categoryText.',
                          child: ExcludeSemantics(
                            child: Padding(
                              key: ValueKey('lexicon-entry-${entry.id}'),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.termKu,
                                    style: AppTypography.heading2.copyWith(
                                      color: AppTheme.textPrimaryColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.meaningTr,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppTheme.textSubColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        sourceText,
                                        style: AppTypography.caption.copyWith(
                                          color: AppTheme.textMutedColor(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        categoryText,
                                        style: AppTypography.caption.copyWith(
                                          color: AppTheme.textMutedColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
