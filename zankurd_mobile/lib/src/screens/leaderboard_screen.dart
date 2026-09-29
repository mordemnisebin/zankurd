import 'dart:async';

import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../config/avatar_presets.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/league_tier.dart';
import '../providers/remote_availability.dart';
import '../utils/app_route.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/rolling_count.dart';
import '../widgets/sahne/sahne.dart';
import 'friends_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.repository,
    this.scrollController,
    this.refreshSignal,
    this.isVisible,
    super.key,
  });

  final ZanKurdRepository repository;
  final ScrollController? scrollController;
  final ValueNotifier<int>? refreshSignal;

  /// AppShell sekmesi görünür mü? `IndexedStack` gizli sekmeleri dispose
  /// etmediği için 30sn'lik otomatik tazeleme, kullanıcı başka sekmedeyken
  /// bile RPC atıyordu. Kapı kapalıyken sayaç atlanır; null ise eski
  /// davranış (her zaman tazele) korunur.
  final bool Function()? isVisible;

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

  /// Liderlik gövdesi: dar ekranda tek sütun, geniş ekranda iki sütun.
  ///
  /// iPad'de telefon düzeni yukarıdan aşağı gerilmiş hâlde çiziliyordu:
  /// podyum ekranın üçte birini kaplıyor, sıralama listesi katlamanın
  /// altında kalıyordu. 720 eşiği `onboarding_screen.dart`taki eşikle
  /// aynıdır; telefon düzeni hiçbir biçimde değişmez (2026-08-04).
  ///
  /// 2026-09-29 Şahnê: gövde artık kendi kaydırıcısını taşımaz; sayfanın
  /// (A iskeleti) içinde marka satırı ve başlıkla birlikte kayar. Podyum
  /// sahne kartı değil, sayfanın kendi zemininde durur (maket): elmas
  /// avatarlar madalya halkasıyla, birincide altın hale ve taç.
  Widget _buildBody(
    List<LeaderboardEntry> entries,
    Map<String, Color> avatarColorOverrides,
    bool ku,
  ) {
    final uid = widget.repository.currentUserId;
    final rest = entries.skip(3).toList();

    List<Widget> rankRows() => [
      for (final e in rest)
        _RankRow(
          entry: e,
          isKu: ku,
          grouped: true,
          highlight: uid != null && e.playerId == uid,
          colorOverride: avatarColorOverrides[e.playerId],
          // Kişi kendini bildiremez. Liste eskiden kendi satırında da
          // bildir düğmesi çiziyordu, çünkü satırın kime ait olduğu
          // sorulmuyordu (2026-08-04).
          onReport: e.playerId == uid ? null : () => _reportProfile(e),
        ),
    ];

    final podium = _Podium(
      entries: entries.take(3).toList(),
      isKu: ku,
      colorOverrides: avatarColorOverrides,
    );
    // Lig bandı bayrakla kapalı (bkz. `kWeeklyLeagueEnabled`).
    final banner = kWeeklyLeagueEnabled && _period == LeaderboardPeriod.weekly
        ? _LeagueBanner(myRank: _myRank(entries), isKu: ku)
        : null;

    // Geniş ekranda sol sütun podyumdan sonra boş kalıyordu; oyuncunun
    // kendi satırı ise sağdaki uzun listenin ortasında bir yerdeydi.
    // Bağlam sütununa kendi sıra özeti konur — AMA yalnız oyuncu gerçekten
    // sıralanmışsa ve podyumda DEĞİLSE.
    final selfIndex = uid == null
        ? -1
        : entries.indexWhere((e) => e.playerId == uid);
    final selfSummary = (_myRank(entries) != null && selfIndex >= 3)
        ? _RankRow(
            entry: entries[selfIndex],
            isKu: ku,
            highlight: true,
            colorOverride: avatarColorOverrides[entries[selfIndex].playerId],
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Eşik ekran enidir; gövde sayfa kenarı (2 × 16) kadar daha dardır.
        if (constraints.maxWidth + 2 * SahneSpace.page < 720) {
          // Podyum bu ekranın kahramanıdır; içerik TEPEDE durur (2026-08-19
          // görsel denetimi: dikeyde ortalanınca ilk bakışta kayboluyordu).
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[
                banner,
                const SizedBox(height: SahneSpace.cardGap),
              ],
              podium,
              if (rest.isNotEmpty) ...[
                const SizedBox(height: SahneSpace.cardGap),
                _RankListSurface(rows: rankRows()),
              ],
            ],
          );
        }
        // Geniş ekran: sol sütun bağlam (lig bandı + podyum), sağ sütun
        // sıralama.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (banner != null) ...[
                    banner,
                    const SizedBox(height: SahneSpace.cardGap),
                  ],
                  podium,
                  if (selfSummary != null) ...[
                    const SizedBox(height: SahneSpace.cardGap),
                    selfSummary,
                  ],
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.cardGap),
            Expanded(
              flex: 6,
              child: rest.isEmpty
                  ? const SizedBox.shrink()
                  : KeyedSubtree(
                      key: const ValueKey('leaderboard-wide-list'),
                      child: _RankListSurface(rows: rankRows()),
                    ),
            ),
          ],
        );
      },
    );
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
        // Genel liderlik sekmesi engellenen oyuncuyu 2026-08-02'den beri
        // süzüyor (yukarıdaki yorum); Arkadaşlar sekmesi aynı süzgeci hiç
        // uygulamıyordu. Engellenen kişi arkadaşsa listede "Odaya davet
        // et" düğmesiyle durmaya devam ediyordu — Apple 1.2'nin istediği
        // "bu kişiyi bir daha görmeyeyim" sözü tek yüzeyde tutulmuyordu
        // (2026-08-14 denetimi).
        _friendsFuture =
            Future.wait([
              widget.repository.loadFriendsLeaderboard(),
              widget.repository.loadBlockedPlayerIds(),
            ]).timeout(const Duration(seconds: 10)).then((results) {
              final friends = results[0] as List<Friend>;
              final blocked = results[1] as Set<String>;
              final visible = friends
                  .where((f) => !blocked.contains(f.friendId))
                  .toList();
              _lastFriends = visible;
              return visible;
            });
      });
    } else {
      setState(() {
        // Engellenen oyuncular liderlikten SÜZÜLÜR.
        //
        // `block_player` 2026-08-02'ye kadar yalnız sohbeti süzüyordu;
        // engellenen kişinin avatarı ve adı liderlikte, eşleştirmede ve
        // turnuva tablosunda görünmeye devam ediyordu. Apple 1.2'nin
        // "engelleme" maddesi kullanıcı gözünde "bu kişiyi bir daha
        // görmeyeyim" demektir — yalnız bir yüzeyde uygulanması onu
        // karşılamaz (A-05 -> P1-008).
        //
        // Sunucu tarafında da süzülür (`leaderboard_visible` RPC'si);
        // buradaki kopya derinlemesine savunmadır ve engel listesi
        // okunamadığında bile listeyi boşaltmaz.
        _future =
            Future.wait([
              widget.repository.loadLeaderboard(limit: 10, period: _period),
              widget.repository.loadBlockedPlayerIds(),
            ]).timeout(const Duration(seconds: 10)).then((results) {
              final entries = results[0] as List<LeaderboardEntry>;
              final blocked = results[1] as Set<String>;
              final visible = entries
                  .where((e) => !blocked.contains(e.playerId))
                  .toList();
              _lastEntries = visible;
              return visible;
            });
      });
    }
  }

  /// Bir oyuncunun profilini (avatar + görünen ad) bildirir.
  ///
  /// Sunucu bildirimi kaydeder VE bildiren kullanıcı için engeli kurar:
  /// kişi bildirdiği avatarı bir daha görmek zorunda kalmamalı. Karar
  /// (içeriğin kaldırılması) moderasyon tarafındadır; istemci karar vermez —
  /// `report_room_message` de aynı deseni izliyor.
  Future<void> _reportProfile(LeaderboardEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('report-profile-dialog'),
        title: Text(dialogContext.t(K.reportProfileTitle)),
        content: Text(
          Tr.forKu(K.reportProfileBodyP, dialogContext.isKu, {
            'p0': entry.displayName,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.t(K.cancel)),
          ),
          FilledButton(
            key: const ValueKey('report-profile-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.t(K.reportAction)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await widget.repository.reportPlayerProfile(
      playerId: entry.playerId,
      reason: 'profile_avatar_or_name',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(ok ? K.reportProfileDone : K.errorOccurred)),
      ),
    );
    if (ok) _loadData();
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
      if (!mounted) return;
      if (!(widget.isVisible?.call() ?? true)) return;
      _loadData();
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
        ? widget.repository.playableQuestions
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

  /// Sayfa iskeleti: sekme olarak A (marka satırı + 28'lik başlık), quiz
  /// sonucundan tam rota olarak açıldığında B (geri + 22'lik başlık).
  ///
  /// Bu ekran İKİ ayrı biçimde kullanılıyor: `AppShell`in 2. sekmesi olarak
  /// ve quiz sonucundan tam rota olarak (`quiz_result_screen.dart` →
  /// `AppRoute.to(...)`). İkinci kullanımda eskiden hiçbir Material atası ve
  /// geri düğmesi yoktu; iOS'ta ekran çıkışsız kalıyordu (2026-08-02
  /// denetimi, A-10). Sekme olarak açıldığında `canPop` false'tur.
  ///
  /// [pinned]: oyuncu ilk 10'da değilse listenin altına sabitlenen kendi
  /// sırası — kaydırmadan bağımsız, her zaman ekranda.
  Widget _page(
    BuildContext context,
    bool ku, {
    required Widget content,
    Widget? pinned,
  }) {
    final canPop = Navigator.of(context).canPop();
    final actions = _HeaderActions(
      onRefresh: _loadData,
      onOpenFriends: _openFriends,
      pendingRequestCount: _pendingRequests,
    );
    final top = <Widget>[
      _PeriodRail(controller: _tabController, ku: ku),
      const SizedBox(height: SahneSpace.x4),
      content,
    ];

    final Widget scroll;
    if (canPop) {
      // Sonuç ekranından açılan liderlik: B iskeleti. Geri düğmesinin
      // sabit anahtarı (`leaderboard-back`) bileşene verilir.
      scroll = SahnePushedPage(
        title: context.t(K.leaderboardTitle),
        backKey: const ValueKey('leaderboard-back'),
        backLabel: context.t(K.back),
        controller: widget.scrollController,
        actions: [actions],
        children: top,
      );
    } else {
      scroll = SahneTabPage(
        controller: widget.scrollController,
        title: context.t(K.leaderboardTitle),
        stats: [actions],
        children: top,
      );
    }

    return Material(
      color: SahneTokens.of(context).bg,
      child: Column(
        children: [
          Expanded(child: scroll),
          ?pinned,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return _tabController.index == 3
        ? _buildFriendsTab(ku)
        : _buildLeaderboardTab(ku);
  }

  /// Filtre/yenileme sırasında mevcut liste korunur; ince çubuk yükleme
  /// sinyali verir — gri boş ekran yerine.
  Widget _refreshBar(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x3),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: SahneShape.s),
        child: LinearProgressIndicator(
          minHeight: 4,
          color: t.goldTx,
          backgroundColor: t.s3,
        ),
      ),
    );
  }

  Widget _loadingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.x8),
      child: Center(
        child: CircularProgressIndicator(
          color: SahneTokens.of(context).goldTx,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildFriendsTab(bool ku) {
    return FutureBuilder<List<Friend>>(
      future: _friendsFuture,
      builder: (ctx, snap) {
        final stale = _lastFriends;
        final Widget content;
        if (snap.connectionState == ConnectionState.waiting && stale == null) {
          content = _loadingIndicator(context);
        } else if (snap.hasError && stale == null) {
          content = AppErrorState(
            title: context.t(K.friendsLoadFail),
            message: context.t(K.checkConnection),
            retryLabel: context.t(K.retry),
            onRetry: _loadData,
          );
        } else {
          final friends = snap.data ?? stale ?? [];
          if (friends.isEmpty) {
            content = AppEmptyState(
              icon: AppIcons.peopleGroup,
              title: context.t(K.noFriends),
              message: context.t(K.noFriendsAddHint),
              actionLabel: context.t(K.addFriend),
              actionIcon: AppIcons.userPlus,
              onAction: _openFriends,
            );
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snap.connectionState == ConnectionState.waiting)
                  _refreshBar(context),
                SahneListGroup(
                  dividerIndent: SahneSpace.x3 + 36 + SahneSpace.x3,
                  children: [
                    for (final friend in friends)
                      _FriendRankRow(friend: friend, isKu: ku),
                  ],
                ),
              ],
            );
          }
        }
        return _page(context, ku, content: content);
      },
    );
  }

  Widget _buildLeaderboardTab(bool ku) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (ctx, snap) {
        final stale = _lastEntries;
        if (snap.connectionState == ConnectionState.waiting && stale == null) {
          return _page(context, ku, content: _loadingIndicator(context));
        }
        if (snap.hasError && stale == null) {
          return _page(
            context,
            ku,
            content: AppErrorState(
              title: context.t(K.boardLoadFailed),
              message: context.t(K.checkConnection),
              retryLabel: context.t(K.retry),
              onRetry: _loadData,
            ),
          );
        }
        final entries = snap.data ?? stale ?? [];
        // Sunucuya ulaşılamıyorken boş liste "henüz puan yok" demek
        // değildir: sıralama yalnız okunamadı (2026-09-27 simülatör turu).
        if (entries.isEmpty && RemoteAvailability.socialLockedIn(context)) {
          return _page(
            context,
            ku,
            content: AppErrorState(
              title: context.t(K.boardLoadFailed),
              message: context.t(K.checkConnection),
              retryLabel: context.t(K.retry),
              onRetry: _loadData,
            ),
          );
        }
        if (entries.isEmpty) {
          return _page(
            context,
            ku,
            content: AppEmptyState(
              icon: AppIcons.trophy,
              title: context.t(K.noScoresYet),
              message: context.t(K.startRaceHint),
              actionLabel: context.t(K.startRaceAction),
              actionIcon: AppIcons.bolt,
              onAction: _startQuickRace,
            ),
          );
        }
        // 2026-07-23 M25b: görünür ilk 10 arasında hash çakışması varsa
        // (ör. podyumdaki 3 oyuncu aynı pembe) round-robin ile çözülür.
        // Build başında bir kez hesaplanır, renkler "titremesin" diye.
        final avatarColorOverrides = resolveAvatarColors(
          entries.map(
            (e) => (
              id: e.playerId,
              displayName: e.displayName,
              colorHex: e.avatarColor,
            ),
          ),
        );
        return _page(
          context,
          ku,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snap.connectionState == ConnectionState.waiting)
                _refreshBar(context),
              _buildBody(entries, avatarColorOverrides, ku),
            ],
          ),
          // Liderlik yalnız ilk 10'u getiriyor; oyuncu listede yoksa
          // kendi sırasını hiç göremiyordu (2026-07-22 UX denetimi). Satır
          // listenin altına sabitlenir — her zaman ekranda (2026-07-25).
          pinned: _myRank(entries) == null ? _buildMyRankRow(ku) : null,
        );
      },
    );
  }
}

// ─── Sabitlenen kendi sıran ─────────────────────────────────────────────────

/// Liderlik listesinin altına sabitlenen "senin sıran" şeridi. Listeden
/// ayrı bir katman olduğu için kaydırmadan bağımsız olarak hep görünür.
/// Zemin sayfanın kendisi; üstte 1 px çizgi.
class _PinnedMyRank extends StatelessWidget {
  const _PinnedMyRank({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x2,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Haftalık Lig Bandı ──────────────────────────────────────────────────────

/// Haftalık ligde oyuncunun kademesini gösterir: Zêr / Zîv / Bronz.
/// Kademe canlı haftalık sıradan türetilir. Yüzey kartı; kademe ikonu Zêr
/// (ödül) tonlu karoda.
class _LeagueBanner extends StatelessWidget {
  const _LeagueBanner({required this.myRank, required this.isKu});

  final int? myRank;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final tier = LeagueTier.forRank(myRank);
    final accessibilityText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return KeyedSubtree(
      key: const ValueKey('league-banner'),
      child: SahneSurfaceCard(
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Row(
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: t.goldTint,
                shape: SahneShape.m,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(tier.icon, color: t.goldTx, size: 24),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.label(isKu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                  Text(
                    myRank != null
                        ? (Tr.forKu(K.buHaftakiSiranP, isKu, {'p0': '$myRank'}))
                        : (Tr.forKu(K.buHaftaYarisLige, isKu)),
                    maxLines: accessibilityText ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
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

// ─── Başlık eylemleri ───────────────────────────────────────────────────────

/// Arkadaşlar ve yenile: marka satırının sağında (A) ya da çubuğun sağında
/// (B) duran iki 44'lük pahlı ikon düğmesi (48 dokunma alanı).
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onRefresh,
    required this.onOpenFriends,
    required this.pendingRequestCount,
  });

  final VoidCallback onRefresh;

  /// Arkadaş ekranını açar. Bu düğme 2026-07-31'e kadar YOKTU.
  ///
  /// `FriendsScreen` — oyuncu arama, istek gönderme, GELEN İSTEKLERİ
  /// kabul/ret, arkadaşla oda kurma — yalnız Arkadaşlar sekmesinin BOŞ DURUM
  /// düğmesinden açılıyordu. Kullanıcı bir arkadaş edindiği anda boş durum
  /// kayboluyor ve ekrana giden hiçbir yol kalmıyordu: tüm sosyal katman
  /// ilk arkadaştan sonra sessizce ölüyordu.
  final VoidCallback onOpenFriends;

  /// Bekleyen arkadaşlık isteği sayısı; 0 ise rozet çizilmez.
  final int pendingRequestCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        _HeaderAction(
          valueKey: const ValueKey('leaderboard-refresh-button'),
          icon: AppIcons.arrowsRotate,
          tooltip: context.t(K.refreshAction),
          semanticLabel: context.t(K.refreshBoardA11y),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

/// Tek başlık düğmesi: 44'lük görsel (Perde, M pah, gündüzde 1 px kenar)
/// 48'lik dokunma kutusunda. Rozet yalnız sayı sıfırdan büyükken görünür —
/// boş bir nokta "bir şey var" der ama ne olduğunu söylemez. Rozet dolu
/// kırmızı değil: Boyax tonu + sayı.
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
    final button = SahneIconButton(
      key: valueKey,
      icon: icon,
      semanticLabel: semanticLabel,
      tooltip: tooltip,
      onPressed: onPressed,
    );

    if (badgeCount <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        PositionedDirectional(
          end: -SahneSpace.x1,
          top: -SahneSpace.x1,
          child: IgnorePointer(
            child: SahneBadge(
              key: const ValueKey('leaderboard-friends-badge'),
              label: badgeCount > 9 ? '9+' : '$badgeCount',
              tone: SahneBadgeTone.race,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dönem rayı ─────────────────────────────────────────────────────────────

/// Gün / Hafta / Ay / Arkadaş — sığan seçim rayı ([SahneRail.fit]); seçili
/// çip Zêr (ödül) tonu. Kısa etiketler: 4 eşit çip 320 px'te de sığar.
class _PeriodRail extends StatelessWidget {
  const _PeriodRail({required this.controller, required this.ku});

  final TabController controller;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final labels = ku
        ? ['Roj', 'Heft', 'Meh', 'Heval']
        : ['Gün', 'Hafta', 'Ay', 'Arkadaş'];
    // Çip görselde 44; dokunma kutusu ve ekran okuyucu düğümü 48
    // (2026-09-29 ek kararı: `SahneRailChip` 48'lik kutuya sarılır).
    return SahneRail.fit(
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            container: true,
            button: true,
            selected: controller.index == i,
            label: labels[i],
            onTap: () => controller.index = i,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.index = i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SahneRailChip(
                  label: labels[i],
                  selected: controller.index == i,
                  role: SahneRole.gold,
                  onTap: () => controller.index = i,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Podium (top 3) ──────────────────────────────────────────────────────────

/// Kürsü: 2. sol, 1. orta (daha büyük, altın hale ve taç), 3. sağ.
///
/// 2026-09-29 Şahnê: podyum artık bir sahne kartı değil, sayfanın kendi
/// zemininde durur (maket). Elmas avatarlar madalya renginde Halka 3
/// taşır (altın / gümüş / bronz); birincinin arkasında altın hale
/// (gradyan, bulanıklık yok), üstünde taç glifi. Kaideler Kulis tonunda,
/// üst kenarları madalya renginde; sıra numarası kaidede. Eski ışık
/// hüzmesi + konfeti ressamı, kilim açılışı, madalya amblemleri ve dolu
/// renkli kaideler kalktı.
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

    final content = slots.length == 1
        ? Center(child: slots.first)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const SizedBox(width: SahneSpace.x2),
                Expanded(child: slots[i]),
              ],
            ],
          );

    return KeyedSubtree(
      key: const ValueKey('leaderboard-podium'),
      child: content,
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

  /// Madalya rengi: halka ve kaidenin üst kenarı.
  Color _medal(SahneTokens t) => switch (entry.rank) {
    1 => t.gold,
    2 => SahneStageColors.silver,
    _ => SahneStageColors.bronze,
  };

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final medal = _medal(t);
    final first = entry.rank == 1;
    final avatar = isCenter ? 64.0 : 48.0;
    final pedestalH = isCenter
        ? 80.0
        : entry.rank == 2
        ? 56.0
        : 44.0;

    // Avatar + madalya halkası (içe çizilen Halka 3). Birincide arkada
    // 116'lık altın hale.
    final ring = SizedBox.square(
      dimension: avatar,
      child: Stack(
        children: [
          PlayerAvatar(
            radius: avatar / 2,
            photoUrl: entry.avatarUrl,
            iconId: entry.avatarIcon,
            colorHex: entry.avatarColor,
            frameId: entry.avatarFrame,
            displayName: entry.displayName,
            colorOverride: colorOverride,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: SahneShape.diamond(
                    avatar,
                    side: BorderSide(
                      color: medal,
                      width: SahneRing.r3,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final avatarBlock = first
        ? SizedBox(
            width: 116,
            height: avatar + 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: avatar / 2 - 58,
                  child: IgnorePointer(
                    child: SizedBox.square(
                      dimension: 116,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              SahneStageColors.haloGold,
                              SahneStageColors.haloGold.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  child: SahneGlyph(SahneGlyphKind.crown, size: 24),
                ),
                ring,
              ],
            ),
          )
        : ring;

    // Tek kazanan (ya da geniş sütun) basamağı ekran boyu gerilmesin:
    // basamak en çok 180 genişlikte kalır.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Column(
        key: ValueKey('podium-slot-${entry.rank}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          avatarBlock,
          const SizedBox(height: SahneSpace.x2),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          if (entry.showcaseTitle != null)
            Text(
              entry.showcaseTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          // Puan %200 yazıda "50/00" gibi iki satıra bölünüyordu: sayı bir
          // sözcük değil. `FittedBox` YALNIZ sayıya uygulanır ve yalnız
          // gerekince küçültür (2026-08-04 görsel denetimi).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RollingCount(
              value: entry.totalScore,
              maxLines: 1,
              style: SahneType.captionStrong.copyWith(
                color: t.goldTx,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: SahneSpace.x2),
          // Kaide: Perde tonu, üstte madalya renginde 3 px şerit, sıra no
          // (birincide koyu altın). Şerit pahın içinde kalır (M pahla
          // kırpılır). Birincinin kaidesi Kulis'e çıkmaz: gündüzde Kulis
          // üstünde koyu altın 4.4:1'e düşüyordu.
          ClipPath(
            clipper: const ShapeBorderClipper(shape: SahneShape.m),
            child: SizedBox(
              width: double.infinity,
              height: pedestalH,
              child: ColoredBox(
                color: t.s1,
                child: Column(
                  children: [
                    SizedBox(
                      height: SahneRing.r3,
                      width: double.infinity,
                      child: ColoredBox(color: medal),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${entry.rank}',
                          style: SahneType.headline.copyWith(
                            color: first ? t.goldTx : t.tx2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rank Row (4-10) ─────────────────────────────────────────────────────────

/// Sıralama satırlarını tek bir yüzeyde toplar: liste grubu, satırlar
/// arası avatar hizasından başlayan 1 px ayırıcı.
///
/// Her satıra ayrı kenarlık, gölge ve dış boşluk vermek listeyi on ayrı
/// karta bölüyordu (2026-08-04).
class _RankListSurface extends StatelessWidget {
  const _RankListSurface({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return SahneListGroup(
      dividerIndent: SahneSpace.x3 + 24 + SahneSpace.x3,
      children: rows,
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.isKu,
    this.highlight = false,
    this.grouped = false,
    this.colorOverride,
    this.onReport,
  });

  final LeaderboardEntry entry;
  final bool isKu;

  /// Oyuncunun kendi satırı. Grup DIŞINDA (sabitlenen satır, geniş ekran
  /// özeti) maketteki "Sen" satırıdır: Zêr tonu + altın halka, L pah.
  /// Grubun içinde sıra no koyu altın ve adın yanında "Sen" rozeti —
  /// vurgu renk tek başına değil, söz de taşır.
  final bool highlight;

  /// Satır ortak liste grubunun İÇİNDE mi çiziliyor.
  final bool grouped;

  /// 2026-07-23 M25b: yalnız ana listeden (görünür ilk 10) çağrılırken
  /// [resolveAvatarColors] ile doldurulur.
  final Color? colorOverride;

  /// Bu oyuncunun profilini (avatar + ad) bildirme eylemi.
  ///
  /// Avatar, yabancılara gösterilen bir GÖRSEL UGC yüzeyidir; 2026-08-02'ye
  /// kadar onu bildirmenin hiçbir yolu yoktu (A-05 -> P1-008). Eylem
  /// GÖRÜNÜR bir düğmedir. Kendi satırında null'dır — kişi kendini
  /// bildiremez.
  final VoidCallback? onReport;

  String get _meta => entry.showcaseTitle != null
      ? '${entry.showcaseTitle} · ${entry.bestStreak} ${Tr.forKu(K.streakUnit, isKu)}'
      : '${entry.roomsPlayed} ${Tr.forKu(K.roomUnit, isKu)}'
            ' · ${entry.bestStreak} ${Tr.forKu(K.streakUnit, isKu)}';

  @override
  Widget build(BuildContext context) {
    // Satır sıra, ad, oda/zincir ve puanı ayrı metinler olarak taşıyordu;
    // ekran okuyucu bunları bağlamsız dört parça hâlinde okuyordu. Tek
    // düğümde birleştirilir (2026-07-25 denetimi).
    final label = highlight
        ? (Tr.forKu(K.seninSiranPP, isKu, {
            'p0': '${entry.rank}',
            'p1': entry.displayName,
            'p2': '${entry.totalScore}',
          }))
        : (Tr.forKu(K.pPPPuan, isKu, {
            'p0': '${entry.rank}',
            'p1': entry.displayName,
            'p2': '${entry.totalScore}',
          }));

    if (highlight && !grouped) {
      return SahneListRow.me(
        key: const ValueKey('leaderboard-my-rank-row'),
        rank: entry.rank,
        title: entry.displayName,
        subtitle: _meta,
        // "Sen" rozeti vurgunun sözlü kanalı: altın ton ve halka tek
        // başına renk körü oyuncuya yetmez.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SahneBadge(label: Tr.forKu(K.you, isKu), tone: SahneBadgeTone.gold),
            const SizedBox(width: SahneSpace.x2),
            _score(),
          ],
        ),
        semanticLabel: label,
      );
    }
    return Semantics(
      key: ValueKey('leaderboard-rank-row-${entry.rank}'),
      container: true,
      label: label,
      child: _buildRow(context),
    );
  }

  Widget _score() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 72),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SahneRowValue('${entry.totalScore}'),
    ),
  );

  Widget _buildRow(BuildContext context) {
    final t = SahneTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x1,
          onReport == null && !grouped ? SahneSpace.x4 : 0,
          SahneSpace.x1,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${entry.rank}',
                    maxLines: 1,
                    style: SahneType.bodyStrong.copyWith(
                      color: highlight ? t.goldTx : t.tx2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            PlayerAvatar(
              radius: 18,
              photoUrl: entry.avatarUrl,
              iconId: entry.avatarIcon,
              colorHex: entry.avatarColor,
              frameId: entry.avatarFrame,
              displayName: entry.displayName,
              colorOverride: colorOverride,
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ad ve "Sen" rozeti tek satırda; ad esner, rozet
                    // esnemez. %200 yazı + 320 px gibi aşırı dar durumda
                    // rozet yalnız okunabileceği genişlikte çizilir; satırın
                    // birleşik etiketi "senin sıran" bilgisini zaten verir.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final showSelfTag =
                            highlight && constraints.maxWidth >= 72;
                        return Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.displayName,
                                style: SahneType.bodyStrong.copyWith(
                                  color: t.tx,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showSelfTag) ...[
                              const SizedBox(width: SahneSpace.x2),
                              SahneBadge(
                                label: Tr.forKu(K.you, isKu),
                                tone: SahneBadgeTone.gold,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    Text(
                      _meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            ExcludeSemantics(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: highlight ? t.goldTx : t.tx),
                child: _score(),
              ),
            ),
            // Bildir düğmesi GÖRÜNÜRDÜR. Sohbetteki bildir/engelle yalnız
            // keşfedilemez bir uzun basmayla erişilebiliyordu ve denetimde
            // bu ayrıca kusur sayılmıştı. Kendi satırında düğme yok ama
            // LİSTE İÇİNDE yeri durur: aksi hâlde puan sağa kayıyor ve
            // listenin sağ kenarı en çok bakılan satırda kırılıyordu.
            if (onReport == null)
              if (grouped)
                const SizedBox(width: 48)
              else
                const SizedBox.shrink()
            else
              Semantics(
                button: true,
                label: Tr.forKu(K.reportProfileTitle, isKu),
                child: IconButton(
                  key: ValueKey('leaderboard-report-${entry.playerId}'),
                  onPressed: onReport,
                  icon: const Icon(AppIcons.flag, size: 16),
                  color: t.tx3,
                  // Android dokunma hedefi: 48 dp altına düşmez.
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: Tr.forKu(K.reportProfileTitle, isKu),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Friend Rank Row (Arkadaşlar tab) ─────────────────────────────────────────

/// Arkadaş sıralaması satırı (liste grubunun içinde): seviye karesi, elmas
/// avatar + çevrimiçi noktası, ad + durum sözü, puan. Durum yalnız renkle
/// verilmez: "Çevrimiçi" / "Çevrimdışı" yazar.
class _FriendRankRow extends StatelessWidget {
  const _FriendRankRow({required this.friend, required this.isKu});

  final Friend friend;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final online = friend.isOnline;
    return ConstrainedBox(
      key: ValueKey('friend-rank-row-${friend.friendId}'),
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x4,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            // Seviye karesi
            DecoratedBox(
              decoration: ShapeDecoration(color: t.s2, shape: SahneShape.s),
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Text(
                    '${friend.level}',
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            SizedBox.square(
              dimension: 40,
              child: Stack(
                children: [
                  PlayerAvatar(
                    radius: 18,
                    colorHex: friend.friendAvatarColor,
                    displayName: friend.friendName,
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    end: 0,
                    child: SizedBox.square(
                      dimension: 12,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: online ? t.learnTx : t.tx3,
                          shape: SahneShape.diamond(
                            12,
                            side: BorderSide(color: t.s1, width: SahneRing.r2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.friendName,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    online
                        ? (Tr.forKu(K.online, isKu))
                        : (Tr.forKu(K.offline, isKu)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.caption.copyWith(
                      color: online ? t.learnTx : t.tx2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${friend.totalScore}',
                  style: SahneType.bodyStrong.copyWith(
                    color: t.tx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
