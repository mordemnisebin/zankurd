import 'dart:math' as math;

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
/// dildeki ad durur; her karoda soru sayısı üçüncül metinle yazılır,
/// başlanmış konunun ilerlemesi onun altında ince bir Zimrût çubuktur
/// (yüzdeyi ekran okuyucu okur). 2026-09-30 simülatör: çubuk eskiden
/// sayının yerine geçiyordu; tutarsızdı.
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

  /// Karonun en büyük kenarı (ızgara geniş ekranda karoyu büyütmez).
  static const _maxTile = 128.0;

  /// Sütun sayısı: kullanılabilir genişlikten başlar (4; 330 px altında 3),
  /// sonra yazı ölçeğine göre düşer — ta ki hiçbir ad sözü, öteki ad sözü ve
  /// tek satırlık soru sayısı sütuna sığana (kelime ortasından bölünmeyene)
  /// kadar.
  ///
  /// 2026-09-30 simülatör: büyük yazıda (Ekstra Büyük 2.35x) dört sütun
  /// sabit kalıyordu; ~78 px'lik sütunda "Ziman" -> "Zima/n", "214 soru" ->
  /// "214 ..." oluyordu. Tur ve testler 1.0 ölçekte koştuğu için kusur
  /// sessiz kaldı.
  int _columnsFor(BuildContext context, double maxWidth, double gap) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Ölçü, karonun gerçekten çizdiği biçemle yapılır: `Text` aileyi
    // mirastan alır, boyayıcı almaz; miras biçem + Şahnê biçemi birleşir.
    final inherited = DefaultTextStyle.of(context).style;
    double word(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: inherited.merge(style).copyWith(fontFamily: style.fontFamily),
        ),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    var widest = 0.0;
    for (final category in categories) {
      // Karo adları tek satırdır ve sarmaz: ölçü sözcük değil BÜTÜN ad,
      // yoksa uzun ad "…" ile kesilir. Kısa karo adları
      // ([CategoryNames.tile]) kullanılır.
      widest = math.max(
        widest,
        word(CategoryNames.tile(category, isKu), SahneType.bodyStrong),
      );
      widest = math.max(
        widest,
        word(CategoryNames.tile(category, !isKu), SahneType.caption),
      );
      // Soru sayısı ("241 soru") BÜTÜN olarak tek satıra sığmalı.
      final count = questionCounts[category];
      if (count != null) {
        widest = math.max(
          widest,
          word('$count ${Tr.forKu(K.soru, isKu)}', SahneType.caption),
        );
      }
    }
    var columns = maxWidth < 330 ? 3 : 4;
    while (columns > 1) {
      final tile = (maxWidth - gap * (columns - 1)) / columns;
      // 1 px pay: kenarda duran sözün ölçümde sığıp çizimde inmesini önler.
      if (tile >= widest + 1) break;
      columns--;
    }
    return columns;
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
                  size: math.min(tileWidth, _maxTile),
                  width: tileWidth,
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
    required this.width,
    super.key,
  });

  final String category;
  final bool isKu;
  final CategoryProgress? progress;
  final int? questionCount;
  final VoidCallback? onTap;

  /// Karonun kenarı.
  final double size;

  /// Yazı sütununun genişliği (tek sütunda karodan geniş olabilir).
  final double width;

  @override
  Widget build(BuildContext context) {
    // Karoda KISA ad yazılır (bkz. [CategoryNames.tile]); ekran okuyucu tam
    // adı okur.
    final name = CategoryNames.tile(category, isKu);
    final other = CategoryNames.tile(category, !isKu);
    final fullName = CategoryNames.localized(category, isKu);
    final fullOther = CategoryNames.localized(category, !isKu);
    final ratio = (progress?.ratio ?? 0).clamp(0.0, 1.0);
    final started = ratio > 0;
    final count = questionCount;
    final percent = started ? context.percentRatio(ratio) : null;
    final countText = count == null ? null : '$count ${Tr.forKu(K.soru, isKu)}';
    final t = SahneTokens.of(context);
    // 2026-09-30 izgara: yazı bloğu her karoda AYNI satırlardan kurulur —
    // ad, öteki ad (iki dil aynıysa boş satır), soru sayısı, ilerleme çizgisi.
    // Çizgi ARTIK HER karoda durur: oynanmamışta boş iz (%0) çizilir. Eskiden
    // çubuk yalnız oynanmış konuda çıkıyor, alt boşluk karodan karoya
    // değişiyordu (Siyaset altında ~100 pt boş kuyu). Boş iz sahte ilerleme
    // değildir: dolgu yok, yalnız yer ve "henüz yok" bilgisi.
    const barGap = SahneSpace.x2;
    const barHeight = 8.0;
    return SahneJewelTile(
      name: name,
      otherName: other == name ? null : other,
      semanticName: fullOther == fullName ? fullName : '$fullName, $fullOther',
      icon: CategoryVisuals.icon(category),
      mark: CategoryVisuals.mark(category),
      tone: CategoryVisuals.tone(category),
      onTap: onTap,
      size: size,
      width: width,
      metaLabel: [?countText, ?percent].isEmpty
          ? null
          : [?countText, ?percent].join(', '),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            countText ?? '\u00A0',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: SahneType.caption.copyWith(color: t.tx3),
          ),
          Padding(
            padding: const EdgeInsets.only(top: barGap),
            // `SahneProgressBar` ile aynı ölçü, renk ve kenar (8 px, S pah,
            // iz Ray, dolgu Zimrût). `LinearProgressIndicator` üstüne kurulu
            // çünkü ortak `home_screen_navigation_refresh_test`
            // ilerlemenin karoda bu tiple çizildiğini arıyor.
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: SahneShape.withSide(
                  SahneShape.s,
                  sahneTrackEdge(t),
                  width: 1,
                ),
              ),
              child: ClipPath(
                clipper: const ShapeBorderClipper(shape: SahneShape.s),
                child: LinearProgressIndicator(
                  key: ValueKey('home-topic-progress-$category'),
                  value: ratio,
                  minHeight: barHeight,
                  color: t.learnBar,
                  backgroundColor: t.s3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
