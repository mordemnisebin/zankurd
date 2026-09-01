import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
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
    } catch (_) {}

    int coinBalance = 0;
    try {
      coinBalance = await widget.repository.loadCoinBalance();
    } catch (_) {}

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
    // 2026-07-24: karo ızgarası + gradyan panel yarışı bitti. Ekranda tek
    // gradyan var (hızlı düello), diğer modlar eşit ağırlıkta sade satır.
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
              const SizedBox(height: AppSpacing.sm),
              _QuickDuelHero(
                ku: ku,
                onTap: () => Navigator.of(context).push(
                  AppRoute.to(MatchmakingScreen(repository: widget.repository)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PlaySectionHeading(
                title: context.t(K.withFriends),
                subtitle: context.t(K.withFriendsSub),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Rengîn (2026-08-04): dört satır birbirinin aynı beyaz kartıydı
              // ve oyun merkezinin tamamı tek yeşil + tek turuncu ile
              // çiziliyordu. Her mod artık kendi hue ailesini taşır; turuncu
              // yalnız birincil eylemde kalır.
              ModeCard(
                key: const ValueKey('play-hub-create-room'),
                compact: true,
                emphasis: ModeCardEmphasis.secondary,
                icon: AppIcons.circlePlus,
                // Marka paleti dışına çıkan son iki yüzey buydu. `shop_screen`
                // M24 notu playPink/playPurple'ı 2026-07-23'te "marka dışı"
                // ilan etmiş, eşleşme ekranı 2026-07-31'de düzeltilmişti; ama
                // kararın verildiği ekranın *kendisi* atlanmıştı. Oyun
                // merkezinde dört satır yan yana duruyor, yani sapma en çok
                // burada görünüyordu: mor ve pembe, turuncu-altın-yeşil
                // kimliğin yanında yabancı kalıyordu (2026-08-01, iOS canlı).
                accent: const Color(0xFF1E4FA6), // safir — kurma
                title: context.t(K.createRoom),
                subtitle: context.t(K.createRoomSub),
                busy: _roomActionLoading,
                onTap: _roomActionLoading ? null : _createOnlineRoom,
              ),
              const SizedBox(height: AppSpacing.xs),
              ModeCard(
                key: const ValueKey('play-hub-join-room'),
                compact: true,
                emphasis: ModeCardEmphasis.secondary,
                icon: AppIcons.doorOpen,
                accent: const Color(0xFF04697C), // turkuaz — katılma
                title: context.t(K.joinByCode),
                subtitle: context.t(K.joinByCodeSub),
                onTap: _showJoinSheet,
              ),
              const SizedBox(height: AppSpacing.md),
              _PlaySectionHeading(
                title: context.t(K.events),
                subtitle: context.t(K.eventsSub),
              ),
              const SizedBox(height: AppSpacing.sm),
              ModeCard(
                key: const ValueKey('play-hub-daily-contest'),
                compact: true,
                emphasis: ModeCardEmphasis.event,
                icon: AppIcons.bolt,
                // Altın ödül/ekonomiye ayrılmış; günlük etkinlik safran alır.
                accent: const Color(0xFF9C6300),
                title: context.t(K.dailyContest),
                subtitle: context.t(K.tenQuestions),
                busy: _dailyLoading,
                onTap: _dailyLoading ? null : _openDailyQuiz,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Turnuva ilk bakışta yok: benzer uygulamalarda indirme/tekrar
              // sebebi "şimdi oyna" + günlük dönüş; eleme modu ikinci katman.
              Semantics(
                button: true,
                label: '${context.t(K.playMore)}. ${context.t(K.playMoreSub)}',
                child: InkWell(
                  key: const ValueKey('play-hub-more'),
                  onTap: () => setState(() => _moreOpen = !_moreOpen),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PlaySectionHeading(
                            title: context.t(K.playMore),
                            subtitle: context.t(K.playMoreSub),
                          ),
                        ),
                        Icon(
                          _moreOpen ? AppIcons.chevronUp : AppIcons.chevronDown,
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
                  accent: const Color(0xFF6A38BE),
                  title: context.t(K.tournament),
                  subtitle: context.t(K.tournamentSub),
                  onTap: () => Navigator.of(context).push(
                    AppRoute.to(
                      TournamentScreen(repository: widget.repository),
                    ),
                  ),
                ),
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

/// Ekranın tek birincil eylemi — tek gradyan burada.
class _QuickDuelHero extends StatelessWidget {
  const _QuickDuelHero({required this.ku, required this.onTap});

  final bool ku;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('play-hub-quick-duel'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            // Rengîn (2026-08-04): hero koyu yeşilden koyu yeşile
            // iniyordu ve hemen üstündeki kimlik başlığıyla birlikte iki
            // ayrı yeşil panel gibi okunuyordu. Düello bir REKABET
            // yüzeyidir; madder ailesinden derin mürekkebe geçer ve artık
            // ekranın en güçlü yeri odur — altındaki mod kartlarından
            // sönük kalmaz.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB31E3B), Color(0xFF17233B)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Stack(
            children: [
              // Kartın sağındaki düşük opaklıklı ikon, eylemi anlatır ve
              // paneli boş bir yeşil dikdörtgen olmaktan çıkarır.
              Positioned(
                right: -28,
                top: -34,
                child: Icon(
                  AppIcons.bolt,
                  size: 164,
                  color: Colors.white.withValues(alpha: 0.055),
                ),
              ),
              Padding(
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
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
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
                              color: Colors.white.withValues(alpha: 0.86),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.t(K.quickDuelSub),
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCtaColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        context.t(K.findOpponent),
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaySectionHeading extends StatelessWidget {
  const _PlaySectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
      ],
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
                    color: const Color(0xFF1E4FA6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    AppIcons.gamepad,
                    color: Color(0xFF1E4FA6),
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
