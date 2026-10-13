import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import '../theme/app_theme.dart';
import 'sahne/sahne.dart';
import 'zk_back_button.dart';

/// Konu akışının TEK başlığı: kategori → alt kategori → seviye ekranları
/// aynı bantlı başlığı taşır (kategorinin düz tonu + sağ kenarda K1 kilim
/// deseni, solda geri plakası, ad ve alt satır).
///
/// 2026-09-30 izgara: başlık üç ekranda üç ayrı yapıdaydı — alt kategori
/// ekranı bantlı (gece çubuk + kilim), seviye ekranı düz ve gündüz çubuğuydu,
/// geri düğmeleri de farklıydı. Konu akışında bir adım ilerleyince başlığın
/// değişmesi "başka bir uygulamaya geçtim" duygusu veriyordu. Başlık artık
/// bu bileşenden gelir; ekranlar yalnız ad, alt satır ve gövdeyi verir.
///
/// Zemin her temada gecedir; çubuk (geri + ad + alt satır) onun üstünde gece
/// metinleriyle yazılır ve durum çubuğu açık ikon ister. Çubuk gece TEMASIYLA
/// kurulur: gece rengi yalnız metnin biçemine yazılsa `zkAppBar` başlığı
/// temanın metin rengiyle yeniden çizer, gündüzde ad çizimin üstünde lacivert
/// kalır (2026-09-29 doğallık, K1).
class CategoryBandScaffold extends StatelessWidget {
  const CategoryBandScaffold({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.body,
    super.key,
  });

  /// Bandın tonunu ve motifini belirleyen kategori kimliği.
  final String category;

  /// Çubuktaki ad (en çok iki satır, kesilmez).
  final String title;

  /// Adın altındaki satır (sınırsız satır; bant uzar, metin kesilmez).
  final String subtitle;

  /// Bandın altındaki gövde; kalan alanı doldurur (genellikle bir liste).
  final Widget body;

  /// Bandın desen katmanının anahtarı (bekçi testleri okur).
  static const bandKey = ValueKey('category-kilim-band');

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final slots = kilimSlots(
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context).scale(10) / 10,
    );
    PreferredSizeWidget bar(BuildContext barContext) => zkAppBar(
      barContext,
      backgroundColor: Colors.transparent,
      // Çubuk gece başlığının üstünde: saat ve pil açık renkte olmalı
      // (bkz. `AppTheme.overlayOnDarkHeader`).
      systemOverlayStyle: AppTheme.overlayOnDarkHeader,
      title: Text(title),
      // Alt satır pratikte SINIRSIZDIR: `AppBar` başlığı varsayılan olarak
      // tek satır + "…" ile sarar, bu yüzden açık bir üst sınır şarttır; sınır
      // 12 satırdır (gerçek metin bunun çok altında kalır). Eskiden 3-4'tü ve
      // Kurmancî uzun cümle ya da büyük yazıda aşılıp kesiliyordu. Çubuk ve
      // bant yüksekliği ölçülen gerçek satır sayısıyla uzar.
      subtitle: Text(subtitle, maxLines: _subtitleLines),
      // Kilim deseni sağ kenardadır: çubuk onun genişliği kadar yer bırakır
      // ([kilimSlots] x 48 boş yuva), metin desenin altına girmez. Motifsiz
      // konuda yuva açılmaz.
      actions: CategoryVisuals.mark(category) == null
          ? null
          : [
              for (var i = 0; i < slots; i++)
                const SizedBox(width: sahneTapTarget),
            ],
    );
    return Scaffold(
      backgroundColor: t.bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: bar(context).preferredSize,
        child: Theme(
          data: AppTheme.stage,
          child: Builder(builder: bar),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CategoryBand(
              category: category,
              slots: slots,
              // Durum çubuğu payı Scaffold'un DIŞINDAN okunur: gövdenin
              // içinde `padding.top` çubuğun yüksekliğini de içerir.
              topInset: MediaQuery.paddingOf(context).top,
              barHeight: bar(context).preferredSize.height,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Kilim desenine ayrılan yuva sayısı: 360 px ve üstünde üç (desen 132 px'e
/// kadar), daha dar ekranda iki (84 px) — 320 px'te başlık ve alt satır
/// yeterli genişlik bulur. Büyük yazıda (x1,3 ve üstü) bir yuva eksilir: alt
/// satır en çok iki satırdır ve dar metin alanında ("Bir alt alan seçe...")
/// yarım kalırdı; desen o zaman daha az sütun gösterir.
///
/// 2026-09-30 simülatör: %200'ü aşan yazıda (iPhone 17e en büyük boyut,
/// %235) bir yuva daha eksilir (en az bir kalır); metin alanı genişler ve
/// alt satır kesilmeden yerleşir.
@visibleForTesting
int kilimSlots(double width, double textScale) {
  final base = width >= 360 ? 3 : 2;
  if (textScale > 2) return math.max(1, base - 2);
  return textScale > 1.3 ? base - 1 : base;
}

/// Alt satırın açık üst sınırı (bkz. [CategoryBandScaffold.build]).
const int _subtitleLines = 12;

/// [slots] yuvanın desene bıraktığı genişlik: yuvalar eksi 12 px nefes.
double _kilimReserved(int slots) => slots * sahneTapTarget - SahneSpace.x3;

/// Kategori başlığı bandı: kategorinin düz tonu ([SahneCategoryTone.ground])
/// ve sağ kenardan taşan K1 kilim deseni ([SahneKilimBandPainter]).
///
/// 2026-09-30 kimlik: başlık eskiden kategorinin fotoğraf benzeri çiziminin
/// üstüne gece perdesi çekilerek kuruluyordu; çizimi olmayan kategoriler
/// (Ziman, Sînema) yalnız düz bir renk çubuğu alıyordu, yani yedi konudan
/// ikisi başka bir dilde konuşuyordu. Kullanıcı K1'i seçti: bütün konular
/// kendi dokuma motifini taşır. Motif her temada aynı çizilir (bant kimlik
/// taşır, gece değerleriyle): çubuktaki gece metni tonun koyu zemininde
/// okunur, desen bandın sağındadır ve başlığın altına girmez (bkz.
/// `SahneKilimBandPainter.reservedWidth`).
///
/// 2026-09-30 bant: yükseklik içeriğe oturur: durum çubuğu payı + çubuk
/// (geri düğmesi, ad, alt yazı; büyük yazıda çubuğun kendisi
/// uzar) + alt kenarda [_bottomGap]; sonuç 9'un katına yükseltilir (alt
/// kenarda 16-24 px boşluk kalır) ki desenin tam sayı hücresi bandın
/// tepesinden dibine yetsin. Motifi olmayan konu (Siyaset, Paradigma,
/// Teknolojî) aynı yükseklikte düz tonda kalır.
class CategoryBand extends StatelessWidget {
  const CategoryBand({
    required this.category,
    required this.slots,
    required this.topInset,
    required this.barHeight,
    super.key,
  });

  final String category;

  /// Desene ayrılan 48'lik yuva sayısı ([kilimSlots]).
  final int slots;

  /// Durum çubuğu payı: düz tonla boyanır, desen bu payın ALTINDA başlar.
  /// 2026-09-30 simülatör: desen durum çubuğunun arkasına uzanınca açık
  /// motif hücreleri (Sînema lilası, Çand mercanı) saat, sinyal ve pil
  /// simgelerini okunmaz yapıyordu; test koşucusu payı 0 aldığı için tur
  /// karelerinde görünmüyordu.
  final double topInset;

  /// Çubuğun (durum çubuğu payı hariç) yüksekliği: metne göre ölçülür.
  final double barHeight;

  /// Çubuğun altında bırakılan boşluk (çubuğun kendi 8 px iç payına ek).
  static const double _bottomGap = SahneSpace.x2;

  /// Desenli kısmın yüksekliği: çubuk + boşluk, 9'un katına yükseltilmiş
  /// (durum çubuğu payı hariç; o pay desensiz düz tondur).
  static double heightFor(double barHeight) =>
      SahneKilimBandPainter.snapHeight(barHeight + _bottomGap);

  @override
  Widget build(BuildContext context) {
    final height = heightFor(barHeight);
    final mark = CategoryVisuals.mark(category);
    final tone = CategoryVisuals.tone(category);
    return ColoredBox(
      color: tone.ground,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: height,
          child: mark == null
              ? null
              : ExcludeSemantics(
                  child: CustomPaint(
                    key: CategoryBandScaffold.bandKey,
                    painter: SahneKilimBandPainter(
                      mark: mark,
                      tone: tone,
                      reservedWidth: _kilimReserved(slots),
                    ),
                  ),
                ),
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
