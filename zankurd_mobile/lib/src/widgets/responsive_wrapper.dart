import 'package:flutter/material.dart';

import '../theme/sahne.dart';

/// Web masaüstü/tablet geniş ekranlarda içeriği ortalar ve maksimum genişlik
/// sınırı uygular. Mobil cihazlarda tam ekran davranışı korunur.
///
/// Mevcut uygulama: tek sütun + ortalama + [maxContentWidth] sınırı.
/// Gerçek iki sütunlu tablet düzeni kapsamlı bir tasarım işi;
/// izole bir sprint olarak planlanmalı (M-12).
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  /// Geniş ekranda içeriğin maksimum genişliği.
  ///
  /// 2026-08-02'ye kadar 1200'dü ve bu, iPad'de sınırın HİÇ BAĞLAMAMASI
  /// anlamına geliyordu: iPad Pro 13" dikey mantıksal genişliği ~1032 pt,
  /// yani 1200'ün altında. Sonuç, gerçek cihazda görüldü — telefon düzeni
  /// tablete gerilmiş hâlde çiziliyordu: hero kartı ~1400 pt boş bir
  /// dikdörtgene dönüşüyor, içerik sol %30'a sıkışıyor, altta yüzlerce pt
  /// boşluk kalıyordu (Aşama 1 denetimi, P1-002).
  ///
  /// `TARGETED_DEVICE_FAMILY = "1,2"` olduğu için Apple uygulamayı iPad'de
  /// İNCELER ve iPad ekran görüntüsü ister; "yalnız telefonda iyi görünsün"
  /// seçeneği yoktu.
  ///
  /// 820, bu sarmalayıcının görsel dilinin gerektirdiği ölçüdür: ortalanmış
  /// tek sütun — yani masaüstünde "telefon çerçevesi" görünümü. 1200 pt o çerçeve için fazla geniş olduğu
  /// gibi, tek sütunluk okuma ölçüsünü de aşıyordu.
  ///
  /// [AppShell]'in 768 px'lik masaüstü gezinme eşiği bundan küçük olduğu
  /// için NavigationRail'e geçiş hâlâ erişilebilir.
  static const double maxContentWidth = 820;

  /// Bu genişliğin üstünde içerik ortalanır.
  static const double wideThreshold = 600;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Mobil: tam ekran
    if (screenWidth <= wideThreshold) {
      return child;
    }

    // Tablet/masaüstü: içeriği ortala ve geniş ekran taşmasını sınırla.
    //
    // 2026-09-29 Şahnê: dış alan sayfa zemini (`bg`); sütun yanlarda 1 px
    // ayırıcı (`line`) ile ayrılır. Yuvarlak köşe ve bulanık gölge yok —
    // Şahnê'de şekil pahtır ve tek bulanık gölge birincil düğmededir.
    final t = SahneTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveWrapper.maxContentWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: t.line)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
