import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/pronunciation_sheet.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';
import '../utils/number_format.dart';

/// Sözlük arama yönü: Kurmancî -> Türkçe (terim, biçim ve anlam) ya da
/// Türkçe -> Kurmancî (yalnız Türkçe anlamlar).
enum LexiconDirection { kuToTr, trToKu }

class LearnerLexiconScreen extends StatefulWidget {
  const LearnerLexiconScreen({this.initialQuery = '', super.key});

  /// Dokunmayla açılan balondan gelen arama metni (boşsa tüm sözlük).
  final String initialQuery;

  @override
  State<LearnerLexiconScreen> createState() => _LearnerLexiconScreenState();
}

class _LearnerLexiconScreenState extends State<LearnerLexiconScreen> {
  late String _query = widget.initialQuery;
  LexiconDirection _direction = LexiconDirection.kuToTr;
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final t = SahneTokens.of(context);
    final trToKu = _direction == LexiconDirection.trToKu;
    final results = trToKu
        ? LearnerLexicon.searchByMeaning(_query)
        : LearnerLexicon.search(_query);

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
                    controller: _controller,
                    hintText: context.t(
                      trToKu ? K.lexiconSearchHintTr : K.lexiconSearchHint,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  // Yön seçimi: iki çip yan yana sığmazsa alt satıra iner
                  // (320 dp + 2x yazıda taşmaz).
                  Semantics(
                    container: true,
                    label: context.t(K.lexiconDirection),
                    child: Wrap(
                      spacing: SahneSpace.x2,
                      runSpacing: SahneSpace.x1,
                      children: [
                        SahneRailChip(
                          key: const ValueKey('lexicon-dir-ku-tr'),
                          label: context.t(K.lexiconDirKuTr),
                          selected: !trToKu,
                          onTap: () => setState(
                            () => _direction = LexiconDirection.kuToTr,
                          ),
                        ),
                        SahneRailChip(
                          key: const ValueKey('lexicon-dir-tr-ku'),
                          label: context.t(K.lexiconDirTrKu),
                          selected: trToKu,
                          onTap: () => setState(
                            () => _direction = LexiconDirection.trToKu,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Text(
                    context.t(K.lexiconCount, {
                      'count': groupThousands(results.length),
                    }),
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
                        // Terimin cümlede görünen biçimleri (`malê`,
                        // `dizanim`): öğrenen sorudaki çekimli sözcüğü
                        // aratınca neden bu maddenin çıktığını görür.
                        final formsText = entry.forms.isEmpty
                            ? null
                            : '${context.t(K.lexiconForms)}: '
                                  '${entry.forms.join(', ')}';

                        // Ses düğmesi okuyucuya açık kalsın diye
                        // `ExcludeSemantics` yalnız metin sütununu sarar.
                        return SahneSurfaceCard(
                          key: ValueKey('lexicon-entry-${entry.id}'),
                          // Dokunulabilir kart etiketli olmalı (a11y matrisi):
                          // okuyucu "terim, anlam" duyar ve balonu açar.
                          semanticLabel: '${entry.termKu}. ${entry.meaningTr}.',
                          // Kart dokunulabilir: aramadan çıkan maddeyi balon
                          // olarak açar (ses, biçimler, kaynak ders).
                          onTap: () => showLexiconEntrySheet(
                            context,
                            entry,
                            showOpenInLexicon: false,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Semantics(
                                  container: true,
                                  label:
                                      '${entry.termKu}. ${entry.meaningTr}. '
                                      '${formsText == null ? '' : '$formsText. '}'
                                      '$sourceText. $categoryText.',
                                  child: ExcludeSemantics(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (formsText != null) ...[
                                          const SizedBox(height: SahneSpace.x1),
                                          Text(
                                            formsText,
                                            key: ValueKey(
                                              'lexicon-forms-${entry.id}',
                                            ),
                                            style: SahneType.caption.copyWith(
                                              color: t.tx3,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: SahneSpace.x2),
                                        Wrap(
                                          spacing: SahneSpace.x3,
                                          runSpacing: SahneSpace.x1,
                                          children: [
                                            Text(
                                              sourceText,
                                              style: SahneType.captionStrong
                                                  .copyWith(color: t.learnTx),
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
                              ),
                              LexiconSpeakButton(text: entry.termKu),
                              PronunciationButton(text: entry.termKu),
                              WordSaveButton(entryId: entry.id),
                            ],
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
