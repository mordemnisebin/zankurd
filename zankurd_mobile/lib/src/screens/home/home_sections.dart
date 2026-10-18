import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../utils/percent_format.dart';
import '../../widgets/category_kicker_mark.dart';
import '../../widgets/sahne/sahne.dart';
import 'home_rows.dart' show CategoryProgress;

/// Ana ekranın iki kapısı: öğrenme alanı ve yarış.
///
/// Uygulama iki şeyi birden yapar: Kurmancî ve Kürt kültürünü öğretir,
/// insanları birbiriyle yarıştırır. Yarış kapısı eskiden yalnız ikinci
/// oturumdan sonra, sayfanın dibinde düz bir satırdı; yeni gelen,
/// uygulamada yarış olduğunu ancak alt menüden tahmin edebiliyordu.
///
/// 2026-09-29 Şahnê: iki doygun degrade kart yerine TEK liste grubu, iki
/// satır. Renk yalnız rol taşır: öğrenme satırının ikon karosu Zimrût,
/// yarışınki Boyax. Degrade kapılar ekranın tek birincil eylemiyle (günün
/// dersi) yarışıyordu.
class HomeDoors extends StatelessWidget {
  const HomeDoors({required this.learn, required this.play, super.key});

  final HomeDoorTile learn;
  final HomeDoorTile play;

  @override
  Widget build(BuildContext context) {
    return SahneListGroup(
      dividerIndent: SahneSpace.x3 + 44 + SahneSpace.x3,
      children: [learn, play],
    );
  }
}

/// Kapılardan biri: rol tonlu ikon karosu, başlık, tek satırlık vaat,
/// chevron. [SahneListRow.icon] üstüne kurulur.
class HomeDoorTile extends StatelessWidget {
  const HomeDoorTile({
    required this.icon,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final SahneRole role;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SahneListRow.icon(
      icon: icon,
      role: role,
      title: title,
      subtitle: subtitle,
      chevron: true,
      enabled: onTap != null,
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
    );
  }
}

/// Konu ızgarası: kategorilerin HEPSİ ilk bakışta, iki sütunlu yatay
/// karolarda.
///
/// ## 2026-10-19 sadeleşme
///
/// Eskiden dört sütun (4 + 3) kare mücevher karoydu: büyük bir silüet, altında
/// iki dilde ad, soru sayısı ve HER karoda boş bir ilerleme çubuğu. Test
/// edenler ekranı "kalabalık, gözü yoruyor" buldu; bir ekranda yirmiden çok
/// ayrı öğe, hepsi aynı ağırlıkta. Yeni karo: küçük yuvarlak köşeli konu
/// işareti (aynı silüet, soru künyesindeki [CategoryKickerMark] ile birebir —
/// ikon ve renk ekrandan ekrana değişmez) + YALNIZ geçerli arayüz dilinde
/// ad. Öteki dildeki ad, soru sayısı ve boş çubuk kalktı; ince (4 px) çubuk
/// yalnız ilerleme sıfırdan büyükse çizilir (yüzdeyi ekran okuyucu okur).
///
/// Sütun sayısı 2'dir; en uzun ad bir sütuna tek satırda sığmıyorsa (dar
/// ekran, büyük yazı) tek sütuna düşer — ad hiçbir zaman kelime ortasından
/// bölünmez ya da "…" ile kesilmez (2026-09-30 simülatör bulgusu: büyük
/// yazıda "Ziman" -> "Zima/n").
class HomeTopicGrid extends StatelessWidget {
  const HomeTopicGrid({
    required this.isKu,
    required this.categories,
    required this.progress,
    required this.onOpen,
    super.key,
  });

  final bool isKu;
  final List<String> categories;
  final Map<String, CategoryProgress> progress;
  final ValueChanged<String>? onOpen;

  /// Karonun iç boşluğu ve işaret ölçüsü.
  static const double _pad = SahneSpace.x3;
  static const double _mark = 40;

  /// Sütun sayısı: 2; en uzun ad (gerçek biçem ve yazı ölçeğiyle ölçülür)
  /// sütundaki yazı alanına sığmazsa 1.
  int _columnsFor(BuildContext context, double maxWidth, double gap) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final inherited = DefaultTextStyle.of(context).style;
    var widest = 0.0;
    for (final category in categories) {
      final painter = TextPainter(
        text: TextSpan(
          text: CategoryNames.tile(category, isKu),
          style: inherited
              .merge(SahneType.bodyStrong)
              .copyWith(fontFamily: SahneType.bodyStrong.fontFamily),
        ),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    const columns = 2;
    final tile = (maxWidth - gap * (columns - 1)) / columns;
    // 2 px kenar halkası + 1 px pay.
    final room = tile - 2 - _pad * 2 - _mark - SahneSpace.x3;
    return room >= widest + 1 ? columns : 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SahneSpace.x2;
        final columns = _columnsFor(context, constraints.maxWidth, gap);
        final tileWidth =
            ((constraints.maxWidth - gap * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          key: const ValueKey('home-topic-grid'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final category in categories)
              SizedBox(
                width: tileWidth,
                child: _HomeTopicTile(
                  key: ValueKey('home-topic-$category'),
                  category: category,
                  isKu: isKu,
                  progress: progress[category],
                  onTap: onOpen == null ? null : () => onOpen!(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeTopicTile extends StatelessWidget {
  const _HomeTopicTile({
    required this.category,
    required this.isKu,
    required this.progress,
    required this.onTap,
    super.key,
  });

  final String category;
  final bool isKu;
  final CategoryProgress? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Karoda KISA ad yazılır (bkz. [CategoryNames.tile]); ekran okuyucu tam
    // adı okur.
    final name = CategoryNames.tile(category, isKu);
    final fullName = CategoryNames.localized(category, isKu);
    final ratio = (progress?.ratio ?? 0).clamp(0.0, 1.0);
    final started = ratio > 0;
    final percent = started ? context.percentRatio(ratio) : null;
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      padding: const EdgeInsets.all(HomeTopicGrid._pad),
      onTap: onTap,
      semanticLabel: [fullName, ?percent].join(', '),
      child: ExcludeSemantics(
        child: Row(
          children: [
            CategoryKickerMark(
              category: category,
              fallbackColor: t.tx2,
              size: HomeTopicGrid._mark,
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                  if (started)
                    Padding(
                      padding: const EdgeInsets.only(top: SahneSpace.x2),
                      // `LinearProgressIndicator` üstüne kurulu: ortak
                      // `home_screen_navigation_refresh_test` ilerlemenin
                      // karoda bu tiple çizildiğini arıyor.
                      child: ClipPath(
                        clipper: const ShapeBorderClipper(
                          shape: StadiumBorder(),
                        ),
                        child: LinearProgressIndicator(
                          key: ValueKey('home-topic-progress-$category'),
                          value: ratio,
                          minHeight: 4,
                          color: t.learnBar,
                          backgroundColor: t.s3,
                        ),
                      ),
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
