import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import 'sahne/sahne.dart';
import 'zk_back_button.dart';

/// Konu akışının TEK başlığı: kategori → alt kategori → seviye ekranları
/// uygulamanın standart NÖTR sayfa başlığını ([zkAppBar]) taşır. 2026-10-28
/// kurul K2: dolu konu renkli bant kalktı; konu rengi yalnız ikon rozetinde
/// ve çubuğun altındaki 3–4 px'lik ilerleme/süs izindedir. Aşağıdaki
/// 2026-10-20 notu tarihçedir.
///
/// 2026-10-20 renk ve canlılık (B aşaması): kurul 2. tur başlığı sade beyaz
/// çubuğa indirmişti (kategori rengi yalnız ikon karosunda ve 3 pt'lik
/// çizgide kalmıştı); ana sayfadaki dolu konu karosundan konu ekranına
/// geçince renk kayboluyordu. Rakiplerde (Kurdish Quiz, Trivia Crack) konu
/// ekranının bandı konunun rengindedir. Üç ekranın aynı bileşenden gelmesi
/// korunur; kilim deseni ana sayfada kalır.
class CategoryBandScaffold extends StatelessWidget {
  const CategoryBandScaffold({
    required this.category,
    required this.title,
    this.subtitle,
    required this.body,
    this.progress,
    super.key,
  });

  /// Verilirse bandın altındaki çizgi GERÇEK bir ilerleme çubuğudur (0–1):
  /// dolu kısım beyaz, boş kısım cam iz. Verilmezse kategori kimliğini taşıyan
  /// dolu süs çizgisidir (alt kategori ekranı).
  ///
  /// Kusur (8. kurul, Opus): seviye listesinde süs çizgisi tam genişlik dolu
  /// olduğundan 0/5'te "tamamlanmış ilerleme" gibi okunuyordu.
  final double? progress;

  /// Bandı ve ikon karosunu renklendiren kategori kimliği.
  final String category;

  /// Başlıktaki ad.
  final String title;

  /// Adın altındaki satır (sarar, kesilmez).
  final String? subtitle;

  /// Başlığın altındaki gövde; kalan alanı doldurur (genellikle bir liste).
  final Widget body;

  /// Kategori çizgisinin anahtarı (bekçi testleri okur).
  static const accentKey = ValueKey('category-accent-line');

  /// Bandın anahtarı (renk bekçisi okur).
  static const bandKey = ValueKey('category-band');

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final night = Theme.of(context).brightness == Brightness.dark;
    final fill = CategoryVisuals.tone(category).fill(night: night);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 12),
        // K2: nötr çubuk; konu rengi ikon rozetinde ve altındaki izde.
        // Büyük yazıda ikon karosu düşer: dar ekranda ad ve alt satıra
        // yer kalsın, kesilmesin.
        actions: MediaQuery.textScalerOf(context).scale(16) >= 24
            ? null
            : [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: SahneSpace.page,
                  ),
                  child: Center(
                    child: ExcludeSemantics(
                      child: CategoryIconTile(
                        category: category,
                        icon: CategoryVisuals.icon(category),
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              key: bandKey,
              color: t.bg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  0,
                  SahneSpace.page,
                  SahneSpace.x4,
                ),
                child: progress == null
                    ? SizedBox(
                        height: 3,
                        child: DecoratedBox(
                          key: accentKey,
                          decoration: ShapeDecoration(
                            color: fill,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      )
                    : _BandProgress(
                        key: accentKey,
                        value: progress!,
                        color: fill,
                        track: t.s3,
                      ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Kategori tonlu 44'lük ikon karosu: konu akışının satırlarında (alt
/// kategori listesi) ikon, uygulamanın genel Zimrût yerine KONUNUN renginde
/// durur — ana ekrandaki dolu karo ve başlık bandıyla aynı renk ailesi.
/// Zemin konunun dolu rengi ([SahneCategoryTone.fill], gece/gündüz), ikon
/// beyaz (≥ 4,5:1). [onBand] bandın üstünde durur: dolu renk bandın
/// kendisi olduğundan karo yarı saydam beyaz camdır.
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({
    required this.category,
    required this.icon,
    this.size = 44,
    super.key,
  });

  final String category;
  final IconData icon;

  /// Rozet kenarı: satırlarda 44, konu karosunda 40.
  final double size;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: CategoryVisuals.tone(category).fill(night: night),
        shape: SahneShape.m,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size >= 44 ? 24 : 22, color: SahneVivid.onFill),
      ),
    );
  }
}

/// Başlık altı ilerleme çubuğu: 4 pt, yuvarlak uç; boş kısım cam iz, dolu
/// kısım beyaz. Değer 0'da dolu kısım hiç çizilmez.
class _BandProgress extends StatelessWidget {
  const _BandProgress({
    super.key,
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 4,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: track, shape: const StadiumBorder()),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: v <= 0
              ? null
              : FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: color,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
