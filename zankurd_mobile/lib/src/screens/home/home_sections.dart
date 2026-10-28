import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../utils/percent_format.dart';
import '../../config/category_visuals.dart';
import '../../widgets/category_band.dart' show CategoryIconTile;
import '../../widgets/sahne/sahne.dart';
import 'home_rows.dart' show CategoryProgress;

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
/// ## 2026-10-20 renk ve canlılık
///
/// Sadeleştirme konu rengini 28 px'lik koyu kısık bir kutuya indirmişti; on
/// bir karo yan yana gri-kahve bir leke gibi okunuyordu (sahibi "renkliliği,
/// canlılığı öldürüldü" dedi; rakipler — TRT Bil Bakalım, Trivia Crack —
/// konuyu karonun TAMAMINA boyuyor). Karo artık konunun renginde DOLUDUR
/// ([SahneCategoryTone.fill]): beyaz silüet, beyaz ad, altında beyaz %92
/// Kurmancî ikinci satır, sağ altta beyaz %12 filigran. Gece aynı karo bir
/// basamak koyu dolguyla kalır; griye dönmez.
///
/// ## 2026-10-28 kurul K1 (sadelik)
///
/// Doygun dolu karo geri alındı (11 dolu karo yan yana ekranı bağırtıyordu;
/// kurul 3 model): karo standart yüzey kartıdır (açık temada beyaz, koyu
/// temada grafit [SahneTokens.s1]); konu rengi YALNIZ 40 px'lik ikon rozetinde
/// ve karonun başındaki 4 px'lik kenar şeridinde. Ad normal metin rengindedir;
/// ikinci dil yalnız "iki dilli etiketler" açıksa küçük soluk satır. Büyük
/// silik filigran kalktı (metinle çakışıyordu). Konu→renk eşlemesi aynen
/// [SahneCategoryTone]'dan gelir; rozet eşleme sayfasındaki satırla
/// ([CategoryIconTile]) birebir aynıdır. Bekçi: `test/konu_karosu_notr_test.dart`.
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
  ///
  /// Tur 10a (9. kurul kare 01/20/26, Gemini + Grok): ikon+metin sola
  /// yapışık, sağda orantısız boşluk, kartlar sıkışıktı. İç sol/sağ boşluk 16,
  /// dikey 12, ızgara aralığı 12; işaret 28'lik kutu, metin onunla dikey ortalı.
  static const double _pad = SahneSpace.x4;
  static const double _padV = SahneSpace.x3;
  static const double _gap = SahneSpace.x3;
  static const double _badge = 40;
  static const double _strip = 4;
  static const double _minHeight = 96;

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
    // Ad ikonun ALTINDADIR (dolu karo): yazı alanı karonun iç genişliği.
    final room = tile - _pad * 2 - _strip;
    return room >= widest + 1 ? columns : 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = _gap;
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

  Widget? _secondName(BuildContext context) {
    final key = CategoryNames.tileKey(category);
    if (key == null) return null;
    final text = secondLabelFor(context, key, isKu: isKu);
    return text == null ? null : SahneBilingualLabel(text);
  }

  @override
  Widget build(BuildContext context) {
    // Karoda KISA ad yazılır (bkz. [CategoryNames.tile]); ekran okuyucu tam
    // adı okur.
    final t = SahneTokens.of(context);
    final name = CategoryNames.tile(category, isKu);
    final fullName = CategoryNames.localized(category, isKu);
    final ratio = (progress?.ratio ?? 0).clamp(0.0, 1.0);
    final started = ratio > 0;
    final percent = started ? context.percentRatio(ratio) : null;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fill = CategoryVisuals.tone(category).fill(night: night);
    return Semantics(
      container: true,
      button: onTap != null,
      label: [fullName, ?percent].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: SahneTappable(
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
        color: t.s1,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: HomeTopicGrid._minHeight,
          ),
          child: Stack(
            children: [
              // Konu rengi kenar şeridi (4 px); kartın yuvarlak köşesine
              // kırpılır.
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: HomeTopicGrid._strip,
                child: ColoredBox(
                  key: ValueKey('home-topic-strip-$category'),
                  color: fill,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  HomeTopicGrid._pad + HomeTopicGrid._strip,
                  HomeTopicGrid._padV,
                  HomeTopicGrid._pad,
                  HomeTopicGrid._padV,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryIconTile(
                        key: ValueKey('home-topic-badge-$category'),
                        category: category,
                        icon: CategoryVisuals.icon(category),
                        size: HomeTopicGrid._badge,
                      ),
                      const SizedBox(height: SahneSpace.x2),
                      Text(
                        name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                      // İki dilli etiket: ayar açıksa konunun öbür dildeki adı,
                      // küçük soluk tek satır; sığmazsa hiç çizilmez.
                      ?_secondName(context),
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
                              color: fill,
                              backgroundColor: t.s3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
