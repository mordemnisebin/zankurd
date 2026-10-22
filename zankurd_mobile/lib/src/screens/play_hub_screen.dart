import 'home/room_invite_card.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/room.dart';
import '../providers/remote_availability.dart';
import '../widgets/sahne/sahne.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../services/analytics_service.dart';
import '../widgets/app_panel.dart';
import 'async_duel/async_duel_challenge_sheet.dart';
import 'async_duel/async_duel_inbox.dart';
import 'async_duel/async_duel_play_screen.dart';
import 'contest_screen.dart';
import 'friends_screen.dart';
import 'matchmaking_screen.dart';
import 'room_screen.dart';
import 'spin_wheel_screen.dart';
import 'tournament_screen.dart';
import 'home/home_rows.dart' show TabStatChips;
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class PlayHubScreen extends StatefulWidget {
  const PlayHubScreen({
    required this.repository,
    this.refreshSignal,
    this.asyncDuelEnabled = kAsyncDuelEnabled,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Kabuk, bir sayfa kapanıp Yarış sekmesine dönülünce bunu tetikler;
  /// "Düellolarım" listesi (sonuç görüldü mü, rakip oynadı mı) tazelenir.
  final Listenable? refreshSignal;

  /// Varsayılanı [kAsyncDuelEnabled]; testler ve ekran turu kartı bayrak
  /// kapalıyken de açabilsin diye parametredir.
  final bool asyncDuelEnabled;

  @override
  State<PlayHubScreen> createState() => _PlayHubScreenState();
}

class _PlayHubScreenState extends State<PlayHubScreen> {
  bool _dailyLoading = false;
  bool _roomActionLoading = false;
  bool _moreOpen = false;

  /// Düello akışından (oyun → sonuç) dönünce "Düellolarım"ı tazeler.
  /// Kabuğun [PlayHubScreen.refreshSignal]iyle birleştirilir; ekran kabuk
  /// dışında (testte) kullanıldığında da liste güncel kalır.
  final ValueNotifier<int> _asyncDuelInboxRefresh = ValueNotifier<int>(0);
  late final Listenable _asyncDuelInboxSignal = Listenable.merge([
    widget.refreshSignal,
    _asyncDuelInboxRefresh,
  ]);

  /// Sunucuda meydan okuma RPC'leri var mı (sonuç gelene dek `false`:
  /// giriş noktası çizilip sonra kaybolmasın).
  bool _challengeAvailable = false;

  /// Bekleyen arkadaşlık isteği sayısı; "Arkadaşlar" satırında rozet olur.
  int _pendingRequests = 0;

  /// Rozet bir iyileştirmedir: başarısızlık sessizdir, satır yine açılır.
  Future<void> _refreshPendingRequests() async {
    try {
      final requests = await widget.repository.loadPendingFriendRequests();
      if (!mounted || requests.length == _pendingRequests) return;
      setState(() => _pendingRequests = requests.length);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'play_hub_pending_requests');
    }
  }

  Future<void> _openFriends() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(FriendsScreen(repository: widget.repository)));
    if (!mounted) return;
    await _refreshPendingRequests();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPendingRequests());
    if (widget.asyncDuelEnabled) {
      unawaited(
        asyncDuelChallengeAvailable(widget.repository).then((available) {
          if (mounted && available) setState(() => _challengeAvailable = true);
        }),
      );
    }
  }

  /// Oda kodu alanının denetleyicisi. Ömrü sayfaya değil EKRANA bağlıdır.
  ///
  /// Sayfaya bağlıyken (her açılışta `TextEditingController()`, kapanışta
  /// `whenComplete` + `addPostFrameCallback` ile `dispose`) kodla katılma
  /// yolunda uygulama hata ekranına düşüyordu: katılma başarılı olunca
  /// sayfa kapanır ve hemen ardından oda ekranı itilir; sayfanın kapanış
  /// animasyonu ise sürmeye devam eder. `TextField`in imleç animasyonu
  /// denetleyiciyi `listenable` olarak tutar ve o animasyon bir sonraki
  /// karede `addListener` çağırır — denetleyici bir kare önce atılmıştır.
  /// Tek kare beklemek yetmez, çünkü kapanış animasyonu onlarca kare sürer.
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    _asyncDuelInboxRefresh.dispose();
    super.dispose();
  }

  Future<void> _openDailyQuiz() async {
    setState(() => _dailyLoading = true);
    try {
      // Her zaman ContestScreen'e yönlendir; etkinlik yoksa ekran kendisi
      // boş durum mesajı gösterir ("Hîn çalakî tune"). Eskiden contest
      // null olduğunda sessizce generic quiz başlatılıyordu — bu, kullanıcının
      // günlük ilerleme etkinliğini açtığını sanmasına yol açıyordu.
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(AppRoute.to(ContestScreen(repository: widget.repository)));
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _createOnlineRoom() async {
    if (_roomActionLoading) return;

    List<String> availableCategories = widget.repository.categories;
    try {
      final serverCats = await widget.repository.loadMatchmakingCategories();
      if (serverCats.isNotEmpty) availableCategories = serverCats;
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'play_hub_load_matchmaking_categories',
      );
    }

    int coinBalance = 0;
    try {
      coinBalance = await widget.repository.loadCoinBalance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'play_hub_load_coin_balance');
    }

    if (!mounted) return;

    final config = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CustomRoomBottomSheet(
        availableCategories: availableCategories,
        coinBalance: coinBalance,
      ),
    );

    if (config == null || !mounted) return;

    // Oyuncu seçtiği katılım ücretine yetmediğini görüp "Jeton kazan"ı
    // seçtiyse oda kurulmaz; jeton kazanılan yere (günlük çark) gidilir.
    if (config is _EarnCoinsRequest) {
      await _openSpinWheel();
      return;
    }
    if (config is! _CustomRoomConfig) return;

    setState(() => _roomActionLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom(
        category: config.category,
        secondsPerQuestion: config.duration,
        questionCount: config.questionCount,
        entryFee: config.entryFee,
        maxPlayers: config.maxPlayers,
      );
      if (!mounted) return;
      AnalyticsService.instance.logActivationStep('room_created');
      _openRoom(room);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'play hub create room failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.roomOpenFailed))));
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  Future<void> _openSpinWheel() async {
    await Navigator.of(context).push(
      AppRoute<void>(page: SpinWheelScreen(repository: widget.repository)),
    );
  }

  void _openRoom(GameRoom room) {
    Navigator.of(context).push(
      AppRoute.to(RoomScreen(repository: widget.repository, initialRoom: room)),
    );
  }

  Future<void> _showJoinSheet() async {
    final controller = _joinCodeController..clear();
    final formKey = GlobalKey<FormState>();
    var joining = false;
    final inputTextStyle = SahneType.bodyStrong.copyWith(
      color: SahneTokens.of(context).tx,
      letterSpacing: 1.4,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        // Klavye ve erişilebilir yazı ölçeği aynı anda açıkken içerik sabit
        // bir Column'a sığmayabilir. Sheet'i kaydırılabilir tutarak alanı ya
        // da doğrulama mesajını erişilemez bırakma.
        //
        // Klavye payı kaydırma alanının DIŞINDADIR: içeride (dolgu olarak)
        // durunca görünüm alanı klavyenin arkasına uzanıyordu ve kaydırma
        // doğrulama mesajını klavyenin altına bırakıyordu (320 px,
        // Kurmancî, 2026-09-29).
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: SahneSpace.page,
              right: SahneSpace.page,
              bottom: SahneSpace.page,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AppPanel(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(K.joinRoomTitle),
                      style: SahneType.headline.copyWith(
                        color: SahneTokens.of(context).tx,
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x4),
                    SahneField(
                      key: const ValueKey('play-hub-join-room-code-field'),
                      label: context.t(K.roomCode),
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      // Yeni kod 6 rakamdır: sayı klavyesi açılır. Eski `ZK-…`
                      // kodu ya da bağlantı yapıştırılırsa biçimlendirici
                      // yine kabul eder (klavye türü yapıştırmayı engellemez).
                      keyboardType: TextInputType.number,
                      // Yazarken gösterim biçimine çeker: "482913" alanda
                      // "482 913" görünür; eski kodlarda kanonik `ZK-…`.
                      inputFormatters: const [_RoomCodeInputFormatter()],
                      inputTextStyle: inputTextStyle,
                      prefixIcon: AppIcons.doorOpen,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.t(K.roomCodeRequired);
                        }
                        if (!isSupportedRoomCode(value)) {
                          return context.t(K.roomCodeInvalid);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: SahneSpace.x4),
                    // Katıl beklerken düğme kilitlenir ve dönen gösterge
                    // görünür: 1–2 sn hiçbir geri bildirim yoktu, oyuncu
                    // tekrar dokunuyordu (Android turu, 2026-10-22).
                    StatefulBuilder(
                      builder: (btnCtx, setBtn) => SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('play-hub-join-submit'),
                          onPressed: joining
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setBtn(() => joining = true);
                                  try {
                                    final room = await widget.repository
                                        .joinOnlineRoom(
                                          normalizeRoomCode(controller.text),
                                        );
                                    if (!sheetCtx.mounted) return;
                                    AnalyticsService.instance.logActivationStep(
                                      'room_joined',
                                    );
                                    Navigator.of(sheetCtx).pop();
                                    if (mounted) _openRoom(room);
                                  } catch (error, stack) {
                                    ErrorReporter.record(
                                      error,
                                      stack,
                                      reason: 'play hub join room failed',
                                    );
                                    if (!sheetCtx.mounted) return;
                                    Navigator.of(sheetCtx).pop();
                                    if (!mounted) return;
                                    // Ücretli odaya jetonu yetmeyen oyuncuya "tekrar
                                    // dene" demek yalandı: tekrar denemek sonucu
                                    // değiştirmez. Mesajın yanında gerçek sonraki
                                    // adım (jeton kazan) durur.
                                    final short =
                                        error is RoomJoinException &&
                                        error.reason ==
                                            RoomJoinFailureReason
                                                .insufficientCoins;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t(joinRoomErrorKey(error)),
                                        ),
                                        action: short
                                            ? SnackBarAction(
                                                label: context.t(K.earnCoins),
                                                onPressed: _openSpinWheel,
                                              )
                                            : null,
                                      ),
                                    );
                                  }
                                },
                          icon: joining
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(AppIcons.rightToBracket),
                          label: Text(context.t(K.joinAction)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Kilitliyken (sunucuya ulaşılamıyor) pasif giriş dokunulunca kısa bir
  /// geri bildirim verir: sessiz ölü düğme kalmaz. 2026-09-30 simülatör.
  ///
  /// Dokunuş AYNI ZAMANDA en güçlü "tekrar dene" işaretidir: kullanıcı
  /// sunucuya ulaşmak istiyor. Arkadaki geri çekilmeyi (60 sn'ye kadar)
  /// beklemeden hemen yokla; başarısız olursa kilit yerinde kalır, geri
  /// çekilme kendi takviminde sürer.
  void _notifyLocked() {
    final availability = RemoteAvailability.read(context);
    if (availability != null) unawaited(availability.retryNow());
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.t(K.serverUnreachableTitle))),
    );
  }

  /// Pasif girişi dokunuşu yakalayan, ekran okuyucuya EYLEM eklemeyen bir
  /// sarmalayıcıyla sarar (giriş `enabled: false` kalır).
  Widget _lockedTap(bool locked, Widget child) => locked
      ? GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _notifyLocked,
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    // `watch`: arka plan geriçekilmesi uzak başlatmayı sonlandırdığında
    // düğmeler anında açılsın; `socialLockedIn` (dinlemeyen) yalnız bir
    // sonraki tesadüfi çizimde açardı.
    final locked = RemoteAvailability.socialLockedWatch(context);

    // 2026-09-29 Şahnê A iskeleti: marka satırı → "Yarış" → alt başlık →
    // tek birincil eylem (hızlı düello sahne kartı) → iki adlandırılmış
    // bölüm. Ekran eskiden eşit ağırlıkta satırlardan oluşan bir
    // menü gibi duruyordu; yeni kullanıcı hangisinin "asıl oyun" olduğunu
    // seçemiyordu (2026-07-25 canlı denetimi). Renk rol taşır: yarış
    // kimliği Boyax (sahne kartı degradesi ve etkinlik satırlarının ikon
    // karosu), turuncu yalnız "Rakip bul".
    // 2026-09-29 doğallık (K7): "Oda kur" ve "Kodla katıl" iki satırlık
    // bir liste grubuydu; her satırın başında ikon karosu, altında ikinci
    // bir açıklama, sonunda ok — iki düğmelik bir iş için şablon bir menü.
    // Artık bölüm başlığının altında tek açıklama satırı ve yan yana iki
    // ikincil düğme. Kodun biçimi katılma sayfasındaki alan ve doğrulama
    // mesajında yazılı. Kilitliyken açıklama satırı DEĞİŞMEZ (2026-09-30: sunucu
    // durumunu üstteki şerit söyler).
    final createRoom = KeyedSubtree(
      key: const ValueKey('play-hub-create-room'),
      child: _lockedTap(
        locked,
        SahneButton.tonal(
          tint: SahneTokens.of(context).nilTint,
          foreground: SahneTokens.of(context).nilTx,
          icon: AppIcons.peopleGroup,
          label: context.t(K.createRoom),
          // Anahtarın kendi ekran okuyucu düğümü olsun (düğme + dokunma).
          semanticLabel: context.t(K.createRoom),
          loading: _roomActionLoading,
          expand: true,
          onPressed: locked ? null : _createOnlineRoom,
        ),
      ),
    );
    final joinRoom = KeyedSubtree(
      key: const ValueKey('play-hub-join-room'),
      child: _lockedTap(
        locked,
        SahneButton.tonal(
          tint: SahneTokens.of(context).nilTint,
          foreground: SahneTokens.of(context).nilTx,
          icon: AppIcons.hashtag,
          label: context.t(K.joinByCode),
          semanticLabel: context.t(K.joinByCode),
          expand: true,
          onPressed: locked ? null : _showJoinSheet,
        ),
      ),
    );

    final dailyContest = _lockedTap(
      locked,
      SahneModeTile(
        key: const ValueKey('play-hub-daily-contest'),
        icon: AppIcons.calendarDays,
        role: SahneRole.race,
        title: context.t(K.dailyContest),
        subtitle: context.t(K.tenQuestions),
        loading: _dailyLoading,
        onTap: locked || _dailyLoading ? null : _openDailyQuiz,
        semanticLabel:
            '${context.t(K.dailyContest)}. ${context.t(K.tenQuestions)}',
      ),
    );

    // Çark: günlük jeton kazanma yeri. Eskiden yalnız mağazadan ve "jeton
    // yetmedi" iletisinden bulunuyordu; Yarış sekmesinde tek dokunuşta durur.
    final wheelTile = SahneModeTile(
      key: const ValueKey('play-hub-spin-wheel'),
      icon: AppIcons.dice,
      role: SahneRole.gold,
      title: context.t(K.wheelTitle),
      subtitle: context.t(K.wheelOncePerDay),
      onTap: _openSpinWheel,
    );

    // Arkadaşlar: istek göndermek/yanıtlamak için tek dokunuş (Nîl, sosyal).
    // Sıralama ekranındaki yalnız-simge düğmesi de durur.
    final friendsRow = _lockedTap(
      locked,
      SahneListRow.icon(
        key: const ValueKey('play-hub-friends'),
        icon: AppIcons.userPlus,
        role: SahneRole.social,
        title: context.t(K.friendsScreen),
        trailing: _pendingRequests > 0 && !locked
            ? SahneBadge(label: '$_pendingRequests', tone: SahneBadgeTone.learn)
            : null,
        chevron: !locked && _pendingRequests == 0,
        enabled: !locked,
        onTap: locked ? null : _openFriends,
        semanticLabel: _pendingRequests > 0
            ? context.t(K.friendRequestsPendingA11y, {
                'count': '$_pendingRequests',
              })
            : context.t(K.friendsScreen),
      ),
    );

    return SahneTabPage(
      title: context.t(K.playTitle),
      // İki dilli etiket: öbür dilde aynı anahtar ("Pêşbirk" / "Yarış").
      titleEyebrow: context.secondLabel(K.playTitle),
      stats: [
        TabStatChips(
          repository: widget.repository,
          refreshSignal: widget.refreshSignal,
        ),
      ],
      children: [
        if (!locked)
          RoomInviteCard(
            repository: widget.repository,
            refreshSignal: widget.refreshSignal,
            topGap: false,
          ),
        if (widget.asyncDuelEnabled && !locked)
          AsyncDuelTurnSection(
            repository: widget.repository,
            refreshSignal: _asyncDuelInboxSignal,
          ),
        _QuickDuelHero(
          repository: widget.repository,
          onLockedTap: locked ? _notifyLocked : null,
          onTap: locked
              ? null
              : () {
                  Navigator.of(context).push(
                    AppRoute.to(
                      MatchmakingScreen(repository: widget.repository),
                    ),
                  );
                },
        ),
        // Sırayla düello (async 1v1): rakibin aynı anda çevrimiçi
        // olmasını istemez — oyuncu şimdi oynar, rakip kendi
        // zamanında. Sunucu göçü uygulanana dek bayrakla kapalı; kapalıyken
        // "Etkinlikler" grubunda "Yakında" satırı olarak durur.
        // Tasarım kurulu 2026-10-22 (ChatGPT, Gemini 3.1 Pro, Claude Opus;
        // rakip kıyası TRT Bil Bakalım, Trivia Crack, Kahoot): üç model de
        // liste satırlarının büyük renkli mod kartlarına dönmesini istedi.
        // Hızlı düello kahramanı üstte kalır; altında 2×2 mod kartı:
        // Sırayla düello (Boyax), Arkadaşına meydan oku (Nîl), Günün turu
        // (Boyax), Günün çarkı (Zêr). Oda kur / Kodla katıl ve Arkadaşlar
        // aşağıda kompakt kalır. Turuncu yalnız "Rakip bul"da.
        const SizedBox(height: SahneSpace.cardGap),
        SahneModeGrid(
          children: [
            if (widget.asyncDuelEnabled)
              _lockedTap(
                locked,
                SahneModeTile(
                  key: const ValueKey('play-hub-async-duel'),
                  icon: AppIcons.hourglass,
                  role: SahneRole.race,
                  title: context.t(K.asyncDuel),
                  subtitle: context.t(K.asyncDuelSub),
                  onTap: locked
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            AppRoute.to(
                              AsyncDuelPlayScreen(
                                repository: widget.repository,
                              ),
                            ),
                          );
                          if (mounted) _asyncDuelInboxRefresh.value++;
                        },
                ),
              ),
            if (widget.asyncDuelEnabled && _challengeAvailable)
              _lockedTap(
                locked,
                SahneModeTile(
                  key: const ValueKey('play-hub-async-duel-challenge'),
                  icon: AppIcons.peopleGroup,
                  // Arkadaşa meydan okumak sosyal moddur: Nîl.
                  role: SahneRole.social,
                  title: context.t(K.challengeEntry),
                  onTap: locked
                      ? null
                      : () async {
                          await showAsyncDuelChallengeSheet(
                            context,
                            widget.repository,
                          );
                          if (mounted) _asyncDuelInboxRefresh.value++;
                        },
                ),
              ),
            dailyContest,
            wheelTile,
          ],
        ),
        // Kurul 2026-10-20 (GLM, Nemotron): sayfa yarı boş duruyordu. Yeni
        // öğe eklenmedi; "Günün soruları" zaten görünür. Gruplar arası
        // dikey ritim bir kademe açıldı (cardGap → x5) ki içerik yukarıya
        // yığılmış değil, sayfaya yayılmış okunsun.
        const SizedBox(height: SahneSpace.x5),
        _RoomActions(createRoom: createRoom, joinRoom: joinRoom),
        const SizedBox(height: SahneSpace.x3),
        SahneListGroup(children: [friendsRow]),
        if (!widget.asyncDuelEnabled || kTournamentEnabled) ...[
          const SizedBox(height: SahneSpace.x5),
          SahneListGroup(
            children: [
              if (!widget.asyncDuelEnabled)
                SahneListRow.icon(
                  key: const ValueKey('play-hub-async-duel-soon'),
                  icon: AppIcons.shuffle,
                  title: context.t(K.asyncDuel),
                  enabled: false,
                  trailing: SahneBadge(
                    label: context.t(K.yakinda),
                    tone: SahneBadgeTone.soon,
                  ),
                ),
              // Turnuva kalabalık bir kitle bekliyor; o kitle gelene dek
              // bayrakla kapalı (bkz. `kTournamentEnabled`). Açıkken de ilk
              // bakışta yok: benzer uygulamalarda indirme/tekrar sebebi "şimdi
              // oyna" + günlük dönüş; eleme modu ikinci katman.
              if (kTournamentEnabled) ...[
                if (!_moreOpen)
                  SahneListRow.icon(
                    key: const ValueKey('play-hub-more'),
                    icon: AppIcons.chevronDown,
                    title: context.t(K.playMore),
                    subtitle: context.t(K.playMoreSub),
                    semanticLabel:
                        '${context.t(K.playMore)}. ${context.t(K.playMoreSub)}',
                    onTap: () => setState(() => _moreOpen = true),
                  ),
                if (_moreOpen)
                  _lockedTap(
                    locked,
                    SahneListRow.icon(
                      key: const ValueKey('play-hub-tournament'),
                      icon: AppIcons.trophy,
                      role: SahneRole.gold,
                      title: context.t(K.tournament),
                      subtitle: context.t(K.tournamentSub),
                      chevron: !locked,
                      enabled: !locked,
                      semanticLabel:
                          '${context.t(K.tournament)}. '
                          '${context.t(K.tournamentSub)}',
                      onTap: locked
                          ? null
                          : () {
                              Navigator.of(context).push(
                                AppRoute.to(
                                  TournamentScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
              ],
            ],
          ),
        ],
        // 'Bu hafta' kartı düellolarım kutusunun ALTINDA durur: üstte olunca
        // yüksekliği kutuyu tembel listede ekran dışına itiyordu.
        if (widget.asyncDuelEnabled && !locked)
          AsyncDuelInboxSection(
            repository: widget.repository,
            refreshSignal: _asyncDuelInboxSignal,
            excludeNeedsAttention: true,
          ),
        if (!locked) ...[
          const SizedBox(height: SahneSpace.x5),
          ThisWeekCard(
            repository: widget.repository,
            refreshSignal: widget.refreshSignal,
            onStart: () => Navigator.of(context).push(
              AppRoute.to(MatchmakingScreen(repository: widget.repository)),
            ),
          ),
        ],
        // Mağaza satırı buradan kaldırıldı: aynı ekrana Yarış
        // sekmesinden, profilden ve kendi rotasından olmak üzere üç
        // ayrı giriş vardı ve "burası neresi?" hissi yaratıyordu
        // (2026-07-25 canlı denetimi). Tek ev profildeki HESAP bölümü.
      ],
    );
  }
}

/// Arkadaşlarla oynamanın iki yolu: tek açıklama satırı + yan yana iki
/// ikincil düğme. Sığmazlarsa (dar ekran, büyük yazı) alt alta dizilir;
/// "Kodla katıl" Kurmancîde ("Bi kodê têkeve") yarım genişliğe iki
/// satırdan fazla düşmesin diye eşik yazı ölçeğine de bakar.
class _RoomActions extends StatelessWidget {
  const _RoomActions({required this.createRoom, required this.joinRoom});

  final Widget createRoom;
  final Widget joinRoom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
            if (constraints.maxWidth < 320 || largeText) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  createRoom,
                  const SizedBox(height: SahneSpace.x2),
                  joinRoom,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: createRoom),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(child: joinRoom),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ekranın tek birincil eylemi — sakin bir yüzey kartı.
///
/// 2026-10-19 sadeleşme (ikinci tur): kart Boyax sahne degradeli gece
/// kartıydı; ana ekranın "Günün dersi" kartı sadeleşince Yarış sekmesinin
/// bu kartı ekranın en doygun, en büyük lekesi kalmıştı. Artık gündüz
/// beyaz / gece Perde yüzey kartı; kimliği yarış tonundaki üst etiket
/// taşır, turuncu yalnız "Rakip bul". Anahtarlar ve ekran okuyucu düğümü
/// değişmedi.
///
/// 2026-09-29 Şahnê: düello sahne kartı (Boyax sahne degradesi, gündüzde de
/// gece). Üstte "Hızlı düello" etiketi, manşet ve bilgi satırı; altında tam
/// genişlik TEK birincil düğme "Rakip bul" (Agir, koyu metin). Eski ışık
/// hüzmesi + konfeti ressamı, yeşil degrade ve beyaz daireler kalktı.
///
/// 2026-09-29 doğallık (K5, K8): sağdaki VS amblemi (oyuncu elması + "vs" +
/// "?" elması) kalktı. Hiçbir şey söylemeyen bir süstü ve elması üçüncü bir
/// anlama çekiyordu; yerine oyuncunun karar verirken bakacağı somut bilgi
/// geldi: kaç soru, ne kadar sürer ("10 soru · ~2 dakika"). Rakibin
/// seviyesi manşette ("Seviyene yakın rakip"). Üst etiket büyük harf
/// değil, kalın açıklama.
///
/// Kart `SahneStageCard.duel` ile aynı yerleşimi kurar ama düğmeyi kendisi
/// çizer: `play-hub-quick-duel-cta` anahtarı ve kartın tek ekran okuyucu
/// düğümü ("Hızlı düello. Rakip bul") bu ekranın sözleşmesidir.
///
/// Kilitliyken (sunucuya hiç ulaşılamıyor) düğme görsel olarak pasifleşir
/// (2026-09-27 simülatör turu: dokununca hiçbir şey olmayan canlı turuncu
/// düğme "bozuk" sanılıyordu). 2026-09-30 simülatör: manşet ve alt satırlar
/// artık "Sunucuya ulaşılamadı" demez; bunu üstteki şerit tek başına söyler
/// (eskiden aynı cümle Yarış sekmesinde dört kez yazılıyordu).
class _QuickDuelHero extends StatefulWidget {
  const _QuickDuelHero({
    required this.onTap,
    required this.repository,
    this.onLockedTap,
  });

  final VoidCallback? onTap;
  final ZanKurdRepository repository;

  /// Kilitliyken düğmeye dokunulunca çağrılır (geri bildirim); düğme yine
  /// pasif görünür ve ekran okuyucuya tıklanabilir bildirilmez.
  final VoidCallback? onLockedTap;

  @override
  State<_QuickDuelHero> createState() => _QuickDuelHeroState();
}

class _QuickDuelHeroState extends State<_QuickDuelHero> {
  /// Oyuncunun adının baş harfleri ("SK" göstergesi); ad yoksa kişi ikonu.
  String? _initials;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitials());
  }

  Future<void> _loadInitials() async {
    try {
      final name = (await widget.repository.getProfileName()).trim();
      if (!mounted || name.isEmpty) return;
      final parts = name
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      final letters = parts.length >= 2
          ? '${parts.first.characters.first}${parts.last.characters.first}'
          : name.characters.take(2).toString();
      setState(
        () => _initials = SahneType.upperFor(letters, isKu: context.isKu),
      );
    } catch (error, stack) {
      // Ad okunamazsa kişi ikonu kalır; gösterge süstür, akış değil.
      ErrorReporter.record(error, stack, reason: 'play_hub_vs_initials');
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final enabled = onTap != null;
    final title = context.t(K.quickDuelHeadline);
    // Eşleşme odası 10 soruyla kurulur (`MatchmakingScreen`, `limit: 10`).
    // Soru sayısı ve süre ayrı dizgelerdir; ayraç çeviriye girmez.
    final meta =
        '${context.t(K.tenQuestions)} · ${context.t(K.quickDuelDuration)}';

    return Semantics(
      key: const ValueKey('play-hub-quick-duel'),
      container: true,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: '${context.t(K.quickDuel)}. ${context.t(K.findOpponent)}',
      onTap: onTap,
      // Boyax DOLU kahraman (2026-10-20 renk ve canlılık): yarış kimliği tek
      // bakışta. Sadeleştirme beyaz bir karta indirmişti; Boyax ekranda
      // neredeyse görünmüyordu.
      child: SahneRaceHeroSurface(
        kilimKey: const ValueKey('play-hub-kilim-strip'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.x4,
            SahneSpace.x4,
            SahneSpace.x4,
            SahneSpace.x3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(K.quickDuel),
                style: SahneType.captionStrong.copyWith(
                  color: SahneVivid.heroEyebrow,
                ),
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                title,
                style: SahneType.headline.copyWith(color: SahneVivid.onFill),
              ),
              const SizedBox(height: SahneSpace.x2),
              LayoutBuilder(
                builder: (context, c) {
                  // Dar ekran / büyük yazıda "SK vs ?" göstergesi çizilmez
                  // (süs; metin ve düğme önceliklidir).
                  final showVs =
                      c.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(16) < 22;
                  // Spacer yok: Flexible + Spacer genişliği yarı yarıya
                  // bölüyordu ve çip yazısı FittedBox'ta ~10 pt'ye
                  // küçülüyordu; çip önce kendi doğal genişliğini alır.
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: DecoratedBox(
                          decoration: const ShapeDecoration(
                            color: SahneVivid.glass,
                            shape: SahneShape.m,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SahneSpace.x3,
                              vertical: SahneSpace.x1,
                            ),
                            // Tek satır: sığmazsa yazı küçülür, sarmaz
                            // ("10 soru · ~2 dakika").
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                meta,
                                key: const ValueKey('play-hub-quick-duel-meta'),
                                maxLines: 1,
                                style: SahneType.captionStrong.copyWith(
                                  color: SahneVivid.onFill,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showVs) ...[
                        const SizedBox(width: SahneSpace.x3),
                        SahneVsIndicator(initials: _initials),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: SahneSpace.x4),
              KeyedSubtree(
                key: const ValueKey('play-hub-quick-duel-cta'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: onTap == null ? widget.onLockedTap : null,
                  child: SahneButton.primary(
                    label: context.t(K.findOpponent),
                    onPressed: onTap,
                    expand: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bu hafta" kartı: YALNIZ gerçek veri — `getMyLeaderboardRank(weekly)`
/// (haftalık lig sırası, hafta puanı, hafta içinde biten çevrimiçi yarış
/// sayısı). Sunucuda "bu hafta kazanılan düello" sayısı yoktur; uydurulmaz.
/// Değeri 0 olan hücre (puan, yarış) gösterilmez. Oyuncunun haftalık
/// kaydı yoksa sayı yerine kısa bir çağrı ve "Yarışa başla" durur.
class ThisWeekCard extends StatefulWidget {
  const ThisWeekCard({
    super.key,
    required this.repository,
    required this.onStart,
    this.refreshSignal,
  });

  final ZanKurdRepository repository;
  final VoidCallback onStart;
  final Listenable? refreshSignal;

  @override
  State<ThisWeekCard> createState() => _ThisWeekCardState();
}

class _ThisWeekCardState extends State<ThisWeekCard> {
  bool _loaded = false;
  LeaderboardEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    LeaderboardEntry? entry;
    try {
      entry = await widget.repository.getMyLeaderboardRank(
        LeaderboardPeriod.weekly,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'play_hub_this_week');
    }
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Yüklenene dek hiçbir şey çizilmez: boş durum parlayıp kaybolmasın.
    if (!_loaded) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final entry = _entry;
    final hasData = entry != null && entry.rank > 0;
    final cells = <(String, String)>[
      if (hasData) (context.t(K.statRank), '#${entry.rank}'),
      if (hasData && entry.totalScore > 0)
        (context.t(K.scoreWord), '${entry.totalScore}'),
      if (hasData && entry.roomsPlayed > 0)
        (context.t(K.raceWord), '${entry.roomsPlayed}'),
    ];
    final night = Theme.of(context).brightness == Brightness.dark;
    return SahneSurfaceCard(
      key: const ValueKey('play-hub-this-week'),
      child: hasData
          // Zêr sıra bloğu + renkli ikonlu sayılar (2026-10-20): sıra altın,
          // puan şimşek (Zêr tonu), yarış kupa (Boyax tonu).
          ? IntrinsicHeight(
              key: const ValueKey('play-hub-this-week-stats'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: SahneGoldBlock(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.t(K.thisWeek),
                            style: SahneType.captionStrong.copyWith(
                              color: t.goldTx,
                            ),
                          ),
                          Text(
                            cells.first.$2,
                            style: SahneType.title.copyWith(color: t.goldTx),
                          ),
                          Text(
                            cells.first.$1,
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 1; i < cells.length; i++) ...[
                          if (i > 1) const SizedBox(height: SahneSpace.x2),
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: i == 1 ? t.goldTint : t.raceTint,
                                  shape: SahneShape.m,
                                ),
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: Icon(
                                    i == 1 ? AppIcons.bolt : AppIcons.trophy,
                                    size: 18,
                                    color: i == 1
                                        ? t.goldTx
                                        : night
                                        ? t.raceTx
                                        : t.race,
                                  ),
                                ),
                              ),
                              const SizedBox(width: SahneSpace.x2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cells[i].$2,
                                      style: SahneType.bodyStrong.copyWith(
                                        color: t.tx,
                                      ),
                                    ),
                                    Text(
                                      cells[i].$1,
                                      style: SahneType.caption.copyWith(
                                        color: t.tx2,
                                      ),
                                    ),
                                  ],
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
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t(K.thisWeek),
                  style: SahneType.captionStrong.copyWith(color: t.goldTx),
                ),
                const SizedBox(height: SahneSpace.x2),
                Text(
                  context.t(K.buHaftaYarisLige),
                  key: const ValueKey('play-hub-this-week-empty'),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
                SahneButton.text(
                  key: const ValueKey('play-hub-this-week-start'),
                  label: context.t(K.startRaceAction),
                  onPressed: widget.onStart,
                ),
              ],
            ),
    );
  }
}

/// Oda katılma hatasını gösterilecek K.* anahtarına çevirir.
///
/// Eskiden `joinOnlineRoom`ın her hatası (dolu oda, kullanıcı zaten başka
/// bir odada, ağ hatası...) TEK `K.roomNotFound` metnine iniyordu — oda
/// gerçekten var olsa bile kullanıcı hep "bulunamadı" görüyordu. Sunucu
/// tarafının ayırt ettiği sebep artık `RoomJoinException.reason` ile
/// buraya kadar taşınıyor; tanınmayan/ağ kaynaklı hatalar (RoomJoinException
/// DEĞİLSE) kasıtlı olarak "bulunamadı" değil, jenerik `K.roomJoinFailed`
/// döner — yanlış bir kesinlik iddia etmez (2026-08-14 denetimi).
String joinRoomErrorKey(Object error) {
  if (error is! RoomJoinException) return K.roomJoinFailed;
  return switch (error.reason) {
    RoomJoinFailureReason.notFound => K.roomNotFound,
    RoomJoinFailureReason.full => K.roomFull,
    RoomJoinFailureReason.alreadyInAnotherRoom => K.roomAlreadyInAnotherRoom,
    RoomJoinFailureReason.insufficientCoins => K.insufficientCoins,
    RoomJoinFailureReason.tooManyAttempts => K.roomCodeTooManyAttempts,
    RoomJoinFailureReason.unknown => K.roomJoinFailed,
  };
}

/// Oda kodu alanını yazılırken kanonik biçime çeker.
///
/// Kullanıcının gördüğü kod `ZK-ABCDEF0123`; elle yazarken tireyi atlamak,
/// küçük harf kullanmak ya da araya boşluk koymak olağandır. Biçimlendirici
/// olmadan bunların hepsi "oda bulunamadı" ile dönüyordu.
class _RoomCodeInputFormatter extends TextInputFormatter {
  const _RoomCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = formatRoomCodeInput(newValue.text);
    // İmleç sona alınır: kod kısa ve tek parça yazılır, ortasına dönüp
    // düzenleme yapmak beklenen kullanım değil. Metin değişmediyse
    // değeri olduğu gibi bırak, yoksa her tuşta imleç zıplar.
    if (normalized == newValue.text) return newValue;
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

/// Oda kurma sayfasından dönen "jeton kazanmaya git" isteği: katılım
/// ücretine yetmeyen oyuncuya, ölü bir düğme yerine gerçek sonraki adım.
class _EarnCoinsRequest {
  const _EarnCoinsRequest();
}

class _CustomRoomConfig {
  const _CustomRoomConfig({
    /// Seçilen kategoriler tek dizgede: Karışık = `Tevlihev`, tek kategori =
    /// adı, çoklu = adlar `, ` ile (sunucudaki `room_category_label` biçimi).
    required this.category,
    required this.duration,
    required this.questionCount,
    required this.entryFee,
    required this.maxPlayers,
  });

  final String category;
  final int duration;
  final int questionCount;
  final int entryFee;

  /// Oda kapasitesi (2 = bugünkü iki kişilik oda; > 2 = kalabalık oda).
  final int maxPlayers;
}

/// Eşit sütunlu seçim ızgarası (konu, soru sayısı, süre, oyuncu, ücret).
///
/// 2026-10-19 sadeleşme (ikinci tur): seçenekler `Wrap` içinde doğal
/// genişlikte dizildiği için satırlar tırtıklı, seçili/seçilmemiş çipler
/// birbirine benziyordu. Artık her hücre eşit genişlikte ve çip hücreyi
/// doldurur; seçili çip DOLU renk, seçilmemiş çip yalnız çerçevedir.
/// Sığmayınca (dar ekran, büyük yazı) sütun sayısı düşer (en az 1).
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.columns,
    required this.children,
    this.minCellWidth,
    this.fallbackColumns,
    this.gap = SahneSpace.x2,
  });

  final int columns;

  /// Verilirse hücre en az bu genişlikte (ölçeksiz) olmalıdır; yoksa yazı
  /// ölçeğine göre 72 kullanılır. Yalnız rakam çipleri için.
  final double? minCellWidth;

  /// [columns] sığmazsa düşülecek sütun sayısı. Ardışık azaltma tek çipi
  /// yetim satıra atar (6 -> 5 = 5+1); bu yüzden doğrudan 3'e (2x3) iner.
  final int? fallbackColumns;

  /// Çipler arası boşluk (satır ve sütun).
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minCell =
            minCellWidth ?? MediaQuery.textScalerOf(context).scale(72);
        var cols = columns;
        double cell(int c) => (constraints.maxWidth - gap * (c - 1)) / c;
        if (fallbackColumns != null && cell(cols) < minCell) {
          cols = fallbackColumns!;
        }
        while (cols > 1 && cell(cols) < minCell) {
          cols--;
        }
        final width = cell(cols);
        // Satır satır kurulur: her satırda bütün çipler en uzununun boyunu
        // alır (büyük yazıda biri iki satıra sarsa bile satır eşit kalır).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += cols) ...[
              if (i > 0) SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) SizedBox(width: gap),
                      SizedBox(
                        width: width,
                        child: i + j < children.length
                            ? children[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

Widget _choiceChip(
  BuildContext context, {
  required Key key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
  Widget? avatar,
  String? semanticLabel,
  bool locked = false,
  bool looked = false,
}) => SahnePickChip(
  minHeight: _roomChipHeight,
  key: key,
  label: label,
  semanticLabel: semanticLabel,
  selected: selected,
  onTap: onTap,
  leading: avatar,
  locked: locked,
  looked: looked,
);

Widget _filterChip(
  BuildContext context, {
  required Key key,
  required String label,
  required bool selected,
  required VoidCallback onTap,
  String? semanticLabel,
}) => SahnePickChip(
  minHeight: _roomChipHeight,
  key: key,
  label: label,
  semanticLabel: semanticLabel,
  selected: selected,
  onTap: onTap,
);

/// Oda kurma sayfasındaki çiplerin yüksekliği (tur 8b: 48 → 44; 44 dokunma
/// tabanıdır). Sayfa 390×844'te kaydırmadan sığsın diye.
const double _roomChipHeight = 44;

/// Katlanır "Ayarlar" satırı: başlık + güncel değerlerin özeti + ok.
class _SettingsSummaryRow extends StatelessWidget {
  const _SettingsSummaryRow({
    super.key,
    required this.title,
    required this.summary,
    required this.open,
    required this.onTap,
  });

  final String title;
  final String summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      expanded: open,
      label: '$title, $summary',
      onTap: onTap,
      excludeSemantics: true,
      child: SahneTappable(
        shape: SahneShape.withSide(SahneShape.m, t.tx3, width: 1),
        color: Colors.transparent,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: sahneTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                      Text(
                        summary,
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SahneSpace.x2),
                Icon(
                  open ? AppIcons.chevronUp : AppIcons.chevronDown,
                  size: 20,
                  color: t.tx2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomRoomBottomSheet extends StatefulWidget {
  const _CustomRoomBottomSheet({
    required this.availableCategories,
    required this.coinBalance,
  });

  final List<String> availableCategories;
  final int coinBalance;

  @override
  State<_CustomRoomBottomSheet> createState() => _CustomRoomBottomSheetState();
}

class _CustomRoomBottomSheetState extends State<_CustomRoomBottomSheet> {
  /// Seçili kategori adları. Boş küme = Karışık (hepsi). En az bir seçim
  /// her zaman vardır: Karışık da bir seçimdir.
  final Set<String> _selectedCategories = <String>{};
  bool _mixed = true;
  int _selectedDuration = GameRoom.defaultSecondsPerQuestion;
  int _selectedQuestionCount = 10;
  int _selectedEntryFee = 0;

  /// Jetonu yetmediği için seçilemeyen ve dokunulan ücret; "N jeton eksik"
  /// notu ile "Jeton kazan" yolunu açar. Seçim ASLA bakiyeyi aşmaz.
  int? _blockedFee;
  int _selectedMaxPlayers = GameRoom.defaultCrowdCapacity;
  bool _settingsOpen = false;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Ayarlar açılınca açılan gruplar görünsün diye içeriğin sonuna kaydırır.
  /// Eskiden "Ayarlar" satırı görünür alanın tepesine hizalanıp altına boş
  /// "kuyruk" eklenirdi; bu, ücret ızgarası ile alt bant arasında ~180 pt ölü
  /// boşluk bırakıyordu (tur 9a). Artık son grubun altında yalnız normal boşluk.
  void _revealSettings() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  /// "10 soru · 20 sn · ücretsiz": kapalı Ayarlar satırının özeti.
  String _settingsSummary(BuildContext context) =>
      '$_selectedQuestionCount ${context.t(K.soru)} · '
      '$_selectedDuration ${context.t(K.secondsShortUnit)} · '
      '${_selectedEntryFee == 0 ? context.t(K.freeEntry) : '$_selectedEntryFee ${context.t(K.coinWord)}'}';

  @override
  void initState() {
    super.initState();
    _selectedEntryFee = _affordableFee(_selectedEntryFee);
  }

  /// [fee] bakiyeyi aşıyorsa yetebilen en yüksek izinli ücret (en az 0).
  int _affordableFee(int fee) {
    if (fee <= widget.coinBalance) return fee;
    var best = 0;
    for (final f in GameRoom.allowedEntryFees) {
      if (f <= widget.coinBalance && f > best) best = f;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final blockedFee = _blockedFee;
    final hasEnoughCoins = blockedFee == null;

    final t = SahneTokens.of(context);
    // 2026-10-02 uçtan uca QA: bu sayfa kapatılamıyordu. İçerik (dört seçim
    // grubu) ekrandan uzun olduğundan kaydırma alanı sayfanın tüm yüksekliğini
    // dolduruyordu: perde (barrier) hiçbir yerde açıkta kalmıyor, aşağı çekme
    // kaydırma alanına gidiyor, ne tutamaç ne kapat düğmesi vardı. "Odaya
    // katıl" sayfası kısa olduğu için perdeye dokunuşla kapanıyordu; kusur
    // yalnız uzun sayfada ve gerçek ekranda görünür. Şimdi: yükseklik %90 ile
    // sınırlı (üstte perde açıkta), tutamaç + kapat düğmesi kaydırma
    // alanının DIŞINDA sabit.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: SahneSpace.page,
          right: SahneSpace.page,
          bottom: MediaQuery.viewInsetsOf(context).bottom + SahneSpace.page,
        ),
        child: AppPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: SizedBox(
                    key: const ValueKey('custom-room-handle'),
                    width: 40,
                    height: 4,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.tx3,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SahneSpace.x3),
              Row(
                children: [
                  // Yarış rolünün ikon karosu (Boyax tonu, M pah). Büyük
                  // yazıda (≥ %150) karo kalkar: başlık "oluştu / r" diye
                  // sözcüğün ortasından kırılıyordu (320 px, x2).
                  if (MediaQuery.textScalerOf(context).scale(14) < 21) ...[
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.raceTint,
                        shape: SahneShape.m,
                      ),
                      child: SizedBox.square(
                        dimension: 44,
                        child: Icon(
                          AppIcons.gamepad,
                          color: t.raceTx,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: SahneSpace.x3),
                  ],
                  Expanded(
                    child: Text(
                      context.t(K.customRoomTitle),
                      style: SahneType.headline.copyWith(color: t.tx),
                    ),
                  ),
                  SahneIconButton(
                    key: const ValueKey('custom-room-close'),
                    icon: AppIcons.xmark,
                    semanticLabel: context.t(K.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: SahneSpace.x2),
              // Başlığın altında net ayraç: kaydırılan içerik başlığın altından
              // "yarım kesik çip" olarak görünmesin.
              Divider(
                key: const ValueKey('custom-room-header-divider'),
                height: 1,
                thickness: 1,
                color: t.tx3.withValues(alpha: 0.35),
              ),
              const SizedBox(height: SahneSpace.x2),
              Flexible(
                child: SahneBottomFade(
                  key: const ValueKey('custom-room-bottom-fade'),
                  color: SahneTokens.of(context).s1,
                  // Tur 8: 24 px solma son ücret satırını soluk/bozuk
                  // gösteriyordu; 8 px'e indi, üstte 8 px bant.
                  height: 8,
                  topHeight: 8,
                  // `shrinkWrap`: kısa içerikte sayfa içeriğe göre boyutlanır
                  // (tur 9a: `SingleChildScrollView` her zaman izin verilen
                  // yüksekliği doldurup ücret ızgarası ile alt bant arasında
                  // ~180 pt ölü boşluk bırakıyordu); uzun içerikte %90 sınırı
                  // içinde kaydırır.
                  child: CustomScrollView(
                    controller: _scroll,
                    shrinkWrap: true,
                    slivers: [
                      SliverPadding(
                        // Alt boşluk: son satır (oyuncu sayısı/ücret) kaydırınca
                        // ayracın ve düğmenin tam üstüne rahatça çıkar.
                        padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kategori Seçimi
                              Text(
                                context.t(K.selectCategory),
                                style: SahneType.bodyStrong.copyWith(
                                  color: SahneTokens.of(context).tx,
                                ),
                              ),
                              const SizedBox(height: SahneSpace.x2),
                              _ChoiceGrid(
                                columns: 3,
                                children: [
                                  // Karışık: bütün kategoriler. Seçilince tekil
                                  // seçimler temizlenir; bir kategori seçilince
                                  // Karışık kalkar.
                                  _filterChip(
                                    context,
                                    key: const ValueKey(
                                      'custom-room-cat-mixed',
                                    ),
                                    label: CategoryNames.tile(
                                      'Tevlihev',
                                      context.isKu,
                                    ),
                                    semanticLabel: CategoryNames.localized(
                                      'Tevlihev',
                                      context.isKu,
                                    ),
                                    selected: _mixed,
                                    onTap: () => setState(() {
                                      _mixed = true;
                                      _selectedCategories.clear();
                                    }),
                                  ),
                                  for (final cat in widget.availableCategories)
                                    _filterChip(
                                      context,
                                      key: ValueKey('custom-room-cat-$cat'),
                                      label: CategoryNames.tile(
                                        cat,
                                        context.isKu,
                                      ),
                                      semanticLabel: CategoryNames.localized(
                                        cat,
                                        context.isKu,
                                      ),
                                      selected: _selectedCategories.contains(
                                        cat,
                                      ),
                                      onTap: () => setState(() {
                                        if (!_selectedCategories.remove(cat)) {
                                          _selectedCategories.add(cat);
                                        }
                                        // Son kategori kaldırılırsa Karışık'a dön:
                                        // seçimsiz oda kurulamaz.
                                        _mixed = _selectedCategories.isEmpty;
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: SahneSpace.x3),

                              // Oyuncu sayısı (kapasite). 2 = bugünkü iki kişilik oda;
                              // daha fazlası kalabalık oda: ev sahibi >= 2 kişiyle
                              // başlatır, sonuç sıralı gelir.
                              Text(
                                context.t(K.roomCapacityLabel),
                                style: SahneType.bodyStrong.copyWith(
                                  color: SahneTokens.of(context).tx,
                                ),
                              ),
                              const SizedBox(height: SahneSpace.x2),
                              // TEK satır, yalnız rakamlar ("Oyuncu sayısı" başlığı
                              // birimi söyler; ekran okuyucu "N kişi" okur). İkinci
                              // satırın yarısı sabit "Odayı aç" altında kaldığında
                              // "boş çerçeve" gibi okunuyordu (iki tasarım turu).
                              // 320'de 6x48 sığmaz: 2x3'e iner, hiç yetim çip yok.
                              _ChoiceGrid(
                                columns: GameRoom.allowedMaxPlayers.length,
                                minCellWidth: sahneTapTarget,
                                fallbackColumns: 3,
                                // 6 çip 390 pt telefonda 48'e ancak 6 pt aralıkla sığar.
                                gap: 6,
                                children: [
                                  for (final capacity
                                      in GameRoom.allowedMaxPlayers)
                                    _choiceChip(
                                      context,
                                      key: ValueKey(
                                        'custom-room-capacity-$capacity',
                                      ),
                                      label: '$capacity',
                                      semanticLabel: context.t(
                                        K.roomCapacityOption,
                                        {'n': '$capacity'},
                                      ),
                                      selected: _selectedMaxPlayers == capacity,
                                      onTap: () => setState(
                                        () => _selectedMaxPlayers = capacity,
                                      ),
                                    ),
                                ],
                              ),
                              if (_selectedMaxPlayers > 2) ...[
                                const SizedBox(height: SahneSpace.x2),
                                Text(
                                  context.t(K.roomCapacityHint),
                                  key: const ValueKey(
                                    'custom-room-capacity-hint',
                                  ),
                                  style: SahneType.caption.copyWith(
                                    color: SahneTokens.of(context).tx2,
                                  ),
                                ),
                              ],
                              const SizedBox(height: SahneSpace.x3),

                              // Kurul 3. tur 2026-10-20: üç ikincil grup (soru sayısı,
                              // süre, ücret) tek "Ayarlar" satırında toplandı; özet
                              // güncel değerleri gösterir, dokununca satır içinde açılır.
                              _SettingsSummaryRow(
                                key: const ValueKey('custom-room-settings-row'),
                                title: context.t(K.settings),
                                summary: _settingsSummary(context),
                                open: _settingsOpen,
                                onTap: () {
                                  setState(() {
                                    _settingsOpen = !_settingsOpen;
                                  });
                                  if (_settingsOpen) _revealSettings();
                                },
                              ),
                              if (_settingsOpen) ...[
                                const SizedBox(height: SahneSpace.x3),
                                // Soru Sayısı Seçimi
                                Text(
                                  context.t(K.questionCountLabel),
                                  style: SahneType.bodyStrong.copyWith(
                                    color: SahneTokens.of(context).tx,
                                  ),
                                ),
                                const SizedBox(height: SahneSpace.x2),
                                _ChoiceGrid(
                                  columns: 3,
                                  children: [
                                    for (final count
                                        in GameRoom.allowedQuestionCounts)
                                      _choiceChip(
                                        context,
                                        key: ValueKey(
                                          'custom-room-count-$count',
                                        ),
                                        label: '$count ${context.t(K.soru)}',
                                        selected:
                                            _selectedQuestionCount == count,
                                        onTap: () => setState(
                                          () => _selectedQuestionCount = count,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: SahneSpace.x3),

                                // Soru Başına Süre
                                Text(
                                  context.t(K.secondsPerQuestion),
                                  style: SahneType.bodyStrong.copyWith(
                                    color: SahneTokens.of(context).tx,
                                  ),
                                ),
                                const SizedBox(height: SahneSpace.x2),
                                _ChoiceGrid(
                                  columns: 4,
                                  children: [
                                    for (final seconds
                                        in GameRoom.allowedDurations)
                                      _choiceChip(
                                        context,
                                        key: ValueKey(
                                          'custom-room-duration-$seconds',
                                        ),
                                        label:
                                            '$seconds ${context.t(K.secondsShortUnit)}',
                                        selected: _selectedDuration == seconds,
                                        onTap: () => setState(
                                          () => _selectedDuration = seconds,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: SahneSpace.x3),

                                // Bahis / Giriş Ücreti
                                // İki metin de esnek: dar ekranda ve Kurmancî'de etiketler
                                // uzuyor ve sabit genişlikli `Row` sağdan 192 piksel taşıyordu
                                // (`home_room_failures_test` yakaladı). `spaceBetween` tek
                                // başına taşmayı önlemez — çocuklar doğal boyutlarını ister.
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.t(K.entryFeeLabel),
                                        style: SahneType.bodyStrong.copyWith(
                                          color: SahneTokens.of(context).tx,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: SahneSpace.x2),
                                    Flexible(
                                      child: Text(
                                        context.t(K.yourBalance, {
                                          'coins': widget.coinBalance
                                              .toString(),
                                        }),
                                        textAlign: TextAlign.end,
                                        style: SahneType.caption.copyWith(
                                          color: SahneTokens.of(context).tx2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: SahneSpace.x2),
                                _ChoiceGrid(
                                  // 2x2: tek satırda çip ~80 pt'e daralıp yazı
                                  // küçülüyordu (tur 10a); 14 pt yazı için geniş hücre.
                                  columns: 2,
                                  children: [
                                    for (final fee in GameRoom.allowedEntryFees)
                                      _choiceChip(
                                        context,
                                        key: ValueKey('custom-room-fee-$fee'),
                                        avatar: fee > 0
                                            ? const ExcludeSemantics(
                                                child: SahneGlyph(
                                                  SahneGlyphKind.coin,
                                                  size: 16,
                                                ),
                                              )
                                            : null,
                                        label: fee == 0
                                            ? context.t(K.freeEntry)
                                            : '$fee ${context.t(K.coinWord)}',
                                        selected: _selectedEntryFee == fee,
                                        locked: fee > widget.coinBalance,
                                        looked: _blockedFee == fee,
                                        semanticLabel: fee > widget.coinBalance
                                            ? '${'$fee ${context.t(K.coinWord)}'}, '
                                                  '${context.t(K.coinsShort, {'coins': '${coinShortfall(cost: fee, balance: widget.coinBalance)}'})}'
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            if (fee > widget.coinBalance) {
                                              // Yetmeyen ücret seçilmez: seçim kalır,
                                              // eksik miktar alt notta söylenir.
                                              _blockedFee = fee;
                                            } else {
                                              _selectedEntryFee = fee;
                                              _blockedFee = null;
                                            }
                                          });
                                          // Not satırı görünür alanı kısaltır: ızgara kesilmeden görünsün.
                                          _revealSettings();
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Alt çubuğun üstünde ince ayraç: kaydırılan içerik düğmenin
              // altında "kesilmiş" görünmesin.
              Divider(
                key: const ValueKey('custom-room-footer-divider'),
                height: SahneSpace.x2 * 2 + 1,
                thickness: 1,
                color: t.tx3.withValues(alpha: 0.35),
              ),

              // Yetmeyen bir ücrete dokunulduğunda: not + ikincil "Jeton kazan"
              // bağlantısı, kaydırma alanının DIŞINDA, birincil düğmenin hemen
              // üstünde. Birincil düğme HEP "Oda oluştur"dur ve seçili (yetebilen)
              // ücretle açar; not yalnız dokunulan kilitli ücretin bağlamında
              // görünür, yetebilen bir ücrete dokunmak onu kapatır (tur 9a).
              if (!hasEnoughCoins)
                Padding(
                  padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                  child: Row(
                    key: const ValueKey('custom-room-shortfall-row'),
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SahneShortfallNote(
                            key: const ValueKey('custom-room-shortfall'),
                            missing: coinShortfall(
                              cost: blockedFee,
                              balance: widget.coinBalance,
                            ),
                            fee: blockedFee,
                            warn: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: SahneSpace.x2),
                      SahneButton.text(
                        buttonKey: const ValueKey('custom-room-earn-coins'),
                        label: context.t(K.earnCoins),
                        icon: AppIcons.dice,
                        arrow: false,
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(const _EarnCoinsRequest()),
                      ),
                    ],
                  ),
                ),
              // 2026-10-19: düğme kaydırma alanının DIŞINDA, sayfanın altında SABİT;
              // uzun seçim listesinde "Oda kur" hiç kaybolmaz. Seçili ücret her
              // zaman yetebilen bir ücrettir (bkz. `_affordableFee`).
              // Sayfanın düğmesi `FilledButton` kalır: ekranın tek `SahneButton.
              // primary`si hızlı düellodur (bkz. `brand_accent_guard_test`).
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('custom-room-open'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      _CustomRoomConfig(
                        category: _mixed
                            ? 'Tevlihev'
                            : _selectedCategories.join(', '),
                        duration: _selectedDuration,
                        questionCount: _selectedQuestionCount,
                        entryFee: _selectedEntryFee,
                        maxPlayers: _selectedMaxPlayers,
                      ),
                    );
                  },
                  child: Text(context.t(K.openRoom)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
