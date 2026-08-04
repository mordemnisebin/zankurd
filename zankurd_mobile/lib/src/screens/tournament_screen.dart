import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/tournament.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/arena_kit.dart';
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
                        Icon(
                          AppIcons.hourglass,
                          size: 16,
                          color: AppColors.readableAccent(
                            context,
                            AppTheme.gold,
                          ),
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
                // Şemanın ALTINDAKİ düz tur listesi kaldırıldı.
                //
                // Aynı eşleşmeleri ikinci kez, üstelik DAHA AZ bilgiyle
                // gösteriyordu: şemada kupa/çarpı işareti, üstü çizili
                // kaybeden adı, kullanıcının vurgulu maçı ve (bu turdan
                // itibaren) skor var; düz listede yalnız iki ad ve bir
                // onay simgesi vardı. Kod içinde de "legacy" diye
                // işaretliydi. İki kez anlatılan bir yapı, bir kez
                // anlatılandan daha anlaşılır olmuyor (2026-08-04).
                //
                // Yerine turun NEREDE olduğunu söyleyen ilerleme şeridi
                // konur — lobideki kupa merdiveni diliyle aynı aile.
                const SizedBox(height: AppSpacing.md),
                _RoundProgressStrip(
                  roundNames: roundNames,
                  rounds: bracket.rounds,
                  currentRound: bracket.currentRound,
                  bracketStatus: bracket.status,
                ),
                const SizedBox(height: AppSpacing.md),
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
    // Kupanın ne zaman başlayacağı.
    //
    // Burada "Her Cumartesi 20:00" ve ona giden bir geri sayım yazıyordu.
    // Kupa gerçek oyunculara çevrildiğinde (2026-07-26) kural değişti:
    // kontenjan dolunca başlar, dolmazsa 24 saat sonunda eldeki oyuncularla.
    // Cumartesi metni o günden beri yalandı — üstelik daha öncesinde de
    // yanıltıcıydı: bot benzetiminde "Katıl"a basınca tur **hemen**
    // başlıyordu, geri sayımın işaret ettiği bekleme hiç yaşanmıyordu
    // (2026-07-27 Kurmancî taraması).
    final scheduleText = context.t(K.cupStartsWhenFull);

    // Kupa hero'su: durum, ödül ve ana eylem TEK yüzeyde.
    //
    // Eskiden burada ikon + çip + paragraf + hap + paragraf + düğme alt
    // alta diziliydi ve ekranın yarısından fazlası boştu. Daha kötüsü,
    // kupanın ödülü (`coinRewardPerMatch`, `coinBonusChampion`) ve yapısı
    // (16 oyuncu, 4 tur) `TournamentConfig`te sabit dururken ekranda HİÇ
    // görünmüyordu: oyuncu neye katıldığını okumadan karar veriyordu
    // (2026-08-04 görsel denetimi).
    final hero = ArenaHero(
      title: context.t(K.tournamentTitle),
      // Kural alt başlıkta, DURUM çipte. Çip bir etikettir; "Kontenjan
      // dolunca başlar" gibi bir cümleyi taşıyamaz ve taşımaya
      // çalışınca "Kontenj..." diye kırpılıyordu (2026-08-04).
      subtitle: scheduleText,
      accent: AppTheme.gold,
      icon: AppIcons.trophy,
      // Durum çipi başlığın YANINDA değil, jeton satırında. Başlıkla aynı
      // satırda genişlik yarıştırınca ikisi de kırpılıyordu ("ZanKurd
      // Kupası" iki satıra, "Başlamadı" → "Başlama..."). Jeton satırı
      // sarmalı bir `Wrap`; orada hiçbir şey kısalmaz (2026-08-04).
      tokens: [
        ArenaStatusChip(
          // Kupa henüz başlamadı: kontenjan dolunca başlar.
          status: ArenaStatus.upcoming,
          label: context.t(K.cupNotStarted),
          onSolid: true,
        ),
        // Ödül GERÇEK sabitlerden gelir; uydurulmaz.
        RewardToken(
          kind: RewardKind.coin,
          value: '${TournamentConfig.coinRewardPerMatch}',
          label: context.t(K.cupPerMatchReward),
          onSolid: true,
        ),
        RewardToken(
          kind: RewardKind.coin,
          value: '${TournamentConfig.coinBonusChampion}',
          label: context.t(K.cupChampionReward),
          onSolid: true,
        ),
      ],
      action: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('tournament-primary-cta'),
          onPressed: onStart,
          icon: const Icon(AppIcons.trophy, size: 20),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
    );

    final format = _CupFormatPanel(ku: ku);
    final ladder = _CupLadder(ku: ku);

    return LayoutBuilder(
      builder: (context, constraints) {
        // `ScreenIdentityHeader` BİLEREK yok: `ArenaHero` aynı başlığı,
        // aynı amblemi ve fazlasını (durum, ödül, eylem) taşıyor. İkisi
        // birlikte çizilince "ZanKurd Kupası" ilk 300 pikselde iki kez
        // yazıyordu — 2026-07-30 ekran turunda kapatılmış bir kusur; hero'ya
        // geçerken farkında olmadan geri geldi ve görüntüde yakalandı
        // (2026-08-04).

        // Geniş ekranda gerçek iki sütun: solda kupanın ne olduğu ve
        // katılma eylemi, sağda biçim ve kupa yolu. Telefon düzeni
        // 720'nin altında hiç değişmez.
        if (constraints.maxWidth >= 720) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: hero),
                    const SizedBox(width: AppSpacing.cardGap),
                    Expanded(
                      flex: 5,
                      child: Column(
                        key: const ValueKey('tournament-wide-column'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          format,
                          const SizedBox(height: AppSpacing.cardGap),
                          ladder,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // 2026-07-22 canlı UX denetimi: dikey ortalama — hero kart viewport
        // kısa kaldığında alt boşluk yerine dikeyde ortalanır; içerik
        // uzunsa scroll. IntrinsicHeight KULLANILMADI: LayoutBuilder içinde
        // "LayoutBuilder does not support returning intrinsic dimensions"
        // hatası veriyor. ConstrainedBox(minHeight) tek başına yeterli.
        final minH = math.max(0.0, constraints.maxHeight - AppSpacing.lg * 2);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hero,
                const SizedBox(height: AppSpacing.cardGap),
                format,
                const SizedBox(height: AppSpacing.cardGap),
                ladder,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kupanın biçimi: kaç oyuncu, kaç tur, maç başına kaç soru, hangi beş.
///
/// Dört değer de `TournamentConfig`te sabittir ve uydurulmaz. Bunlar
/// eskiden yalnız tek bir çipte "Eleme kupası · 4 soru/maç" diye
/// özetleniyordu; oyuncu kaç kişilik bir kupaya girdiğini göremiyordu.
class _CupFormatPanel extends StatelessWidget {
  const _CupFormatPanel({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (
        AppIcons.peopleGroup,
        '${TournamentConfig.totalPlayers}',
        Tr.forKu(K.cupPlayers, ku),
      ),
      (
        AppIcons.trophy,
        '${TournamentConfig.roundCount}',
        Tr.forKu(K.cupRounds, ku),
      ),
    ];

    // Kupanın türü ve maç uzunluğu TEK cümlede durur.
    //
    // Sayıya bölünmüş bir blok ("4" + "soru/maç") görsel olarak daha
    // düzenli görünüyordu ama cümleyi parçalıyordu: kupanın eleme usulü
    // olduğu bilgisi hiçbir yerde kalmıyordu ve bu, 2026-07-30'da bilerek
    // konmuş dürüstlük ifadesiydi. Sunum değişti diye kaybolmamalı.
    final formatLine =
        '${Tr.forKu(K.botDailyCup, ku)} · '
        '${Tr.forKu(K.formatSummary, ku, {'perMatch': '${TournamentConfig.questionsPerMatch}'})}';

    return _CupPanel(
      title: Tr.forKu(K.cupFormatTitle, ku),
      icon: AppIcons.trophy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatLine,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Yatay kaydırma: bloklar %200 yazıda dar telefona sığmıyor ve
          // sayıları küçültmek biçim bilgisini okunmaz kılardı.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == items.length - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: _CupStat(
                      icon: items[i].$1,
                      value: items[i].$2,
                      label: items[i].$3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Kupanın iki kuralı da burada durur: kontenjan dolmazsa ne
          // olacağı hero'nun alt başlığına sığmıyordu.
          Text(
            '${Tr.forKu(K.botRaceHint, ku)}\n${Tr.forKu(K.cupStartsLatest, ku)}',
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kupa yolu: 16 → 8 → 4 → 2 → 1.
///
/// Turnuvayı yarışmadan ayıran şey tam da bu: aşamalı ve uzun soluklu bir
/// etkinlik. Merdiven o kimliği tek bakışta anlatır — "Eleme kupası"
/// yazan bir çipin anlatamadığı şey.
class _CupLadder extends StatelessWidget {
  const _CupLadder({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    // 16 → 8 → 4 → 2 → 1: `TournamentConfig.generateBracket` ile aynı
    // bölme mantığı; sabit dizi yazılmaz ki ikisi ayrışmasın.
    final steps = <int>[TournamentConfig.totalPlayers];
    while (steps.last > 1) {
      steps.add(steps.last ~/ 2);
    }

    return _CupPanel(
      title: Tr.forKu(K.cupLadder, ku),
      icon: AppIcons.chartLine,
      // `Wrap`, yatay kaydırma DEĞİL: kaydırmada merdivenin son basamağı
      // — yani şampiyonluk — ekranın sağında kesik duruyordu ve kupanın
      // varış noktası tam da o basamak (2026-08-04).
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.textMutedColor(context),
              ),
            _LadderStep(count: steps[i], isFinal: steps[i] == 1),
          ],
        ],
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({required this.count, required this.isFinal});

  final int count;
  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    // Son basamak şampiyonluk: altın dolu, diğerleri sakin tonal.
    final tone = isFinal ? AppTheme.gold : const Color(0xFF6A38BE);
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: isFinal
              ? (AppTheme.isLight(context) ? 0.22 : 0.34)
              : (AppTheme.isLight(context) ? 0.10 : 0.22),
        ),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: isFinal
            ? Border.all(color: tone.withValues(alpha: 0.55))
            : null,
      ),
      // `alignment` YOK: alignment verilen bir `Container` gevşek
      // kısıtlar altında var olan bütün genişliği doldurur. Yatay
      // kaydırmada (sınırsız genişlik) sorun çıkmıyordu, `Wrap`a
      // geçince her basamak tam satır oldu ve merdiven dikey bir
      // yığına dönüştü (2026-08-04).
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Şampiyonluk basamağı ayrıca bir kupa taşır: renk tek kanal
          // olamaz, son basamağın farkı yalnız tonla anlatılmamalı.
          if (isFinal) ...[
            Icon(
              AppIcons.trophy,
              size: 13,
              color: AppColors.readableAccent(context, tone),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$count',
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.readableAccent(context, tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayı + etiketten oluşan küçük biçim bloğu.
class _CupStat extends StatelessWidget {
  const _CupStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSubColor(context)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: AppTypography.subtitle.copyWith(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıklı sakin panel — arena ailesinin nötr yüzeyi.
///
/// Her bilgiyi ayrı renkli karta koymak yeni bir kart yığını üretirdi;
/// panel yalnız iki tane ve ikisi de mürekkep nötrü.
class _CupPanel extends StatelessWidget {
  const _CupPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.textSubColor(context)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSubColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Turun nerede olduğunu söyleyen ilerleme şeridi.
///
/// Şema yatay kaydırılabilir ve dar telefonda yalnız ilk iki tur görünür;
/// oyuncu kupanın kaç turdan oluştuğunu ve hangi turda olduğunu şemayı
/// kaydırmadan göremiyordu. Şerit bunu tek bakışta verir ve aynı zamanda
/// şemada sağa doğru daha fazla içerik olduğunun işaretidir.
///
/// Lobideki kupa merdiveniyle aynı görsel aile — ikinci bir dil kurulmaz.
class _RoundProgressStrip extends StatelessWidget {
  const _RoundProgressStrip({
    required this.roundNames,
    required this.rounds,
    required this.currentRound,
    required this.bracketStatus,
  });

  final List<String> roundNames;
  final List<TournamentRound> rounds;
  final int currentRound;
  final String bracketStatus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < rounds.length && i < roundNames.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AppTheme.textMutedColor(context),
            ),
          _RoundPill(
            label: roundNames[i],
            // Durum GERÇEK tur verisinden gelir; sıra numarasından
            // tahmin edilmez. Turnuva bittiyse (kazandı/elendi) hiçbir
            // tur "şu an oynanıyor" diye işaretlenmez.
            state: rounds[i].status == 'completed'
                ? _RoundState.done
                : (bracketStatus == 'active' && i == currentRound)
                ? _RoundState.active
                : _RoundState.upcoming,
          ),
        ],
      ],
    );
  }
}

enum _RoundState { done, active, upcoming }

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.label, required this.state});

  final String label;
  final _RoundState state;

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.isLight(context);
    // Renk tek kanal değil: her durumun kendi ikonu var.
    final (tone, icon) = switch (state) {
      _RoundState.done => (const Color(0xFF0E7A57), Icons.check_rounded),
      _RoundState.active => (AppTheme.gold, Icons.play_arrow_rounded),
      _RoundState.upcoming => (const Color(0xFF3A4557), Icons.remove_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: state == _RoundState.upcoming
              ? (light ? 0.07 : 0.16)
              : (light ? 0.14 : 0.26),
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: state == _RoundState.active
            ? Border.all(color: tone.withValues(alpha: 0.55))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.readableAccent(context, tone)),
          const SizedBox(width: 5),
          // Esnek olmalı: "Çeyrek Final" %200 yazıda dar telefonda çipi
          // 47 piksel taşırıyordu. `Wrap` satırı sarabilir ama tek bir
          // çipin kendi içeriğini sığdırması gerekir.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: state == _RoundState.active
                    ? FontWeight.w900
                    : FontWeight.w700,
                color: AppColors.readableAccent(context, tone),
              ),
            ),
          ),
        ],
      ),
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
          // Esnek olmalı: "Elendi"/"Şampiyon" %200 yazıda tur rozetiyle
          // aynı satıra sığmıyordu ve durum kartı taşıyordu. Bu kart tam
          // da elenme ve şampiyonluk anında görünen kart — taşma şeridi
          // sonucun kendisini örtüyordu (2026-08-04).
          Expanded(
            child: Column(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading2.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
              maxLines: 1,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.onAccentTint(context, AppTheme.gold),
              ),
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
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.onAccentTint(context, AppTheme.gold),
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
              style: TextStyle(
                color: AppColors.readableAccent(context, AppTheme.accent),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
