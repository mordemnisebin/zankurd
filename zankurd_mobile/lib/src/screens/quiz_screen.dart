import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.repository,
    required this.room,
    required this.questions,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final List<QuizQuestion> questions;

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
  Set<String> hiddenAnswers = const {};
  late List<Player> livePlayers = widget.room.players;
  StreamSubscription<List<Player>>? _playersSub;
  final List<AnswerRecord> _answerRecords = [];

  Timer? _countdownTimer;
  int _remainingMs = 0;
  DateTime? _questionStartTime;

  int get _totalMs => widget.room.secondsPerQuestion * 1000;

  QuizQuestion get question => widget.questions[index];
  bool get answered => selectedAnswer.isNotEmpty;
  bool get isLastQuestion => index == widget.questions.length - 1;

  @override
  void initState() {
    super.initState();
    _playersSub = widget.repository.subscribeRoomPlayers(widget.room).listen((
      players,
    ) {
      if (!mounted) return;
      setState(() => livePlayers = players);
    });
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _questionStartTime = DateTime.now();
    _remainingMs = _totalMs;
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _remainingMs = (_remainingMs - 100).clamp(0, _totalMs);
      });
      if (_remainingMs <= 0) {
        _countdownTimer?.cancel();
        if (!answered) _autoSkip();
      }
    });
  }

  void _autoSkip() {
    _answerRecords.add(
      AnswerRecord(
        questionId: question.id,
        prompt: question.prompt,
        answers: question.answers,
        correctAnswer: question.correctAnswer,
        selectedAnswer: '',
        explanation: question.explanation,
        imageUrl: question.imageUrl,
        category: question.category,
      ),
    );
    if (isLastQuestion) {
      widget.repository.finishGame(widget.room).catchError((_) {});
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
            answerRecords: _answerRecords,
          ),
        ),
      );
      return;
    }
    setState(() {
      index += 1;
      selectedAnswer = '';
      favorite = false;
      hiddenAnswers = const {};
    });
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.code),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            _ScoreHeader(
              score: score,
              streak: streak,
              progress: '${index + 1}/${widget.questions.length}',
            ),
            const SizedBox(height: 10),
            _TimerBar(remainingMs: _remainingMs, totalMs: _totalMs),
            const SizedBox(height: 6),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TinyTag(label: question.category),
                      const SizedBox(width: 8),
                      _TinyTag(label: question.typeLabel),
                      const Spacer(),
                      _TinyTag(label: '${question.difficulty}/5'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (question.hasImage) ...[
                    _QuestionImage(url: question.imageUrl!),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    question.prompt,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < question.answers.length; i++)
                    if (!hiddenAnswers.contains(question.answers[i]))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnswerButton(
                          answer: question.answers[i],
                          index: i,
                          selected: selectedAnswer == question.answers[i],
                          correct: answered && question.answers[i] == question.correctAnswer,
                          disabled: answered,
                          onTap: () => _answer(question.answers[i]),
                        ),
                      ),
                  if (answered) ...[
                    const SizedBox(height: 6),
                    Text(
                      question.explanation,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ],
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
                    onPressed: answered ? _next : null,
                    icon: Icon(
                      isLastQuestion
                          ? Icons.flag_outlined
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(isLastQuestion ? 'Bitir' : 'Sonraki'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LiveScoreboard(players: livePlayers),
          ],
        ),
      ),
    );
  }

  Future<void> _answer(String answer) async {
    if (answered) return;

    _countdownTimer?.cancel();
    final responseMs = _questionStartTime == null
        ? 2000
        : DateTime.now().difference(_questionStartTime!).inMilliseconds;

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
        responseMs: responseMs,
      );

      if (!mounted) return;

      setState(() {
        score =
            result['new_score'] as int? ??
            (score + (result['points'] as int? ?? 0));
        final correct = result['is_correct'] == true;
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
      });
    } catch (_) {
      // Fallback local logic if network fails during answer submit
      if (!mounted) return;
      final correct = answer == question.correctAnswer;
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
      });
    }
  }

  void _next() {
    // Record the current question result
    _answerRecords.add(
      AnswerRecord(
        questionId: question.id,
        prompt: question.prompt,
        answers: question.answers,
        correctAnswer: question.correctAnswer,
        selectedAnswer: selectedAnswer,
        explanation: question.explanation,
        imageUrl: question.imageUrl,
        category: question.category,
      ),
    );

    if (isLastQuestion) {
      widget.repository.finishGame(widget.room).catchError((_) {});
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
            answerRecords: _answerRecords,
          ),
        ),
      );
      return;
    }

    setState(() {
      index += 1;
      selectedAnswer = '';
      favorite = false;
      hiddenAnswers = const {};
    });
    _startTimer();
  }

  void _useFiftyFifty() {
    final wrongAnswers = question.answers
        .where((answer) => answer != question.correctAnswer)
        .take(2)
        .toSet();
    setState(() => hiddenAnswers = wrongAnswers);
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
          content: Text(saved ? 'Soru kaydedildi.' : 'Kayıt kaldırıldı.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => favorite = !nextFavorite);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Soru kaydedilemedi.')));
    }
  }

  Future<void> _reportQuestion() async {
    final controller = TextEditingController(text: 'Cevap veya içerik hatası');
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Soruyu bildir'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Neden',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Gönder'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Soru raporu gönderildi.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rapor gönderilemedi.')));
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_outlined, color: AppTheme.green),
              SizedBox(width: 8),
              Text(
                'Canlı skor',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${player.score}',
            style: const TextStyle(fontWeight: FontWeight.w900),
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
      color: const Color(0xFFE8F3EE),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.green,
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
          child: _Metric(label: 'Puan', value: '$score'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: 'Seri', value: '$streak'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: 'Soru', value: progress),
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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.index,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
  });

  final String answer;
  final int index;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wrong = selected && !correct && disabled;

    final bgColor = correct
        ? AppTheme.success
        : wrong
            ? AppTheme.error
            : Colors.white;

    final letterBgColor = (correct || wrong)
        ? Colors.white.withValues(alpha: 0.25)
        : AppTheme.primary.withValues(alpha: 0.1);

    final textColor = (correct || wrong) ? Colors.white : AppTheme.ink;
    final letterColor = (correct || wrong) ? Colors.white : AppTheme.primary;

    const letters = ['A', 'B', 'C', 'D'];
    final letter = index < letters.length ? letters[index] : '?';

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: correct
                ? AppTheme.success
                : wrong
                    ? AppTheme.error
                    : AppTheme.line,
          ),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: letterBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: letterColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                answer,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ),
            if (correct)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            if (wrong)
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
          ],
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
        color: const Color(0xFFE8F3EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.green,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.remainingMs, required this.totalMs});
  final int remainingMs, totalMs;

  @override
  Widget build(BuildContext context) {
    final pct = totalMs > 0 ? (remainingMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final color = pct > 0.5
        ? AppTheme.success
        : pct > 0.25
            ? AppTheme.warning
            : AppTheme.error;
    final secs = (remainingMs / 1000).ceil();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              '$secs',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: pct),
              duration: const Duration(milliseconds: 100),
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppTheme.line,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
