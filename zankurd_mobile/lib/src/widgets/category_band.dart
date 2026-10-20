import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import 'sahne/sahne.dart';
import 'zk_back_button.dart';

/// Konu akışının TEK başlığı: kategori → alt kategori → seviye ekranları
/// uygulamanın standart sayfa başlığını ([zkAppBar]: beyaz kare geri düğmesi
/// + ad + alt satır) taşır; kategori rengi yalnız sağdaki ikon karosunda ve
/// başlığın altındaki ince çizgide durur.
///
/// Kurul 2. tur 2026-10-20 (Opus, ChatGPT, Argon): başlık eskiden koyu
/// yeşil-turkuaz bir bant + kilim deseniydi; koyu geri düğmesi ve düşük
/// kontrastlı alt yazı öteki bütün ekranların beyaz kare geri düğmeli
/// başlığından ayrışıyordu. Üç ekranın aynı bileşenden gelmesi korunur;
/// yalnız bantlı görünüm gitti (kilim deseni ana sayfada kalır).
class CategoryBandScaffold extends StatelessWidget {
  const CategoryBandScaffold({
    required this.category,
    required this.title,
    this.subtitle,
    required this.body,
    this.progress,
    super.key,
  });

  /// Verilirse başlığın altındaki çizgi GERÇEK bir ilerleme çubuğudur
  /// (0–1): dolu kısım kategori tonunda, boş kısım nötr iz. Verilmezse
  /// kategori kimliğini taşıyan dolu süs çizgisidir (alt kategori ekranı).
  ///
  /// Kusur (8. kurul, Opus): seviye listesinde süs çizgisi tam genişlik dolu
  /// olduğundan 0/5'te "tamamlanmış ilerleme" gibi okunuyordu.
  final double? progress;

  /// İkon karosunu ve ince çizgiyi renklendiren kategori kimliği.
  final String category;

  /// Başlıktaki ad.
  final String title;

  /// Adın altındaki satır (sarar, kesilmez).
  final String? subtitle;

  /// Başlığın altındaki gövde; kalan alanı doldurur (genellikle bir liste).
  final Widget body;

  /// Kategori çizgisinin anahtarı (bekçi testleri okur).
  static const accentKey = ValueKey('category-accent-line');

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 12),
        // Büyük yazıda ikon karosu düşer: dar ekranda ad ve alt satıra
        // yer kalsın, kesilmesin (kategori rengi çizgide durur).
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
              child: progress == null
                  ? SizedBox(
                      height: 3,
                      child: DecoratedBox(
                        key: accentKey,
                        decoration: ShapeDecoration(
                          color: CategoryVisuals.tone(category).ground,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    )
                  : _BandProgress(
                      key: accentKey,
                      value: progress!,
                      fill: CategoryVisuals.tone(category).ground,
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
/// durur — ana ekrandaki karo ve başlık bandıyla aynı renk ailesi. Zemin
/// kategorinin düz tonu, ikon gece birincil metni (yedi tonun hepsinde
/// ≥ 4,5:1, bkz. `category_color_identity_test`).
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({
    required this.category,
    required this.icon,
    super.key,
  });

  final String category;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: CategoryVisuals.tone(category).ground,
        shape: SahneShape.m,
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, size: 24, color: SahneTokens.night.tx),
      ),
    );
  }
}

/// Başlık altı ilerleme çubuğu: 4 pt, yuvarlak uç; boş kısım nötr iz (`s3`,
/// gündüzde ince kenarlı), dolu kısım kategori tonu. Değer 0'da dolu kısım
/// hiç çizilmez.
class _BandProgress extends StatelessWidget {
  const _BandProgress({super.key, required this.value, required this.fill});

  final double value;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 4,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: t.s3, shape: const StadiumBorder()),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: v <= 0
              ? null
              : FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
