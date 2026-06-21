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
    return switch (_stage) {
      'quarter' => ku ? 'Çaryek Fînal' : 'Çeyrek Final',
      'semi' => ku ? 'Nîv Fînal' : 'Yarı Final',
      'final' => ku ? 'Fînal' : 'Final',
      'won' => ku ? 'Şampiyon!' : 'Şampiyon!',
      'lost' => ku ? 'Tû elendî' : 'Elendin',
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
        _stage = 'lost';
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
              fontWeight: FontWeight.w900,
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
    final isFinished = _stage == 'won' || _stage == 'lost';

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
                  fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  ku ? 'Te +200 Coin qezenc kir.' : '+200 Coin kazandın.',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
              ] else if (_stage == 'lost') ...[
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
                  style: TextStyle(color: AppTheme.textSub),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PlayerCard(name: ku ? 'Tu' : 'Sen', isUser: true),
                    const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textMuted)),
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
            fontWeight: FontWeight.w900,
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
    final q1 = ku ? 'Tu vs ${_bots[0]}' : 'Sen vs ${_bots[0]}';
    final q2 = '${_bots[1]} vs ${_bots[2]}';
    final q3 = '${_bots[3]} vs ${_bots[4]}';
    final q4 = '${_bots[5]} vs ${_bots[6]}';

    final s1Winner = _stage == 'quarter'
        ? '?'
        : (_stage == 'semi' || _stage == 'final' || _stage == 'won' ? (ku ? 'Tu' : 'Sen') : _bots[0]);
    final s2Winner = _stage == 'quarter' ? '?' : _botWinners[0];
    final s3Winner = _stage == 'quarter' ? '?' : _botWinners[1];
    final s4Winner = _stage == 'quarter' ? '?' : _botWinners[2];

    final f1Winner = (_stage == 'quarter' || _stage == 'semi')
        ? '?'
        : (_stage == 'final' || _stage == 'won' ? (ku ? 'Tu' : 'Sen') : (ku ? 'Elendî' : 'Elendin'));
    final f2Winner = (_stage == 'quarter' || _stage == 'semi')
        ? '?'
        : (_botWinners.length >= 2 ? _botWinners[1] : '?');

    final champion = _stage == 'won' ? (ku ? 'Tu' : 'Sen') : (_stage == 'lost' ? (ku ? 'Lîstikvanê din' : 'Diğer Oyuncu') : '?');

    return AppPanel(
      child: Column(
        children: [
          _BracketRoundRow(
            round: ku ? 'Çaryek Fînal' : 'Çeyrek Final',
            matches: [q1, q2, q3, q4],
          ),
          Icon(Icons.arrow_downward, color: AppTheme.textMutedColor(context), size: 16),
          _BracketRoundRow(
            round: ku ? 'Nîv Fînal' : 'Yarı Final',
            matches: [
              s1Winner != '?' && s2Winner != '?' ? '$s1Winner vs $s2Winner' : '?',
              s3Winner != '?' && s4Winner != '?' ? '$s3Winner vs $s4Winner' : '?'
            ],
          ),
          Icon(Icons.arrow_downward, color: AppTheme.textMutedColor(context), size: 16),
          _BracketRoundRow(
            round: ku ? 'Fînal' : 'Final',
            matches: [
              f1Winner != '?' && f2Winner != '?' ? '$f1Winner vs $f2Winner' : '?'
            ],
          ),
          Icon(Icons.arrow_downward, color: AppTheme.textMutedColor(context), size: 16),
          AppPanel(
            color: champion == (ku ? 'Tu' : 'Sen')
                ? AppTheme.gold.withValues(alpha: 0.15)
                : AppTheme.surfaceColor(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: AppTheme.gold, size: 24),
                const SizedBox(width: 8),
                Text(
                  '${ku ? "Şampiyon" : "Şampiyon"}: $champion',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: champion == (ku ? 'Tu' : 'Sen') ? AppTheme.gold : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          fontWeight: FontWeight.w900,
          color: isUser ? AppTheme.accent : AppTheme.textPrimaryColor(context),
        ),
      ),
    );
  }
}

class _BracketRoundRow extends StatelessWidget {
  const _BracketRoundRow({required this.round, required this.matches});

  final String round;
  final List<String> matches;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            round,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final match in matches)
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Text(
                      match,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
