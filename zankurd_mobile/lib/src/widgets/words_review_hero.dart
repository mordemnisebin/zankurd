import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mistake_store.dart';
import '../data/tekrar_plani.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../screens/tekrar_screen.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'sahne/sahne.dart';
import 'zan_mascot.dart';

/// Kelimenin ustalık aşaması (Leitner kutusundan): 1 yeni, 2–3 pekişiyor,
/// 4–5 öğrenildi. Renk tek başına anlam taşımaz; aşamanın adı da yazılır.
enum WordStage {
  fresh(K.wordsStageNew),
  growing(K.wordsStageGrowing),
  learned(K.wordsStageLearned);

  const WordStage(this.labelKey);

  final String labelKey;

  static WordStage of(int box) => box <= 1
      ? fresh
      : box <= 3
      ? growing
      : learned;

  /// Aşamanın rengi: yeni nötr, pekişen açık öğrenme, öğrenilen dolu
  /// öğrenme yeşili.
  Color color(SahneTokens t) => switch (this) {
    fresh => t.tx3,
    growing => Color.lerp(t.learnFill, t.s1, 0.45)!,
    learned => t.learnFill,
  };
}

/// "Kelimelerim" ekranının kahramanı (vay katmanı 2B, 2026-10-29).
///
/// ## Niçin
///
/// GPT-6 Astra (Bêje/Duolingo kıyası, 6/10): "Tekrar, serbest pratik ve
/// kelime listesi benzer ağırlıkta; ilk yapılacak iş belirgin değil; küçük
/// halkaların anlamı belirsiz". Eskiden üstte ince bir "Tekrar · bugün N"
/// satırı vardı; dokunulabildiği bile belli değildi.
///
/// ## Düzen
///
/// Öğrenme tonlu kart: "Tekrar · bugün N" + kelime/soru dökümü, sağda rehber
/// maskot; altında listenin ustalık dağılımı (yeni / pekişiyor / öğrenildi,
/// sayılarıyla) ve ekranın TEK turuncu düğmesi: vadesi gelen varsa "Tekrara
/// başla" (tek oturum: kelime + yanlış soruları, [TekrarScreen]), yoksa
/// "Tüm kelimelerle çalış" ([onPractice]).
///
/// Plan [TekrarPlan] ile kurulur — öğrenme ekranındaki `TodaysReviewCard`
/// ile aynı kural, aynı oturum; burada yalnız sunum farklıdır.
class WordsReviewHero extends StatefulWidget {
  const WordsReviewHero({
    required this.repository,
    required this.store,
    required this.onPractice,
    this.mistakeStore,
    super.key,
  });

  final ZanKurdRepository repository;
  final WordListStore store;
  final MistakeStore? mistakeStore;

  /// Vadesi gelen yokken birincil düğme: serbest pratik (tüm kelimeler).
  final VoidCallback onPractice;

  @override
  State<WordsReviewHero> createState() => _WordsReviewHeroState();
}

class _WordsReviewHeroState extends State<WordsReviewHero> {
  TekrarPlan? _plan;
  bool _starting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant WordsReviewHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
      _refresh();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  Future<TekrarPlan> _build() async {
    final mistakes = widget.mistakeStore ?? await MistakeStore.load();
    return TekrarPlan.build(
      wordStore: widget.store,
      mistakeStore: mistakes,
      playable: widget.repository.playableQuestions,
    );
  }

  Future<void> _refresh() async {
    final g = ++_generation;
    try {
      final plan = await _build();
      if (mounted && g == _generation) setState(() => _plan = plan);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'words_review_hero');
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await Navigator.of(context).push(
        AppRoute.to(
          TekrarScreen(
            repository: widget.repository,
            isKu: context.isKu,
            wordStore: widget.store,
            mistakeStore: widget.mistakeStore,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
      await _refresh();
    }
  }

  String _breakdown(BuildContext context, TekrarPlan plan) {
    if (plan.dueWords > 0 && plan.dueQuestions > 0) {
      return context.t(K.tekrarBreakdown, {
        'words': groupThousands(plan.dueWords),
        'questions': groupThousands(plan.dueQuestions),
      });
    }
    return plan.dueWords > 0
        ? context.t(K.wordsCount, {'count': groupThousands(plan.dueWords)})
        : context.t(K.tekrarQuestionsOnly, {
            'count': groupThousands(plan.dueQuestions),
          });
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final plan = _plan;
    final ready = plan != null && plan.dueTotal > 0;
    // 2026-10-29 son kurul: "Tekrar · bugün 5" ile altındaki "3 kelime · 2
    // soru" iki ayrı sayı gibi okunuyordu; üst satır yalnız kapsamı söyler
    // ("Bugünkü tekrar"), dökümü başlık verir.
    final eyebrow = ready
        ? context.t(K.tekrarTodayTitle)
        : context.t(K.tekrarNone);
    final headline = ready
        ? _breakdown(context, plan)
        : context.t(K.tekrarNoneHint);
    final big = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          key: const ValueKey('my-words-hero-eyebrow'),
          style: SahneType.captionStrong.copyWith(color: t.learnTx),
        ),
        const SizedBox(height: 2),
        Text(
          headline,
          style: (ready ? SahneType.headline : SahneType.bodyStrong).copyWith(
            color: t.tx,
          ),
        ),
      ],
    );
    return SahneSurfaceCard(
      key: const ValueKey('my-words-review-card'),
      color: t.learnTint,
      edgeColor: Color.lerp(t.learnTint, t.learnFill, 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (big)
            text
          else
            Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: SahneSpace.x2),
                ZanMascot(
                  key: const ValueKey('my-words-hero-mascot'),
                  pose: ready ? ZanPose.guide : ZanPose.welcome,
                  size: 104,
                ),
              ],
            ),
          const SizedBox(height: SahneSpace.x3),
          WordMasteryBar(words: widget.store.words),
          const SizedBox(height: SahneSpace.x4),
          if (ready)
            // Anahtar eski tek tekrar girişinin sözleşmesi
            // (`todays-review-card`, word_screens_test): dokunuş aynı tek
            // oturumu açar.
            KeyedSubtree(
              key: const ValueKey('todays-review-card'),
              child: SahneButton.primary(
                label: context.t(K.wordsReviewStart),
                onPressed: _starting ? null : _start,
                loading: _starting,
                expand: true,
              ),
            )
          else
            SahneButton.primary(
              key: const ValueKey('my-words-hero-practice'),
              label: context.t(K.wordsPracticeStart),
              onPressed: widget.onPractice,
              expand: true,
            ),
        ],
      ),
    );
  }
}

/// Listenin ustalık dağılımı: üç renkli yığılmış çubuk + sayılı açıklama.
class WordMasteryBar extends StatelessWidget {
  const WordMasteryBar({required this.words, super.key});

  final List<SavedWord> words;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final counts = {for (final s in WordStage.values) s: 0};
    for (final w in words) {
      final s = WordStage.of(w.box);
      counts[s] = counts[s]! + 1;
    }
    final total = math.max(words.length, 1);
    final label = [
      for (final s in WordStage.values)
        '${groupThousands(counts[s]!)} ${context.t(s.labelKey)}',
    ].join(', ');
    return Semantics(
      key: const ValueKey('my-words-mastery-bar'),
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in WordStage.values.reversed)
                    if (counts[s]! > 0)
                      Expanded(
                        flex: (counts[s]! * 1000 / total).round(),
                        child: ColoredBox(color: s.color(t)),
                      ),
                  if (words.isEmpty) Expanded(child: ColoredBox(color: t.s3)),
                ],
              ),
            ),
          ),
          const SizedBox(height: SahneSpace.x2),
          Wrap(
            spacing: SahneSpace.x4,
            runSpacing: SahneSpace.x1,
            children: [
              for (final s in WordStage.values.reversed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: s.color(t),
                        shape: const CircleBorder(),
                      ),
                      child: const SizedBox.square(dimension: 10),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${groupThousands(counts[s]!)} ${context.t(s.labelKey)}',
                        style: SahneType.captionStrong.copyWith(color: t.tx),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
