import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/styled_button.dart';
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

  /// Realtime yetersiz kalırsa devreye giren polling fallback.
  /// Yalnızca lobide en az 2 oyuncu görülünce durur; aksi halde devam eder.
  Timer? _pollTimer;
  int _pollCount = 0;
  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollsBeforePause = 20; // ~60s, yalnızca >=2 oyuncu varken

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
    _startPolling();
    widget.repository.updateReady(room, ready);
  }

  void _startSubscriptions() {
    _playersSub = widget.repository.subscribeRoomPlayers(room).listen((p) {
      if (!mounted) return;
      _applyPlayerList(p);
    });
    _statusSub = widget.repository.subscribeRoomStatus(room).listen((status) {
      if (!mounted) return;
      if (status == RoomStatus.active && !quizOpened) _navigateToQuiz();
      setState(() => room = room.copyWith(status: status));
    });
  }

  void _applyPlayerList(List<Player> players) {
    if (!mounted) return;
    setState(() => room = room.copyWith(players: players));
    _syncPollingForLobby(players.length);
  }

  /// Lobide 2 oyuncu görülene kadar polling açık kalır; eksik realtime
  /// yanıtlarında host takılı kalmaz.
  void _syncPollingForLobby(int playerCount) {
    if (quizOpened) {
      _pausePolling();
      return;
    }
    if (playerCount >= 2) {
      _pausePolling();
      _pollCount = 0;
      return;
    }
    if (_pollTimer == null) {
      _startPolling();
    }
  }

  /// Realtime yetersizse host, 2. oyuncuyu polling ile görür.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollPlayersOnce());
  }

  Future<void> _pollPlayersOnce() async {
    if (!mounted || quizOpened) return;
    try {
      final players = await widget.repository.loadRoomPlayers(room);
      if (!mounted) return;
      _applyPlayerList(players);
      if (players.length < 2) {
        _pollCount = 0;
        return;
      }
      _pollCount++;
      if (_pollCount >= _maxPollsBeforePause) {
        _pausePolling();
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted && !quizOpened && room.players.length >= 2) {
            _startPolling();
          }
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'loadRoomPlayers poll failed');
    }
  }

  void _pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _statusSub?.cancel();
    _pausePolling();
    widget.repository.updateReady(room, false).catchError((_) {});
    super.dispose();
  }

  Future<void> _copyRoomCode(BuildContext context, bool ku) async {
    await Clipboard.setData(ClipboardData(text: room.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${room.code} ${ku ? "hat kopîkirin" : "kopyalandı"}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final sorted = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final currentUserId = widget.repository.currentUserId;
    final isHost = room.hostId == null || room.hostId == currentUserId;
    final canStart = ready && !starting && room.players.length >= 2;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _copyRoomCode(context, ku),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      room.code,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSubColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),

              // Brand hero — deep green (not generic blue Material)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Stack(
                  children: [
                    AppPanel(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.secondaryAccent,
                          AppTheme.bgDeep,
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ku ? 'Odeya Taybet' : 'Özel Oda',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            room.name,
                            style: AppTypography.heading1.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _Pill(label: room.code, icon: Icons.tag_rounded),
                              _Pill(
                                label: room.category,
                                icon: Icons.category_outlined,
                              ),
                              if (isHost)
                                _Pill(
                                  label: ku ? 'Mêvandar' : 'Ev sahibi',
                                  icon: Icons.star_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Large invite code for sharing
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _copyRoomCode(context, ku),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ku
                                                ? 'Koda odeyê parve bike'
                                                : 'Oda kodunu paylaş',
                                            style: AppTypography.caption
                                                .copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            room.code,
                                            style: AppTypography.heading1
                                                .copyWith(
                                              color: AppTheme.gold,
                                              letterSpacing: 2,
                                              fontSize: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.copy_all_rounded,
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: const KilimPatternPainter(
                            drawPattern: true,
                            color: Colors.white,
                            opacity: 0.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          color: AppTheme.textSubColor(context),
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          ku ? 'Lîstikvan' : 'Oyuncular',
                          style: AppTypography.heading2.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${sorted.length}',
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                      ],
                    ),
                    if (room.players.length < 2) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.primaryGradientStart
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              ku
                                  ? 'Lîsteya lîstikvanan tê nûvekirin…'
                                  : 'Oyuncu listesi güncelleniyor…',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (sorted.isEmpty)
                      Text(
                        ku
                            ? 'Hîn lîstikvan tune.'
                            : 'Henüz oyuncu yok.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      )
                    else
                      for (var i = 0; i < sorted.length; i++)
                        _PlayerTile(
                          rank: i + 1,
                          player: sorted[i],
                          isKu: ku,
                          isHost: room.hostId != null &&
                              sorted[i].id == room.hostId,
                        ),
                    if (room.players.length < 2) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppTheme.gold,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                ku
                                    ? 'Hevalê xwe bi kodê vexwîne — herî kêm 2 lîstikvan pêwîst e.'
                                    : 'Arkadaşını kodla davet et — en az 2 oyuncu gerekir.',
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w600,
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
              const SizedBox(height: AppSpacing.cardGap),

              AppPanel(
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        value: ready,
                        activeThumbColor: AppTheme.primaryGradientStart,
                        activeTrackColor: AppTheme.primaryGradientStart
                            .withValues(alpha: 0.45),
                        onChanged: (v) {
                          setState(() => ready = v);
                          widget.repository.updateReady(room, v);
                        },
                        title: Text(
                          ku ? 'Amade Me' : 'Hazırım',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          ku
                              ? 'Rewşa te ji lîstikvanên din re ciyê-rast nîşan dide.'
                              : 'Odadaki durumun diğer oyunculara canlı yansır.',
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (room.players.length < 2) ...[
                      Text(
                        ku
                            ? 'Ji bo destpêkirina pêşbirkê herî kêm 2 lîstikvan divên.'
                            : 'Yarışı başlatmak için en az 2 oyuncu olmalıdır.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.wrong,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    if (isHost) ...[
                      GeometricGradientButton(
                        label: starting
                            ? (ku ? 'Tê Amadekirin' : 'Hazırlanıyor')
                            : (ku
                                ? 'Pêşbirkê Dest Pê Bike'
                                : 'Yarışı Başlat'),
                        icon: Icons.play_arrow_rounded,
                        isLoading: starting,
                        onPressed: canStart ? _startGameHost : null,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGradientStart
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppTheme.primaryGradientStart
                                .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryGradientStart,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                ku
                                    ? 'Li benda mêvandar e... Lîstik dê ji aliyê damezrîner ve bê destpêkirin.'
                                    : 'Ev sahibi bekleniyor... Yarışma, odayı kuran kişi tarafından başlatılacaktır.',
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.primaryGradientStart,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                ? 'Lîstik nehat destpêkirin. Dîsa biceribîne.'
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
      AppRoute.to(
        QuizScreen(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: AppSpacing.xxs + 1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
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
    this.isHost = false,
  });

  final int rank;
  final Player player;
  final bool isKu;
  final bool isHost;

  /// Depodan gelen durum metni Türkçe sabittir; KU modunda burada çevrilir.
  String _localizedState(String state) {
    if (!isKu) return state;
    return switch (state) {
      'Hazır' => 'Amade',
      'Bekliyor' => 'Li bendê',
      'Cevapladı' => 'Bersivand',
      _ => state,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isHost
            ? Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
              )
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.secondaryAccent.withValues(alpha: 0.2),
            child: Text(
              '$rank',
              style: AppTypography.caption.copyWith(
                color: AppTheme.secondaryAccent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          isKu ? 'Host' : 'Host',
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.gold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _localizedState(player.state),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
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
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${player.streak} ${isKu ? "zincîr" : "seri"}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
