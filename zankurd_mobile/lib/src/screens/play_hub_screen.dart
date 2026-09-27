import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
import '../providers/remote_availability.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../services/analytics_service.dart';
import '../widgets/app_panel.dart';
import '../widgets/screen_identity_header.dart';
import 'contest_screen.dart';
import '../widgets/mode_card.dart';
import 'matchmaking_screen.dart';
import 'room_screen.dart';
import 'tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class PlayHubScreen extends StatefulWidget {
  const PlayHubScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<PlayHubScreen> createState() => _PlayHubScreenState();
}

class _PlayHubScreenState extends State<PlayHubScreen> {
  bool _dailyLoading = false;
  bool _roomActionLoading = false;
  bool _moreOpen = false;

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
    final inputTextStyle = TextStyle(
      color: AppTheme.textPrimaryColor(context),
      fontWeight: FontWeight.w800,
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
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom + AppSpacing.page,
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
                    style: AppTypography.heading1.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.t(K.joinRoomBody),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.md),
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
                              content: Text(context.t(joinRoomErrorKey(error))),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final locked = RemoteAvailability.socialLockedIn(context);
    // Oyun merkezi tek bir sakin marka yüzeyi ve nötr ikincil satırlardan
    // oluşur. Mod kimliğini büyük renk blokları veya dekoratif efektler değil,
    // başlık sırası ve küçük ikon aksanları taşır.
    return ColoredBox(
      color: AppTheme.bgOf(context),
      child: SafeArea(
        child: Material(
          color: AppTheme.bgOf(context),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              // Ekran altı eşit ağırlıkta satırdan oluşan bir menü gibi
              // duruyordu; yeni kullanıcı hangisinin "asıl oyun" olduğunu
              // seçemiyordu (2026-07-25 canlı denetimi). Artık tek birincil
              // eylem (hızlı düello) ve altında iki adlandırılmış grup var.
              ScreenIdentityHeader(
                title: context.t(K.playTitle),
                subtitle: context.t(K.playSubtitle),
                accent: AppTheme.brand,
                icon: AppIcons.gamepad,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickDuelHero(
                ku: ku,
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
              const SizedBox(height: AppSpacing.lg),
              ScreenSectionHeading(
                title: context.t(K.withFriends),
                subtitle: context.t(K.withFriendsSub),
              ),
              const SizedBox(height: AppSpacing.md),
              // İkincil oyun yolları ayrı ayrı gökkuşağı tonları taşımaz.
              // Sosyal/navigasyon yolları ortak yeşil kimliği, etkinlikler
              // ise ödül/prestij rengi olan altını paylaşır. Böylece renk
              // "hangi kart?" değil, "hangi rol?" sorusunu yanıtlar.
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 18;
                  final stackActions =
                      constraints.maxWidth < 340 || largeText || locked;
                  final createTitle = context.t(K.createRoom);
                  final createSubtitle = locked
                      ? context.t(K.serverUnreachableTitle)
                      : context.t(K.createRoomSub);
                  final joinTitle = context.t(K.joinByCode);
                  final joinSubtitle = locked
                      ? context.t(K.serverUnreachableTitle)
                      : context.t(K.joinByCodeSub);
                  final createRoom = ModeCard(
                    key: const ValueKey('play-hub-create-room'),
                    compact: true,
                    emphasis: ModeCardEmphasis.secondary,
                    icon: AppIcons.circlePlus,
                    accent: AppTheme.playGreen,
                    title: createTitle,
                    subtitle: createSubtitle,
                    busy: _roomActionLoading,
                    onTap: locked || _roomActionLoading
                        ? null
                        : () {
                            _createOnlineRoom();
                          },
                  );
                  final joinRoom = ModeCard(
                    key: const ValueKey('play-hub-join-room'),
                    compact: true,
                    emphasis: ModeCardEmphasis.secondary,
                    icon: AppIcons.doorOpen,
                    accent: AppTheme.playGreen,
                    title: joinTitle,
                    subtitle: joinSubtitle,
                    onTap: locked ? null : _showJoinSheet,
                  );
                  if (stackActions) {
                    return Column(
                      children: [
                        createRoom,
                        const SizedBox(height: AppSpacing.sm),
                        joinRoom,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _CompactRoomAction(
                            key: const ValueKey('play-hub-create-room'),
                            icon: AppIcons.circlePlus,
                            title: createTitle,
                            semanticSubtitle: createSubtitle,
                            busy: _roomActionLoading,
                            onTap: _roomActionLoading
                                ? null
                                : _createOnlineRoom,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _CompactRoomAction(
                            key: const ValueKey('play-hub-join-room'),
                            icon: AppIcons.doorOpen,
                            title: joinTitle,
                            semanticSubtitle: joinSubtitle,
                            onTap: _showJoinSheet,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              ScreenSectionHeading(
                title: context.t(K.events),
                subtitle: context.t(K.eventsSub),
              ),
              const SizedBox(height: AppSpacing.md),
              ModeCard(
                key: const ValueKey('play-hub-daily-contest'),
                compact: true,
                emphasis: ModeCardEmphasis.event,
                icon: AppIcons.bolt,
                accent: AppTheme.gold,
                title: context.t(K.dailyContest),
                subtitle: locked
                    ? context.t(K.serverUnreachableTitle)
                    : context.t(K.tenQuestions),
                busy: _dailyLoading,
                onTap: locked || _dailyLoading ? null : _openDailyQuiz,
              ),
              // Turnuva kalabalık bir kitle bekliyor; o kitle gelene dek
              // bayrakla kapalı (bkz. `kTournamentEnabled`).
              if (kTournamentEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                // Turnuva ilk bakışta yok: benzer uygulamalarda indirme/tekrar
                // sebebi "şimdi oyna" + günlük dönüş; eleme modu ikinci katman.
                Semantics(
                  button: true,
                  excludeSemantics: true,
                  label:
                      '${context.t(K.playMore)}. ${context.t(K.playMoreSub)}',
                  onTap: () => setState(() => _moreOpen = !_moreOpen),
                  child: InkWell(
                    key: const ValueKey('play-hub-more'),
                    onTap: () => setState(() => _moreOpen = !_moreOpen),
                    excludeFromSemantics: true,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ScreenSectionHeading(
                              title: context.t(K.playMore),
                              subtitle: context.t(K.playMoreSub),
                              semanticHeader: false,
                            ),
                          ),
                          Icon(
                            _moreOpen
                                ? AppIcons.chevronUp
                                : AppIcons.chevronDown,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_moreOpen) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ModeCard(
                    key: const ValueKey('play-hub-tournament'),
                    compact: true,
                    emphasis: ModeCardEmphasis.event,
                    icon: AppIcons.trophy,
                    accent: AppTheme.gold,
                    title: context.t(K.tournament),
                    subtitle: locked
                        ? context.t(K.serverUnreachableTitle)
                        : context.t(K.tournamentSub),
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
                ],
              ],
              // Mağaza satırı buradan kaldırıldı: aynı ekrana Yarış
              // sekmesinden, profilden ve kendi rotasından olmak üzere üç
              // ayrı giriş vardı ve "burası neresi?" hissi yaratıyordu
              // (2026-07-25 canlı denetimi). Tek ev profildeki HESAP bölümü.
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRoomAction extends StatelessWidget {
  const _CompactRoomAction({
    required this.icon,
    required this.title,
    required this.semanticSubtitle,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String semanticSubtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onTap != null;
    final accent = AppColors.readableAccent(context, AppTheme.playGreen);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $semanticSubtitle',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.iconTileBg(
                          context,
                          AppTheme.playGreen,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    if (busy)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      )
                    else
                      Icon(
                        AppIcons.chevronRight,
                        size: 17,
                        color: AppTheme.textMutedColor(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ekranın tek birincil eylemi. Düz marka yüzeyi, altındaki mod satırlarıyla
/// aynı ürün ailesinde kalır; promosyon/banner hissi oluşturmaz.
class _QuickDuelHero extends StatelessWidget {
  const _QuickDuelHero({required this.ku, required this.onTap});

  final bool ku;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      key: const ValueKey('play-hub-quick-duel'),
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: '${context.t(K.quickDuel)}. ${context.t(K.findOpponent)}',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.culturalBrandBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppTheme.cardShadow(context),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          AppIcons.peopleGroup,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          context.t(K.quickDuel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.t(K.quickDuelSub),
                    style: AppTypography.heading2.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    key: const ValueKey('play-hub-quick-duel-cta'),
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCtaColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      context.t(K.findOpponent),
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.onSolid(
                          AppTheme.primaryCtaColor(context),
                        ),
                        fontWeight: FontWeight.w700,
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
        left: AppSpacing.page,
        right: AppSpacing.page,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.page,
      ),
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    AppIcons.gamepad,
                    color: AppTheme.terracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.t(K.customRoomTitle),
                    style: AppTypography.heading1.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Kategori Seçimi
            Text(
              context.t(K.selectCategory),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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
            const SizedBox(height: AppSpacing.md),

            // Soru Sayısı Seçimi
            Text(
              context.t(K.questionCountLabel),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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
            const SizedBox(height: AppSpacing.md),

            // Soru Başına Süre
            Text(
              context.t(K.secondsPerQuestion),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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
            const SizedBox(height: AppSpacing.md),

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
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    context.t(K.yourBalance, {
                      'coins': widget.coinBalance.toString(),
                    }),
                    textAlign: TextAlign.end,
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final fee in GameRoom.allowedEntryFees)
                  ChoiceChip(
                    key: ValueKey('custom-room-fee-$fee'),
                    avatar: fee > 0
                        ? const ExcludeSemantics(
                            child: Icon(
                              AppIcons.coins,
                              size: 14,
                              color: Color(0xFFD4AF37),
                            ),
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.t(K.insufficientCoins),
                style: AppTypography.caption.copyWith(
                  color: AppTheme.wrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

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
