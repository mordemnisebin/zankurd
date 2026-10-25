import 'package:flutter/material.dart';

import '../../data/streak_store.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/sahne/sahne.dart';

/// Profilde son yedi günün etkinlik şeridi: oynanan gün dolu (✓), seri
/// dondurmasıyla korunan gün kalkanlı, bugün çerçeveli.
///
/// 2026-10-25 (kurul: Codex + Gemini 4 Argon, profil 6–7/10): profil yeni
/// oyuncuda yalnız boş durumlardan oluşuyordu; ilerleme ve alışkanlık hiçbir
/// yerde görünmüyordu (Duolingo/Busuu haftalık şerit kalıbı). Gün adları
/// yerine tarih numarası yazılır: kısaltma iki dilde ayrı çeviri isterdi ve
/// tarih zaten aynı bilgiyi verir.
class ProfileWeekStrip extends StatefulWidget {
  const ProfileWeekStrip({super.key, this.clock, this.loader});

  /// Testler için saat.
  final DateTime Function()? clock;

  /// Testler için veri kaynağı: (oynanan günler, dondurulan günler).
  final Future<(Set<String>, Set<String>)> Function()? loader;

  @override
  State<ProfileWeekStrip> createState() => _ProfileWeekStripState();
}

class _ProfileWeekStripState extends State<ProfileWeekStrip> {
  late final Future<(Set<String>, Set<String>)> _days = _load();

  Future<(Set<String>, Set<String>)> _load() async {
    final loader = widget.loader;
    if (loader != null) return loader();
    try {
      final store = await StreakStore.load();
      return (store.playedDays, store.frozenDays);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile week strip');
      return (<String>{}, <String>{});
    }
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final now = (widget.clock ?? DateTime.now)();
    final today = DateTime(now.year, now.month, now.day);
    // Takvim günü aritmetiği (yaz saati geçişinde 24 saat çıkarmak günü
    // kaçırır).
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    return FutureBuilder<(Set<String>, Set<String>)>(
      future: _days,
      builder: (context, snapshot) {
        final played = snapshot.data?.$1 ?? const <String>{};
        final frozen = snapshot.data?.$2 ?? const <String>{};
        final activeCount = days.where((d) => played.contains(_key(d))).length;
        return SahneSurfaceCard(
          key: const ValueKey('profile-week-strip'),
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.x4,
            SahneSpace.x3,
            SahneSpace.x4,
            SahneSpace.x3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIcons.fire, size: 18, color: t.learnTx),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      context.t(K.lastSevenDays),
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                  ),
                  Text(
                    '$activeCount/7',
                    key: const ValueKey('profile-week-count'),
                    style: SahneType.captionStrong.copyWith(
                      color: t.tx2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SahneSpace.x3),
              Row(
                children: [
                  for (final d in days)
                    Expanded(
                      child: _DayCell(
                        day: d.day,
                        played: played.contains(_key(d)),
                        frozen: frozen.contains(_key(d)),
                        today: d == today,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.played,
    required this.frozen,
    required this.today,
  });

  final int day;
  final bool played;
  final bool frozen;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fill = played
        ? t.learnTx
        : frozen
        ? t.nilTint
        : t.s2;
    final edge = today ? t.learnTx : (played ? t.learnTx : t.edge);
    return Semantics(
      label: '$day',
      value: played ? '✓' : (frozen ? '❄' : ''),
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: fill,
              shape: SahneShape.withSide(
                SahneShape.s,
                edge,
                width: today ? 2 : 1,
              ),
            ),
            child: played
                ? Icon(AppIcons.check, size: 18, color: t.learnTint)
                : frozen
                ? Icon(AppIcons.shield, size: 16, color: t.nilTx)
                : null,
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            '$day',
            style: SahneType.caption.copyWith(
              color: today ? t.learnTx : t.tx3,
              fontWeight: today ? FontWeight.w700 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
