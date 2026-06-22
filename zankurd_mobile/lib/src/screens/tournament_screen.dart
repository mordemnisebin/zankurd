import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/confetti_overlay.dart';
import 'quiz_screen.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  static const String _prefStage = 'zankurd.tournament.stage';
  static const String _prefUserScore = 'zankurd.tournament.userScore';
  static const String _prefOpponentScore = 'zankurd.tournament.opponentScore';
  static const String _prefBotWinners = 'zankurd.tournament.botWinners';

  static const List<String> _bots = [
    'ZanînBot',
    'Zana',
    'KurdBot',
    'Rûbar',
    'Hêvî',
    'Diyar',
    'Boran',
  ];

  // Aşama: 'lobby' (katıl), 'quarter' (çeyrek), 'semi' (yarı), 'final' (final), 'won' (şampiyon), 'lost' (elendi)
  String _stage = 'lobby';
  int _userScore = 0;
  int _opponentScore = 0;
  List<String> _botWinners = [];
  bool _loading = true;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stage = prefs.getString(_prefStage) ?? 'lobby';
      _userScore = prefs.getInt(_prefUserScore) ?? 0;
      _opponentScore = prefs.getInt(_prefOpponentScore) ?? 0;
      _botWinners = prefs.getStringList(_prefBotWinners) ?? [];
      _loading = false;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStage, _stage);
    await prefs.setInt(_prefUserScore, _userScore);
    await prefs.setInt(_prefOpponentScore, _opponentScore);
    await prefs.setStringList(_prefBotWinners, _botWinners);
  }

  Future<void> _startTournament() async {
    setState(() {
      _stage = 'quarter';
      _userScore = 0;
      _opponentScore = 0;
      // Çeyrek final bot eşleşmeleri için kazananları simüle et
      final rng = math.Random();
      _botWinners = [
        _bots[rng.nextBool() ? 1 : 2], // Match 2 winner
        _bots[rng.nextBool() ? 3 : 4], // Match 3 winner
        _bots[rng.nextBool() ? 5 : 6], // Match 4 winner
      ];
    });
    await _saveState();
  }

  Future<void> _resetTournament() async {
    setState(() {
      _stage = 'lobby';
      _userScore = 0;
      _opponentScore = 0;
      _botWinners = [];
      _showConfetti = false;
    });
    await _saveState();
  }

  String get _currentOpponent {
    return switch (_stage) {
      'quarter' => _bots[0],
      'semi' => _botWinners.isNotEmpty ? _botWinners[0] : 'Yarı Final Rakibi',
      'final' => _botWinners.length >= 2 ? _botWinners[1] : 'Final Rakibi',
      _ => '',
    };
  }

  String _stageLabel(bool ku) {
    if (_stage.startsWith('lost')) {
      return ku ? 'Tû elendî!' : 'Elendin!';
    }
    return switch (_stage) {
      'quarter' => ku ? 'Çaryek Fînal' : 'Çeyrek Final',
      'semi' => ku ? 'Nîv Fînal' : 'Yarı Final',
      'final' => ku ? 'Fînal' : 'Final',
      'won' => ku ? 'Şampiyon!' : 'Şampiyon!',
      _ => '',
    };
  }

  Future<void> _playMatch() async {
    final opponent = _currentOpponent;
    final ku = context.isKu;

    // Turnuva için 10 adet orta/zor soru yükle
    final questions = await widget.repository
        .loadLevelQuestions(category: 'Ziman', difficultyMin: 2, difficultyMax: 4, limit: 10)
        .catchError((_) => widget.repository.questions.take(10).toList());

    final room = GameRoom(
      id: null,
      code: 'TRN-${_stage.toUpperCase()}',
      name: ku ? 'Kûpa Zanînê' : 'Bilgi Kupası',
      category: 'Ziman',
      questionCount: 10,
      status: RoomStatus.active,
      players: [
        Player(name: ku ? 'Tu' : 'Sen', score: 0, state: 'Hazır', streak: 0),
        Player(name: opponent, score: 0, state: 'Hazır', streak: 0),
      ],
    );

    if (!mounted) return;

    // Oyunu başlat
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: room,
          questions: questions,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final score = result['score'] as int? ?? 0;
    final rng = math.Random();
    // Rakip bot skoru (500 - 950 arası rastgele)
    final botScore = 500 + rng.nextInt(450);

    setState(() {
      _userScore = score;
      _opponentScore = botScore;
      final win = _userScore >= _opponentScore;

      if (win) {
        if (_stage == 'quarter') {
          _stage = 'semi';
          // Yarı finalin diğer kazananını simüle et
          _botWinners = [_botWinners[0], _botWinners[rng.nextBool() ? 1 : 2]];
        } else if (_stage == 'semi') {
          _stage = 'final';
        } else if (_stage == 'final') {
          _stage = 'won';
          _showConfetti = true;
          context.read<SoundProvider>().playWin();
          widget.repository.addCoins(200, 'tournament_champion');
        }
      } else {
        _stage = 'lost_$_stage';
        context.read<SoundProvider>().playWrong();
      }
    });

    await _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      appBar: AppBar(
        title: Text(ku ? 'Turnuva' : 'Turnuva Modu'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: Stack(
          children: [
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            else
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_stage == 'lobby') _buildLobby(ku) else _buildBracket(ku),
                  ],
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
    );
  }

  Widget _buildLobby(bool ku) {
    return AppPanel(
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.gold,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            ku ? 'Kûpa Zanînê' : 'ZanKurd Kupası',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ku
                ? 'Bi 8 lîstikvanan re turnuvayê dest pê bike. Botan eledar bike û kûpayê qezenc bike!'
                : '8 oyunculu eleme turnuvasına katıl. Bot rakipleri eleyerek kupayı kaldır!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSubColor(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          AppPanel(
            color: AppTheme.gold.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: AppTheme.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  ku ? 'Xelata Mezin: 200 Coin' : 'Büyük Ödül: 200 Coin',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _startTournament,
              icon: Icon(Icons.play_arrow_rounded),
              label: Text(ku ? 'Têkeve Turnuvayê' : 'Turnuvaya Başla'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBracket(bool ku) {
    final opponent = _currentOpponent;
    final isFinished = _stage == 'won' || _stage.startsWith('lost');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tur durumu kartı
        AppPanel(
          child: Column(
            children: [
              Text(
                isFinished ? (ku ? 'Turnuva Qediya' : 'Turnuva Bitti') : _stageLabel(ku),
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              if (_stage == 'won') ...[
                Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 64),
                const SizedBox(height: 8),
                Text(
                  ku ? 'Şampiyonê Turnuvayê!' : 'Turnuva Şampiyonu!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  ku ? 'Te +200 Coin qezenc kir.' : '+200 Coin kazandın.',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
              ] else if (_stage.startsWith('lost')) ...[
                Icon(Icons.sentiment_very_dissatisfied_rounded, color: AppTheme.wrong, size: 64),
                const SizedBox(height: 8),
                Text(
                  ku ? 'Te li hember $opponent winda kir.' : '$opponent karşısında elendin.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  '${ku ? "Skora Te" : "Skorun"}: $_userScore | $opponent: $_opponentScore',
                  style: TextStyle(color: AppTheme.textSubOf(context)),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PlayerCard(name: ku ? 'Tu' : 'Sen', isUser: true),
                    const Text('VS', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                    _PlayerCard(name: opponent, isUser: false),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _playMatch,
                    icon: Icon(Icons.sports_esports_outlined),
                    label: Text(ku ? 'Pêşbirkê Dest Pê Bike' : 'Maçı Başlat'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Eşleşme Şeması (Braket Görseli)
        Text(
          ku ? 'Braketa Turnuvayê' : 'Turnuva Şeması',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 10),

        _buildBracketVisual(ku),

        const SizedBox(height: 24),
        if (isFinished)
          OutlinedButton.icon(
            onPressed: _resetTournament,
            icon: Icon(Icons.refresh_rounded),
            label: Text(ku ? 'Turnuvayek Nû' : 'Yeni Turnuva'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_rounded),
            label: Text(ku ? 'Vegere' : 'Geri Dön'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
      ],
    );
  }

  Widget _buildBracketVisual(bool ku) {
    // Quarter Finals
    final userOpponent = _bots[0];
    final q1Player1 = ku ? 'Tu' : 'Sen';
    final q1Player2 = userOpponent;
    int? q1Score1;
    int? q1Score2;
    if (_stage != 'quarter' && _stage != 'lobby') {
      q1Score1 = _userScore;
      q1Score2 = _opponentScore;
    }

    final q2Player1 = _bots[1];
    final q2Player2 = _bots[2];
    final q2Winner = _botWinners.isNotEmpty ? _botWinners[0] : '';
    final q2Score1 = q2Winner == q2Player1 ? 820 : 680;
    final q2Score2 = q2Winner == q2Player2 ? 820 : 680;

    final q3Player1 = _bots[3];
    final q3Player2 = _bots[4];
    final q3Winner = _botWinners.length >= 2 ? _botWinners[1] : '';
    final q3Score1 = q3Winner == q3Player1 ? 790 : 710;
    final q3Score2 = q3Winner == q3Player2 ? 790 : 710;

    final q4Player1 = _bots[5];
    final q4Player2 = _bots[6];
    final q4Winner = _botWinners.length >= 3 ? _botWinners[2] : '';
    final q4Score1 = q4Winner == q4Player1 ? 850 : 640;
    final q4Score2 = q4Winner == q4Player2 ? 850 : 640;

    // Semi Finals
    final s1Player1 = (_stage == 'quarter' || _stage == 'lobby') ? '?' : (_stage == 'lost_quarter' ? userOpponent : (ku ? 'Tu' : 'Sen'));
    final s1Player2 = (_stage == 'quarter' || _stage == 'lobby') ? '?' : q2Winner;
    int? s1Score1;
    int? s1Score2;
    if (_stage != 'quarter' && _stage != 'lobby' && _stage != 'lost_quarter' && _stage != 'semi') {
      s1Score1 = _userScore;
      s1Score2 = _opponentScore;
    }

    final s2Player1 = (_stage == 'quarter' || _stage == 'lobby') ? '?' : q3Winner;
    final s2Player2 = (_stage == 'quarter' || _stage == 'lobby') ? '?' : q4Winner;
    final s2Winner = (_stage != 'quarter' && _stage != 'lobby' && _stage != 'lost_quarter' && _botWinners.length >= 2) ? _botWinners[1] : '';
    final s2Score1 = s2Winner == s2Player1 ? 840 : 730;
    final s2Score2 = s2Winner == s2Player2 ? 840 : 730;

    // Final
    final f1Player1 = (_stage == 'quarter' || _stage == 'semi' || _stage == 'lost_quarter' || _stage == 'lost_semi' || _stage == 'lobby') 
        ? '?' 
        : (ku ? 'Tu' : 'Sen');
    final f1Player2 = (_stage == 'quarter' || _stage == 'semi' || _stage == 'lost_quarter' || _stage == 'lost_semi' || _stage == 'lobby')
        ? '?'
        : s2Winner;
    int? fScore1;
    int? fScore2;
    if (_stage == 'won' || _stage == 'lost_final') {
      fScore1 = _userScore;
      fScore2 = _opponentScore;
    }

    final champion = _stage == 'won' 
        ? (ku ? 'Tu' : 'Sen') 
        : (_stage == 'lost_final' ? f1Player2 : '?');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        height: 340,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column 1: Quarter Finals
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _MatchCard(player1: q1Player1, player2: q1Player2, score1: q1Score1, score2: q1Score2, isActive: _stage == 'quarter', isKu: ku),
                const SizedBox(height: 20),
                _MatchCard(player1: q2Player1, player2: q2Player2, score1: _stage != 'quarter' && _stage != 'lobby' ? q2Score1 : null, score2: _stage != 'quarter' && _stage != 'lobby' ? q2Score2 : null, isKu: ku),
                const SizedBox(height: 20),
                _MatchCard(player1: q3Player1, player2: q3Player2, score1: _stage != 'quarter' && _stage != 'lobby' ? q3Score1 : null, score2: _stage != 'quarter' && _stage != 'lobby' ? q3Score2 : null, isKu: ku),
                const SizedBox(height: 20),
                _MatchCard(player1: q4Player1, player2: q4Player2, score1: _stage != 'quarter' && _stage != 'lobby' ? q4Score1 : null, score2: _stage != 'quarter' && _stage != 'lobby' ? q4Score2 : null, isKu: ku),
              ],
            ),
            // Connector 1
            CustomPaint(
              size: const Size(40, 300),
              painter: BracketConnectorPainter(type: 1, color: AppTheme.borderColor(context)),
            ),
            // Column 2: Semi Finals
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _MatchCard(player1: s1Player1, player2: s1Player2, score1: s1Score1, score2: s1Score2, isActive: _stage == 'semi', isKu: ku),
                const SizedBox(height: 100),
                _MatchCard(player1: s2Player1, player2: s2Player2, score1: _stage != 'quarter' && _stage != 'lobby' && _stage != 'lost_quarter' && _stage != 'semi' ? s2Score1 : null, score2: _stage != 'quarter' && _stage != 'lobby' && _stage != 'lost_quarter' && _stage != 'semi' ? s2Score2 : null, isKu: ku),
              ],
            ),
            // Connector 2
            CustomPaint(
              size: const Size(40, 300),
              painter: BracketConnectorPainter(type: 2, color: AppTheme.borderColor(context)),
            ),
            // Column 3: Final
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                _MatchCard(player1: f1Player1, player2: f1Player2, score1: fScore1, score2: fScore2, isActive: _stage == 'final', isKu: ku),
              ],
            ),
            // Connector 3
            CustomPaint(
              size: const Size(40, 300),
              painter: BracketConnectorPainter(type: 3, color: AppTheme.borderColor(context)),
            ),
            // Column 4: Champion
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                Container(
                  width: 140,
                  height: 60,
                  decoration: BoxDecoration(
                    color: champion == (ku ? 'Tu' : 'Sen')
                        ? AppTheme.gold.withValues(alpha: 0.12)
                        : AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: champion == (ku ? 'Tu' : 'Sen') ? AppTheme.gold : AppTheme.borderColor(context),
                      width: champion == (ku ? 'Tu' : 'Sen') ? 1.8 : 1,
                    ),
                    boxShadow: champion == (ku ? 'Tu' : 'Sen') ? AppTheme.elevatedShadow(AppTheme.gold) : AppTheme.cardShadow(context),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          champion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: champion == (ku ? 'Tu' : 'Sen') ? AppTheme.gold : AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.name, required this.isUser});

  final String name;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.borderColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUser ? AppTheme.accent : AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isUser ? AppTheme.accent : AppTheme.textPrimaryColor(context),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.player1,
    required this.player2,
    this.score1,
    this.score2,
    this.isActive = false,
    this.isKu = false,
  });

  final String player1;
  final String player2;
  final int? score1;
  final int? score2;
  final bool isActive;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final borderCol = isActive ? AppTheme.accent : AppTheme.borderColor(context);
    final bgCol = isActive
        ? AppTheme.accent.withValues(alpha: 0.06)
        : AppTheme.surfaceColor(context);

    final isWinner1 = score1 != null && score2 != null && score1! >= score2!;
    final isWinner2 = score1 != null && score2 != null && score2! > score1!;

    return Container(
      width: 140,
      height: 60,
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: isActive ? 1.8 : 1),
        boxShadow: isActive ? AppTheme.elevatedShadow(AppTheme.accent) : AppTheme.cardShadow(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPlayerRow(context, player1, score1, isWinner1, isWinner2),
          Divider(height: 1, color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
          _buildPlayerRow(context, player2, score2, isWinner2, isWinner1),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(BuildContext context, String name, int? score, bool isWinner, bool isOpponentWinner) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: isWinner ? FontWeight.w700 : FontWeight.w600,
      color: isWinner
          ? AppTheme.textPrimaryColor(context)
          : (isOpponentWinner ? AppTheme.textMutedColor(context) : AppTheme.textSubColor(context)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 4),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isWinner ? AppTheme.gold : AppTheme.textMutedColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BracketConnectorPainter extends CustomPainter {
  BracketConnectorPainter({required this.type, required this.color});
  final int type; // 1: double fork (quarter to semi), 2: single large fork (semi to final), 3: straight line (final to champion)
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final w = size.width;
    
    if (type == 1) {
      // Two forks.
      // Fork 1: starts at y=30 and y=110, connects to y=70.
      _drawFork(canvas, paint, 0.0, 30.0, 110.0, 70.0, w);
      // Fork 2: starts at y=190 and y=270, connects to y=230.
      _drawFork(canvas, paint, 0.0, 190.0, 270.0, 230.0, w);
    } else if (type == 2) {
      // One large fork.
      // Starts at y=70 and y=230, connects to y=150.
      _drawFork(canvas, paint, 0.0, 70.0, 230.0, 150.0, w);
    } else if (type == 3) {
      // Straight line at y=150
      canvas.drawLine(const Offset(0, 150), Offset(w, 150), paint);
    }
  }

  void _drawFork(Canvas canvas, Paint paint, double xStart, double y1, double y2, double yMid, double width) {
    final halfW = width / 2;
    // Draw two horizontal lines from start to half width
    canvas.drawLine(Offset(xStart, y1), Offset(xStart + halfW, y1), paint);
    canvas.drawLine(Offset(xStart, y2), Offset(xStart + halfW, y2), paint);
    // Draw vertical line connecting them
    canvas.drawLine(Offset(xStart + halfW, y1), Offset(xStart + halfW, y2), paint);
    // Draw horizontal line from midpoint to end
    canvas.drawLine(Offset(xStart + halfW, yMid), Offset(xStart + width, yMid), paint);
  }

  @override
  bool shouldRepaint(covariant BracketConnectorPainter oldDelegate) =>
      type != oldDelegate.type || color != oldDelegate.color;
}
