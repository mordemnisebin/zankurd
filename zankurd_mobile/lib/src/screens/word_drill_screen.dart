import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/word_list_store.dart';
import '../data/word_drill.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';

/// Kelime tekrarı oturumu: Kurmancî sözcük -> dört Türkçe anlamdan doğrusu.
///
/// Oturum, [WordListStore.sessionWords] ile vadesi gelmiş en çok 10
/// kelimedir ve açılışta SABİTLENİR: cevap verdikçe kelimenin vadesi
/// ileri gittiği için listeyi her adımda yeniden hesaplamak sırayı bozardı.
/// Her cevap hemen yerelde saklanır (yarıda çıkılırsa işlenenler kaybolmaz).
/// Yanlış cevaplanan kelime bu oturumda yeniden sorulmaz; 1. kutuya döner ve
/// yarın tekrar gelir. Ses düğmesi yalnız o ifade için kayıt/TTS varsa çizilir.
class WordDrillScreen extends StatefulWidget {
  const WordDrillScreen({this.store, this.random, super.key});

  /// Testlerde verilir; yoksa kullanıcının paylaşılan listesi.
  final WordListStore? store;

  /// Belirlenimli çeldirici sırası için (test, ekran turu).
  final math.Random? random;

  @override
  State<WordDrillScreen> createState() => _WordDrillScreenState();
}

class _WordDrillScreenState extends State<WordDrillScreen> {
  WordListStore? _store;
  List<WordReviewQuestion> _questions = const [];
  bool _loading = true;
  int _index = 0;
  int _correct = 0;
  String? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      final rng = widget.random ?? math.Random();
      final questions = <WordReviewQuestion>[];
      for (final word in store.sessionWords()) {
        final entry = LearnerLexicon.byId(word.entryId);
        if (entry != null) {
          questions.add(WordReviewQuestion.build(entry, random: rng));
        }
      }
      if (!mounted) return;
      setState(() {
        _store = store;
        _questions = questions;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_load');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _finished => _index >= _questions.length;
  bool get _answered => _picked != null;

  Future<void> _answer(String option) async {
    if (_answered || _finished) return;
    final question = _questions[_index];
    final correct = question.isCorrect(option);
    setState(() {
      _picked = option;
      if (correct) _correct++;
    });
    try {
      await _store?.recordReview(question.entry.id, correct: correct);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_record');
    }
  }

  void _next() {
    setState(() {
      _index++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.wordsReviewTitle))),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
            ? AppEmptyState(
                key: const ValueKey('word-review-empty'),
                icon: AppIcons.circleCheck,
                title: context.t(K.reviewsDone),
                message: context.t(K.wordsDueNone),
              )
            : _finished
            ? _buildDone(context, t)
            : _buildQuestion(context, t),
      ),
    );
  }

  Widget _buildDone(BuildContext context, SahneTokens t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SahneSpace.page),
      child: Column(
        key: const ValueKey('word-review-done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: SahneSpace.x6),
          Icon(AppIcons.circleCheck, size: 48, color: t.okTx),
          const SizedBox(height: SahneSpace.x3),
          Text(
            context.t(K.reviewsDone),
            textAlign: TextAlign.center,
            style: SahneType.headline.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.wordsReviewScore, {
              'correct': '$_correct',
              'total': '${_questions.length}',
            }),
            key: const ValueKey('word-review-score'),
            textAlign: TextAlign.center,
            style: SahneType.bodyStrong.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x5),
          SahneButton.primary(
            key: const ValueKey('word-review-finish'),
            label: context.t(K.finish),
            expand: true,
            arrow: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, SahneTokens t) {
    final question = _questions[_index];
    final entry = question.entry;
    final total = _questions.length;
    final isLast = _index == total - 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SahneSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SahneProgressBar(
            value: _index / total,
            trailing: '${_index + 1}/$total',
            semanticLabel: context.t(K.wordsReviewTitle),
          ),
          const SizedBox(height: SahneSpace.x5),
          Text(
            context.t(K.wordsReviewPrompt),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x2),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    entry.termKu,
                    key: const ValueKey('word-review-term'),
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
              ),
              LexiconSpeakButton(text: entry.termKu),
            ],
          ),
          const SizedBox(height: SahneSpace.x4),
          for (final option in question.options) ...[
            _option(context, t, question, option),
            const SizedBox(height: SahneSpace.x2),
          ],
          if (_answered) ...[
            const SizedBox(height: SahneSpace.x1),
            Semantics(
              liveRegion: true,
              child: Text(
                question.isCorrect(_picked!)
                    ? context.t(K.lessonListeningCorrect)
                    : context.t(K.lessonListeningWrong),
                key: const ValueKey('word-review-feedback'),
                style: SahneType.bodyStrong.copyWith(
                  color: question.isCorrect(_picked!) ? t.okTx : t.errTx,
                ),
              ),
            ),
            const SizedBox(height: SahneSpace.x3),
            SahneButton.primary(
              key: const ValueKey('word-review-next'),
              label: context.t(isLast ? K.finish : K.lessonRecallNext),
              expand: true,
              arrow: !isLast,
              onPressed: _next,
            ),
          ],
        ],
      ),
    );
  }

  /// Cevaptan sonra doğru şık yeşil, yanlış seçilen kırmızı tonludur; renk
  /// tek başına işaret olmasın diye geri bildirim metni ayrıca yazılır.
  Widget _option(
    BuildContext context,
    SahneTokens t,
    WordReviewQuestion question,
    String option,
  ) {
    final key = ValueKey(
      'word-review-option-${question.options.indexOf(option)}',
    );
    if (_answered && question.isCorrect(option)) {
      return SahneButton.tonal(
        buttonKey: key,
        label: option,
        tint: t.okTint,
        foreground: t.okTx,
        edge: t.okTx,
        expand: true,
        onPressed: null,
      );
    }
    if (_answered && option == _picked) {
      return SahneButton.tonal(
        buttonKey: key,
        label: option,
        tint: t.errTint,
        foreground: t.errTx,
        edge: t.errTx,
        expand: true,
        onPressed: null,
      );
    }
    return SahneButton.secondary(
      buttonKey: key,
      label: option,
      expand: true,
      onPressed: _answered ? null : () => _answer(option),
    );
  }
}
