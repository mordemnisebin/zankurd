import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/learner_lexicon.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../utils/app_route.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/todays_review_card.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';
import 'word_drill_screen.dart';

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
                  _practiceSection(context, t, words),
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

  /// Serbest pratik (Pro): vadesini beklemeden tüm kelimeler ya da yalnız
  /// zorlandıkların (1. kutu). Kutular değişmez (bkz.
  /// [WordDrillScreen.practice]). Yalnız aboneye görünür: kilitli bir satış
  /// satırı paywall'a üçüncü bir giriş olurdu ve App Review notlarındaki yol
  /// tarifini bozardı (`subscription_disclosure_test`). Fayda paywall'da
  /// tanıtılır.
  ///
  /// 2026-10-25 kurul (Codex + Gemini 4 Argon): Pro yalnız seri koruma
  /// veriyordu; fazladan joker sıralamaya XP taşıyacağı için reddedildi,
  /// öğrenme değeri olan bu fayda seçildi.
  Widget _practiceSection(
    BuildContext context,
    SahneTokens t,
    List<SavedWord> words,
  ) {
    final weak = [
      for (final w in words)
        if (w.box <= 1) w,
    ];
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        if (!premium.isPremium) return const SizedBox.shrink();
        Widget row({
          required Key key,
          required String title,
          required List<SavedWord> pool,
        }) {
          return SahneListRow.icon(
            key: key,
            icon: AppIcons.play,
            role: SahneRole.learn,
            title: title,
            subtitle: '${pool.length}',
            trailing: const SahneBadge(label: 'Pro', tone: SahneBadgeTone.gold),
            chevron: true,
            onTap: () => _startPractice(context, pool),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x4),
          child: Column(
            key: const ValueKey('my-words-practice'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(K.wordsPracticeTitle),
                style: SahneType.bodyStrong.copyWith(color: t.tx),
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                context.t(K.wordsPracticeHint),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x2),
              SahneListGroup(
                children: [
                  row(
                    key: const ValueKey('my-words-practice-all'),
                    title: context.t(K.wordsPracticeAll),
                    pool: words,
                  ),
                  if (weak.isNotEmpty)
                    row(
                      key: const ValueKey('my-words-practice-weak'),
                      title: context.t(K.wordsPracticeWeak),
                      pool: weak,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Oturum en çok [_practiceCap] kelime; her açılışta karışık.
  static const _practiceCap = 15;

  Future<void> _startPractice(
    BuildContext context,
    List<SavedWord> pool,
  ) async {
    final picked = [...pool]..shuffle(math.Random());
    await Navigator.of(context).push(
      AppRoute.to(
        WordDrillScreen(
          store: _store,
          words: picked.take(_practiceCap).toList(),
          practice: true,
        ),
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
