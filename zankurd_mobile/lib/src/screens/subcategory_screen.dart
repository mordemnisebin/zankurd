import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../config/category_visuals.dart';
import '../config/subcategory_config.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
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
    final canonicalCat = CategoryVisuals.canonicalName(category);
    final rawList =
        SubcategoryConfig.subcategories[category] ??
        SubcategoryConfig.subcategories[canonicalCat];
    final list = (rawList != null && rawList.isNotEmpty)
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
    // Renk kategorinin adından gelir; liste sırasına bağlı değildir.
    final gradient = CategoryVisuals.gradient(category);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Geri oku her zaman renkli banner'ın üzerinde durur.
        iconTheme: const IconThemeData(color: Colors.white),
        // Başlık banner'da büyük yazılıyor; app bar'da tekrar etmiyoruz.
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Geometric category banner
              _CategoryBanner(category: category, gradient: gradient, isKu: ku),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == list.length) {
                      return _SubcategoryProgressHint(
                        isKu: ku,
                        gradient: gradient,
                      );
                    }
                    final sub = list[index];
                    return _SubcategoryCard(
                      info: sub,
                      isKu: ku,
                      gradient: gradient,
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryProgressHint extends StatelessWidget {
  const _SubcategoryProgressHint({required this.isKu, required this.gradient});

  final bool isKu;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final tint = gradient.colors.first;
    // Bu kart yalnız BİLGİLENDİRİR: hangi alt kategoriye ait olduğu
    // belirsiz olduğu için tıklanınca gidebileceği anlamlı tek bir hedef
    // yok (seviye seçimi her zaman bir alt kategoriye bağlı —
    // `_SubcategoryCard.onTap` bunu zaten yapıyor). Eskiden sağ ucunda
    // `chevronRight` ikonu vardı; listedeki her tıklanabilir alt kategori
    // satırı aynı ikonla bitiyor, o yüzden bu kart da dokunulabilir
    // görünüyordu ama `onTap` yoktu — dokunan kullanıcı hiçbir tepki
    // almıyordu (2026-08-14 denetimi). Düzeltme: sahte "buraya dokun"
    // ipucunu kaldır, kartı InkWell'siz bırak.
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(AppIcons.stairs, color: tint, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.forKu(K.kolaydanZoraDogruIlerle, isKu),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var step = 1; step <= 5; step++) ...[
                      Text(
                        '$step',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.readableAccent(context, tint),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (step < 5)
                        Icon(
                          AppIcons.arrowRight,
                          size: 12,
                          color: AppTheme.textMutedColor(context),
                        ),
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

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({
    required this.category,
    required this.gradient,
    required this.isKu,
  });

  final String category;
  final LinearGradient gradient;
  final bool isKu;

  static IconData _bannerIcon(String category) {
    return switch (category) {
      'Ziman' => AppIcons.language,
      'Çand' => AppIcons.peopleGroup,
      'Dîrok' => AppIcons.buildingColumns,
      'Edebiyat' => AppIcons.bookOpenReader,
      'Cografya' => AppIcons.mountain,
      'Muzîk' => AppIcons.music,
      'Siyaset' => AppIcons.gavel,
      'Paradigma' => AppIcons.brain,
      'Teknolojî' => AppIcons.mobileScreen,
      _ => AppIcons.graduationCap,
    };
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final color1 = Colors.white.withValues(alpha: 0.10);
    final color2 = Colors.white.withValues(alpha: 0.04);

    return Container(
      height: 160 + topInset,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kategori görseli — en alt katman. Seviye haritasının hero'suyla
          // aynı dil: ekranda tek kategori olduğu için görsel yorucu değil,
          // kimlik taşır. (Kategori *listesine* konmadı; 2026-07-24 kararı
          // sekiz posteri bilinçli olarak kaldırmıştı.)
          Opacity(
            opacity: 0.28,
            child: Image.asset(
              CategoryVisuals.imagePath(category),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradient.colors.first.withValues(alpha: 0.55),
                  gradient.colors.last.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          // Soft Glow 1 — larger, warmer
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color1, color1.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          // Soft Glow 2
          Positioned(
            left: -50,
            bottom: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color2, color2.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          // 160px'lik filigran ikon kaldırıldı. Üstündeki yorum "kilim
          // deseni" diyordu ama çizilen şey büyütülmüş bir ikondu; kartın
          // kenarından taşıp başlığın arkasına giriyor ve zemini
          // kirletiyordu (2026-07-25 görsel denetimi). Görsel imzayı artık
          // gerçek kategori fotoğrafı taşıyor.
          //
          // "Decorative dots" adlı tek bir 6px beyaz nokta da kaldırıldı:
          // hiçbir şey anlatmıyor, ekranda açıklanamayan bir leke olarak
          // duruyordu.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Category icon in small circle
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.1,
                    ),
                  ),
                  child: Icon(
                    _bannerIcon(category),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Text(
                  CategoryNames.localized(category, isKu),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        color: Color(0x55000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Tr.forKu(K.birAltAlanSecerek, isKu),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({
    required this.info,
    required this.isKu,
    required this.gradient,
    required this.onTap,
  });

  final SubcategoryInfo info;
  final bool isKu;
  final LinearGradient gradient;
  final VoidCallback onTap;

  // 2026-07-22 canlı UX denetimi: alt kategori ikon eşleştirmesi
  IconData _iconForId(String id) {
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

  @override
  Widget build(BuildContext context) {
    final title = isKu ? info.nameKu : info.nameTr;
    final desc = isKu ? info.descriptionKu : info.descriptionTr;
    final icon = _iconForId(info.id);
    final tint = gradient.colors.first;

    return ClipRRect(
      key: ValueKey('subcategory-card-${info.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tint.withValues(alpha: 0.22), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        // Filigran ikon kartın dışına taşıyordu: köşeler yuvarlak ama
        // Stack kırpmıyordu, dolayısıyla dev ikonun bir parçası kartın
        // kenarından dışarı çıkıp ekranda kopuk soluk lekeler bırakıyordu
        // — çizim hatası gibi duruyordu (2026-07-27).
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -18,
                child: Icon(
                  icon,
                  size: 92,
                  color: tint.withValues(alpha: 0.10),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  splashColor: tint.withValues(alpha: 0.12),
                  highlightColor: tint.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.36),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textMutedColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _LevelChip(
                                    icon: AppIcons.stairs,
                                    label: Tr.forKu(K.seviye, isKu),
                                    tint: tint,
                                  ),
                                  _LevelChip(
                                    icon: AppIcons.bolt,
                                    label: Tr.forKu(K.yaris, isKu),
                                    tint: tint,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tint.withValues(alpha: 0.24),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            AppIcons.arrowRight,
                            color: AppColors.onAccentTint(context, tint),
                            size: 17,
                          ),
                        ),
                      ],
                    ),
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

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
