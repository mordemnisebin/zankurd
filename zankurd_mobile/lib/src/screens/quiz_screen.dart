import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mistake_store.dart';
import '../data/seen_question_store.dart';
import '../data/zankurd_repository.dart';
import '../game/bot_opponent.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/wildcard.dart';
import '../l10n/explanation_ku.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.repository,
    required this.room,
    required this.questions,
    this.practice = false,
    this.botRace = false,
    this.dailyQuiz = false,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final List<QuizQuestion> questions;

  /// Yanlışlardan çalışma modu: coin ödülü verilmez.
  final bool practice;

  /// Tek kişilik yarışta simüle bot rakipler etkinleşir.
  final bool botRace;

  /// Günün yarışması akışından açıldıysa daily quiz sayacı işler.
  final bool dailyQuiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correctCount = 0;
  int wrongCount = 0;
  String selectedAnswer = '';
  bool favorite = false;
  bool completing = false;
  Set<String> hiddenAnswers = const {};
  final List<AnswerRecord> answerRecords = [];
  late List<Player> livePlayers = widget.room.players;
  StreamSubscription<List<Player>>? _playersSub;
  BotRace? _botRace;
  bool _isKu = true;

  // Joker sistemi
  late List<QuizQuestion> _questions;
  WildcardState _wildcard = const WildcardState();
  String _firstAttemptAnswer = '';
  Map<String, double>? _audiencePoll;
  int _coinBalance = 0;

  QuizQuestion get question => _questions[index];
  bool get answered => selectedAnswer.isNotEmpty;
  bool get isLastQuestion => index == widget.questions.length - 1;
  bool get _isSoloMode => widget.room.id == null || widget.botRace;

  @override
  void initState() {
    super.initState();
    _isKu = context.langProvider.isKu;
    _questions = List.of(widget.questions);
    _loadCoinBalance();
    if (widget.botRace) {
      _botRace = BotRace.standard();
      livePlayers = _composeBotRacePlayers();
    } else {
      _playersSub = widget.repository.subscribeRoomPlayers(widget.room).listen((
        players,
      ) {
        if (!mounted) return;
        setState(() => livePlayers = players);
      });
    }
    _markQuestionSeen();
  }

  void _loadCoinBalance() {
    widget.repository.loadCoinBalance().then((balance) {
      if (mounted) setState(() => _coinBalance = balance);
    });
  }

  List<Player> _composeBotRacePlayers() {
    final players = [
      Player(
        name: _isKu ? 'Tu' : 'Sen',
        score: score,
        state: '—',
        streak: streak,
      ),
      ...?_botRace?.toPlayers(),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return players;
  }

  /// Bot rakipler de güncel soruya cevap verir ve tablo tazelenir.
  void _advanceBots() {
    final race = _botRace;
    if (race == null) return;
    race.answerAll(question.difficulty);
    livePlayers = _composeBotRacePlayers();
  }

  /// Gösterilen soruyu tekrar-önleme deposuna işler.
  void _markQuestionSeen() {
    final id = question.id;
    SeenQuestionStore.load().then((store) => store.markSeen([id]));
  }

  /// Yanlış cevabı yanlış defterine ekler, doğru cevap kaydı düşürür.
  void _trackMistake(bool correct) {
    final id = question.id;
    MistakeStore.load().then(
      (store) => correct ? store.markResolved(id) : store.markMistake(id),
    );
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    super.dispose();
  }

  /// İlerleme varken geri tuşunda onay sorar; yanlışlıkla çıkışı önler.
  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.s('Ji pêşbirkê derkevî?', 'Yarıştan çıkılsın mı?')),
        content: Text(
          context.s(
            'Pêşketina te ya vê pêşbirkê winda dibe.',
            'Bu yarıştaki ilerlemen kaybolur.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.s('Bidomîne', 'Devam Et')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.s('Derkeve', 'Çık')),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = index > 0 || answered;
    return PopScope(
      canPop: !hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('${context.s('Jûr', 'Oda')} ${widget.room.code}'),
          actions: [
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
            ),
            IconButton(
              onPressed: _reportQuestion,
              icon: const Icon(Icons.report_gmailerrorred_outlined),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient(context),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _ScoreHeader(
                  score: score,
                  streak: streak,
                  progress: '${index + 1}/${widget.questions.length}',
                  coinBalance: _coinBalance,
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: (index + 1) / widget.questions.length,
                  ),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: AppTheme.surfaceHiColor(context),
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(index),
                    child: _buildQuestionPanel(context),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWildcardRow(),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: answered && !completing ? () => _next() : null,
                      icon: Icon(
                        isLastQuestion
                            ? Icons.flag_outlined
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        isLastQuestion
                            ? context.s('Qediya', 'Bitir')
                            : context.s('Piştî vê', 'Sonraki'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LiveScoreboard(players: livePlayers),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Joker satırı ────────────────────────────────────────────────────────

  Widget _buildWildcardRow() {
    final jokers = [
      WildcardType.fiftyFifty,
      WildcardType.audience,
      WildcardType.doubleAnswer,
      if (_isSoloMode) WildcardType.changeQuestion,
    ];
    return Row(
      children: [
        for (var i = 0; i < jokers.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _buildWildcardButton(jokers[i])),
        ],
      ],
    );
  }

  Widget _buildWildcardButton(WildcardType type) {
    final used = _wildcard.isUsed(type);
    // doubleAnswer "kullanıldı" = aktive edildi: görsel olarak vurgulanır
    final isActive = type == WildcardType.doubleAnswer && used;
    final canAfford = _coinBalance >= type.coinCost;
    final isEnabled = !used && canAfford && !answered;

    return _WildcardButton(
      type: type,
      isKu: _isKu,
      isEnabled: isEnabled,
      isActive: isActive,
      onTap: () => _onWildcardTap(type),
    );
  }

  void _onWildcardTap(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty     => _useFiftyFifty(),
    WildcardType.audience       => _useAudience(),
    WildcardType.doubleAnswer   => _activateDoubleAnswer(),
    WildcardType.changeQuestion => _changeQuestion(),
  };

  // ─── Joker mekanikleri ───────────────────────────────────────────────────

  void _useFiftyFifty() {
    const cost = 20;
    if (_wildcard.fiftyFiftyUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(fiftyFiftyUsed: true);
      hiddenAnswers = question.answers
          .where((a) => a != question.correctAnswer)
          .take(2)
          .toSet();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_fifty_fifty')
        .catchError((_) => false);
  }

  void _useAudience() {
    const cost = 30;
    if (_wildcard.audienceUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_audience')
        .catchError((_) => false);
  }

  Map<String, double> _buildAudiencePoll() {
    final seed = question.id.codeUnits.fold<int>(0, (s, u) => s + u);
    final rng = Random(seed);

    // 50/50 aktifse sadece görünür şıkları kullan
    final visible = question.answers
        .where((a) => !hiddenAnswers.contains(a))
        .toList();
    final wrongs = visible.where((a) => a != question.correctAnswer).toList();

    // Doğru cevap %50-70 oy alır
    final correctShare = 0.50 + rng.nextDouble() * 0.20;
    var remaining = 1.0 - correctShare;

    final poll = <String, double>{};
    for (var i = 0; i < wrongs.length; i++) {
      if (i == wrongs.length - 1) {
        poll[wrongs[i]] = remaining < 0 ? 0.0 : remaining;
      } else {
        final share = remaining * (0.15 + rng.nextDouble() * 0.45);
        poll[wrongs[i]] = share;
        remaining -= share;
      }
    }
    poll[question.correctAnswer] = correctShare;
    return poll;
  }

  void _activateDoubleAnswer() {
    const cost = 50;
    if (_wildcard.doubleAnswerActivated ||
        _coinBalance < cost ||
        answered ||
        _firstAttemptAnswer.isNotEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(doubleAnswerActivated: true);
    });
    widget.repository
        .spendCoins(cost, 'wildcard_double_answer')
        .catchError((_) => false);
  }

  void _changeQuestion() {
    const cost = 40;
    if (!_isSoloMode ||
        _wildcard.changeQuestionUsed ||
        _coinBalance < cost ||
        answered) {
      return;
    }

    final category = question.category;
    final difficulty = question.difficulty;
    final usedIds = _questions.map((q) => q.id).toSet();

    // Önce aynı kategori + zorlukta aday ara
    var candidates = widget.repository.questions
        .where(
          (q) =>
              q.category == category &&
              q.difficulty == difficulty &&
              !usedIds.contains(q.id),
        )
        .toList();

    // Yeterli yoksa aynı kategoride herhangi bir zorluk
    if (candidates.isEmpty) {
      candidates = widget.repository.questions
          .where((q) => q.category == category && !usedIds.contains(q.id))
          .toList();
    }

    if (candidates.isEmpty) return; // değiştirilecek soru bulunamadı

    HapticFeedback.selectionClick();
    final replacement = candidates[Random().nextInt(candidates.length)];

    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      _questions[index] = replacement;
      hiddenAnswers = const {};
      _audiencePoll = null;
    });
    _markQuestionSeen();
    widget.repository
        .spendCoins(cost, 'wildcard_change_question')
        .catchError((_) => false);
  }

  // ─── Soru paneli ─────────────────────────────────────────────────────────

  Widget _buildQuestionPanel(BuildContext context) {
    final promptText = question.promptText;
    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: _TinyTag(
                  label: CategoryNames.localized(
                    question.category,
                    context.isKu,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _TinyTag(
                  label: question.typeLabelLocalized(context.isKu),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (question.hasImage) ...[
            _QuestionImage(url: question.imageUrl!),
            const SizedBox(height: 14),
          ],
          Text(
            promptText,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 18),
          for (final answer in question.displayAnswers)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: hiddenAnswers.contains(answer) ? 0.25 : 1,
              child: IgnorePointer(
                ignoring: hiddenAnswers.contains(answer),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerButton(
                    answer: answer,
                    selected: selectedAnswer == answer,
                    correct: answered && answer == question.correctAnswer,
                    disabled: answered || answer == _firstAttemptAnswer,
                    firstAttemptWrong:
                        !answered && answer == _firstAttemptAnswer,
                    audiencePercent: _audiencePoll?[answer],
                    onTap: () => _answer(answer),
                  ),
                ),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.s('Bersiva rast', 'Doğru cevap'),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          question.correctAnswer,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.isKu
                              ? explanationToKu(question.explanation)
                              : question.explanation,
                          style: TextStyle(
                            color: AppTheme.textSubColor(context),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _answer(String answer) async {
    if (answered) return;

    // Çift Cevap aktifse ve ilk deneme yanlışsa: göster ama kilitleme
    if (_wildcard.doubleAnswerActivated &&
        _firstAttemptAnswer.isEmpty &&
        answer != question.correctAnswer) {
      HapticFeedback.heavyImpact();
      setState(() => _firstAttemptAnswer = answer);
      return;
    }

    HapticFeedback.lightImpact();

    // Optimistically select it to disable buttons immediately
    setState(() {
      selectedAnswer = answer;
    });

    final optionKey = question.optionKeyForAnswer(answer);

    try {
      final result = await widget.repository.submitAnswer(
        room: widget.room,
        question: question,
        selectedOptionOptionKey: optionKey,
      );

      if (!mounted) return;

      if (result['is_correct'] == true) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }

      final isCorrect = result['is_correct'] == true;
      _trackMistake(isCorrect);
      setState(() {
        score =
            result['new_score'] as int? ??
            (score + (result['points'] as int? ?? 0));
        final correct = isCorrect;
        final alreadyAnswered = result['already_answered'] == true;
        streak = result['new_streak'] as int? ?? (correct ? streak + 1 : 0);
        bestStreak = bestStreak < streak ? streak : bestStreak;
        if (!alreadyAnswered) {
          if (correct) {
            correctCount += 1;
          } else {
            wrongCount += 1;
          }
        }
        _recordAnswer(answer);
        _advanceBots();
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'submitAnswer failed');
      // Fallback local logic if network fails during answer submit
      if (!mounted) return;
      final correct = answer == question.correctAnswer;
      _trackMistake(correct);
      if (correct) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        if (correct) {
          streak += 1;
          bestStreak = bestStreak < streak ? streak : bestStreak;
          correctCount += 1;
          score += 100 + (streak * 10).clamp(0, 50);
        } else {
          streak = 0;
          wrongCount += 1;
        }
        _recordAnswer(answer);
        _advanceBots();
      });
    }
  }

  Future<void> _next() async {
    if (isLastQuestion) {
      if (completing) return;
      setState(() => completing = true);
      widget.repository.finishGame(widget.room).catchError((_) {});
      final coinsAwarded = widget.practice
          ? 0
          : await widget.repository
                .awardQuizCoins(
                  score: score,
                  correctCount: correctCount,
                  bestStreak: bestStreak,
                  totalQuestions: widget.questions.length,
                  room: widget.room,
                )
                .catchError((_) => 0);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppRoute.replace(
          QuizResultScreen(
            repository: widget.repository,
            room: widget.room,
            score: score,
            correctCount: correctCount,
            wrongCount: wrongCount,
            totalQuestions: widget.questions.length,
            bestStreak: bestStreak,
            answerRecords: answerRecords,
            coinsAwarded: coinsAwarded,
            opponents: _botRace?.toPlayers() ?? const [],
            practice: widget.practice,
            dailyQuiz: widget.dailyQuiz,
          ),
        ),
      );
      return;
    }

    setState(() {
      index += 1;
      selectedAnswer = '';
      favorite = false;
      completing = false;
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
    });
    _markQuestionSeen();
  }

  void _recordAnswer(String answer) {
    final existingIndex = answerRecords.indexWhere(
      (record) => record.id == question.id,
    );
    final record = AnswerRecord(
      id: question.id,
      category: question.category,
      prompt: question.promptText,
      answers: question.answers,
      correctAnswer: question.correctAnswer,
      selectedAnswer: answer,
      explanation: question.explanation,
      imageUrl: question.imageUrl,
    );

    if (existingIndex == -1) {
      answerRecords.add(record);
    } else {
      answerRecords[existingIndex] = record;
    }
  }

  Future<void> _toggleFavorite() async {
    final nextFavorite = !favorite;
    setState(() => favorite = nextFavorite);
    try {
      final saved = await widget.repository.toggleFavoriteQuestion(
        question,
        nextFavorite,
      );
      if (!mounted) return;
      setState(() => favorite = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? context.s('Pirs hat tomarkirin.', 'Soru kaydedildi.')
                : context.s('Tomar hate rakirin.', 'Kayıt kaldırıldı.'),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'toggleFavorite failed');
      if (!mounted) return;
      setState(() => favorite = !nextFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Pirs nehate tomarkirin.', 'Soru kaydedilemedi.'),
          ),
        ),
      );
    }
  }

  Future<void> _reportQuestion() async {
    final controller = TextEditingController(
      text: context.s('Şaşiya bersiv an naverokê', 'Cevap veya içerik hatası'),
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.s('Pirsê ragihîne', 'Soruyu bildir')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.s('Sedem', 'Neden'),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.s('Betal bike', 'Vazgeç')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(context.s('Bişîne', 'Gönder')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null) return;

    try {
      await widget.repository.reportQuestion(question, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Rapor hat şandin.', 'Soru raporu gönderildi.'),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'reportQuestion failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Rapor nehat şandin.', 'Rapor gönderilemedi.'),
          ),
        ),
      );
    }
  }
}

// ─── Canlı skor tablosu ──────────────────────────────────────────────────────

class _LiveScoreboard extends StatelessWidget {
  const _LiveScoreboard({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_outlined, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                context.s('Skora zindî', 'Canlı skor'),
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < sortedPlayers.take(4).length; i++)
            _LiveScoreRow(rank: i + 1, player: sortedPlayers[i]),
        ],
      ),
    );
  }
}

class _LiveScoreRow extends StatelessWidget {
  const _LiveScoreRow({required this.rank, required this.player});

  final int rank;
  final Player player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${player.score}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Soru görseli ────────────────────────────────────────────────────────────

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final assetPath = url.startsWith('asset://')
        ? url.replaceFirst('asset://', '')
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: assetPath == null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _QuestionImageFallback(),
              )
            : Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _QuestionImageFallback(),
              ),
      ),
    );
  }
}

class _QuestionImageFallback extends StatelessWidget {
  const _QuestionImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceHiColor(context),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.textMutedColor(context),
        size: 36,
      ),
    );
  }
}

// ─── Üst skor başlığı ────────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.streak,
    required this.progress,
    required this.coinBalance,
  });

  final int score;
  final int streak;
  final String progress;
  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Pûan', 'Puan'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: streak),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Rêz', 'Seri'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: context.s('Pirs', 'Soru'), value: progress),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: coinBalance),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: 'Coin', value: '$value'),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cevap butonu ────────────────────────────────────────────────────────────

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
    this.firstAttemptWrong = false,
    this.audiencePercent,
  });

  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;
  final bool firstAttemptWrong;
  final double? audiencePercent;

  @override
  Widget build(BuildContext context) {
    final wrong = (selected && !correct && disabled) || firstAttemptWrong;
    final color = correct
        ? AppTheme.correct.withValues(alpha: 0.15)
        : wrong
        ? AppTheme.wrong.withValues(alpha: 0.15)
        : AppTheme.surfaceColor(context).withValues(alpha: 0.72);
    final borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : AppTheme.borderColor(context);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: selected ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      answer,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (correct)
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.correct,
                    ),
                  if (wrong)
                    const Icon(Icons.cancel_outlined, color: AppTheme.wrong),
                ],
              ),
              if (audiencePercent != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: audiencePercent!.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: AppTheme.borderColor(context),
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(audiencePercent! * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Küçük etiket ────────────────────────────────────────────────────────────

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textSubColor(context),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Joker butonu ────────────────────────────────────────────────────────────

class _WildcardButton extends StatelessWidget {
  const _WildcardButton({
    required this.type,
    required this.isKu,
    required this.isEnabled,
    required this.isActive,
    required this.onTap,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (isEnabled || isActive) ? 1.0 : 0.35,
      child: OutlinedButton(
        onPressed: isEnabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive
              ? AppTheme.accent.withValues(alpha: 0.15)
              : null,
          side: isActive
              ? const BorderSide(color: AppTheme.accent)
              : BorderSide(color: AppTheme.borderColor(context)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 16),
            const SizedBox(height: 2),
            Text(
              '${type.coinCost}c',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
