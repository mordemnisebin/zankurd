import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
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
    final t = SahneTokens.of(context);
    final results = LearnerLexicon.search(_query);

    // 2026-09-29 Şahnê: B iskeleti. Sayfa adı çubukta; arama
    // alanı temanın Kulis tonlu alanıdır (ayrı renk/köşe yazılmaz); her
    // kayıt bir yüzey kartı (L pah): terim Manşet, anlam Gövde, kaynak ve
    // konu açıklama satırında.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.lexiconTitle))),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x2,
                SahneSpace.page,
                SahneSpace.x3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SahneField.search(
                    key: const ValueKey('lexicon-search-field'),
                    hintText: context.t(K.lexiconSearchHint),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  Text(
                    context.t(K.lexiconCount, {'count': '${results.length}'}),
                    key: const ValueKey('lexicon-result-count'),
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
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
                        SahneSpace.page,
                        0,
                        SahneSpace.page,
                        SahneSpace.x6,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: SahneSpace.x2),
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
                            child: SahneSurfaceCard(
                              key: ValueKey('lexicon-entry-${entry.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.termKu,
                                    style: SahneType.headline.copyWith(
                                      color: t.tx,
                                    ),
                                  ),
                                  const SizedBox(height: SahneSpace.x1),
                                  Text(
                                    entry.meaningTr,
                                    style: SahneType.body.copyWith(
                                      color: t.tx2,
                                    ),
                                  ),
                                  const SizedBox(height: SahneSpace.x2),
                                  Wrap(
                                    spacing: SahneSpace.x3,
                                    runSpacing: SahneSpace.x1,
                                    children: [
                                      Text(
                                        sourceText,
                                        style: SahneType.captionStrong.copyWith(
                                          color: t.learnTx,
                                        ),
                                      ),
                                      Text(
                                        categoryText,
                                        style: SahneType.caption.copyWith(
                                          color: t.tx3,
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
