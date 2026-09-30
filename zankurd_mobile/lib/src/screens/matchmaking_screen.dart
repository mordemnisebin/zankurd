import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/avatar_identity.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../widgets/kilim_progress_bar.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_moderation_button.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/sahne/sahne.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../services/analytics_service.dart';
import '../services/matchmaking_metrics.dart';
import '../utils/test_environment.dart';
import '../widgets/app_state.dart';
import 'async_duel/async_duel_play_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../config/bot_names.dart';
import '../config/category_visuals.dart';
import '../config/feature_flags.dart';
import '../widgets/dialog_action_pair.dart';

Player? selectOpponentPlayer(
  Iterable<Player> players, {
  required String? currentPlayerId,
  required String currentName,
  String? preferredName,
}) {
  final preferred = preferredName?.trim();
  if (preferred != null && preferred.isNotEmpty) {
    for (final player in players) {
      if (player.name == preferred &&
          !playerMatchesIdentity(
            player,
            id: currentPlayerId,
            legacyName: currentName,
          )) {
        return player;
      }
    }
  }
  for (final player in players) {
    if (!playerMatchesIdentity(
      player,
      id: currentPlayerId,
      legacyName: currentName,
    )) {
      return player;
    }
  }
  return null;
}

/// 20sn'de rakip bulunamayınca oyuncunun `_showBotPrompt` diyaloğunda
/// verdiği karar.
enum _NoOpponentChoice {
  /// Aramadan tamamen vazgeç (eski "Hayır"ın karşılığı).
  cancel,

  /// Botla hemen oyna (eski "Evet").
  bot,

  /// Sırayla düello başlat: rakip aynı anda çevrimiçi olmasa da katılır.
  asyncDuel,
}

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({
    required this.repository,
    this.metrics,
    this.asyncDuelEnabled = kAsyncDuelEnabled,
    super.key,
  });

  final ZanKurdRepository repository;
  final MatchmakingMetrics? metrics;

  /// Varsayılanı [kAsyncDuelEnabled]; testler ve ekran turu bayrak
  /// kapalıyken de "sırayla düello" teklifini açabilsin diye parametredir
  /// (bkz. `PlayHubScreen.asyncDuelEnabled` — aynı desen).
  final bool asyncDuelEnabled;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  static const _joinSettleTimeout = Duration(seconds: 10);

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

  /// Rakibin kimliği — bildir/engelle için gerekli.
  ///
  /// Bot rakipte `null` kalır: bot bildirilebilir bir kullanıcı değildir
  /// ve sunucuya gönderilecek bir kimliği yoktur.
  String? _opponentId;

  /// Rakip bu oturumda engellendi mi; VS kartındaki fotoğraf/ad bunun
  /// yerine geçer.
  ///
  /// `PlayerModerationButton.onBlocked` tanımlıydı ama bu ekranda hiçbir
  /// yere bağlı değildi: rakip engellendiğinde düğme "Oyuncu engellendi"
  /// diyordu ama aynı fotoğraf ve ad tam ekran VS kartında görünmeye
  /// devam ediyordu — kullanıcı tam da engellemek istediği şeyi görmeye
  /// devam ediyordu (2026-08-14 denetimi). Eşleşmenin kendisi iptal
  /// edilmez (oyun sunucuda zaten kurulu); yalnız istemcide gösterilen
  /// UGC (fotoğraf + ad) gizlenir.
  bool _opponentBlocked = false;
  int _opponentLevel = 1;

  /// `_opponentLevel` gerçek bir veriyi mi yansıtıyor.
  ///
  /// Eskiden gerçek rakip için de `_myLevel + Random().nextInt(3) - 1`
  /// hesaplanıyordu — sunucu opponent'ın gerçek seviyesini hiç döndürmüyor,
  /// bu tamamen uydurmaydı ve sunucuya yazılamayan bir başarıyı bildirmekle
  /// aynı sınıf hata: kullanıcıya var olmayan bir veriyi gerçekmiş gibi
  /// sunuyordu (2026-08-14 denetimi). Yalnız bot düellosunda (kasıtlı
  /// sentetik rakip) `true` olur; gerçek eşleşmede seviye rozeti gizlenir.
  bool _opponentLevelKnown = false;
  String? _profileName;

  String get _myName => _profileName ?? (context.t(K.playerWord));
  bool _isCancelled = false;
  bool _cancelling = false;
  bool _cancelRequested = false;

  /// İptal RPC'si en az bir kez başarısız oldu.
  ///
  /// Ekrandan çıkan her yol tek bir iptal çağrısına bağlı ve arama
  /// başladıktan sonra `canPop` kapalı. İptal de başarısız olduğunda geriye
  /// hiçbir çıkış kalmıyordu; ağı kopmuş oyuncu için uygulamayı zorla
  /// kapatmak tek seçenekti (2026-08-03). Hayalet kuyruk kaygısı yerinde
  /// ama takas yanlış taraftaydı: sunucudaki artık kuyruk satırı
  /// süpürülebilir, hapsolmuş kullanıcı süpürülemez. İlk hata hâlâ
  /// gösterilir ve yeniden denenebilir; ısrar eden oyuncu çıkar.
  bool _cancelFailed = false;
  int _matchmakingAttempt = 0;
  Future<Map<String, dynamic>>? _joinRequest;
  // Bot diyaloğu açıkken arka plan sayacı gizlenir (zamanlayıcı zaten durmuş
  // olur; ekranda donuk "X sn" çipi kalmasın).
  bool _botPromptOpen = false;

  bool _searchingStarted = false;
  List<String> _categories = const [];
  bool _loadingCategories = false;
  bool _categoriesError = false;
  String? _lastMatchCategory;
  String? _matchmakingErrorMessage;

  StreamSubscription? _matchmakingSub;
  Timer? _statusTimer;
  int _secondsElapsed = 0;
  final Stopwatch _matchmakingClock = Stopwatch()..start();
  late final MatchmakingMetrics _matchmakingMetrics;

  @override
  void initState() {
    super.initState();
    _matchmakingMetrics =
        widget.metrics ??
        MatchmakingMetrics(
          elapsed: () => _matchmakingClock.elapsed,
          record: (parameters) {
            AnalyticsService.instance.logMatchmakingWait(
              outcome: parameters['outcome']! as String,
              waitSeconds: parameters['wait_seconds']! as int,
            );
          },
        );
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Sonsuz animasyonlar "hareketi azalt" açıkken HİÇ başlamaz.
    //
    // 2026-07-31'e kadar tek koşul test ortamıydı: yani animasyonlar
    // yalnız test koşucusunda duruyordu, gerçek kullanıcının tercihi
    // hiçbirini etkilemiyordu. Radar ve nabız eşleşme beklenirken
    // sürekli döndüğü için en rahatsız edici olanlardı.
    //
    // `addPostFrameCallback`: provider'a `initState` içinde `listen: true`
    // ile erişilemez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = ReducedMotionProvider.isReducedIn(context);
      if (isFlutterTestEnvironment || reduce) return;
      _radarController.repeat();
      _pulseController.repeat(reverse: true);
    });

    _loadCategoriesOnly();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _matchmakingSub?.cancel();
    _statusTimer?.cancel();
    if (_searchingStarted && !_isCancelled && !_found) {
      _cancelRequested = true;
      final cleanupGeneration = ++_matchmakingAttempt;
      unawaited(
        _cancelDisposedSearch(
          _joinRequest,
          widget.repository,
          cleanupGeneration,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _cancelDisposedSearch(
    Future<Map<String, dynamic>>? pendingJoin,
    ZanKurdRepository repository,
    int cleanupGeneration,
  ) async {
    var joinTimedOut = false;
    try {
      if (pendingJoin != null) {
        try {
          await pendingJoin.timeout(_joinSettleTimeout);
        } on TimeoutException catch (error, stack) {
          joinTimedOut = true;
          ErrorReporter.record(
            error,
            stack,
            reason: 'matchmaking_dispose_join_timeout',
          );
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'matchmaking_dispose_join_settle',
          );
        }
      }
      final result = await repository.cancelMatchmaking();
      final roomId = _matchedRoomId(result);
      if (roomId != null) {
        // Ekran kapanırken eşleşme cevabı geç geldiyse bekleme sonucu
        // iptal değil, gerçek rakip eşleşmesidir.
        _matchmakingMetrics.finish(MatchmakingOutcome.human);
        await repository.leaveOnlineRoom(_roomReference(roomId));
        joinTimedOut = false;
      } else {
        _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_dispose_cancel');
    } finally {
      if (joinTimedOut && pendingJoin != null) {
        unawaited(_cleanupLateJoin(pendingJoin, repository, cleanupGeneration));
      }
    }
  }

  Future<void> _handleCancelAndPop() async {
    if (_cancelling) return;
    final pendingJoin = _joinRequest;
    final repository = widget.repository;
    final cleanupGeneration = ++_matchmakingAttempt;

    // İptal zaten bir kez başarısız oldu ve oyuncu yine çıkmak istiyor.
    // Ağ geri gelene kadar RPC'yi beklemek onu ekranda tutmaktan başka bir
    // şey yapmaz; çıkışı hemen ver, temizliği arka planda en iyi çaba
    // olarak sürdür.
    if (_cancelFailed) {
      _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
      _matchmakingSub?.cancel();
      _matchmakingSub = null;
      _statusTimer?.cancel();
      _statusTimer = null;
      unawaited(_bestEffortCancel(pendingJoin, repository, cleanupGeneration));
      if (mounted) {
        setState(() {
          _isCancelled = true;
          _cancelRequested = true;
        });
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {
      _cancelling = true;
      _cancelRequested = true;
      _statusTextKu = 'Tê betalkirin...';
      _statusTextTr = 'İptal ediliyor...';
    });

    _matchmakingSub?.cancel();
    _matchmakingSub = null;
    _statusTimer?.cancel();
    _statusTimer = null;

    var joinTimedOut = false;
    try {
      // Katılma isteği ağda hâlâ ilerliyorsa önce onun kesin sonucunu bekle.
      // Aksi hâlde iptal RPC'si "idle" dönüp hemen ardından join kuyruğa
      // yazabilir ve ekrandan çıkan oyuncuyu hayalet kayıt olarak bırakır.
      if (pendingJoin != null) {
        try {
          await pendingJoin.timeout(_joinSettleTimeout);
        } on TimeoutException catch (error, stack) {
          joinTimedOut = true;
          ErrorReporter.record(
            error,
            stack,
            reason: 'matchmaking_join_settle_timeout',
          );
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'matchmaking_join_settle_before_cancel',
          );
        }
      }

      final result = await repository.cancelMatchmaking();
      final matchedRoomId = _matchedRoomId(result);
      if (matchedRoomId != null) {
        _matchmakingMetrics.finish(MatchmakingOutcome.human);
        await repository.leaveOnlineRoom(_roomReference(matchedRoomId));
        joinTimedOut = false;
      } else {
        _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_cancel_and_pop');
      _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
      _cancelFailed = true;
      if (mounted) {
        setState(() {
          _cancelling = false;
          _matchmakingErrorMessage = context.t(K.matchFailed);
        });
      }
      if (joinTimedOut && pendingJoin != null) {
        unawaited(_cleanupLateJoin(pendingJoin, repository, cleanupGeneration));
      }
      return;
    }

    if (joinTimedOut && pendingJoin != null) {
      unawaited(_cleanupLateJoin(pendingJoin, repository, cleanupGeneration));
    }

    if (mounted) {
      setState(() {
        _isCancelled = true;
        _cancelling = false;
      });
      Navigator.of(context).pop();
    }
  }

  /// Ekrandan çıkıldıktan sonra kuyruğu kapatmayı sürdürür.
  ///
  /// Oyuncu artık beklemiyor, bu yüzden hata yüzeye çıkmaz; kullanılan tek
  /// güvence `_cleanupLateJoin`in nesil kontrolüdür — yeni bir arama
  /// başladıysa bu geç temizlik onun odasını terk etmez.
  Future<void> _bestEffortCancel(
    Future<Map<String, dynamic>>? pendingJoin,
    ZanKurdRepository repository,
    int cleanupGeneration,
  ) async {
    if (pendingJoin != null) {
      await _cleanupLateJoin(pendingJoin, repository, cleanupGeneration);
      return;
    }
    try {
      final cancellation = await repository.cancelMatchmaking();
      if (_matchmakingAttempt != cleanupGeneration) return;
      final cancellationRoomId = _matchedRoomId(cancellation);
      if (cancellationRoomId != null) {
        await repository.leaveOnlineRoom(_roomReference(cancellationRoomId));
      }
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'matchmaking_best_effort_cancel',
      );
    }
  }

  Future<void> _cleanupLateJoin(
    Future<Map<String, dynamic>> pendingJoin,
    ZanKurdRepository repository,
    int cleanupGeneration,
  ) async {
    try {
      final joinResult = await pendingJoin;
      // Retry başladıysa yeni RPC aynı canlı üyeliği idempotent biçimde
      // döndürebilir. Eski temizliğin bu odayı terk etmesi yeni maçı forfeit
      // eder; yeni nesil artık sunucu üyeliğinin tek sahibidir.
      if (_matchmakingAttempt != cleanupGeneration) return;
      final matchedRoomId = joinResult['status'] == 'matched'
          ? joinResult['room_id'] as String?
          : null;
      if (matchedRoomId != null && matchedRoomId.trim().isNotEmpty) {
        await repository.leaveOnlineRoom(_roomReference(matchedRoomId));
        return;
      }

      // Yeni bir arama başladıysa kullanıcıya ait tek sunucu kuyruğunu eski
      // isteğin temizliğiyle silme. Eski istek hâlâ son denemeyse ikinci
      // iptal, timeout sonrasında oluşabilecek hayalet kuyruk kaydını kapatır.
      final cancellation = await repository.cancelMatchmaking();
      final cancellationRoomId = _matchedRoomId(cancellation);
      if (cancellationRoomId != null) {
        await repository.leaveOnlineRoom(_roomReference(cancellationRoomId));
      }
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'matchmaking_late_join_cleanup',
      );
    }
  }

  bool _isAttemptActive(int attempt) =>
      attempt == _matchmakingAttempt &&
      !_cancelRequested &&
      !_isCancelled &&
      mounted;

  Future<void> _loadCategoriesOnly() async {
    if (_loadingCategories) return;
    setState(() {
      _loadingCategories = true;
      _categoriesError = false;
      _categories = const [];
    });
    try {
      final name = await widget.repository.getProfileName();
      final identity = await widget.repository.loadAvatarIdentity();
      final xpStore = await XPStore.load();
      final level = xpStore.currentLevel;
      final cats = await widget.repository.loadMatchmakingCategories();
      if (!mounted) return;
      setState(() {
        _profileName = name;
        _myIdentity = identity;
        _myLevel = level;
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_load_categories');
      if (mounted) {
        setState(() {
          _loadingCategories = false;
          _categoriesError = true;
        });
      }
    }
  }

  Future<void> _startMatchmaking(String chosenCategory) async {
    final attempt = ++_matchmakingAttempt;
    final ku = context.isKu;
    _lastMatchCategory = chosenCategory;
    _cancelRequested = false;
    // Yeni arama, iptal borcunu da sıfırlar. Aksi hâlde ağ geri geldikten
    // sonra başlatılan aramada iptal hâlâ "ateşle-unut" kalır ve hayalet
    // kuyruğa karşı koruma sessizce kaybolurdu.
    _cancelFailed = false;
    _matchmakingMetrics.start();
    AnalyticsService.instance.logActivationStep('matchmaking_started');
    // Eşleşme akışı asenkron: rakip adı yer tutucusu, `context` async
    // boşluğun ötesine taşınmasın diye burada, senkron olarak çözülür.
    final opponentPlaceholder = context.t(K.opponentWord);
    setState(() {
      _searchingStarted = true;
      _categoryName = chosenCategory;
      _statusTextKu = 'Lîstikvanek tê gerîn...';
      _statusTextTr = 'Rakip aranıyor...';
      _found = false;
      _matchmakingErrorMessage = null;
      _opponentIdentity = const AvatarIdentity();
      _opponentId = null;
      // Yeni arama yeni bir rakip getirir; önceki rakibin engeli bu
      // ekranın yerel görüntüsünde kalıcı değil (gerçek engel sunucuda
      // duruyor, bir sonraki eşleşmede yine rakip olmaz zaten — bkz.
      // eşleştirme kuyruğu engellenenleri süzer).
      _opponentBlocked = false;
      _secondsElapsed = 0;
    });

    try {
      // Join the matchmaking queue in Supabase
      final request = widget.repository.joinMatchmaking(chosenCategory);
      _joinRequest = request;
      late final Map<String, dynamic> matchRes;
      try {
        matchRes = await request;
      } finally {
        if (identical(_joinRequest, request)) _joinRequest = null;
      }
      if (!_isAttemptActive(attempt)) return;

      if (matchRes['status'] == 'matched') {
        // Matched immediately!
        var matchedName = matchRes['opponent_name'] as String? ?? 'Raqîb';
        var opponentIdentity = const AvatarIdentity();
        // C-2: null-safe cast — Supabase schema hatası veya edge-case'de
        // String? null dönebilir; null ise navigasyon iptal edilir.
        final roomId = matchRes['room_id'] as String?;
        if (roomId == null) {
          _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
          return; // beklenmedik schema yanıtı
        }
        final matchedRoom = await _loadMatchedRoom(roomId);
        if (!_isAttemptActive(attempt)) return;
        final opponent = selectOpponentPlayer(
          matchedRoom.players,
          currentPlayerId: widget.repository.currentUserId,
          currentName: _myName,
          preferredName: matchedName,
        );
        if (opponent != null) {
          matchedName = opponent.name;
          opponentIdentity = _identityFromPlayer(opponent);
        }

        await _onMatched(
          matchedName,
          opponentIdentity,
          matchedRoom,
          chosenCategory,
          ku,
          attempt,
          opponentId: opponent?.id,
        );
      } else {
        // Status is waiting. Let's subscribe to matchmaking_queue changes.
        _matchmakingSub = widget.repository.subscribeMatchmakingQueue().listen((
          entry,
        ) async {
          if (!_isAttemptActive(attempt)) return;
          if (entry != null && entry['room_id'] != null) {
            _matchmakingSub?.cancel();
            _matchmakingSub = null;
            _statusTimer?.cancel();
            _statusTimer = null;

            // C-2: null-safe cast — subscription yanıtı beklenmedik türde
            // olursa crash yerine sessizce çıkar.
            final roomId = entry['room_id'] as String?;
            if (roomId == null) {
              _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
              return;
            }
            try {
              // Fetch opponent display name
              String matchedName = opponentPlaceholder;
              var opponentIdentity = const AvatarIdentity();
              final matchedRoom = await _loadMatchedRoom(roomId);
              if (!_isAttemptActive(attempt)) return;
              final opponent = selectOpponentPlayer(
                matchedRoom.players,
                currentPlayerId: widget.repository.currentUserId,
                currentName: _myName,
              );
              if (opponent != null) {
                matchedName = opponent.name;
                opponentIdentity = _identityFromPlayer(opponent);
              }

              await _onMatched(
                matchedName,
                opponentIdentity,
                matchedRoom,
                chosenCategory,
                ku,
                attempt,
                opponentId: opponent?.id,
              );
            } catch (error, stack) {
              ErrorReporter.record(
                error,
                stack,
                reason: 'matchmaking_load_room_snapshot',
              );
              if (!_isAttemptActive(attempt)) return;
              setState(() {
                _found = false;
                _matchmakingErrorMessage = context.t(K.matchFailed);
              });
            }
          }
        });

        // Periodically update the status text and count to 30s
        _statusTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) async {
          _secondsElapsed++;
          if (!_isAttemptActive(attempt)) {
            timer.cancel();
            return;
          }

          // 30 saniye, canlı oyuncu havuzu henüz yokken yeni kullanıcıyı
          // boş bir radar ekranında bekletiyordu (2026-07-25 canlı
          // denetimi). Süre kısaltıldı ve durum metniyle hizalandı:
          // 0-12sn "aranıyor", 12-20sn "henüz bulunamadı", 20sn'de bot
          // teklifi. Havuz büyüdüğünde bu değer yeniden uzatılabilir.
          if (_secondsElapsed >= 20) {
            timer.cancel();
            _matchmakingSub?.cancel();
            _matchmakingSub = null;
            Map<String, dynamic> cancellation;
            try {
              cancellation = await widget.repository.cancelMatchmaking();
            } catch (error, stack) {
              ErrorReporter.record(
                error,
                stack,
                reason: 'matchmaking_timeout_cancel',
              );
              _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
              if (mounted) {
                setState(() {
                  _found = false;
                  _matchmakingErrorMessage = context.t(K.matchFailed);
                });
              }
              return;
            }

            try {
              final matchedRoomId = _matchedRoomId(cancellation);
              if (matchedRoomId != null) {
                await _openMatchedRoom(
                  matchedRoomId,
                  chosenCategory,
                  ku,
                  opponentPlaceholder,
                  attempt,
                );
                return;
              }
            } catch (error, stack) {
              ErrorReporter.record(
                error,
                stack,
                reason: 'matchmaking_timeout_matched_room',
              );
              _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
              if (mounted) {
                setState(() {
                  _found = false;
                  _matchmakingErrorMessage = context.t(K.matchFailed);
                });
              }
              return;
            }

            if (!_isAttemptActive(attempt)) return;
            // Ask user for bot fallback / sırayla düello / cancel
            setState(() => _botPromptOpen = true);
            final choice = await _showBotPrompt();
            if (mounted) setState(() => _botPromptOpen = false);
            if (!_isAttemptActive(attempt)) return;
            if (!mounted) return;
            if (choice == _NoOpponentChoice.bot) {
              // M-3: Bot isimleri merkezi config'den; inline liste kaldırıldı.
              final matchedName =
                  BotNames.pool[Random().nextInt(BotNames.pool.length)];
              // Bot kendi beyan edilmiş sentetik bir rakiptir — burada
              // "seviye" gerçek bir kişiyi temsil etmediği için jitter
              // uydurma kuralına takılmaz (bkz. `_opponentLevelKnown`
              // yorumu).
              final botLevel = max(1, _myLevel + Random().nextInt(5) - 2);

              await _onMatched(
                matchedName,
                const AvatarIdentity(),
                null,
                chosenCategory,
                ku,
                attempt,
                opponentLevel: botLevel,
              );
            } else if (choice == _NoOpponentChoice.asyncDuel) {
              _matchmakingMetrics.finish(MatchmakingOutcome.asyncDuel);
              _isCancelled = true;
              // Sunucu 'Rastgele' kategori adını tanımaz; sırayla düello
              // ekranı `category == null` olduğunda kendi rastgele
              // kategori seçimini yapar (bkz. `AsyncDuelPlayScreen`).
              final category = chosenCategory.toLowerCase() == 'rastgele'
                  ? null
                  : chosenCategory;
              Navigator.of(context).pushReplacement(
                AppRoute.to(
                  AsyncDuelPlayScreen(
                    repository: widget.repository,
                    category: category,
                  ),
                ),
              );
            } else {
              // cancel/null: eski "Hayır" dalıyla birebir.
              _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
              _isCancelled = true;
              Navigator.of(context).pop();
            }
          } else {
            setState(() {
              // "Bağlantı kuruluyor..." ara evresi kaldırıldı: kurulan bir
              // bağlantı yok, hâlâ rakip aranıyor. Üstelik alttaki geçen-süre
              // çipi aynı anda "Rakip aranıyor… 19 sn" yazdığı için ekranda
              // iki çelişik durum görünüyordu (2026-07-25 canlı denetimi).
              // Durum metni yalnız gerçekten değişen şeyi söyler.
              if (_secondsElapsed < 12) {
                _statusTextKu = 'Lîstikvanek tê gerîn...';
                _statusTextTr = 'Rakip aranıyor...';
              } else {
                _statusTextKu = 'Hîn lîstikvan nehat dîtin...';
                _statusTextTr = 'Henüz rakip bulunamadı...';
              }
            });
          }
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_start');
      if (!_isAttemptActive(attempt)) return;
      _matchmakingMetrics.finish(MatchmakingOutcome.cancelled);
      _matchmakingSub?.cancel();
      _statusTimer?.cancel();
      setState(() {
        _found = false;
        _matchmakingErrorMessage = context.t(K.matchFailed);
      });
    }
  }

  /// 20sn zaman aşımında oyuncuya sunulan üç seçenek.
  ///
  /// [asyncDuelEnabled] kapalıyken [asyncDuel] hiç üretilmez — diyalog eski
  /// iki düğmeli hâlindedir ve `bot`/`cancel` dışında bir değer dönmez.
  Future<_NoOpponentChoice?> _showBotPrompt() async {
    if (!widget.asyncDuelEnabled) {
      // Bayrak kapalıyken diyalog BİREBİR eski hâlidir: aynı iki metin,
      // aynı iki düğme. Sunucu göçü uygulanana dek (bkz. `kAsyncDuelEnabled`
      // yorumu) mevcut kullanıcı hiçbir fark görmez.
      final playWithBot = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          // 2026-09-29 Şahnê: yazı ve renk temadan; "Hayır" bir hata
          // durumu değil (Şaş kırmızısı kalktı), "Evet" diyaloğun tek
          // birincil eylemi (Agir, koyu metin — temanın düğmesi).
          title: Text(
            context.t(K.searchTimedOut),
            style: SahneType.headline.copyWith(
              color: SahneTokens.of(context).tx,
            ),
          ),
          content: Text(
            context.t(K.playWithBotQ),
            style: SahneType.body.copyWith(color: SahneTokens.of(context).tx2),
          ),
          actions: [
            DialogActionPair(
              cancel: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.t(K.no)),
              ),
              confirm: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.t(K.yes)),
              ),
            ),
          ],
        ),
      );
      return playWithBot == true
          ? _NoOpponentChoice.bot
          : _NoOpponentChoice.cancel;
    }

    return showDialog<_NoOpponentChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          context.t(K.searchTimedOut),
          style: SahneType.headline.copyWith(color: SahneTokens.of(context).tx),
        ),
        content: Text(
          context.t(K.asyncDuelOfferBody),
          style: SahneType.body.copyWith(color: SahneTokens.of(context).tx2),
        ),
        // Üç eylem: hep alt alta, tam genişlikte, birincil üstte
        // (2026-09-30 simülatör: `AlertDialog.actions` üçünü içerik
        // genişliğinde, sağa yaslı diziyordu; bkz. [DialogActionPair]).
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const ValueKey('mm-offer-async-duel'),
                onPressed: () =>
                    Navigator.of(context).pop(_NoOpponentChoice.asyncDuel),
                child: Text(context.t(K.asyncDuel)),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('mm-offer-bot'),
                onPressed: () =>
                    Navigator.of(context).pop(_NoOpponentChoice.bot),
                child: Text(context.t(K.asyncDuelOfferBot)),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('mm-offer-cancel'),
                onPressed: () =>
                    Navigator.of(context).pop(_NoOpponentChoice.cancel),
                child: Text(context.t(K.cancel)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AvatarIdentity _identityFromPlayer(Player player) => AvatarIdentity(
    iconId: player.avatarIcon,
    colorHex: player.avatarColor,
    photoUrl: player.avatarUrl,
    frameId: player.avatarFrame,
    showcaseTitle: player.showcaseTitle,
  );

  Future<GameRoom> _loadMatchedRoom(String roomId) async {
    final room = await widget.repository.loadRoomSnapshot(roomId);
    if (room.id != roomId) {
      throw StateError('Matched room snapshot id does not match room_id.');
    }
    if (room.players.length < 2) {
      throw StateError('Matched room snapshot has fewer than two players.');
    }
    final currentPlayerId = widget.repository.currentUserId?.trim();
    if (currentPlayerId != null &&
        currentPlayerId.isNotEmpty &&
        !room.players.any((player) => player.id == currentPlayerId)) {
      throw StateError('Current player is missing from matched room snapshot.');
    }
    return room;
  }

  String? _matchedRoomId(Map<String, dynamic> result) {
    final status = result['status'];
    if (status == 'cancelled' || status == 'idle') return null;
    if (status != 'matched') {
      throw FormatException('Unexpected cancel_matchmaking status: $status');
    }
    final roomId = result['room_id'];
    if (roomId is! String || roomId.trim().isEmpty) {
      throw const FormatException(
        'Matched cancel_matchmaking response is missing room_id.',
      );
    }
    return roomId;
  }

  GameRoom _roomReference(String roomId) => GameRoom(
    id: roomId,
    name: '1vs1',
    code: '',
    category: _lastMatchCategory ?? 'Ziman',
    players: const [],
    status: RoomStatus.active,
    questionCount: 10,
  );

  Future<void> _openMatchedRoom(
    String roomId,
    String category,
    bool ku,
    String opponentPlaceholder,
    int attempt,
  ) async {
    final room = await _loadMatchedRoom(roomId);
    if (!_isAttemptActive(attempt)) return;
    final opponent = selectOpponentPlayer(
      room.players,
      currentPlayerId: widget.repository.currentUserId,
      currentName: _myName,
    );
    final matchedName = opponent?.name ?? opponentPlaceholder;
    await _onMatched(
      matchedName,
      opponent == null ? const AvatarIdentity() : _identityFromPlayer(opponent),
      room,
      category,
      ku,
      attempt,
      opponentId: opponent?.id,
    );
  }

  Future<void> _onMatched(
    String matchedName,
    AvatarIdentity opponentIdentity,
    GameRoom? matchedRoom,
    String category,
    bool ku,
    int attempt, {
    String? opponentId,
    // `null` = gerçek rakip, gerçek seviye verisi yok → rozet gizlenir.
    // Yalnız bot dalı gerçek bir sayı geçer (bkz. `_opponentLevelKnown`).
    int? opponentLevel,
  }) async {
    if (!_isAttemptActive(attempt)) return;
    _matchmakingMetrics.finish(
      matchedRoom == null ? MatchmakingOutcome.bot : MatchmakingOutcome.human,
    );
    AnalyticsService.instance.logActivationStep('matchmaking_matched');
    setState(() {
      _found = true;
      _opponentName = matchedName;
      _opponentLevelKnown = opponentLevel != null;
      if (opponentLevel != null) _opponentLevel = opponentLevel;
      _opponentIdentity = opponentIdentity;
      _opponentId = opponentId;
      _statusTextKu = 'Lîstikvanek hat dîtin: $matchedName!';
      _statusTextTr = 'Rakip bulundu: $matchedName!';
    });

    // Wait 1.5 seconds for victory transition animation
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!_isAttemptActive(attempt)) return;
    if (!mounted) return;

    final roomId = matchedRoom?.id;
    var room =
        matchedRoom ??
        widget.repository
            .createRoom(category: category)
            .copyWith(
              name: context.t(K.duel1v1Short),
              // Bot düellosu yerel bir odadır. Gerçek eşleşmede süre ve
              // diğer tüm alanlar yukarıdaki sunucu snapshot'ından gelir.
              secondsPerQuestion: 20,
              players: [
                Player(
                  name: _myName,
                  score: 0,
                  state: Player.readyState,
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
                  state: Player.readyState,
                  streak: 0,
                  avatarIcon: opponentIdentity.iconId,
                  avatarColor: opponentIdentity.colorHex,
                  avatarUrl: opponentIdentity.photoUrl,
                  avatarFrame: opponentIdentity.frameId,
                  showcaseTitle: opponentIdentity.showcaseTitle,
                ),
              ],
            );

    List<QuizQuestion> matchQuestions = const [];
    if (roomId != null) {
      try {
        final roomQuestions = await widget.repository.loadRoomQuestions(room);
        if (roomQuestions.isNotEmpty) {
          matchQuestions = roomQuestions;
        } else if (widget.repository.usesServerHiddenAnswers) {
          throw StateError('Real room has no playable questions.');
        }
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'matchmaking_load_room_questions',
        );
        if (widget.repository.usesServerHiddenAnswers) {
          setState(() {
            _found = false;
          });
          if (!_cancelRequested && !_isCancelled && mounted) {
            setState(() {
              _matchmakingErrorMessage = context.t(K.gameStartFailed);
            });
          }
          return;
        }
      }
      if (!_isAttemptActive(attempt)) return;
    }

    if (matchQuestions.isEmpty) {
      final roomCategory = matchedRoom?.category ?? category;
      final actualCategory =
          (roomCategory == 'Rastgele' || roomCategory == 'Random')
          ? (_categories.isNotEmpty
                ? _categories[Random().nextInt(_categories.length)]
                : 'Ziman')
          : roomCategory;
      try {
        matchQuestions = await widget.repository.loadLevelQuestions(
          category: actualCategory,
          difficultyMin: 1,
          difficultyMax: 5,
          limit: 10,
        );
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'matchmaking_load_questions',
        );
      }
      if (matchQuestions.isEmpty) {
        matchQuestions = widget.repository.playableQuestions;
      }
      if (!_isAttemptActive(attempt)) return;
    }

    if (matchedRoom == null) {
      room = room.copyWith(questionCount: matchQuestions.length);
    }

    if (!mounted) return;
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
    final status =
        (ku ? _statusTextKu : _statusTextTr) ?? context.t(K.searchingShort);

    return PopScope(
      // İptal bir kez başarısız olduysa sistem geri hareketi de serbest
      // bırakılır: aksi hâlde ağı kopmuş oyuncunun tek çıkışı uygulamayı
      // zorla kapatmak oluyor.
      canPop: !_searchingStarted || _cancelling || _cancelFailed,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleCancelAndPop();
      },
      // 2026-09-29 Şahnê: seçim B iskeletidir (açılan sayfa); arama ve
      // eşleşme anı C iskeletidir (oyun sahnesi, her temada gece). Eski
      // alt kenardaki üçgen kilim deseni kalktı.
      child: _searchingStarted
          ? _buildSearchStage(status, ku)
          : _buildSelectionMenu(ku),
    );
  }

  Widget _buildSelectionMenu(bool ku) {
    final t = SahneTokens.of(context);
    final Widget categories;
    if (_loadingCategories) {
      categories = Padding(
        padding: const EdgeInsets.all(SahneSpace.x6),
        child: Center(child: CircularProgressIndicator(color: t.raceTx)),
      );
    } else if (_categories.isEmpty) {
      // Ekranın birincil eylemi yukarıdaki rastgele eşleşme kartı; buradaki
      // yeniden deneme ikincildir.
      categories = _categoriesError
          ? AppErrorState(
              title: context.t(K.loadFailedShort),
              message: context.t(K.categoriesLoadFail),
              retryLabel: context.t(K.retryShort),
              primaryAction: false,
              onRetry: _loadCategoriesOnly,
            )
          : AppEmptyState(
              icon: AppIcons.layerGroup,
              title: context.t(K.categoriesNotFound),
              message: context.t(K.checkConnection),
              actionLabel: context.t(K.retryShort),
              primaryAction: false,
              onAction: _loadCategoriesOnly,
            );
    } else {
      // Kategori satırı: 36'lık çizimsiz küçük (kategori tonu + ikon); alt
      // satırda öteki dildeki ad. Tam kategori çizimi (mücevher karo) burada yok:
      // eşleşme bir kategori vitrini değil, hızlı bir seçim listesi.
      categories = SahneListGroup(
        children: [
          for (final category in _categories) _categoryRow(category, ku),
        ],
      );
    }

    return SahnePushedPage(
      // Ekranın kimliği artık B iskeletinin çubuğudur (başlık + alt satır);
      // eski kimlik başlığının anahtarı çubuğu taşıyan sayfadadır.
      key: const ValueKey('matchmaking-selection-header'),
      title: context.t(K.duel1v1),
      backLabel: context.t(K.back),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RandomMatchCard(onTap: () => _startMatchmaking('Rastgele')),
                SahneSectionHeader(title: context.t(K.matchByCategory)),
                categories,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryRow(String category, bool ku) {
    void onTap() => _startMatchmaking(category);

    final title = CategoryNames.localized(category, ku);
    final other = CategoryNames.localized(category, !ku);
    final subtitle = other == title ? null : other;
    // 2026-09-29 doğallık (K1): liste satırında çizim yok. 36'lık küçükte
    // üretilmiş çizim seçilemeyen bir renk lekesiydi; her kategori
    // çizimsiz karonun küçüğünü alır (kendi tonu + kendi ikonu).
    return SahneListRow.thumb(
      image: null,
      icon: CategoryVisuals.icon(category),
      tone: CategoryVisuals.tone(category),
      title: title,
      subtitle: subtitle,
      chevron: true,
      onTap: onTap,
    );
  }

  Widget _buildSearchStage(String status, bool ku) {
    final Widget body;
    if (_cancelling) {
      body = Center(
        child: Column(
          key: const ValueKey('matchmaking-cancelling-state'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: SahneTokens.of(context).raceTx,
              ),
            ),
            const SizedBox(height: SahneSpace.x6),
            Text(
              status,
              style: SahneType.headline.copyWith(
                color: SahneTokens.of(context).tx,
              ),
            ),
          ],
        ),
      );
    } else if (_matchmakingErrorMessage != null) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppErrorState(
                title: context.t(K.loadFailedShort),
                message: _matchmakingErrorMessage!,
                retryLabel: context.t(K.retryShort),
                onRetry: () {
                  final category = _lastMatchCategory;
                  if (category != null) _startMatchmaking(category);
                },
              ),
              SahneButton.secondary(
                label: context.t(K.cancelAction),
                icon: AppIcons.xmark,
                onPressed: _cancelling ? null : _handleCancelAndPop,
              ),
            ],
          ),
        ),
      );
    } else {
      body = _buildVersus(status, ku);
    }

    final showDock =
        !_cancelling && _matchmakingErrorMessage == null && !_found;
    return SahneStageScaffold(
      closeLabel: context.t(K.back),
      onClose: _cancelling ? null : _handleCancelAndPop,
      center: _categoryName == null
          ? null
          : Text(
              context.t(K.categoryPrefix, {
                'name': CategoryNames.localized(_categoryName!, ku),
              }),
            ),
      body: body,
      dock: showDock
          ? SahneButton.secondary(
              label: context.t(K.cancelAction),
              icon: AppIcons.xmark,
              expand: true,
              onPressed: _cancelling ? null : _handleCancelAndPop,
            )
          : null,
    );
  }

  /// VS sahnesi: iki elmas avatar yüz yüze, arada logo işareti + "VS".
  ///
  /// Yarış rolünde sahne kartı (Boyax sahne degradesi). Kullanıcı Halka 3
  /// altın; rakip aranırken boş elmas ("?") ve etrafında atan elmas halkalar
  /// (hareketi azaltta durur), bulununca oyuncunun elması + Halka 3 Rast.
  Widget _buildVersus(String status, bool ku) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final t = SahneTokens.of(context);
        final reduce = sahneMotionReduced(context) || isFlutterTestEnvironment;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

        final me = _VersusSide(
          avatar: _RingedAvatar(
            ring: t.gold,
            child: PlayerAvatar(
              radius: 32,
              photoUrl: _myIdentity.photoUrl,
              iconId: _myIdentity.iconId,
              colorHex: _myIdentity.colorHex,
              frameId: _myIdentity.frameId,
              displayName: _myName,
            ),
          ),
          name: Text(
            _myName,
            maxLines: 2,
            overflow: TextOverflow.clip,
            softWrap: true,
            textAlign: TextAlign.center,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          level: _LevelTag(
            label: context.t(K.levelPrefix, {'level': '$_myLevel'}),
          ),
        );

        final Widget opponentAvatar;
        if (_found && _opponentBlocked) {
          // Engellenen rakibin YÜKLEDİĞİ fotoğrafı artık çizilmez — bu tam
          // da kullanıcının engelleyerek bir daha görmek istemediği şey.
          opponentAvatar = _RingedAvatar(
            ring: t.tx3,
            child: SahneAvatar(
              size: 64,
              icon: AppIcons.circleXmark,
              color: t.s3,
              foreground: t.tx2,
            ),
          );
        } else if (_found) {
          opponentAvatar = _RingedAvatar(
            ring: t.okTx,
            child: PlayerAvatar(
              radius: 32,
              photoUrl: _opponentIdentity.photoUrl,
              iconId: _opponentIdentity.iconId,
              colorHex: _opponentIdentity.colorHex,
              frameId: _opponentIdentity.frameId,
              displayName: _opponentName,
            ),
          );
        } else {
          opponentAvatar = _SearchPulse(
            controller: _pulseController,
            animate: !reduce,
            child: const _RingedAvatar(
              ring: SahneStageColors.raceSoft,
              child: SahneAvatar(
                size: 64,
                icon: AppIcons.question,
                color: SahneStageColors.race3,
                foreground: SahneStageColors.raceSoft,
              ),
            ),
          );
        }

        final opponentNameText = Text(
          !_found
              ? '?'
              : _opponentBlocked
              ? context.t(K.chatBlocked)
              : (_opponentName ?? ''),
          maxLines: 2,
          overflow: TextOverflow.clip,
          softWrap: true,
          textAlign: TextAlign.center,
          style: SahneType.bodyStrong.copyWith(
            color: _found ? t.tx : SahneStageColors.raceSoft,
          ),
        );

        // Rakibin YÜKLEDİĞİ fotoğraf ve adı burada tam ekran gösteriliyor;
        // bildir/engelle de tam burada olmalı (2026-08-06 denetimi).
        final Widget opponentName;
        if (largeText && _found && !_opponentBlocked) {
          opponentName = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              opponentNameText,
              PlayerModerationButton(
                repository: widget.repository,
                playerId: _opponentId,
                playerName: _opponentName ?? '',
                compact: true,
                onBlocked: () => setState(() => _opponentBlocked = true),
              ),
            ],
          );
        } else {
          opponentName = Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: opponentNameText),
              if (_found && !_opponentBlocked)
                PlayerModerationButton(
                  repository: widget.repository,
                  playerId: _opponentId,
                  playerName: _opponentName ?? '',
                  compact: true,
                  onBlocked: () => setState(() => _opponentBlocked = true),
                ),
            ],
          );
        }

        final opponent = _VersusSide(
          avatar: opponentAvatar,
          name: opponentName,
          level: _LevelTag(
            label: !_found
                ? '?'
                : _opponentLevelKnown
                ? context.t(K.levelPrefix, {'level': '$_opponentLevel'})
                : context.t(K.levelUnknown),
            found: _found,
          ),
        );

        // Eşleşme bulunduğunda VS altın renge döner ve yarışma programı
        // hissiyle "punch" yapar; hareketi azaltta yalnız renk değişir.
        final vs = TweenAnimationBuilder<double>(
          key: ValueKey('vs-punch-$_found'),
          tween: Tween(begin: _found && !reduce ? 1.8 : 1.0, end: 1.0),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            'VS',
            style: SahneType.title.copyWith(
              color: _found ? t.gold : SahneStageColors.raceSoft,
            ),
          ),
        );

        final emblem = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SahneSpace.x1),
            const RojMascot(size: 36),
            const SizedBox(height: SahneSpace.x2),
            vs,
          ],
        );

        // Büyük yazıda iki yan yan yana sığmaz (ad harf harf bölünür): yüz
        // yüze düzen dikey bir sıraya döner — oyuncu, amblem, rakip.
        final stage = SahneStageCard(
          role: SahneRole.race,
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.x3,
            SahneSpace.x6,
            SahneSpace.x3,
            SahneSpace.x5,
          ),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    me,
                    const SizedBox(height: SahneSpace.x3),
                    emblem,
                    const SizedBox(height: SahneSpace.x3),
                    opponent,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: me),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SahneSpace.x2,
                      ),
                      child: emblem,
                    ),
                    Expanded(child: opponent),
                  ],
                ),
        );

        // İçerik C iskeletinde olduğu gibi üst satırın hemen altından
        // başlar (dikey ortalama yok): yüz yüze kart sahnenin ışık
        // huzmesinin altında durur, durum metni onun altında.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x6,
            SahneSpace.page,
            SahneSpace.x6,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                key: const ValueKey('matchmaking-waiting-state'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stage,
                  const SizedBox(height: SahneSpace.x6),
                  if (!_found) ...[
                    Center(
                      child: SizedBox(
                        width: 180,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final val = reduce
                                ? 0.65
                                : (0.35 + 0.45 * _pulseController.value);
                            return KilimProgressBar(
                              value: val,
                              height: 8,
                              color: t.race,
                              trackColor: t.s3,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x4),
                  ],
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: SahneType.headline.copyWith(
                      color: _found ? t.okTx : t.tx,
                    ),
                  ),
                  if (_found) ...[
                    const SizedBox(height: SahneSpace.x2),
                    Text(
                      context.t(K.startingSoon),
                      textAlign: TextAlign.center,
                      style: SahneType.bodyStrong.copyWith(color: t.goldTx),
                    ),
                  ],
                  if (!_found) ...[
                    const SizedBox(height: SahneSpace.x3),
                    // Geçen bekleme süresi — yalnız gösterim; zamanlayıcı
                    // mantığı değişmez. Bot diyaloğu açıkken çip gizlenir.
                    if (!_botPromptOpen)
                      Center(
                        child: SahneStatChip(
                          leading: Icon(
                            AppIcons.stopwatch,
                            size: 20,
                            color: t.tx2,
                          ),
                          label: ku
                              // Çip yalnız geçen süreyi taşır; durumu
                              // üstteki başlık söyler. İkisi de durum
                              // yazdığında biri ötekini yalanlıyordu.
                              ? '$_secondsElapsed çirke'
                              : '$_secondsElapsed saniye',
                        ),
                      ),
                    const SizedBox(height: SahneSpace.x3),
                    Text(
                      context.t(K.searchingNote),
                      textAlign: TextAlign.center,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rastgele eşleşme — seçim ekranının TEK birincil eylemi.
///
/// 2026-09-29 doğallık (K7): kartın tamamı Agir (turuncu) dolguydu; ekranın
/// üst yarısı tek bir turuncu blok olunca eylem değil afiş gibi okunuyordu.
/// Kart artık ikincil yüzeydir (Perde `s1`, düz, gölgesiz, kenarlıksız, L
/// pah); turuncu
/// yalnız sağdaki ok karosunda kalır — ekranda tek turuncu öğe. Kartın
/// tamamı yine dokunulur. Kart kendi dolgusunu taşıyan bir `Container`dır
/// (bekçi: `matchmaking_screen_test`); pah şekli kırpıcıyla verilir.
class _RandomMatchCard extends StatelessWidget {
  const _RandomMatchCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahnePressSink(
      enabled: true,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: SahneShape.l),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Container(
              key: const ValueKey('matchmaking-duel-card'),
              // Kenarlık yok: dikdörtgen kenarlık pah kırpıcısında köşeleri
              // kesik bir çerçeve bırakıyordu.
              decoration: BoxDecoration(
                color: t.s1,
                boxShadow: const <BoxShadow>[],
              ),
              padding: const EdgeInsets.all(SahneSpace.x4),
              child: Row(
                children: [
                  DecoratedBox(
                    // İkon karosu nötr (Kulis): kartın tek renkli öğesi
                    // sağdaki Agir ok karosudur.
                    decoration: ShapeDecoration(
                      color: t.s2,
                      shape: SahneShape.m,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(AppIcons.shuffle, color: t.tx2, size: 24),
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(K.randomMatch),
                          style: SahneType.button.copyWith(color: t.tx),
                        ),
                        Text(
                          context.t(K.randomMatchSub),
                          style: SahneType.caption.copyWith(color: t.tx2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  DecoratedBox(
                    key: const ValueKey('matchmaking-duel-card-go'),
                    decoration: ShapeDecoration(
                      color: AppTheme.primaryCtaColor(context),
                      shape: SahneShape.m,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        AppIcons.arrowRight,
                        color: t.onAct,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// VS sahnesinin bir yanı: avatar, ad, seviye etiketi.
class _VersusSide extends StatelessWidget {
  const _VersusSide({
    required this.avatar,
    required this.name,
    required this.level,
  });

  final Widget avatar;
  final Widget name;
  final Widget level;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: SahneSpace.x3),
        name,
        const SizedBox(height: SahneSpace.x2),
        level,
      ],
    );
  }
}

/// 80'lik pahlı kare yuva: içte 64'lük avatar, dışta Halka 3.
///
/// 2026-09-29 doğallık (K5): yuva ve arama halkaları elmastı; avatar pahlı
/// kare olunca elmas halka kareyi çevreleyen ikinci bir şekil oluyordu.
/// Elmas yalnız soru ilerlemesi ve ders sayacında kalır.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.ring, required this.child});

  final Color ring;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 80,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: SahneShape.withSide(
            SahneShape.forSize(80),
            ring,
            width: SahneRing.r3,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Aranırken rakip yuvasının etrafında atan pahlı kare halkalar.
///
/// Denetleyici hareketi azalt açıkken hiç başlamaz (bkz. `initState`);
/// [animate] `false` iken halkalar sabit ve sönük durur.
class _SearchPulse extends StatelessWidget {
  const _SearchPulse({
    required this.controller,
    required this.animate,
    required this.child,
  });

  final Animation<double> controller;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final v = animate ? controller.value : 0.0;
              return IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    for (final base in const [96.0, 112.0])
                      SizedBox.square(
                        dimension: base + 8 * v,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: SahneShape.withSide(
                              SahneShape.forSize(base + 8 * v),
                              SahneStageColors.raceSoft.withValues(
                                alpha:
                                    (base == 96 ? 0.32 : 0.16) * (1 - 0.5 * v),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          child,
        ],
      ),
    );
  }
}

/// Seviye etiketi: S pah, ton zemin + kalın açıklama. Büyük harfe
/// çevrilmez (ad ve seviye sözü olduğu gibi okunur); dar sütunda sarar.
class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.label, this.found = true});

  final String label;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: found ? t.s2 : SahneStageColors.race3,
        shape: SahneShape.s,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x2,
            vertical: 2,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            softWrap: true,
            style: SahneType.captionStrong.copyWith(
              color: found ? t.tx2 : SahneStageColors.raceSoft,
            ),
          ),
        ),
      ),
    );
  }
}
