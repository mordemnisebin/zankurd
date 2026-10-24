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
import 'quiz/quiz_option_tile.dart';

/// Kelime tekrarı oturumu: Kurmancî sözcük -> dört Türkçe anlamdan doğrusu.
///
/// Oturum, [WordListStore.sessionWords] ile vadesi gelmiş en çok 10
/// kelimedir ve açılışta SABİTLENİR: cevap verdikçe kelimenin vadesi
/// ileri gittiği için listeyi her adımda yeniden hesaplamak sırayı bozardı.
/// Her cevap hemen yerelde saklanır (yarıda çıkılırsa işlenenler kaybolmaz).
/// Yanlış cevaplanan kelime bu oturumda yeniden sorulmaz; 1. kutuya döner ve
/// yarın tekrar gelir. Ses düğmesi yalnız o ifade için kayıt/TTS varsa çizilir.
class WordDrillScreen extends StatefulWidget {
  const WordDrillScreen({
    this.store,
    this.random,
    this.words,
    this.onDone,
    this.doneLabel,
    super.key,
  });

  /// Tek "Tekrar" oturumu kelime kısmını kendi seçtiği kelimelerle açar
  /// ([TekrarPlan]); verilmezse eski davranış: vadesi gelen en çok 10.
  /// Kutu/vade kuralı değişmez: her cevap yine `recordReview`dan geçer.
  final List<SavedWord>? words;

  /// Bitiş düğmesi ekranı kapatmak yerine bunu çağırır (Tekrar oturumunda
  /// sıradaki aşama: sorular).
  final VoidCallback? onDone;

  /// Bitiş düğmesinin yazısı; verilmezse "Tamamla".
  final String? doneLabel;

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
  bool _saveFailed = false;

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
      for (final word in widget.words ?? store.sessionWords()) {
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
    // Kayıt yazılamadıysa ilerleme DURUR: yoksa kullanıcı "tekrar ettim"
    // sanır, kutu/vade diske geçmez ve kelime yarın yine aynı kutuda gelir.
    var saved = true;
    try {
      final store = _store;
      if (store != null && store.contains(question.entry.id)) {
        saved = await store.recordReview(question.entry.id, correct: correct);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_record');
      saved = false;
    }
    if (mounted && !saved) setState(() => _saveFailed = true);
  }

  /// Bellekteki cevap zaten işlendi; yalnız diske yazmayı yeniden dener
  /// (cevabı ikinci kez saymaz).
  Future<void> _retrySave() async {
    var saved = false;
    try {
      saved = await (_store?.persist() ?? Future.value(true));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_retry');
    }
    if (mounted && saved) setState(() => _saveFailed = false);
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
      appBar: zkAppBar(context, title: Text(context.t(K.tekrarTitle))),
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
            // Sorular sürüyorsa "Tekrarlar tamam" yalan olurdu: yalnız
            // kelime aşaması bitti.
            context.t(
              widget.onDone != null ? K.tekrarWordsDone : K.reviewsDone,
            ),
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
            label: widget.doneLabel ?? context.t(K.finish),
            expand: true,
            arrow: widget.onDone != null,
            onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
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
            semanticLabel: context.t(K.tekrarTitle),
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
            if (_saveFailed) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  context.t(K.saveFailed),
                  key: const ValueKey('word-review-save-failed'),
                  style: SahneType.bodyStrong.copyWith(color: t.errTx),
                ),
              ),
              const SizedBox(height: SahneSpace.x2),
              SahneButton.secondary(
                key: const ValueKey('word-review-retry'),
                label: context.t(K.retry),
                expand: true,
                onPressed: _retrySave,
              ),
            ] else
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

  /// Cevaptan sonra doğru şık Rast (yeşil + ✓), yanlış seçilen Şaş (kırmızı +
  /// çapraz tarama + ✗), ötekiler sönük görünür: quiz'in şık çubuğunun
  /// ([QuizOptionTile]) aynı durumları. Geri bildirim metni ayrıca yazılır;
  /// durum yalnız renkle verilmez.
  ///
  /// Eskiden cevaptan sonra şıklar `onPressed: null` ile pasifleştiriliyordu
  /// ve pasif `SahneButton` ton dolgusunu değil ortak soluk dolguyu çizer:
  /// işaretleme hiç görünmüyor, dört şık aynı gri kalıyordu (bekçi:
  /// `word_drill_option_states_test`).
  Widget _option(
    BuildContext context,
    SahneTokens t,
    WordReviewQuestion question,
    String option,
  ) {
    final index = question.options.indexOf(option);
    final isRight = question.isCorrect(option);
    final isPicked = option == _picked;
    return KeyedSubtree(
      key: ValueKey('word-review-option-$index'),
      child: QuizOptionTile(
        index: index,
        answer: option,
        selected: isPicked,
        correct: _answered && isRight,
        disabled: _answered,
        dimmed: _answered && !isRight && !isPicked,
        onTap: _answered ? null : () => _answer(option),
      ),
    );
  }
}
