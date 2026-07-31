import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'contest_screen.dart';
import '../widgets/app_row_card.dart';
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
    final seconds = await _pickRoomDuration();
    if (seconds == null || !mounted) return; // kullanıcı sayfayı kapattı
    setState(() => _roomActionLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom(
        secondsPerQuestion: seconds,
      );
      if (!mounted) return;
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

  /// Oda kurucusunun her soru için tanımlı süreyi seçmesini sağlar. Bu ayar
  /// yalnızca UI'da eksikti — repository/DB katmanı zaten `secondsPerQuestion`
  /// alanını destekliyordu (2026-07-21 denetiminde bulunan boşluk).
  Future<int?> _pickRoomDuration() async {
    // Tek kaynak modeldir: UI ayrıca 15 sn sunuyordu ama bu değer
    // GameRoom.allowedSecondsPerQuestion içinde yok ve canlı denetimde
    // görülen uzun sorular için okunamayacak kadar kısa (2026-07-22).
    const options = GameRoom.allowedSecondsPerQuestion;
    var selected = GameRoom.defaultSecondsPerQuestion;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.page,
                right: AppSpacing.page,
                bottom:
                    MediaQuery.viewInsetsOf(sheetCtx).bottom + AppSpacing.page,
              ),
              child: AppPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(K.secondsPerQuestion),
                      style: AppTypography.heading1.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.t(K.secondsPerQuestionNote),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final seconds in options)
                          ChoiceChip(
                            key: ValueKey('room-duration-$seconds'),
                            label: Text('$seconds sn'),
                            selected: selected == seconds,
                            onSelected: (_) =>
                                setSheetState(() => selected = seconds),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(selected),
                        child: Text(context.t(K.openRoom)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openRoom(GameRoom room) {
    Navigator.of(context).push(
      AppRoute.to(RoomScreen(repository: widget.repository, initialRoom: room)),
    );
  }

  Future<void> _showJoinSheet() async {
    final controller = TextEditingController();
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
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom + AppSpacing.page,
          ),
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
                    // Yazarken kanonik biçime çeker: kullanıcı `zkx8wy`
                    // yazsa da alanda `ZK-X8WY` görünür, yani gönderilen
                    // kodun doğru olduğunu göndermeden önce görür.
                    inputFormatters: const [_RoomCodeInputFormatter()],
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: context.t(K.roomCode),
                      prefixIcon: const Icon(AppIcons.doorOpen),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.t(K.roomCodeRequired);
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
                            controller.text.trim(),
                          );
                          if (!sheetCtx.mounted) return;
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
                            SnackBar(content: Text(context.t(K.roomNotFound))),
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
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // 2026-07-24: karo ızgarası + gradyan panel yarışı bitti. Ekranda tek
    // gradyan var (hızlı düello), diğer modlar eşit ağırlıkta sade satır.
    return ColoredBox(
      color: AppTheme.bgOf(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            // Ekran altı eşit ağırlıkta satırdan oluşan bir menü gibi
            // duruyordu; yeni kullanıcı hangisinin "asıl oyun" olduğunu
            // seçemiyordu (2026-07-25 canlı denetimi). Artık tek birincil
            // eylem (hızlı düello) ve altında iki adlandırılmış grup var.
            _PlaySectionHeading(
              title: context.t(K.playTitle),
              subtitle: context.t(K.playSubtitle),
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
            AppRowCard(
              key: const ValueKey('play-hub-create-room'),
              icon: AppIcons.circlePlus,
              // Marka paleti dışına çıkan son iki yüzey buydu. `shop_screen`
              // M24 notu playPink/playPurple'ı 2026-07-23'te "marka dışı"
              // ilan etmiş, eşleşme ekranı 2026-07-31'de düzeltilmişti; ama
              // kararın verildiği ekranın *kendisi* atlanmıştı. Oyun
              // merkezinde dört satır yan yana duruyor, yani sapma en çok
              // burada görünüyordu: mor ve pembe, turuncu-altın-yeşil
              // kimliğin yanında yabancı kalıyordu (2026-08-01, iOS canlı).
              accent: AppTheme.culturalBrandBg,
              title: context.t(K.createRoom),
              subtitle: context.t(K.createRoomSub),
              trailing: _roomActionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _roomActionLoading ? null : _createOnlineRoom,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('play-hub-join-room'),
              icon: AppIcons.doorOpen,
              accent: AppTheme.playCyan,
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
            AppRowCard(
              key: const ValueKey('play-hub-daily-contest'),
              icon: AppIcons.bolt,
              accent: AppTheme.gold,
              title: context.t(K.dailyContest),
              subtitle: context.t(K.tenQuestions),
              trailing: _dailyLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _dailyLoading ? null : _openDailyQuiz,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('play-hub-tournament'),
              icon: AppIcons.trophy,
              // Altın bir satır yukarıda "Günün Etkinliği"nde; turnuva
              // marka turuncusunu alır. Dört satır artık koyu yeşil ·
              // çamurlu turkuaz · altın · turuncu — hepsi palet içinde,
              // yine de birbirinden ayrılıyor.
              accent: AppTheme.brand,
              title: context.t(K.tournament),
              subtitle: context.t(K.tournamentSub),
              onTap: () => Navigator.of(context).push(
                AppRoute.to(TournamentScreen(repository: widget.repository)),
              ),
            ),
            // Mağaza satırı buradan kaldırıldı: aynı ekrana Yarış
            // sekmesinden, profilden ve kendi rotasından olmak üzere üç
            // ayrı giriş vardı ve "burası neresi?" hissi yaratıyordu
            // (2026-07-25 canlı denetimi). Tek ev profildeki HESAP bölümü.
          ],
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.culturalBrandBg, Color(0xFF1E6B4C)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(K.quickDuel),
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t(K.quickDuelSub),
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
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

/// Oda kodu alanını yazılırken kanonik biçime çeker.
///
/// Kullanıcının gördüğü kod `ZK-X8WY`; elle yazarken tireyi atlamak,
/// küçük harf kullanmak ya da araya boşluk koymak olağandır. Biçimlendirici
/// olmadan bunların hepsi "oda bulunamadı" ile dönüyordu.
class _RoomCodeInputFormatter extends TextInputFormatter {
  const _RoomCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeRoomCode(newValue.text);
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
