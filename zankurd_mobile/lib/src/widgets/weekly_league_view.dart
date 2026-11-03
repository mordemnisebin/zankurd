import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

import '../l10n/strings.dart';
import '../models/weekly_league.dart';
import '../utils/number_format.dart';
import '../utils/player_identity.dart';
import 'player_avatar.dart';
import 'sahne/sahne.dart';

/// Kademe adı (yalın): "Altın", "Gümüş"… Tam ad için [leagueTierTitle].
String leagueTierName(int tier, bool isKu) =>
    Tr.forKu(switch (tier.clamp(0, kLeagueTierCount - 1)) {
      0 => K.lgTierBronze,
      1 => K.lgTierSilver,
      2 => K.lgTierGold,
      3 => K.lgTierDiamond,
      _ => K.lgTierLegend,
    }, isKu);

/// "Altın Lig" / "Lîga Zêr".
String leagueTierTitle(int tier, bool isKu) =>
    Tr.forKu(K.lgLeagueName, isKu, {'tier': leagueTierName(tier, isKu)});

/// Kademe rengi: yalnız süsleme; adı her zaman yazılıdır.
Color leagueTierColor(int tier) =>
    switch (tier.clamp(0, kLeagueTierCount - 1)) {
      0 => const Color(0xFFC77B4A),
      1 => const Color(0xFFB8C4CE),
      2 => const Color(0xFFE0A93B),
      3 => const Color(0xFF4FB3D9),
      _ => const Color(0xFF9B6BD6),
    };

IconData leagueTierIcon(int tier) =>
    switch (tier.clamp(0, kLeagueTierCount - 1)) {
      0 => AppIcons.shieldHalved,
      1 => AppIcons.medal,
      2 => AppIcons.medal,
      3 => AppIcons.gem,
      _ => AppIcons.trophy,
    };

/// Kalan süre: gün+saat, saat+dakika ya da yalnız dakika.
String leagueTimeLeft(int seconds, bool isKu) {
  final s = seconds < 0 ? 0 : seconds;
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) {
    return Tr.forKu(K.lgTimeLeftDays, isKu, {'d': '$d', 'h': '$h'});
  }
  if (h > 0) {
    return Tr.forKu(K.lgTimeLeftHours, isKu, {'h': '$h', 'm': '$m'});
  }
  return Tr.forKu(K.lgTimeLeftMinutes, isKu, {'m': '${m < 1 ? 1 : m}'});
}

/// Haftalık lig gövdesi: kademe kartı, (varsa) geçen hafta sonucu, kümenin
/// sıralaması; çıkma bölgesi yeşil, düşme bölgesi kırmızı. Bölge yalnız renkle
/// anlatılmaz: bölge başlığı yazılıdır. Kendi satırın "Sen" rozetiyle işaretli.
class WeeklyLeagueView extends StatelessWidget {
  const WeeklyLeagueView({
    required this.league,
    required this.isKu,
    required this.onStart,
    this.showResult = true,
    this.onDismissResult,
    super.key,
  });

  final WeeklyLeague league;
  final bool isKu;
  final VoidCallback onStart;
  final bool showResult;
  final VoidCallback? onDismissResult;

  @override
  Widget build(BuildContext context) {
    final result = showResult ? league.lastResult : null;
    return Column(
      key: const ValueKey('league-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          LeagueResultCard(
            result: result,
            isKu: isKu,
            onDismiss: onDismissResult,
          ),
          const SizedBox(height: SahneSpace.cardGap),
        ],
        LeagueTierCard(league: league, isKu: isKu),
        const SizedBox(height: SahneSpace.cardGap),
        if (!league.joined)
          _NotJoined(isKu: isKu, onStart: onStart)
        else
          _Cohort(league: league, isKu: isKu),
      ],
    );
  }
}

/// Ekranın altına sabitlenen "Sen" satırı (kümeye girdiyse).
class LeagueMyRow extends StatelessWidget {
  const LeagueMyRow({required this.league, required this.isKu, super.key});

  final WeeklyLeague league;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    LeagueMember? me;
    for (final m in league.members) {
      if (m.isMe) me = m;
    }
    final rank = league.myRank ?? me?.rank;
    if (!league.joined || rank == null) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final label = Tr.forKu(K.lgYourRank, isKu, {
      'r': groupThousands(rank),
      'p': groupThousands(league.myScore),
    });
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('league-my-row'),
          decoration: BoxDecoration(
            color: t.goldTint,
            border: Border(top: BorderSide(color: t.goldTx, width: 2)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SahneSpace.page,
                vertical: SahneSpace.x2,
              ),
              child: Row(
                children: [
                  SahneBadge(
                    label: Tr.forKu(K.you, isKu),
                    tone: SahneBadgeTone.gold,
                  ),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LeagueTierCard extends StatelessWidget {
  const LeagueTierCard({required this.league, required this.isKu, super.key});

  final WeeklyLeague league;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final color = leagueTierColor(league.tier);
    final title = leagueTierTitle(league.tier, isKu);
    final countdown = leagueTimeLeft(league.secondsLeft, isKu);
    final sub = league.joined && league.myRank != null
        ? Tr.forKu(K.lgYourRank, isKu, {
            'r': groupThousands(league.myRank!),
            'p': groupThousands(league.myScore),
          })
        : null;
    return KeyedSubtree(
      key: const ValueKey('league-tier-card'),
      child: SahneSurfaceCard(
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Row(
          children: [
            DecoratedBox(
              key: const ValueKey('league-tier-badge'),
              decoration: ShapeDecoration(
                color: color.withValues(alpha: 0.18),
                shape: SahneShape.m,
              ),
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  leagueTierIcon(league.tier),
                  color: color,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SahneType.headline.copyWith(color: t.tx)),
                  if (sub != null)
                    Text(
                      sub,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                  Text(
                    countdown,
                    key: const ValueKey('league-countdown'),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Geçen haftanın sonucu ("Altın lige yükseldin!"). Kapatılınca sunucuya
/// "görüldü" yazılır; kart bir daha çıkmaz.
class LeagueResultCard extends StatelessWidget {
  const LeagueResultCard({
    required this.result,
    required this.isKu,
    this.onDismiss,
    super.key,
  });

  final LeagueResult result;
  final bool isKu;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (key, tier, icon, tint, tx) = switch (result.outcome) {
      LeagueOutcome.promoted => (
        K.lgResultPromoted,
        result.toTier,
        AppIcons.chevronUp,
        t.okTint,
        t.okTx,
      ),
      LeagueOutcome.demoted => (
        K.lgResultDemoted,
        result.toTier,
        AppIcons.chevronDown,
        t.errTint,
        t.errTx,
      ),
      LeagueOutcome.stayed => (
        K.lgResultStayed,
        result.toTier,
        AppIcons.medal,
        t.goldTint,
        t.goldTx,
      ),
    };
    final title = Tr.forKu(key, isKu, {'tier': leagueTierName(tier, isKu)});
    final rank = result.rank;
    return KeyedSubtree(
      key: const ValueKey('league-result-card'),
      child: SahneSurfaceCard(
        color: tint,
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tx, size: 24),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    title,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
            if (rank != null && rank > 0) ...[
              const SizedBox(height: SahneSpace.x1),
              Text(
                Tr.forKu(K.lgResultRank, isKu, {'r': groupThousands(rank)}),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ],
            if (onDismiss != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SahneButton.text(
                  key: const ValueKey('league-result-dismiss'),
                  label: Tr.forKu(K.ok, isKu),
                  onPressed: onDismiss,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotJoined extends StatelessWidget {
  const _NotJoined({required this.isKu, required this.onStart});

  final bool isKu;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return KeyedSubtree(
      key: const ValueKey('league-not-joined'),
      child: SahneSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.forKu(K.lgNotJoinedTitle, isKu),
              style: SahneType.headline.copyWith(color: t.tx),
            ),
            const SizedBox(height: SahneSpace.x2),
            Text(
              Tr.forKu(K.lgNotJoinedBody, isKu),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x4),
            SahneButton.primary(
              label: Tr.forKu(K.startRaceAction, isKu),
              onPressed: onStart,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Cohort extends StatelessWidget {
  const _Cohort({required this.league, required this.isKu});

  final WeeklyLeague league;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var promoLabelDone = false;
    var demoLabelDone = false;
    for (final m in league.members) {
      final promo = league.inPromotionZone(m.rank);
      final demo = league.inDemotionZone(m.rank);
      if (promo && !promoLabelDone) {
        promoLabelDone = true;
        children.add(
          _ZoneLabel(
            key: const ValueKey('league-zone-promote'),
            text:
                '${Tr.forKu(K.lgZonePromote, isKu)} · ${Tr.forKu(K.lgPromoteHint, isKu, {'n': groupThousands(league.promoteCount)})}',
            promote: true,
          ),
        );
      }
      if (demo && !demoLabelDone) {
        demoLabelDone = true;
        children.add(
          _ZoneLabel(
            key: const ValueKey('league-zone-demote'),
            text:
                '${Tr.forKu(K.lgZoneDemote, isKu)} · ${Tr.forKu(K.lgDemoteHint, isKu, {'n': groupThousands(league.demoteCount)})}',
            promote: false,
          ),
        );
      }
      children.add(_LeagueRow(member: m, isKu: isKu, promo: promo, demo: demo));
    }
    final group = SahneListGroup(
      key: const ValueKey('league-cohort'),
      dividerIndent: SahneSpace.x3 + 24 + SahneSpace.x3,
      children: children,
    );
    // Küçük küme (< 4 oyuncu): sunucu bölge boyutunu 0 verir, bölge
    // etiketleri hiç çıkmaz ve oyuncu yükselme/düşme kuralının var olduğunu
    // bile göremezdi. Kural cümlesi açıkça yazılır (2026-11-04, ikinci tur).
    if (league.cohortSize >= 4 || league.members.isEmpty) return group;
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: SahneSpace.x2),
          child: Text(
            Tr.forKu(K.lgZonesPending, isKu),
            key: const ValueKey('league-zones-pending'),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
        group,
      ],
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.text, required this.promote, super.key});

  final String text;
  final bool promote;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final tx = promote ? t.okTx : t.errTx;
    return ColoredBox(
      color: promote ? t.okTint : t.errTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x3,
          vertical: SahneSpace.x2,
        ),
        child: Row(
          children: [
            Icon(
              promote ? AppIcons.chevronUp : AppIcons.chevronDown,
              color: tx,
              size: 18,
            ),
            const SizedBox(width: SahneSpace.x2),
            Expanded(
              child: Text(
                text,
                style: SahneType.captionStrong.copyWith(color: tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.member,
    required this.isKu,
    required this.promo,
    required this.demo,
  });

  final LeagueMember member;
  final bool isKu;
  final bool promo;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final name = PlayerIdentity.resolveNameWithTag(
      member.displayName,
      isKu: isKu,
      tag: null,
    );
    final zoneColor = promo ? t.okTx : (demo ? t.errTx : null);
    final bg = member.isMe
        ? t.goldTint
        : (promo ? t.okTint : (demo ? t.errTint : null));
    final label = Tr.forKu(K.pPPPuan, isKu, {
      'p0': groupThousands(member.rank),
      'p1': name,
      'p2': groupThousands(member.score),
    });
    return Semantics(
      key: ValueKey('league-row-${member.rank}'),
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: bg ?? Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(
                  width: 4,
                  height: 56,
                  child: ColoredBox(color: zoneColor ?? Colors.transparent),
                ),
                const SizedBox(width: SahneSpace.x2),
                SizedBox(
                  width: 24,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      groupThousands(member.rank),
                      maxLines: 1,
                      style: SahneType.bodyStrong.copyWith(
                        color: member.isMe ? t.goldTx : t.tx2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                PlayerAvatar(
                  radius: 18,
                  photoUrl: member.avatarUrl,
                  iconId: member.avatarIcon,
                  colorHex: member.avatarColor,
                  frameId: member.avatarFrame,
                  displayName: member.displayName,
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Rozet yazıyla büyür; dar + büyük yazıda yer yoksa
                      // çizilmez (satırın birleşik etiketi ve sıra numarası
                      // "sen"i zaten söyler; alttaki sabit satır da yazılı).
                      final scale =
                          MediaQuery.textScalerOf(context).scale(16) / 16;
                      final showTag =
                          member.isMe &&
                          constraints.maxWidth >= 72 * scale + 24;
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SahneType.bodyStrong.copyWith(color: t.tx),
                            ),
                          ),
                          if (showTag) ...[
                            const SizedBox(width: SahneSpace.x2),
                            SahneBadge(
                              label: Tr.forKu(K.you, isKu),
                              tone: SahneBadgeTone.gold,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: SahneSpace.x2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SahneRowValue(groupThousands(member.score)),
                  ),
                ),
                const SizedBox(width: SahneSpace.x4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
