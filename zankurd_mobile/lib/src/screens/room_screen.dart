import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'quiz_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    required this.repository,
    required this.initialRoom,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom initialRoom;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late GameRoom room = widget.initialRoom;
  bool ready = true;
  bool starting = false;
  bool quizOpened = false;
  StreamSubscription? _playersSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
    widget.repository.updateReady(room, ready);
  }

  void _startSubscriptions() {
    _playersSub = widget.repository.subscribeRoomPlayers(room).listen((p) {
      if (!mounted) return;
      setState(() => room = room.copyWith(players: p));
    });
    _statusSub = widget.repository.subscribeRoomStatus(room).listen((status) {
      if (!mounted) return;
      if (status == RoomStatus.active && !quizOpened) _navigateToQuiz();
      setState(() => room = room.copyWith(status: status));
    });
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _statusSub?.cancel();
    widget.repository.updateReady(room, false).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final sorted = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Back + copy row
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textSub,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${room.code} ${ku ? "kopî kir" : "kopyalandı"}.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      room.code,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Room hero
              AppPanel(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku ? 'Jûra Taybet' : 'Özel Oda',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Pill(label: room.code, icon: Icons.tag_rounded),
                        const SizedBox(width: 8),
                        _Pill(
                          label: room.category,
                          icon: Icons.category_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Players panel
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.group_outlined,
                          color: AppTheme.textSub,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ku ? 'Lîstikvan' : 'Oyuncular',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${sorted.length}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < sorted.length; i++)
                      _PlayerTile(rank: i + 1, player: sorted[i], isKu: ku),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ready + start panel
              AppPanel(
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        value: ready,
                        onChanged: (v) {
                          setState(() => ready = v);
                          widget.repository.updateReady(room, v);
                        },
                        title: Text(
                          ku ? 'Amade Me' : 'Hazırım',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          ku
                              ? 'Rewşa te ji lîstikvanên din re ciyê-rast nîşan dide.'
                              : 'Odadaki durumun diğer oyunculara canlı yansır.',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: ready && !starting ? _startGameHost : null,
                        icon: starting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          starting
                              ? (ku ? 'Tê Amadekirin' : 'Hazırlanıyor')
                              : (ku ? 'Yara Destpê Bike' : 'Yarışı Başlat'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startGameHost() async {
    setState(() => starting = true);
    try {
      await widget.repository.startGame(room);
      _navigateToQuiz();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'startGame failed');
      if (!mounted) return;
      setState(() => starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu
                ? 'Lîstik nehat destpêkirin. Dîsa bicerib.'
                : 'Oyun başlatılamadı. Tekrar dene.',
          ),
        ),
      );
    }
  }

  Future<void> _navigateToQuiz() async {
    if (quizOpened) return;
    setState(() {
      quizOpened = true;
      starting = true;
    });
    final questions = await widget.repository
        .loadRoomQuestions(room)
        .catchError((_) => widget.repository.questions);
    if (!mounted) return;
    setState(() => starting = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          repository: widget.repository,
          room: room,
          questions: questions.isEmpty
              ? widget.repository.questions
              : questions,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.rank,
    required this.player,
    required this.isKu,
  });

  final int rank;
  final Player player;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHi,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.correct.withValues(alpha: 0.15),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.correct,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  player.state,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${player.streak} ${isKu ? "zincîr" : "seri"}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
