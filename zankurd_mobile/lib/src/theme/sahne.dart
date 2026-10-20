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
    required this.actShadow,
    required this.actShadowBlur,
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
    required this.goldDeep,
    required this.onGold,
    required this.silverTx,
    required this.bronzeTx,
    required this.okFill,
    required this.okTx,
    required this.okTint,
    required this.onOk,
    required this.errFill,
    required this.errTx,
    required this.errTint,
    required this.rim,
  });

  /// Zemin (Şev). Gece nötr grafit; gündüz soğuk açık gri-mavi (krem değil).
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

  /// Yüzeylerin 1 px kenarı: gündüz açık gri-mavi, gece ince saydam çizgi.
  final Color edge;

  bool get _isDay => bg.computeLuminance() > 0.5;

  /// Ortak pasif dolgu (kurul 3. tur 2026-10-20): DÜZ soluk dolgu, kenarsız.
  /// İkincil düğmeyle karışmasın diye pasifin kenarı YOKTUR (ikincil görünür
  /// kenar taşır, bkz. [secondaryEdge]). Gündüz `#E3E7F0`, gece `#282A2F` (tx3 etiket ile ≥ 4.5).
  Color get disabledFill =>
      _isDay ? const Color(0xFFE3E7F0) : const Color(0xFF282A2F);

  /// "N jeton eksik" notu (kurul 5. tur 2026-10-20): altın metin gündüz
  /// kartta soluk kalıyordu; gündüz koyu kehribar `#6E4400` (beyaz üstünde
  /// ≈ 8.9:1), gece Zêr metni.
  /// Sonuç kahramanının "puan · %67 doğruluk" satırı (tur 10b, Gemini +
  /// Grok): koyu temada 13 px / 400 [tx2] 64 punto sayının altında sönük
  /// kalıyordu. Ana ikincil metinden bir ton açık (gecede daha açık, gündüzde
  /// daha koyu): [tx2] ile [tx] arası %35.
  Color get heroCaptionTx => Color.lerp(tx2, tx, 0.35)!;

  Color get shortfallTx => _isDay ? const Color(0xFF6E4400) : goldTx;

  /// Pasif etiket: üçüncül metin; pasif dolguya karşı yine ≥ 3 (okunur ama
  /// etkin ikincil etiketten (`tx`) belli ölçüde soluk).
  ///
  /// Tur 8 (Opus + Grok, 115/116/73/14): `tx3` pasif dolguya 4,9 (gündüz) ve
  /// 4,6 (gece) idi: AA'yı geçiyor ama "Yarışı başlat"/"Sonraki" yazısı yine
  /// silik duruyordu. Gündüz `#3F4872` (≈ 7:1), gece `#A9ABB3` (≈ 6,2:1);
  /// etkin etiketten (`tx`) hâlâ soluk, ama okunur.
  Color get disabledFg =>
      _isDay ? const Color(0xFF3F4872) : const Color(0xFFA9ABB3);

  /// İkincil düğmenin 1,5 px görünür kenarı (mürekkep ~%40): şeffaf dolgu +
  /// bu kenar + güçlü etiket = ikincil; kenarsız soluk dolgu = pasif.
  Color get secondaryEdge => tx.withValues(alpha: 0.4);

  /// Metin alanı dolgusu (kurul 2026-10-20): gündüz Şev'e yakın açık ton, kart
  /// içinde beyazdan ve pasif düğmeden ayrılır; gece Kulis.
  Color get fieldFill => _isDay ? const Color(0xFFF4F6FA) : s2;

  /// Metin alanının dinlenme kenarı, 1 px: eski `edge` zemine karışıyordu
  /// (Giriş ekranında alanlar arka planla birleşti).
  Color get fieldEdge => _isDay ? const Color(0xFFB4BCD0) : tx3;

  /// Şık çubuğunun dinlenme dolgusu (tur 8, 5 denetçinin 5'i): gecede Kulis
  /// (`s2`) zemine (`bg`) 1,2:1 yakındı; bir ton açık Ray (`s3`) + [optionEdge]
  /// kenarı. Gündüz Kulis aynı kalır.
  Color get optionFill => _isDay ? s2 : s3;

  /// Şık çubuğunun 1 px kenarı: gece zeminden ve dolgudan ayrılan ince çizgi
  /// (`#4C4F57`), gündüz `edge`.
  Color get optionEdge => _isDay ? edge : const Color(0xFF4C4F57);

  /// Şık harf karosu: gecede dolgu Ray olduğu için karo bir ton koyu (`s1`).
  Color get optionLetterFill => _isDay ? s3 : s1;

  /// Agir — birincil eylem dolgusu.
  final Color act;

  /// Agir üstündeki metin.
  final Color onAct;

  /// Agir'in metin bağlantısı hâli (düz zeminde okunur).
  final Color actTx;

  /// TEK metin bağlantısı / ikincil eylem rengi. Yeşil (`okTx`) yalnız
  /// doğruya, kırmızı (`errTx`) yalnız hataya aittir; "gözden geçir",
  /// "davet et", "Adını gir" gibi dokunulur metinler hep bu belirteci
  /// kullanır (7. kurul: aynı eylem ekrana göre yeşil/turuncu/gri çıkıyordu).
  Color get linkTx => actTx;

  /// TEK kart üst etiketi (eyebrow) rengi ve hap dolgusu (tur 9b, Opus iki
  /// tur + Gemini): "İlk ders" yeşil, "Hızlı düello" kırmızı/mor, "Sıradaki
  /// ders" nane yeşili çıkıyordu; kartların üst etiketi üç ayrı renk
  /// konuşuyordu. Artık hepsi bağlantı rengidir ([linkTx]); hap biçimli
  /// etiket aynı rengin %12'lik açık dolgusunu ([eyebrowFill]) taşır.
  /// Yeşil yalnız doğruya/başarıya, kırmızı yalnız hataya kalır.
  Color get eyebrowTx => linkTx;
  Color get eyebrowFill => act.withValues(alpha: 0.12);

  /// Eylem gölgesinin rengi ve bulanıklığı — ekrandaki TEK bulanık gölge,
  /// yalnız birincil düğmede (`0 8 24 -8`; gündüzde `0 8 20 -8`, koyu
  /// turuncu). Rengi Agir'den türetilemez: gündüzde ayrı bir tondur.
  final Color actShadow;
  final double actShadowBlur;

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

  /// Jeton glifinin iç halkası ve damgası (koyu altın). İki temada aynı.
  final Color goldDeep;

  /// Zêr dolgusu üstündeki glif ve metin (ustalık yıldızı, Sen avatarı).
  final Color onGold;

  /// Gümüş ve bronz METİN (sıralamada 2. ve 3. sıra rakamı). Sahne
  /// madalyaları ([SahneStageColors.silver], [SahneStageColors.bronze])
  /// gündüz zemininde 4.5:1'i tutmadığı için gündüzde koyulaşır. Perde
  /// (`s1`) ve zemin (`bg`) üstünde iki temada ≥ 4.5:1.
  final Color silverTx;
  final Color bronzeTx;

  /// Rast — doğru durumu.
  final Color okFill;
  final Color okTx;
  final Color okTint;

  /// Rast dolgusu ([okTx] ile dolan elmas) üstündeki ✓. Gecede koyu,
  /// gündüzde — dolgu koyu zümrüte döndüğü için — beyaz.
  final Color onOk;

  /// Şaş — yanlış durumu.
  final Color errFill;
  final Color errTx;
  final Color errTint;

  /// Mücevher karonun nötr kaşı.
  final Color rim;

  /// TEK seçili stili (kurul incelemesi 2026-10-19): seçili çip, segment ve
  /// sekme her yerde Agir'den türer — açık turuncu ton dolgu + turuncu çizgi
  /// + koyu turuncu metin. Dolu turuncu yalnız ana eylem düğmesindedir;
  /// seçili çip de dolu olunca ikisi birbiriyle yarışıyordu (7 modelden 4'ü).
  /// Kurul 3. tur 2026-10-20: seçili hâl soluktu (oda kurma sheet'i); ton
  /// koyulaştı, çizgi 2 px, etiket kalın. Metin ≥ 4.5:1 ([selTx] ton dolgu
  /// üstünde; test bunu ölçer).
  ///
  /// Gece (2026-10-20): yarı saydam turuncu koyu zeminde çamur kahve-mor
  /// oluyordu; seçili çip OPAK `#3A2A1F` dolgu + 2 px Agir çizgi + `#FFB27F`
  /// etiket (≥ 7.8:1).
  ///
  /// Kurul 4. tur 2026-10-20 (AI Studio, Grok): seçili hâl hâlâ yalnız ince
  /// çerçeveyle okunuyordu; dolgu koyulaştı (gündüz `#FFE1CC`, gece opak
  /// `#4A321F`). Metin hâlâ ≥ 4.5:1 (bekçi ölçer).
  Color get selFill =>
      _isNight ? const Color(0xFF4A321F) : const Color(0xFFFFE1CC);
  Color get selLine => act;
  Color get selTx => _isNight ? const Color(0xFFFFB27F) : actTx;

  bool get _isNight => bg.computeLuminance() < 0.2;

  /// Günün dersi kartının tepesindeki manzara şeridi ("Çiya", 2026-10-20
  /// kimlik kararı; kullanıcının açık tercihi). Logodaki dağ sırtı büyüyüp
  /// alçak bir manzaraya döner: gündüz şafak gökyüzü + lacivert tonlu üç
  /// katman sırt + güneş; gece yıldızlı lacivert gök + aynı sırtlar koyu +
  /// zirvede TEK turuncu ışık. Değerler maketten (`B_ciya.html`); gece
  /// değerleri aynı rolün koyu ikizi. Yalnız bu şerit kullanır.
  Color get vistaSkyTop =>
      _isDay ? const Color(0xFFFFD9BC) : const Color(0xFF1B1E3A);
  Color get vistaSkyBottom =>
      _isDay ? const Color(0xFFFFF7EF) : const Color(0xFF2E3152);

  /// Gündüz güneşi; gecede zirvedeki tek ışık [act] (turuncu) olur.
  Color get vistaSun => _isDay ? const Color(0xFFFFB27F) : act;
  Color get vistaRidgeFar =>
      _isDay ? const Color(0xFFD6DCEE) : const Color(0xFF3A4068);
  Color get vistaRidgeMid =>
      _isDay ? const Color(0xFF9EA9CF) : const Color(0xFF2A2F55);
  Color get vistaRidgeNear =>
      _isDay ? const Color(0xFF454E79) : const Color(0xFF191B30);

  /// Gece yıldızı (gündüz çizilmez).
  Color get vistaStar => const Color(0xFFF5F3EF);

  /// Kilim imzasının rengi (2026-10-20 kimlik kararı, imza "Kilim"):
  /// kökboya kırmızısı ile turuncu arasında tek ton. Yarış kimliğinin pembe
  /// düello vurgusundan ([raceTx]) ve Agir'den ([act]) ayrı; gündüz Perde
  /// üstünde koyu, gece düşük opaklıkla çizilir (bkz. [kilimOpacity]).
  Color get kilimTx =>
      _isDay ? const Color(0xFFB4442A) : const Color(0xFFE0663F);

  /// Kilim şeridinin opaklığı: gecede şerit fısıltı kalır.
  double get kilimOpacity => _isDay ? 1.0 : 0.55;

  static const night = SahneTokens(
    // 2026-10-20 gece paleti kuruldu (9 modelli kurul oy birliğiyle B):
    // nötr grafit, mavi ton yok; turuncu Agir aynı. Eski lacivert (#0A0F2E)
    // mavi tonlu yüzeylerle katmanları bulandırıyor, turuncuyla tamamlayıcı
    // titreşim yapıyor, yarı saydam turuncu tonlar lacivert üstünde çamur
    // moru oluyordu. Gündüz temasının koyu ikizi: aynı turuncu, aynı roller.
    // Okunurluk: tx, bg/s1/s2/s3 üstünde 16.9/15.2/13.5/11.4; tx2 ≥ 6.5;
    // tx3 ≥ 4.0 (yüzeylerde AA'ya yakın, test ölçer).
    bg: Color(0xFF121214),
    nav: Color(0xFF17171A),
    // 2026-10-20 (tur 6b, 20/21/22): kart/zemin ayrımı zayıftı (2 denetçi):
    // Perde #1C1D21, Şev #121214 üstünde yalnız 1,13:1 duruyordu. Perde bir
    // ton açıldı (#222328), Kulis ve Ray ona göre kaydı; zemin #121214 ve
    // grafit kimlik aynı. Kenar da bir ton belirginleşti (#3A3D44).
    s1: Color(0xFF222328),
    s2: Color(0xFF2B2C32),
    s3: Color(0xFF34363C),
    tx: Color(0xFFF5F3EF),
    // 2026-10-20 (kurul 9-10. tur, ChatGPT + Grok + Codex): ikincil ve
    // üçüncül yazı grafit kartlarda sönük okunuyordu. tx2 #B9BAC0 → #C4C6CD
    // (Perde üstünde ~9:1), tx3 #8F9199 → #A2A5AD (Perde üstünde ~6:1);
    // sıra (tx > tx2 > tx3) korunur.
    tx2: Color(0xFFC4C6CD),
    tx3: Color(0xFFA2A5AD),
    // Ayırıcı ve yüzey kenarı DEKORATİF (opak, saydam değil): etkileşimli
    // kenar için tx3 kullanılır (≥ 3:1).
    line: Color(0xFF3A3D44),
    edge: Color(0xFF3A3D44),
    // Büyük dolgularda (birincil düğme) gece turuncusu bir ton sönük: tam
    // doygun #FF8A3D koyu zeminde göz yoruyordu.
    act: Color(0xFFF08A4A),
    onAct: Color(0xFF1B0C02),
    actTx: Color(0xFFFF9A57),
    // rgba(255,138,61,.7)
    actShadow: Color(0xB3FF8A3D),
    actShadowBlur: 24,
    race: Color(0xFFE8638F),
    raceTx: Color(0xFFFF86AE),
    raceTint: Color(0xFF3A2229),
    learn: Color(0xFF34C795),
    learnTx: Color(0xFF52DBA5),
    learnTint: Color(0xFF1E2F28),
    learnBar: Color(0xFF34C795),
    gold: Color(0xFFF5C24C),
    goldTx: Color(0xFFF5C24C),
    goldTint: Color(0xFF362E1C),
    goldDeep: Color(0xFFB07D12),
    onGold: Color(0xFF1E1400),
    // Gümüş, ikincil metinden (4. sıra ve sonrası) parlaklığıyla ayrılsın
    // diye sahne madalyasından bir ton açık; bronz sahne madalyasının aynısı.
    silverTx: Color(0xFFDDDEE3),
    bronzeTx: SahneStageColors.bronze,
    okFill: Color(0xFF0E7453),
    okTx: Color(0xFF52DBA5),
    okTint: Color(0xFF1E2F28),
    onOk: Color(0xFF03140D),
    errFill: Color(0xFF6B1F1A),
    errTx: Color(0xFFFF7466),
    errTint: Color(0xFF3A2220),
    rim: Color(0x29FFFFFF),
  );

  // 2026-10-19 sadeleşme: gündüz zemini #F4F6FA, kart beyaz, kenar 1 px
  // #E3E7F0 (eski zemin #E9EDF6 artık yükseltilmiş yüzey `s2`; eski `s2`
  // #D8DEEE kartın içinde fazla koyu, "kalabalık" izlenimi veriyordu).
  static const day = SahneTokens(
    bg: Color(0xFFF4F6FA),
    nav: Color(0xFFFFFFFF),
    s1: Color(0xFFFFFFFF),
    s2: Color(0xFFE9EDF6),
    s3: Color(0xFFD0D7EC),
    tx: Color(0xFF0E1433),
    tx2: Color(0xFF454E79),
    tx3: Color(0xFF566090),
    line: Color(0x1A0E1433),
    edge: Color(0xFFE3E7F0),
    act: Color(0xFFFF8A3D),
    onAct: Color(0xFF1B0C02),
    // #A84300 Kulis (s2) üstünde 4.499:1 kalıyordu; bir ton koyulaştı.
    actTx: Color(0xFF9E3F00),
    // rgba(214,98,20,.6)
    actShadow: Color(0x99D66214),
    actShadowBlur: 20,
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
    goldDeep: Color(0xFFB07D12),
    onGold: Color(0xFF1E1400),
    // Perde üstünde 5.6:1 ve 6.1:1; zeminde 4.8:1 ve 5.2:1.
    silverTx: Color(0xFF5F6878),
    bronzeTx: Color(0xFF8F5427),
    okFill: Color(0xFF0E7453),
    okTx: Color(0xFF08784F),
    okTint: Color(0xFFD8F3E8),
    onOk: Color(0xFFFFFFFF),
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
      actShadow: l(actShadow, other.actShadow),
      actShadowBlur: actShadowBlur + (other.actShadowBlur - actShadowBlur) * t,
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
      goldDeep: l(goldDeep, other.goldDeep),
      onGold: l(onGold, other.onGold),
      silverTx: l(silverTx, other.silverTx),
      bronzeTx: l(bronzeTx, other.bronzeTx),
      okFill: l(okFill, other.okFill),
      okTx: l(okTx, other.okTx),
      okTint: l(okTint, other.okTint),
      onOk: l(onOk, other.onOk),
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
  static const top = Color(0xFF24252A);
  static const bottom = Color(0xFF1A1B1F);

  /// Yarış sahnesi degradesi.
  static const race1 = Color(0xFF6B2A45);
  static const race2 = Color(0xFF43202F);
  static const race3 = Color(0xFF25141C);

  /// Altın hale (sayaç, 1. sıra) ve yarış halesi (≤ 5 sn).
  static const haloGold = Color(0x4DF5C24C);
  static const haloRace = Color(0x5CE8638F);

  /// Işık huzmesi ve sonuç ışınları.
  static const beam = Color(0x1FFFEECC);
  static const ray = Color(0x1FF5C24C);

  /// Madalyalar.
  static const silver = Color(0xFFC9CBD2);
  static const bronze = Color(0xFFD9925F);

  /// Çizimi olmayan kategori karosu (Sinema) — nötr grafit radyal.
  static const art1 = Color(0xFF5A5C66);
  static const art2 = Color(0xFF3C3E46);
  static const art3 = Color(0xFF26272C);

  /// Sayacın boş izi: rgba(143,145,153,.36).
  static const timerTrack = Color(0x5C8F9199);

  /// Yarış sahnesinin yumuşak metni (düello meta satırı, VS rakibi).
  static const raceSoft = Color(0xFFFFC9DA);

  /// Oyun sahnesinin alttan ışıması: rgba(240,138,74,.14).
  static const underglow = Color(0x24F08A4A);

  /// Sahne zemini çiziminin opaklığı (%14). `Image.color` + `modulate` ile
  /// uygulanır; `Opacity` katmanı (saveLayer) açılmaz.
  static const backdropTint = Color(0x24FFFFFF);
}

/// Kategori ışığı — oyun sahnesinin ışık huzmesini kategoriye göre boyar.
///
/// ## Niçin var
///
/// Soru sahnesi her kategoride aynı beyazımsı huzmeyi taşıyordu; kategori
/// yalnız %14'lük sahne zemininde (çizim) seziliyordu ve çizimi olmayan
/// kategoride hiç seçilmiyordu. Huzme sahnenin en parlak öğesi: rengi
/// kategoriyi tek bakışta söyler.
///
/// ## Kural
///
/// Bu renkler YALNIZ ışıktır (huzme, hale). Dolgu, metin, kenar ya da
/// ikon rengi değildir; rol renklerinin (Agir, Boyax, Zimrût, Zêr) ve durum
/// renklerinin (Rast, Şaş) yerini almaz. Işık her zaman varsayılan huzmenin
/// yoğunluğunda (%12) çizilir. Tabloda olmayan kategori varsayılan huzmeye
/// ([SahneStageColors.beam]) düşer.
class SahneCategoryLight {
  const SahneCategoryLight._();

  static const ziman = Color(0xFF26B8C4);
  static const cand = Color(0xFFEA6A4F);
  static const dirok = Color(0xFFD4A15A);
  static const edebiyat = Color(0xFFE46E90);
  static const cografya = Color(0xFF3DB26A);
  static const muzik = Color(0xFFF08A3C);
  static const sinema = Color(0xFFA98BF0);

  /// Kanonik kategori kimliği → ışık (bkz. `CategoryVisuals.canonicalName`).
  static const Map<String, Color> byCategory = {
    'Ziman': ziman,
    'Çand': cand,
    'Dîrok': dirok,
    'Edebiyat': edebiyat,
    'Cografya': cografya,
    'Muzîk': muzik,
    'Sînema': sinema,
  };

  /// Kanonik kategori kimliğinin ışığı; bilinmeyen kategori `null`.
  static Color? of(String canonicalCategory) => byCategory[canonicalCategory];

  /// Işığın huzme rengi: varsayılan huzmeyle aynı yoğunluk (%12).
  static Color beamOf(Color? light) => light == null
      ? SahneStageColors.beam
      : light.withValues(alpha: SahneStageColors.beam.a);
}

/// Kategori tonu — çizimsiz kategori karosunun düz zemini ve ince ayrıntısı.
///
/// ## Niçin var
///
/// 2026-09-29 doğallık (K1): kategori çizimleri uygulamanın en belirgin
/// "üretilmiş görsel" iziydi. Ana sayfa karosu çizimsiz olur: kategorinin
/// renk ailesinden düz bir zemin, üstünde ince bir pah yüzeyi, ad ve küçük
/// ikon. Kategori renkleri eskiden `CategoryVisuals` içinde Şahnê'den
/// bağımsız bir tabloydu ("Rengîn Editorial", 2026-08-03); artık tek kaynak
/// burasıdır ve `CategoryVisuals.color`/`gradientColors` buradan okur.
///
/// ## Kural
///
/// * [ground] — düz zemin. Kategori ışığının ([SahneCategoryLight]) tonunda,
///   koyu ve kısık doygunlukta; gece birincil metni (`tx`) üstünde ≥ 6.9:1.
///   Karo her iki temada da bu zemindir (sahne gibi, kimlik taşır).
/// * [deep] — aynı tonun bir basamak koyusu (eski gradyanın koyu ucu).
/// * [detail] — ince ayrıntının rengi: ışık tablosundaki kategori ışığı.
///   Yalnız çizgi/yüzey ayrıntısında, düşük örtücülükte; metin değil.
///
/// Işık tablosunda olmayan dört kategori (Siyaset, Paradigma, Teknolojî;
/// 2026-09-30'da gizlilikten çıktılar; ve aynı gün eklenen Cîhan) tonlarını
/// kalan boşluklardan alır (zeytin, erik, çelik mavi, deniz petrolü).
@immutable
class SahneCategoryTone {
  const SahneCategoryTone({
    required this.ground,
    required this.deep,
    required this.detail,
  });

  final Color ground;
  final Color deep;
  final Color detail;

  static const ziman = SahneCategoryTone(
    ground: Color(0xFF254D51),
    deep: Color(0xFF1E4042),
    detail: SahneCategoryLight.ziman,
  );
  static const cand = SahneCategoryTone(
    ground: Color(0xFF583028),
    deep: Color(0xFF42251E),
    detail: SahneCategoryLight.cand,
  );
  static const dirok = SahneCategoryTone(
    ground: Color(0xFF584428),
    deep: Color(0xFF42331E),
    detail: SahneCategoryLight.dirok,
  );
  static const edebiyat = SahneCategoryTone(
    ground: Color(0xFF582836),
    deep: Color(0xFF421E29),
    detail: SahneCategoryLight.edebiyat,
  );
  static const cografya = SahneCategoryTone(
    ground: Color(0xFF275037),
    deep: Color(0xFF20412D),
    detail: SahneCategoryLight.cografya,
  );
  static const muzik = SahneCategoryTone(
    ground: Color(0xFF633B20),
    deep: Color(0xFF4A2C18),
    detail: SahneCategoryLight.muzik,
  );
  static const sinema = SahneCategoryTone(
    ground: Color(0xFF362858),
    deep: Color(0xFF291E42),
    detail: SahneCategoryLight.sinema,
  );
  static const teknoloji = SahneCategoryTone(
    ground: Color(0xFF283A58),
    deep: Color(0xFF1E2D42),
    detail: Color(0xFF5F91E0),
  );
  // Cîhan: deniz petrolü. Teknolojî'nin lacivertiyle (0xFF22395E) Ziman'ın
  // yeşilimsi turkuazı (0xFF22595E) arasındaki boşluk; zemin gece birincil
  // metni üstünde ≥ 4,5:1 (bekçi: category_color_identity_test).
  static const cihan = SahneCategoryTone(
    ground: Color(0xFF274A63),
    deep: Color(0xFF1D394E),
    detail: Color(0xFF69BADD),
  );
  static const paradigma = SahneCategoryTone(
    ground: Color(0xFF502858),
    deep: Color(0xFF3D1E42),
    detail: Color(0xFFCA89D6),
  );
  // Zemin 0xFF575528 idi: alt konu bandındaki gece alt satırı (`tx2`) 4,41:1
  // kalıyordu (< 4,5). Kimliği bozmayan bir basamak koyulaştırıldı (4,61:1);
  // bekçi yalnız yedi konuyu ölçtüğü için kusur bu üçüne bakılmadan
  // sessiz kalmıştı (`sahne_topic_marks_test`, artık 11 işaretin hepsi).
  static const siyaset = SahneCategoryTone(
    ground: Color(0xFF4B492B),
    deep: Color(0xFF3E3C22),
    detail: Color(0xFFADA855),
  );

  /// Tabloda olmayan kategori: sahne kartının gece tonu, ayrıntı üçüncül
  /// metin.
  static const fallback = SahneCategoryTone(
    ground: SahneStageColors.top,
    deep: SahneStageColors.bottom,
    detail: Color(0xFF8F9199),
  );

  /// Kanonik kategori kimliği → ton (bkz. `CategoryVisuals.canonicalName`).
  static const Map<String, SahneCategoryTone> byCategory = {
    'Ziman': ziman,
    'Çand': cand,
    'Dîrok': dirok,
    'Edebiyat': edebiyat,
    'Cografya': cografya,
    'Muzîk': muzik,
    'Sînema': sinema,
    'Teknolojî': teknoloji,
    'Paradigma': paradigma,
    'Siyaset': siyaset,
    'Cîhan': cihan,
  };

  /// Kanonik kategori kimliğinin tonu; bilinmeyen kategori [fallback].
  static SahneCategoryTone of(String canonicalCategory) =>
      byCategory[canonicalCategory] ?? fallback;

  @override
  bool operator ==(Object other) =>
      other is SahneCategoryTone &&
      other.ground == ground &&
      other.deep == deep &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(ground, deep, detail);
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

/// Şekil dili: yumuşak yuvarlak köşe + yalnız marka aksanında kesik köşe.
///
/// ## 2026-10-19 sadeleşme
///
/// Test edenler genel tasarımı "çok kalabalık, gözü yoruyor" diye
/// değerlendirdi; iki bağımsız dış inceleme (Gemini, ChatGPT) aynı bulguyu
/// verdi: her kart ve düğmenin pahlı köşesi, üstüne doygun dolgu, sayfayı
/// "oyun menüsü" gürültüsüne çeviriyordu. Karar (onaylı maket): kart ve
/// karo YUVARLAK dikdörtgen (16), düğme, çip ve şık YUVARLAK (12). Kesik
/// köşe (pah) yalnız küçük rozet, sıra/seviye mücevheri ve jeton çipinde
/// kalır: markanın tek imza ayrıntısı olarak, az olduğu için anlamlı.
///
/// * [l] — kart ve karo: yarıçap 16.
/// * [m] — düğme, şık, çip, joker, ikon karosu: yarıçap 12.
/// * [s] — rozet, durum karesi: pah 4 (kesik köşe kalır).
/// * [chamferM] / [chamferL] — marka aksanı: jeton çipi, sıra/seviye
///   mücevheri, avatar ([forSize]). Pah boyu 8 / 12.
/// * Elmas — YALNIZ ders sayacı ve sonuç/mücevher süsü (soru ilerlemesi
///   artık ince çubuk).
class SahneShape {
  const SahneShape._();

  /// Öğenin boyuna uygun pahlı kare: ≤ 28 → S, ≤ 56 → M, üstü → L.
  /// Avatar ve avatar renk örnekleri bunu kullanır (marka aksanı: pah
  /// kalır).
  static BeveledRectangleBorder forSize(double size) {
    if (size <= 28) return s;
    if (size <= 56) return chamferM;
    return chamferL;
  }

  /// Yuvarlak yarıçaplar: kart / kontrol.
  static const double lValue = 16;
  static const double mValue = 12;

  /// Pah boyları (marka aksanı).
  static const double sValue = 4;
  static const double chamferMValue = 8;
  static const double chamferLValue = 12;

  /// Kart ve karo.
  static const RoundedRectangleBorder l = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(lValue)),
  );

  /// Düğme, şık, çip, joker.
  static const RoundedRectangleBorder m = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(mValue)),
  );

  /// Rozet ve durum karesi: kesik köşe kalır.
  static const BeveledRectangleBorder s = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(sValue)),
  );
  static const BeveledRectangleBorder chamferM = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(chamferMValue)),
  );
  static const BeveledRectangleBorder chamferL = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(chamferLValue)),
  );

  /// Kenarlıklı çeşit (halka). Halkalar içe çizilir; şekil türü korunur.
  static T withSide<T extends OutlinedBorder>(
    T shape,
    Color color, {
    double width = SahneRing.r1,
  }) {
    return shape.copyWith(
          side: BorderSide(
            color: color,
            width: width,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        )
        as T;
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

  /// 26/32 — YALNIZ soru metni (soru ekranı, düello, seviye belirleme).
  ///
  /// 2026-10-19 sadeleşme: soru 28/32 ile çiziliyordu; üstündeki ışık
  /// huzmesi ve elmas sayaçla yarışırken ekranın en yüksek sesiydi. 24/30
  /// hâlâ büyük ve ağır (800) okunur ama sahnenin geri kalanıyla aynı
  /// ölçekte durur. 2026-10-20 kurul: 24 şıklara göre cılız bulundu, 26/32'ye
  /// çıkarıldı ([title] 28/32 ile [headline] 22/28 arasında). Beş boyutlu ölçeğin dışında tek ek boyuttur ve yalnız
  /// soru metni içindir (bekçi: `typography_scale_test.dart`); satır
  /// bütçesini aşan soru yine [headline] 22/28'e iner.
  static const TextStyle question = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 32 / 26,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 22/28 — bölüm ve kart başlığı, açılan sayfa başlığı, sayaç.
  ///
  /// 700 (2026-09-29 doğallık, K8): 800 yalnız sekme başlığında ([title]),
  /// soru metninde ve skorda ([screen]) kalır. Her başlık 800 olunca sayfada
  /// hiyerarşi kalmıyor, her şey aynı sesle bağırıyordu. Bölüm başlığı
  /// kararda 20/700 yazıyordu; 20 beş boyutlu ölçeğin (64/28/22/16/14)
  /// dışında olduğu için boyut değil ağırlık düşürüldü: 22/700.
  static const TextStyle headline = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
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

  /// 16/24 — düğme etiketi (başlık ailesi, 700; K8 — 800 yalnız sekme
  /// başlığı, soru metni ve skorda).
  static const TextStyle button = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
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

  /// 14/20 kalın — çip, metin bağlantısı, seçim rayı, durum rozeti, joker
  /// fiyatı. Açıklama boyutunun 700 çeşidi (maketteki `--t-cap-b`); yeni
  /// bir boyut değil.
  static const TextStyle captionStrong = TextStyle(
    fontFamily: text,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 20 / 14,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 10/12 — YALNIZ alt gezinmedeki iki dilli etiketin küçük satırı
  /// (2026-10-20). Beş boyutlu ölçeğin dışında bilerek kalan tek küçük
  /// boyut: 64 + küçük satırlık gezinme çubuğuna 14'lük ikinci bir satır
  /// sığmıyor ve sekme adının kendisiyle yarışıyordu. Okunur içerik
  /// taşımaz (asıl ad 14'lük satırdadır); büyük yazı ölçeğinde gizlenir.
  static const TextStyle navHint = TextStyle(
    fontFamily: text,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 12 / 10,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 14/20 — soru sahnesinin üst satırı ("Konu · Soru n/N"), hikâye ve
  /// bölüm künyesi: başlık ailesi, 800, CÜMLE DÜZENİ, harf aralığı yok.
  ///
  /// 2026-09-29 doğallık (K8): rozet, çip ve kart üst etiketleri
  /// [captionStrong]a (cümle düzeni) geçmişti; büyük harf yalnız soru
  /// künyesinde kalmıştı. 2026-10-01 tasarım denetimi: künye de cümle
  /// düzenine geçti — "SİYASET • SORU 1/5" bağırıyordu ve harf aralığı
  /// Kurmancî uzun kategori adlarını daha erken sarıyordu. Artık hiçbir
  /// etiket büyük harfle çizilmez (bekçi: `no_caps_labels_test.dart`).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    height: 20 / 14,
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
