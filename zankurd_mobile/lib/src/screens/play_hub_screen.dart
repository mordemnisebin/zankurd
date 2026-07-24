import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'contest_screen.dart';
import '../widgets/app_row_card.dart';
import 'matchmaking_screen.dart';
import 'room_screen.dart';
import 'shop_screen.dart';
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
      // Her zaman ContestScreen'e yönlendir; contest yoksa ekran kendisi
      // boş durum mesajı gösterir ("Hîn çalakî tune"). Eskiden contest
      // null olduğunda sessizce generic quiz başlatılıyordu — bu, kullanıcının
      // günlük yarışmaya katıldığını sanmasına yol açıyordu.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Ode nehate vekirin. Têkiliya xwe kontrol bike.',
              'Oda açılamadı. Bağlantını kontrol et.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  /// Oda kurucusunun her soru için tanımlı süreyi seçmesini sağlar. Bu ayar
  /// yalnızca UI'da eksikti — repository/DB katmanı zaten `secondsPerQuestion`
  /// alanını destekliyordu (2026-07-21 denetiminde bulunan boşluk).
  Future<int?> _pickRoomDuration() async {
    final ku = context.isKu;
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
                      ku ? 'Ji bo her pirsê dem' : 'Soru başına süre',
                      style: AppTypography.heading1.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ku
                          ? 'Ev dem ji bo hemû lîstikvanên vê odeyê derbasdar e.'
                          : 'Bu süre odadaki tüm oyuncular için geçerli olur.',
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
                        child: Text(ku ? 'Odeyê Veke' : 'Odayı Aç'),
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
    final ku = context.isKu;
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
                    ku ? 'Tevlî Odeyê Bibe' : 'Odaya Katıl',
                    style: AppTypography.heading1.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ku
                        ? 'Koda odeyê binivîse û bi hevalên xwe re bilîze.'
                        : 'Oda kodunu yaz ve arkadaşlarınla oyna.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('play-hub-join-room-code-field'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: ku ? 'Koda odeyê' : 'Oda kodu',
                      prefixIcon: const Icon(AppIcons.doorOpen),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return ku ? 'Kod pêwîst e' : 'Kod zorunlu';
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
                            SnackBar(
                              content: Text(
                                ku
                                    ? 'Odeya bi vê kodê nehate dîtin.'
                                    : 'Bu kodla oda bulunamadı.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(AppIcons.rightToBracket),
                      label: Text(ku ? 'Tevlî bibe' : 'Katıl'),
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
            _PlaySectionHeading(
              title: ku ? 'Pêşbazî' : 'Yarış',
              subtitle: ku
                  ? 'Hevrikê xwe hilbijêre û dest pê bike.'
                  : 'Rakibini seç ve başla.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickDuelHero(
              ku: ku,
              onTap: () => Navigator.of(context).push(
                AppRoute.to(MatchmakingScreen(repository: widget.repository)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('play-hub-create-room'),
              icon: AppIcons.circlePlus,
              accent: AppTheme.playPurple,
              title: ku ? 'Oda ava bike' : 'Oda Kur',
              subtitle: ku
                  ? 'Hevalên xwe bi kodê vexwîne'
                  : 'Arkadaşlarını kodla çağır',
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
              title: ku ? 'Kodê tevlî bibe' : 'Kodla Katıl',
              subtitle: ku ? 'Koda odeyê ya 6 tîpî' : '6 haneli oda kodu',
              onTap: _showJoinSheet,
            ),
            const SizedBox(height: AppSpacing.md),
            _PlaySectionHeading(
              title: ku ? 'Çalakî' : 'Etkinlikler',
              subtitle: ku ? 'Her roj nû dibe.' : 'Her gün yenilenir.',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppRowCard(
              key: const ValueKey('play-hub-daily-contest'),
              icon: AppIcons.bolt,
              accent: AppTheme.gold,
              title: ku ? 'Pêşbirka Rojê' : 'Günün Yarışması',
              subtitle: ku ? '10 pirs' : '10 soru',
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
              accent: AppTheme.playPink,
              title: ku ? 'Kûpa' : 'Turnuva Modu',
              subtitle: ku ? 'Elemeya 8 kesan' : '8 kişilik eleme',
              onTap: () => Navigator.of(context).push(
                AppRoute.to(TournamentScreen(repository: widget.repository)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppRowCard(
              key: const ValueKey('play-hub-shop-card'),
              icon: AppIcons.store,
              accent: AppTheme.playGreen,
              title: ku ? 'Dukan û joker' : 'Mağaza ve jokerler',
              subtitle: ku
                  ? 'Coin, çerx û mafên joker'
                  : 'Coin, çark ve joker hakların',
              onTap: () => Navigator.of(
                context,
              ).push(AppRoute.to(ShopScreen(repository: widget.repository))),
            ),
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
                  ku ? 'Duelo bi lez' : 'Hızlı düello',
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  ku
                      ? 'Hevrikekî di asta te de · ~2 deqe'
                      : 'Seviyene yakın rakip · ~2 dakika',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    ku ? 'Hevrik bibîne' : 'Rakip bul',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppTheme.culturalBrandBg,
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
