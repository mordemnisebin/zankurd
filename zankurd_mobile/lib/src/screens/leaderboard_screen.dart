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
import '../utils/player_identity.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import 'friends_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../widgets/dialog_action_pair.dart';

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

  /// Liderlik gövdesi: (varsa lig bandı) + sıralı liste.
  ///
  /// 2026-09-29 doğallık (K9): podyum kalktı. İlk üç büyük elmas avatar,
  /// madalya halkası, birincide taç ve altın haleyle kaidelere diziliyordu;
  /// üç kişilik bir haftada ekranın tamamı buydu ve "kutlama" hiçbir şey
  /// kazanılmadan çiziliyordu. Artık bütün sıralama tek liste: ilk üç
  /// yalnız sıra rakamının renginden ayrılır ([_RankRow]), oyuncunun kendi
  /// satırı listede "Sen" rozetiyle, listede değilse altta sabit.
  ///
  /// Geniş ekranda (iPad) liste okunur bir genişlikte (≤ 640) ortalanır;
  /// eskiden sol sütun podyumu, sağ sütun listeyi taşıyordu. 720 eşiği
  /// `onboarding_screen.dart`taki eşikle aynıdır (2026-08-04).
  Widget _buildBody(
    List<LeaderboardEntry> entries,
    Map<String, Color> avatarColorOverrides,
    bool ku,
  ) {
    final uid = widget.repository.currentUserId;

    final list = KeyedSubtree(
      key: const ValueKey('leaderboard-rank-list'),
      child: _RankListSurface(
        rows: [
          for (final e in entries)
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
        ],
      ),
    );
    // Lig bandı bayrakla kapalı (bkz. `kWeeklyLeagueEnabled`).
    final banner = kWeeklyLeagueEnabled && _period == LeaderboardPeriod.weekly
        ? _LeagueBanner(myRank: _myRank(entries), isKu: ku)
        : null;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          banner,
          const SizedBox(height: SahneSpace.cardGap),
        ],
        list,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Eşik ekran enidir; gövde sayfa kenarı (2 × 16) kadar daha dardır.
        if (constraints.maxWidth + 2 * SahneSpace.page < 720) return column;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: const ValueKey('leaderboard-wide-list'),
            constraints: const BoxConstraints(maxWidth: 640),
            child: column,
          ),
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
            'p0': PlayerIdentity.resolveName(
              entry.displayName,
              isKu: dialogContext.isKu,
            ),
          }),
        ),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.t(K.cancel)),
            ),
            confirm: FilledButton(
              key: const ValueKey('report-profile-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.t(K.reportAction)),
            ),
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

  bool _listsMe(List<LeaderboardEntry> entries) {
    final uid = widget.repository.currentUserId;
    return uid != null && entries.any((e) => e.playerId == uid);
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
        final fetched = snap.data ?? stale ?? [];
        // Sunucuya ulaşılamıyorken boş liste "henüz puan yok" demek
        // değildir: sıralama yalnız okunamadı (2026-09-27 simülatör turu).
        if (fetched.isEmpty && RemoteAvailability.socialLockedIn(context)) {
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
        // 2026-09-30 canlı: sıralama YALNIZ biten çevrimiçi odalardan
        // toplanır (`get_leaderboard`: room_players x rooms). Bot düellosu
        // ve günün soruları cihazda oynanır, oda açmaz; oyuncu ikisini de
        // oynadığı hâlde satırı "0 puan" görünüyordu ve 0 puanlı satır
        // sıralama değil gürültüdür (Ay sekmesinde dört ad sıfırla
        // sıralanıyordu). Puanı olmayanlar listeye girmez; hiç kimse
        // puanlı değilse boş durum ("Henüz puan yok", yarışa yönlendirir)
        // dürüst olandır. Sıra sunucu sırasıdır ve sıfırlar sondadır, yani
        // süzmek kalanların sırasını kaydırmaz.
        final entries = fetched.where((e) => e.totalScore > 0).toList();
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
          //
          // Oyuncunun kendi satırı bu dönemde listeden yalnız 0 puanla
          // süzüldüyse sabit satır da çizilmez: `getPlayerStats` toplam XP
          // ve tüm profiller içindeki sırayı verir (dönem puanı değil);
          // "0 puan" yerine XP'yi göstermek aynı ekranda iki ayrı sayıyı
          // aynı etiketle sunmak olurdu.
          pinned: _myRank(entries) == null && !_listsMe(fetched)
              ? _buildMyRankRow(ku)
              : null,
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

// ─── Sıra satırı ────────────────────────────────────────────────────────────

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

  /// Sıra rakamının rengi — ilk üçü listede ayıran TEK işaret.
  ///
  /// 2026-09-29 doğallık (K9): podyum, taç ve madalya halkası yok; birinci
  /// altın, ikinci gümüş, üçüncü bronz ([SahneTokens.silverTx],
  /// [SahneTokens.bronzeTx]; iki temada AA), gerisi ikincil metin. Rakam
  /// her zaman yazılıdır: sıra yalnız renkle anlatılmaz.
  Color _rankColor(SahneTokens t) {
    if (highlight) return t.goldTx;
    return switch (entry.rank) {
      1 => t.goldTx,
      2 => t.silverTx,
      3 => t.bronzeTx,
      _ => t.tx2,
    };
  }

  /// Görünen ad: sunucunun yer tutucu adı ("ZanKurd Oyuncusu") ham
  /// basılmaz, dile göre "Oyuncu" / "Lîstikvan" olur (satırda "ZanKurd
  /// Oyu…" diye kesiliyordu). Avatar rengi ham addan türer (değişmez).
  String get _name => PlayerIdentity.resolveName(entry.displayName, isKu: isKu);

  /// Alt metindeki sayı `get_leaderboard`ın `count(distinct room_id)`
  /// değeridir: oyuncunun BİTMİŞ çevrimiçi yarış (oda) sayısı. Birim
  /// eskiden "oda / ode" idi; oyuncu için bu bir yer değil oyun sayısı
  /// olduğundan sözlükteki "yarış / pêşbirk" ([K.raceWord]) yazılır
  /// (2026-09-30 canlı: "1 ode" anlaşılmıyordu). Bot düellosu ve günün
  /// soruları oda açmadığı için bu sayıya girmez.
  String get _meta => entry.showcaseTitle != null
      ? '${entry.showcaseTitle} · ${entry.bestStreak} ${Tr.forKu(K.streakUnit, isKu)}'
      : '${entry.roomsPlayed} ${Tr.forKu(K.raceWord, isKu).toLowerCase()}'
            ' · ${entry.bestStreak} ${Tr.forKu(K.streakUnit, isKu)}';

  @override
  Widget build(BuildContext context) {
    // Satır sıra, ad, oda/zincir ve puanı ayrı metinler olarak taşıyordu;
    // ekran okuyucu bunları bağlamsız dört parça hâlinde okuyordu. Tek
    // düğümde birleştirilir (2026-07-25 denetimi).
    final label = highlight
        ? (Tr.forKu(K.seninSiranPP, isKu, {
            'p0': '${entry.rank}',
            'p1': _name,
            'p2': '${entry.totalScore}',
          }))
        : (Tr.forKu(K.pPPPuan, isKu, {
            'p0': '${entry.rank}',
            'p1': _name,
            'p2': '${entry.totalScore}',
          }));

    if (highlight && !grouped) {
      return SahneListRow.me(
        key: const ValueKey('leaderboard-my-rank-row'),
        rank: entry.rank,
        title: _name,
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
                      color: _rankColor(t),
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
                                _name,
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

/// Arkadaş sıralaması satırı (liste grubunun içinde): seviye karesi,
/// avatar + çevrimiçi işareti, ad + durum sözü, puan. Durum yalnız renkle
/// verilmez: "Çevrimiçi" / "Çevrimdışı" yazar.
///
/// 2026-09-29 doğallık (K5): çevrimiçi işareti küçük elmastı; elmas yalnız
/// soru ilerlemesi ve ders sayacında kalır, işaret küçük pahlı kare.
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
                          shape: SahneShape.withSide(
                            SahneShape.forSize(12),
                            t.s1,
                            width: SahneRing.r2,
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
                    PlayerIdentity.resolveName(friend.friendName, isKu: isKu),
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
