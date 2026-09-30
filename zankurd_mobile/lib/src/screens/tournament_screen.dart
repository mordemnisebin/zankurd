import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tournament_progress_publisher.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../models/tournament.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/arena_kit.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
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

/// `matchId`den türeyen SABİT bir seçimle aynı maçtaki her iki oyuncuya
/// da AYNI soruları verir.
///
/// Gerçek turnuvada `loadQuestions` her oyuncuda farklı sonuç verirdi:
/// seçim `SeenQuestionStore`ye (cihaz başına yerel "görülen soru" durumu)
/// dayanıyordu — sunucu soru ataması yapmıyor, yalnız skoru kaydediyor.
/// Aynı maçın iki oyuncusu birbirinden habersiz farklı sorularla
/// oynuyordu (2026-08-14 denetimi).
///
/// `String.hashCode` platformlar arası aynı garantisi TAŞIMAZ (dil
/// spesifikasyonu bunu vaat etmez); bu yüzden kendi basit, saf tamsayı
/// aritmetiğiyle çalışan bir özet (FNV-1a) kullanılır — iOS ve Android
/// aynı `matchId` için her zaman aynı sonucu üretir. Havuz önce kimliğe
/// göre sıralanır (statik paket her cihazda aynı sırada gelmese bile bu,
/// sırayı sabitler), sonra özetten türeyen bir döndürmeyle seçilir.
List<QuizQuestion> deterministicMatchQuestions(
  List<QuizQuestion> pool,
  String matchId,
  int limit,
) {
  if (pool.isEmpty || limit <= 0) return const [];
  final sorted = [...pool]..sort((a, b) => a.id.compareTo(b.id));
  var hash = 0x811c9dc5;
  for (final unit in matchId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  final offset = hash % sorted.length;
  final rotated = [...sorted.skip(offset), ...sorted.take(offset)];
  return rotated.take(limit).toList();
}

/// Maçın hükmen kapanacağı anı `GG.AA SS:dd` biçiminde yerel saate çevirir.
String formatMatchDeadline(DateTime deadline) {
  final local = deadline.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
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

  /// "Yeni Turnuvaya Katıl" düğmesinin çift dokunuşla iki kez
  /// `join_tournament` çağırmasını engeller.
  bool _startingNewTournament = false;

  /// Bu oturumda skorumuzu gönderdiğimiz maç kimlikleri.
  ///
  /// `get_tournament_bracket` "ben gönderdim mi" bilgisini AYRI bir alan
  /// olarak taşımıyor; istemci bunu skorun sıfırdan büyük olmasından
  /// çıkarıyordu (`_awaitingOpponent`). Turu 0 puanla bitiren (bütün
  /// sorulara yanlış cevap veren ya da süresi dolan) oyuncu için bu
  /// çıkarım YANLIŞ sonuç veriyordu: "Maçı başlat" düğmesi geri geliyor,
  /// tekrar basınca sunucu skoru tek sefer kabul ettiği için sessizce
  /// hiçbir şey olmuyordu (2026-08-14 denetimi). Bu küme yanlış
  /// çıkarımı düzeltir.
  final Set<String> _submittedMatchIds = {};

  /// Şema sunucudan mı geldi?
  ///
  /// Geldiyse eşleştirmeyi, kazananı ve ilerlemeyi sunucu belirler; istemci
  /// yalnız kendi skorunu bildirir. Gelmediyse (migration uygulanmamış ya da
  /// cihaz çevrimdışı) eski bot benzetimi yedek olarak sürer — turnuva
  /// ekranı hiç açılmaz olmasın diye (2026-07-26).
  bool _serverBracket = false;

  /// Turnuva doldu mu bekliyoruz?
  bool _waitingForPlayers = false;

  /// Şampiyonluk ödülünün GERÇEK durumu.
  ///
  /// Kupayı kazanmak ödülün verildiği anlamına gelmez: ödülü sunucu verir
  /// (`claimTournamentChampionReward`) ve bot benzetiminde hiç talep
  /// edilmez. Ekran eskiden her iki durumda da aynı altın "Şampiyon!"
  /// bandını gösteriyordu — yani yerel bir kupada oyuncu hiçbir şey
  /// almadığı hâlde kutlanıyor ve bunu hiçbir yerde okuyamıyordu
  /// (2026-08-04).
  _CupRewardState _rewardState = _CupRewardState.none;
  int _rewardAmount = 0;
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
        // `get_tournament_bracket` RPC'si `totalScore` HİÇ döndürmüyor
        // (yalnız tournamentId/userId/currentRound/status/rounds) —
        // Şampiyon banner'ındaki "Final skoru" bu yüzden gerçek turnuvada
        // her zaman 0 kalıyordu. Kullanıcının kendi skoru zaten
        // `rounds[].matches[]`te duruyor; sunucuya yeni bir alan
        // eklemeden burada toplanır (2026-08-14 denetimi). Kaynak zaten
        // dolu bir değer verdiyse (yerel benzetimin kendi hesabı) o
        // korunur — yalnız 0/boşken türetilir.
        _bracket = seeded
            ? bracket.copyWith(
                totalScore: bracket.totalScore != 0
                    ? bracket.totalScore
                    : _sumUserScore(
                        bracket.rounds,
                        real != null
                            ? (bracket.userId.isNotEmpty
                                  ? bracket.userId
                                  : (widget.repository.currentUserId ??
                                        _simulatedUserId))
                            : _simulatedUserId,
                      ),
              )
            : null;
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

  /// Kullanıcının brakete kayıtlı tüm maçlardaki toplam skoru.
  ///
  /// Ne sunucu (`get_tournament_bracket`) ne de yerel benzetim
  /// `TournamentBracket.totalScore`ı hiçbir yerde dolduruyordu; alan
  /// `Şampiyon` banner'ında ve sıralamada hep 0 gösteriyordu. Skorun
  /// kendisi zaten her maçta duruyor, yalnız toplanmamıştı
  /// (2026-08-14 denetimi).
  int _sumUserScore(List<TournamentRound> rounds, String userId) {
    var total = 0;
    for (final round in rounds) {
      for (final match in round.matches) {
        if (match.playerOneId == userId) {
          total += match.playerOneScore;
        } else if (match.playerTwoId == userId) {
          total += match.playerTwoScore;
        }
      }
    }
    return total;
  }

  bool _isSeeded(TournamentBracket bracket) =>
      bracket.rounds.isNotEmpty &&
      bracket.rounds.first.matches.any((m) => m.playerOneId.isNotEmpty);

  /// Bitmiş bir şemanın (`_bracket.status != 'active'`) üzerinden yeni bir
  /// turnuvaya katılır. `_startTournament`in kendisi `_bracket`i her
  /// durumda üzerine yazdığı için tek fark burada yalnız çift dokunuşu
  /// engellemek.
  Future<void> _startNewTournamentAfterFinish() async {
    if (_startingNewTournament) return;
    setState(() => _startingNewTournament = true);
    try {
      await _startTournament();
    } finally {
      if (mounted) setState(() => _startingNewTournament = false);
    }
  }

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
    //
    // `save_tournament_progress`in geçerli `p_stage` kümesi ('lobby',
    // 'quarter', 'semi', 'final', 'won', 'lost' —
    // 2026-07-14_tournament_integrity_hardening.sql) 'r16' İÇERMEZ; bu
    // çağrı her yerel turnuva başlangıcında sessizce reddediliyor,
    // kaydın işi zaten yerel oyunu etkilemediği için kimse fark etmiyordu
    // (2026-08-14 denetimi). Hiçbir eleme turu henüz tamamlanmadığı için
    // doğru karşılık 'lobby'dir.
    unawaited(
      TournamentProgressPublisher.publish(
        repository: widget.repository,
        stage: 'lobby',
        userScore: 0,
        opponentScore: 0,
        botWinners: const [],
      ),
    );
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
    if (mounted) setState(() => _rewardState = _CupRewardState.claiming);
    try {
      final amount = await widget.repository.claimTournamentChampionReward();
      if (!mounted) return;
      // Sunucu sıfır döndüyse ödül VERİLMEDİ: hak ediş doğrulanmamış ya da
      // aynı kupa için zaten talep edilmiş olabilir. "Verildi" demek yanlış
      // olurdu.
      setState(() {
        _rewardAmount = amount;
        _rewardState = amount > 0
            ? _CupRewardState.granted
            : _CupRewardState.unverified;
      });
      if (amount <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.championRewardGranted, {'coins': '$amount'}),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_champion_reward');
      if (!mounted) return;
      setState(() => _rewardState = _CupRewardState.unverified);
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
    if (_submittedMatchIds.contains(match.id)) return true;
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

  List<QuizQuestion> _matchQuestions(String matchId) {
    final pool = widget.repository.playableQuestions
        .where((q) => q.category == TournamentConfig.tournamentCategory)
        .toList();
    return deterministicMatchQuestions(
      pool,
      matchId,
      TournamentConfig.questionsPerMatch,
    );
  }

  Future<void> _startMatch() async {
    if (_matchLoading) return;
    setState(() => _matchLoading = true);
    try {
      final match = _userMatch;
      List<QuizQuestion> questions;
      if (_serverBracket && match != null) {
        // Gerçek turnuvada `loadQuestions` HER OYUNCUDA farklı sonuç
        // verirdi: seçim `SeenQuestionStore`ye (cihaz başına yerel "görülen
        // soru" durumu) dayanıyordu. Aynı maçın iki oyuncusu birbirinden
        // habersiz farklı sorularla oynuyordu — sunucu soru ataması
        // yapmıyor, yalnız skoru kaydediyor (2026-08-14 denetimi).
        //
        // Sunucuya dokunmadan adillik: seçim `match.id`den (iki oyuncuda
        // da aynı, `get_tournament_bracket`ten gelir) türeyen SABİT bir
        // döndürmeyle yapılır — aynı statik pakete, aynı sırayla, aynı
        // ofsetle bakan iki cihaz aynı soruları seçer.
        questions = _matchQuestions(match.id);
      } else {
        questions = await widget.repository.loadQuestions(
          categoryId: TournamentConfig.tournamentCategory,
          limit: TournamentConfig.questionsPerMatch,
        );
      }
      if (questions.isEmpty) {
        questions = widget.repository.playableQuestions
            .take(TournamentConfig.questionsPerMatch)
            .toList();
      }
      if (!mounted) return;
      // Maç ekranına versus bandı: rakip adı + tur bilgisi (bracket verisi
      // zaten var; yalnız UI'a taşınır).
      final ku = context.isKu;
      final bracket = _bracket;
      String? versusBanner;
      if (bracket != null && match != null) {
        final opponentName = match.playerOneId == _userId
            ? match.playerTwoName
            : match.playerOneName;
        final roundName = _roundNames(
          ku,
          bracket.rounds.length,
        )[bracket.currentRound];
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
          var submitFailed = false;
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
                submitFailed = true;
                return match;
              });
          if (!mounted) return;
          if (submitFailed) {
            // Skor sunucuya yazılamadı; sessiz kalırsa kullanıcı az önce
            // oynadığı maçın boşa gittiğini hiçbir yerde göremezdi
            // (2026-08-14 denetimi). RPC skoru tek sefer kabul ettiği
            // için "tekrar oyna" güvenlidir.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.t(K.tournamentMatchSubmitFailed))),
            );
          } else {
            // Skor 0 olsa bile (bütün sorular yanlış/süre doldu)
            // gönderildi sayılır — `_awaitingOpponent` skorun sıfırdan
            // büyük olmasına bakınca bu durumu kaçırıyordu (2026-08-14
            // denetimi).
            _submittedMatchIds.add(match.id);
          }
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
        totalScore: _sumUserScore(rounds, _userId),
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
    unawaited(
      TournamentProgressPublisher.publish(
        repository: widget.repository,
        stage: userLost
            ? 'lost'
            : stages[roundIndex.clamp(0, stages.length - 1)],
        userScore: userScore,
        opponentScore: opponentScore,
        botWinners: winners.map((winner) => winner.name).toList(),
      ),
    );
  }

  /// Tur adları SONDAN sayılır: son tur her zaman Final'dir.
  ///
  /// Gerçek turnuva `tournaments.size` varsayılanı 4 ile 2 tur (yarı final
  /// + final) oynanıyor; yerel bot benzetimi (`TournamentConfig`) hep 4 tur
  /// (16 oyuncu). Sabit, BAŞTAN sayan tek bir liste ikisine birden
  /// uygulanamaz — gerçek turnuvanın final maçı "Çeyrek Final" diye
  /// etiketleniyordu (2026-08-14 denetimi). `totalRounds`, o an elde olan
  /// `bracket.rounds.length`dir.
  List<String> _roundNames(bool ku, int totalRounds) {
    final namesFromFinal = ku
        ? const ['Fînal', 'Nîv-Fînal', 'Çaryeka Fînalê', 'Dawiya 16an']
        : const ['Final', 'Yarı Final', 'Çeyrek Final', 'Son 16'];
    return List.generate(totalRounds, (i) {
      final distanceFromFinal = totalRounds - 1 - i;
      if (distanceFromFinal < namesFromFinal.length) {
        return namesFromFinal[distanceFromFinal];
      }
      // Bilinen 4 addan taşan (32+ oyuncu) erken turlar için genel yedek.
      return Tr.forKu(K.tournamentRoundGeneric, ku, {'n': '${i + 1}'});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final t = SahneTokens.of(context);
    final bracket = _bracket;
    final inBracket =
        !_loading && !_hasError && !_waitingForPlayers && bracket != null;

    // 2026-09-29 Şahnê: B iskeleti. Lobide çubuk "Turnuva" der; kupanın
    // adı ("ZanKurd Kupası") kahraman kartındadır — iki kez yazılmaz.
    // Şemada kahraman yok: çubuk kupanın adını ve türünü taşır.
    final Widget body;
    if (_loading) {
      body = SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: t.goldTx)),
      );
    } else if (_hasError) {
      body = SliverFillRemaining(
        child: AppErrorState(
          title: context.t(K.loadFailedShort),
          message: context.t(K.tournamentLoadFail),
          retryLabel: context.t(K.retry),
          onRetry: _load,
        ),
      );
    } else if (_waitingForPlayers) {
      // Gerçek oyunculu turnuvanın kaçınılmaz hâli: kontenjan dolana dek
      // beklenir. Burada bot uydurmak "gerçek insanlar" sözünü bozardı
      // (2026-07-26).
      body = SliverFillRemaining(
        child: AppEmptyState(
          key: const ValueKey('tournament-waiting'),
          icon: AppIcons.hourglass,
          title: context.t(K.tournamentWaitingTitle),
          message: context.t(K.tournamentWaitingBody),
          actionLabel: context.t(K.retry),
          actionIcon: AppIcons.arrowsRotate,
          onAction: _load,
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
        sliver: SliverToBoxAdapter(
          child: bracket == null
              ? _LobbyView(ku: ku, onStart: _startTournament)
              : _buildBracket(context, ku),
        ),
      );
    }

    return SahnePushedPage(
      title: context.t(inBracket ? K.tournamentTitle : K.tournament),
      // Tur bilgisi yalnızca maç kartında gösterilir; burada tekrar
      // edilmez.
      subtitle: inBracket ? context.t(K.botTournament) : null,
      backLabel: context.t(K.back),
      slivers: [body],
    );
  }

  Widget _buildBracket(BuildContext context, bool ku) {
    final bracket = _bracket!;
    final userMatch = _userMatch;
    final roundNames = _roundNames(ku, bracket.rounds.length);
    final t = SahneTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Durum kartı yalnızca turnuva aktif değilken (elendi/kazandı)
        // anlam taşır; aktif oyunda maç kartı zaten bağlamı verir.
        if (bracket.status != 'active')
          _StatusCard(bracket: bracket, ku: ku, roundNames: roundNames),
        if (bracket.status == 'won') ...[
          const SizedBox(height: SahneSpace.cardGap),
          _ChampionBanner(
            ku: ku,
            finalScore: bracket.totalScore,
            // Ödül yalnız SUNUCU şemasında talep edilir; yerel
            // benzetimde hiç istenmez ve bu açıkça yazılır.
            rewardState: _serverBracket
                ? _rewardState
                : _CupRewardState.localOnly,
            rewardAmount: _rewardAmount,
          ),
        ],
        if (bracket.status != 'active') ...[
          // Turnuva bittikten sonra `get_tournament_bracket` kullanıcının
          // EN SON kaydını döndürmeye devam eder — biten turnuva sonsuza
          // kadar "en son" kalır. `_bracket` bu yüzden bir daha hiç null
          // olmuyor ve lobideki "Katıl" düğmesi kalıcı olarak
          // kayboluyordu; oyuncu bir daha hiç turnuvaya giremiyordu
          // (2026-08-14 denetimi). Sunucu tarafı zaten doğru:
          // `join_tournament` yalnız `open`/`running` turnuvalara bakar.
          //
          // Biten turnuvada ekranın TEK birincil eylemi budur (maç kartı
          // yalnız aktif turnuvada çizilir; ikisi hiç birlikte olmaz).
          const SizedBox(height: SahneSpace.x4),
          SahneButton.primary(
            key: const ValueKey('tournament-join-new-cta'),
            label: context.t(K.joinTournament),
            expand: true,
            onPressed: _startingNewTournament
                ? null
                : _startNewTournamentAfterFinish,
          ),
        ],
        // Skorumuzu bildirdik ama maç kapanmadı: rakip henüz oynamamış.
        // Gerçek oyunculu turnuvada bu normal bir durumdur ve söylenmezse
        // oyuncu bir şeyin bozulduğunu sanır (2026-07-26).
        if (_serverBracket && _awaitingOpponent) ...[
          const SizedBox(height: SahneSpace.cardGap),
          SahneSurfaceCard(
            key: const ValueKey('tournament-awaiting-opponent'),
            child: Row(
              children: [
                Icon(AppIcons.hourglass, size: 20, color: t.goldTx),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    context.t(K.tournamentWaitingOpponent),
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Maç kartı yalnız aktif turnuvada ve bekleme kartı yokken çizilir;
        // üstünde başka kart olmadığı için ayrı aralık gerekmez.
        if (userMatch != null && !_awaitingOpponent) ...[
          _UserMatchCard(
            match: userMatch,
            userId: _userId,
            roundName: roundNames[bracket.currentRound],
            loading: _matchLoading,
            ku: ku,
            onStart: _startMatch,
          ),
        ],
        SahneSectionHeader(title: context.t(K.bracket)),
        SahneSurfaceCard(
          padding: const EdgeInsets.all(SahneSpace.x3),
          child: TournamentBracketWidget(
            bracket: bracket,
            userId: _userId,
            ku: ku,
            onTapMatch: (match, roundIndex) {
              // Yalnız kullanıcının bu turdaki açık maçı dokunulabilir.
              if (roundIndex == bracket.currentRound &&
                  (match.playerOneId == _userId ||
                      match.playerTwoId == _userId) &&
                  match.status != 'completed') {
                _startMatch();
              }
            },
          ),
        ),
        // Şemanın ALTINDAKİ düz tur listesi kaldırıldı (2026-08-04): aynı
        // eşleşmeleri ikinci kez, daha az bilgiyle gösteriyordu. Yerine
        // turun NEREDE olduğunu söyleyen ilerleme şeridi durur — lobideki
        // kupa yolu diliyle aynı aile.
        const SizedBox(height: SahneSpace.x3),
        _RoundProgressStrip(
          roundNames: roundNames,
          rounds: bracket.rounds,
          currentRound: bracket.currentRound,
          bracketStatus: bracket.status,
        ),
        if (_standings.isNotEmpty) ...[
          SahneSectionHeader(title: context.t(K.standings)),
          SahneListGroup(
            children: [
              for (final s in _standings)
                SahneListRow.rank(
                  rank: s.rank,
                  title: s.playerName,
                  initial: s.playerName.trim().isEmpty
                      ? null
                      : SahneType.upperFor(s.playerName.trim()[0], isKu: ku),
                  icon: AppIcons.user,
                  trailing: SahneRowValue('${s.totalScore}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.ku, required this.onStart});

  final bool ku;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Kupanın ne zaman başlayacağı: kontenjan dolunca, dolmazsa 24 saat
    // sonunda eldeki oyuncularla. Eski "Her Cumartesi 20:00" metni bu
    // kuraldan önce yazılmıştı ve gerçeği anlatmıyordu (2026-07-27).
    final scheduleText = context.t(K.cupStartsWhenFull);

    // Kupa kahramanı: durum, ödül ve ana eylem TEK yüzeyde (2026-08-04).
    //
    // 2026-09-29 Şahnê: sahne kartı Zêr (ödül) rolünde — altın kilim
    // şeridi, altın köşe ışıması; "Turnuvaya Katıl" ekranın tek birincil
    // eylemidir (Agir, koyu metin). Eski düğme turuncu üstüne beyaz
    // yazıyordu.
    final hero = ArenaHero(
      title: context.t(K.tournamentTitle),
      // Kural alt başlıkta, DURUM çipte. Çip bir etikettir; "Kontenjan
      // dolunca başlar" gibi bir cümleyi taşıyamaz (2026-08-04).
      subtitle: scheduleText,
      accent: SahneTokens.of(context).gold,
      icon: AppIcons.trophy,
      tokens: [
        ArenaStatusChip(
          // Kupa henüz başlamadı: kontenjan dolunca başlar.
          status: ArenaStatus.upcoming,
          label: context.t(K.cupNotStarted),
          onSolid: true,
        ),
        // Ödül GERÇEK sabitlerden gelir; uydurulmaz. Maç başı jeton
        // kasıtlı olarak yok: sunucu maç başına hiçbir coin ödemiyor
        // (2026-08-14 denetimi).
        RewardToken(
          kind: RewardKind.coin,
          value: '${TournamentConfig.coinBonusChampion}',
          label: context.t(K.cupChampionReward),
          onSolid: true,
        ),
      ],
      action: SahneButton.primary(
        key: const ValueKey('tournament-primary-cta'),
        label: context.t(K.joinTournament),
        expand: true,
        onPressed: onStart,
      ),
    );

    final format = _CupFormatPanel(ku: ku);
    final ladder = _CupLadder(ku: ku);

    return LayoutBuilder(
      builder: (context, constraints) {
        // `ScreenIdentityHeader` BİLEREK yok: kahraman kupanın adını,
        // amblemini ve fazlasını (durum, ödül, eylem) taşıyor (2026-08-04).

        // Geniş ekranda gerçek iki sütun: solda kupanın ne olduğu ve
        // katılma eylemi, sağda biçim ve kupa yolu.
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: hero),
              const SizedBox(width: SahneSpace.cardGap),
              Expanded(
                flex: 5,
                child: Transform.translate(
                  // Bölüm başlığının 24'lük üst boşluğu geri alınır: sağ
                  // sütunun başlığı kahramanın üst kenarıyla hizalanır.
                  offset: const Offset(0, -SahneSpace.sectionTop),
                  child: Column(
                    key: const ValueKey('tournament-wide-column'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [format, ladder],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hero, format, ladder],
        );
      },
    );
  }
}

/// Kupanın biçimi: kaç oyuncu, kaç tur, maç başına kaç soru.
///
/// Değerler `TournamentConfig`te sabittir ve uydurulmaz.
///
/// 2026-09-29 Şahnê: bölüm başlığı + yüzey kartı; sayılar istatistik
/// karolarında (Kulis tonu, M pah, Zêr ikon, Manşet 22 tablo rakamı).
class _CupFormatPanel extends StatelessWidget {
  const _CupFormatPanel({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
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

    // Kupanın türü ve maç uzunluğu TEK cümlede durur: eleme usulü olduğu
    // bilgisi 2026-07-30'da bilerek konmuş bir dürüstlük ifadesidir.
    final formatLine =
        '${Tr.forKu(K.botDailyCup, ku)} · '
        '${Tr.forKu(K.formatSummary, ku, {'perMatch': '${TournamentConfig.questionsPerMatch}'})}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneSectionHeader(title: Tr.forKu(K.cupFormatTitle, ku)),
        SahneSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                formatLine,
                style: SahneType.bodyStrong.copyWith(color: t.tx),
              ),
              const SizedBox(height: SahneSpace.x3),
              // Karolar sarar: %200 yazıda dar telefonda alt satıra iner.
              Wrap(
                spacing: SahneSpace.x2,
                runSpacing: SahneSpace.x2,
                children: [
                  for (final item in items)
                    _CupStat(icon: item.$1, value: item.$2, label: item.$3),
                ],
              ),
              const SizedBox(height: SahneSpace.x3),
              // Kupanın iki kuralı da burada durur.
              Text(
                '${Tr.forKu(K.botRaceHint, ku)}\n${Tr.forKu(K.cupStartsLatest, ku)}',
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kupa yolu: 16 → 8 → 4 → 2 → 1.
///
/// Turnuvayı yarışmadan ayıran şey: aşamalı ve uzun soluklu bir etkinlik.
/// 2026-09-29 Şahnê: ara basamaklar yarış tonu (Boyax), varış basamağı
/// ödül tonu (Zêr) + taç glifi — renk tek kanal değil.
class _CupLadder extends StatelessWidget {
  const _CupLadder({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // `TournamentConfig.generateBracket` ile aynı bölme mantığı; sabit dizi
    // yazılmaz ki ikisi ayrışmasın.
    final steps = <int>[TournamentConfig.totalPlayers];
    while (steps.last > 1) {
      steps.add(steps.last ~/ 2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneSectionHeader(title: Tr.forKu(K.cupLadder, ku)),
        SahneSurfaceCard(
          // `Wrap`, yatay kaydırma DEĞİL: kaydırmada merdivenin son
          // basamağı — şampiyonluk — sağda kesik duruyordu (2026-08-04).
          child: Wrap(
            spacing: SahneSpace.x1,
            runSpacing: SahneSpace.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  ExcludeSemantics(
                    child: Icon(AppIcons.chevronRight, size: 16, color: t.tx3),
                  ),
                _LadderStep(count: steps[i], isFinal: steps[i] == 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({required this.count, required this.isFinal});

  final int count;
  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fg = isFinal ? t.goldTx : t.raceTx;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isFinal ? t.goldTint : t.raceTint,
        shape: isFinal
            ? SahneShape.withSide(SahneShape.s, t.gold, width: SahneRing.r1)
            : SahneShape.s,
      ),
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — turnuva merdiveni ilerleme
        // rozeti; salt görsel, dokunma hedefi değil.
        constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Şampiyonluk basamağı ayrıca taç taşır: son basamağın farkı
              // yalnız tonla anlatılmaz.
              if (isFinal) ...[
                const SahneGlyph(SahneGlyphKind.crown, size: 16),
                const SizedBox(width: SahneSpace.x1),
              ],
              Text(
                '$count',
                maxLines: 1,
                style: SahneType.captionStrong.copyWith(
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İstatistik karosu: ikon + değer + etiket (Kulis tonu, M pah).
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
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 96),
        child: Padding(
          padding: const EdgeInsets.all(SahneSpace.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: t.goldTx),
              const SizedBox(height: SahneSpace.x1),
              Text(
                value,
                maxLines: 1,
                style: SahneType.headline.copyWith(
                  color: t.tx,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                maxLines: 1,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turun nerede olduğunu söyleyen ilerleme şeridi.
///
/// Şema yatay kaydırılabilir ve dar telefonda yalnız ilk iki tur görünür;
/// şerit kupanın kaç turdan oluştuğunu ve hangi turda olunduğunu tek
/// bakışta verir. Kupa yolu ile aynı görsel aile.
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
    final t = SahneTokens.of(context);
    return Wrap(
      spacing: SahneSpace.x1,
      runSpacing: SahneSpace.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < rounds.length && i < roundNames.length; i++) ...[
          if (i > 0)
            ExcludeSemantics(
              child: Icon(AppIcons.chevronRight, size: 16, color: t.tx3),
            ),
          _RoundPill(
            label: roundNames[i],
            // Durum GERÇEK tur verisinden gelir; sıra numarasından tahmin
            // edilmez. Turnuva bittiyse hiçbir tur "şu an oynanıyor" diye
            // işaretlenmez.
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
    final t = SahneTokens.of(context);
    // Renk tek kanal değil: her durumun kendi ikonu var. Biten tur Rast
    // (✓), oynanan tur yarış tonu + Halka 1, gelecek tur nötr.
    final (bg, fg, icon) = switch (state) {
      _RoundState.done => (t.okTint, t.okTx, AppIcons.check),
      _RoundState.active => (t.raceTint, t.raceTx, AppIcons.play),
      _RoundState.upcoming => (t.s2, t.tx2, AppIcons.clock),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: bg,
        shape: state == _RoundState.active
            ? SahneShape.withSide(SahneShape.s, fg, width: SahneRing.r1)
            : SahneShape.s,
      ),
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — tur durumu çipi; salt görsel,
        // dokunma hedefi değil.
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: SahneSpace.x1),
              // Esnek olmalı: "Çeyrek Final" %200 yazıda dar telefonda
              // çipi taşırıyordu.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turnuva bittiğinde (elendi/kazandı) görünen özet.
///
/// "Elendi" tek başına hangi turda elenildiğini ve kaç puan alındığını
/// söylemiyordu; ikisi de şemada gerçekten duruyor (2026-08-04).
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.bracket,
    required this.ku,
    required this.roundNames,
  });

  final TournamentBracket bracket;
  final bool ku;
  final List<String> roundNames;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final statusLabel = switch (bracket.status) {
      'won' => context.t(K.champion),
      'eliminated' => context.t(K.eliminated),
      _ => context.t(K.ongoing),
    };
    return SahneSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Esnek olmalı: "Elendi"/"Şampiyon" %200 yazıda tur rozetiyle
          // aynı satıra sığmıyordu (2026-08-04).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(K.status),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
                Text(
                  statusLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
                // Elenen oyuncuya HANGİ turda elendiği ve kaç puan aldığı
                // söylenir; ikisi de şemada gerçekten duruyor.
                if (bracket.status == 'eliminated' &&
                    bracket.currentRound < roundNames.length)
                  Text(
                    Tr.forKu(K.cupEliminatedRound, ku, {
                      'round': roundNames[bracket.currentRound],
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                if (bracket.totalScore > 0)
                  Text(
                    '${Tr.forKu(K.cupFinalScore, ku)}: ${bracket.totalScore}',
                    maxLines: 1,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          SahneBadge(
            label:
                '${(bracket.currentRound + 1).clamp(1, bracket.rounds.length)}'
                '/${bracket.rounds.length}',
            tone: SahneBadgeTone.gold,
          ),
        ],
      ),
    );
  }
}

/// Şampiyonluk ödülünün durumu.
enum _CupRewardState {
  /// Henüz talep edilmedi.
  none,

  /// Sunucudan cevap bekleniyor.
  claiming,

  /// Sunucu ödülü verdi ve miktarı bildirdi.
  granted,

  /// Sunucu sıfır döndü ya da çağrı başarısız oldu — ödül VERİLMEDİ.
  unverified,

  /// Kupa yerel benzetimde oynandı; ödül hiç talep edilmez.
  localOnly,
}

/// Şampiyonluk yüzeyi: kupa, gerçek final skoru ve ödülün GERÇEK durumu.
///
/// Eskiden yalnız altın bir bantta "Tebrikler, şampiyon!" yazıyordu.
/// Kupayı kazanmak ödülün verildiği anlamına gelmez: ödülü sunucu verir ve
/// bot benzetiminde hiç talep edilmez. Oyuncu yerel bir kupada hiçbir şey
/// almadığı hâlde kutlanıyor ve bunu hiçbir yerde okuyamıyordu.
class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({
    required this.ku,
    required this.finalScore,
    required this.rewardState,
    required this.rewardAmount,
  });

  final bool ku;
  final int finalScore;
  final _CupRewardState rewardState;
  final int rewardAmount;

  (ArenaStatus, String) _rewardVisual(BuildContext context) =>
      switch (rewardState) {
        _CupRewardState.claiming => (
          ArenaStatus.loading,
          context.t(K.cupRewardClaiming),
        ),
        _CupRewardState.granted => (
          ArenaStatus.completed,
          context.t(K.cupRewardGranted),
        ),
        _CupRewardState.unverified => (
          ArenaStatus.upcoming,
          context.t(K.cupRewardUnverified),
        ),
        _CupRewardState.localOnly => (
          ArenaStatus.locked,
          context.t(K.cupRewardLocal),
        ),
        _CupRewardState.none => (
          ArenaStatus.loading,
          context.t(K.cupRewardClaiming),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final (status, label) = _rewardVisual(context);
    return ArenaHero(
      key: const ValueKey('tournament-champion'),
      title: context.t(K.championCongrats),
      // Final skoru GERÇEK şemadan gelir.
      subtitle: '${context.t(K.cupFinalScore)}: $finalScore',
      accent: SahneTokens.of(context).gold,
      icon: AppIcons.trophy,
      tokens: [
        ArenaStatusChip(status: status, label: label, onSolid: true),
        // Jeton YALNIZ ödül gerçekten verildiyse çizilir. "500 şampiyon"
        // lobide bir vaattir; burada yazılan sayı sunucunun bildirdiği
        // gerçek miktardır.
        if (rewardState == _CupRewardState.granted && rewardAmount > 0)
          RewardToken(
            kind: RewardKind.coin,
            value: '$rewardAmount',
            onSolid: true,
          ),
      ],
    );
  }
}

/// Kullanıcının bu turdaki maçı — ekranın aktif turnuvadaki TEK birincil
/// eylemi burada.
///
/// 2026-09-29 Şahnê: yarış rolünde sahne kartı (Boyax sahne degradesi,
/// lal kilim şeridi). İki oyuncu elmas avatarla yüz yüze: kullanıcı Halka
/// 3 altın, rakip yumuşak lal; arada "VS". Altında tarih ve "Maçı Başlat".
class _UserMatchCard extends StatelessWidget {
  const _UserMatchCard({
    required this.match,
    required this.userId,
    required this.roundName,
    required this.loading,
    required this.ku,
    required this.onStart,
  });

  final TournamentMatch match;
  final String userId;
  final String roundName;
  final bool loading;
  final bool ku;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SahneStageCard(
      role: SahneRole.race,
      child: Builder(
        builder: (context) {
          // Sahne kartının içi gece belirteçleridir.
          final t = SahneTokens.of(context);
          Widget side(String name, {required bool me}) {
            final trimmed = name.trim();
            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SahneDiamondAvatar(
                    size: 56,
                    initial: trimmed.isEmpty
                        ? null
                        : SahneType.upperFor(trimmed[0], isKu: ku),
                    icon: trimmed.isEmpty ? AppIcons.user : null,
                    color: me ? t.tx : SahneStageColors.race3,
                    foreground: me
                        ? SahneStageColors.race2
                        : SahneStageColors.raceSoft,
                    ring: me ? t.gold : SahneStageColors.raceSoft,
                    ringWidth: me ? SahneRing.r3 : SahneRing.r2,
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(K.yourMatchRound, {'round': roundName}),
                style: SahneType.captionStrong.copyWith(
                  color: SahneStageColors.raceSoft,
                ),
              ),
              const SizedBox(height: SahneSpace.x3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side(match.playerOneName, me: match.playerOneId == userId),
                  Padding(
                    padding: const EdgeInsets.only(top: SahneSpace.x4),
                    child: Text(
                      'VS',
                      style: SahneType.eyebrow.copyWith(color: t.tx),
                    ),
                  ),
                  side(match.playerTwoName, me: match.playerTwoId == userId),
                ],
              ),
              if (match.deadline != null) ...[
                const SizedBox(height: SahneSpace.x3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        AppIcons.clock,
                        size: 16,
                        color: SahneStageColors.raceSoft,
                      ),
                    ),
                    const SizedBox(width: SahneSpace.x1),
                    Expanded(
                      child: Text(
                        key: const ValueKey('tournament-match-deadline'),
                        match.deadline!.isBefore(DateTime.now())
                            ? context.t(K.tournamentMatchDeadlinePassed)
                            : Tr.forKu(K.tournamentMatchDeadline, ku, {
                                'time': formatMatchDeadline(match.deadline!),
                              }),
                        style: SahneType.caption.copyWith(
                          color: SahneStageColors.raceSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SahneSpace.x4),
              SahneButton.primary(
                label: context.t(K.startMatch),
                icon: AppIcons.play,
                arrow: false,
                expand: true,
                onPressed: loading ? null : onStart,
              ),
            ],
          );
        },
      ),
    );
  }
}
