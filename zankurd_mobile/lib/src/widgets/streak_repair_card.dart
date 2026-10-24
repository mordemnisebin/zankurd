import 'package:flutter/material.dart';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../services/streak_repair_service.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// "Seriyi geri al" kartı: kırılan serinin son 24 saatte onarım teklifi.
///
/// Kart kendi durumunu taşır (yükleniyor / hata); onarım
/// [StreakRepairService] üzerinden yürür: sunucu onayı olmadan yerel seri
/// değişmez. Başarıda [onRepaired] yeni seri değeriyle çağrılır.
class StreakRepairCard extends StatefulWidget {
  const StreakRepairCard({
    required this.store,
    required this.repository,
    required this.offer,
    required this.onRepaired,
    this.onLater,
    this.premium,
    this.now,
    super.key,
  });

  final StreakStore store;
  final ZanKurdRepository repository;
  final StreakRepairOffer offer;
  final ValueChanged<int> onRepaired;

  /// Verilirse "Niha na" düğmesi çizilir (açılış sayfasında).
  final VoidCallback? onLater;

  /// Premium bayrağı; verilmezse [PremiumService] okunur (testte enjekte).
  final bool? premium;

  final DateTime? now;

  @override
  State<StreakRepairCard> createState() => _StreakRepairCardState();
}

class _StreakRepairCardState extends State<StreakRepairCard> {
  bool _busy = false;
  String? _errorKey;

  bool get _premium =>
      widget.premium ?? (PremiumService.instance?.isPremium ?? false);

  Future<void> _repair() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    final outcome = await StreakRepairService.repair(
      repository: widget.repository,
      store: widget.store,
      offer: widget.offer,
      premium: _premium,
      now: widget.now,
    );
    if (!mounted) return;
    switch (outcome) {
      case StreakRepairOutcome.charged ||
          StreakRepairOutcome.free ||
          StreakRepairOutcome.alreadyRepaired:
        setState(() => _busy = false);
        widget.onRepaired(widget.offer.restoredStreak);
      case StreakRepairOutcome.insufficient:
        setState(() {
          _busy = false;
          _errorKey = K.streakFreezeNoCoins;
        });
      case StreakRepairOutcome.monthlyLimit:
        setState(() {
          _busy = false;
          _errorKey = K.streakRepairMonthly;
        });
      case StreakRepairOutcome.failed:
        setState(() {
          _busy = false;
          _errorKey = K.streakRepairFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = _premium
        ? context.t(K.streakRepairActionFree)
        : context.t(K.streakRepairAction, {
            'cost': '${StreakStore.repairCost}',
          });
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(AppIcons.fire, size: 20, color: t.goldTx),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Text(
                  context.t(K.streakRepairTitle),
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.streakRepairBody, {
              'days': '${widget.offer.lostStreak}',
            }),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            context.t(K.streakRepairHint),
            style: SahneType.caption.copyWith(color: t.tx3),
          ),
          if (_errorKey != null) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(_errorKey!),
              key: const ValueKey('streak-repair-error'),
              style: SahneType.captionStrong.copyWith(color: t.errTx),
            ),
          ],
          const SizedBox(height: SahneSpace.x3),
          SahneButton.primary(
            buttonKey: const ValueKey('streak-repair-action'),
            label: label,
            icon: AppIcons.fire,
            expand: true,
            arrow: false,
            loading: _busy,
            onPressed: _busy ? null : _repair,
          ),
          if (widget.onLater != null) ...[
            const SizedBox(height: SahneSpace.x1),
            Align(
              alignment: Alignment.center,
              child: SahneButton.text(
                buttonKey: const ValueKey('streak-repair-later'),
                label: context.t(K.notifPromptLater),
                arrow: false,
                onPressed: _busy ? null : widget.onLater,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kırılmadan sonraki İLK açılışta bir kez gösterilen onarım sayfası.
///
/// Gösterim `StreakStore.markRepairOfferSeen` ile işlenir; çağıran
/// göstermeden önce işaretler, böylece sayfa kapatılıp tekrar açılmaz.
Future<void> showStreakRepairSheet({
  required BuildContext context,
  required StreakStore store,
  required ZanKurdRepository repository,
  required StreakRepairOffer offer,
  required ValueChanged<int> onRepaired,
  bool? premium,
  DateTime? now,
}) {
  return showSahneSheet<void>(
    context: context,
    title: context.t(K.streakCalendarTitle),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x4),
      child: StreakRepairCard(
        store: store,
        repository: repository,
        offer: offer,
        premium: premium,
        now: now,
        onLater: () => Navigator.of(sheetContext).pop(),
        onRepaired: (days) {
          Navigator.of(sheetContext).pop();
          onRepaired(days);
        },
      ),
    ),
  );
}
