import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/streak_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../widgets/sahne/sahne.dart';

/// Home üzerindeki ikincil eylemler için düz satır.
///
/// Ana günlük görev ve konu ızgarası görsel omurgayı taşır. Bu satır ise
/// ikincil gezinme hedeflerini ayrı ayrı "kart" gibi yükseltmeden erişilebilir
/// ve dokunulabilir tutar.
///
/// 2026-09-29 Şahnê: tek satırlık liste grubu ([SahneListGroup] +
/// [SahneListRow.icon]); renk yalnız ikon karosunun rol tonunda ([role]).
class HomeSupportRow extends StatelessWidget {
  const HomeSupportRow({
    required this.icon,
    required this.role,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.surfaceKey,
    super.key,
  });

  final IconData icon;
  final SahneRole role;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    return SahneListGroup(
      key: surfaceKey,
      children: [
        SahneListRow.icon(
          icon: icon,
          role: role,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          chevron: onTap != null,
          enabled: onTap != null,
          onTap: onTap,
          semanticLabel: subtitle == null ? title : '$title. $subtitle',
        ),
      ],
    );
  }
}

/// Bir kategorideki ustalık ilerlemesi (MasteryStore verisinden türetilir).
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.correct,
    required this.threshold,
  });

  final String category;
  final int correct;
  final int threshold;

  double get ratio =>
      threshold <= 0 ? 0 : (correct / threshold).clamp(0.0, 1.0);
}

/// A iskeletinin marka satırındaki stat çipleri: seri (alev) ve jeton.
///
/// 2026-09-29 Şahnê: dört sekmenin HEPSİ aynı marka satırını taşır —
/// sekme geçişinde üst alan zıplamaz. Ana sayfa seri ve jetonu zaten
/// kendi durumunda tutar ve çipleri dokunulabilir çizer (seri → seri
/// paneli, jeton → mağaza). Öteki sekmeler (Yarış, Sıralama, Profil) bu
/// sayıları hiç yüklemiyordu; bu bileşen onları kendisi okur ve çipleri
/// YALNIZ GÖSTERİR — o sekmelere yeni bir gezinme hedefi eklenmez.
///
/// Okuma başarısızsa çip görünmez (uydurma "0" yazılmaz); sayılar süstür,
/// sekmenin kendisi onlara bağlı değil.
class TabStatChips extends StatefulWidget {
  const TabStatChips({required this.repository, this.refreshSignal, super.key});

  final ZanKurdRepository repository;

  /// Sekmeye dönüldüğünde sayıları tazeler (kabuğun sekme sinyali).
  final Listenable? refreshSignal;

  @override
  State<TabStatChips> createState() => _TabStatChipsState();
}

class _TabStatChipsState extends State<TabStatChips> {
  int? _streak;
  int? _coins;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    widget.refreshSignal?.addListener(_onRefresh);
  }

  @override
  void didUpdateWidget(covariant TabStatChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_onRefresh);
      widget.refreshSignal?.addListener(_onRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() => unawaited(_load());

  Future<void> _load() async {
    int? streak;
    int? coins;
    try {
      streak = (await StreakStore.load()).effectiveStreak();
    } on Object {
      streak = null;
    }
    try {
      coins = await widget.repository.loadCoinBalance();
    } on Object {
      coins = null;
    }
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _coins = coins;
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = _streak;
    final coins = _coins;
    return Wrap(
      spacing: SahneSpace.x2,
      runSpacing: SahneSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (streak != null) streakStatChip(context, streak),
        if (coins != null) coinStatChip(context, coins),
      ],
    );
  }
}

/// Seri çipi: alev glifi + "N gün". Ekran okuyucu "Günlük seri: N gün".
Widget streakStatChip(BuildContext context, int days, {VoidCallback? onTap}) {
  return SahneStatChip(
    leading: const SahneGlyph(SahneGlyphKind.flame),
    label: '$days ${context.t(K.streakDayUnit)}',
    semanticLabel: context.t(K.dailyStreakDays, {'days': '$days'}),
    onTap: onTap,
  );
}

/// Jeton çipi: jeton glifi + bakiye.
Widget coinStatChip(
  BuildContext context,
  int coins, {
  VoidCallback? onTap,
  String? semanticLabel,
}) {
  return SahneStatChip(
    leading: const SahneGlyph(SahneGlyphKind.coin),
    label: '$coins',
    semanticLabel: semanticLabel ?? '$coins ${context.t(K.coinWord)}',
    onTap: onTap,
  );
}
