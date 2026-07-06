import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/avatar_identity.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/test_environment.dart';
import 'quiz_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _radarController;
  late final AnimationController _pulseController;

  String? _statusTextKu;
  String? _statusTextTr;
  bool _found = false;
  String? _opponentName;
  String? _categoryName;
  int _myLevel = 1;
  AvatarIdentity _myIdentity = const AvatarIdentity();
  AvatarIdentity _opponentIdentity = const AvatarIdentity();
  int _opponentLevel = 1;
  String _myName = 'Lîstikvan';
  bool _isCancelled = false;

  StreamSubscription? _matchmakingSub;
  Timer? _statusTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (!isFlutterTestEnvironment) {
      _radarController.repeat();
      _pulseController.repeat(reverse: true);
    }

    _startMatchmaking();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _matchmakingSub?.cancel();
    _statusTimer?.cancel();
    widget.repository.cancelMatchmaking().catchError((_) {});
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    final ku = context.isKu;
    setState(() {
      _statusTextKu = 'Li hevrikekî tê gerîn...';
      _statusTextTr = 'Rakip aranıyor...';
      _found = false;
      _opponentIdentity = const AvatarIdentity();
      _secondsElapsed = 0;
    });

    try {
      final name = await widget.repository.getProfileName();
      final identity = await widget.repository.loadAvatarIdentity();
      final xpStore = await XPStore.load();
      final level = xpStore.currentLevel;
      if (_isCancelled || !mounted) return;

      setState(() {
        _myName = name;
        _myIdentity = identity;
        _myLevel = level;
      });

      // Load categories and pick a random one
      final categories = await widget.repository.loadCategories();
      if (_isCancelled || !mounted) return;

      final now = DateTime.now();
      final seed = now.year * 10000 + now.month * 100 + now.day;
      final category = categories.isNotEmpty
          ? categories[Random(seed).nextInt(categories.length)]
          : 'Ziman';
      _categoryName = category;

      // Load questions for the category (difficulty 1 to 5)
      final questions = await widget.repository.loadLevelQuestions(
        category: category,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 10,
      );
      if (_isCancelled || !mounted) return;

      // Join the matchmaking queue in Supabase
      final matchRes = await widget.repository.joinMatchmaking(category);
      if (_isCancelled || !mounted) return;

      if (matchRes['status'] == 'matched') {
        // Matched immediately!
        var matchedName = matchRes['opponent_name'] as String? ?? 'Raqîb';
        var opponentIdentity = const AvatarIdentity();
        final matchedLevel = max(1, level + Random().nextInt(3) - 1);
        final roomId = matchRes['room_id'] as String;
        final opponent = await _loadOpponentPlayer(
          roomId: roomId,
          category: category,
          currentName: name,
        );
        if (opponent != null) {
          matchedName = opponent.name;
          opponentIdentity = _identityFromPlayer(opponent);
        }

        await _onMatched(
          matchedName,
          matchedLevel,
          opponentIdentity,
          roomId,
          questions,
          category,
          ku,
        );
      } else {
        // Status is waiting. Let's subscribe to matchmaking_queue changes.
        _matchmakingSub = widget.repository.subscribeMatchmakingQueue().listen((
          entry,
        ) async {
          if (entry != null && entry['room_id'] != null) {
            _matchmakingSub?.cancel();
            _matchmakingSub = null;
            _statusTimer?.cancel();
            _statusTimer = null;

            final roomId = entry['room_id'] as String;
            // Fetch opponent display name
            String matchedName = ku ? 'Hevrik' : 'Rakip';
            var opponentIdentity = const AvatarIdentity();
            final opponent = await _loadOpponentPlayer(
              roomId: roomId,
              category: category,
              currentName: name,
            );
            if (opponent != null) {
              matchedName = opponent.name;
              opponentIdentity = _identityFromPlayer(opponent);
            }

            final matchedLevel = max(1, level + Random().nextInt(3) - 1);
            await _onMatched(
              matchedName,
              matchedLevel,
              opponentIdentity,
              roomId,
              questions,
              category,
              ku,
            );
          }
        });

        // Periodically update the status text and count to 30s
        _statusTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) async {
          _secondsElapsed++;
          if (_isCancelled || !mounted) {
            timer.cancel();
            return;
          }

          if (_secondsElapsed >= 30) {
            timer.cancel();
            _matchmakingSub?.cancel();
            _matchmakingSub = null;
            // Abort online queue
            await widget.repository.cancelMatchmaking().catchError((_) {});

            // Fallback to bot match simulation
            final botNames = [
              'Rojda',
              'Baran',
              'Dilan',
              'Hogir',
              'Azad',
              'Berfin',
              'Narin',
              'Sero',
              'Çiçek',
              'Welat',
            ];
            final matchedName = botNames[Random().nextInt(botNames.length)];
            final matchedLevel = max(1, level + Random().nextInt(5) - 2);

            await _onMatched(
              matchedName,
              matchedLevel,
              const AvatarIdentity(),
              null,
              questions,
              category,
              ku,
            );
          } else {
            setState(() {
              if (_secondsElapsed < 10) {
                _statusTextKu = 'Li hevrikekî tê gerîn...';
                _statusTextTr = 'Rakip aranıyor...';
              } else if (_secondsElapsed < 20) {
                _statusTextKu = 'Têkilî tê çêkirin...';
                _statusTextTr = 'Bağlantı kuruluyor...';
              } else {
                _statusTextKu = 'Hevrik nehat dîtin, bot tê amadekirin...';
                _statusTextTr = 'Rakip bulunamadı, bot hazırlanıyor...';
              }
            });
          }
        });
      }
    } catch (error) {
      if (_isCancelled || !mounted) return;
      _matchmakingSub?.cancel();
      _statusTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ku ? 'Li hevberdan bi ser neket.' : 'Eşleştirme başarısız oldu.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  AvatarIdentity _identityFromPlayer(Player player) => AvatarIdentity(
    iconId: player.avatarIcon,
    colorHex: player.avatarColor,
    photoUrl: player.avatarUrl,
    frameId: player.avatarFrame,
    showcaseTitle: player.showcaseTitle,
  );

  Future<Player?> _loadOpponentPlayer({
    required String roomId,
    required String category,
    required String currentName,
  }) async {
    try {
      final roomPlayers = await widget.repository.loadRoomPlayers(
        GameRoom(
          name: '',
          code: '',
          category: category,
          players: const [],
          status: RoomStatus.lobby,
          questionCount: 0,
        ).copyWith(id: roomId),
      );
      for (final player in roomPlayers) {
        if (player.name != currentName) return player;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onMatched(
    String matchedName,
    int matchedLevel,
    AvatarIdentity opponentIdentity,
    String? roomId,
    List<QuizQuestion> questions,
    String category,
    bool ku,
  ) async {
    setState(() {
      _found = true;
      _opponentName = matchedName;
      _opponentLevel = matchedLevel;
      _opponentIdentity = opponentIdentity;
      _statusTextKu = 'Hevrik hat dîtin: $matchedName!';
      _statusTextTr = 'Rakip bulundu: $matchedName!';
    });

    // Wait 1.5 seconds for victory transition animation
    await Future.delayed(const Duration(milliseconds: 1500));
    if (_isCancelled || !mounted) return;

    var room = widget.repository
        .createRoom(category: category)
        .copyWith(
          id: roomId,
          name: ku ? 'Şerê 1v1' : '1v1 Savaş',
          players: [
            Player(
              name: _myName,
              score: 0,
              state: 'Hazır',
              streak: 0,
              avatarIcon: _myIdentity.iconId,
              avatarColor: _myIdentity.colorHex,
              avatarUrl: _myIdentity.photoUrl,
              avatarFrame: _myIdentity.frameId,
              showcaseTitle: _myIdentity.showcaseTitle,
            ),
            Player(
              name: matchedName,
              score: 0,
              state: 'Hazır',
              streak: 0,
              avatarIcon: opponentIdentity.iconId,
              avatarColor: opponentIdentity.colorHex,
              avatarUrl: opponentIdentity.photoUrl,
              avatarFrame: opponentIdentity.frameId,
              showcaseTitle: opponentIdentity.showcaseTitle,
            ),
          ],
        );

    // Gerçek online eşleşmede iki oyuncu da AYNI soruları görmeli:
    // start_room_game odaya soru seti yazar, buradan okunur. Yerelde
    // yüklenen sorular yalnızca bot maçında / oda seti yoksa kullanılır.
    var matchQuestions = questions;
    if (roomId != null) {
      try {
        final roomQuestions = await widget.repository.loadRoomQuestions(room);
        if (roomQuestions.isNotEmpty) matchQuestions = roomQuestions;
      } catch (_) {}
      if (_isCancelled || !mounted) return;
    }
    room = room.copyWith(questionCount: matchQuestions.length);

    Navigator.of(context).pushReplacement(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: room,
          questions: matchQuestions,
          is1v1: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final status = ku
        ? (_statusTextKu ?? 'Tê gerîn...')
        : (_statusTextTr ?? 'Aranıyor...');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_categoryName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      ku
                          ? 'Kategorî: ${CategoryNames.localized(_categoryName!, true)}'
                          : 'Kategori: ${CategoryNames.localized(_categoryName!, false)}',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
                // Matching Animation View
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scanning background radar circles
                      for (double radius in [60.0, 110.0, 160.0, 210.0])
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulseValue = _pulseController.value;
                            return Container(
                              width: radius + (pulseValue * 15.0),
                              height: radius + (pulseValue * 15.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _found
                                      ? AppTheme.correct.withValues(
                                          alpha: (1.0 - (radius / 260.0)).clamp(
                                            0.02,
                                            0.4,
                                          ),
                                        )
                                      : AppTheme.accent.withValues(
                                          alpha: (1.0 - (radius / 260.0)).clamp(
                                            0.02,
                                            0.4,
                                          ),
                                        ),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                      // Rotating Sweep Indicator (only when searching)
                      if (!_found)
                        RotationTransition(
                          turns: _radarController,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  AppTheme.accent.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                                stops: const [0.15, 1.0],
                              ),
                            ),
                          ),
                        ),
                      // Avatars view
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // User Avatar
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.accent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                                child: PlayerAvatar(
                                  radius: 33,
                                  photoUrl: _myIdentity.photoUrl,
                                  iconId: _myIdentity.iconId,
                                  colorHex: _myIdentity.colorHex,
                                  frameId: _myIdentity.frameId,
                                  displayName: _myName,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _myName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ku ? 'Ast $_myLevel' : 'Seviye $_myLevel',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 32),
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Opponent Avatar (fades in or animated)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _found
                                        ? AppTheme.correct
                                        : Colors.white24,
                                    width: 3,
                                  ),
                                  boxShadow: _found
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.correct.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 15,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: _found
                                    ? PlayerAvatar(
                                        radius: 33,
                                        photoUrl: _opponentIdentity.photoUrl,
                                        iconId: _opponentIdentity.iconId,
                                        colorHex: _opponentIdentity.colorHex,
                                        frameId: _opponentIdentity.frameId,
                                        displayName: _opponentName,
                                      )
                                    : const CircleAvatar(
                                        backgroundColor: Color(0xFF1F1D2B),
                                        child: Icon(
                                          Icons.question_mark,
                                          color: Colors.white24,
                                          size: 38,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _found ? (_opponentName ?? '') : '?',
                                style: TextStyle(
                                  color: _found ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _found
                                      ? AppTheme.correct.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _found
                                      ? (ku
                                            ? 'Ast $_opponentLevel'
                                            : 'Seviye $_opponentLevel')
                                      : '?',
                                  style: TextStyle(
                                    color: _found
                                        ? AppTheme.correct
                                        : Colors.white24,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _found ? AppTheme.correct : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_found) ...[
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      _isCancelled = true;
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(ku ? 'Betal Bike' : 'İptal Et'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
