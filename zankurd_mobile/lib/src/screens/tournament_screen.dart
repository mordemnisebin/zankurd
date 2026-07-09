import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/tournament.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/kilim_pattern_painter.dart';
import 'quiz_screen.dart';

/// Günlük turnuva: 16 oyuncu, 4 tur, tur başına 4 soruluk maç.
/// Lobi → şema → maç (bot yarışı quiz) → tur ilerlemesi.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  static const _botNames = [
    'Azad', 'Rojîn', 'Berfîn', 'Zana', 'Dilan',
    'Şêrko', 'Evîn', 'Baran', 'Hêlîn', 'Serhat',
    'Xezal', 'Mîran', 'Delal', 'Welat', 'Nûdem',
  ];

  TournamentBracket? _bracket;
  List<TournamentStandings> _standings = const [];
  bool _loading = true;
  bool _hasError = false;
  bool _matchLoading = false;
  String _userName = '';
  static const _userId = 'user';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final bracket = await widget.repository.loadTournamentBracket();
      final standings = await widget.repository.loadTournamentStandings();
      if (!mounted) return;
      setState(() {
        // Oyuncu yerleştirilmemiş (boş) şema lobi sayılır.
        _bracket = (bracket != null && _isSeeded(bracket)) ? bracket : null;
        _standings = standings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  bool _isSeeded(TournamentBracket bracket) =>
      bracket.rounds.isNotEmpty &&
      bracket.rounds.first.matches.any((m) => m.playerOneId.isNotEmpty);

  Future<void> _startTournament() async {
    String name = '';
    try {
      name = await widget.repository.getProfileName();
    } catch (_) {}
    if (!mounted) return;
    final ku = context.isKu;
    _userName = name.isEmpty ? (ku ? 'Tu' : 'Sen') : name;

    final rounds = TournamentConfig.generateBracket();
    final firstRound = rounds.first;
    final seededMatches = <TournamentMatch>[];
    var botIndex = 0;
    for (var i = 0; i < firstRound.matches.length; i++) {
      final match = firstRound.matches[i];
      if (i == 0) {
        seededMatches.add(
          match.copyWith(
            playerOneId: _userId,
            playerOneName: _userName,
            playerTwoId: 'bot_$botIndex',
            playerTwoName: _botNames[botIndex],
            status: 'active',
          ),
        );
        botIndex++;
      } else {
        seededMatches.add(
          match.copyWith(
            playerOneId: 'bot_$botIndex',
            playerOneName: _botNames[botIndex],
            playerTwoId: 'bot_${botIndex + 1}',
            playerTwoName: _botNames[botIndex + 1],
          ),
        );
        botIndex += 2;
      }
    }

    setState(() {
      _bracket = TournamentBracket(
        tournamentId: 'daily',
        userId: _userId,
        rounds: [
          firstRound.copyWith(matches: seededMatches, status: 'active'),
          ...rounds.skip(1),
        ],
        createdAt: DateTime.now(),
      );
    });
    // Sunucuya kaydet; hata sessizce yutulur (yerel oyun sürer).
    widget.repository
        .saveTournamentProgress('r16', 0, 0, const [])
        .catchError((_) => false);
    widget.repository
        .logAnalyticsEvent('tournament_started', null)
        .catchError((_) => false);
  }

  TournamentMatch? get _userMatch {
    final bracket = _bracket;
    if (bracket == null || bracket.status != 'active') return null;
    if (bracket.currentRound >= bracket.rounds.length) return null;
    final round = bracket.rounds[bracket.currentRound];
    for (final match in round.matches) {
      if ((match.playerOneId == _userId || match.playerTwoId == _userId) &&
          match.status != 'completed') {
        return match;
      }
    }
    return null;
  }

  Future<void> _startMatch() async {
    if (_matchLoading) return;
    setState(() => _matchLoading = true);
    try {
      var questions = await widget.repository.loadQuestions(
        categoryId: TournamentConfig.tournamentCategory,
        limit: TournamentConfig.questionsPerMatch,
      );
      if (questions.isEmpty) {
        questions = widget.repository.questions
            .take(TournamentConfig.questionsPerMatch)
            .toList();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: widget.repository.createRoom(),
            questions: questions,
            botRace: true,
          ),
        ),
      );
      if (!mounted) return;
      _advanceRound();
    } finally {
      if (mounted) setState(() => _matchLoading = false);
    }
  }

  /// Maç sonrası turu kapatır ve bir üst tura geçer.
  /// Not: Gerçek skor bağlantısı G3'te; şimdilik oyuncu tur atlar.
  void _advanceRound() {
    final bracket = _bracket;
    if (bracket == null) return;
    final roundIndex = bracket.currentRound;
    final round = bracket.rounds[roundIndex];

    // Bu turun tüm maçlarını sonuçlandır (kullanıcı + bot simülasyonu).
    final completed = round.matches.map((m) {
      final winnerId = m.playerOneId == _userId || m.playerTwoId == _userId
          ? _userId
          : m.playerOneId;
      return m.copyWith(status: 'completed', winnerId: winnerId);
    }).toList();

    final winners = completed
        .map(
          (m) => m.winnerId == m.playerOneId
              ? (id: m.playerOneId, name: m.playerOneName)
              : (id: m.playerTwoId, name: m.playerTwoName),
        )
        .toList();

    final rounds = [...bracket.rounds];
    rounds[roundIndex] = round.copyWith(
      matches: completed,
      status: 'completed',
    );

    final isFinal = roundIndex == rounds.length - 1;
    if (!isFinal) {
      // Kazananları bir sonraki turun maçlarına yerleştir.
      final next = rounds[roundIndex + 1];
      final nextMatches = <TournamentMatch>[];
      for (var i = 0; i < next.matches.length; i++) {
        final p1 = winners[i * 2];
        final p2 = winners[i * 2 + 1];
        nextMatches.add(
          next.matches[i].copyWith(
            playerOneId: p1.id,
            playerOneName: p1.name,
            playerTwoId: p2.id,
            playerTwoName: p2.name,
            status: p1.id == _userId || p2.id == _userId
                ? 'active'
                : 'pending',
          ),
        );
      }
      rounds[roundIndex + 1] = next.copyWith(
        matches: nextMatches,
        status: 'active',
      );
    }

    setState(() {
      _bracket = bracket.copyWith(
        rounds: rounds,
        currentRound: isFinal ? roundIndex : roundIndex + 1,
        status: isFinal ? 'won' : 'active',
        completedAt: isFinal ? DateTime.now() : null,
      );
    });

    if (isFinal) {
      widget.repository
          .logAnalyticsEvent('tournament_champion', null)
          .catchError((_) => false);
    }

    final stages = ['quarter', 'semi', 'final', 'won'];
    widget.repository
        .saveTournamentProgress(
          stages[roundIndex.clamp(0, stages.length - 1)],
          0,
          0,
          winners.map((w) => w.name).toList(),
        )
        .catchError((_) => false);
  }

  List<String> _roundNames(bool ku) => ku
      ? const ['Dawiya 16an', 'Çaryeka Fînalê', 'Nîv-Fînal', 'Fînal']
      : const ['Son 16', 'Çeyrek Final', 'Yarı Final', 'Final'];

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Kûpaya ZanKurd' : 'Turnuva')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                )
              : _hasError
              ? Center(
                  child: AppErrorState(
                    title: ku ? 'Barnebû' : 'Yüklenemedi',
                    message: ku
                        ? 'Turnuva nehat barkirin'
                        : 'Turnuva yüklenemedi',
                    retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar dene',
                    onRetry: _load,
                  ),
                )
              : _bracket == null
              ? _LobbyView(ku: ku, onStart: _startTournament)
              : _buildBracket(context, ku),
        ),
      ),
    );
  }

  Widget _buildBracket(BuildContext context, bool ku) {
    final bracket = _bracket!;
    final userMatch = _userMatch;
    final roundNames = _roundNames(ku);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(bracket: bracket, ku: ku),
          if (bracket.status == 'won') ...[
            const SizedBox(height: AppSpacing.md),
            _ChampionBanner(ku: ku),
          ],
          if (userMatch != null) ...[
            const SizedBox(height: AppSpacing.md),
            _UserMatchCard(
              match: userMatch,
              roundName: roundNames[bracket.currentRound],
              loading: _matchLoading,
              ku: ku,
              onStart: _startMatch,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _TournamentSectionTitle(
            title: ku ? 'Şemaya Turnuvayê' : 'Turnuva Şeması',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < bracket.rounds.length; i++) ...[
            _RoundSection(
              title: roundNames[i],
              round: bracket.rounds[i],
              userId: _userId,
              ku: ku,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_standings.isNotEmpty) ...[
            _TournamentSectionTitle(title: ku ? 'Rêzkirin' : 'Sıralama'),
            const SizedBox(height: AppSpacing.sm),
            ..._standings.map((s) => _StandingRow(s: s)),
          ],
        ],
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.ku, required this.onStart});

  final bool ku;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.secondaryAccent, AppTheme.bgDeep],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: AppTheme.glowShadow(AppTheme.gold, intensity: 0.14),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: KilimPatternPainter(
                        drawPattern: true,
                        color: Colors.white,
                        opacity: 0.05,
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.goldGradient,
                        boxShadow: AppTheme.glowShadow(
                          AppTheme.gold,
                          intensity: 0.3,
                        ),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      ku ? 'Kûpaya ZanKurd' : 'ZanKurd Kupası',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ku
                          ? '16 lîstikvan · 4 tur · ${TournamentConfig.questionsPerMatch} pirs/maç'
                          : '16 oyuncu · 4 tur · ${TournamentConfig.questionsPerMatch} soru/maç',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      ku
                          ? 'Şampiyon dibe xwediyê kûpayê!'
                          : 'Şampiyon kupanın sahibi olur!',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.bgDeep,
                        ),
                        child: Text(
                          ku ? 'Dest Bi Turnuvayê Bike' : 'Turnuvaya Başla',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.bracket, required this.ku});

  final TournamentBracket bracket;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (bracket.status) {
      'won' => ku ? 'Şampiyon!' : 'Şampiyon!',
      'eliminated' => ku ? 'Derket' : 'Elendi',
      _ => ku ? 'Berdewam' : 'Devam',
    };
    return AppPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ku ? 'Rewş' : 'Durum',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statusLabel,
                style: AppTypography.heading2.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              '${(bracket.currentRound + 1).clamp(1, bracket.rounds.length)}'
              '/${bracket.rounds.length}',
              style: AppTypography.bodyLarge.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: AppTheme.goldGradient,
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ku
                  ? 'Pîroz be! Tu şampiyonê Kûpaya ZanKurd î!'
                  : 'Tebrikler! ZanKurd Kupası şampiyonusun!',
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMatchCard extends StatelessWidget {
  const _UserMatchCard({
    required this.match,
    required this.roundName,
    required this.loading,
    required this.ku,
    required this.onStart,
  });

  final TournamentMatch match;
  final String roundName;
  final bool loading;
  final bool ku;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ku ? 'Maça Te · $roundName' : 'Maçın · $roundName',
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.playerOneName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  match.playerTwoName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onStart,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(ku ? 'Maçê Bide Destpêkirin' : 'Maçı Başlat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.title,
    required this.round,
    required this.userId,
    required this.ku,
  });

  final String title;
  final TournamentRound round;
  final String userId;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: round.status == 'active'
                ? AppTheme.accent
                : AppTheme.textSubColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        AppPanel(
          child: Column(
            children: [
              for (var i = 0; i < round.matches.length; i++) ...[
                if (i > 0)
                  Divider(height: 16, color: AppTheme.borderColor(context)),
                _MatchRow(match: round.matches[i], userId: userId, ku: ku),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.userId, required this.ku});

  final TournamentMatch match;
  final String userId;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final isUserMatch =
        match.playerOneId == userId || match.playerTwoId == userId;
    final placeholder = ku ? 'Nediyar' : 'Belirsiz';

    TextStyle nameStyle(String playerId) => TextStyle(
      color: match.status == 'completed' && match.winnerId != playerId
          ? AppTheme.textMutedColor(context)
          : isUserMatch
          ? AppTheme.accent
          : AppTheme.textPrimaryColor(context),
      fontWeight: playerId == userId ? FontWeight.w800 : FontWeight.w600,
      fontSize: 13,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            match.playerOneName == 'TBD' ? placeholder : match.playerOneName,
            maxLines: 1,
            style: nameStyle(match.playerOneId),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: match.status == 'completed'
              ? const Icon(Icons.check_circle, size: 14, color: AppTheme.accent)
              : Text(
                  '—',
                  style: TextStyle(color: AppTheme.textMutedColor(context)),
                ),
        ),
        Expanded(
          child: Text(
            match.playerTwoName == 'TBD' ? placeholder : match.playerTwoName,
            textAlign: TextAlign.end,
            style: nameStyle(match.playerTwoId),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TournamentSectionTitle extends StatelessWidget {
  const _TournamentSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.accent, AppTheme.primaryGradientEnd],
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.s});

  final TournamentStandings s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        child: Row(
          children: [
            Text(
              '${s.rank}.',
              style: TextStyle(color: AppTheme.textSubColor(context)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                s.playerName,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${s.totalScore}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
