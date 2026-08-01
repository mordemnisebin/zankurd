import 'dart:async';

import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/league_tier.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/roj_mascot.dart';
import 'friends_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.repository,
    this.scrollController,
    this.refreshSignal,
    super.key,
  });

  final ZanKurdRepository repository;
  final ScrollController? scrollController;
  final ValueNotifier<int>? refreshSignal;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late Future<List<LeaderboardEntry>> _future;
  late Future<List<Friend>> _friendsFuture;
  Timer? _refreshTimer;
  LeaderboardPeriod _period = LeaderboardPeriod.weekly;

  /// Filtre geçişinde önceki veri korunur: gri boş ekran yerine mevcut
  /// liste + ince yükleme çubuğu gösterilir (2026-07-19 canlı denetim P1).
  List<LeaderboardEntry>? _lastEntries;
  List<Friend>? _lastFriends;

  /// Oyuncunun kendi istatistikleri; ilk 10'da değilse sırasını yine de
  /// gösterebilmek için ayrıca yüklenir.
  Future<LeaderboardEntry?>? _myStatsFuture;

  /// Bekleyen arkadaşlık isteği sayısı — başlıktaki rozet için.
  ///
  /// `loadPendingFriendRequests` 2026-07-31'e kadar YALNIZCA
  /// `friends_screen.dart` içinde çağrılıyordu ve o ekrana giden tek yol
  /// boş durum düğmesiydi. Yani ilk arkadaştan sonra gelen istekler
  /// hiçbir yerde görünmüyordu: gönderen cevap bekliyor, alan taraf
  /// isteğin varlığından habersizdi.
  int _pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startAutoRefresh();
    widget.refreshSignal?.addListener(_loadData);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final periods = [
      LeaderboardPeriod.daily,
      LeaderboardPeriod.weekly,
      LeaderboardPeriod.monthly,
    ];
    if (_tabController.index == 3) {
      // Friends tab
      _loadData();
      return;
    }
    setState(() {
      _period = periods[_tabController.index];
    });
    _loadData();
  }

  Future<LeaderboardEntry?> _loadMyStats() async {
    try {
      return await widget.repository.getPlayerStats();
    } catch (_) {
      return null;
    }
  }

  /// Oyuncu ilk 10'da değilse en alta sabitlenen kendi sırası.
  Widget _buildMyRankRow(bool ku) {
    return FutureBuilder<LeaderboardEntry?>(
      future: _myStatsFuture,
      builder: (context, snapshot) {
        final me = snapshot.data;
        // Veri yokken hiçbir şey çizilmez — sarmalayıcı da dahil. Aksi
        // halde listenin altında boş, kenarlıklı bir şerit kalır ve
        // görünmez bir satır için dikey alan harcanır.
        // Puan kapısı `_myRank` ile aynı sebeple burada da gerekli: aksi
        // hâlde banner susarken bu sabit satır sıfır puanla "#1" demeye
        // devam eder, yani yanlış iddia yer değiştirmiş olur.
        if (me == null || me.rank <= 0 || me.totalScore <= 0) {
          return const SizedBox.shrink();
        }
        return _PinnedMyRank(
          child: _RankRow(entry: me, isKu: ku, highlight: true),
        );
      },
    );
  }

  /// Rozet sayısını tazeler. Başarısızlık sessizdir: rozet bir
  /// iyileştirmedir, tablonun kendisi ona bağlı değil.
  Future<void> _refreshPendingRequests() async {
    try {
      final requests = await widget.repository.loadPendingFriendRequests();
      if (!mounted) return;
      if (requests.length == _pendingRequests) return;
      setState(() => _pendingRequests = requests.length);
    } catch (_) {
      // Yoksay: rozet görünmezse tablo yine çalışır.
    }
  }

  void _loadData() {
    _myStatsFuture = _loadMyStats();
    unawaited(_refreshPendingRequests());
    if (_tabController.index == 3) {
      setState(() {
        _friendsFuture = widget.repository
            .loadFriendsLeaderboard()
            .timeout(const Duration(seconds: 10))
            .then((friends) => _lastFriends = friends);
      });
    } else {
      setState(() {
        _future = widget.repository
            .loadLeaderboard(limit: 10, period: _period)
            .timeout(const Duration(seconds: 10))
            .then((entries) => _lastEntries = entries);
      });
    }
  }

  /// 30 saniyelik yenileme yalnız uygulama ÖNDEYKEN çalışır.
  ///
  /// Zamanlayıcı eskiden yalnız `dispose()`ta iptal ediliyordu. Ama bu ekran
  /// bir kez ziyaret edildikten sonra `IndexedStack` içinde kalıcı olarak
  /// mount kalır — sekme değiştirmek onu dispose etmez. Dolayısıyla
  /// kullanıcı ana sayfadayken, profildeyken, hatta bir quizin ortasındayken
  /// bile her 30 saniyede bir Supabase RPC'si atılıyor ve görünmeyen bir
  /// ağaç yeniden çiziliyordu.
  ///
  /// Depoda tek bir `WidgetsBindingObserver` yoktu, yani uygulama arka
  /// plana alındığında da sorgu sürüyordu: gereksiz mobil veri, pil ve
  /// Supabase kotası (2026-07-31 denetimi).
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // Dönüşte bir kez tazele, sonra döngüyü yeniden kur.
        _loadData();
        _startAutoRefresh();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _refreshTimer?.cancel();
        _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshSignal?.removeListener(_loadData);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Oturum sahibinin haftalık listedeki sırası; listede yoksa ya da
  /// puanı sıfırsa null.
  ///
  /// Puan kapısı şart. Herkesin sıfırda eşitlendiği bir haftada sıra
  /// gelişigüzeldir: canlı denetimde iki oyuncu da 0 puandayken ekran
  /// "Lîga Zêr · Rêza te ya heftane: #1" diyordu — hiç puan almamış
  /// oyuncuya altın lig birinciliği. `profile_screen.dart` aynı kapıyı
  /// 2026-07-27'de koymuştu ("profil '#85' derken toplam puan 0'dı");
  /// karar verildi ama liderlik ekranına uygulanmadı, yani iki ekran
  /// birbiriyle çelişiyordu — profil "—", liderlik "#1" (2026-08-01).
  int? _myRank(List<LeaderboardEntry> entries) {
    final uid = widget.repository.currentUserId;
    if (uid == null) return null;
    for (final entry in entries) {
      if (entry.playerId != uid) continue;
      return entry.totalScore > 0 ? entry.rank : null;
    }
    return null;
  }

  /// Arkadaş ekranını açar ve dönüşte rozeti tazeler — kullanıcı orada
  /// istekleri cevaplamış olabilir.
  Future<void> _openFriends() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(FriendsScreen(repository: widget.repository)));
    if (!mounted) return;
    await _refreshPendingRequests();
  }

  Future<void> _startQuickRace() async {
    final questions = await widget.repository.loadQuestions(limit: 10);
    if (!mounted) return;
    final raceQuestions = questions.isEmpty
        ? widget.repository.questions
        : questions;
    Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: widget.repository.createRoom(),
          questions: raceQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Container(
      color: AppTheme.bgOf(context),
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              ku: ku,
              onRefresh: _loadData,
              onOpenFriends: _openFriends,
              pendingRequestCount: _pendingRequests,
            ),
            _PeriodTabs(controller: _tabController, ku: ku),
            Expanded(
              child: _tabController.index == 3
                  ? _buildFriendsTab(ku)
                  : _buildLeaderboardTab(ku),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(bool ku) {
    return FutureBuilder<List<Friend>>(
      future: _friendsFuture,
      builder: (ctx, snap) {
        final stale = _lastFriends;
        if (snap.connectionState == ConnectionState.waiting && stale == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError && stale == null) {
          return AppErrorState(
            title: context.t(K.friendsLoadFail),
            message: context.t(K.checkConnection),
            retryLabel: context.t(K.retry),
            onRetry: _loadData,
          );
        }
        final friends = snap.data ?? stale ?? [];
        if (friends.isEmpty) {
          return AppEmptyState(
            icon: AppIcons.peopleGroup,
            title: context.t(K.noFriends),
            message: context.t(K.noFriendsAddHint),
            actionLabel: context.t(K.addFriend),
            actionIcon: AppIcons.userPlus,
            onAction: _openFriends,
          );
        }
        return Column(
          children: [
            if (snap.connectionState == ConnectionState.waiting)
              // `backgroundColor` verilmezse M3 rayı `secondaryContainer`
              // yapar. lib/src'deki 12 LinearProgressIndicator'ın 10'u bunu
              // açıkça veriyor; yalnız bu iki kardeş vermiyordu
              // (2026-07-31 denetimi).
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primaryGradientStart,
                backgroundColor: AppTheme.borderColor(context),
              ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                children: [
                  for (final friend in friends)
                    _FriendRankRow(friend: friend, isKu: ku),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaderboardTab(bool ku) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (ctx, snap) {
        final stale = _lastEntries;
        if (snap.connectionState == ConnectionState.waiting && stale == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
              strokeWidth: 2.5,
            ),
          );
        }
        if (snap.hasError && stale == null) {
          return AppErrorState(
            title: context.t(K.boardLoadFailed),
            message: context.t(K.checkConnection),
            retryLabel: context.t(K.retry),
            onRetry: _loadData,
          );
        }
        final entries = snap.data ?? stale ?? [];
        if (entries.isEmpty) {
          return AppEmptyState(
            icon: AppIcons.trophy,
            title: context.t(K.noScoresYet),
            message: context.t(K.startRaceHint),
            actionLabel: context.t(K.startRaceAction),
            actionIcon: AppIcons.bolt,
            onAction: _startQuickRace,
          );
        }
        // 2026-07-23 M25b: görünür ilk 10 arasında hash çakışması varsa
        // (ör. podyumdaki 3 oyuncu aynı pembe) round-robin ile çözülür.
        // Build başında bir kez hesaplanır — ListView içinde her frame'de
        // yeniden çağrılmaz, renkler "titremesin" diye.
        final avatarColorOverrides = resolveAvatarColors(
          entries.map(
            (e) => (
              id: e.playerId,
              displayName: e.displayName,
              colorHex: e.avatarColor,
            ),
          ),
        );
        return Column(
          children: [
            // Filtre/yenileme sırasında mevcut liste korunur; ince çubuk
            // yükleme sinyali verir — gri boş ekran yerine.
            if (snap.connectionState == ConnectionState.waiting)
              // `backgroundColor` verilmezse M3 rayı `secondaryContainer`
              // yapar. lib/src'deki 12 LinearProgressIndicator'ın 10'u bunu
              // açıkça veriyor; yalnız bu iki kardeş vermiyordu
              // (2026-07-31 denetimi).
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.primaryGradientStart,
                backgroundColor: AppTheme.borderColor(context),
              ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                children: [
                  if (_period == LeaderboardPeriod.weekly) ...[
                    _LeagueBanner(myRank: _myRank(entries), isKu: ku),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                  _Podium(
                    entries: entries.take(3).toList(),
                    isKu: ku,
                    colorOverrides: avatarColorOverrides,
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  for (final e in entries.skip(3))
                    _RankRow(
                      entry: e,
                      isKu: ku,
                      colorOverride: avatarColorOverrides[e.playerId],
                    ),
                ],
              ),
            ),
            // Liderlik yalnız ilk 10'u getiriyor; oyuncu listede yoksa
            // kendi sırasını hiç göremiyordu — tablonun temel motivasyon
            // mekanizması eksikti (2026-07-22 UX denetimi).
            //
            // Satır listenin *içinde*, en altta duruyordu: podyum tek
            // başına bir ekranı doldurduğu için kullanıcı kendi sırasını
            // görmek üzere aşağı kaydırmak zorundaydı ve satır pratikte
            // görünmez kalıyordu (2026-07-25 canlı denetimi). Artık
            // listenin altına sabitlenir — her zaman ekranda.
            if (_myRank(entries) == null) _buildMyRankRow(ku),
          ],
        );
      },
    );
  }
}

// ─── Haftalık Lig Bandı ──────────────────────────────────────────────────────

/// Liderlik listesinin altına sabitlenen "senin sıran" şeridi. Listeden
/// ayrı bir katman olduğu için kaydırmadan bağımsız olarak hep görünür.
class _PinnedMyRank extends StatelessWidget {
  const _PinnedMyRank({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor(context).withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xs,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Haftalık ligde oyuncunun kademesini gösterir: Zêr / Zîv / Bronz.
/// Kademe canlı haftalık sıradan türetilir; Zêr'de Zana kutlama yapar.
class _LeagueBanner extends StatelessWidget {
  const _LeagueBanner({required this.myRank, required this.isKu});

  final int? myRank;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final tier = LeagueTier.forRank(myRank);
    final color = tier.color;
    final surface = AppTheme.surfaceHiColor(context);

    return Container(
      key: const ValueKey('league-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), surface),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          if (tier == LeagueTier.zer)
            const RojMascot(size: 44, mood: RojMood.celebrate)
          else
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(
                tier.icon,
                color: AppColors.onAccentTint(context, color),
                size: 22,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label(isKu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  myRank != null
                      ? (Tr.forKu(K.buHaftakiSiranP, isKu, {'p0': '$myRank'}))
                      : (Tr.forKu(K.buHaftaYarisLige, isKu)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(tier.icon, color: color.withValues(alpha: 0.55), size: 28),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.ku,
    required this.onRefresh,
    required this.onOpenFriends,
    required this.pendingRequestCount,
  });

  final bool ku;
  final VoidCallback onRefresh;

  /// Arkadaş ekranını açar. Bu düğme 2026-07-31'e kadar YOKTU.
  ///
  /// `FriendsScreen` — oyuncu arama, istek gönderme, GELEN İSTEKLERİ
  /// kabul/ret, arkadaşla oda kurma — uygulamanın tamamında yalnız tek
  /// yerden açılıyordu: Liderlik > Arkadaşlar sekmesinin BOŞ DURUM
  /// düğmesinden. Kullanıcı bir arkadaş edindiği anda `friends.isEmpty`
  /// false oluyor, boş durum kayboluyor ve yerine dokunulamayan bir liste
  /// geliyordu. O andan sonra ekrana giden hiçbir yol kalmıyordu: yeni
  /// arkadaş aranamıyor, gelen istekler hiçbir yerde görülemiyor, arkadaşla
  /// oda kurulamıyordu. Tüm sosyal katman ilk arkadaştan sonra sessizce
  /// ölüyordu.
  final VoidCallback onOpenFriends;

  /// Bekleyen arkadaşlık isteği sayısı; 0 ise rozet çizilmez.
  ///
  /// Görünür bir işaret olmadan istekler asla fark edilmiyordu: gönderen
  /// taraf cevap bekliyor, alan taraf isteğin varlığından habersizdi.
  final int pendingRequestCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: AppSpacing.sm, top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppTheme.brand,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(K.leaderboardTitle),
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  context.t(K.refreshEvery30),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _HeaderAction(
            valueKey: const ValueKey('leaderboard-friends-button'),
            icon: AppIcons.userPlus,
            tooltip: context.t(K.friendsScreen),
            semanticLabel: pendingRequestCount > 0
                ? context.t(K.friendRequestsPendingA11y, {
                    'count': '$pendingRequestCount',
                  })
                : context.t(K.friendsScreen),
            onPressed: onOpenFriends,
            badgeCount: pendingRequestCount,
          ),
          const SizedBox(width: AppSpacing.xs),
          _HeaderAction(
            valueKey: const ValueKey('leaderboard-refresh-button'),
            icon: AppIcons.arrowsRotate,
            tooltip: context.t(K.refreshAction),
            semanticLabel: context.t(K.refreshBoardA11y),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// Liderlik başlığındaki kare eylem düğmesi.
///
/// İki düğme aynı kabı paylaşsın diye ayrıldı; ayrıca rozeti tek yerde
/// çizer. Rozet yalnız sayı sıfırdan büyükken görünür — boş bir nokta
/// "bir şey var" der ama ne olduğunu söylemez.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.valueKey,
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final ValueKey<String> valueKey;
  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: IconButton(
          key: valueKey,
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppTheme.textSubColor(context), size: 20),
        ),
      ),
    );

    if (badgeCount <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            key: const ValueKey('leaderboard-friends-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: AppTheme.brand,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppTheme.bgOf(context), width: 1.5),
            ),
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSolid(AppTheme.brand),
                fontFamily: AppTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Period Tabs ─────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.controller, required this.ku});

  final TabController controller;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    // Kısa etiketler: 4 eşit sekme 390px'te uzun TR etiketleri kırpıyordu
    // ("Haftalı…", "Arkada…").
    final labels = ku
        ? ['Roj', 'Heft', 'Meh', 'Heval']
        : ['Gün', 'Hafta', 'Ay', 'Arkadaş'];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxs,
      ),
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.textPrimaryColor(context),
        unselectedLabelColor: AppTheme.textMutedColor(context),
        labelStyle: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppTheme.gold.withValues(alpha: 0.46),
            width: 1.2,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        // Varsayılan 16px label padding 4 sekmede "Arkadaş"ı kırpıyordu.
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        dividerColor: Colors.transparent,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}

// ─── Podium (top 3) ──────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({
    required this.entries,
    required this.isKu,
    this.colorOverrides = const {},
  });

  final List<LeaderboardEntry> entries;
  final bool isKu;
  final Map<String, Color> colorOverrides;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    // Yerleşim: 2. sol, 1. orta (daha büyük), 3. sağ
    final slots = [
      if (second != null)
        _PodiumSlot(
          entry: second,
          isCenter: false,
          colorOverride: colorOverrides[second.playerId],
        ),
      if (first != null)
        _PodiumSlot(
          entry: first,
          isCenter: true,
          colorOverride: colorOverrides[first.playerId],
        ),
      if (third != null)
        _PodiumSlot(
          entry: third,
          isCenter: false,
          colorOverride: colorOverrides[third.playerId],
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        key: const ValueKey('leaderboard-podium'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          // 2026-07-24: madalya gradyanı ve altın gölge kaldırıldı. Podyum
          // sıradan bir yüzeydir; sıralamayı taşıyan şey rakam ve isim,
          // parlaklık değil. Altın yalnız 1. sıranın rakamında kalır.
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: slots.length == 1
            ? Center(child: slots.first)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final slot in slots) Expanded(child: slot)],
              ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.isCenter,
    this.colorOverride,
  });

  final LeaderboardEntry entry;
  final bool isCenter;
  final Color? colorOverride;

  Color _colorFor(bool isLight) {
    switch (entry.rank) {
      case 1:
        return AppTheme.gold;
      case 2:
        return isLight ? AppTheme.silverLight : AppTheme.silver;
      default:
        return isLight ? AppTheme.bronzeLight : AppTheme.bronze;
    }
  }

  IconData get _medalIcon {
    if (entry.rank == 1) return AppIcons.trophy;
    return AppIcons.medal;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(AppTheme.isLight(context));
    final avatarR = isCenter ? 28.0 : 22.0;
    final nameFontSz = isCenter ? 13.5 : 12.0;
    final scoreFontSz = isCenter ? 15.5 : 13.5;
    final pedestalH = isCenter
        ? 56.0
        : entry.rank == 2
        ? 42.0
        : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey('podium-slot-${entry.rank}'),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_medalIcon, color: color, size: isCenter ? 30 : 22),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: isCenter ? 2.5 : 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: isCenter ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: PlayerAvatar(
                  radius: avatarR,
                  photoUrl: entry.avatarUrl,
                  iconId: entry.avatarIcon,
                  colorHex: entry.avatarColor,
                  frameId: entry.avatarFrame,
                  displayName: entry.displayName,
                  colorOverride: colorOverride,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: nameFontSz,
                ),
              ),
              if (entry.showcaseTitle != null)
                Text(
                  entry.showcaseTitle!,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.gold,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.28),
                      color.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${entry.totalScore}',
                  style: TextStyle(
                    color: AppColors.readableAccent(context, color),
                    fontWeight: FontWeight.w800,
                    fontSize: scoreFontSz,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Klasik podyum kaidesi (sabit genişlik — tek kazanan landscape'te
              // tüm satırı şişirmesin).
              Container(
                width: isCenter ? 88 : 72,
                height: pedestalH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.55),
                      color.withValues(alpha: 0.28),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Builder(
                  builder: (context) {
                    final pedestal = Color.alphaBlend(
                      color.withValues(alpha: 0.28),
                      AppTheme.surfaceColor(context),
                    );
                    final ink = AppColors.onSolid(pedestal);
                    return Text(
                      '#${entry.rank}',
                      style: AppTypography.heading2.copyWith(
                        // Kaidenin üstündeki beyaz "#1" altın zeminde 1.36:1
                        // ölçüldü — okunabilirliğini yalnız altındaki gölgeye
                        // borçluydu (2026-07-27). Yazı rengi kaidenin gerçek
                        // rengine göre seçilir; gradyanın açık ucu (%28) en
                        // kötü durum olduğu için ölçüt odur.
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: isCenter ? 20 : 16,
                        // Gölge yalnız beyaz yazıya destekti; koyu yazının
                        // altında kirli bir hale bırakıyor.
                        shadows: ink == Colors.white
                            ? const [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Rank Row (4-10) ─────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.isKu,
    this.highlight = false,
    this.colorOverride,
  });

  final LeaderboardEntry entry;
  final bool isKu;

  /// Oyuncunun kendi satırı: listede görünmediğinde en alta sabitlenir.
  final bool highlight;

  /// 2026-07-23 M25b: yalnız ana listeden (görünür ilk 10) çağrılırken
  /// [resolveAvatarColors] ile doldurulur. `_buildMyRankRow`'un ayrıca
  /// getirdiği "kendi sıram" satırı bu listenin dışında, override almaz.
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    // Satır sıra, ad, oda/zincir ve puanı ayrı metinler olarak taşıyordu;
    // ekran okuyucu bunları bağlamsız dört parça hâlinde okuyordu. Tek
    // düğümde birleştirilir (2026-07-25 denetimi).
    return Semantics(
      label: highlight
          ? (Tr.forKu(K.seninSiranPP, isKu, {
              'p0': '${entry.rank}',
              'p1': entry.displayName,
              'p2': '${entry.totalScore}',
            }))
          : (Tr.forKu(K.pPPPuan, isKu, {
              'p0': '${entry.rank}',
              'p1': entry.displayName,
              'p2': '${entry.totalScore}',
            })),
      excludeSemantics: true,
      child: _buildRow(context),
    );
  }

  Widget _buildRow(BuildContext context) {
    return Container(
      key: highlight
          ? const ValueKey('leaderboard-my-rank-row')
          : ValueKey('leaderboard-rank-row-${entry.rank}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.brand.withValues(alpha: 0.10)
            : AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        border: Border.all(
          color: highlight
              ? AppTheme.brand.withValues(alpha: 0.45)
              : AppTheme.borderColor(context).withValues(alpha: 0.55),
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppTheme.brand.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: entry.rank <= 10
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.gold,
                        Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.12),
                          AppTheme.gold,
                        ),
                      ],
                    )
                  : null,
              color: entry.rank <= 10
                  ? null
                  : AppTheme.textMutedColor(context).withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: AppTypography.bodyMedium.copyWith(
                color: entry.rank <= 10
                    ? Colors.white
                    : AppTheme.textSubColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PlayerAvatar(
            radius: 18,
            photoUrl: entry.avatarUrl,
            iconId: entry.avatarIcon,
            colorHex: entry.avatarColor,
            frameId: entry.avatarFrame,
            displayName: entry.displayName,
            colorOverride: colorOverride,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  entry.showcaseTitle != null
                      ? '${entry.showcaseTitle} · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}'
                      : '${entry.roomsPlayed} ${isKu ? "ode" : "oda"}'
                            ' · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${entry.totalScore}',
                style: AppTypography.bodyLarge.copyWith(
                  // Ham altın beyaz kart üstünde 2.30:1; sıralamadaki puan
                  // okunmuyordu (2026-07-27).
                  color: AppColors.readableAccent(context, AppTheme.gold),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend Rank Row (Arkadaşlar tab) ─────────────────────────────────────────

class _FriendRankRow extends StatelessWidget {
  const _FriendRankRow({required this.friend, required this.isKu});

  final Friend friend;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final online = friend.isOnline;
    return Container(
      key: ValueKey('friend-rank-row-${friend.friendId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppTheme.statCard(context, AppTheme.cyan).copyWith(
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${friend.level}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar with online dot
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                PlayerAvatar(
                  radius: 18,
                  colorHex: friend.friendAvatarColor,
                  displayName: friend.friendName,
                ),
                // Online status dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? AppTheme.brand : AppTheme.textMuted,
                      border: Border.all(
                        color: AppTheme.surfaceColor(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.friendName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  online
                      ? (Tr.forKu(K.online, isKu))
                      : (Tr.forKu(K.offline, isKu)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: online
                        ? AppTheme.brand
                        : AppTheme.textMutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${friend.totalScore}',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.readableAccent(context, AppTheme.cyan),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
