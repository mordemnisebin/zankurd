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
import '../widgets/player_moderation_button.dart';
import '../widgets/app_state.dart';
import '../widgets/leaderboard_arena.dart';
import '../widgets/leaderboard_podium.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import 'contest_screen.dart';
import 'friends_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/number_format.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.repository,
    this.scrollController,
    this.refreshSignal,
    this.isVisible,
    this.onOpenPlay,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Boş sıralamanın "Yarışa başla" düğmesi: Oyna sekmesine geçer. Sıralama
  /// yalnız biten çevrimiçi odaları saydığı için yerel bir quiz açmak
  /// kullanıcıyı puan getirmeyen bir oyuna götürüyordu (Codex denetimi
  /// 2026-10-29). Verilmezse (tam rota olarak açılmış) eski yerel yarış.
  final VoidCallback? onOpenPlay;
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

  /// Oyuncunun kendi satırı; ilk 10'da değilse sırasını yine de
  /// gösterebilmek için ayrıca yüklenir.
  ///
  /// 2026-09-30: sonuç SEÇİLİ DÖNEMİN (Gün/Hafta/Ay) sıralamasından gelir
  /// (`getMyLeaderboardRank`), toplam XP'den değil — liste de aynı dönem
  /// süzgeciyle çiziliyor.
  Future<_MyRankLookup>? _myRankFuture;

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

  @override
  void didUpdateWidget(covariant LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_loadData);
      widget.refreshSignal?.addListener(_loadData);
    }
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

  /// Seçili dönemin sıralamasındaki kendi satırı.
  ///
  /// `getMyLeaderboardRank` yalnız biten çevrimiçi odalardan gelen dönem
  /// puanını döndürür (`get_leaderboard` ile aynı süzgeç); `getPlayerStats`
  /// toplam XP veriyordu ve aynı ekranda iki ayrı sayı aynı etiketle
  /// sunuluyordu. Dönemde puanı yoksa null — sabit satır çizilmez.
  Future<_MyRankLookup> _loadMyRank() async {
    try {
      return _MyRankLookup(
        await widget.repository.getMyLeaderboardRank(_period),
      );
    } catch (_) {
      // Okunamadı: "sıralamada değilsin" demek için sebep yok.
      return const _MyRankLookup(null, failed: true);
    }
  }

  /// Liderlik gövdesi: (varsa lig bandı) + ilk üç podyum + kalan sıralı liste.
  ///
  /// 2026-09-29 doğallık (K9) podyumu kaldırmıştı (büyük elmaslar, madalya
  /// halkası, taç, hale). 2026-10-01 tasarım denetimi (A8) ilk üçün
  /// ayrışmasını yeniden istedi: [LeaderboardPodium] — süssüz, üç pahlı
  /// kaide. Üç ve daha çok oyuncu varken ilk üç podyumda, 4. sıradan
  /// itibaren liste; daha azında ya da podyum sığmayan yerde (320 px'te
  /// büyük yazı) bütün sıralama tek liste. Oyuncunun kendi satırı listede
  /// (ya da podyumda) "Sen" rozetiyle, ilk 10'da değilse altta sabit.
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
    // Sıra kaynağın sırasına değil `rank` alanına bağlanır: podyum "1" yazan
    // kaideye listedeki İLK kaydı koyar, kaynak sırasız dönerse ad ile sıra
    // rakamı ayrışırdı (kurul 2026-10-20, MiniMax). Kararlı sıralama.
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byRank = a.$2.rank.compareTo(b.$2.rank);
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    entries = [for (final e in indexed) e.$2];

    Widget listOf(List<LeaderboardEntry> rows) => KeyedSubtree(
      key: const ValueKey('leaderboard-rank-list'),
      child: _RankListSurface(
        rows: [
          for (final e in rows)
            _RankRow(
              entry: e,
              isKu: ku,
              grouped: true,
              highlight: uid != null && e.playerId == uid,
              colorOverride: avatarColorOverrides[e.playerId],
              // Kişi kendini bildiremez. Liste eskiden kendi satırında da
              // bildir düğmesi çiziyordu, çünkü satırın kime ait olduğu
              // sorulmuyordu (2026-08-04).
              onReport: e.playerId == uid || e.playerId.isEmpty
                  ? null
                  : () => _openPlayerSheet(e),
            ),
        ],
      ),
    );
    // Lig bandı bayrakla kapalı (bkz. `kWeeklyLeagueEnabled`).
    final banner = kWeeklyLeagueEnabled && _period == LeaderboardPeriod.weekly
        ? _LeagueBanner(myRank: _myRank(entries), isKu: ku)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Eşik ekran enidir; gövde sayfa kenarı (2 × 16) kadar daha dardır.
        final wide = constraints.maxWidth + 2 * SahneSpace.page >= 720;
        final width = wide ? 640.0 : constraints.maxWidth;
        final podium =
            entries.length >= 3 && LeaderboardPodium.fits(context, width);

        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (banner != null) ...[
              banner,
              const SizedBox(height: SahneSpace.cardGap),
            ],
            // 2026-10-29 vay 2B (B8): lig başlığı — dönem, sıran ve üst
            // sıraya kalan puan (listedeki komşunun gerçek puanından).
            _arenaHeader(entries, ku),
            const SizedBox(height: SahneSpace.x4),
            if (podium) ...[
              LeaderboardPodium(
                key: const ValueKey('leaderboard-podium'),
                entries: entries.take(3).toList(growable: false),
                isKu: ku,
                selfId: uid,
                colorOverrides: avatarColorOverrides,
                onReport: _openPlayerSheet,
              ),
              if (entries.length > 3) ...[
                // 7. kurul: kürsü ile liste birbirinden kopuktu; kürsü
                // altında 24 boşluk + ince ayraç, sonra liste.
                const SizedBox(height: SahneSpace.x6),
                Divider(
                  key: const ValueKey('leaderboard-podium-divider'),
                  height: 1,
                  thickness: 1,
                  color: SahneTokens.of(context).line,
                ),
                const SizedBox(height: SahneSpace.x4),
                listOf(entries.skip(3).toList(growable: false)),
              ],
            ] else
              listOf(entries),
            // Listenin dibi boş kalmasın: tek turuncu "Yarışa başla" (oyuncu
            // listedeyken; değilse sabit şerit aynı eylemi taşır).
            if (_listsMe(entries)) ...[
              const SizedBox(height: SahneSpace.sectionTop),
              LeaderboardClimbCard(onStart: _startQuickRace),
            ],
          ],
        );
        if (!wide) return column;
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
  ///
  /// Satır, seçili dönemin (Gün/Hafta/Ay) puanını ve dönem içindeki sırasını
  /// gösterir — liste satırlarıyla aynı `get_leaderboard` süzgecinden gelir
  /// (`getMyLeaderboardRank`), toplam XP'den değil.
  ///
  /// Dönemde puanı yoksa (hiç oynamadı, ya da yalnız bot düellosu ve günün
  /// soruları oynadı) ve sorgu BAŞARILI döndüyse satırın yerinde dürüst
  /// bir boş durum durur: "bu sıralamada henüz yoksun" + yarışa başla.
  /// Sorgu okunamadıysa ya da oturum yoksa hiçbir şey iddia edilmez.
  Widget _buildMyRankRow(bool ku) {
    return FutureBuilder<_MyRankLookup>(
      future: _myRankFuture,
      builder: (context, snapshot) {
        final lookup = snapshot.data;
        if (lookup == null || lookup.failed) return const SizedBox.shrink();
        final me = lookup.entry;
        // Puan kapısı `_myRank` ile aynı sebeple burada da gerekli: aksi
        // hâlde banner susarken bu sabit satır sıfır puanla "#1" demeye
        // devam eder, yani yanlış iddia yer değiştirmiş olur. Dönem puanı
        // olmayan oyuncuya toplam XP de basılmaz (2026-09-30).
        if (me == null || me.rank <= 0 || me.totalScore <= 0) {
          if (widget.repository.currentUserId == null) {
            return const SizedBox.shrink();
          }
          return _PinnedMyRank(
            child: _NotRankedStrip(isKu: ku, onStart: _startQuickRace),
          );
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
    _myRankFuture = _loadMyRank();
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
        // buradaki kopya derinlemesine savunmadır. Engel listesi
        // okunamazsa (`loadBlockedPlayerIds` hatayı taşır) liste süzgeçsiz
        // gösterilmez: son başarılı liste kalır, yoksa hata durumu çizilir.
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

  /// Bir oyuncunun alt sayfasını açar: Arkadaş ekle + Bildir + Engelle.
  ///
  /// Bildirme sunucuda bildiren için engeli de kurar; bu yüzden liste
  /// bildirimden ve engelden sonra yeniden okunur. Karar (içeriğin
  /// kaldırılması) moderasyon tarafındadır; istemci karar vermez.
  ///
  /// 2026-10-23: sıralamadaki satır eskiden yalnız "bildir" sunuyordu;
  /// sıralamada karşılaşılan biri arkadaş eklenemiyordu. Giriş artık
  /// odalarla AYNI alt sayfa ([showPlayerModerationSheet]).
  Future<void> _openPlayerSheet(LeaderboardEntry entry) {
    return showPlayerModerationSheet(
      context: context,
      repository: widget.repository,
      playerId: entry.playerId,
      playerName: PlayerIdentity.resolveNameWithTag(
        entry.displayName,
        isKu: context.isKu,
        tag: entry.playerTag,
      ),
      onBlocked: _loadData,
      onReported: _loadData,
    );
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

  Widget _arenaHeader(List<LeaderboardEntry> entries, bool ku) {
    final uid = widget.repository.currentUserId;
    LeaderboardEntry? me;
    LeaderboardEntry? above;
    for (var i = 0; i < entries.length; i++) {
      if (uid != null && entries[i].playerId == uid) {
        me = entries[i];
        if (i > 0) above = entries[i - 1];
      }
    }
    final labels = ku ? ['Roj', 'Heft', 'Meh'] : ['Gün', 'Hafta', 'Ay'];
    final period = labels[_tabController.index.clamp(0, 2)];
    LeaderboardArenaHeader header(LeaderboardEntry? me, int? nextScore) {
      final ranked = me != null && me.rank > 0 && me.totalScore > 0;
      return LeaderboardArenaHeader(
        periodLabel: period,
        myRank: ranked ? me.rank : null,
        myScore: ranked ? me.totalScore : null,
        nextScore: ranked ? nextScore : null,
      );
    }

    if (me != null) return header(me, above?.totalScore);
    // İlk 10'da değilse sıra, sabit satırla AYNI sorgudan
    // (`getMyLeaderboardRank`); üstteki komşu listede görünüyorsa fark yazılır.
    return FutureBuilder<_MyRankLookup>(
      future: _myRankFuture,
      builder: (context, snap) {
        final mine = snap.data?.entry;
        int? next;
        if (mine != null) {
          for (final e in entries) {
            if (e.rank == mine.rank - 1) next = e.totalScore;
          }
        }
        return header(mine, next);
      },
    );
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

  void _openDailyTour() {
    Navigator.of(
      context,
    ).push(AppRoute.to(ContestScreen(repository: widget.repository)));
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
  Future<void> _pullRefresh() async {
    _loadData();
    // Göstergenin dönüşü yenilemeyle aynı Future'ı bekler; hata ekranın
    // kendi durumunda gösterilir, burada yutulur.
    try {
      await (_tabController.index == 3 ? _friendsFuture : _future);
    } catch (_) {}
  }

  Widget _page(
    BuildContext context,
    bool ku, {
    required Widget content,
    Widget? pinned,
  }) {
    final canPop = Navigator.of(context).canPop();
    final actions = _HeaderActions(
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
        onRefresh: _pullRefresh,
        children: top,
      );
    } else {
      scroll = SahneTabPage(
        controller: widget.scrollController,
        title: context.t(K.leaderboardTitle),
        titleEyebrow: context.secondLabel(K.leaderboardTitle),
        stats: [actions],
        onRefresh: _pullRefresh,
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
        if (fetched.isEmpty && RemoteAvailability.socialLockedWatch(context)) {
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
              onAction: widget.onOpenPlay ?? _startQuickRace,
              // Günün turunun kendi sıralaması var; burada sayılmadığı
              // için oraya götüren ikincil bağlantı (2026-10-29, X1).
              footer: SahneButton.text(
                key: const ValueKey('leaderboard-empty-daily-ranking'),
                label: context.t(K.dailyTourRankingAction),
                onPressed: _openDailyTour,
              ),
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
          // Satırın içeriği 2026-09-30'dan beri `getMyLeaderboardRank`: seçili
          // dönemin sıralaması, `get_leaderboard` ile aynı süzgeçten. Dönemde
          // puanı yoksa (listeden 0 puanla süzüldüyse ya da hiç oynamadıysa)
          // RPC boş döner ve sabit satır çizilmez; toplam XP basılmaz —
          // "0 puan" yerine XP'yi göstermek aynı ekranda iki ayrı sayıyı
          // aynı etiketle sunmak olurdu.
          pinned: !_listsMe(entries) ? _buildMyRankRow(ku) : null,
        );
      },
    );
  }
}

/// Oyuncunun dönem sırası sorgusunun sonucu. [failed]: sorgu okunamadı —
/// "sıralamada yoksun" ile "sıralama okunamadı" ayrı şeylerdir.
class _MyRankLookup {
  const _MyRankLookup(this.entry, {this.failed = false});

  final LeaderboardEntry? entry;
  final bool failed;
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

/// Sabit kendi-satırın dürüst boş durumu: bu dönemde puanı yok.
class _NotRankedStrip extends StatelessWidget {
  const _NotRankedStrip({required this.isKu, required this.onStart});

  final bool isKu;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Wrap(
      key: const ValueKey('leaderboard-not-ranked'),
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SahneSpace.x3,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(AppIcons.trophy, size: 20, color: t.tx2),
            ),
            const SizedBox(width: SahneSpace.x3),
            Flexible(
              child: Text(
                Tr.forKu(K.notRankedYet, isKu),
                style: SahneType.captionStrong.copyWith(color: t.tx),
              ),
            ),
          ],
        ),
        SahneButton.text(
          label: Tr.forKu(K.startRaceAction, isKu),
          onPressed: onStart,
        ),
      ],
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

/// Arkadaşlar: marka satırının sağında (A) ya da çubuğun sağında (B) duran
/// TEK 44'lük pahlı ikon düğmesi (48 dokunma alanı). Yenileme aşağı çekmeyle
/// (U10, 2026-10-28 tur 4: çubuğun sağında en çok bir eylem).
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onOpenFriends,
    required this.pendingRequestCount,
  });

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
/// çip ortak seçili biçimdir (`selFill`/`selLine`; kurul 3. tur: eskiden
/// çağrıdaki `role: gold` hiç uygulanmıyordu, belge yanlış söylüyordu). Kısa etiketler: 4 eşit çip 320 px'te de sığar.
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
  String get _name => PlayerIdentity.resolveNameWithTag(
    entry.displayName,
    isKu: isKu,
    tag: entry.playerTag,
  );

  // İkinci satır ("9 yarış · 6 seri") 2026-10-28 kurul K18 ile KALKTI: satır
  // yalnız sıra · avatar · ad · puan. Yarış/seri sayısı sunucu verisi
  // (`get_leaderboard`: bitmiş çevrimiçi oda sayısı) olarak modelde durur.

  @override
  Widget build(BuildContext context) {
    // Satır sıra, ad, oda/zincir ve puanı ayrı metinler olarak taşıyordu;
    // ekran okuyucu bunları bağlamsız dört parça hâlinde okuyordu. Tek
    // düğümde birleştirilir (2026-07-25 denetimi).
    final label = highlight
        ? (Tr.forKu(K.seninSiranPP, isKu, {
            'p0': '${entry.rank}',
            'p1': _name,
            'p2': groupThousands(entry.totalScore),
          }))
        : (Tr.forKu(K.pPPPuan, isKu, {
            'p0': '${entry.rank}',
            'p1': _name,
            'p2': groupThousands(entry.totalScore),
          }));

    if (highlight && !grouped) {
      return SahneListRow.me(
        key: const ValueKey('leaderboard-my-rank-row'),
        rank: entry.rank,
        title: _name,
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
      // Bildir/engelle yolu ekran okuyucuya duyurulur (App Store 1.2).
      hint: onReport == null ? null : Tr.forKu(K.reportTapHint, isKu),
      button: onReport != null,
      onTap: onReport,
      onLongPress: onReport,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // Satıra dokunmak da, uzun basmak da aynı alt sayfayı (Bildir /
        // Engelle) açar. Görünür ⋮ düğmesi 2026-10-28 kurul K18 ile kalktı.
        onTap: onReport,
        onLongPress: onReport,
        // Kendi satırın Zêr tonlu zemin taşır (2026-10-20 B): vurgu yalnız
        // rakam rengi değil, satırın kendisidir.
        child: highlight
            ? Padding(
                // İç boşluk: grup kırpıcısı yan kenarları keserdi.
                padding: const EdgeInsets.symmetric(
                  horizontal: SahneSpace.x1,
                  vertical: 2,
                ),
                child: DecoratedBox(
                  key: const ValueKey('leaderboard-me-outline'),
                  decoration: ShapeDecoration(
                    color: SahneTokens.of(context).goldTint,
                    // "Sen" satırı belirgin çerçeve (K18): renk tek başına
                    // değil, 2 px altın kenar + "Sen" rozeti.
                    shape: SahneShape.withSide(
                      SahneShape.m,
                      SahneTokens.of(context).goldTx,
                      width: 2,
                    ),
                  ),
                  // B8 (2026-10-29): 3 px altın yan işaret.
                  child: Stack(
                    children: [
                      _buildRow(context),
                      PositionedDirectional(
                        start: 4,
                        top: 10,
                        bottom: 10,
                        width: 3,
                        child: DecoratedBox(
                          key: const ValueKey('leaderboard-me-marker'),
                          decoration: ShapeDecoration(
                            color: SahneTokens.of(context).goldTx,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _buildRow(context),
      ),
    );
  }

  Widget _score() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 72),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SahneRowValue(groupThousands(entry.totalScore)),
    ),
  );

  Widget _buildRow(BuildContext context) {
    final t = SahneTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x1,
          SahneSpace.x4,
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
              showcaseTitle: entry.showcaseTitle,
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
                        // Rozet yazıyla büyür: eşik yazı ölçeğiyle birlikte
                        // artar (320 pt + %200'de ⋮ kalkınca ad alanı
                        // genişledi ve sabit 72 eşiği rozeti sığdırıp
                        // taşırıyordu).
                        final scale =
                            MediaQuery.textScalerOf(context).scale(16) / 16;
                        final showSelfTag =
                            highlight &&
                            constraints.maxWidth >= 72 * scale + 24;
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
                  PlayerAvatar.fromIdentity(
                    radius: 18,
                    identity: friend.friendAvatar,
                    fallbackColorHex: friend.friendAvatarColor,
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
                    PlayerIdentity.resolveNameWithTag(
                      friend.friendName,
                      isKu: isKu,
                      tag: friend.friendTag,
                    ),
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
                  groupThousands(friend.totalScore),
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
