import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';

/// Kalan bekleme süresini "12 sa sonra tekrar" / "35 dk sonra tekrar"
/// metnine çevirir. Saat YUKARI yuvarlanır: dürttükten hemen sonra kalan
/// 11 sa 59 dk, "11" değil "12 sa" okunur (sunucunun kuralı 12 saattir).
String asyncDuelNudgeCooldownLabel(BuildContext context, Duration left) {
  if (left.inMinutes >= 60) {
    final hours = (left.inMinutes / 60).ceil();
    return context.t(K.nudgeCooldownHours, {'n': '$hours'});
  }
  final minutes = (left.inSeconds / 60).ceil().clamp(1, 59);
  return context.t(K.nudgeCooldownMinutes, {'n': '$minutes'});
}

/// "Rakip bekleniyor" satırındaki "Dürt" düğmesi.
///
/// Etkin: rakibe "sıra sende" bildirimi gönderir (`nudge_async_duel`).
/// Dürttükten sonra düğme pasif kalır ve kalan süreyi yazar ("12 sa sonra
/// tekrar"); sunucu 12 saatte en çok bir dürtmeye izin verir, istemci
/// bekleme süresini `my_nudged_at`tan hesaplar.
///
/// Hata (ağ, engel, süre bitti): oyuncuya tek cümle söylenir, düğme etkin
/// kalır. 12 saat dolmadan ikinci istek ("cooldown": başka cihazdan dürtmüş)
/// [onChanged] ile listeyi tazeletir ki gerçek bekleme süresi görünsün.
class AsyncDuelNudgeButton extends StatefulWidget {
  const AsyncDuelNudgeButton({
    required this.repository,
    required this.summary,
    this.onChanged,
    this.clock = DateTime.now,
    super.key,
  });

  final ZanKurdRepository repository;
  final AsyncDuelSummary summary;

  /// Sunucu durumu değişti (dürtme gitti ya da beklenmedik ret): liste
  /// yeniden çekilebilir.
  final VoidCallback? onChanged;

  /// Test için sabit saat.
  final DateTime Function() clock;

  @override
  State<AsyncDuelNudgeButton> createState() => _AsyncDuelNudgeButtonState();
}

class _AsyncDuelNudgeButtonState extends State<AsyncDuelNudgeButton> {
  bool _sending = false;

  /// Bu oturumda gönderdiğim dürtme; liste tazelenene dek sunucu değerinin
  /// önüne geçer.
  DateTime? _localNudgedAt;

  Duration? _cooldownLeft() {
    final now = widget.clock();
    final local = _localNudgedAt;
    if (local != null) {
      final left = local.add(asyncDuelNudgeCooldown).difference(now);
      if (left > Duration.zero) return left;
    }
    return widget.summary.nudgeCooldownLeft(now);
  }

  Future<void> _nudge() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final sentText = context.t(K.nudgeSent);
    final failedText = context.t(K.nudgeFailed);
    try {
      final at = await widget.repository.nudgeAsyncDuel(widget.summary.duelId);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _localNudgedAt = at;
      });
      messenger?.showSnackBar(SnackBar(content: Text(sentText)));
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      final kind = classifyAsyncDuelNudgeError(error);
      messenger?.showSnackBar(SnackBar(content: Text(failedText)));
      if (kind != AsyncDuelNudgeError.other) widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _cooldownLeft();
    final cooling = left != null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SahneButton.text(
        buttonKey: const ValueKey('async-duel-nudge-button'),
        label: cooling
            ? asyncDuelNudgeCooldownLabel(context, left)
            : context.t(K.nudgeAction),
        icon: AppIcons.bolt,
        arrow: false,
        // Pasif: bekleme sürerken ya da istek giderken dokunuş yok.
        onPressed: cooling || _sending ? null : () => unawaited(_nudge()),
      ),
    );
  }
}
