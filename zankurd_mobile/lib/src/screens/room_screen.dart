import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
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

    // Initial ready state will be sent
    widget.repository.updateReady(room, ready);
  }

  void _startSubscriptions() {
    _playersSub = widget.repository.subscribeRoomPlayers(room).listen((
      players,
    ) {
      if (!mounted) return;
      setState(() => room = room.copyWith(players: players));
    });

    _statusSub = widget.repository.subscribeRoomStatus(room).listen((status) {
      if (!mounted) return;
      if (status == RoomStatus.active && !quizOpened) {
        _navigateToQuiz();
      }
      setState(() => room = room.copyWith(status: status));
    });
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _statusSub?.cancel();
    // Try to mark not ready when leaving
    widget.repository.updateReady(room, false).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oda'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${room.code} kopyalandı.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            AppPanel(
              color: AppTheme.brown,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Özel oda',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _InfoPill(label: room.code, icon: Icons.tag_rounded),
                      const SizedBox(width: 8),
                      _InfoPill(
                        label: room.category,
                        icon: Icons.category_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Oyuncular',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < sortedPlayers.length; i++)
                    _PlayerTile(rank: i + 1, player: sortedPlayers[i]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      value: ready,
                      onChanged: (value) {
                        setState(() => ready = value);
                        widget.repository.updateReady(room, value);
                      },
                      title: const Text(
                        'Hazırım',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Odadaki durumun diğer oyunculara canlı yansır.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: ready && !starting ? _startGameHost : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(starting ? 'Hazırlanıyor' : 'Yarışı Başlat'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGameHost() async {
    setState(() => starting = true);
    try {
      await widget.repository.startGame(room);
      _navigateToQuiz();
    } catch (_) {
      if (!mounted) return;
      setState(() => starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun başlatılamadı. Tekrar dene.')),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.rank, required this.player});

  final int rank;
  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.page,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE8F3EE),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.green,
                fontWeight: FontWeight.w900,
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  player.state,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${player.streak} seri',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
