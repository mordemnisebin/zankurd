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
    this.streak = 0,
    this.streakSemanticLabel,
    this.onStreakTap,
    this.goalDone,
    this.goalTarget,
    super.key,
  });

  final bool isKu;
  final List<DailyMission> missions;
  final bool loading;
  final bool compact;
  final void Function(DailyMission mission)? onClaimReward;

  /// Seri (gün). Yalnız kompakt "Bugün" panelinde, panelin en üstünde çip
  /// olarak durur; 0 iken çizilmez (sıfır sayaç bilgi değil, boş kalıptır).
  final int streak;
  final String? streakSemanticLabel;
  final VoidCallback? onStreakTap;

  /// Günlük hedef (bugünkü doğru cevap sayısı / hedef). Ayrı bir sayaç
  /// DEĞİL, listenin bir satırıdır; ödülü yoktur. Günün görevlerinden biri
  /// zaten "N doğru cevap ver" ise o görev hedefin kendisidir ve ikinci bir
  /// satır eklenmez (aynı sayı iki kez görünmesin).
  final int? goalDone;
  final int? goalTarget;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Günlük hedef listenin bir satırı olur (bkz. [goalDone]).
    final hasAnswerMission = missions.any(
      (m) => m.type == MissionType.answerCorrect,
    );
    final goalTargetValue = goalTarget ?? 0;
    final goalRow =
        compact && !hasAnswerMission && goalDone != null && goalTargetValue > 0
        ? DailyMission(
            type: MissionType.answerCorrect,
            target: goalTargetValue,
            coinReward: 0,
            progress: goalDone!.clamp(0, goalTargetValue),
            completed: goalDone! >= goalTargetValue,
            claimed: true,
          )
        : null;
    // Tur 2 R8: kompakt "Bugün" en çok ÜÇ satır (hedef satırı + görevler);
    // fazlası ana sayfayı uzatıyordu, tam liste Günün turu/Görevler'de.
    final everything = [?goalRow, ...missions];
    final all = compact ? everything.take(3).toList() : everything;
    final completedCount = all.where((m) => m.completed).length;
    final totalProgress = all.isEmpty ? 0.0 : completedCount / all.length;
    // Kompakt "Bugün" panelinde bütün satırlar görünür: tek liste, tek
    // özet. Eskiden yalnız 2 açık görev çizilip kalanı "N görev daha"
    // diye sayılıyordu; sayaç ve liste hep ayrı okunuyordu.
    final visible = compact ? all : missions;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const SkeletonLoader(count: 2, height: 44, borderRadius: 8)
        else ...[
          if (compact && streak > 0) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SahneStatChip(
                key: const ValueKey('home-today-streak'),
                leading: const SahneGlyph(SahneGlyphKind.flame),
                label: '$streak ${Tr.forKu(K.streakDayUnit, isKu)}',
                tint: t.warmFill,
                foreground: t.warmTx,
                semanticLabel: streakSemanticLabel,
                onTap: onStreakTap,
              ),
            ),
            const SizedBox(height: SahneSpace.x2),
          ],
          SahneProgressBar(
            key: const ValueKey('daily-missions-overall-progress'),
            value: totalProgress,
            trailing: compact
                ? Tr.forKu(K.todaySummary, isKu, {
                    'done': '$completedCount',
                    'total': '${all.length}',
                  })
                : '$completedCount/${all.length} ${Tr.forKu(K.tamamlandi, isKu)}',
            semanticLabel: Tr.forKu(
              compact ? K.contestToday : K.gunlukGorevler,
              isKu,
            ),
          ),
          if (visible.isNotEmpty) ...[
            if (compact) const SizedBox(height: SahneSpace.x1),
            for (final m in visible)
              if (compact)
                _CompactMissionRow(
                  mission: m,
                  isKu: isKu,
                  onClaim: onClaimReward,
                  isGoal: identical(m, goalRow),
                )
              else
                _MissionTile(
                  mission: m,
                  isKu: isKu,
                  compact: compact,
                  onClaim: onClaimReward,
                  isGoal: identical(m, goalRow),
                ),
            if (compact && completedCount == all.length) ...[
              const SizedBox(height: SahneSpace.x3),
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
      ],
    );

    if (compact) {
      return Column(
        key: const ValueKey('home-missions-compact-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SahneSectionHeader(title: Tr.forKu(K.contestToday, isKu)),
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
    this.isGoal = false,
  });

  /// Günlük hedef satırı: ödülsüz, alınacak bir şey yok.
  final bool isGoal;

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
    if (isGoal) {
      trailing = const SizedBox.shrink();
    } else if (!isDone) {
      // U11 (2026-10-28 tur 4): ana sayfa "Bugün" panelinde hedef tamamlanana
      // kadar XP rozeti YOK (üç görevde üç altın rozet panelin sesini
      // yükseltiyordu); ödül yalnız alınabilir olunca, "Ödülü al" ile görünür.
      trailing = compact
          ? const SizedBox.shrink()
          : SahneBadge(
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
            //
            // Sağ öğe satırın en çok yarısını alır, sığmazsa küçülür:
            // 320 px + yazı ölçeği 2'de "Ödül al" çipi ikon + etiketle
            // kendi doğal genişliğinde kalıp satırı 14 px taşırıyordu
            // (2026-10-24; ilk oturum bu kartı göstermediği için taşma
            // ana ekran taşma testlerinde sessiz kalmıştı).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.4,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: canClaim ? trailing : ExcludeSemantics(child: trailing),
              ),
            ),
          ],
        ),
        const SizedBox(height: SahneSpace.x2),
        ExcludeSemantics(
          child: SahneProgressBar(
            value: ratio,
            trailing: compact && mission.target <= 1
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

/// Ana sayfa "Bugün" panelinin sade satırı (2026-10-28 kurul K4): ikon · kısa
/// ad · sağda tek sayı. Satır başı ilerleme çubuğu ve "+N XP" rozeti yok
/// (panelin üstündeki genel çubuk yeter); ödül yalnız ALINABİLİRKEN tek
/// kompakt eylem olarak çıkar, bitmiş görev onay işareti gösterir.
class _CompactMissionRow extends StatelessWidget {
  const _CompactMissionRow({
    required this.mission,
    required this.isKu,
    this.onClaim,
    this.isGoal = false,
  });

  final DailyMission mission;
  final bool isKu;
  final bool isGoal;
  final void Function(DailyMission mission)? onClaim;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = isKu ? mission.labelKu : mission.labelTr;
    final done = mission.completed;
    final canClaim = done && !mission.claimed && onClaim != null;
    final count =
        '${mission.progress.clamp(0, mission.target)}/${mission.target}';
    final Widget trailing;
    if (canClaim) {
      trailing = KeyedSubtree(
        key: ValueKey('claim-mission-${mission.missionKey}'),
        child: SahneStatChip(
          gold: true,
          leading: const SahneGlyph(SahneGlyphKind.coin),
          label: context.t(K.missionClaimAction),
          onTap: () => onClaim!(mission),
        ),
      );
    } else if (done) {
      trailing = ExcludeSemantics(
        child: Icon(AppIcons.circleCheck, size: 22, color: t.okTx),
      );
    } else {
      trailing = ExcludeSemantics(
        child: Text(count, style: SahneType.bodyStrong.copyWith(color: t.tx2)),
      );
    }
    return Padding(
      key: ValueKey('home-mission-row-${mission.type.name}'),
      padding: const EdgeInsets.only(top: SahneSpace.x2),
      child: Semantics(
        container: true,
        label: label,
        value: done ? Tr.forKu(K.tamamlandi, isKu) : count,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              ExcludeSemantics(
                child: _IconTile(
                  icon: done
                      ? AppIcons.check
                      : _MissionTile._missionIcon(mission.type),
                  size: 36,
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(
                      color: done ? t.tx2 : t.tx,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
