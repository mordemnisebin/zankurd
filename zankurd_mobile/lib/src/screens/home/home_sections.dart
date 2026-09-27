import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/percent_format.dart';
import 'home_rows.dart' show CategoryProgress;

/// Ana ekranın bölüm başlığı: kısa bir başlık ve tek satır açıklama.
///
/// Ana ekran 2026-09-27'ye kadar "Öğrenme yolları" başlığı altında dört ayrı
/// öğrenme kapısını (ders listesi, seviye yolu, tüm konular, kaldığın yer)
/// üst üste diziyordu. Yeni gelen hangisinin ne olduğunu ayırt edemiyordu.
/// Artık her bölümün tek bir işi var ve başlığı o işi söylüyor.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// İlk oturumda görünen üç adımlık yol gösterici.
///
/// Uygulamaya ilk giren kişi iki soruyu yanıtlamak zorunda: "burada ne
/// yapılıyor?" ve "nereden başlarım?". Ana ekran bunu yalnız düzeniyle
/// anlatmaya çalışıyordu. Bu kart aynı şeyi üç cümleyle söyler ve oyuncu
/// ilk turunu bitirince kaybolur (bkz. `HomeScreen._firstSession`).
class HomeFirstSteps extends StatelessWidget {
  const HomeFirstSteps({required this.isKu, super.key});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final steps = [
      Tr.forKu(K.homeStep1, isKu),
      Tr.forKu(K.homeStep2, isKu),
      Tr.forKu(K.homeStep3, isKu),
    ];
    final accent = AppColors.readableAccent(context, AppTheme.playGreen);
    return Container(
      key: const ValueKey('home-first-steps'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              Tr.forKu(K.homeStepsTitle, isKu),
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.iconTileBg(context, AppTheme.playGreen),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[i],
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i != steps.length - 1) const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Ana ekranın iki kapısı: öğrenme alanı ve yarış.
///
/// Uygulama iki şeyi birden yapar: Kurmancî ve Kürt kültürünü öğretir,
/// insanları birbiriyle yarıştırır. Bu ikiliği ilk bakışta göstermek için
/// iki kapı hero'nun hemen altında yan yana durur. Yarış kapısı eskiden
/// yalnız ikinci oturumdan sonra, sayfanın dibinde düz bir satırdı; yeni
/// gelen, uygulamada yarış olduğunu ancak alt menüden tahmin edebiliyordu.
class HomeDoors extends StatelessWidget {
  const HomeDoors({required this.learn, required this.play, super.key});

  final HomeDoorTile learn;
  final HomeDoorTile play;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        if (constraints.maxWidth < 340 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              learn,
              const SizedBox(height: AppSpacing.sm),
              play,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: learn),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: play),
            ],
          ),
        );
      },
    );
  }
}

/// Kapılardan biri: renkli ikon, başlık, tek satırlık vaat.
class HomeDoorTile extends StatelessWidget {
  const HomeDoorTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    // 2026-09-27: sahibi ana ekranı renksiz buldu — kapılar soluk %8-16
    // tonlu bir zemin ve ince kenarlıktan ibaretti, aksan yalnız 40×40'lık
    // ikon karosunda yaşıyordu. Kapı artık aksanın TAMAMINI dolduran bir
    // gradyan taşır (Duolingo/Kahoot'un dolu renkli kartları gibi); koyu
    // uç aksanın kendisinin siyaha %28 kırılmışı, ayrı bir ton değil.
    final deep = Color.lerp(accent, Colors.black, 0.28)!;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, deep],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                children: [
                  // Filigran sağ-alt köşede durur ve alt satırın (uzun
                  // başlıkta başlığın da) sağ ucuna değer. Gradyan orada
                  // zaten koyulaşmıştır; %12 beyazla en açık noktada bile
                  // metin AA'nın üstünde kalır (bekçi:
                  // home_color_identity_test).
                  Positioned(
                    right: -18,
                    bottom: -22,
                    child: Icon(
                      icon,
                      size: 104,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 128),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Icon(icon, size: 19, color: Colors.white),
                            ),
                            const Spacer(),
                            Icon(
                              AppIcons.arrowRight,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Konu ızgarası: her kategori bir karo, ilerleme karonun içinde.
///
/// Eskiden konulara üç ayrı yoldan gidiliyordu: seviye yolunun içindeki
/// "Tüm konular" bağlantısı, ayrı kategori ekranı ve yalnız başlanmış
/// konuları listeleyen "Kaldığın yer". Izgara üçünü tek yerde toplar:
/// bütün konular görünür, başlanmışların ilerlemesi karonun altında durur.
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
  final Map<String, int> questionCounts;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 1 : 2;
        const gap = AppSpacing.sm;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
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
                  questionCount: questionCounts[category],
                  onTap: onOpen == null ? null : () => onOpen!(category),
                  tileWidth: tileWidth,
                  wide: columns == 1,
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
    required this.tileWidth,
    required this.wide,
    super.key,
  });

  final String category;
  final bool isKu;
  final CategoryProgress? progress;
  final int? questionCount;
  final VoidCallback? onTap;

  /// Karonun ekrandaki genişliği: `Image.asset`in `cacheWidth`ı için —
  /// kararlaştırılmış boyuttan büyük bir bitmap kod çözmek gereksiz bellek
  /// harcar.
  final double tileWidth;

  /// Tek sütuna düşen (dar ekran) düzende kart daha geniş bir en/boy oranı
  /// alır; grid iki sütuna geçince kareye yaklaşır.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final name = CategoryNames.localized(category, isKu);
    final color = CategoryVisuals.color(category);
    final ratio = progress?.ratio ?? 0;
    final started = ratio > 0;
    final count = questionCount;
    final meta = started
        ? context.percentRatio(ratio)
        : count == null
        ? null
        : '$count ${Tr.forKu(K.soru, isKu)}';
    final light = AppTheme.isLight(context);

    return Semantics(
      button: onTap != null,
      label: meta == null ? name : '$name, $meta',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              gradient: CategoryVisuals.gradient(category),
              borderRadius: BorderRadius.circular(AppRadius.card),
              // 2026-09-27: sahibi ana ekranı renksiz buldu — karo beyaz
              // zemin + kenarlıktan ibaretti, kategori rengi yalnız 36×36
              // ikon rozetinde yaşıyordu. Kategori kimliği artık karonun
              // TAMAMINI kaplar (bkz. `category_color_identity_test`ki
              // "her ton beyaz metinle AA'yı kendi başına geçer" garantisi).
              boxShadow: light
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    // Tek sütunda kart yatayda geniş kalır (21:9, bir
                    // afiş gibi); iki sütunda kareye yakın (16:11) durur —
                    // aksi hâlde tek sütunlu dar telefonlarda kart aşırı
                    // uzun bir dikdörtgene dönüşürdü.
                    aspectRatio: wide ? 21 / 9 : 16 / 11,
                    child: CategoryVisuals.hasOwnImage(category)
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                CategoryVisuals.imagePath(category),
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                cacheWidth:
                                    (tileWidth *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round(),
                                errorBuilder: (_, _, _) =>
                                    _TopicIconArt(category: category),
                              ),
                              // Fotoğraf etiket bandına erir: görsel ile
                              // altındaki isim arasında sert bir kenar
                              // olmasın diye.
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        color.withValues(alpha: 0),
                                        color,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _TopicIconArt(category: category),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        if (started) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 5,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.percentRatio(ratio),
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ] else if (meta != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              // 2026-09-27: %90 alfa denendi ama Coğrafya
                              // (#9C6300, beyazla TAM opaklıkta zaten sınırda
                              // 5.00:1) ve Muzîk (#4C7A17) üstünde 4.39:1 ve
                              // 4.49:1'e düşüyordu — ikisi de AA eşiğinin
                              // ALTINDA ve ikisi de bugün ekranda görünen
                              // gerçek kategoriler. %95 bütün tanımlı
                              // kategori renklerinde (görünür/gizli fark
                              // etmeksizin) en az 4.68:1 verir.
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kendi fotoğrafı olmayan (ya da yüklenemeyen) kategoriler için karo
/// içeriği: gradyan zemin görünür kalır, ikon hem ortada hem de dev bir
/// filigran olarak sağ-altta tekrarlanır.
class _TopicIconArt extends StatelessWidget {
  const _TopicIconArt({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final icon = CategoryVisuals.icon(category);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -16,
          bottom: -20,
          child: Icon(
            icon,
            size: 110,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        Center(
          child: Icon(
            icon,
            size: 44,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}
