import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'contest_screen.dart';
import 'home/quick_play_grid.dart';
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
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            // Büyük 'Pêşbazî' tanıtım kartı kaldırıldı — bölüm başlığı
            // ekranı tanıtmaya yeter.
            _PlaySectionHeading(
              title: ku
                  ? 'Çawa dixwazî pêşbaz bibî?'
                  : 'Nasıl yarışmak istersin?',
              subtitle: ku
                  ? 'Yek ji modan hilbijêre û dest pê bike.'
                  : 'Bir mod seç ve başla.',
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickPlayGrid(
              isKu: ku,
              dailyQuizLoading: _dailyLoading,
              onDuel: () => Navigator.of(context).push(
                AppRoute.to(MatchmakingScreen(repository: widget.repository)),
              ),
              onDailyQuiz: _openDailyQuiz,
              onTournament: () => Navigator.of(context).push(
                AppRoute.to(TournamentScreen(repository: widget.repository)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _GroupPlayPanel(
              ku: ku,
              loading: _roomActionLoading,
              onCreateRoom: _createOnlineRoom,
              onJoinRoom: _showJoinSheet,
            ),
            const SizedBox(height: AppSpacing.md),
            _SupportActions(
              ku: ku,
              onOpenShop: () => Navigator.of(
                context,
              ).push(AppRoute.to(ShopScreen(repository: widget.repository))),
            ),
          ],
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

class _GroupPlayPanel extends StatelessWidget {
  const _GroupPlayPanel({
    required this.ku,
    required this.loading,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool ku;
  final bool loading;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      key: const ValueKey('play-hub-group-panel'),
      // Remove hardcoded gradient to use standard surface color
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.playCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
                  border: Border.all(
                    color: AppTheme.playCyan.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  AppIcons.peopleGroup,
                  color: AppTheme.playCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku
                          ? 'Bi heval an komê re bilîze'
                          : 'Arkadaşınla veya grupla oyna',
                      style: AppTypography.heading2.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ku
                          ? 'Odeyek veke, kodê parve bike, hevalên xwe vexwîne.'
                          : 'Oda aç, kodu paylaş, arkadaşlarını davet et.',
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('play-hub-create-room'),
                  onPressed: loading ? null : onCreateRoom,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand,
                    foregroundColor: Colors.white,
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(AppIcons.circlePlus, size: 20),
                  label: Text(
                    loading
                        ? (ku ? 'Tê Vekirin...' : 'Açılıyor...')
                        : (ku ? 'Odeyek Ava Bike' : 'Oda Kur'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('play-hub-join-room'),
                  onPressed: onJoinRoom,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.borderColor(context),
                      width: 1.5,
                    ),
                    foregroundColor: AppTheme.textPrimaryColor(context),
                  ),
                  icon: const Icon(AppIcons.doorOpen, size: 20),
                  label: Text(
                    ku ? 'Kodê tevlî bibe' : 'Kodla Katıl',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportActions extends StatelessWidget {
  const _SupportActions({required this.ku, required this.onOpenShop});

  final bool ku;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      key: const ValueKey('play-hub-shop-card'),
      icon: AppIcons.store,
      color: AppTheme.gold,
      title: ku ? 'Dukan û joker' : 'Mağaza ve jokerler',
      subtitle: ku
          ? 'Coin, çerx û mafên joker li yek derê.'
          : 'Coin, çark ve joker hakların tek yerde.',
      onTap: onOpenShop,
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textSubColor(context),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(AppIcons.chevronRight, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
