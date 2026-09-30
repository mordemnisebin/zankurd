import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
import '../providers/remote_availability.dart';
import '../widgets/sahne/sahne.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../services/analytics_service.dart';
import '../widgets/app_panel.dart';
import 'async_duel/async_duel_inbox.dart';
import 'async_duel/async_duel_play_screen.dart';
import 'contest_screen.dart';
import 'matchmaking_screen.dart';
import 'room_screen.dart';
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

    final config = await showModalBottomSheet<_CustomRoomConfig>(
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

    setState(() => _roomActionLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom(
        category: config.category,
        secondsPerQuestion: config.duration,
        questionCount: config.questionCount,
        entryFee: config.entryFee,
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

  void _openRoom(GameRoom room) {
    Navigator.of(context).push(
      AppRoute.to(RoomScreen(repository: widget.repository, initialRoom: room)),
    );
  }

  Future<void> _showJoinSheet() async {
    final controller = _joinCodeController..clear();
    final formKey = GlobalKey<FormState>();
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
                    TextFormField(
                      key: const ValueKey('play-hub-join-room-code-field'),
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      // Yazarken kanonik biçime çeker: kullanıcı yalnız soneki
                      // yazsa da alanda `ZK-ABCDEF0123` görünür, yani gönderilen
                      // kodun doğru olduğunu göndermeden önce görür.
                      inputFormatters: const [_RoomCodeInputFormatter()],
                      style: inputTextStyle,
                      errorBuilder: (_, errorText) =>
                          Text(errorText, overflow: TextOverflow.visible),
                      decoration: InputDecoration(
                        labelText: context.t(K.roomCode),
                        prefixIcon: const Icon(AppIcons.doorOpen),
                      ),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            final room = await widget.repository.joinOnlineRoom(
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t(joinRoomErrorKey(error)),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(AppIcons.rightToBracket),
                        label: Text(context.t(K.joinAction)),
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

  /// Kilitliyken (sunucuya hiç ulaşılamıyor) pasif giriş dokunulunca kısa bir
  /// geri bildirim verir: sessiz ölü düğme kalmaz. 2026-09-30 simülatör.
  void _notifyLocked() {
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
    final locked = RemoteAvailability.socialLockedIn(context);

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
        SahneButton.secondary(
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
        SahneButton.secondary(
          icon: AppIcons.hashtag,
          label: context.t(K.joinByCode),
          semanticLabel: context.t(K.joinByCode),
          expand: true,
          onPressed: locked ? null : _showJoinSheet,
        ),
      ),
    );

    final dailyContestRow = SahneListRow.icon(
      key: const ValueKey('play-hub-daily-contest'),
      icon: AppIcons.calendarDays,
      role: SahneRole.race,
      title: context.t(K.dailyContest),
      subtitle: context.t(K.tenQuestions),
      // 2026-09-29 doğallık (K7): sağdaki "Bugün" rozeti kalktı; satırın
      // adı zaten "Günün soruları", rozet aynı sözü ikinci kez söylüyordu.
      trailing: _dailyLoading ? const _RowSpinner() : null,
      chevron: !locked && !_dailyLoading,
      enabled: !locked,
      onTap: locked || _dailyLoading ? null : _openDailyQuiz,
      semanticLabel:
          '${context.t(K.dailyContest)}. ${context.t(K.tenQuestions)}',
    );
    final dailyContest = _lockedTap(locked, dailyContestRow);

    return SahneTabPage(
      title: context.t(K.playTitle),
      stats: [
        TabStatChips(
          repository: widget.repository,
          refreshSignal: widget.refreshSignal,
        ),
      ],
      children: [
        _QuickDuelHero(
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
        if (widget.asyncDuelEnabled) ...[
          const SizedBox(height: SahneSpace.cardGap),
          SahneListGroup(
            children: [
              _lockedTap(
                locked,
                SahneListRow.icon(
                  key: const ValueKey('play-hub-async-duel'),
                  icon: AppIcons.hourglass,
                  role: SahneRole.race,
                  title: context.t(K.asyncDuel),
                  subtitle: context.t(K.asyncDuelSub),
                  chevron: !locked,
                  enabled: !locked,
                  semanticLabel:
                      '${context.t(K.asyncDuel)}. ${context.t(K.asyncDuelSub)}',
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
            ],
          ),
          if (!locked) ...[
            const SizedBox(height: SahneSpace.x2),
            AsyncDuelInboxSection(
              repository: widget.repository,
              refreshSignal: _asyncDuelInboxSignal,
            ),
          ],
        ],
        SahneSectionHeader(title: context.t(K.withFriends)),
        _RoomActions(
          note: context.t(K.createRoomSub),
          createRoom: createRoom,
          joinRoom: joinRoom,
        ),
        SahneSectionHeader(title: context.t(K.events)),
        SahneListGroup(
          children: [
            dailyContest,
            if (!widget.asyncDuelEnabled)
              SahneListRow.icon(
                key: const ValueKey('play-hub-async-duel-soon'),
                icon: AppIcons.shuffle,
                title: context.t(K.asyncDuel),
                subtitle: context.t(K.asyncDuelSub),
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
                                TournamentScreen(repository: widget.repository),
                              ),
                            );
                          },
                  ),
                ),
            ],
          ],
        ),
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
/// "Kodla katıl" Kurmancîde ("Bi kodê tevlî bibe") yarım genişliğe iki
/// satırdan fazla düşmesin diye eşik yazı ölçeğine de bakar.
class _RoomActions extends StatelessWidget {
  const _RoomActions({
    required this.note,
    required this.createRoom,
    required this.joinRoom,
  });

  final String note;
  final Widget createRoom;
  final Widget joinRoom;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(note, style: SahneType.caption.copyWith(color: t.tx2)),
        const SizedBox(height: SahneSpace.x3),
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

/// Satır sağındaki yükleniyor göstergesi (oda kuruluyor, etkinlik açılıyor).
class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: SahneTokens.of(context).tx2,
      ),
    );
  }
}

/// Ekranın tek birincil eylemi — bir YARIŞMA SAHNESİ.
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
class _QuickDuelHero extends StatelessWidget {
  const _QuickDuelHero({required this.onTap, this.onLockedTap});

  final VoidCallback? onTap;

  /// Kilitliyken düğmeye dokunulunca çağrılır (geri bildirim); düğme yine
  /// pasif görünür ve ekran okuyucuya tıklanabilir bildirilmez.
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
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
      child: SahneStageCard(
        role: SahneRole.race,
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t(K.quickDuel),
                  style: SahneType.captionStrong.copyWith(
                    color: SahneStageColors.raceSoft,
                  ),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(title, style: SahneType.headline.copyWith(color: t.tx)),
                const SizedBox(height: SahneSpace.x1),
                Text(
                  meta,
                  key: const ValueKey('play-hub-quick-duel-meta'),
                  style: SahneType.caption.copyWith(
                    color: SahneStageColors.raceSoft,
                  ),
                ),
                const SizedBox(height: SahneSpace.x4),
                KeyedSubtree(
                  key: const ValueKey('play-hub-quick-duel-cta'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: onTap == null ? onLockedTap : null,
                    child: SahneButton.primary(
                      label: context.t(K.findOpponent),
                      onPressed: onTap,
                      expand: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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

class _CustomRoomConfig {
  const _CustomRoomConfig({
    required this.category,
    required this.duration,
    required this.questionCount,
    required this.entryFee,
  });

  final String category;
  final int duration;
  final int questionCount;
  final int entryFee;
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
  late String _selectedCategory;
  int _selectedDuration = GameRoom.defaultSecondsPerQuestion;
  int _selectedQuestionCount = 10;
  int _selectedEntryFee = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.availableCategories.firstOrNull ?? 'Ziman';
  }

  @override
  Widget build(BuildContext context) {
    final hasEnoughCoins = widget.coinBalance >= _selectedEntryFee;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: SahneSpace.page,
        right: SahneSpace.page,
        bottom: MediaQuery.viewInsetsOf(context).bottom + SahneSpace.page,
      ),
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Yarış rolünün ikon karosu (Boyax tonu, M pah).
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: SahneTokens.of(context).raceTint,
                    shape: SahneShape.m,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      AppIcons.gamepad,
                      color: SahneTokens.of(context).raceTx,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    context.t(K.customRoomTitle),
                    style: SahneType.headline.copyWith(
                      color: SahneTokens.of(context).tx,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),

            // Kategori Seçimi
            Text(
              context.t(K.selectCategory),
              style: SahneType.bodyStrong.copyWith(
                color: SahneTokens.of(context).tx,
              ),
            ),
            const SizedBox(height: SahneSpace.x2),
            Wrap(
              spacing: SahneSpace.x2,
              runSpacing: SahneSpace.x2,
              children: [
                for (final cat in widget.availableCategories)
                  ChoiceChip(
                    key: ValueKey('custom-room-cat-$cat'),
                    label: Text(CategoryNames.localized(cat, context.isKu)),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),

            // Soru Sayısı Seçimi
            Text(
              context.t(K.questionCountLabel),
              style: SahneType.bodyStrong.copyWith(
                color: SahneTokens.of(context).tx,
              ),
            ),
            const SizedBox(height: SahneSpace.x2),
            Wrap(
              spacing: SahneSpace.x2,
              runSpacing: SahneSpace.x2,
              children: [
                for (final count in GameRoom.allowedQuestionCounts)
                  ChoiceChip(
                    key: ValueKey('custom-room-count-$count'),
                    label: Text('$count ${context.t(K.soru)}'),
                    selected: _selectedQuestionCount == count,
                    onSelected: (_) =>
                        setState(() => _selectedQuestionCount = count),
                  ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),

            // Soru Başına Süre
            Text(
              context.t(K.secondsPerQuestion),
              style: SahneType.bodyStrong.copyWith(
                color: SahneTokens.of(context).tx,
              ),
            ),
            const SizedBox(height: SahneSpace.x2),
            Wrap(
              spacing: SahneSpace.x2,
              runSpacing: SahneSpace.x2,
              children: [
                for (final seconds in GameRoom.allowedDurations)
                  ChoiceChip(
                    key: ValueKey('custom-room-duration-$seconds'),
                    label: Text('$seconds ${context.t(K.secondsShortUnit)}'),
                    selected: _selectedDuration == seconds,
                    onSelected: (_) =>
                        setState(() => _selectedDuration = seconds),
                  ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),

            // Bahis / Giriş Ücreti
            // İki metin de esnek: dar ekranda ve Kurmancî'de etiketler
            // uzuyor ve sabit genişlikli `Row` sağdan 192 piksel taşıyordu
            // (`home_room_failures_test` yakaladı). `spaceBetween` tek
            // başına taşmayı önlemez — çocuklar doğal boyutlarını ister.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      'coins': widget.coinBalance.toString(),
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
            Wrap(
              spacing: SahneSpace.x2,
              runSpacing: SahneSpace.x2,
              children: [
                for (final fee in GameRoom.allowedEntryFees)
                  ChoiceChip(
                    key: ValueKey('custom-room-fee-$fee'),
                    avatar: fee > 0
                        ? const ExcludeSemantics(
                            child: SahneGlyph(SahneGlyphKind.coin, size: 16),
                          )
                        : null,
                    label: Text(
                      fee == 0
                          ? context.t(K.freeEntry)
                          : '$fee ${context.t(K.coinWord)}',
                    ),
                    selected: _selectedEntryFee == fee,
                    onSelected: (_) => setState(() => _selectedEntryFee = fee),
                  ),
              ],
            ),
            if (!hasEnoughCoins) ...[
              const SizedBox(height: SahneSpace.x2),
              Text(
                context.t(K.insufficientCoins),
                style: SahneType.captionStrong.copyWith(
                  color: SahneTokens.of(context).errTx,
                ),
              ),
            ],
            const SizedBox(height: SahneSpace.x6),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !hasEnoughCoins
                    ? null
                    : () {
                        Navigator.of(context).pop(
                          _CustomRoomConfig(
                            category: _selectedCategory,
                            duration: _selectedDuration,
                            questionCount: _selectedQuestionCount,
                            entryFee: _selectedEntryFee,
                          ),
                        );
                      },
                child: Text(context.t(K.openRoom)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
