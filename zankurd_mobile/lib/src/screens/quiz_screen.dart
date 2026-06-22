import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/mistake_store.dart';
import '../data/sync_manager.dart';
import '../providers/sound_provider.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../data/seen_question_store.dart';
import '../data/zankurd_repository.dart';
import '../game/bot_opponent.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/wildcard.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import 'quiz_result_screen.dart';

part 'quiz/quiz_widgets.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.repository,
    required this.room,
    required this.questions,
    this.practice = false,
    this.botRace = false,
    this.dailyQuiz = false,
    this.enableTimer = true,
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

  final bool enableTimer;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
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

  // Timer ve animasyon durumları
  late final AnimationController _timerController;
  Timer? _explanationTimer;
  bool _showExplanation = false;
  bool _showConfetti = false;

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

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
      value: 1.0,
    );
    if (widget.enableTimer) {
      _timerController.addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          if (!answered) {
            _answer('TIMEOUT');
          }
        }
      });
      int lastTickSecond = 15;
      _timerController.addListener(() {
        if (_timerController.isAnimating) {
          final remaining = (_timerController.value * 15).ceil();
          if (remaining != lastTickSecond) {
            lastTickSecond = remaining;
            if (remaining > 0 && remaining <= 5) {
              HapticFeedback.lightImpact();
            }
          }
        }
      });
    }

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
    _startTimer();
  }

  void _startTimer() {
    if (widget.enableTimer) {
      _timerController.stop();
      _timerController.value = 1.0;
      _timerController.reverse();
    }
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
    if (widget.practice && correct) {
      // In mistake practice, correct reviews are handled by the rating buttons
      return;
    }
    MistakeStore.load().then(
      (store) => correct
          ? store.markResolved(id)
          : store.markMistake(id, category: question.category),
    );
  }

  Future<void> _submitPracticeRating(int score) async {
    final id = question.id;
    final store = await MistakeStore.load();
    await store.markResolvedSM2(id, score);
    await _next();
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _timerController.dispose();
    _explanationTimer?.cancel();
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
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final landscape = constraints.maxWidth >= 700;
                    if (!landscape) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        children: [
                          _buildScoreHeader(),
                          const SizedBox(height: 16),
                          _buildProgressBar(context),
                          const SizedBox(height: 16),
                          _buildQuestionSwitcher(context),
                          const SizedBox(height: 16),
                          _buildActionControls(),
                          const SizedBox(height: 16),
                          _LiveScoreboard(players: livePlayers),
                        ],
                      );
                    }

                    return Row(
                      key: const ValueKey('quiz-landscape-layout'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 8, 10, 18),
                            children: [
                              _buildQuestionSwitcher(context),
                              const SizedBox(height: 12),
                              _buildProgressBar(context),
                              const SizedBox(height: 12),
                              _buildScoreHeader(),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(8, 8, 18, 18),
                            children: [
                              _buildActionControls(),
                              const SizedBox(height: 12),
                              _LiveScoreboard(players: livePlayers),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_showConfetti)
                ConfettiOverlay(
                  onFinished: () {
                    setState(() {
                      _showConfetti = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHeader() {
    return _ScoreHeader(
      score: score,
      streak: streak,
      progress: '${index + 1}/${widget.questions.length}',
      coinBalance: _coinBalance,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (index + 1) / widget.questions.length),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => LinearProgressIndicator(
        value: value,
        minHeight: 8,
        borderRadius: BorderRadius.circular(99),
        backgroundColor: AppTheme.surfaceHiColor(context),
        color: AppTheme.accent,
      ),
    );
  }

  Widget _buildQuestionSwitcher(BuildContext context) {
    return AnimatedSwitcher(
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
    );
  }

  Widget _buildActionControls() {
    final bool showRatingBar =
        widget.practice &&
        answered &&
        selectedAnswer == question.correctAnswer &&
        !completing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWildcardRow(),
        const SizedBox(height: 8),
        showRatingBar
            ? Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(3),
                      child: Text(
                        context.s('Zor', 'Zor'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(4),
                      child: Text(
                        context.s('Navîn', 'Orta'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.correct,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(5),
                      child: Text(
                        context.s('Hêsan', 'Kolay'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : FilledButton.icon(
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
      cantAfford: !used && !canAfford && !answered,
      onTap: () => _onWildcardTap(type),
    );
  }

  void _onWildcardTap(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty => _useFiftyFifty(),
    WildcardType.audience => _useAudience(),
    WildcardType.doubleAnswer => _activateDoubleAnswer(),
    WildcardType.changeQuestion => _changeQuestion(),
  };

  // ─── Joker mekanikleri ───────────────────────────────────────────────────

  void _trackWildcardMission() {
    DailyMissionStore.load().then((store) {
      store.reportWildcardUsed().then((completed) {
        if (completed != null && mounted) {
          widget.repository.addCoins(
            completed.coinReward,
            'daily_mission_reward',
          );
          XPStore.load().then((xpStore) {
            xpStore.addXP(100).then((leveledUp) {
              widget.repository.updateProfileXP(xpStore.totalXP).catchError((
                _,
              ) {
                SyncManager.instance.queueXP(xpStore.totalXP);
              });
              if (mounted) {
                MissionToast.show(context, completed);
                if (leveledUp) {
                  final isKu = context.isKu;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isKu
                            ? 'Asta Te Bilind Bû! Ast Nû: ${xpStore.currentLevel}'
                            : 'Tebrikler, seviye atladın! Yeni Seviye: ${xpStore.currentLevel}',
                      ),
                      backgroundColor: AppTheme.secondaryAccent,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            });
          });
        }
      });
    });
  }

  void _useFiftyFifty() {
    const cost = 20;
    if (_wildcard.fiftyFiftyUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
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
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
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
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
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
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final replacement = candidates[Random().nextInt(candidates.length)];

    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      _questions[index] = replacement;
      hiddenAnswers = const {};
      _audiencePoll = null;
    });
    _markQuestionSeen();
    _startTimer();
    widget.repository
        .spendCoins(cost, 'wildcard_change_question')
        .catchError((_) => false);
  }

  // ─── Soru paneli ─────────────────────────────────────────────────────────

  Widget _buildQuestionPanel(BuildContext context) {
    final promptText = question.promptText;
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.width >= 700 && size.width > size.height;
    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
              _CircularTimer(
                key: const ValueKey('quiz-circular-timer'),
                animation: _timerController,
                maxSeconds: 15,
                isPaused: answered,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (compactLandscape && question.hasImage)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 164,
                  child: _QuestionImage(url: question.imageUrl!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuestionTextAndAnswers(
                    promptText: promptText,
                    promptFontSize: 20,
                    question: question,
                    selectedAnswer: selectedAnswer,
                    answered: answered,
                    hiddenAnswers: hiddenAnswers,
                    firstAttemptAnswer: _firstAttemptAnswer,
                    audiencePoll: _audiencePoll,
                    showExplanation: _showExplanation,
                    onAnswer: _answer,
                  ),
                ),
              ],
            )
          else ...[
            if (question.hasImage) ...[
              _QuestionImage(url: question.imageUrl!),
              const SizedBox(height: 14),
            ],
            _QuestionTextAndAnswers(
              promptText: promptText,
              promptFontSize: compactLandscape ? 20 : 24,
              question: question,
              selectedAnswer: selectedAnswer,
              answered: answered,
              hiddenAnswers: hiddenAnswers,
              firstAttemptAnswer: _firstAttemptAnswer,
              audiencePoll: _audiencePoll,
              showExplanation: _showExplanation,
              onAnswer: _answer,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _answer(String answer) async {
    if (answered) return;

    _timerController.stop();

    _explanationTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showExplanation = true);
      }
    });

    // Çift Cevap aktifse ve ilk deneme yanlışsa: göster ama kilitleme
    if (_wildcard.doubleAnswerActivated &&
        _firstAttemptAnswer.isEmpty &&
        answer != question.correctAnswer) {
      HapticFeedback.heavyImpact();
      setState(() => _firstAttemptAnswer = answer);
      return;
    }

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
        HapticFeedback.lightImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.heavyImpact();
        context.read<SoundProvider>().playWrong();
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
        if (correct && streak >= 5 && streak % 5 == 0) {
          _showConfetti = true;
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
        HapticFeedback.lightImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.heavyImpact();
        context.read<SoundProvider>().playWrong();
      }
      setState(() {
        if (correct) {
          streak += 1;
          bestStreak = bestStreak < streak ? streak : bestStreak;
          correctCount += 1;
          score += 100 + (streak * 10).clamp(0, 50);
          if (streak >= 5 && streak % 5 == 0) {
            _showConfetti = true;
          }
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
      context.read<SoundProvider>().playWin();
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

    _explanationTimer?.cancel();
    setState(() {
      index += 1;
      selectedAnswer = '';
      favorite = false;
      completing = false;
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
      _showExplanation = false;
    });
    _markQuestionSeen();
    _startTimer();
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
