import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/streak_store.dart';
import '../data/word_list_store.dart';
import '../data/word_drill.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/analytics_service.dart';
import '../services/lesson_listening_speaker.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/pronunciation_sheet.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'quiz/quiz_option_tile.dart';

/// Kelime tekrarı oturumu: Kurmancî sözcük -> dört Türkçe anlamdan doğrusu.
///
/// Oturum, [WordListStore.sessionWords] ile vadesi gelmiş en çok 10
/// kelimedir ve açılışta SABİTLENİR: cevap verdikçe kelimenin vadesi
/// ileri gittiği için listeyi her adımda yeniden hesaplamak sırayı bozardı.
/// Her cevap hemen yerelde saklanır (yarıda çıkılırsa işlenenler kaybolmaz).
/// Yanlış cevaplanan kelime 1. kutuya döner ve yarın tekrar gelir; oturum
/// sonunda bir kez daha sorulur, ama bu ikinci deneme kutu/vade YAZMAZ ve
/// skor/özet yalnız ilk denemeyi sayar. Ses düğmesi yalnız o ifade için kayıt/TTS varsa çizilir.
class WordDrillScreen extends StatefulWidget {
  const WordDrillScreen({
    this.store,
    this.random,
    this.words,
    this.onDone,
    this.doneLabel,
    this.practice = false,
    super.key,
  });

  /// Serbest pratik: cevaplar kutu/vade YAZMAZ. Vadesi gelmemiş
  /// kelimeyi erken çalışmak kutusunu ilerletirse Leitner aralıkları bozulur
  /// (kurul 2026-10-25: Gemini 4 Argon uyarısı).
  final bool practice;

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
  bool _loadFailed = false;
  int _index = 0;
  int _correct = 0;

  /// Oturumun asıl kelime sayısı; bunun ötesindeki sorular yanlış
  /// cevaplanan kelimelerin oturum sonu tekrarıdır (kayıt yazmaz, sayılmaz).
  int _firstPassCount = 0;
  math.Random _rng = math.Random();
  String? _picked;
  bool _saveFailed = false;

  /// Cevap diske yazılırken "Sonraki" kapalıdır: yazma sonradan hata
  /// verirse uyarı bir sonraki soruya sızıyordu (Gemini 4 Argon incelemesi).
  bool _saving = false;
  LessonListeningSpeaker? _speaker;

  /// Harf dizme sorusunda seçilen harflerin [WordReviewQuestion.letters]
  /// içindeki sıraları (aynı harf iki kez geçebilir).
  final List<int> _spelled = [];

  /// Oturumdaki cevaplar (bitiş ekranının kelime özeti).
  final List<({WordReviewQuestion question, bool correct})> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      final rng = widget.random ?? math.Random();
      // Ses yüklemesi oturumu BEKLETMEZ: hazır değilse bu oturumda dinleme
      // yerine geri çağırma sorulur, ses arkadan yüklenip çalmaya hazır olur.
      final speaker = LessonAudio.loaded;
      if (speaker == null) {
        LessonAudio.shared().then(
          (loaded) {
            if (mounted) setState(() => _speaker = loaded);
          },
          onError: (Object error, StackTrace stack) {
            ErrorReporter.record(error, stack, reason: 'word_review_audio');
          },
        );
      }
      final questions = <WordReviewQuestion>[];
      for (final word in widget.words ?? store.sessionWords()) {
        final entry = LearnerLexicon.byId(word.entryId);
        if (entry == null) continue;
        final mode = WordReviewQuestion.modeForBox(
          word.box,
          entry: entry,
          canListen: speaker?.availableFor(entry.termKu) ?? false,
        );
        questions.add(WordReviewQuestion.buildFor(entry, mode, random: rng));
      }
      if (!mounted) return;
      setState(() {
        _store = store;
        _speaker ??= speaker;
        _questions = questions;
        _firstPassCount = questions.length;
        _rng = rng;
        _loading = false;
        _loadFailed = false;
      });
      _autoPlayIfListening();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_load');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _retryLoad() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    unawaited(_load());
  }

  bool get _finished => _index >= _questions.length;
  bool get _answered => _picked != null;

  Future<void> _answer(String option) async {
    if (_answered || _finished) return;
    final question = _questions[_index];
    final correct = question.isCorrect(option);
    final retry = _index >= _firstPassCount;
    setState(() {
      _picked = option;
      _saveFailed = false;
      if (retry) return;
      _saving = true;
      if (correct) _correct++;
      _results.add((question: question, correct: correct));
      if (!correct) {
        // Öğrenme açısından yanlış kelime oturum bitmeden bir kez daha
        // görülür (2026-10-25); yalnız bir kez, ve kutuya yazılmadan.
        _questions = [
          ..._questions,
          WordReviewQuestion.buildFor(
            question.entry,
            question.mode,
            random: _rng,
          ),
        ];
      }
    });
    if (retry) return;
    // Kayıt yazılamadıysa ilerleme DURUR: yoksa kullanıcı "tekrar ettim"
    // sanır, kutu/vade diske geçmez ve kelime yarın yine aynı kutuda gelir.
    var saved = true;
    try {
      final store = _store;
      if (!widget.practice &&
          store != null &&
          store.contains(question.entry.id)) {
        saved = await store.recordReview(question.entry.id, correct: correct);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_review_record');
      saved = false;
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _saveFailed = !saved;
      });
    }
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

  /// Dinleme sorusu açılınca ses bir kez kendiliğinden çalar.
  void _autoPlayIfListening() {
    if (_finished || _questions.isEmpty) return;
    final question = _questions[_index];
    if (question.mode != WordReviewMode.listen) return;
    _speak(question.entry.termKu);
  }

  void _speak(String text) {
    final speaker = _speaker;
    if (speaker == null || !speaker.availableFor(text)) return;
    unawaited(
      speaker.speak(text).catchError((Object error, StackTrace stack) {
        ErrorReporter.record(error, stack, reason: 'word_review_speak');
        return false;
      }),
    );
  }

  @override
  void dispose() {
    final speaker = _speaker;
    if (speaker != null) unawaited(speaker.stop().catchError((_) {}));
    super.dispose();
  }

  void _next() {
    if (_saving) return;
    setState(() {
      _index++;
      _picked = null;
      _spelled.clear();
    });
    _autoPlayIfListening();
    if (_finished && _questions.isNotEmpty) {
      unawaited(StreakStore.recordActivity());
      AnalyticsService.instance.logReviewComplete(
        correctCount: _correct,
        totalCount: _firstPassCount,
      );
    }
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
            : _loadFailed
            ? AppErrorState(
                key: const ValueKey('word-review-load-error'),
                title: context.t(K.loadFailedShort),
                message: context.t(K.genericErrorBody),
                retryLabel: context.t(K.retryShort),
                onRetry: _retryLoad,
              )
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
              'total': '$_firstPassCount',
            }),
            key: const ValueKey('word-review-score'),
            textAlign: TextAlign.center,
            style: SahneType.bodyStrong.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x4),
          // Oturumun kelime özeti: hangi kelime bilindi, hangisi kutu 1'e
          // döndü (2026-10-25: bitiş ekranı yalnız skor yazıyordu).
          SahneListGroup(
            key: const ValueKey('word-review-summary'),
            children: [
              for (final r in _results)
                SahneListRow.plain(
                  dense: true,
                  title: r.question.entry.termKu,
                  subtitle: r.question.entry.meaningTr,
                  trailing: Icon(
                    r.correct ? AppIcons.circleCheck : AppIcons.circleXmark,
                    size: 20,
                    color: r.correct ? t.okTx : t.errTx,
                  ),
                ),
            ],
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
          _ModeBadge(mode: question.mode),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(switch (question.mode) {
              WordReviewMode.meaning => K.wordsReviewPrompt,
              WordReviewMode.reverse => K.wordsReviewPromptReverse,
              WordReviewMode.listen => K.wordsReviewPromptListen,
              WordReviewMode.spell => K.wordsReviewPromptSpell,
            }),
            key: const ValueKey('word-review-prompt'),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x2),
          _buildStem(context, t, question),
          const SizedBox(height: SahneSpace.x4),
          if (question.mode == WordReviewMode.spell)
            _buildSpell(context, t, question)
          else
            for (final option in question.options) ...[
              _option(context, t, question, option),
              const SizedBox(height: SahneSpace.x2),
            ],
          if (_answered && question.mode != WordReviewMode.meaning) ...[
            const SizedBox(height: SahneSpace.x2),
            _buildReveal(context, t, question),
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
                onPressed: _saving ? null : _next,
              ),
          ],
        ],
      ),
    );
  }

  /// Sorunun gövdesi: türüne göre Kurmancî sözcük, Türkçe anlam ya da
  /// dinle düğmesi.
  Widget _buildStem(
    BuildContext context,
    SahneTokens t,
    WordReviewQuestion question,
  ) {
    final entry = question.entry;
    switch (question.mode) {
      case WordReviewMode.meaning:
        return Row(
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
        );
      case WordReviewMode.reverse:
      case WordReviewMode.spell:
        return Semantics(
          header: true,
          child: Text(
            entry.meaningTr,
            key: const ValueKey('word-review-meaning'),
            style: SahneType.headline.copyWith(color: t.tx),
          ),
        );
      case WordReviewMode.listen:
        final speaker = _speaker;
        return Center(
          child: Semantics(
            button: true,
            label: context.t(K.lessonListeningReplay),
            onTap: () => _speak(entry.termKu),
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('word-review-listen'),
              onTap: () => _speak(entry.termKu),
              child: speaker == null
                  ? _ListenDisc(t: t, speaking: false)
                  : ValueListenableBuilder<bool>(
                      valueListenable: speaker.speakingListenable,
                      builder: (context, speaking, _) =>
                          _ListenDisc(t: t, speaking: speaking),
                    ),
            ),
          ),
        );
    }
  }

  /// Cevaptan sonra doğru Kurmancî sözcük, anlamı ve sesi.
  Widget _buildReveal(
    BuildContext context,
    SahneTokens t,
    WordReviewQuestion question,
  ) {
    final entry = question.entry;
    return Container(
      key: const ValueKey('word-review-reveal'),
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.x3,
        SahneSpace.x2,
        SahneSpace.x1,
        SahneSpace.x2,
      ),
      decoration: ShapeDecoration(
        color: t.learnTint,
        shape: SahneShape.withSide(SahneShape.m, t.learnEdge, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.termKu,
                  style: SahneType.bodyStrong.copyWith(color: t.learnTx),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.meaningTr,
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ],
            ),
          ),
          LexiconSpeakButton(text: entry.termKu),
          // K13: telaffuz denemesi liste satırından çalışmaya taşındı;
          // cevap açıldığında doğru sözcüğü söyleyip deneyebilir.
          PronunciationButton(text: entry.termKu),
        ],
      ),
    );
  }

  /// Harf dizme: üstte kurulan sözcük, altta karışık harf karoları.
  Widget _buildSpell(
    BuildContext context,
    SahneTokens t,
    WordReviewQuestion question,
  ) {
    final letters = question.letters;
    final built = [for (final i in _spelled) letters[i]].join();
    final complete = _spelled.length == letters.length;
    final answered = _answered;
    final right = answered && question.isCorrect(built);
    final edge = !answered
        ? t.learnEdge
        : right
        ? t.okTx
        : t.errTx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('word-review-spelled'),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x3,
            vertical: SahneSpace.x2,
          ),
          decoration: ShapeDecoration(
            color: t.s1,
            shape: SahneShape.withSide(SahneShape.m, edge, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  built.isEmpty ? '·' * letters.length : built,
                  style: SahneType.headline.copyWith(
                    color: built.isEmpty ? t.tx3 : t.tx,
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (!answered && _spelled.isNotEmpty)
                IconButton(
                  key: const ValueKey('word-review-undo'),
                  tooltip: context.t(K.wordsReviewUndo),
                  onPressed: () => setState(_spelled.removeLast),
                  icon: Icon(AppIcons.arrowRotateLeft, color: t.tx2),
                ),
            ],
          ),
        ),
        const SizedBox(height: SahneSpace.x3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: SahneSpace.x2,
          runSpacing: SahneSpace.x2,
          children: [
            for (var i = 0; i < letters.length; i++)
              _LetterChip(
                key: ValueKey('word-review-letter-$i'),
                letter: letters[i],
                used: _spelled.contains(i),
                onTap: answered || _spelled.contains(i)
                    ? null
                    : () => setState(() => _spelled.add(i)),
              ),
          ],
        ),
        if (!answered) ...[
          const SizedBox(height: SahneSpace.x4),
          SahneButton.primary(
            key: const ValueKey('word-review-check'),
            label: context.t(K.kontrolEt),
            expand: true,
            onPressed: complete ? () => _answer(built) : null,
          ),
        ],
      ],
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

/// Sorunun türünü anlatan küçük rozet (öğrenen ilerlemeyi görür).
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final WordReviewMode mode;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final icon = switch (mode) {
      WordReviewMode.meaning => AppIcons.bookOpen,
      WordReviewMode.reverse => AppIcons.language,
      WordReviewMode.listen => AppIcons.volumeHigh,
      WordReviewMode.spell => AppIcons.pen,
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        key: ValueKey('word-review-mode-${mode.name}'),
        padding: const EdgeInsets.all(SahneSpace.x2),
        decoration: ShapeDecoration(
          color: t.learnTint,
          shape: SahneShape.withSide(SahneShape.s, t.learnEdge, width: 1),
        ),
        child: Icon(icon, size: 18, color: t.learnTx),
      ),
    );
  }
}

/// Dinleme sorusunun büyük ses düğmesi.
class _ListenDisc extends StatelessWidget {
  const _ListenDisc({required this.t, required this.speaking});

  final SahneTokens t;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 96,
      height: 96,
      decoration: ShapeDecoration(
        color: speaking ? t.learnTx : t.learnTint,
        shape: SahneShape.withSide(SahneShape.chamferL, t.learnTx, width: 2),
      ),
      child: Icon(
        AppIcons.volumeHigh,
        size: 40,
        color: speaking ? t.learnTint : t.learnTx,
      ),
    );
  }
}

/// Harf dizme karosu; kullanılınca boş yuva olarak kalır (yer kaymaz).
class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.used,
    required this.onTap,
    super.key,
  });

  final String letter;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: letter,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: used ? 0.25 : 1,
          child: Container(
            // En az 48 (dokunma hedefi); büyük yazıda harfle birlikte büyür.
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x2,
              vertical: SahneSpace.x1,
            ),
            decoration: ShapeDecoration(
              color: t.learnTint,
              shape: SahneShape.withSide(SahneShape.s, t.learnEdge, width: 1),
            ),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                letter,
                style: SahneType.headline.copyWith(color: t.learnTx),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
