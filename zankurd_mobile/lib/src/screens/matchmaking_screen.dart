import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../data/supabase_zankurd_repository.dart';
import '../data/xp_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/avatar_identity.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../services/analytics_service.dart';
import '../utils/test_environment.dart';
import '../widgets/app_state.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../config/bot_names.dart';
import '../config/category_visuals.dart';

Player? selectOpponentPlayer(
  Iterable<Player> players, {
  required String currentName,
  String? preferredName,
}) {
  final preferred = preferredName?.trim();
  if (preferred != null && preferred.isNotEmpty) {
    for (final player in players) {
      if (player.name == preferred && player.name != currentName) {
        return player;
      }
    }
  }
  for (final player in players) {
    if (player.name != currentName) return player;
  }
  return null;
}

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
  String? _profileName;

  String get _myName => _profileName ?? (context.t(K.playerWord));
  bool _isCancelled = false;
  bool _cancelling = false;
  // Bot diyaloğu açıkken arka plan sayacı gizlenir (zamanlayıcı zaten durmuş
  // olur; ekranda donuk "X sn" çipi kalmasın).
  bool _botPromptOpen = false;

  bool _searchingStarted = false;
  List<String> _categories = const [];
  bool _loadingCategories = false;
  bool _categoriesError = false;
  String? _selectedCategory;
  String? _lastMatchCategory;
  String? _matchmakingErrorMessage;

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
    widget.repository.cancelMatchmaking().catchError((error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_dispose_cancel');
    });
    super.dispose();
  }

  Future<void> _handleCancelAndPop() async {
    if (_cancelling) return;
    setState(() {
      _cancelling = true;
      _statusTextKu = 'Tê betalkirin...';
      _statusTextTr = 'İptal ediliyor...';
    });

    _matchmakingSub?.cancel();
    _matchmakingSub = null;
    _statusTimer?.cancel();
    _statusTimer = null;

    try {
      await widget.repository.cancelMatchmaking();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_cancel_and_pop');
    }

    if (mounted) {
      setState(() {
        _isCancelled = true;
        _cancelling = false;
      });
      Navigator.of(context).pop();
    }
  }

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
    final ku = context.isKu;
    _lastMatchCategory = chosenCategory;
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
      _secondsElapsed = 0;
    });

    try {
      // Join the matchmaking queue in Supabase
      final matchRes = await widget.repository.joinMatchmaking(chosenCategory);
      if (_isCancelled || !mounted) return;

      if (matchRes['status'] == 'matched') {
        // Matched immediately!
        var matchedName = matchRes['opponent_name'] as String? ?? 'Raqîb';
        var opponentIdentity = const AvatarIdentity();
        final matchedLevel = max(1, _myLevel + Random().nextInt(3) - 1);
        // C-2: null-safe cast — Supabase schema hatası veya edge-case'de
        // String? null dönebilir; null ise navigasyon iptal edilir.
        final roomId = matchRes['room_id'] as String?;
        if (roomId == null) return; // beklenmedik schema yanıtı
        final opponent = await _loadOpponentPlayer(
          roomId: roomId,
          category: chosenCategory,
          currentName: _myName,
          preferredName: matchedName,
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
          chosenCategory,
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

            // C-2: null-safe cast — subscription yanıtı beklenmedik türde
            // olursa crash yerine sessizce çıkar.
            final roomId = entry['room_id'] as String?;
            if (roomId == null) return;
            // Fetch opponent display name
            String matchedName = opponentPlaceholder;
            var opponentIdentity = const AvatarIdentity();
            final opponent = await _loadOpponentPlayer(
              roomId: roomId,
              category: chosenCategory,
              currentName: _myName,
            );
            if (opponent != null) {
              matchedName = opponent.name;
              opponentIdentity = _identityFromPlayer(opponent);
            }

            final matchedLevel = max(1, _myLevel + Random().nextInt(3) - 1);
            await _onMatched(
              matchedName,
              matchedLevel,
              opponentIdentity,
              roomId,
              chosenCategory,
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

          // 30 saniye, canlı oyuncu havuzu henüz yokken yeni kullanıcıyı
          // boş bir radar ekranında bekletiyordu (2026-07-25 canlı
          // denetimi). Süre kısaltıldı ve durum metniyle hizalandı:
          // 0-12sn "aranıyor", 12-20sn "henüz bulunamadı", 20sn'de bot
          // teklifi. Havuz büyüdüğünde bu değer yeniden uzatılabilir.
          if (_secondsElapsed >= 20) {
            timer.cancel();
            _matchmakingSub?.cancel();
            _matchmakingSub = null;
            // Abort online queue
            await widget.repository.cancelMatchmaking().catchError((
              error,
              stack,
            ) {
              ErrorReporter.record(
                error,
                stack,
                reason: 'matchmaking_timeout_cancel',
              );
            });

            if (!mounted) return;
            // Ask user for bot fallback
            setState(() => _botPromptOpen = true);
            final playWithBot = await _showBotPrompt();
            if (mounted) setState(() => _botPromptOpen = false);
            if (!mounted) return;
            if (playWithBot == true) {
              // M-3: Bot isimleri merkezi config'den; inline liste kaldırıldı.
              final matchedName =
                  BotNames.pool[Random().nextInt(BotNames.pool.length)];
              final matchedLevel = max(1, _myLevel + Random().nextInt(5) - 2);

              await _onMatched(
                matchedName,
                matchedLevel,
                const AvatarIdentity(),
                null,
                chosenCategory,
                ku,
              );
            } else {
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
      if (_isCancelled || !mounted) return;
      _matchmakingSub?.cancel();
      _statusTimer?.cancel();
      setState(() {
        _found = false;
        _matchmakingErrorMessage = context.t(K.matchFailed);
      });
    }
  }

  Future<bool?> _showBotPrompt() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(
          context.t(K.searchTimedOut),
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.t(K.playWithBotQ),
          style: TextStyle(color: AppTheme.textSubColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.t(K.no),
              style: const TextStyle(color: AppTheme.wrong),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGradientStart,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t(K.yes)),
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

  Future<Player?> _loadOpponentPlayer({
    required String roomId,
    required String category,
    required String currentName,
    String? preferredName,
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
      return selectOpponentPlayer(
        roomPlayers,
        currentName: currentName,
        preferredName: preferredName,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'matchmaking_load_opponent');
    }
    return null;
  }

  Future<void> _onMatched(
    String matchedName,
    int matchedLevel,
    AvatarIdentity opponentIdentity,
    String? roomId,
    String category,
    bool ku,
  ) async {
    AnalyticsService.instance.logActivationStep('matchmaking_matched');
    setState(() {
      _found = true;
      _opponentName = matchedName;
      _opponentLevel = matchedLevel;
      _opponentIdentity = opponentIdentity;
      _statusTextKu = 'Lîstikvanek hat dîtin: $matchedName!';
      _statusTextTr = 'Rakip bulundu: $matchedName!';
    });

    // Wait 1.5 seconds for victory transition animation
    await Future.delayed(const Duration(milliseconds: 1500));
    if (_isCancelled || !mounted) return;

    String? dbHostId;
    if (roomId != null && widget.repository is SupabaseZanKurdRepository) {
      try {
        final client = (widget.repository as SupabaseZanKurdRepository).client;
        final res = await client
            .from('rooms')
            .select('host_id')
            .eq('id', roomId)
            .maybeSingle();
        if (res != null) {
          dbHostId = res['host_id'] as String?;
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'matchmaking_load_host');
      }
    }
    if (!mounted) return;

    var room = widget.repository
        .createRoom(category: category)
        .copyWith(
          id: roomId,
          hostId: dbHostId,
          name: context.t(K.duel1v1Short),
          // 1v1 tempolu bir düello; 20sn (2026-07-21 kullanıcı kararı).
          secondsPerQuestion: 20,
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
          if (!_isCancelled && mounted) {
            setState(() {
              _matchmakingErrorMessage = context.t(K.gameStartFailed);
            });
          }
          return;
        }
      }
      if (_isCancelled || !mounted) return;
    }

    if (matchQuestions.isEmpty) {
      final actualCategory = (category == 'Rastgele' || category == 'Random')
          ? (_categories.isNotEmpty
                ? _categories[Random().nextInt(_categories.length)]
                : 'Ziman')
          : category;
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
        matchQuestions = widget.repository.questions;
      }
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

    return PopScope(
      canPop: !_searchingStarted || _cancelling || _found,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleCancelAndPop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.textPrimaryColor(context)),
          leading: _searchingStarted
              ? IconButton(
                  icon: const Icon(AppIcons.arrowLeft),
                  tooltip: context.t(K.back),
                  onPressed: _cancelling ? null : _handleCancelAndPop,
                )
              : null,
        ),
        body: Container(
          color: AppTheme.bgOf(context),
          child: SafeArea(
            child: _searchingStarted
                ? _buildRadarSearch(status, ku)
                : _buildSelectionMenu(ku),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionMenu(bool ku) {
    // Dikey ortalama yok: hero kart üstten başlar, boşluk alta kalır.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Aynı özellik, tek kimlik.
            //
            // Oyun merkezindeki "Hızlı düello" kartı marka yeşiliyle
            // sunuluyor (play_hub_screen.dart:370), eşleşme ekranının
            // hero'su ise `playPink` ile — kullanıcı aynı özelliğe iki
            // ayrı renkten giriyordu. `shop_screen.dart`taki M24 notu
            // playPink/playCyan/playPurple'ı zaten "marka dışı" diye
            // işaretlemişti; bu yüzey o kararın dışında kalmıştı
            // (2026-07-31 denetimi).
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.culturalBrandBg, Color(0xFF1E6B4C)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.culturalBrandBg.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(AppIcons.bolt, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                context.t(K.duel1v1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t(K.duel1v1Sub),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 1. Random Match Card
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: () => _startMatchmaking('Rastgele'),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              key: const ValueKey('matchmaking-duel-card'),
              decoration: BoxDecoration(
                // Rastgele eşleşme birincil CTA: kırmızı (tehlike anlamı)
                // yerine oda/mod kimliğiyle tutarlı teal-yeşil gradyan.
                gradient: const LinearGradient(
                  colors: [AppTheme.playCyan, Color(0xFF1E6E66)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppTheme.playCyan.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.playCyan.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(AppIcons.shuffle, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(K.randomMatch),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t(K.randomMatchSub),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 2. Category selection label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            context.t(K.matchByCategory),
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        if (_loadingCategories)
          const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
            ),
          )
        else if (_categories.isEmpty)
          _categoriesError
              ? AppErrorState(
                  title: context.t(K.loadFailedShort),
                  message: context.t(K.categoriesLoadFail),
                  retryLabel: context.t(K.retryShort),
                  onRetry: _loadCategoriesOnly,
                )
              : AppEmptyState(
                  icon: AppIcons.layerGroup,
                  title: context.t(K.categoriesNotFound),
                  message: context.t(K.categoriesSubtitle),
                  actionLabel: context.t(K.retryShort),
                  onAction: _loadCategoriesOnly,
                )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final tint = CategoryVisuals.color(category);
              final isSelected = _selectedCategory == category;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    _startMatchmaking(category);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                tint,
                                Color.alphaBlend(
                                  Colors.black.withValues(alpha: 0.14),
                                  tint,
                                ),
                              ],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : AppTheme.surfaceHiColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : tint.withValues(alpha: 0.45),
                        width: isSelected ? 1.2 : 1.4,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryVisuals.icon(category),
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : AppColors.toneOnSurface(context, tint),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          CategoryNames.localized(category, ku),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRadarSearch(String status, bool ku) {
    if (_cancelling) {
      return Center(
        child: Column(
          key: const ValueKey('matchmaking-cancelling-state'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
            ),
            const SizedBox(height: 24),
            Text(
              status,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (_matchmakingErrorMessage != null) {
      return Center(
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
            OutlinedButton.icon(
              onPressed: _cancelling ? null : _handleCancelAndPop,
              icon: const Icon(AppIcons.xmark, size: 18),
              label: Text(context.t(K.cancelAction)),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        key: const ValueKey('matchmaking-waiting-state'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_categoryName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGradientStart.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGradientStart.withValues(alpha: 0.32),
                ),
              ),
              child: Text(
                context.t(K.categoryPrefix, {
                  'name': CategoryNames.localized(_categoryName!, context.isKu),
                }),
                style: TextStyle(
                  color: AppColors.onAccentTint(
                    context,
                    AppTheme.primaryGradientStart,
                  ),
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
                      final isLight = AppTheme.isLight(context);
                      final baseAlpha = 1.0 - (radius / 260.0);
                      final alpha = (isLight ? baseAlpha * 1.5 : baseAlpha)
                          .clamp(0.06, 0.6);
                      return Container(
                        width: radius + (pulseValue * 15.0),
                        height: radius + (pulseValue * 15.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _found
                                ? AppTheme.correct.withValues(alpha: alpha)
                                : AppTheme.primaryGradientStart.withValues(
                                    alpha: alpha,
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
                            AppTheme.primaryGradientStart.withValues(
                              alpha: AppTheme.isLight(context) ? 0.35 : 0.25,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.15, 1.0],
                        ),
                      ),
                    ),
                  ),
                // Avatars view
                //
                // İki sütun da `Flexible`: sütunun genişliğini avatar değil
                // altındaki oyuncu adı belirliyor ve ad sınırsız uzayabilir.
                // Uzun adlı bir rakip bulunduğunda 260 piksellik radar
                // alanı taşıyordu (2026-07-30: 148 piksel). Avatarlar 72
                // piksel sabit olduğu için sıkışacak yer var; taşan tek şey
                // addır, o da tek satıra kırpılır.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User Avatar
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryGradientStart,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGradientStart
                                      .withValues(alpha: 0.3),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
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
                              color: AppTheme.isLight(context)
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.t(K.levelPrefix, {'level': '$_myLevel'}),
                              style: TextStyle(
                                color: AppTheme.textSubColor(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Eşleşme bulunduğunda VS altın renge döner ve
                    // yarışma programı hissiyle "punch" yapar.
                    TweenAnimationBuilder<double>(
                      key: ValueKey('vs-punch-$_found'),
                      tween: Tween(begin: _found ? 2.4 : 1.0, end: 1.0),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: _found
                              ? AppTheme.gold
                              : AppTheme.primaryGradientStart,
                          fontWeight: FontWeight.w900,
                          fontSize: _found ? 26 : 22,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1,
                          shadows: _found
                              ? [
                                  Shadow(
                                    color: AppTheme.gold.withValues(alpha: 0.7),
                                    blurRadius: 14,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Opponent Avatar (fades in or animated)
                    Flexible(
                      child: Column(
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
                                : CircleAvatar(
                                    backgroundColor: AppColors.disabledSurface(
                                      context,
                                    ),
                                    child: Icon(
                                      AppIcons.question,
                                      color: AppTheme.isLight(context)
                                          ? AppTheme.textMutedColor(context)
                                          : Colors.white24,
                                      size: 38,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _found ? (_opponentName ?? '') : '?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _found
                                  ? AppTheme.textPrimaryColor(context)
                                  : AppTheme.textMutedColor(context),
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
                                  : (AppTheme.isLight(context)
                                        ? Colors.black.withValues(alpha: 0.05)
                                        : Colors.white.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _found
                                  ? (context.t(K.levelPrefix, {
                                      'level': '$_opponentLevel',
                                    }))
                                  : '?',
                              style: TextStyle(
                                color: _found
                                    ? AppTheme.correct
                                    : AppTheme.textMutedColor(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _found
                    ? AppTheme.correct
                    : AppTheme.textPrimaryColor(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_found) ...[
            const SizedBox(height: 10),
            Text(
              context.t(K.startingSoon),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!_found) ...[
            const SizedBox(height: 12),
            // Geçen bekleme süresi — yalnız gösterim; zamanlayıcı mantığı
            // değişmez. Bot diyaloğu açıkken çip gizlenir.
            if (!_botPromptOpen)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHiColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  ku
                      // Çip yalnız geçen süreyi taşır; durumu üstteki
                      // başlık söyler. İkisi de durum yazdığında biri
                      // ötekini yalanlıyordu.
                      ? '$_secondsElapsed çirke'
                      : '$_secondsElapsed saniye',
                  style: TextStyle(
                    color: AppTheme.textSubColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.t(K.searchingNote),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimaryColor(context),
                side: BorderSide(
                  color: AppTheme.primaryGradientStart.withValues(alpha: 0.55),
                  width: 1.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              onPressed: _cancelling ? null : _handleCancelAndPop,
              icon: const Icon(AppIcons.xmark, size: 18),
              label: Text(
                context.t(K.cancelAction),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
