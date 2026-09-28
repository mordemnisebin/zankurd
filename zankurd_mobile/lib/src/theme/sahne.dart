import 'package:flutter/material.dart';

/// Şahnê tasarım sistemi — belirteçler, şekiller, aralıklar ve yazı ölçeği.
///
/// ## Niçin var
///
/// 2026-09-28 ölçümünde uygulamada ortak bir kural yoktu: sekiz ekranda altı
/// ayrı sayfa başlığı biçimi, 14 köşe yarıçapı, 23 yazı boyutu ve temanın
/// dışında 68 ham renk. Her ekran ayrı giydirilmişti. Üç tasarım yönü
/// maketlendi, üç bağımsız gözle değerlendirildi ve "Şahnê — Gece sahnesi"
/// seçildi (maket ve belirteç tablosu: `~/Projects/zankurd-tasarim/design/`
/// altında `spec_sahne.json`).
///
/// Kural: bir rengin, şeklin, aralığın ya da yazı boyutunun TEK kaynağı bu
/// dosyadır. Ekranlar değerleri buradan okur; yeni bir değer gerekiyorsa
/// önce buraya eklenir.
///
/// ## Renk rolleri
///
/// * **Agir** — ekranın tek birincil eylemi. Başka hiçbir yerde dolgu değil.
/// * **Boyax** — yarış (lal kök boyası). Durum (yanlış) için asla.
/// * **Zimrût** — öğrenme (zümrüt).
/// * **Zêr** — ödül ve ışık (altın): jeton, yıldız, XP, seri, skor.
/// * **Rast / Şaş** — durum: doğru / yanlış. Rol renklerinden ayrı bir
///   aile; durum hiçbir zaman yalnız renkle verilmez (✓ / ✗ ve söz).
///
/// Sahne her zaman gecedir: soru, sonuç ve sahne kartları gündüz temasında
/// da gece belirteçleriyle çizilir (bkz. [SahneStage]).
@immutable
class SahneTokens extends ThemeExtension<SahneTokens> {
  const SahneTokens({
    required this.bg,
    required this.nav,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.tx,
    required this.tx2,
    required this.tx3,
    required this.line,
    required this.edge,
    required this.act,
    required this.onAct,
    required this.actTx,
    required this.race,
    required this.raceTx,
    required this.raceTint,
    required this.learn,
    required this.learnTx,
    required this.learnTint,
    required this.learnBar,
    required this.gold,
    required this.goldTx,
    required this.goldTint,
    required this.okFill,
    required this.okTx,
    required this.okTint,
    required this.errFill,
    required this.errTx,
    required this.errTint,
    required this.rim,
  });

  /// Zemin (Şev). Gece çivit; gündüz soğuk açık gri-mavi (krem değil).
  final Color bg;

  /// Alt gezinme çubuğunun zemini.
  final Color nav;

  /// Yüzey (Perde): kart, liste grubu.
  final Color s1;

  /// Yükseltilmiş yüzey (Kulis): çip, ikincil düğme, şık, joker.
  final Color s2;

  /// İz (Ray): ilerleme izi, renksiz şık harfi, boş elmas.
  final Color s3;

  /// Birincil metin.
  final Color tx;

  /// İkincil metin.
  final Color tx2;

  /// Üçüncül metin. Silik gri açıklama yok: bu da AA (≥ 4.5) geçer.
  final Color tx3;

  /// Satır ve bölüm ayırıcı.
  final Color line;

  /// Gündüz yüzeylerinin 1 px kenarı; gecede saydam (katman tonla ayrılır).
  final Color edge;

  /// Agir — birincil eylem dolgusu.
  final Color act;

  /// Agir üstündeki metin.
  final Color onAct;

  /// Agir'in metin bağlantısı hâli (düz zeminde okunur).
  final Color actTx;

  /// Boyax — yarış kimliği.
  final Color race;
  final Color raceTx;
  final Color raceTint;

  /// Zimrût — öğrenme kimliği.
  final Color learn;
  final Color learnTx;
  final Color learnTint;

  /// Öğrenme ilerleme çubuğunun dolgusu (gündüzde koyulaşır).
  final Color learnBar;

  /// Zêr — ödül ve ışık.
  final Color gold;
  final Color goldTx;
  final Color goldTint;

  /// Rast — doğru durumu.
  final Color okFill;
  final Color okTx;
  final Color okTint;

  /// Şaş — yanlış durumu.
  final Color errFill;
  final Color errTx;
  final Color errTint;

  /// Mücevher karonun nötr kaşı.
  final Color rim;

  static const night = SahneTokens(
    bg: Color(0xFF0A0F2E),
    nav: Color(0xFF0D1335),
    s1: Color(0xFF131A42),
    s2: Color(0xFF1C2455),
    s3: Color(0xFF29336F),
    tx: Color(0xFFF6F3EC),
    tx2: Color(0xFFBCC3E4),
    tx3: Color(0xFF959DC9),
    line: Color(0x24BCC3E4),
    edge: Color(0x00000000),
    act: Color(0xFFFF8A3D),
    onAct: Color(0xFF1B0C02),
    actTx: Color(0xFFFF9A57),
    race: Color(0xFFC4265A),
    raceTx: Color(0xFFFF86AE),
    raceTint: Color(0xFF4A1233),
    learn: Color(0xFF1DB482),
    learnTx: Color(0xFF52DBA5),
    learnTint: Color(0xFF0B4637),
    learnBar: Color(0xFF1DB482),
    gold: Color(0xFFF5C24C),
    goldTx: Color(0xFFF5C24C),
    goldTint: Color(0xFF3A3218),
    okFill: Color(0xFF0E7453),
    okTx: Color(0xFF52DBA5),
    okTint: Color(0xFF0B4637),
    errFill: Color(0xFF6B1F1A),
    errTx: Color(0xFFFF7466),
    errTint: Color(0xFF45160F),
    rim: Color(0x29FFFFFF),
  );

  static const day = SahneTokens(
    bg: Color(0xFFE9EDF6),
    nav: Color(0xFFFFFFFF),
    s1: Color(0xFFFFFFFF),
    s2: Color(0xFFD8DEEE),
    s3: Color(0xFFD0D7EC),
    tx: Color(0xFF0E1433),
    tx2: Color(0xFF454E79),
    tx3: Color(0xFF566090),
    line: Color(0x1A0E1433),
    edge: Color(0x140E1433),
    act: Color(0xFFFF8A3D),
    onAct: Color(0xFF1B0C02),
    // #A84300 Kulis (s2) üstünde 4.499:1 kalıyordu; bir ton koyulaştı.
    actTx: Color(0xFF9E3F00),
    race: Color(0xFFC4265A),
    raceTx: Color(0xFFA8134A),
    raceTint: Color(0xFFFBE1EA),
    learn: Color(0xFF1DB482),
    learnTx: Color(0xFF08784F),
    learnTint: Color(0xFFD8F3E8),
    learnBar: Color(0xFF08784F),
    gold: Color(0xFFF5C24C),
    goldTx: Color(0xFF8A5A00),
    goldTint: Color(0xFFFBF0D2),
    okFill: Color(0xFF0E7453),
    okTx: Color(0xFF08784F),
    okTint: Color(0xFFD8F3E8),
    errFill: Color(0xFF6B1F1A),
    errTx: Color(0xFFB42318),
    errTint: Color(0xFFFDE4E1),
    rim: Color(0x290E1433),
  );

  /// Bağlamdaki belirteçler. Tema bir [SahneTokens] taşımıyorsa (ör. çıplak
  /// bir test `MaterialApp`i) parlaklığa göre gece ya da gündüz döner.
  static SahneTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SahneTokens>() ??
        (theme.brightness == Brightness.dark ? night : day);
  }

  @override
  SahneTokens copyWith() => this;

  @override
  SahneTokens lerp(ThemeExtension<SahneTokens>? other, double t) {
    if (other is! SahneTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SahneTokens(
      bg: l(bg, other.bg),
      nav: l(nav, other.nav),
      s1: l(s1, other.s1),
      s2: l(s2, other.s2),
      s3: l(s3, other.s3),
      tx: l(tx, other.tx),
      tx2: l(tx2, other.tx2),
      tx3: l(tx3, other.tx3),
      line: l(line, other.line),
      edge: l(edge, other.edge),
      act: l(act, other.act),
      onAct: l(onAct, other.onAct),
      actTx: l(actTx, other.actTx),
      race: l(race, other.race),
      raceTx: l(raceTx, other.raceTx),
      raceTint: l(raceTint, other.raceTint),
      learn: l(learn, other.learn),
      learnTx: l(learnTx, other.learnTx),
      learnTint: l(learnTint, other.learnTint),
      learnBar: l(learnBar, other.learnBar),
      gold: l(gold, other.gold),
      goldTx: l(goldTx, other.goldTx),
      goldTint: l(goldTint, other.goldTint),
      okFill: l(okFill, other.okFill),
      okTx: l(okTx, other.okTx),
      okTint: l(okTint, other.okTint),
      errFill: l(errFill, other.errFill),
      errTx: l(errTx, other.errTx),
      errTint: l(errTint, other.errTint),
      rim: l(rim, other.rim),
    );
  }
}

/// Temadan bağımsız sahne renkleri: yalnız gece sahnesinde (C iskeleti,
/// sahne kartı, sonuç) kullanılır ve iki temada da aynıdır.
class SahneStageColors {
  const SahneStageColors._();

  /// Sahne kartı degradesi (üst → alt).
  static const top = Color(0xFF1A2352);
  static const bottom = Color(0xFF121942);

  /// Yarış sahnesi degradesi.
  static const race1 = Color(0xFF7A1446);
  static const race2 = Color(0xFF4A1036);
  static const race3 = Color(0xFF2A0A1E);

  /// Altın hale (sayaç, 1. sıra) ve yarış halesi (≤ 5 sn).
  static const haloGold = Color(0x4DF5C24C);
  static const haloRace = Color(0x5CC4265A);

  /// Işık huzmesi ve sonuç ışınları.
  static const beam = Color(0x1FFFEECC);
  static const ray = Color(0x1FF5C24C);

  /// Madalyalar.
  static const silver = Color(0xFFC9D0EA);
  static const bronze = Color(0xFFD9925F);

  /// Çizimi olmayan kategori karosu (Sinema) — kobalt radyal.
  static const art1 = Color(0xFF3F74EE);
  static const art2 = Color(0xFF1D43B0);
  static const art3 = Color(0xFF0F2468);
}

/// Aralık ölçeği. Bütün boşluklar 4'ün katıdır; sayfa kenarı 16.
class SahneSpace {
  const SahneSpace._();

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;

  /// Sayfa yan kenarı.
  static const double page = 16;

  /// Başlık → içerik.
  static const double titleGap = 16;

  /// Bölüm başlığının üstü ve altı.
  static const double sectionTop = 24;
  static const double sectionBottom = 12;

  /// Kartlar arası.
  static const double cardGap = 12;
}

/// Kesik köşe (45° pah) şekil dili. Yarıçap değil, pah boyu.
///
/// * S (4) — yüksekliği ≤ 28 öğe: rozet, durum karesi, ilerleme çubuğu.
/// * M (8) — 32–56 öğe: çip, düğme, şık, ikon karosu, gezinme plaketi.
/// * L (12) — kart ve karo.
/// * Elmas — avatar, ilerleme elması, sayaç, yol düğümü.
class SahneShape {
  const SahneShape._();

  static const double sValue = 4;
  static const double mValue = 8;
  static const double lValue = 12;

  static const BeveledRectangleBorder s = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(sValue)),
  );
  static const BeveledRectangleBorder m = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(mValue)),
  );
  static const BeveledRectangleBorder l = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(lValue)),
  );

  /// Kenarlıklı çeşit (halka). Halkalar içe çizilir.
  static BeveledRectangleBorder withSide(
    BeveledRectangleBorder shape,
    Color color, {
    double width = SahneRing.r1,
  }) {
    return BeveledRectangleBorder(
      borderRadius: shape.borderRadius,
      side: BorderSide(
        color: color,
        width: width,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    );
  }

  /// Elmas: kenar uzunluğunun yarısı kadar pah, yani 45° dönmüş kare.
  static BeveledRectangleBorder diamond(double size, {BorderSide? side}) {
    return BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(size / 2)),
      side: side ?? BorderSide.none,
    );
  }
}

/// Halka (içe çizilen kenar) kalınlıkları.
class SahneRing {
  const SahneRing._();

  /// Mücevher kaşı, Sen satırı.
  static const double r1 = 1.5;

  /// Şık durumu, seçili çip, odak halkası.
  static const double r2 = 2;

  /// Madalya.
  static const double r3 = 3;
}

/// Hareket belirteçleri (ms).
class SahneMotion {
  const SahneMotion._();

  static const answerReveal = Duration(milliseconds: 240);
  static const fade = Duration(milliseconds: 160);
  static const scoreFlight = Duration(milliseconds: 420);
  static const diamondPop = Duration(milliseconds: 200);
  static const tension = Duration(milliseconds: 600);
}

/// Yazı ölçeği: beş boyut, her birinin tek satır yüksekliği.
///
/// Başlık ailesi Bricolage Grotesque (700/800), metin ailesi Onest
/// (400–700). İkisi de OFL; `assets/fonts` altında sabit kalınlık
/// dosyaları olarak gömülü, Türkçe ve Kurmancî harflerin hepsini taşır.
class SahneType {
  const SahneType._();

  static const display = 'BricolageGrotesque';
  static const text = 'Onest';

  /// 64/64 — sonuç puanı.
  static const TextStyle screen = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 64,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 28/32 — sekme başlığı, soru metni.
  static const TextStyle title = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 28,
    height: 32 / 28,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 22/28 — bölüm ve kart başlığı, açılan sayfa başlığı, sayaç.
  static const TextStyle headline = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 28 / 22,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 16/24 — metin, şık metni, liste satırı.
  static const TextStyle body = TextStyle(
    fontFamily: text,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 24 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 16/24 kalın — satır başlığı, şık metni.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: text,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 24 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 16/24 — düğme etiketi (başlık ailesi, 800).
  static const TextStyle button = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    height: 24 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 14/20 — açıklama, çip, gezinme etiketi.
  static const TextStyle caption = TextStyle(
    fontFamily: text,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 14/20 — üst etiket ve rozet: başlık ailesi, BÜYÜK HARF, +%8 aralık.
  /// Metin [upperFor] ile büyütülür; `toUpperCase()` yerele duyarsızdır.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 14 * 0.08,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Yerele duyarlı büyük harf.
  ///
  /// Dart'ın `toUpperCase()`'i "i"yi "I" yapar; Türkçede "İ" olmalı. Kurmancî
  /// Latin alfabesinde noktasız ı yoktur ve büyük "i" de "I"dır. Bu yüzden
  /// Türkçe için i→İ, ı→I önceden çevrilir; Kurmancîde varsayılan doğrudur
  /// (î → Î, ê → Ê zaten doğru büyür).
  static String upperFor(String text, {required bool isKu}) {
    if (isKu) return text.toUpperCase();
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
}

/// Sahne kapsamı: gündüz temasında da gece belirteçleriyle çizilen bölge
/// (soru ekranı, sonuç, sahne kartı). Tema `AppTheme.stage` ile değiştirilir,
/// böylece altındaki her bileşen — ayrıca renk geçmeden — gece renklerini
/// alır.
class SahneStage extends StatelessWidget {
  const SahneStage({super.key, required this.stage, required this.child});

  /// Gece teması (genelde `AppTheme.stage`). Döngüsel içe aktarmayı
  /// önlemek için çağıran verir.
  final ThemeData stage;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(data: stage, child: child);
}
