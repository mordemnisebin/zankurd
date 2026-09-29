import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../utils/percent_format.dart';
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

/// Konu ızgarası: yedi kategorinin HEPSİ ilk bakışta, mücevher karolarda.
///
/// Eskiden konulara üç ayrı yoldan gidiliyordu: seviye yolunun içindeki
/// "Tüm konular" bağlantısı, ayrı kategori ekranı ve yalnız başlanmış
/// konuları listeleyen "Kaldığın yer". Izgara üçünü tek yerde toplar.
///
/// 2026-09-29 Şahnê: karo [SahneJewelTile] (kare, L pah, gölgesiz). Maketteki kayan raf yerine
/// ızgara: dört sütun (4 + 3), 330 px içeriğin altında üç sütun — 320 px'te de
/// her karo tam görünür, yatay kaydırma gerekmez. Adın altında öteki
/// dildeki ad durur; başlanmış konunun ilerlemesi karonun altında ince bir
/// Zimrût çubuktur (yüzdeyi ekran okuyucu okur), başlanmamışın soru sayısı
/// üçüncül metinle yazılır.
///
/// 2026-09-29 doğallık (K1): karolarda kategori çizimi yok. Yedi karonun
/// beşi aynı üretilmiş görsel dilini (kilim çerçeve, parlak nesne yığını)
/// taşıyordu; yan yana dizilince ekranın ilk bakışta "yapay zekâ yapmış"
/// dediği yer burasıydı. Her karo artık çizimsiz: kategorinin kendi renk
/// ailesinden düz zemin ([CategoryVisuals.tone]) + kendi çizgi ikonu. Konu
/// renkle ve adla ayrılır; çizimler yalnız alt kategori kahramanında kalır.
///
/// 2026-09-30 kimlik: ikonun yerini konunun K3 silüeti aldı (Ziman
/// konuşma balonunda Ê, Çand çaydanlık, Dîrok kale, Wêje açık defter,
/// Erdnîgarî çiya ve nehir, Muzîk tembûr, Sînema film şeridi); silüeti
/// olmayan konu eski ikonda kalır ([CategoryVisuals.mark] `null`).
class HomeTopicGrid extends StatelessWidget {
  const HomeTopicGrid({
    required this.isKu,
    required this.categories,
    required this.progress,
    required this.questionCounts,
    required this.onOpen,
    super.key,
  });

  final bool isKu;
  final List<String> categories;
  final Map<String, CategoryProgress> progress;

  /// Başlanmamış karonun altında "245 soru" olarak yazılır.
  final Map<String, int> questionCounts;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 3 : 4;
        const gap = SahneSpace.x2;
        final tileWidth =
            ((constraints.maxWidth - gap * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          key: const ValueKey('home-topic-grid'),
          spacing: gap,
          runSpacing: SahneSpace.x4,
          children: [
            for (final category in categories)
              SizedBox(
                width: tileWidth,
                child: _HomeTopicTile(
                  key: ValueKey('home-topic-$category'),
                  category: category,
                  isKu: isKu,
                  progress: progress[category],
                  questionCount: questionCounts[category],
                  onTap: onOpen == null ? null : () => onOpen!(category),
                  size: tileWidth,
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
    required this.questionCount,
    required this.onTap,
    required this.size,
    super.key,
  });

  final String category;
  final bool isKu;
  final CategoryProgress? progress;
  final int? questionCount;
  final VoidCallback? onTap;

  /// Karonun kenarı.
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = CategoryNames.localized(category, isKu);
    final other = CategoryNames.localized(category, !isKu);
    final ratio = progress?.ratio ?? 0;
    final started = ratio > 0;
    final count = questionCount;
    final meta = started
        ? context.percentRatio(ratio)
        : count == null
        ? null
        : '$count ${Tr.forKu(K.soru, isKu)}';
    final t = SahneTokens.of(context);
    return SahneJewelTile(
      name: name,
      otherName: other == name ? null : other,
      icon: CategoryVisuals.icon(category),
      mark: CategoryVisuals.mark(category),
      tone: CategoryVisuals.tone(category),
      onTap: onTap,
      size: size,
      metaLabel: meta,
      meta: started
          ? Padding(
              padding: const EdgeInsets.only(top: SahneSpace.x2),
              // `SahneProgressBar` ile aynı ölçü ve renk (8 px, S pah, iz
              // Ray, dolgu Zimrût). `LinearProgressIndicator` üstüne kurulu
              // çünkü ortak `home_screen_navigation_refresh_test`
              // ilerlemenin karoda bu tiple çizildiğini arıyor.
              child: ClipPath(
                clipper: const ShapeBorderClipper(shape: SahneShape.s),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: t.learnBar,
                  backgroundColor: t.s3,
                ),
              ),
            )
          // Başlanmamış konu sahte ilerleme çizmez; varsa soru sayısını
          // söyler (2026-07-25 denetimi).
          : meta == null
          ? null
          : Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.caption.copyWith(color: t.tx3),
            ),
    );
  }
}
