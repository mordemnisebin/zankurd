import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/local_data_service.dart';
import '../data/zankurd_repository.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'quiz_result_screen.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  List<QuizQuestion>? _questions;
  bool _loading = true;
  bool _completed = false;
  bool _alreadyDoneToday = false;
  LocalDataService? _local;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = await LocalDataService.getInstance();
    try {
      final allQuestions = await widget.repository.loadQuestions(limit: 200)
          .catchError((_) => widget.repository.questions);
      // Date-seeded deterministic selection — same day → same 10 questions for all
      final seed = local.dailySeed;
      final rng = Random(seed);
      final pool = List<QuizQuestion>.from(allQuestions);
      pool.shuffle(rng);
      final daily = pool.take(10).toList();
      if (mounted) {
        setState(() {
          _local = local;
          _questions = daily;
          _alreadyDoneToday = local.hasCompletedDailyQuiz;
          _completed = _alreadyDoneToday;
          _loading = false;
        });
      }
    } catch (_) {
      final pool = List<QuizQuestion>.from(widget.repository.questions);
      pool.shuffle(Random(local.dailySeed));
      if (mounted) {
        setState(() {
          _local = local;
          _questions = pool.take(10).toList();
          _alreadyDoneToday = local.hasCompletedDailyQuiz;
          _completed = _alreadyDoneToday;
          _loading = false;
        });
      }
    }
  }

  String get _todayLabel {
    final now = DateTime.now();
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.page,
      appBar: AppBar(
        title: const Text('Günlük Quiz'),
        backgroundColor: AppTheme.page,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _todayLabel,
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _completed
          ? _CompletedBanner(
              alreadyDone: _alreadyDoneToday,
              onReplay: _alreadyDoneToday ? null : () => setState(() => _completed = false),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  AppPanel(
                    color: const Color(0xFFFFF7E6),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFFBD7B2B)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Günün Soruları',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFBD7B2B),
                                ),
                              ),
                              Text(
                                '${_questions!.length} soru · Bugün herkese aynı sorular çıkıyor',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_questions!.length, (i) {
                    final q = _questions![i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppPanel(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.green.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              q.category,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _startQuiz(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFBD7B2B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Günlük Quizi Başlat',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _startQuiz(BuildContext context) {
    final room = widget.repository.createRoom(category: 'Günlük');
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => _DailyPlayScreen(
          repository: widget.repository,
          questions: _questions!,
          room: room,
          onCompleted: () async {
            await _local?.markDailyQuizCompleted();
            await _local?.addCoins(50); // daily completion reward
            if (mounted) {
              navigator.pop();
              setState(() { _completed = true; _alreadyDoneToday = true; });
            }
          },
        ),
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.alreadyDone, this.onReplay});
  final bool alreadyDone;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: AppTheme.green, size: 44),
            ),
            const SizedBox(height: 18),
            Text(
              alreadyDone ? 'Bugün zaten tamamladın!' : 'Bugünkü quizi tamamladın!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              alreadyDone
                  ? 'Günlük ödülün verildi. Yarın yeni sorular gelecek!'
                  : '🪙 +50 coin kazandın! Yarın yeni sorular gelecek.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            if (onReplay != null)
              OutlinedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay_outlined),
                label: const Text('Tekrar Çöz'),
              ),
          ],
        ),
      ),
    );
  }
}

// Minimal play screen that wraps QuizResultScreen flow
class _DailyPlayScreen extends StatefulWidget {
  const _DailyPlayScreen({
    required this.repository,
    required this.questions,
    required this.room,
    required this.onCompleted,
  });

  final ZanKurdRepository repository;
  final List<QuizQuestion> questions;
  final GameRoom room;
  final VoidCallback onCompleted;

  @override
  State<_DailyPlayScreen> createState() => _DailyPlayScreenState();
}

class _DailyPlayScreenState extends State<_DailyPlayScreen> {
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _correct = 0;
  int _wrong = 0;
  String _selected = '';
  Timer? _timer;
  int _remaining = 15;
  DateTime? _startTime;
  final List<AnswerRecord> _records = [];

  QuizQuestion get _q => widget.questions[_index];
  bool get _answered => _selected.isNotEmpty;
  bool get _isLast => _index == widget.questions.length - 1;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _startTime = DateTime.now();
    _remaining = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        if (!_answered) _recordAndNext('');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _answer(String answer) {
    if (_answered) return;
    _timer?.cancel();
    final ms = _startTime == null ? 2000 : DateTime.now().difference(_startTime!).inMilliseconds;
    setState(() => _selected = answer);
    final correct = answer == _q.correctAnswer;
    setState(() {
      if (correct) { _streak++; _bestStreak = _bestStreak < _streak ? _streak : _bestStreak; _correct++; _score += 100 + (_streak * 10).clamp(0, 50); }
      else { _streak = 0; _wrong++; }
    });
    widget.repository.submitAnswer(room: widget.room, question: _q, selectedOptionOptionKey: _optKey(answer), responseMs: ms).catchError((_) => <String, dynamic>{});
  }

  String _optKey(String ans) {
    final i = _q.answers.indexOf(ans);
    return i == 0 ? 'A' : i == 1 ? 'B' : i == 2 ? 'C' : 'D';
  }

  void _recordAndNext(String overrideSelected) {
    _records.add(AnswerRecord(
      questionId: _q.id, prompt: _q.prompt, answers: _q.answers,
      correctAnswer: _q.correctAnswer, selectedAnswer: overrideSelected,
      explanation: _q.explanation, imageUrl: _q.imageUrl, category: _q.category,
    ));
    if (_isLast) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          repository: widget.repository, room: widget.room,
          score: _score, correctCount: _correct, wrongCount: _wrong,
          totalQuestions: widget.questions.length, bestStreak: _bestStreak,
          answerRecords: _records,
        ),
      ));
      widget.onCompleted();
      return;
    }
    setState(() { _index++; _selected = ''; });
    _startTimer();
  }

  void _next() {
    _records.add(AnswerRecord(
      questionId: _q.id, prompt: _q.prompt, answers: _q.answers,
      correctAnswer: _q.correctAnswer, selectedAnswer: _selected,
      explanation: _q.explanation, imageUrl: _q.imageUrl, category: _q.category,
    ));
    if (_isLast) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          repository: widget.repository, room: widget.room,
          score: _score, correctCount: _correct, wrongCount: _wrong,
          totalQuestions: widget.questions.length, bestStreak: _bestStreak,
          answerRecords: _records,
        ),
      ));
      widget.onCompleted();
      return;
    }
    setState(() { _index++; _selected = ''; });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Günlük Quiz · ${_index + 1}/${widget.questions.length}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Timer bar
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _remaining / 15,
                  minHeight: 8,
                  backgroundColor: AppTheme.line,
                  valueColor: AlwaysStoppedAnimation<Color>(_remaining <= 5 ? AppTheme.red : const Color(0xFFBD7B2B)),
                ),
              )),
              const SizedBox(width: 10),
              SizedBox(width: 30, child: Text('${_remaining}s', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _remaining <= 5 ? AppTheme.red : AppTheme.muted))),
            ]),
            const SizedBox(height: 16),
            AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(6)), child: Text(_q.category, style: const TextStyle(color: Color(0xFFBD7B2B), fontWeight: FontWeight.w800, fontSize: 12))),
              ]),
              const SizedBox(height: 12),
              Text(_q.prompt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 16),
              for (final ans in _q.answers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerBtn(
                    answer: ans, selected: _selected == ans,
                    correct: _answered && ans == _q.correctAnswer,
                    wrong: _selected == ans && ans != _q.correctAnswer,
                    disabled: _answered, onTap: () => _answer(ans),
                  ),
                ),
              if (_answered) ...[
                const SizedBox(height: 6),
                Text(_q.explanation, style: const TextStyle(color: AppTheme.muted)),
              ],
            ])),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _answered ? _next : null,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBD7B2B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: Icon(_isLast ? Icons.flag_outlined : Icons.arrow_forward_rounded),
              label: Text(_isLast ? 'Bitir' : 'Sonraki'),
            )),
          ],
        ),
      ),
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  const _AnswerBtn({required this.answer, required this.selected, required this.correct, required this.wrong, required this.disabled, required this.onTap});
  final String answer; final bool selected, correct, wrong, disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFFDFF2E9) : wrong ? const Color(0xFFFDECEA) : AppTheme.page;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.line)),
        child: Row(children: [
          Expanded(child: Text(answer, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (correct) const Icon(Icons.check_circle_outline, color: AppTheme.green),
          if (wrong) const Icon(Icons.cancel_outlined, color: AppTheme.red),
        ]),
      ),
    );
  }
}
