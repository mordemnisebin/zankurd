import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_progress_scope.dart';
import '../data/tournament_progress_publisher.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/async_duel.dart';
import '../models/quiz_question.dart';
import '../models/tournament.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/player_identity.dart';
import '../widgets/arena_kit.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/tournament_bracket_widget.dart';
import 'async_duel/async_duel_play_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../config/bot_names.dart';
import '../utils/number_format.dart';

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

/// Sunucu `start_due_tournaments`: kupa açıldıktan bu kadar saat sonra en az
/// 2 oyuncuyla başlar (`tournaments.fill_hours` varsayılanı).
const int cupFillHours = 24;

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

  /// Eski RPC için kullanıcıya göre ayrılmış kalıcı gönderim yedeği.
  /// Yeni RPC'nin açık gönderim bilgisi bu yerel tahminden önceliklidir.
  final Set<String> _submittedMatchIds = {};

  static String get _submittedKey =>
      LocalProgressScope.physical('zankurd.tournament.submittedMatches');

  Future<void> _restoreSubmitted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _submittedMatchIds.addAll(prefs.getStringList(_submittedKey) ?? const []);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_submitted_read');
    }
  }

  Future<void> _markSubmitted(String matchId) async {
    _submittedMatchIds.add(matchId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _submittedMatchIds.toList();
      final kept = ids.length > 40 ? ids.sublist(ids.length - 40) : ids;
      await prefs.setStringList(_submittedKey, kept);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_submitted_write');
    }
  }

  /// Şema sunucudan mı geldi?
  ///
  /// Geldiyse eşleştirmeyi, kazananı ve ilerlemeyi sunucu belirler; istemci
  /// yalnız kendi skorunu bildirir. Gelmediyse (migration uygulanmamış ya da
  /// cihaz çevrimdışı) eski bot benzetimi yedek olarak sürer — turnuva
  /// ekranı hiç açılmaz olmasın diye (2026-07-26).
  bool _serverBracket = false;

  /// Turnuva doldu mu bekliyoruz?
  bool _waitingForPlayers = false;

  /// Bekleme ekranındaki doluluk ("1/4 oyuncu katıldı"); sunucu sayıyı
  /// göndermezse null ve satır çizilmez (2026-10-27).
  ({int count, int size})? _waitingFill;

  /// Oyuncu "Katıl"a bastı ve bekleme ekranına düştü: yeni açılan kupayı
  /// açıkça söyler (önceki kupa doluyken boş "1/4" ekranı açıklamasızdı).
  bool _joinedJustNow = false;

  /// Kupanın açıldığı an (sunucu `opened_at`); 24 saatlik süre buradan
  /// sayılır. Yalnız doluluk alanlarını döndüren (yeni) RPC'de güvenilir.
  DateTime? _waitingOpenedAt;

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

  /// Beklerken sessiz yenileme: kontenjan dolunca şema kendiliğinden gelir,
  /// doluluk sayısı güncellenir; rakip maçını bitirince sonuç görünür.
  /// Eskiden oyuncu "Tekrar dene"ye basmadıkça bekleme ekranında kalıyordu
  /// (4 simülatörlü tur, 2026-10-27).
  static const Duration _waitingPollInterval = Duration(seconds: 15);
  Timer? _waitingPoll;

  @override
  void initState() {
    super.initState();
    _load();
    _waitingPoll = Timer.periodic(
      _waitingPollInterval,
      (_) => unawaited(_pollWhileWaiting()),
    );
  }

  @override
  void dispose() {
    _waitingPoll?.cancel();
    super.dispose();
  }

  /// Havadaki yenileme: yavaş bağlantıda iki istek üst üste binip geç dönen
  /// eskisi ekrandaki doluluğu geri almasın (GPT-6 Sol incelemesi).
  bool _pollInFlight = false;

  Future<void> _pollWhileWaiting() async {
    if (_loading || _pollInFlight) return;
    _pollInFlight = true;
    try {
      await _pollOnce();
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _pollOnce() async {
    // Puanımı gönderdim, rakip oynuyor: maç kapanınca (ve sonraki tur
    // kurulunca) şema kendiliğinden yenilenir. Eskiden "rakibini
    // bekliyoruz" kartı rakip bitirdikten sonra da kalıyordu (4 simülatörlü
    // tur, 2026-10-27).
    if (_serverBracket && _awaitingOpponent) {
      final matchId = _userMatch?.id;
      try {
        final real = await widget.repository.loadRealTournamentBracket();
        if (!mounted || real == null) return;
        final stillOpen = real.rounds
            .expand((round) => round.matches)
            .any((m) => m.id == matchId && m.status != 'completed');
        if (!stillOpen) await _load();
      } catch (_) {
        // Sonraki tıkta denenir.
      }
      return;
    }
    // Maçım bitti (ör. yarı finali erken kazandım) ama kupa sürüyor: sonraki
    // tur diğer maç kapanınca kurulur. `_userMatch` boş olduğundan yukarıdaki
    // dal çalışmıyordu ve ekran eski kalıyordu (Codex denetimi 2026-10-29).
    final current = _bracket;
    if (_serverBracket &&
        current != null &&
        current.status == 'active' &&
        _userMatch == null) {
      try {
        final real = await widget.repository.loadRealTournamentBracket();
        if (!mounted || real == null) return;
        if (_bracketSignature(real) != _bracketSignature(current)) {
          await _load();
        }
      } catch (_) {
        // Sonraki tıkta denenir.
      }
      return;
    }
    if (!_waitingForPlayers) return;
    try {
      final real = await widget.repository.loadRealTournamentBracket();
      if (!mounted || !_waitingForPlayers) return;
      if (real != null && _isSeeded(real)) {
        await _load();
        return;
      }
      final fill = _fillOf(real);
      final openedAt = _openedAtOf(real);
      if (fill != _waitingFill || openedAt != _waitingOpenedAt) {
        setState(() {
          _waitingFill = fill;
          _waitingOpenedAt = openedAt;
        });
      }
    } catch (_) {
      // Bekleme ekranı doğru durumu gösteriyor; sonraki tıkta denenir.
    }
  }

  /// Şemanın ilerleyişini özetler: tur, durum ve biten maç sayısı.
  static String _bracketSignature(TournamentBracket b) {
    final completed = b.rounds
        .expand((round) => round.matches)
        .where((m) => m.status == 'completed')
        .length;
    return '${b.currentRound}|${b.status}|$completed';
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
      await _restoreSubmitted();
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
        _waitingFill = _fillOf(real);
        _waitingOpenedAt = _openedAtOf(real);
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
  /// turnuvaya katılır.
  Future<void> _startNewTournamentAfterFinish() async {
    await _startTournament();
  }

  Future<void> _startTournament() async {
    if (_startingNewTournament) return;
    setState(() => _startingNewTournament = true);
    try {
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
            _waitingFill = _fillOf(joined);
            _waitingOpenedAt = _openedAtOf(joined);
            _joinedJustNow = !seeded;
          });
          return;
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'tournament_join');
        // Geçici hata sahte bot şemasına düşürmez (gerçek insan sözü); kullanıcı
        // tekrar deneyebilsin diye lobide kalır.
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.checkConnection))));
        return;
      }
      if (!mounted) return;
      await _startPracticeCup();
    } finally {
      if (mounted) setState(() => _startingNewTournament = false);
    }
  }

  /// Antrenman kupası: botlarla, yerel, ÖDÜLSÜZ (ödül yalnız sunucu
  /// şemasında talep edilir; bkz. [_CupRewardState.localOnly]).
  ///
  /// 2026-10-27: gerçek kupa kontenjanı (4 kişi; en geç 24 saatte en az 2
  /// kişiyle) beklerken oyuncunun yapacak hiçbir şeyi yoktu. Antrenman
  /// açıkça "botlarla" diye adlandırılır; gerçek insan sözü bozulmaz ve
  /// oyuncu gerçek kupadaki kaydını kaybetmez.
  Future<void> _startPracticeCup() async {
    if (_userName.isEmpty) _userName = context.t(K.you);
    try {
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
        _serverBracket = false;
        _waitingForPlayers = false;
        _rewardState = _CupRewardState.none;
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
      widget.repository
          .logAnalyticsEvent('tournament_started', null)
          .catchError((error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'log_tournament_started',
            );
            return false;
          });
    } finally {
      if (mounted) setState(() => _startingNewTournament = false);
    }
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
      final claim = await widget.repository.claimChampionRewardStatus();
      if (!mounted) return;
      // Sunucu ne ödedi ne de "zaten ödendi" dedi: hak ediş doğrulanmadı.
      // Daha önce ödenmişse "verildi" görünür ama tekrar kutlanmaz
      // (2026-10-27: ikinci açılışta "doğrulanmadı" yazıyordu).
      setState(() {
        _rewardAmount = claim.shownAmount;
        _rewardState = claim.granted
            ? _CupRewardState.granted
            : _CupRewardState.unverified;
      });
      final amount = claim.amount;
      if (amount <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.championRewardGranted, {
              'coins': groupThousands(amount),
            }),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament_champion_reward');
      if (!mounted) return;
      setState(() => _rewardState = _CupRewardState.unverified);
    }
  }

  /// Gönderim sıfır puanda da sunucudan okunur (başka cihazda da çalışır).
  bool get _awaitingOpponent {
    final match = _userMatch;
    if (match == null || match.status == 'completed') return false;
    final submitted = match.playerOneId == _userId
        ? match.hasPlayerOneSubmitted
        : match.hasPlayerTwoSubmitted;
    return submitted ?? _submittedMatchIds.contains(match.id);
  }

  static int _roundIndexOf(TournamentBracket bracket, TournamentMatch match) {
    for (var i = 0; i < bracket.rounds.length; i++) {
      if (bracket.rounds[i].matches.any((m) => m.id == match.id)) return i;
    }
    return 0;
  }

  /// Kullanıcının en son BİTMİŞ maçı (sonuç kartları için).
  TournamentMatch? get _lastDoneMatch {
    final bracket = _bracket;
    if (bracket == null) return null;
    for (var i = bracket.rounds.length - 1; i >= 0; i--) {
      for (final m in bracket.rounds[i].matches) {
        if (m.status == 'completed' &&
            (m.playerOneId == _userId || m.playerTwoId == _userId)) {
          return m;
        }
      }
    }
    return null;
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
    final bracketNow = _bracket;
    final matchNow = _userMatch;
    // Sunucu puanlı kupa (2026-10-27): sorular, süre ve puan sunucuda;
    // şampiyona ödül bu yüzden ödenir. Maç, sırayla düellonun sunucu
    // sözleşmeli oyun ekranında oynanır ve bitince şemaya dönülür.
    if (_serverBracket &&
        matchNow != null &&
        bracketNow != null &&
        bracketNow.serverScored) {
      await _startServerScoredMatch(bracketNow, matchNow);
      return;
    }
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
          bracket.totalRounds,
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
            roundId: match?.id,
            // Bot yarışı yalnız antrenman kupasında: gerçek kupada sonuç
            // ekranı "Hêlîn önde bitirdi" diye uydurma rakiplerle kıyas
            // gösteriyordu (4 simülatörlü tur, 2026-10-27). Gerçek rakibin
            // skoru şemadan okunur.
            botRace: !_serverBracket,
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
            await _markSubmitted(match.id);
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

  Future<void> _startServerScoredMatch(
    TournamentBracket bracket,
    TournamentMatch match,
  ) async {
    final roundName = _roundNames(
      context.isKu,
      bracket.totalRounds,
    )[bracket.currentRound];
    // Çift dokunuş iki oyun ekranı açmasın.
    setState(() => _matchLoading = true);
    try {
      final result = await Navigator.of(context).push<Object?>(
        AppRoute.to(
          AsyncDuelPlayScreen(
            repository: widget.repository,
            entry: AsyncDuelEntry.tournament(match.id, roundLabel: roundName),
          ),
        ),
      );
      if (!mounted) return;
      // Skoru sunucu son cevapta yazdı; yalnız şema yeniden okunur. Yarıda
      // çıkılan maçta da (kalanlar TIMEOUT) skor yazılmıştır.
      if (tournamentMatchCompleted(result)) await _markSubmitted(match.id);
    } finally {
      if (mounted) setState(() => _matchLoading = false);
    }
    await _load();
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

    // Kaydedilen aşama, turu bitirince ULAŞILAN aşamadır ve SONDAN sayılır
    // (tur adları gibi): 2 turlu kupada ilk tur bitince finale çıkılır;
    // baştan sayan liste bunu "quarter" diye yazıyordu.
    final nextRemaining = bracket.rounds.length - roundIndex - 1;
    final stage = isFinal
        ? 'won'
        : switch (nextRemaining) {
            1 => 'final',
            2 => 'semi',
            _ => 'quarter',
          };
    unawaited(
      TournamentProgressPublisher.publish(
        repository: widget.repository,
        stage: userLost ? 'lost' : stage,
        userScore: userScore,
        opponentScore: opponentScore,
        botWinners: winners.map((winner) => winner.name).toList(),
      ),
    );
  }

  /// Doluluk gövdenin önünde: oyuncu önce "ne kadar kaldı"yı görür.
  String _waitingMessage(BuildContext context) {
    final body = context.t(K.tournamentWaitingBody);
    final fill = _waitingFill;
    if (fill == null) return body;
    final line = context.t(K.tournamentWaitingFill, {
      'count': groupThousands(fill.count),
      'size': groupThousands(fill.size),
    });
    // 2026-10-29 son kurul: doluluğun yanında 24 saatlik sürenin bittiği
    // an da yazılır (kural gövdede; burada yalnız saat).
    final openedAt = _waitingOpenedAt;
    final due = openedAt == null
        ? null
        : context.t(K.cupFillDeadline, {
            'time': formatMatchDeadline(
              openedAt.add(const Duration(hours: cupFillHours)),
            ),
          });
    // Kalan süre: yalnız açılış anı biliniyorsa. 24 saat dolduysa "başlar"
    // denmez; sunucu en az 2 oyuncu olunca başlatır.
    String? remaining;
    if (openedAt != null) {
      final left = openedAt
          .add(const Duration(hours: cupFillHours))
          .difference(DateTime.now());
      remaining = left.isNegative || left == Duration.zero
          ? context.t(K.cupFillElapsed)
          // Sunucu 24 saat sonunda EN AZ 2 oyuncu ister: tek kişiyken
          // "başlamasına X var" kesin başlangıç sözü olurdu.
          : context.t(
              fill.count >= 2 ? K.cupFillRemaining : K.cupFillRemainingMin,
              {'left': _durationLabel(context, left)},
            );
    }
    // Katılma anında kupa yeniyse (tek kayıt: biz) bunu söyle.
    final fresh = _joinedJustNow && fill.count <= 1
        ? context.t(K.tournamentNeedMore, {
            'n': groupThousands(fill.size - fill.count),
          })
        : null;
    final head = [?fresh, line, ?due, ?remaining].join('\n');
    return '$head\n\n$body';
  }

  /// "5 sa 20 dk" / "42 dk"; en az 1 dk.
  static String _durationLabel(BuildContext context, Duration d) {
    final minutes = d.inMinutes < 1 ? 1 : d.inMinutes;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0
        ? context.t(K.cupDurationHM, {'h': '$h', 'm': '$m'})
        : context.t(K.cupDurationM, {'m': '$m'});
  }

  /// `get_tournament_bracket` doluluk alanlarıyla birlikte `createdAt` =
  /// `opened_at` döndürür (2026-10-27_turnuva_doluluk.sql). Eski RPC'de
  /// `createdAt` yoktu ve model "şimdi"ye düşerdi; o zaman saat yazılmaz.
  static DateTime? _openedAtOf(TournamentBracket? bracket) {
    if (bracket == null || bracket.entryCount == null) return null;
    return bracket.createdAt;
  }

  static ({int count, int size})? _fillOf(TournamentBracket? bracket) {
    final count = bracket?.entryCount;
    final size = bracket?.size;
    if (count == null || size == null || size <= 0) return null;
    return (count: count, size: size);
  }

  /// Tur adları SONDAN sayılır: son tur her zaman Final'dir.
  ///
  /// Gerçek turnuva `tournaments.size` varsayılanı 4 ile 2 tur (yarı final
  /// + final) oynanıyor; yerel bot benzetimi (`TournamentConfig`) hep 4 tur
  /// (16 oyuncu). Sabit, BAŞTAN sayan tek bir liste ikisine birden
  /// uygulanamaz — gerçek turnuvanın final maçı "Çeyrek Final" diye
  /// etiketleniyordu (2026-08-14 denetimi). `totalRounds`, o an elde olan
  /// `bracket.rounds.length`dir.
  List<String> _roundNames(bool ku, int totalRounds) =>
      tournamentRoundNames(ku, totalRounds);

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
    final showJoinDock =
        !_loading && !_hasError && !_waitingForPlayers && bracket == null;
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
      // Beklerken antrenman kupası (botlarla, ödülsüz) açıkça sunulur;
      // gerçek kupadaki kayıt sürer (2026-10-27).
      body = SliverFillRemaining(
        child: AppEmptyState(
          key: const ValueKey('tournament-waiting'),
          icon: AppIcons.hourglass,
          title: context.t(K.tournamentWaitingTitle),
          message: _waitingMessage(context),
          actionLabel: context.t(K.tournamentPractice),
          actionIcon: AppIcons.trophy,
          onAction: _startingNewTournament
              ? null
              : () => unawaited(_startPracticeCup()),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Antrenman yereldir (botlarla, ödülsüz); sunucudaki kayıt ona
              // dokunmaz: `_startPracticeCup` yalnız bellekteki şemayı kurar,
              // gerçek kupadan ayrılma çağrısı yoktur.
              Text(
                context.t(K.tournamentPracticeNote),
                key: const ValueKey('tournament-practice-note'),
                textAlign: TextAlign.center,
                style: SahneType.caption.copyWith(
                  color: SahneTokens.of(context).tx2,
                ),
              ),
              SahneButton.text(
                key: const ValueKey('tournament-waiting-refresh'),
                // "Tekrar dene" hata gibi okunuyordu; bu yalnız yenilemedir.
                label: context.t(K.refreshAction),
                arrow: false,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
        sliver: SliverToBoxAdapter(
          child: bracket == null
              ? _LobbyView(ku: ku)
              : _buildBracket(context, ku),
        ),
      );
    }

    return SahnePushedPage(
      role: SahneRole.race,
      title: context.t(inBracket ? K.tournamentTitle : K.tournament),
      // Tur bilgisi yalnızca maç kartında gösterilir; burada tekrar
      // edilmez.
      // Yalnız yerel (botlu) şema "antrenman" diye etiketlenir; gerçek
      // kupada bu etiket yanlış olurdu (2026-10-27'ye dek her şemada
      // görünüyordu).
      subtitle: inBracket && !_serverBracket
          ? context.t(K.botTournament)
          : null,
      backLabel: context.t(K.back),
      slivers: [body],
      // W4 (2026-10-28 tur 5): "Turnuvaya katıl" ekranın altına SABİT (Günün
      // turu ve çarktaki gibi); eskiden kahraman kartının içinde, kaydırınca
      // kayboluyordu.
      bottom: showJoinDock
          ? SahneButton.primary(
              key: const ValueKey('tournament-primary-cta'),
              label: context.t(K.joinTournament),
              expand: true,
              onPressed: _startingNewTournament ? null : _startTournament,
            )
          : null,
    );
  }

  Widget _buildBracket(BuildContext context, bool ku) {
    final bracket = _bracket!;
    final userMatch = _userMatch;
    final roundNames = _roundNames(ku, bracket.totalRounds);
    final t = SahneTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Durum kartı yalnızca turnuva aktif değilken (elendi/kazandı)
        // anlam taşır; aktif oyunda maç kartı zaten bağlamı verir.
        if (bracket.status != 'active')
          _StatusCard(
            bracket: bracket,
            ku: ku,
            roundNames: roundNames,
            userId: _userId,
            lastMatch: _lastDoneMatch,
          ),
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
        // Kupa SÜRERKEN elenen oyuncuya katıl düğmesi gösterilmez:
        // `join_tournament` hâlâ kayıtlı olduğu bu kupayı döndürür, düğme hiçbir
        // şey yapmıyordu (4 simülatörlü tur, 2026-10-27). Yerine kupa bitince
        // yenisine katılabileceği söylenir.
        if (bracket.status != 'active' &&
            _serverBracket &&
            bracket.completedAt == null) ...[
          const SizedBox(height: SahneSpace.x3),
          Text(
            context.t(K.tournamentNextAfterFinish),
            key: const ValueKey('tournament-next-after-finish'),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
        ] else if (bracket.status != 'active') ...[
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
            label: context.t(K.joinNewTournament),
            expand: true,
            onPressed: _startingNewTournament
                ? null
                : _startNewTournamentAfterFinish,
          ),
        ],
        // Maçı kazandım, kupa sürüyor: sonucu ve sıradaki adımı üstte söyle.
        // (Eskiden yalnız şema ve ilerleme şeridi vardı; kazandığını oyuncu
        // şemadan çıkarmak zorundaydı — Astra turu, 2026-10-29.) Rakip belli
        // olunca maç bu ekranda açılır: ekran yoklamayla kendiliğinden
        // yenilenir (`_pollOnce`).
        if (bracket.status == 'active' &&
            _userMatch == null &&
            _lastDoneMatch != null &&
            _lastDoneMatch!.winnerId == _userId)
          _MatchWonCard(
            match: _lastDoneMatch!,
            userId: _userId,
            roundName: roundNames[_roundIndexOf(bracket, _lastDoneMatch!)],
            ku: ku,
          ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userMatch!.bothSubmitted
                            ? context.t(K.cupSubmissionsReceived)
                            : context.t(K.tournamentWaitingOpponentScore, {
                                'score': groupThousands(
                                  _userMatch!.playerOneId == _userId
                                      ? _userMatch!.playerOneScore
                                      : _userMatch!.playerTwoScore,
                                ),
                              }),
                        style: SahneType.body.copyWith(color: t.tx2),
                      ),
                      // Sunucu süre dolunca skor göndereni hükmen geçirir
                      // (`resolve_expired_tournament_matches`); kural yalnız
                      // gerçek şemada ve son tarih biliniyorsa yazılır.
                      if (!_userMatch!.bothSubmitted)
                        if (_userMatch?.deadline case final deadline?) ...[
                          const SizedBox(height: SahneSpace.x1),
                          Text(
                            key: const ValueKey('tournament-awaiting-deadline'),
                            deadline.isBefore(DateTime.now())
                                ? context.t(K.tournamentWaitingOpponentExpired)
                                : context.t(
                                    K.tournamentWaitingOpponentDeadline,
                                    {'time': formatMatchDeadline(deadline)},
                                  ),
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                        ],
                    ],
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
          userId: _userId,
        ),
        if (_standings.isNotEmpty) ...[
          SahneSectionHeader(title: context.t(K.standings)),
          Padding(
            padding: const EdgeInsets.only(bottom: SahneSpace.x2),
            child: Text(
              Tr.forKu(K.cupStandingsNote, ku),
              key: const ValueKey('tournament-standings-note'),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
          ),
          SahneListGroup(
            children: [
              for (final s in _standings)
                SahneListRow.rank(
                  rank: s.rank,
                  title: PlayerIdentity.resolveNameWithTag(
                    s.profile?.displayName ?? s.playerName,
                    isKu: ku,
                    tag: s.profile?.playerTag,
                  ),
                  avatar: s.profile == null
                      ? null
                      : PlayerAvatar.fromIdentity(
                          radius: 18,
                          identity: s.profile!.avatar,
                          displayName: s.profile!.displayName ?? s.playerName,
                        ),
                  initial: s.playerName.trim().isEmpty
                      ? null
                      : SahneType.upperFor(s.playerName.trim()[0], isKu: ku),
                  icon: AppIcons.user,
                  // Sıra önce kupadaki duruma, sonra puana göredir; durum
                  // yazılmayınca 0 puanlı bekleyen, 122 puanlı elenenin
                  // üstünde sebepsiz görünüyordu (Astra turu).
                  subtitle: [
                    switch (s.status) {
                      'champion' => Tr.forKu(
                        K.champion,
                        ku,
                      ).replaceAll('!', ''),
                      'finalist' => Tr.forKu(K.cupStandingFinalist, ku),
                      'eliminated' => Tr.forKu(K.eliminated, ku),
                      _ => Tr.forKu(K.cupStandingActive, ku),
                    },
                    if (s.wonByForfeit) Tr.forKu(K.cupAdvancedByForfeit, ku),
                    if (s.hasSubmitted == false)
                      tournamentSubmissionLabel(
                        false,
                        s.totalScore,
                        ku,
                        completed:
                            s.status == 'eliminated' ||
                            bracket.status == 'completed',
                      )!,
                  ].join(' · '),
                  trailing: s.hasSubmitted == false
                      ? null
                      : SahneRowValue(
                          tournamentSubmissionLabel(
                                s.hasSubmitted,
                                s.totalScore,
                                ku,
                              ) ??
                              groupThousands(s.totalScore),
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.ku});

  final bool ku;

  @override
  Widget build(BuildContext context) {
    // Kupanın ne zaman başlayacağı: kontenjan dolunca, dolmazsa 24 saat
    // sonunda eldeki oyuncularla. Eski "Her Cumartesi 20:00" metni bu
    // kuraldan önce yazılmıştı ve gerçeği anlatmıyordu (2026-07-27).
    // Kurul 2. tur 2026-10-20: başlama koşulu iki ayrı yerde, ikincisi
    // yarım cümle olarak ("En geç 24 saat içinde, eldeki oyuncularla")
    // durup kesilmiş gibi okunuyordu. İkisi kahramanın alt satırında TEK
    // cümle; alt satır sarar, kesilmez.
    //
    // Y7 (2026-10-29 tur 6): hero açıklaması TEK satır ("Dolunca ya da 24 saat
    // sonra başlar"); "dolmazsa eldeki oyuncularla" sunucu kuralına uymuyordu
    // (24 saat sonra EN AZ 2 oyuncu gerekir) — doğru ayrıntı "Nasıl oynanır?"
    // içinde. Rakip deseni: mağaza kartlarında tek satırlık alt metin.
    final scheduleText = context.t(K.cupStartsShortMin);

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
        // Durum çipi ("Başlamadı") KALKTI (2026-10-28 kurul K16): hemen
        // altındaki "Turnuvaya katıl" ile çelişiyordu; başlama koşulu alt
        // başlıkta zaten yazılı.
        //
        // Ödül GERÇEK sabitten gelir ve açıkça "Ödül: 200 jeton" yazılır
        // (şampiyona gittiği kurallarda). Maç başı jeton kasıtlı olarak yok:
        // sunucu maç başına hiçbir coin ödemiyor (2026-08-14 denetimi).
        _CupRewardLine(
          text: context.t(K.cupRewardLine, {
            'n': groupThousands(TournamentConfig.coinBonusChampion),
          }),
        ),
        // 2026-10-29 son kurul: "Dolunca" neyin dolacağını söylemiyordu.
        // Lobide (katılmadan) sunucu doluluk vermez — `get_tournament_bracket`
        // yalnız kayıtlı oyuncuya döner; burada kapasite yazılır, katılınca
        // bekleme ekranı "n/4" ve süre sonunu gösterir.
        _CupRewardLine(
          key: const ValueKey('tournament-capacity'),
          text:
              '${groupThousands(TournamentConfig.totalPlayers)} ${context.t(K.cupPlayers)}',
          icon: AppIcons.peopleGroup,
        ),
      ],
    );

    final format = _CupFormatPanel(ku: ku);
    final ladder = _CupLadder(ku: ku);
    final rules = _CupRulesPanel(
      key: const ValueKey('tournament-rules-panel'),
      ku: ku,
    );

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
                    children: [ladder, format, rules],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // Vay 2A: eleme şeması kahramanın hemen altında (turnuvanın "ne"si
          // ilk ekranda görünsün); biçim karoları ondan sonra.
          children: [hero, ladder, format, rules],
        );
      },
    );
  }
}

/// "Ödül: 200 jeton" çipi. [RewardToken] tek satıra kesiyordu (320 pt + %200
/// yazıda "Ödül: 200 jet…"); ödül metni OKUNAKLI olmalı, bu yüzden sarar.
class _CupRewardLine extends StatelessWidget {
  const _CupRewardLine({super.key, required this.text, this.icon});

  final String text;

  /// `null` → jeton glifi (ödül çipi); doluysa bilgi çipi (ör. kapasite).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      key: icon == null ? const ValueKey('tournament-reward') : null,
      label: text,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  const SahneGlyph(SahneGlyphKind.coin, size: 20)
                else
                  Icon(icon, size: 20, color: t.tx2),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    text,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Nasıl oynanır?": kupanın üç kuralı (2026-10-28 görsel kurul — lobinin
/// alt yarısı boştu ve oyuncu sunucu puanlamasını, süreyi bilmiyordu).
/// Kurallar sunucuyla birebir: aynı sorular, 100 + en çok 50 hız puanı,
/// 24 saatte oynanmayan maç hükmen.
class _CupRulesPanel extends StatefulWidget {
  const _CupRulesPanel({super.key, required this.ku});

  final bool ku;

  @override
  State<_CupRulesPanel> createState() => _CupRulesPanelState();
}

class _CupRulesPanelState extends State<_CupRulesPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ku = widget.ku;
    final t = SahneTokens.of(context);
    final rules = <(IconData, String)>[
      (AppIcons.hourglass, Tr.forKu(K.cupRuleStart, ku)),
      (AppIcons.peopleGroup, Tr.forKu(K.cupRuleSameQuestions, ku)),
      (AppIcons.bolt, Tr.forKu(K.cupRuleServerScore, ku)),
      (AppIcons.clock, Tr.forKu(K.cupRuleDeadline, ku)),
    ];
    // Katlanır (2026-10-28 kurul K16): kurallar üç satır ama her biri bir
    // cümle; lobi ilk bakışta yalnız ödül + katıl + format söylesin,
    // "Nasıl oynanır?" dokununca açılır.
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.sectionTop),
      child: SahneSurfaceCard(
        key: const ValueKey('tournament-rules'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              excludeSemantics: true,
              label: Tr.forKu(K.howToPlay, ku),
              onTap: () => setState(() => _open = !_open),
              child: InkWell(
                key: const ValueKey('tournament-rules-toggle'),
                onTap: () => setState(() => _open = !_open),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SahneSpace.x4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            Tr.forKu(K.howToPlay, ku),
                            style: SahneType.bodyStrong.copyWith(color: t.tx),
                          ),
                        ),
                        Icon(
                          _open ? AppIcons.chevronUp : AppIcons.chevronDown,
                          size: 20,
                          color: t.tx3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.x4,
                  0,
                  SahneSpace.x4,
                  SahneSpace.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rules.length; i++) ...[
                      if (i > 0) const SizedBox(height: SahneSpace.x3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(rules[i].$1, size: 20, color: t.goldTx),
                          const SizedBox(width: SahneSpace.x3),
                          Expanded(
                            child: Text(
                              rules[i].$2,
                              style: SahneType.body.copyWith(color: t.tx),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
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
        groupThousands(TournamentConfig.totalPlayers),
        Tr.forKu(K.cupPlayers, ku),
      ),
      (
        AppIcons.trophy,
        groupThousands(TournamentConfig.roundCount),
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
              // Kurul 4. tur (10): karolar yalnız solu dolduruyor, sağ yarı
              // boş kalıyordu; normal yazıda satırı eşit paylaşırlar, büyük
              // yazıda sarmaya döner.
              if (MediaQuery.textScalerOf(context).scale(16) >= 24)
                Wrap(
                  spacing: SahneSpace.x2,
                  runSpacing: SahneSpace.x2,
                  children: [
                    for (final item in items)
                      _CupStat(icon: item.$1, value: item.$2, label: item.$3),
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: SahneSpace.x2),
                        Expanded(
                          child: _CupStat(
                            icon: items[i].$1,
                            value: items[i].$2,
                            label: items[i].$3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kupa yolu: 4 → 2 → 1 eleme ŞEMASI.
///
/// Vay 2A (2026-10-29, Astra turnuva 5,5/10 — "turnuva yolu birkaç etikete
/// indirgenmiş; rakip, rekabet ve ilerleme hissi oluşmuyor"): yatay çip
/// dizisi yerine Clash/TRT tarzı braket ([SahneBracket]): ilk sütunda
/// oyuncu yuvaları (ilki "Sen", ötekiler henüz belli olmayan rakipler "?"),
/// 2 px çizgilerle sonraki tura, en sağda altın taçlı şampiyon yuvası.
/// Sütun adları turların adlarıdır; ekran okuyucu tek cümlede bütün yolu
/// duyar ("Yarı Final · 4 oyuncu › Final · 2 oyuncu › Şampiyon"). Basamak
/// sayıları `TournamentConfig.generateBracket` ile aynı bölmeden türer.
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
    final roundNames = tournamentRoundNames(ku, steps.length - 1);
    final champion = Tr.forKu(K.champion, ku).replaceAll('!', '');
    final labels = [
      for (var i = 0; i < steps.length; i++)
        steps[i] == 1 ? champion : roundNames[i],
    ];
    final spoken = [
      for (var i = 0; i < steps.length; i++)
        steps[i] == 1
            ? champion
            : '${roundNames[i]} · ${groupThousands(steps[i])} ${Tr.forKu(K.cupPlayers, ku)}',
    ].join(' › ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneSectionHeader(title: Tr.forKu(K.cupLadder, ku)),
        SahneSurfaceCard(
          child: SahneBracket(
            key: const ValueKey('tournament-bracket-preview'),
            semanticLabel: spoken,
            roundLabels: labels,
            // Katılmadan kimse şemaya konmaz: 2026-10-29 Astra turu, "Sen"
            // yazan önizleme oyuncuya yeri çoktan ayrılmış gibi okunuyordu.
            entrants: [
              for (var i = 0; i < TournamentConfig.totalPlayers; i++)
                const SahneBracketEntrant(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x2),
          child: Text(
            Tr.forKu(K.cupLadderPreviewNote, ku),
            key: const ValueKey('tournament-ladder-preview-note'),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
      ],
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
    this.userId = '',
  });

  final List<String> roundNames;
  final List<TournamentRound> rounds;
  final int currentRound;
  final String bracketStatus;
  final String userId;

  /// Kurul 3 D16 (3/3): yarı finalini KAZANMIŞ oyuncuda diğer yarı final
  /// sürerken şerit hâlâ "Yarı Final"i etkin (oynat simgesiyle) gösteriyordu;
  /// oyuncunun sıradaki aşaması Final'dir. Oyuncunun kendi tamamlanmış ve
  /// kazanılmış maçı varsa o tur onun için bitmiştir; etkin aşama bir
  /// sonrakidir (henüz kurulmadıysa bekleme simgesiyle).
  int get _userStage {
    if (userId.isEmpty || bracketStatus != 'active') return currentRound;
    if (currentRound >= rounds.length) return currentRound;
    final mine = rounds[currentRound].matches.where(
      (m) => m.playerOneId == userId || m.playerTwoId == userId,
    );
    final won = mine.any(
      (m) => m.status == 'completed' && m.winnerId == userId,
    );
    return won && currentRound + 1 < roundNames.length
        ? currentRound + 1
        : currentRound;
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Wrap(
      spacing: SahneSpace.x1,
      runSpacing: SahneSpace.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Henüz kurulmamış turlar da (sunucu sonraki turu kazananlar belli
        // olunca kurar) "sırada" olarak görünür: kupanın yolu baştan bellidir.
        for (var i = 0; i < roundNames.length; i++) ...[
          if (i > 0)
            ExcludeSemantics(
              child: Icon(AppIcons.chevronRight, size: 16, color: t.tx3),
            ),
          _RoundPill(
            label: roundNames[i],
            // Durum GERÇEK tur verisinden gelir; sıra numarasından tahmin
            // edilmez. Turnuva bittiyse hiçbir tur "şu an oynanıyor" diye
            // işaretlenmez.
            state:
                bracketStatus == 'completed' ||
                    (i < rounds.length &&
                        (rounds[i].status == 'completed' ||
                            (rounds[i].matches.isNotEmpty &&
                                rounds[i].matches.every(
                                  (m) => m.status == 'completed',
                                )))) ||
                    (bracketStatus == 'active' && i < _userStage)
                ? _RoundState.done
                : (bracketStatus == 'active' && i == _userStage)
                ? (i > currentRound ? _RoundState.waiting : _RoundState.active)
                : _RoundState.upcoming,
          ),
        ],
      ],
    );
  }
}

enum _RoundState { done, active, waiting, upcoming }

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
      // Oyuncunun sıradaki aşaması, rakibi henüz belli değil.
      _RoundState.waiting => (t.raceTint, t.raceTx, AppIcons.hourglass),
      _RoundState.upcoming => (t.s2, t.tx2, AppIcons.clock),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: bg,
        shape: state == _RoundState.active || state == _RoundState.waiting
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
    required this.userId,
    this.lastMatch,
  });

  final TournamentBracket bracket;
  final bool ku;
  final List<String> roundNames;
  final String userId;

  /// Kullanıcının son bitmiş maçı: elenme kartı skor ve rakibi yazar.
  final TournamentMatch? lastMatch;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Elenen oyuncunun turu kendi son maçından okunur; bkz.
    // [TournamentBracket.lastRoundIndexOf].
    final shownRound = bracket.status == 'eliminated'
        ? bracket.lastRoundIndexOf(userId) ?? bracket.currentRound
        : bracket.currentRound;
    final runnerUp =
        bracket.status == 'eliminated' &&
        shownRound == bracket.totalRounds - 1 &&
        lastMatch?.status == 'completed' &&
        lastMatch?.winnerId.isNotEmpty == true &&
        lastMatch?.winnerId != userId;
    final statusLabel = switch (bracket.status) {
      'won' => context.t(K.champion),
      'eliminated' => context.t(runnerUp ? K.tournamentRunnerUp : K.eliminated),
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
                    !runnerUp &&
                    shownRound < roundNames.length)
                  Text(
                    Tr.forKu(K.cupEliminatedRound, ku, {
                      'round': roundNames[shownRound],
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                if (bracket.status == 'eliminated' && lastMatch != null)
                  Text(
                    _matchVsLine(lastMatch!, userId, ku, owned: runnerUp),
                    key: const ValueKey('tournament-eliminated-vs'),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                if (bracket.totalScore > 0)
                  Text(
                    '${Tr.forKu(K.statTotalScore, ku)}: ${groupThousands(bracket.totalScore)}',
                    maxLines: 1,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          SahneBadge(
            // "1/2" tek başına belirsizdi: ne olduğu yazılır.
            label: Tr.forKu(K.cupRoundBadge, ku, {
              'n': groupThousands(
                (shownRound + 1).clamp(1, bracket.totalRounds),
              ),
              'total': groupThousands(bracket.totalRounds),
            }),
            tone: SahneBadgeTone.gold,
          ),
        ],
      ),
    );
  }
}

/// "Rakip karşısında benim – onun" satırı.
String _matchVsLine(
  TournamentMatch m,
  String userId,
  bool ku, {
  bool owned = false,
}) {
  if (m.isForfeit) {
    final winner = m.winnerId == m.playerOneId
        ? m.playerOneName
        : m.playerTwoName;
    return '$winner · ${Tr.forKu(K.cupAdvancedByForfeit, ku)}';
  }
  if (m.closedWithoutSubmission) return Tr.forKu(K.cupExpiredUnplayed, ku);
  final mine = m.playerOneId == userId;
  return Tr.forKu(owned ? K.cupOwnedMatchVs : K.cupMatchVs, ku, {
    'opponent': mine ? m.playerTwoName : m.playerOneName,
    'my': groupThousands(mine ? m.playerOneScore : m.playerTwoScore),
    'their': groupThousands(mine ? m.playerTwoScore : m.playerOneScore),
  });
}

/// Kazanılan maçın sonuç kartı: ne oldu ve sıradaki adım ne.
class _MatchWonCard extends StatelessWidget {
  const _MatchWonCard({
    required this.match,
    required this.userId,
    required this.roundName,
    required this.ku,
  });

  final TournamentMatch match;
  final String userId;
  final String roundName;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.cardGap),
      child: SahneSurfaceCard(
        key: const ValueKey('tournament-match-won'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.trophy, size: 20, color: t.goldTx),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.forKu(K.cupWonRound, ku, {'round': roundName}),
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                  Text(
                    _matchVsLine(match, userId, ku),
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    Tr.forKu(K.cupWonNext, ku),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      subtitle: '${context.t(K.statTotalScore)}: ${groupThousands(finalScore)}',
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
            value: groupThousands(rewardAmount),
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
                  if (me)
                    Text(
                      context.t(K.you),
                      key: const ValueKey('tournament-match-self-mark'),
                      style: SahneType.captionStrong.copyWith(color: t.goldTx),
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
