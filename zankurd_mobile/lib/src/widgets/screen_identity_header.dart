import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// İkincil ekranların kimlik başlığı.
///
/// 2026-09-29 Şahnê: sayfa adı bir başlık kartında tekrarlanmaz (B
/// iskeleti). Bu bileşen artık kart çizmez: 44'lük rol ikon karosu (rol
/// tonu zemin + rol metni ikon, M pah) + Manşet 22 başlık + Açıklama alt
/// satırı, zemin yok. Ekrana özgü [accent] yalnız karonun rolünü seçer
/// ([sahneRoleFor]); ham renk boyanmaz. Başlık ekran okuyucuya başlık
/// olarak duyurulur.
class ScreenIdentityHeader extends StatelessWidget {
  const ScreenIdentityHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  /// Daha alçak blok (liste üstü şerit): 36'lık karo, Gövde 700 başlık.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final role = sahneRoleFor(accent);
    final tile = compact ? 36.0 : 44.0;
    return Semantics(
      header: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SahneSpace.x1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.roleTint(role),
                  shape: SahneShape.m,
                ),
                child: SizedBox.square(
                  dimension: tile,
                  child: Icon(
                    icon,
                    size: compact ? 20 : 24,
                    color: t.roleText(role),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: (compact ? SahneType.bodyStrong : SahneType.headline)
                        .copyWith(color: t.tx),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: SahneType.caption.copyWith(color: t.tx2),
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

/// Ana içerik içinde tekrar eden bölüm başlığı.
///
/// Play ve Learning ekranlarının ayrı ayrı tanımladığı başlıklar aynı
/// tipografiyi taşıdığı hâlde küçük spacing/fallback farklarıyla ayrışıyordu.
/// Bu bileşen kart çizmez; yalnız başlık, açıklama ve gerekirse sağ eylemi
/// aynı sakin ritimde hizalar. Böylece sayfanın gerçek CTA'sıyla yarışmaz.
///
/// 2026-09-29 Şahnê: [SahneSectionHeader] ile aynı yazı — Manşet 22/28,
/// alt satır Açıklama (ikincil metin).
class ScreenSectionHeading extends StatelessWidget {
  const ScreenSectionHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    this.semanticHeader = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Normal bölüm başlıkları ekran okuyucuda heading olarak duyurulur.
  /// Başlığın kendisi daha büyük bir düğmenin etiketi olduğunda (ör. Play
  /// "Daha fazla") iç içe button+heading rolü oluşmaması için kapatılabilir.
  final bool semanticHeader;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget copy() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: SahneType.headline.copyWith(color: t.tx)),
        if (subtitle case final subtitle? when subtitle.isNotEmpty) ...[
          const SizedBox(height: SahneSpace.x1),
          Text(subtitle, style: SahneType.caption.copyWith(color: t.tx2)),
        ],
      ],
    );

    return Semantics(
      header: semanticHeader,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          // Eşik 360'tı: sayfa boşlukları düşülünce 390'lık telefonda bile
          // başlığa 354 kalıyordu ve sıralama ekranının iki eylemi (arkadaş
          // ekle, yenile) başlığın altında tek başına bir satıra iniyordu
          // (2026-09-27 tur görüntüsü). 320'nin üstünde başlık metnine iki
          // düğmeden sonra da ~200 nokta kalır; büyük yazıda yine alt alta.
          final stackTrailing =
              trailing != null &&
              (constraints.maxWidth < 320 || textScale >= 1.5);

          if (stackTrailing) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                copy(),
                const SizedBox(height: SahneSpace.x2),
                Align(alignment: Alignment.centerRight, child: trailing!),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy()),
              if (trailing != null) ...[
                const SizedBox(width: SahneSpace.x3),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bölüm etiketi — üst etiket biçemi (başlık ailesi, cümle düzeni).
///
/// 2026-09-29 Şahnê: sol aksan çubuğu kaldırıldı (Şahnê'de sol çubuk yok);
/// renk ham aksan değil, aksanın rolünün metin rengidir.
class ScreenSectionLabel extends StatelessWidget {
  const ScreenSectionLabel({
    required this.label,
    required this.accent,
    super.key,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final role = sahneRoleFor(accent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
      child: Text(
        label,
        style: SahneType.eyebrow.copyWith(
          color: role == SahneRole.neutral ? t.tx2 : t.roleText(role),
        ),
      ),
    );
  }
}
