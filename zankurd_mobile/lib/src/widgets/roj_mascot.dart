import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// Eski maskotun ruh hâlleri.
///
/// 2026-09-29 Şahnê: güneş maskotu kaldırıldı ("maskot: Yok … boş durumda
/// logo işareti", `spec_sahne.json`). Enum, çağıranlar kırılmasın diye
/// kalır; [RojMascot] artık onu yok sayar.
enum RojMood {
  /// Gülümseyen varsayılan hâl (onboarding, karşılama).
  happy,

  /// Kutlama (rozet, şampiyonluk).
  celebrate,

  /// Düşünceli: boş durumlar.
  thinking,

  /// Üzgün: yanlış cevap anı.
  sad,
}

/// Ana ekran selam maskotu: gece gülen güneş + «İyi Geceler» çelişmesin.
RojMood greetingMascotMood({required int hour, required int streak}) {
  if (streak > 0) return RojMood.celebrate;
  if (hour >= 22 || hour < 5) return RojMood.thinking;
  return RojMood.happy;
}

/// Marka işareti plakası — eski "Zana" maskotunun yerinde.
///
/// 2026-09-29 Şahnê: güneş maskotu kaldırıldı. API (boyut, ruh hâli,
/// `roj-mascot` anahtarı) çağıranlar kırılmasın diye kalır; bileşen artık
/// logo işaretini M pahlı bir plakada çizer ([BrandMarkPlate]). [mood] yok
/// sayılır. Dekoratiftir: ekran okuyucuya hiçbir şey söylemez.
class RojMascot extends StatelessWidget {
  const RojMascot({
    this.size = 96,
    this.mood = RojMood.happy,
    super.key = const ValueKey('roj-mascot'),
  });

  final double size;

  /// Yok sayılır (bkz. sınıf belgesi).
  final RojMood mood;

  @override
  Widget build(BuildContext context) => BrandMarkPlate(size: size);
}

/// Logo işareti plakası: M pahlı plaka içinde `assets/zankurd_icon.webp`.
///
/// Gecede Kulis (`s2`), gündüzde Perde (`s1`, beyaz) + 1 px kenar — dağlar
/// koyu zeminde kaybolmasın (A iskeletinin marka satırıyla aynı kural).
/// Dekoratiftir. [RojMascot] ve boş/hata durumları bunu çizer.
class BrandMarkPlate extends StatelessWidget {
  const BrandMarkPlate({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final day = Theme.of(context).brightness == Brightness.light;
    final mark = size * 0.72;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: day ? t.s1 : t.s2,
            shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
          ),
          // İşaret bir `Image` bileşeni değil, süs katmanıdır
          // (`DecorationImage`): görsel sayan ve semantik arayan bekçiler
          // (ör. tanıtımın "tam üç kategori görseli") onu içerik saymaz.
          child: Center(
            child: SizedBox.square(
              dimension: mark,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/zankurd_icon.webp'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
