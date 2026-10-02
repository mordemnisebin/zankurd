import 'package:flutter/material.dart';

import 'brand_mark.dart';
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

/// Marka işareti — eski "Zana" maskotunun yerinde.
///
/// 2026-09-29 Şahnê: güneş maskotu kaldırıldı. API (boyut, ruh hâli,
/// `roj-mascot` anahtarı) çağıranlar kırılmasın diye kalır; bileşen artık
/// logo işaretini çizer ([BrandMarkPlate]). [mood] yok sayılır. Dekoratiftir:
/// ekran okuyucuya hiçbir şey söylemez.
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

/// Logo işareti: [size] genişliğinde L4 soru balonu, [size] kareye ortalı.
///
/// 2026-09-30: adı "plaka" olarak kaldı (çağıranlar kırılmasın) ama plaka
/// yok. Eskiden M pahlı bir plakada, Kulis/Perde üzerinde duruyordu: eski
/// logonun dağları koyu zeminde kaybolduğu için. Yeni işaret tek renkli ve
/// doygun (turuncu balon, içinde oyuk Z); plaka logonun etrafında kutu
/// içinde kutu yaratıyor ve kuyruğu sıkıştırıyordu. İşaret [BrandMark]
/// ile yol olarak çizilir, her boyutta keskindir. Dekoratiftir.
/// [RojMascot] ve boş/hata durumları bunu çizer.
class BrandMarkPlate extends StatelessWidget {
  const BrandMarkPlate({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: BrandMark(color: t.act, height: size / BrandMark.aspect),
        ),
      ),
    );
  }
}
