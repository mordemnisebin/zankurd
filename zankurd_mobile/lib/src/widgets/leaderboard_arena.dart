import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/number_format.dart';
import 'sahne/sahne.dart';
import 'zan_mascot.dart';

/// Sıralamanın "lig" başlığı (vay katmanı 2B, B8 — 2026-10-29).
///
/// ## Niçin
///
/// GPT-6 Astra (Duolingo lig + TRT podyum kıyası, 6,5/10): "Liderlik,
/// yükselme ve ödül hissi zayıf; üst sıraya … puan şeridi ekleyin, farkı
/// GERÇEK veriden hesaplayın". Duolingo'nun lig ekranı tepede kademe
/// arması ve "nerede olduğun" ile açılır.
///
/// ## Dürüstlük sınırı
///
/// Haftalık lig katmanı (Bronz/Gümüş/Altın, yükselme/düşme) bilerek kapalı
/// (`kWeeklyLeagueEnabled`, 2026-09-27: oyuncu az, herkes aynı basamakta).
/// Bu başlık o yüzden kademe/yükselme VAADİ etmez; yalnız dönemin
/// arenasını, oyuncunun sırasını ve bir üst sıraya kalan puanı (listede
/// görünen komşunun gerçek puanından) gösterir. Lig açılınca kademe
/// arması aynı yuvaya girer.
class LeaderboardArenaHeader extends StatelessWidget {
  const LeaderboardArenaHeader({
    required this.periodLabel,
    required this.myRank,
    required this.myScore,
    required this.nextScore,
    super.key,
  });

  /// "Hafta" / "Heft".
  final String periodLabel;

  /// Oyuncunun dönem sırası; listede değilse `null`.
  final int? myRank;
  final int? myScore;

  /// Bir üst sıradakinin puanı (listede görünüyorsa).
  final int? nextScore;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final rank = myRank;
    final top = rank == 1;
    final title = rank == null
        ? context.t(K.lbJoinTitle)
        : top
        ? context.t(K.lbTopOfBoard)
        : context.t(K.lbYourRank, {'n': '$rank'});
    final gap =
        (rank != null && rank > 1 && nextScore != null && myScore != null)
        ? (nextScore! - myScore! + 1).clamp(1, 1 << 30)
        : null;
    final big = MediaQuery.textScalerOf(context).scale(16) >= 24;
    const emblem = ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: CircleBorder(),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE6A0), Color(0xFFD7A744)],
          ),
          shadows: [
            BoxShadow(
              color: Color(0x33B07A12),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: 56,
          child: Icon(AppIcons.trophy, size: 28, color: Color(0xFF5A3A00)),
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${context.t(K.leaderboardTitle)} · $periodLabel',
          style: SahneType.captionStrong.copyWith(color: t.goldTx),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          key: const ValueKey('leaderboard-league-title'),
          style: (rank == null ? SahneType.bodyStrong : SahneType.headline)
              .copyWith(color: t.tx),
        ),
        if (gap != null) ...[
          const SizedBox(height: 2),
          Text(
            context.t(K.lbGapToNext, {'n': groupThousands(gap)}),
            key: const ValueKey('leaderboard-league-gap'),
            style: SahneType.captionStrong.copyWith(color: t.tx2),
          ),
        ],
      ],
    );
    return Semantics(
      key: const ValueKey('leaderboard-league-header'),
      container: true,
      child: SahneSurfaceCard(
        color: t.goldTint,
        edgeColor: Color.lerp(t.goldTint, t.goldTx, 0.35),
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.x4,
          SahneSpace.x3,
          SahneSpace.x3,
          SahneSpace.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Büyük yazıda arma kalkar: başlık harf harf bölünmesin.
                if (!big) ...[emblem, const SizedBox(width: SahneSpace.x3)],
                Expanded(child: text),
                if (!big) ...[
                  const SizedBox(width: SahneSpace.x2),
                  ZanMascot(
                    key: const ValueKey('leaderboard-league-mascot'),
                    pose: rank != null && rank <= 3
                        ? ZanPose.celebrate
                        : ZanPose.guide,
                    size: 88,
                  ),
                ],
              ],
            ),
            if (gap != null) ...[
              const SizedBox(height: SahneSpace.x3),
              SahneProgressBar(
                key: const ValueKey('leaderboard-league-progress'),
                value: (myScore! / nextScore!).clamp(0.0, 1.0),
                tone: SahneProgressTone.gold,
                semanticLabel: context.t(K.lbGapToNext, {
                  'n': groupThousands(gap),
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Listenin dibinde boş kalan alanı dolduran tek eylem: yarışa başla
/// (ekranın TEK turuncu birincili). Astra: "alt bölüm fazla boş".
/// Yalnız oyuncu listedeyken çizilir: listede değilse alttaki sabit şerit
/// zaten "Yarışa başla" taşır (aynı eylem iki kez çizilmez).
class LeaderboardClimbCard extends StatelessWidget {
  const LeaderboardClimbCard({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      key: const ValueKey('leaderboard-climb-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.lbClimbTitle),
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            context.t(K.lbClimbBody),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneButton.primary(
            key: const ValueKey('leaderboard-climb-start'),
            label: context.t(K.startRaceAction),
            onPressed: onStart,
            expand: true,
          ),
        ],
      ),
    );
  }
}
