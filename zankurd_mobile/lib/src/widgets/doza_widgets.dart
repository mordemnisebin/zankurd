import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../screens/doza_me_screen.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import 'sahne/sahne.dart';

/// "Doza me / Davamız" sayfasını açar (tek kapı: bütün girişler buradan).
void openDozaMe(BuildContext context) {
  Navigator.of(context).push(AppRoute.to(const DozaMeScreen()));
}

/// Ana sayfada yalnız o gün görünen tarihî günler.
///
/// Tarih cihazın yerel saatinden gelir ([SahneClock.now]); testler saati
/// sabitler. Metinler jüriden geçmiş kimlik metnidir (`K.dozaG*`).
enum DozaDay {
  languageDay(2, 21, K.dozaG2Date, K.dozaG2Text),
  womenDay(3, 8, K.dozaG5Date, K.dozaG5Text),
  halabja(3, 16, K.dozaG3Date, K.dozaG3Text, subKey: K.dozaG3Sub),
  newroz(3, 21, K.dozaG1Date, K.dozaG1Text),
  languageFestival(5, 15, K.dozaG4Date, K.dozaG4Text);

  const DozaDay(
    this.month,
    this.day,
    this.dateKey,
    this.textKey, {
    this.subKey,
  });

  final int month;
  final int day;
  final String dateKey;
  final String textKey;
  final String? subKey;

  /// Bugün (cihaz yerel tarihi) bir tarihî gün mü? Değilse `null`.
  static DozaDay? on(DateTime date) {
    for (final d in values) {
      if (d.month == date.month && d.day == date.day) return d;
    }
    return null;
  }

  static DozaDay? today() => on(SahneClock.now());
}

/// Tarihî gün şeridi: bugün bir günse ana sayfada Günün dersinin üstünde.
///
/// 16 Mart (Halepçe) anma tonundadır: koyu, sade, kutlama süsü yok. Öbürleri
/// canlıdır; Newroz Agir (turuncu), dil günleri Zimrût, kadınlar günü Boyax.
class DozaDayStrip extends StatelessWidget {
  const DozaDayStrip({super.key, required this.day});

  final DozaDay day;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final memorial = day == DozaDay.halabja;
    final Color fill = switch (day) {
      DozaDay.newroz => t.act,
      DozaDay.halabja => SahneVivid.raceSceneNight[2],
      DozaDay.womenDay => t.raceFill,
      DozaDay.languageDay || DozaDay.languageFestival => t.learnFill,
    };
    final Color fg = day == DozaDay.newroz ? t.onAct : SahneVivid.onFill;
    final Color soft = day == DozaDay.newroz ? t.onAct : SahneVivid.onFillSoft;
    final icon = switch (day) {
      DozaDay.newroz => AppIcons.fire,
      DozaDay.halabja => AppIcons.leaf,
      DozaDay.womenDay => AppIcons.venus,
      DozaDay.languageDay || DozaDay.languageFestival => AppIcons.language,
    };
    final date = context.t(day.dateKey);
    final text = context.t(day.textKey);
    final sub = day.subKey == null ? null : context.t(day.subKey!);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.cardGap),
      child: SahneSurfaceCard(
        key: ValueKey('doza-day-${day.name}'),
        color: fill,
        edgeColor: fill,
        onTap: () => openDozaMe(context),
        semanticLabel: '$date. $text${sub == null ? '' : ' $sub'}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ExcludeSemantics(child: Icon(icon, size: 24, color: fg)),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: SahneType.captionStrong.copyWith(color: soft),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    text,
                    style: (memorial ? SahneType.body : SahneType.bodyStrong)
                        .copyWith(color: fg),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: SahneSpace.x1),
                    Text(sub, style: SahneType.caption.copyWith(color: soft)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            ExcludeSemantics(
              child: Icon(AppIcons.chevronRight, size: 20, color: soft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana sayfanın en altındaki küçük slogan satırı (S1). Dokununca Doza me.
class DozaSloganLine extends StatelessWidget {
  const DozaSloganLine({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final slogan = context.t(K.dozaSlogan);
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x6, bottom: SahneSpace.x2),
      child: Center(
        child: ConstrainedBox(
          // a11y-tap-target: satırın tamamı dokunulur, en az 48 yüksek.
          constraints: const BoxConstraints(minHeight: sahneTapTarget),
          child: Semantics(
            button: true,
            label: slogan,
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('doza-slogan-line'),
              borderRadius: BorderRadius.circular(SahneShape.mValue),
              onTap: () => openDozaMe(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SahneSpace.x4,
                  vertical: SahneSpace.x3,
                ),
                child: Text(
                  slogan,
                  textAlign: TextAlign.center,
                  style: SahneType.bodyStrong.copyWith(
                    color: t.learnTx,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profil ekranındaki belirgin giriş kartı: dolu Zimrût, slogan altında.
class DozaMeEntryCard extends StatelessWidget {
  const DozaMeEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final title = context.t(K.dozaTitle);
    final second = context.secondLabel(K.dozaTitle);
    final slogan = context.t(K.dozaSlogan);
    return SahneSurfaceCard(
      key: const ValueKey('profile-doza-entry'),
      color: t.learnFill,
      edgeColor: t.learnFill,
      onTap: () => openDozaMe(context),
      semanticLabel: '$title. $slogan',
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(AppIcons.flag, size: 28, color: SahneVivid.onFill),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  second == null ? title : '$title · $second',
                  style: SahneType.button.copyWith(color: SahneVivid.onFill),
                ),
                Text(
                  slogan,
                  style: SahneType.caption.copyWith(
                    color: SahneVivid.onFillSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          const ExcludeSemantics(
            child: Icon(
              AppIcons.chevronRight,
              size: 20,
              color: SahneVivid.onFillSoft,
            ),
          ),
        ],
      ),
    );
  }
}
