import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/todays_review_card.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';

/// "Kelimelerim": kullanıcının kaydettiği sözlük maddeleri, her kelimenin
/// Leitner kutusu ve tek "Tekrar · bugün N" girişi.
///
/// Tekrar başlatma burada ayrı bir mekanizma DEĞİLDİR: kart, öğrenme
/// ekranındakiyle aynı [TodaysReviewCard]dır (kelime + yanlış sorusu tek
/// oturum). Eskiden burada yalnız kelimeleri açan ikinci bir "Bugünkü
/// tekrar" kartı vardı; kullanıcı ikisini ayıramıyordu (2026-10-24).
///
/// Liste [WordListStore]u dinler: kelime yer işaretiyle çıkarılınca satır
/// anında kaybolur; tekrar oturumundan dönünce sayılar tazelenir.
class MyWordsScreen extends StatefulWidget {
  const MyWordsScreen({required this.repository, this.store, super.key});

  /// Tekrar oturumunun soru aşaması için.
  final ZanKurdRepository repository;

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
    return SahneSurfaceCard(
      key: const ValueKey('my-words-review-card'),
      child: TodaysReviewCard(
        repository: widget.repository,
        isKu: context.isKu,
        wordStore: store,
        refreshSignal: store,
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
