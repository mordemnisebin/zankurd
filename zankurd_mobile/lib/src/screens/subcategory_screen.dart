import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../config/category_visuals.dart';
import '../config/subcategory_config.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class SubcategoryScreen extends StatelessWidget {
  const SubcategoryScreen({
    required this.repository,
    required this.category,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // Ekranın gördüğü havuz, seviye yükleyicisinin (`loadLevelQuestions`)
    // kullandığı AYNI havuz olmalı — yoksa ekran bir kart gösterir, seviye
    // yükleyici o alt kategoride hiç eşleşen soru bulamaz. `playableQuestions`
    // zaten bu ortak nokta: `MockZanKurdRepository.loadLevelQuestions` da
    // `SupabaseZanKurdRepository` da (kendi `_offline`ı üzerinden) seviye
    // sorularını hep bu getter'dan süzer (2026-09-28).
    final rawList = SubcategoryConfig.visibleFor(
      category,
      repository.playableQuestions,
    );
    final list = rawList.isNotEmpty
        ? rawList
        : [
            SubcategoryInfo(
              id: 'gisti',
              nameKu: 'Hemû Pirs',
              nameTr: 'Tüm Sorular',
              descriptionKu: 'Têkelpêkel pirsên $category',
              descriptionTr: '$category kategorisindeki tüm sorular',
            ),
          ];
    final t = SahneTokens.of(context);
    const night = SahneTokens.night;

    // 2026-09-29 Şahnê: B iskeleti + kategori başlığı. Kategori çizimi bu
    // ekranda başlığın zeminidir (maket kuralı: çizim yalnız karo, kategori
    // başlığı ve soru sahnesi zemininde). Zemin her temada gecedir; çubuk
    // (geri + ad + alt satır) onun üstünde gece metinleriyle yazılır ve
    // durum çubuğu açık ikon ister. Eski palet dışı kategori degradesi,
    // parlama daireleri ve bulanık gölge kalktı.
    return Scaffold(
      backgroundColor: t.bg,
      extendBodyBehindAppBar: true,
      appBar: zkAppBar(
        context,
        backgroundColor: Colors.transparent,
        // Çubuk gece başlığının üstünde: saat ve pil açık renkte olmalı
        // (bkz. `AppTheme.overlayOnDarkHeader`).
        systemOverlayStyle: AppTheme.overlayOnDarkHeader,
        title: Text(
          CategoryNames.localized(category, ku),
          style: SahneType.headline.copyWith(color: night.tx),
        ),
        subtitle: Text(
          Tr.forKu(K.birAltAlanSecerek, ku),
          style: SahneType.caption.copyWith(color: night.tx2),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeader(category: category),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x4,
                  SahneSpace.page,
                  SahneSpace.x6,
                ),
                children: [
                  SahneListGroup(
                    children: [
                      for (final sub in list) _subcategoryRow(context, sub, ku),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.cardGap),
                  _SubcategoryProgressHint(isKu: ku),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alt kategori satırı: Zimrût tonlu ikon karosu + ad + açıklama; sağda
  /// "5 SEVİYE" rozeti ve chevron.
  Widget _subcategoryRow(BuildContext context, SubcategoryInfo sub, bool ku) {
    return SahneListRow.icon(
      key: ValueKey('subcategory-card-${sub.id}'),
      icon: _iconForSubcategory(sub.id),
      role: SahneRole.learn,
      title: ku ? sub.nameKu : sub.nameTr,
      subtitle: ku ? sub.descriptionKu : sub.descriptionTr,
      // Tek rozet: "5 SEVİYE". Eski "Yarış" çipi kalktı — her satırda
      // aynı Boyax rozeti adı sıkıştırıyordu; çubuğun alt satırı
      // ("…yarışmaya başla") bunu zaten söylüyor.
      trailing: SahneBadge(label: Tr.forKu(K.seviye, ku)),
      chevron: true,
      onTap: () {
        Navigator.of(context).push(
          AppRoute.to(
            LevelScreen(
              repository: repository,
              category: category,
              subCategory: sub.id,
            ),
          ),
        );
      },
    );
  }
}

/// Listenin sonundaki bilgi kartı: "Kolaydan zora doğru ilerle" ve 1 → 5
/// basamakları.
class _SubcategoryProgressHint extends StatelessWidget {
  const _SubcategoryProgressHint({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Bu kart yalnız BİLGİLENDİRİR: hangi alt kategoriye ait olduğu
    // belirsiz olduğu için tıklanınca gidebileceği anlamlı tek bir hedef
    // yok (seviye seçimi her zaman bir alt kategoriye bağlı). Eskiden sağ
    // ucunda `chevronRight` ikonu vardı; listedeki her tıklanabilir satır
    // aynı ikonla bittiği için bu kart da dokunulabilir görünüyordu ama
    // `onTap` yoktu — dokunan kullanıcı hiçbir tepki almıyordu (2026-08-14
    // denetimi). Kart InkWell'siz ve chevron'suz kalır.
    return AppPanel(
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: t.learnTint,
              shape: SahneShape.m,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(AppIcons.stairs, color: t.learnTx, size: 24),
            ),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.forKu(K.kolaydanZoraDogruIlerle, isKu),
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Wrap(
                  spacing: SahneSpace.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var step = 1; step <= 5; step++) ...[
                      Text(
                        '$step',
                        style: SahneType.captionStrong.copyWith(
                          color: t.learnTx,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (step < 5)
                        Icon(AppIcons.arrowRight, size: 12, color: t.tx3),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kategori başlığı: kategori çizimi, üstünde gece perdesi (üstte koyu —
/// çubuk metni AA okunsun —, altta çizim görünür), altında kilim göz
/// şeridi. Yüksekliği durum çubuğu + çubuk (64) + çizim bandı.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final String category;

  /// Çubuğun altında çizimin açık kaldığı bant.
  static const double _band = 88;

  @override
  Widget build(BuildContext context) {
    const night = SahneTokens.night;
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: topInset + 64 + _band,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: night.bg),
          ExcludeSemantics(
            child: Image.asset(
              CategoryVisuals.imagePath(category),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // Degrade perde (grup notu: "gerekirse degrade perde"): çubuk
          // bölgesinde gece zemininin %80'i — beyaz çizimin üstünde bile
          // gece metni AA geçer —, alt uçta %8'i.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  night.bg.withValues(alpha: 0.8),
                  night.bg.withValues(alpha: 0.8),
                  night.bg.withValues(alpha: 0.08),
                ],
                stops: [0, (topInset + 64) / (topInset + 64 + _band), 1],
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: SahneKilimStrip(
              color: night.learnTx.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// 2026-07-22 canlı UX denetimi: alt kategori ikon eşleştirmesi
IconData _iconForSubcategory(String id) {
  return switch (id) {
    // ── Ziman ──
    'reziman' ||
    'diroka_kevn' ||
    'helbest' ||
    'dastangotin' ||
    'diroka_siyasi' ||
    'demokratik' => AppIcons.book,
    // ── Çand & Edebiyat ──
    'peyvnasi' ||
    'folklor' ||
    'diroka_nujen' ||
    'klasik' ||
    'bajar_ci' ||
    'nujen' ||
    'siyaseta_nujen' ||
    'ekoloji' => AppIcons.bookOpen,
    // ── Yazım & Sanat ──
    'rastnivisin' || 'sexsiyet' || 'roman' => AppIcons.pen,
    // ── Sınırlar & Coğrafi Yapı ──
    'sinor_duma' => AppIcons.locationDot,
    // ── Müzik Aletleri ──
    'amur' => AppIcons.music,
    // ── Hareket & Mücadele ──
    'tevger' => AppIcons.flag,
    // ── Jineolojî ──
    'jineoloji' => AppIcons.venus,
    // ── Kutlama & Gelenek ──
    'cejn' => AppIcons.champagneGlasses,
    // ── Bilmece & Zekâ ──
    'tistonek' => AppIcons.lightbulb,
    // ── Coğrafya ──
    'ciya_cem' => AppIcons.mountain,
    // ── Müzik ──
    'dengbeji' => AppIcons.microphone,
    // ── Teknoloji ──
    'bingehên_teknolojiyê' => AppIcons.gear,
    'programkirin' => AppIcons.robot,
    'dijital_internet' => AppIcons.globe,
    _ => AppIcons.bookmark,
  };
}
