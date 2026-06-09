import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../l10n/lang.dart';
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
  bool completing = false;
  Set<String> hiddenAnswers = const {};
  final List<AnswerRecord> answerRecords = [];
  late List<Player> livePlayers = widget.room.players;
  StreamSubscription<List<Player>>? _playersSub;

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
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
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
              LinearProgressIndicator(
                value: (index + 1) / widget.questions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppTheme.surfaceHi,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 16),
              AppPanel(
                color: AppTheme.surfaceHi,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TinyTag(
                          label: CategoryNames.localized(
                            question.category,
                            context.isKu,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TinyTag(label: question.typeLabel),
                        const Spacer(),
                        _TinyTag(
                          label:
                              '${context.s('Ast', 'Zorluk')} ${question.difficulty}/5',
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
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.16,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final answer in question.answers)
                      if (!hiddenAnswers.contains(answer))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AnswerButton(
                            answer: answer,
                            selected: selectedAnswer == answer,
                            correct:
                                answered && answer == question.correctAnswer,
                            disabled: answered,
                            onTap: () => _answer(answer),
                          ),
                        ),
                    if (answered) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bg.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
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
                              child: Text(
                                question.explanation,
                                style: const TextStyle(
                                  color: AppTheme.textSub,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      onPressed: answered && !completing ? () => _next() : null,
                      icon: Icon(
                        isLastQuestion
                            ? Icons.flag_outlined
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        isLastQuestion
                            ? context.s('Qedandin', 'Bitir')
                            : context.s('Ya piştî vê', 'Sonraki'),
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

  Future<void> _answer(String answer) async {
    if (answered) return;

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
        _recordAnswer(answer);
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
        _recordAnswer(answer);
      });
    }
  }

  Future<void> _next() async {
    if (isLastQuestion) {
      if (completing) return;
      setState(() => completing = true);
      widget.repository.finishGame(widget.room).catchError((_) {});
      final coinsAwarded = await widget.repository
          .awardQuizCoins(
            score: score,
            correctCount: correctCount,
            bestStreak: bestStreak,
            totalQuestions: widget.questions.length,
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
  }

  void _useFiftyFifty() {
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
    } catch (_) {
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
    } catch (_) {
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
      color: AppTheme.surfaceHi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_outlined, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                context.s('Skora zindî', 'Canlı skor'),
                style: const TextStyle(
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
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.textPrimary,
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
              style: const TextStyle(fontWeight: FontWeight.w800),
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
      color: AppTheme.surfaceHi,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.textMuted,
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
          child: _Metric(label: context.s('Pûan', 'Puan'), value: '$score'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: context.s('Rêz', 'Seri'), value: '$streak'),
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
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
        : AppTheme.bg.withValues(alpha: 0.45);
    final borderColor = correct
        ? AppTheme.correct
        : wrong
        ? AppTheme.wrong
        : AppTheme.border;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (correct)
              const Icon(Icons.check_circle_outline, color: AppTheme.correct),
            if (wrong) const Icon(Icons.cancel_outlined, color: AppTheme.wrong),
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
        color: AppTheme.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSub,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
