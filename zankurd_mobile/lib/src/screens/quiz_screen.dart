import 'dart:async';

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
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
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

  QuizQuestion get question => widget.questions[index];
  bool get answered => selectedAnswer.isNotEmpty;
  bool get isLastQuestion => index == widget.questions.length - 1;

  @override
  void initState() {
    super.initState();
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

  List<Player> _composeBotRacePlayers() {
    final players = [
      Player(name: 'Tu', score: score, state: '—', streak: streak),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: answered ? null : _useFiftyFifty,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('50/50'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
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
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LiveScoreboard(players: livePlayers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPanel(BuildContext context) {
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
              Flexible(child: _TinyTag(label: question.typeLabel)),
              const Spacer(),
              _TinyTag(
                label: '${context.s('Ast', 'Zorluk')} ${question.difficulty}/5',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (question.hasImage) ...[
            _QuestionImage(url: question.imageUrl!),
            const SizedBox(height: 14),
          ],
          Text(
            question.prompt,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 18),
          for (final answer in question.answers)
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
                    disabled: answered,
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
                          question.explanation,
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

    HapticFeedback.lightImpact();

    // Optimistically select it to disable buttons immediately
    setState(() {
      selectedAnswer = answer;
    });

    final optionIndex = question.answers.indexOf(answer);
    final optionKey = optionIndex == 0
        ? 'A'
        : optionIndex == 1
        ? 'B'
        : optionIndex == 2
        ? 'C'
        : 'D';

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
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
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
      hiddenAnswers = const {};
    });
    _markQuestionSeen();
  }

  void _useFiftyFifty() {
    HapticFeedback.selectionClick();
    final wrongAnswers = question.answers
        .where((answer) => answer != question.correctAnswer)
        .take(2)
        .toSet();
    setState(() => hiddenAnswers = wrongAnswers);
  }

  void _recordAnswer(String answer) {
    final existingIndex = answerRecords.indexWhere(
      (record) => record.id == question.id,
    );
    final record = AnswerRecord(
      id: question.id,
      category: question.category,
      prompt: question.prompt,
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

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.streak,
    required this.progress,
  });

  final int score;
  final int streak;
  final String progress;

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

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
  });

  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wrong = selected && !correct && disabled;
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
          child: Row(
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
                const Icon(Icons.check_circle_outline, color: AppTheme.correct),
              if (wrong)
                const Icon(Icons.cancel_outlined, color: AppTheme.wrong),
            ],
          ),
        ),
      ),
    );
  }
}

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
