import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/daily_mission.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/sahne/sahne.dart';
import '../../widgets/skeleton_loader.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Günlük görevler.
///
/// 2026-09-29 Şahnê: kompakt görünüm (ana sayfa) tek bölüm başlığı
/// ([SahneSectionHeader]) + yüzey kartıdır; kartın başında genel ilerleme
/// ("1/3 tamamlandı"), altında görev satırları. Satırda ikon karosu
/// Zimrût tonu (görev öğrenme akışının parçası), ilerleme Zimrût çubuğu,
/// ödül Zêr rozeti ("+20 XP"); ödül alma Zêr stat çipi. Tam görünüm
/// (başka ekranlar) aynı içeriği kendi başlığıyla bir panelde çizer.
class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({
    required this.isKu,
    required this.missions,
    this.loading = false,
    this.compact = true,
    this.onClaimReward,
    super.key,
  });

  final bool isKu;
  final List<DailyMission> missions;
  final bool loading;
  final bool compact;
  final void Function(DailyMission mission)? onClaimReward;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final completedCount = missions.where((m) => m.completed).length;
    final totalProgress = missions.isEmpty
        ? 0.0
        : completedCount / missions.length;
    final pending = missions.where((m) => !m.completed || !m.claimed).toList();
    final visible = compact ? pending.take(2).toList() : missions;
    final hiddenDone = compact
        ? missions.where((m) => m.completed && m.claimed).length
        : 0;
    // Compact modda yalnız 2 açık görev çizilir. Başlıktaki sayaç ise tüm
    // görevleri sayar; üçüncü görev listede yokken başlık "0/3" diyor ve
    // eksik satır kayıp gibi görünüyordu (2026-07-25 canlı denetimi).
    // Kırpılan açık görevler artık sayılıp ayrıca belirtilir.
    final hiddenPending = compact ? pending.length - visible.length : 0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const SkeletonLoader(count: 2, height: 44, borderRadius: 8)
        else ...[
          SahneProgressBar(
            key: const ValueKey('daily-missions-overall-progress'),
            value: totalProgress,
            trailing:
                '$completedCount/${missions.length} ${Tr.forKu(K.tamamlandi, isKu)}',
            semanticLabel: Tr.forKu(K.gunlukGorevler, isKu),
          ),
          if (visible.isNotEmpty) ...[
            for (final m in visible)
              _MissionTile(
                mission: m,
                isKu: isKu,
                compact: compact,
                onClaim: onClaimReward,
              ),
            if (hiddenDone > 0 || hiddenPending > 0)
              Text(
                [
                  if (hiddenDone > 0)
                    Tr.forKu(K.pGorevTamam, isKu, {'p0': '$hiddenDone'}),
                  if (hiddenPending > 0)
                    isKu
                        // Kurmancî'de sayı tekilse ad da tekil olur:
                        // "1 erkên din" yanlış, "1 erkê din" doğru.
                        ? (hiddenPending == 1
                              ? '1 erkê din'
                              : '$hiddenPending erkên din')
                        : '$hiddenPending görev daha',
                ].join(' · '),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
          ] else if (missions.isNotEmpty) ...[
            const SizedBox(height: SahneSpace.x3),
            // Durum yalnız renkle verilmez: ✓ + söz birlikte.
            Row(
              children: [
                Icon(AppIcons.circleCheck, size: 16, color: t.okTx),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    Tr.forKu(K.tumGorevlerTamam, isKu),
                    style: SahneType.captionStrong.copyWith(color: t.okTx),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );

    if (compact) {
      return Column(
        key: const ValueKey('home-missions-compact-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SahneSectionHeader(title: Tr.forKu(K.gunlukGorevler, isKu)),
          SahneSurfaceCard(child: body),
        ],
      );
    }
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconTile(
                key: ValueKey('daily-missions-header-icon'),
                icon: AppIcons.circleCheck,
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    Tr.forKu(K.gunlukGorevler, isKu),
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x3),
          body,
        ],
      ),
    );
  }
}

/// Zimrût tonlu M pahlı ikon karosu (liste satırının öncülüyle aynı dil).
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.size = 44, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.learnTint, shape: SahneShape.m),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size >= 44 ? 24 : 20, color: t.learnTx),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.isKu,
    this.compact = false,
    this.onClaim,
  });

  final DailyMission mission;
  final bool isKu;
  final bool compact;
  final void Function(DailyMission mission)? onClaim;

  /// Görev tipini tek tip bayrak yerine anlamlı bir ikonla gösterir.
  static IconData _missionIcon(MissionType type) {
    return switch (type) {
      MissionType.answerCorrect => AppIcons.bullseye,
      MissionType.completeQuiz => AppIcons.trophy,
      MissionType.useWildcard => AppIcons.wandMagicSparkles,
      MissionType.keepStreak => AppIcons.fire,
      MissionType.playCategory => AppIcons.tableCells,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final ratio = (mission.progress / mission.target).clamp(0.0, 1.0);
    final label = isKu ? mission.labelKu : mission.labelTr;
    final isDone = mission.completed;
    final canClaim = isDone && !mission.claimed && onClaim != null;

    final Widget trailing;
    if (!isDone) {
      trailing = SahneBadge(
        label: '+${mission.xpReward} XP',
        tone: SahneBadgeTone.gold,
      );
    } else if (canClaim) {
      trailing = KeyedSubtree(
        key: ValueKey('claim-mission-${mission.missionKey}'),
        child: SahneStatChip(
          gold: true,
          leading: const SahneGlyph(SahneGlyphKind.coin),
          label: context.t(K.missionClaimAction),
          onTap: () => onClaim!(mission),
        ),
      );
    } else {
      trailing = SahneBadge(
        label: context.t(K.missionClaimed),
        tone: SahneBadgeTone.learn,
      );
    }

    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: _IconTile(
                icon: isDone ? AppIcons.check : _missionIcon(mission.type),
                size: 36,
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: SahneType.bodyStrong.copyWith(
                    color: isDone ? t.tx2 : t.tx,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: isDone ? t.tx2 : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            // Ödül al düğmesi kendi düğümünü taşır; satırın özetine girmez.
            if (canClaim) trailing else ExcludeSemantics(child: trailing),
          ],
        ),
        const SizedBox(height: SahneSpace.x2),
        ExcludeSemantics(
          child: SahneProgressBar(
            value: ratio,
            trailing: compact
                ? null
                : '${mission.progress.clamp(0, mission.target)} / ${mission.target}',
          ),
        ),
      ],
    );

    // Görev karosu; ilerleme ve ödül ayrı metin düğümleriydi. Tek düğümde
    // "görev · ilerleme · durum" olarak duyurulur (2026-07-25 denetimi).
    return Padding(
      key: ValueKey('home-mission-row-${mission.type.name}'),
      padding: const EdgeInsets.only(top: SahneSpace.x4),
      child: Semantics(
        container: true,
        label: label,
        value: isDone
            ? (Tr.forKu(K.tamamlandi, isKu))
            : '${mission.progress}/${mission.target}',
        child: tile,
      ),
    );
  }
}
