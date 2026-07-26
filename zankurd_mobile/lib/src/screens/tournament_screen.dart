import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/tournament.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/duration_format.dart';
import '../utils/weekly_cup_schedule.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/tournament_bracket_widget.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../config/bot_names.dart';

bool tournamentMatchCompleted(Object? result) =>
    result is Map && result['completed'] == true;

int tournamentMatchScore(Object? result) {
  if (!tournamentMatchCompleted(result)) return 0;
  final value = (result as Map)['score'];
  return value is num ? value.toInt() : 0;
}

int tournamentOpponentScore(Object? result) {
  if (!tournamentMatchCompleted(result)) return 0;
  final value = (result as Map)['opponentScore'];
  return value is num ? value.toInt() : 0;
}

/// Günlük turnuva: 16 oyuncu, 4 tur, tur başına 4 soruluk maç.
/// Lobi → şema → maç (bot yarışı quiz) → tur ilerlemesi.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  // M-4: Bot isimleri merkezi BotNames.pool'dan alınır;
  // inline liste kaldırıldı, tek kaynak config/bot_names.dart.
  static List<String> get _botNames => BotNames.pool;

  TournamentBracket? _bracket;

  /// Şema sunucudan mı geldi?
  ///
  /// Geldiyse eşleştirmeyi, kazananı ve ilerlemeyi sunucu belirler; istemci
  /// yalnız kendi skorunu bildirir. Gelmediyse (migration uygulanmamış ya da
  /// cihaz çevrimdışı) eski bot benzetimi yedek olarak sürer — turnuva
  /// ekranı hiç açılmaz olmasın diye (2026-07-26).
  bool _serverBracket = false;

  /// Turnuva doldu mu bekliyoruz?
  bool _waitingForPlayers = false;
  List<TournamentStandings> _standings = const [];
  bool _loading = true;
  bool _hasError = false;
  bool _matchLoading = false;
  String _userName = '';

  /// Bot benzetimindeki yerel oyuncu kimliği.
  ///
  /// Benzetimde şemayı istemci kurduğu için sabit bir kimlik yeterliydi.
  /// Gerçek turnuvada kimlikler sunucudan gelen UUID'lerdir; sabit değeri
  /// kullanmak "benim maçım"ın hiç bulunamaması demekti (2026-07-26).
  static const _simulatedUserId = 'user';

  /// Şemadaki kimliğimiz: sunucu yolunda gerçek kullanıcı, benzetimde
  /// sabit değer.
  String get _userId => _serverBracket
      ? (_bracket?.userId ??
            widget.repository.currentUserId ??
            _simulatedUserId)
      : _simulatedUserId;

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
      // Önce gerçek turnuva sorulur. `null` dönmesi "sunucu tarafı yok"
      // demektir; şemanın kimliğine bakarak tahmin etmek sahte depoyu
      // sunucu sanmaya yol açıyordu.
      final real = await widget.repository.loadRealTournamentBracket();
      final bracket = real ?? await widget.repository.loadTournamentBracket();
      final standings = await widget.repository.loadTournamentStandings();
      if (!mounted) return;
      setState(() {
        // Oyuncu yerleştirilmemiş (boş) şema lobi sayılır.
        final seeded = bracket != null && _isSeeded(bracket);
        _bracket = seeded ? bracket : null;
        _serverBracket = seeded && real != null;
        _waitingForPlayers = real != null && !_isSeeded(real);
        _standings = standings;
        _loading = false;
      });
      if (real != null && real.status == 'won') {
        unawaited(_claimChampionReward());
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_load');
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
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_action');
    }
    if (!mounted) return;
    _userName = name.isEmpty ? context.t(K.you) : name;

    // Önce gerçek turnuva: sunucu bizi açık turnuvaya yazar ve kontenjan
    // dolduğunda eşleşmeleri kurar. Henüz dolmadıysa şema boş döner; o
    // zaman beklenir — bot uydurmak, "gerçek insanlar" sözünü bozardı.
    try {
      final joined = await widget.repository.joinRealTournament();
      if (!mounted) return;
      if (joined != null) {
        setState(() {
          final seeded = _isSeeded(joined);
          _bracket = seeded ? joined : null;
          _serverBracket = seeded;
          // Kontenjan dolmadıysa beklenir; bot uydurmak "gerçek insanlar"
          // sözünü bozardı.
          _waitingForPlayers = !seeded;
        });
        return;
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_join');
    }
    if (!mounted) return;

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
    widget.repository.saveTournamentProgress('r16', 0, 0, const []).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'tournament_save_initial_progress',
      );
      return false;
    });
    widget.repository.logAnalyticsEvent('tournament_started', null).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'log_tournament_started');
      return false;
    });
  }

  /// Şampiyonluk ödülünü talep eder.
  ///
  /// Bu çağrıyı hiçbir ekran yapmıyordu: kupayı kazanan oyuncu ödülünü
  /// hiç almıyordu. Miktarı ve hak edişi sunucu belirler — şampiyon
  /// olmayan çağrıda sıfır döner, aynı kupa ikinci kez talep edilemez
  /// (2026-07-26).
  Future<void> _claimChampionReward() async {
    try {
      final amount = await widget.repository.claimTournamentChampionReward();
      if (!mounted || amount <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.championRewardGranted, {'coins': '$amount'}),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_champion_reward');
    }
  }

  /// Kendi skorumuzu bildirdik ama maç hâlâ açık mı?
  ///
  /// Şemada "kim gönderdi" alanı yok; skorun sıfırdan büyük olması
  /// gönderdiğimizin işaretidir. Sunucu skoru tek sefer kabul ettiği için
  /// bu çıkarım güvenli: bir kez yazıldıysa bizim skorumuzdur.
  bool get _awaitingOpponent {
    final match = _userMatch;
    if (match == null || match.status == 'completed') return false;
    final myScore = match.playerOneId == _userId
        ? match.playerOneScore
        : match.playerTwoScore;
    return myScore > 0;
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
      // Maç ekranına versus bandı: rakip adı + tur bilgisi (bracket verisi
      // zaten var; yalnız UI'a taşınır).
      final ku = context.isKu;
      final bracket = _bracket;
      String? versusBanner;
      final match = _userMatch;
      if (bracket != null && match != null) {
        final opponentName = match.playerOneId == _userId
            ? match.playerTwoName
            : match.playerOneName;
        final roundName = _roundNames(ku)[bracket.currentRound];
        versusBanner = context.t(K.yourMatchVs, {
          'round': roundName,
          'opponent': opponentName,
        });
      }
      final result = await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: widget.repository.createRoom(),
            questions: questions,
            botRace: true,
            versusBannerText: versusBanner,
          ),
        ),
      );
      if (!mounted) return;
      if (tournamentMatchCompleted(result)) {
        if (_serverBracket && match != null) {
          // Gerçek turnuvada sonucu istemci belirlemez: skorumuzu bildirip
          // şemayı sunucudan yeniden okuruz. Rakip henüz oynamadıysa maç
          // 'completed' olmaz ve ekran bekleme durumunu gösterir.
          await widget.repository
              .submitTournamentMatch(
                matchId: match.id,
                playerScore: tournamentMatchScore(result),
                opponentScore: 0,
              )
              .catchError((error, stack) {
                ErrorReporter.record(
                  error,
                  stack,
                  reason: 'tournament_submit_match',
                );
                return match;
              });
          if (!mounted) return;
          await _load();
        } else {
          _advanceRound(
            userScore: tournamentMatchScore(result),
            opponentScore: tournamentOpponentScore(result),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _matchLoading = false);
    }
  }

  /// Maç sonrası gerçek quiz skoruna göre turu kapatır ve sonucu kaydeder.
  void _advanceRound({int userScore = 0, int opponentScore = 0}) {
    final bracket = _bracket;
    if (bracket == null) return;
    final roundIndex = bracket.currentRound;
    final round = bracket.rounds[roundIndex];

    // Bu turun tüm maçlarını sonuçlandır (kullanıcı + bot simülasyonu).
    final completed = round.matches.map((m) {
      final userIsPlayerOne = m.playerOneId == _userId;
      final userIsPlayerTwo = m.playerTwoId == _userId;
      final isUserMatch = userIsPlayerOne || userIsPlayerTwo;
      final playerOneScore = isUserMatch && userIsPlayerOne
          ? userScore
          : isUserMatch
          ? opponentScore
          : m.playerOneScore;
      final playerTwoScore = isUserMatch && userIsPlayerTwo
          ? userScore
          : isUserMatch
          ? opponentScore
          : m.playerTwoScore;
      final winnerId = isUserMatch
          ? (playerOneScore > playerTwoScore ? m.playerOneId : m.playerTwoId)
          : m.playerOneId;
      return m.copyWith(
        playerOneScore: playerOneScore,
        playerTwoScore: playerTwoScore,
        status: 'completed',
        winnerId: winnerId,
      );
    }).toList();

    final userMatch = completed.firstWhere(
      (m) => m.playerOneId == _userId || m.playerTwoId == _userId,
      orElse: () => const TournamentMatch(
        id: '',
        playerOneId: '',
        playerOneName: '',
        playerTwoId: '',
        playerTwoName: '',
        playerOneScore: 0,
        playerTwoScore: 0,
        status: 'completed',
        winnerId: '',
      ),
    );
    final userLost = userMatch.id.isNotEmpty && userMatch.winnerId != _userId;

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
    if (!isFinal && !userLost) {
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
            status: p1.id == _userId || p2.id == _userId ? 'active' : 'pending',
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
        status: userLost ? 'eliminated' : (isFinal ? 'won' : 'active'),
        completedAt: userLost || isFinal ? DateTime.now() : null,
      );
    });

    if (isFinal && !userLost) {
      widget.repository
          .logAnalyticsEvent('tournament_champion', null)
          .catchError((error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'log_tournament_champion',
            );
            return false;
          });
    }

    final stages = ['quarter', 'semi', 'final', 'won'];
    widget.repository
        .saveTournamentProgress(
          userLost ? 'lost' : stages[roundIndex.clamp(0, stages.length - 1)],
          userScore,
          opponentScore,
          winners.map((w) => w.name).toList(),
        )
        .catchError((error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'tournament_save_match_progress',
          );
          return false;
        });
  }

  List<String> _roundNames(bool ku) => ku
      ? const ['Dawiya 16an', 'Çaryeka Fînalê', 'Nîv-Fînal', 'Fînal']
      : const ['Son 16', 'Çeyrek Final', 'Yarı Final', 'Final'];

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: Container(
        color: AppTheme.bgOf(context),
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
                    title: context.t(K.loadFailedShort),
                    message: context.t(K.tournamentLoadFail),
                    retryLabel: context.t(K.retry),
                    onRetry: _load,
                  ),
                )
              : _waitingForPlayers
              // Gerçek oyunculu turnuvanın kaçınılmaz hâli: kontenjan
              // dolana dek beklenir. Burada bot uydurmak "gerçek insanlar"
              // sözünü bozardı (2026-07-26).
              ? Center(
                  child: AppEmptyState(
                    key: const ValueKey('tournament-waiting'),
                    icon: AppIcons.hourglass,
                    title: context.t(K.tournamentWaitingTitle),
                    message: context.t(K.tournamentWaitingBody),
                    actionLabel: context.t(K.retry),
                    actionIcon: AppIcons.arrowsRotate,
                    onAction: _load,
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

    // 2026-07-22 canlı UX denetimi: dikey ortalama
    // IntrinsicHeight KULLANILMADI: LayoutBuilder içinde IntrinsicHeight
    // "LayoutBuilder does not support returning intrinsic dimensions"
    // hatası veriyor. ConstrainedBox(minHeight) tek başına yeterli;
    // Column varsayılan mainAxisSize.max ile viewport'tan uzun olduğunda
    // scroll çalışır, kısa olduğunda mainAxisAlignment.center etkili olur.
    return LayoutBuilder(
      builder: (context, constraints) {
        final minH = math.max(
          0.0,
          constraints.maxHeight - (AppSpacing.sm + AppSpacing.lg),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Dikey ortalama, kimlik başlığını ekranın üçte birine
              // itiyordu: turnuva, başlığı yukarıda duran diğer bütün
              // ekranlardan farklı görünüyor ve yarım yüklenmiş gibi
              // duruyordu (2026-07-26).
              children: [
                ScreenIdentityHeader(
                  title: context.t(K.tournamentTitle),
                  // Tur bilgisi yalnızca maç kartında gösterilir; burada tekrar
                  // edilmez (üst üste 3 kartta aynı bilgi vardı).
                  subtitle: context.t(K.botTournament),
                  accent: AppTheme.gold,
                  icon: AppIcons.trophy,
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.md),
                // Durum kartı yalnızca turnuva aktif değilken (elendi/kazandı)
                // anlam taşır; aktif oyunda maç kartı zaten bağlamı verir.
                if (bracket.status != 'active')
                  _StatusCard(bracket: bracket, ku: ku),
                if (bracket.status == 'won') ...[
                  const SizedBox(height: AppSpacing.md),
                  _ChampionBanner(ku: ku),
                ],
                // Skorumuzu bildirdik ama maç kapanmadı: rakip henüz
                // oynamamış. Gerçek oyunculu turnuvada bu normal bir
                // durumdur ve söylenmezse oyuncu bir şeyin bozulduğunu
                // sanır (2026-07-26).
                if (_serverBracket && _awaitingOpponent) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    key: const ValueKey('tournament-awaiting-opponent'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppTheme.cardDecoration(context),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.hourglass,
                          size: 16,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            context.t(K.tournamentWaitingOpponent),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppTheme.textSubColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (userMatch != null && !_awaitingOpponent) ...[
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
                // -- Bracket visualization --
                _TournamentSectionTitle(
                  label: context.t(K.bracket),
                  accent: AppTheme.gold,
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppTheme.cardDecoration(context),
                    child: TournamentBracketWidget(
                      bracket: bracket,
                      userId: _userId,
                      ku: ku,
                      onTapMatch: (match, roundIndex) {
                        // Only the user's active match in the current round is tappable
                        if (roundIndex == bracket.currentRound &&
                            (match.playerOneId == _userId ||
                                match.playerTwoId == _userId) &&
                            match.status != 'completed') {
                          _startMatch();
                        }
                      },
                    ),
                  ),
                ),
                // -- Legacy round list (collapsed below the bracket) --
                const SizedBox(height: AppSpacing.md),
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
                  _TournamentSectionTitle(
                    label: context.t(K.standings),
                    accent: AppTheme.gold,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._standings.map((s) => _StandingRow(s: s)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.ku, required this.onStart});

  final bool ku;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Bir sonraki kupa anı saf bir işlevden gelir; mantık burada gömülüyken
    // sessiz bir hata barındırıyordu (bkz. `weekly_cup_schedule.dart`).
    final now = DateTime.now();
    final nextSaturday = nextWeeklyCupAfter(now);
    final remaining = nextSaturday.difference(now);
    final remainingText = formatDurationHuman(remaining, ku: ku);

    final scheduleText = context.t(K.everySaturday);
    final countdownText = context.t(K.timeRemaining, {'time': remainingText});

    // 2026-07-22 canlı UX denetimi: dikey ortalama — hero kart viewport kısa
    // kaldığında alt boşluk yerine dikeyde ortalanır; içerik uzunsa scroll.
    // IntrinsicHeight KULLANILMADI: LayoutBuilder içinde IntrinsicHeight
    // "LayoutBuilder does not support returning intrinsic dimensions"
    // hatası veriyor. ConstrainedBox(minHeight) tek başına yeterli.
    return LayoutBuilder(
      builder: (context, constraints) {
        final minH = math.max(0.0, constraints.maxHeight - AppSpacing.lg * 2);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Column(
              children: [
                ScreenIdentityHeader(
                  title: context.t(K.tournamentTitle),
                  subtitle: context.t(K.weeklyCupSub),
                  accent: AppTheme.gold,
                  icon: AppIcons.trophy,
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Container(
                    key: const ValueKey('tournament-hero'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.surfaceColor(context),
                          AppTheme.gold.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.12),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -28,
                          top: -24,
                          child: Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.gold.withValues(alpha: 0.07),
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
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                AppIcons.trophy,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              context.t(K.tournamentTitle),
                              textAlign: TextAlign.center,
                              style: AppTypography.heading1.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Tournament schedule badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHiColor(context),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: AppTheme.borderColor(context),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.clock,
                                    size: 14,
                                    color: AppTheme.textSubColor(context),
                                  ),
                                  const SizedBox(width: 6),
                                  // Sistem yazısı büyütüldüğünde bu satır
                                  // rozetin dışına taşıyordu; metin artık
                                  // kalan genişliğe sığar (2026-07-26).
                                  Flexible(
                                    child: Text(
                                      scheduleText,
                                      style: AppTypography.caption.copyWith(
                                        color: AppTheme.textPrimaryColor(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            // Countdown
                            Text(
                              countdownText,
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Honesty label: bot-filled bracket, not live multiplayer
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                context.t(K.botDailyCup),
                                style: AppTypography.caption.copyWith(
                                  // Altın metin + altın@0.2 zemin açık temada ~2:1
                                  // kalıyordu; aksan kimliği korunarak okunabilir
                                  // açıklığa çekilir.
                                  color: AppColors.readableAccent(
                                    context,
                                    AppTheme.gold,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              context.t(K.formatSummary, {
                                'perMatch':
                                    '${TournamentConfig.questionsPerMatch}',
                              }),
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppTheme.textSubColor(context),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              context.t(K.botRaceHint),
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('tournament-primary-cta'),
                                onPressed: onStart,
                                icon: const Icon(AppIcons.trophy, size: 20),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                  backgroundColor: AppTheme.brand,
                                  foregroundColor: Colors.white,
                                ),
                                label: Text(
                                  context.t(K.joinTournament),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bölüm başlığı — all-caps etiket patlaması yerine standart gövde başlığı:
/// sol accent çizgisi + normal büyük/küçük harf, okunabilir ağırlık.
class _TournamentSectionTitle extends StatelessWidget {
  const _TournamentSectionTitle({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: AppTheme.sectionAccent(accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
      'won' => context.t(K.champion),
      'eliminated' => context.t(K.eliminated),
      _ => context.t(K.ongoing),
    };
    return AppPanel(
      color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(K.status),
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
              color: AppTheme.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.22)),
            ),
            child: Text(
              '${(bracket.currentRound + 1).clamp(1, bracket.rounds.length)}'
              '/${bracket.rounds.length}',
              style: AppTypography.bodyLarge.copyWith(color: AppTheme.gold),
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
      cardType: CardType.primary,
      gradient: AppTheme.goldGradient,
      child: Row(
        children: [
          const Icon(AppIcons.trophy, color: Colors.white, size: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.t(K.championCongrats),
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
      color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(K.yourMatchRound, {'round': roundName}),
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
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.18),
                  ),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: AppTheme.gold,
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
                  : const Icon(AppIcons.play),
              label: Text(context.t(K.startMatch)),
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
          color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
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
  const _MatchRow({
    required this.match,
    required this.userId,
    required this.ku,
  });

  final TournamentMatch match;
  final String userId;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final isUserMatch =
        match.playerOneId == userId || match.playerTwoId == userId;
    final placeholder = context.t(K.unknown);

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
              ? const Icon(
                  AppIcons.circleCheck,
                  size: 14,
                  color: AppTheme.accent,
                )
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

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.s});

  final TournamentStandings s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
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
