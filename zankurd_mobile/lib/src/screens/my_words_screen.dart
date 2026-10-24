import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/word_list_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';
import 'word_drill_screen.dart';

/// "Kelimelerim": kullanıcının kaydettiği sözlük maddeleri, her kelimenin
/// Leitner kutusu ve "Bugünkü tekrar" kartı.
///
/// Liste [WordListStore]u dinler: kelime yer işaretiyle çıkarılınca satır
/// anında kaybolur; tekrar oturumundan dönünce sayılar tazelenir.
class MyWordsScreen extends StatefulWidget {
  const MyWordsScreen({this.store, super.key});

  /// Testlerde verilir; yoksa kullanıcının paylaşılan listesi.
  final WordListStore? store;

  @override
  State<MyWordsScreen> createState() => _MyWordsScreenState();
}

class _MyWordsScreenState extends State<MyWordsScreen> {
  WordListStore? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      store.addListener(_changed);
      if (!mounted) {
        store.removeListener(_changed);
        return;
      }
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'my_words_load');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store?.removeListener(_changed);
    super.dispose();
  }

  Future<void> _startReview() async {
    await Navigator.of(
      context,
    ).push(AppRoute(page: WordDrillScreen(store: _store)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final store = _store;
    final words = store?.words ?? const <SavedWord>[];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.wordsTitle))),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : words.isEmpty
            ? AppEmptyState(
                key: const ValueKey('my-words-empty'),
                icon: AppIcons.bookmark,
                title: context.t(K.wordsEmptyTitle),
                message: context.t(K.wordsEmptyBody),
              )
            : ListView(
                key: const ValueKey('my-words-list'),
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  SahneSpace.x6,
                ),
                children: [
                  _reviewCard(context, t, store!),
                  const SizedBox(height: SahneSpace.x4),
                  Text(
                    context.t(K.wordsCount, {'count': '${words.length}'}),
                    key: const ValueKey('my-words-count'),
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  for (final word in words) ...[
                    _wordCard(context, t, word, store),
                    const SizedBox(height: SahneSpace.x2),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _reviewCard(BuildContext context, SahneTokens t, WordListStore store) {
    final due = store.dueCount();
    return SahneSurfaceCard(
      key: const ValueKey('my-words-review-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.wordsReviewTitle),
            style: SahneType.captionStrong.copyWith(color: t.learnTx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            due > 0
                ? context.t(K.wordsDueCount, {'count': '$due'})
                : context.t(K.wordsDueNone),
            key: const ValueKey('my-words-due-count'),
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          if (due > 0) ...[
            const SizedBox(height: SahneSpace.x3),
            SahneButton.primary(
              key: const ValueKey('my-words-review-start'),
              label: context.t(K.start),
              expand: true,
              onPressed: _startReview,
            ),
          ],
        ],
      ),
    );
  }

  Widget _wordCard(
    BuildContext context,
    SahneTokens t,
    SavedWord word,
    WordListStore store,
  ) {
    final entry = LearnerLexicon.byId(word.entryId)!;
    final due = word.isDue(DateTime.now());
    final box = context.t(K.wordsBox, {'box': '${word.box}'});
    return SahneSurfaceCard(
      key: ValueKey('my-word-${entry.id}'),
      semanticLabel: '${entry.termKu}. ${entry.meaningTr}. $box.',
      onTap: () => showLexiconEntrySheet(context, entry),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.termKu,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    entry.meaningTr,
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Wrap(
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        box,
                        style: SahneType.captionStrong.copyWith(
                          color: t.learnTx,
                        ),
                      ),
                      if (due) SahneBadge(label: context.t(K.wordsDueBadge)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          LexiconSpeakButton(text: entry.termKu),
          WordSaveButton(entryId: entry.id, store: store),
        ],
      ),
    );
  }
}
