import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({required this.repository, required this.category, super.key});

  final ZanKurdRepository repository;
  final String category;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  // Robot opponents with difficulty levels
  static const List<_RobotProfile> _robots = [
    _RobotProfile('Robokar', 0.55, 1200, '🤖'),
    _RobotProfile('ZanBot', 0.70, 1450, '🦾'),
    _RobotProfile('MaestroAI', 0.85, 1700, '🧠'),
    _RobotProfile('Eldar', 0.95, 1950, '⚡'),
  ];

  _RobotProfile? _robot;
  List<QuizQuestion>? _questions;
  bool _loading = true;
  bool _battleStarted = false;

  // Battle state
  int _qIndex = 0;
  int _playerScore = 0;
  int _robotScore = 0;
  int _playerStreak = 0;
  int _robotStreak = 0;
  String _playerAnswer = '';
  String _robotAnswer = '';
  bool _robotAnswered = false;
  Timer? _timer;
  Timer? _robotTimer;
  int _remaining = 12;
  bool _roundRevealed = false;
  bool _battleOver = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: widget.category, difficultyMin: 1, difficultyMax: 3, limit: 7,
      );
      if (mounted) setState(() { _questions = questions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _questions = widget.repository.questions.take(7).toList(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _robotTimer?.cancel();
    super.dispose();
  }

  void _selectRobot(_RobotProfile robot) {
    setState(() { _robot = robot; _battleStarted = true; });
    _startRound();
  }

  QuizQuestion get _q => _questions![_qIndex];

  void _startRound() {
    _timer?.cancel();
    _robotTimer?.cancel();
    setState(() { _remaining = 12; _playerAnswer = ''; _robotAnswer = ''; _robotAnswered = false; _roundRevealed = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) { _timer?.cancel(); _revealRound(); }
    });
    // Robot answers randomly between 2-10 seconds
    final robotDelay = Duration(seconds: 2 + Random().nextInt(8));
    _robotTimer = Timer(robotDelay, () {
      if (!mounted || _roundRevealed) return;
      final correct = Random().nextDouble() < _robot!.accuracy;
      setState(() {
        _robotAnswered = true;
        _robotAnswer = correct ? _q.correctAnswer : _q.answers.firstWhere((a) => a != _q.correctAnswer, orElse: () => _q.answers.first);
      });
    });
  }

  void _answer(String answer) {
    if (_playerAnswer.isNotEmpty || _roundRevealed) return;
    _timer?.cancel();
    setState(() => _playerAnswer = answer);
    Future.delayed(const Duration(milliseconds: 800), _revealRound);
  }

  void _revealRound() {
    if (_roundRevealed) return;
    _timer?.cancel();
    // Robot answer if not answered yet
    if (!_robotAnswered) {
      final correct = Random().nextDouble() < _robot!.accuracy;
      _robotAnswer = correct ? _q.correctAnswer : _q.answers.firstWhere((a) => a != _q.correctAnswer, orElse: () => _q.answers.first);
    }
    final playerCorrect = _playerAnswer == _q.correctAnswer;
    final robotCorrect = _robotAnswer == _q.correctAnswer;

    setState(() {
      _roundRevealed = true;
      if (playerCorrect) { _playerStreak++; _playerScore += 100 + (_playerStreak * 10).clamp(0, 50); }
      else _playerStreak = 0;
      if (robotCorrect) { _robotStreak++; _robotScore += 100 + (_robotStreak * 10).clamp(0, 50); }
      else _robotStreak = 0;
    });
  }

  void _nextRound() {
    if (_qIndex >= _questions!.length - 1) {
      setState(() => _battleOver = true);
      return;
    }
    setState(() => _qIndex++);
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_battleStarted) return _RobotSelectionScreen(robots: _robots, category: widget.category, onSelect: _selectRobot);
    if (_battleOver) return _BattleResultScreen(
      playerScore: _playerScore, robotScore: _robotScore,
      robotName: _robot!.name, robotEmoji: _robot!.emoji,
      onPlayAgain: () => Navigator.of(context).pop(),
    );

    return Scaffold(
      backgroundColor: AppTheme.page,
      appBar: AppBar(
        title: Text('${_robot!.emoji} ${_robot!.name} vs Sen'),
        backgroundColor: AppTheme.page,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scoreboard bar
            _ScoreBar(
              playerScore: _playerScore, robotScore: _robotScore,
              playerStreak: _playerStreak, robotStreak: _robotStreak,
              robotName: _robot!.name, robotEmoji: _robot!.emoji,
            ),
            const SizedBox(height: 12),
            // Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Text('Soru ${_qIndex + 1}/${_questions!.length}', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_remaining}s', style: TextStyle(fontWeight: FontWeight.w900, color: _remaining <= 3 ? AppTheme.red : AppTheme.ink)),
              ]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _remaining / 12,
                  minHeight: 6,
                  backgroundColor: AppTheme.line,
                  valueColor: AlwaysStoppedAnimation<Color>(_remaining <= 3 ? AppTheme.red : AppTheme.green),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Question
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_q.prompt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                        if (_roundRevealed && _q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_q.explanation, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final ans in _q.answers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BattleAnswerBtn(
                        answer: ans,
                        playerSelected: _playerAnswer == ans,
                        robotSelected: _roundRevealed && _robotAnswer == ans,
                        correct: _roundRevealed && ans == _q.correctAnswer,
                        disabled: _playerAnswer.isNotEmpty || _roundRevealed,
                        onTap: () => _answer(ans),
                      ),
                    ),
                  if (_robotAnswered && !_roundRevealed)
                    AppPanel(
                      child: Row(children: [
                        Text('${_robot!.emoji}', style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text('${_robot!.name} cevapladı!', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                      ]),
                    ),
                  if (_roundRevealed) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _nextRound,
                      icon: Icon(_qIndex >= _questions!.length - 1 ? Icons.flag_outlined : Icons.arrow_forward_rounded),
                      label: Text(_qIndex >= _questions!.length - 1 ? 'Sonucu Gör' : 'Sonraki'),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleAnswerBtn extends StatelessWidget {
  const _BattleAnswerBtn({
    required this.answer, required this.playerSelected, required this.robotSelected,
    required this.correct, required this.disabled, required this.onTap,
  });

  final String answer;
  final bool playerSelected, robotSelected, correct, disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = correct ? const Color(0xFFDFF2E9) : (playerSelected && !correct) ? const Color(0xFFFDECEA) : AppTheme.page;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: playerSelected || correct ? (correct ? AppTheme.green : AppTheme.red) : AppTheme.line, width: playerSelected || correct ? 2 : 1),
        ),
        child: Row(children: [
          Expanded(child: Text(answer, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (playerSelected) const Text('👤', style: TextStyle(fontSize: 18)),
          if (robotSelected) const Text(' 🤖', style: TextStyle(fontSize: 18)),
          if (correct) const Icon(Icons.check_circle_outline, color: AppTheme.green),
        ]),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.playerScore, required this.robotScore,
    required this.playerStreak, required this.robotStreak,
    required this.robotName, required this.robotEmoji,
  });

  final int playerScore, robotScore, playerStreak, robotStreak;
  final String robotName, robotEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.brown,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(child: Column(children: [
          const Text('👤 Sen', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('$playerScore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
          if (playerStreak > 1) Text('🔥 $playerStreak', style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ])),
        Container(height: 40, width: 1, color: Colors.white24),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
        Container(height: 40, width: 1, color: Colors.white24),
        Expanded(child: Column(children: [
          Text('$robotEmoji $robotName', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('$robotScore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
          if (robotStreak > 1) Text('🔥 $robotStreak', style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _RobotSelectionScreen extends StatelessWidget {
  const _RobotSelectionScreen({
    required this.robots, required this.category, required this.onSelect,
  });

  final List<_RobotProfile> robots;
  final String category;
  final void Function(_RobotProfile) onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.page,
      appBar: AppBar(title: const Text('Robot Rakip Seç'), backgroundColor: AppTheme.page, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Bir rakip seç ve yarışmaya başla!', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            ...robots.map((robot) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppPanel(
                child: Row(children: [
                  Text(robot.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(robot.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Başarı oranı: ${(robot.accuracy * 100).round()}%  ·  Elo: ${robot.elo}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: robot.accuracy, minHeight: 5,
                        backgroundColor: AppTheme.line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          robot.accuracy < 0.6 ? AppTheme.green : robot.accuracy < 0.8 ? const Color(0xFFBD7B2B) : AppTheme.red,
                        ),
                      ),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => onSelect(robot),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                    child: const Text('Seç'),
                  ),
                ]),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _BattleResultScreen extends StatelessWidget {
  const _BattleResultScreen({
    required this.playerScore, required this.robotScore,
    required this.robotName, required this.robotEmoji,
    required this.onPlayAgain,
  });

  final int playerScore, robotScore;
  final String robotName, robotEmoji;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final won = playerScore > robotScore;
    final draw = playerScore == robotScore;
    return Scaffold(
      backgroundColor: won ? AppTheme.green : draw ? const Color(0xFFBD7B2B) : AppTheme.red,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(won ? '🏆' : draw ? '🤝' : '😔', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                won ? 'Kazandın!' : draw ? 'Berabere!' : 'Kaybettin...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                won ? '$robotEmoji $robotName\'i yendin!' : draw ? 'İki taraf eşit bitti.' : '$robotEmoji $robotName seni geçti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(children: [
                    const Text('👤 Sen', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$playerScore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                  ]),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('–', style: TextStyle(color: Colors.white54, fontSize: 24))),
                  Column(children: [
                    Text('$robotEmoji $robotName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$robotScore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                  ]),
                ]),
              ),
              const SizedBox(height: 28),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: onPlayAgain,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.replay_outlined),
                label: const Text('Tekrar Oyna', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              )),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ana Sayfaya Dön', style: TextStyle(color: Colors.white70)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RobotProfile {
  const _RobotProfile(this.name, this.accuracy, this.elo, this.emoji);
  final String name;
  final double accuracy;
  final int elo;
  final String emoji;
}
