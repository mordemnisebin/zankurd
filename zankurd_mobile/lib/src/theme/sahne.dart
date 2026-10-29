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
    required this.learnFill,
    required this.raceFill,
    required this.raceDeep,
    required this.nil,
    required this.nilTx,
    required this.nilTint,
    required this.nilFill,
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

  /// BEYAZ tonal düğmenin (Nîl kartı üstünde) etiketi: gündüz [nilTx], gece
  /// koyu [nilFill]. Gece [nilTx] açık maviydi (#9DB0FF) ve beyaz dolguda
  /// okunmuyordu (2026-10-20, arkadaşlar "Paylaş"); açık-zemin düğme etiketi
  /// temadan bağımsız KOYU olmalı.
  Color get nilOnWhite => _isDay ? nilTx : nilFill;

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
  Color get heroCaptionTx => Color.lerp(tx2, tx, 0.6)!;

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
  ///
  /// G1 (2026-10-29): gece sahnesi artık lacivert-mor degrade; şık dolgusu
  /// zeminden açık bir çivit ([SahneStageColors] gece dağları üstünde
  /// yarı saydam beyaz gibi okunur, opak tutulur: kontrast ölçülebilsin).
  Color get optionFill => _isDay ? s2 : const Color(0xFF3A3378);

  /// Sönük (açıklanınca seçilmeyen) şık dolgusu: gecede gri Perde yerine
  /// sahneden koyu çivit (G1, 2026-10-29); gündüz Perde.
  Color get optionDimFill => _isDay ? s1 : const Color(0xFF1C1650);

  /// Joker düğmesi dolgusu: gece sahnesinde gri Kulis yerine mor sahneyle
  /// uyumlu çivit (G1, 2026-10-29); gündüz Kulis. Metin ≥ 7:1.
  Color get stageChip => _isDay ? s2 : const Color(0xFF2C2566);

  /// Şık çubuğunun 1 px kenarı: gece zeminden ve dolgudan ayrılan ince çizgi
  /// (`#4C4F57`), gündüz `edge`.
  Color get optionEdge => _isDay ? edge : const Color(0xFF8A82CF);

  /// Zêr (ödül) bandı: mağaza üst bandı ve vip rozeti karosu (2026-10-20 D
  /// aşaması, 4 model: mağaza sönüktü, Zêr yalnız küçük jeton glifindeydi).
  /// Gündüz doygun altın, gece bir basamak koyu kehribar; üstünde KOYU yazı
  /// ([onZer], ≥ 9:1) çünkü altın üstünde beyaz okunmaz.
  Color get zerBand =>
      _isDay ? const Color(0xFFF5C24C) : const Color(0xFFE2AB35);

  /// [zerBand] üstündeki yazı ve ikon: koyu kahve.
  Color get onZer => onGold;

  /// Zêr bandındaki bakiye çipinin dolgusu: koyu kahve, içinde altın jeton ve
  /// açık yazı belirgin durur.
  Color get zerChip => const Color(0xFF2A1D00);

  /// Konu tonlu şık dolgusu (2026-10-20 D aşaması, 3 model: şıklar düz gri,
  /// sahne konunun rengini taşırken kartlar renksizdi): [optionFill]den
  /// konunun dolu rengine doğru ölçülü (%15) kayar; metin kontrastı bekçide
  /// ölçülür (≥ 4,5). Harf karosu renksiz KALIR (bkz. QuizOptionTile).
  Color optionFillFor(SahneCategoryTone tone) =>
      Color.lerp(optionFill, tone.fill(night: !_isDay), 0.15)!;

  /// Konu tonlu şık kenarı: konu rengi düşük alfa, [optionFillFor] üstünde
  /// opak karışım.
  Color optionEdgeFor(SahneCategoryTone tone) => Color.alphaBlend(
    tone.fill(night: !_isDay).withValues(alpha: 0.55),
    optionEdge,
  );

  /// Şık harf karosu: gecede dolgu Ray olduğu için karo bir ton koyu (`s1`).
  Color get optionLetterFill => _isDay ? s3 : const Color(0xFF241D55);

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

  /// MOD RENKLERİ — dolu yüzey (2026-10-20 renk ve canlılık işi).
  ///
  /// Sadeleştirme turları rengi tek turuncuya indirmişti; kimlik renkleri
  /// ([learn], [race]) yalnız 40 px'lik ikon kutusunda yaşıyordu. Artık her
  /// modun büyük bir yüzeyi vardır: öğrenme Zimrût ([learnFill]), yarış Boyax
  /// ([raceFill] → [raceDeep] gradyanı), sosyal (arkadaş, oda, kodla katıl)
  /// Nîl ([nilFill]). Gündüzde dolgu, ikon/metin rengi olan [learn]/[race]
  /// ile aynıdır; gecede dolgu bir basamak koyudur (üstündeki beyaz yazı
  /// ≥ 4.5:1), ikon rengi parlak kalır. Agir yalnız birincil eylem, Zêr
  /// yalnız ödüldür.
  final Color learnFill;
  final Color raceFill;

  /// Boyax kahraman gradyanının koyu ucu.
  final Color raceDeep;

  /// Nîl — sosyal mod (arkadaş, oda, turnuva): ikon/aksan, metin, ton zemini
  /// ve dolu yüzey.
  final Color nil;
  final Color nilTx;
  final Color nilTint;
  final Color nilFill;

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

  /// TEK seçili stili. GÜNCEL HÂL (2026-10-28, K15) aşağıdaki [selFill]
  /// belgesindedir; altındaki tarihçe turuncu dönemi anlatır.
  /// (kurul incelemesi 2026-10-19): seçili çip, segment ve
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
  Color get warmFill =>
      _isNight ? const Color(0xFF4A321F) : const Color(0xFFFFE1CC);
  Color get warmTx => _isNight ? const Color(0xFFFFB27F) : actTx;

  /// 2026-10-28 kurul K15: seçili segment/sekme/çip artık turuncu ton değil,
  /// KOYU MÜREKKEP dolgu + açık metindir (gündüz `tx` dolgu + beyaz metin;
  /// gece açık mürekkep dolgu + koyu metin — ters çevrilmiş nötr, ≥ 12:1).
  /// Turuncu yalnız birincil düğmededir; seçili çip onunla yarışmıyordu
  /// ama ekranda üç dört turuncu öğe birikiyordu. Eski turuncu ton
  /// [warmFill]/[warmTx] olarak kalır (seri çipi gibi seçim OLMAYAN sıcak
  /// vurgular için).
  Color get selFill => tx;
  Color get selLine => selFill;
  Color get selTx => _isNight ? bg : const Color(0xFFFFFFFF);

  /// Kilim imzası (2026-10-20 kimlik işi): kökboya kırmızısı ile turuncu
  /// arası; yalnız Yarış'ın kahraman kartının alt kenarındaki ince kilim
  /// şeridinde. Gündüz düz, gece düşük opaklık (gece zeminde parlamasın,
  /// metinle yarışmasın). Rol rengi değil, imzadır: düğme/durum için değil.
  Color get kilimTx =>
      _isNight ? const Color(0x8CD86B4A) : const Color(0xFFB4452F);

  /// Günün dersi kartının kenarı ve ilerleme izi (Zimrût ton ailesi;
  /// 2026-10-20 renk ve canlılık işi).
  Color get learnEdge =>
      _isNight ? const Color(0xFF24453A) : const Color(0xFFC4E9DA);
  Color get learnTrack =>
      _isNight ? const Color(0xFF24453A) : const Color(0xFFCFEBDF);

  /// "Bu hafta" sıra bloğu: Zêr tonlu gradyan ve kenarı.
  Color get goldBlockFrom =>
      _isNight ? const Color(0xFF3D321A) : const Color(0xFFFFF6DD);
  Color get goldBlockTo =>
      _isNight ? const Color(0xFF2A2416) : const Color(0xFFFBE7AE);
  Color get goldBlockEdge =>
      _isNight ? const Color(0xFF5A4A22) : const Color(0xFFF1D68A);

  /// Zimrût ve Nîl kahraman/bant gradyanlarının koyu ucu (Boyax'ın
  /// [raceDeep]'i gibi; 2026-10-20 renk ve canlılık, B aşaması). Beyaz yazı
  /// dolgudan da koyu uçta ≥ 4,5:1'dir.
  Color get learnDeep =>
      _isNight ? const Color(0xFF123A2D) : const Color(0xFF0A5C44);
  Color get nilDeep =>
      _isNight ? const Color(0xFF1B2660) : const Color(0xFF283C9C);

  /// Sıralama madalya renkleri (Zêr ilk üç, 2026-10-20 B aşaması): kaide
  /// ton zemini ve üst şerit. 0 altın, 1 gümüş, 2 bronz.
  Color medalTint(int place) => switch (place) {
    0 => goldTint,
    1 => _isNight ? const Color(0xFF2C3038) : const Color(0xFFE7EBF3),
    // W9 (2026-10-28 tur 5): bakır tonu; turuncuya (eylem rengi) kaymaz.
    _ => _isNight ? const Color(0xFF332B25) : const Color(0xFFF1E6DC),
  };
  Color medalBar(int place) => switch (place) {
    0 => gold,
    1 => _isNight ? const Color(0xFFAAB3C6) : const Color(0xFF9AA5BC),
    _ => const Color(0xFFA9713F),
  };

  /// Gündüz kartının çok hafif gölgesi (mürekkep %8, 6 pt, 2 aşağı).
  BoxShadow get cardShadow => const BoxShadow(
    color: Color(0x141A2250),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  bool get _isNight => bg.computeLuminance() < 0.2;

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
    tx2: Color(0xFFD0D2D8),
    // 2026-10-20 D aşaması (3 model): gece tx3 sonuç ve sıralama alt
    // yazılarında hâlâ sönüktü: #A2A5AD → #B6B9C1, tx2 #C4C6CD → #D0D2D8.
    tx3: Color(0xFFB6B9C1),
    // Ayırıcı ve yüzey kenarı DEKORATİF (opak, saydam değil): etkileşimli
    // kenar için tx3 kullanılır (≥ 3:1).
    // D aşaması: gece liste ayırıcısı bir ton belirgin (sıralama 4-7).
    line: Color(0xFF474A52),
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
    raceTint: Color(0xFF35202A),
    learn: Color(0xFF34C795),
    learnTx: Color(0xFF52DBA5),
    learnTint: Color(0xFF1B2E27),
    learnBar: Color(0xFF34C795),
    learnFill: Color(0xFF1F7A5C),
    raceFill: Color(0xFF8E2A45),
    raceDeep: Color(0xFF43202F),
    nil: Color(0xFF7F95F0),
    nilTx: Color(0xFF9DB0FF),
    nilTint: Color(0xFF1F2442),
    nilFill: Color(0xFF2E3F8F),
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
    race: Color(0xFFC2304F),
    raceTx: Color(0xFFA51F42),
    raceTint: Color(0xFFFBE6EB),
    learn: Color(0xFF0E8360),
    learnTx: Color(0xFF08704F),
    learnTint: Color(0xFFE3F5EE),
    learnBar: Color(0xFF0E8360),
    learnFill: Color(0xFF0E8360),
    raceFill: Color(0xFFC2304F),
    raceDeep: Color(0xFF8E2A45),
    nil: Color(0xFF3E5BD6),
    nilTx: Color(0xFF2F47B5),
    nilTint: Color(0xFFE7ECFC),
    nilFill: Color(0xFF3E5BD6),
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
      learnFill: l(learnFill, other.learnFill),
      raceFill: l(raceFill, other.raceFill),
      raceDeep: l(raceDeep, other.raceDeep),
      nil: l(nil, other.nil),
      nilTx: l(nilTx, other.nilTx),
      nilTint: l(nilTint, other.nilTint),
      nilFill: l(nilFill, other.nilFill),
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

  /// Oyun sahnesinin "gece dağları" zemini (2026-10-29 canlılık katmanı G1).
  ///
  /// Kusur: soru/sonuç/çark sahnesi düz neredeyse-siyah (#121214) idi;
  /// rakipler (QuizPlanet, TRT, Trivia Crack) oyun sahnesini zengin bir gece
  /// gökyüzüne boyuyor, bizimki "soluk ve düz" okunuyordu. Zemin artık
  /// lacivert → çivit → mor dikey degrade + soluk yıldızlar + alçak dağ
  /// siluetidir. İki temada da aynıdır (oyun sahnesi hep gecedir). Metin
  /// kontrastı: Gece birincil metin (#F5F3EF) en açık durakta bile ≥ 10:1.
  static const nightTop = Color(0xFF0E1433);
  static const nightMid = Color(0xFF241A4F);
  static const nightLow = Color(0xFF3A1F5C);

  /// Dağ siluetleri: uzak (açık mor, yarı saydam), yakın ve zemin (koyu
  /// çivit). Alt perde ([nightGround]) ile aynı renk: siluet perdeye akar.
  static const nightRidgeFar = Color(0xFF5A3A8C);
  static const nightRidgeNear = Color(0xFF1B1245);
  static const nightGround = Color(0xFF1B1245);

  /// Dağların ardındaki hafif sıcak ışıma (uç, saydam).
  static const nightGlow = Color(0x2EF08A4A);
  static const nightGlowEnd = Color(0x00F08A4A);

  /// Soluk yıldız rengi.
  static const nightStar = Color(0xFFFFF4E0);

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
    this.dayFill,
    this.nightFill,
  });

  final Color ground;
  final Color deep;
  final Color detail;

  /// Konu karosunun DOLU zemini (2026-10-20 renk ve canlılık işi). Sadeleştirme
  /// turları konu rengini 28 px'lik koyu kısık bir ikon kutusuna indirmişti;
  /// on bir karo yan yana gri-kahve bir leke gibi okunuyordu. Artık karonun
  /// TAMAMI konunun rengidir: gündüz doygun [dayFill], gece bir basamak koyu
  /// [nightFill]; üstünde beyaz ikon ve beyaz yazı (≥ 4.5:1, bekçi ölçer).
  /// Verilmezse [ground]a düşer.
  ///
  /// Maketin (`build/renk/gen.mjs`) üç gündüz dolgusu (Dil #0B7F8E,
  /// Coğrafya #21824A, Dünya #0D7F72) bir basamak koyulaştırıldı: Kurmancî
  /// ikinci satır beyaz %92 + 14 pt olduğundan 4.26–4.41:1 kalıyordu (< 4.5).
  final Color? dayFill;
  final Color? nightFill;

  /// Gece dolguları (kurul 2026-10-20, iki model): ilk sürümde gündüze göre
  /// sönük (koyu kahve-gri) duruyordu; artık gündüz dolgusunun doygun,
  /// hafifçe koyu ikizidir (beyaz yazı yine ≥ 4,5:1; Kurmancî %92 satırı
  /// dahil). Parlaklık beyaz yazının kontrastıyla sınırlıdır.
  ///
  /// Karonun dolu zemini: gece [nightFill], gündüz [dayFill].
  Color fill({required bool night}) => (night ? nightFill : dayFill) ?? ground;

  static const ziman = SahneCategoryTone(
    ground: Color(0xFF254D51),
    deep: Color(0xFF1E4042),
    detail: SahneCategoryLight.ziman,
    dayFill: Color(0xFF0A7785),
    nightFill: Color(0xFF037887),
  );
  static const cand = SahneCategoryTone(
    ground: Color(0xFF583028),
    deep: Color(0xFF42251E),
    detail: SahneCategoryLight.cand,
    dayFill: Color(0xFFC24130),
    nightFill: Color(0xFFC63926),
  );
  static const dirok = SahneCategoryTone(
    ground: Color(0xFF584428),
    deep: Color(0xFF42331E),
    detail: SahneCategoryLight.dirok,
    dayFill: Color(0xFF98650F),
    nightFill: Color(0xFF976106),
  );
  static const edebiyat = SahneCategoryTone(
    ground: Color(0xFF582836),
    deep: Color(0xFF421E29),
    detail: SahneCategoryLight.edebiyat,
    dayFill: Color(0xFFC23A6E),
    nightFill: Color(0xFFC53169),
  );
  static const cografya = SahneCategoryTone(
    ground: Color(0xFF275037),
    deep: Color(0xFF20412D),
    detail: SahneCategoryLight.cografya,
    dayFill: Color(0xFF207D47),
    nightFill: Color(0xFF197D43),
  );
  static const muzik = SahneCategoryTone(
    ground: Color(0xFF633B20),
    deep: Color(0xFF4A2C18),
    detail: SahneCategoryLight.muzik,
    dayFill: Color(0xFF9B3FB8),
    nightFill: Color(0xFF9335B0),
  );
  static const sinema = SahneCategoryTone(
    ground: Color(0xFF362858),
    deep: Color(0xFF291E42),
    detail: SahneCategoryLight.sinema,
    dayFill: Color(0xFF6448D1),
    nightFill: Color(0xFF5432D5),
  );
  static const teknoloji = SahneCategoryTone(
    ground: Color(0xFF283A58),
    deep: Color(0xFF1E2D42),
    detail: Color(0xFF5F91E0),
    dayFill: Color(0xFF1F70BD),
    nightFill: Color(0xFF156EC3),
  );
  // Cîhan: deniz petrolü. Teknolojî'nin lacivertiyle (0xFF22395E) Ziman'ın
  // yeşilimsi turkuazı (0xFF22595E) arasındaki boşluk; zemin gece birincil
  // metni üstünde ≥ 4,5:1 (bekçi: category_color_identity_test).
  static const cihan = SahneCategoryTone(
    ground: Color(0xFF274A63),
    deep: Color(0xFF1D394E),
    detail: Color(0xFF69BADD),
    dayFill: Color(0xFF0D7B6F),
    nightFill: Color(0xFF067B6E),
  );
  static const paradigma = SahneCategoryTone(
    ground: Color(0xFF502858),
    deep: Color(0xFF3D1E42),
    detail: Color(0xFFCA89D6),
    dayFill: Color(0xFF537A0E),
    nightFill: Color(0xFF507907),
  );
  // Zemin 0xFF575528 idi: alt konu bandındaki gece alt satırı (`tx2`) 4,41:1
  // kalıyordu (< 4,5). Kimliği bozmayan bir basamak koyulaştırıldı (4,61:1);
  // bekçi yalnız yedi konuyu ölçtüğü için kusur bu üçüne bakılmadan
  // sessiz kalmıştı (`sahne_topic_marks_test`, artık 11 işaretin hepsi).
  static const siyaset = SahneCategoryTone(
    ground: Color(0xFF4B492B),
    deep: Color(0xFF3E3C22),
    detail: Color(0xFFADA855),
    dayFill: Color(0xFF36559E),
    nightFill: Color(0xFF2D4C95),
  );

  /// Tabloda olmayan kategori: sahne kartının gece tonu, ayrıntı üçüncül
  /// metin.
  static const fallback = SahneCategoryTone(
    ground: SahneStageColors.top,
    deep: SahneStageColors.bottom,
    detail: Color(0xFF8F9199),
  );

  /// "Karışık" (Tevlihev) karosunun tonu: konu değil, hepsinin karışımı.
  ///
  /// Y8 (2026-10-29 tur 6): karanlıkta sahne gecesine (fallback) düşüyor ve
  /// zeminden ayrışmıyordu; öteki on karo renkli, bu devre dışı gibi duruyordu
  /// (jüri: Opus). Nötr gümüş-arduvaz: gündüz koyu arduvaz, gece açık gümüş;
  /// beyaz ikon/yazı ≥ 4,5:1 (4,78 ve 6,13). [byCategory]ye GİRMEZ: konu
  /// tablosu yalnız on bir gerçek konudur.
  static const mixed = SahneCategoryTone(
    ground: SahneStageColors.top,
    deep: SahneStageColors.bottom,
    detail: Color(0xFF8F9199),
    dayFill: Color(0xFF5B6270),
    nightFill: Color(0xFF6A7383),
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
      byCategory[canonicalCategory] ??
      (canonicalCategory == 'Tevlihev' ? mixed : fallback);

  @override
  bool operator ==(Object other) =>
      other is SahneCategoryTone &&
      other.ground == ground &&
      other.deep == deep &&
      other.detail == detail &&
      other.dayFill == dayFill &&
      other.nightFill == nightFill;

  @override
  int get hashCode => Object.hash(ground, deep, detail, dayFill, nightFill);
}

/// Renkli yüzeylerin üstündeki sabit renkler (2026-10-20 renk ve canlılık
/// işi): dolu konu karosu, Boyax kahraman, renkli sonuç sahnesi. Bu
/// yüzeyler iki temada da renkli olduğundan üstündeki beyaz yazı, cam
/// çipler ve ışıklar temaya göre DEĞİŞMEZ; ham renk ekrana ya da bileşene
/// yazılmaz (`sahne_design_guard_test`), buradan okunur.
class SahneVivid {
  const SahneVivid._();

  /// Doygun mod kartı degradesinin koyu ucuna karışan siyah.
  static const shade = Color(0xFF000000);

  /// Dolu yüzey üstünde ad/ikon: beyaz; ikinci satır beyazın %92'si; filigran
  /// beyazın %12'si.
  static const onFill = Color(0xFFFFFFFF);
  static const onFillSoft = Color(0xEBFFFFFF);
  static const watermark = Color(0x1FFFFFFF);

  /// Gece mod kartında filigran (%18) ve ince açık kenar (%14): koyu
  /// dolguda %12 filigran ve kenarsız kart kayboluyordu (son kurul,
  /// 2026-10-22).
  static const watermarkNight = Color(0x2EFFFFFF);
  static const tileEdgeNight = Color(0x24FFFFFF);

  /// Renkli yüzeyde cam çip dolgusu, iz ve ince çizgi (beyaz %16 / %18 / %12).
  static const glass = Color(0x29FFFFFF);

  /// Zimrût ders kartındaki küçük beyaz yazılı rozetler: koyu cam,
  /// açık/gece dolgu üstünde 4,5:1 üzeri kontrast için.
  static const learnBadgeGlass = Color(0x33000000);

  /// Cam düğme (davet kodu gir): kart zemininden ayrışan yarı saydam beyaz
  /// dolgu (%22) ve ince beyaz kenar (%70); beyaz yazı Nîl kartta ≥ 4,5:1.
  static const glassButton = Color(0x1AFFFFFF);
  static const glassButtonEdge = Color(0xB3FFFFFF);
  static const glassTrack = Color(0x2EFFFFFF);
  static const hairline = Color(0x1FFFFFFF);

  /// Boyax kahraman: üst etiket, baklava motifi, kilim şeridi.
  static const heroEyebrow = Color(0xFFFFE3EA);
  static const heroMotif = Color(0x17FFFFFF);
  static const heroKilim = Color(0x52FFFFFF);

  /// "SK vs ?" göstergesi: şeftali oyuncu dairesi ve kesik çizgili boş rakip.
  static const vsAvatar = Color(0xFFFFE1CC);
  static const vsAvatarTx = Color(0xFF9E3F00);
  static const vsDash = Color(0x99FFFFFF);

  /// Sonuç sahnesi: parıltılar, ışınlar, dağ gölgesi, ödül etiketi.
  static const sparkGold = Color(0xFFF5C24C);
  static const sparkLight = Color(0xFFFFE7A8);
  static const sceneRay = Color(0x14FFE2A8);
  static const sceneRidge = Color(0x2E000000);
  static const rewardLabel = Color(0xFFFFE7A8);
  static const starEmpty = Color(0x29FFFFFF);

  /// Sonuç sahnesinin gradyanı (4 durak) ve puan arkasındaki hale: yarışta
  /// Boyax, öğrenmede Zimrût; gündüz doygun, gece bir basamak koyu.
  static const raceSceneDay = [
    Color(0xFFB8294A),
    Color(0xFF8E2342),
    Color(0xFF4E1A2C),
    Color(0xFF24141B),
  ];
  static const raceSceneNight = [
    Color(0xFF6B2A45),
    Color(0xFF4A2030),
    Color(0xFF24161C),
    Color(0xFF16171B),
  ];
  static const learnSceneDay = [
    Color(0xFF0E8360),
    Color(0xFF0B6B4E),
    Color(0xFF0A3F31),
    Color(0xFF0F1D19),
  ];
  static const learnSceneNight = [
    Color(0xFF1B5C46),
    Color(0xFF14412F),
    Color(0xFF12261E),
    Color(0xFF16171B),
  ];

  /// Düşük sonuçta gradyanın tabana doğru çekilme payı (bir kademe sakin).
  static const calmSceneMix = 0.38;
  static const glowDay = Color(0x6BF5C24C);
  static const glowNight = Color(0x42F5C24C);

  /// Sonuç sayım çipleri (ton dolgu + etiket): doğru, yanlış, boş, seri.
  static const chipOkTint = Color(0x4034C795);
  static const chipOkTx = Color(0xFF52DBA5);
  static const chipErrTint = Color(0x40FF7466);
  static const chipErrTx = Color(0xFFFF8A7D);
  static const chipBlankTint = Color(0x33FFFFFF);
  static const chipBlankTx = Color(0xFFE3E4E8);
  static const chipGoldTint = Color(0x40F5C24C);
  static const chipGoldTx = Color(0xFFF5C24C);

  /// Renkli sahnede konu listesi kartı.
  static const sheet = Color(0x14FFFFFF);
  static const sheetEdge = Color(0x1FFFFFFF);

  /// [sheet]'in OPAK eşi: gece sahnesinin orta durağı
  /// ([SahneStageColors.nightMid]) üstünde beyaz %8 — cam kartla aynı ton,
  /// ama arkasındaki dağ silueti geçmez. Uzun metin taşıyan kartlar içindir
  /// (yanlış cevap açıklaması; 2026-10-29 son kurul tur 3, üç model: dağ
  /// açıklama yazısının arkasından görünüyordu).
  static const sheetSolid = Color(0xFF352C5D);
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

/// Manzara şeridinin saat dilimi (2026-10-21). Şerit TEMAYA değil cihazın
/// yerel saatine bakar: sabah şafak, gündüz mavi gök, akşam gün batımı,
/// gece yıldızlı gök. Kartın zemini ve metni temayı izlemeye devam eder.
enum SahneVistaPhase {
  dawn,
  day,
  dusk,
  night;

  /// 05:00–09:59 şafak, 10:00–16:59 gündüz, 17:00–19:59 akşam, kalanı gece.
  static SahneVistaPhase atHour(int hour) {
    if (hour >= 5 && hour < 10) return dawn;
    if (hour >= 10 && hour < 17) return day;
    if (hour >= 17 && hour < 20) return dusk;
    return night;
  }

  static SahneVistaPhase now() => atHour(SahneClock.now().hour);
}

/// Test edilebilir saat: testler `SahneClock.now = () => DateTime(...)` ile
/// sabitler (ekran turu öğlen 12:00 / gece kareleri 22:00).
class SahneClock {
  SahneClock._();
  static DateTime Function() now = DateTime.now;
}

/// Bir manzara döneminin renkleri ve güneş yerleşimi. Ham renk yalnız burada.
class SahneVistaPalette {
  const SahneVistaPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.ridgeFar,
    required this.ridgeMid,
    required this.ridgeNear,
    required this.star,
    required this.stars,
    required this.sunX,
    required this.sunY,
    required this.sunR,
  });

  final Color skyTop;
  final Color skyBottom;

  /// Güneş; gecede zirvedeki tek turuncu ışık.
  final Color sun;
  final Color ridgeFar;
  final Color ridgeMid;
  final Color ridgeNear;
  final Color star;

  /// Yıldız çizilir mi (yalnız gece; gecede güneş yerine zirve ışığı çizilir).
  final bool stars;

  /// Güneşin merkezi (şerit boyutuna oranla) ve yarıçapı (yüksekliğe oranla).
  final double sunX;
  final double sunY;
  final double sunR;

  static const _star = Color(0xFFF5F3EF);

  static const dawn = SahneVistaPalette(
    skyTop: Color(0xFFFFA24D),
    skyBottom: Color(0xFFFFD7A3),
    sun: Color(0xFFFF8A3D),
    ridgeFar: Color(0xFF63D2A2),
    ridgeMid: Color(0xFF1B9E68),
    ridgeNear: Color(0xFF067A57),
    star: _star,
    stars: false,
    sunX: 0.68,
    sunY: 0.50,
    sunR: 0.15,
  );
  static const day = SahneVistaPalette(
    skyTop: Color(0xFF2E8CF0),
    skyBottom: Color(0xFFA6DAFB),
    sun: Color(0xFFFFD23F),
    ridgeFar: Color(0xFF63D2A2),
    ridgeMid: Color(0xFF1B9E68),
    ridgeNear: Color(0xFF067A57),
    star: _star,
    stars: false,
    sunX: 0.70,
    sunY: 0.20,
    sunR: 0.15,
  );
  static const dusk = SahneVistaPalette(
    skyTop: Color(0xFF6B2BA0),
    skyBottom: Color(0xFFF5744F),
    sun: Color(0xFFE8391F),
    ridgeFar: Color(0xFF5B8F86),
    ridgeMid: Color(0xFF1D7254),
    ridgeNear: Color(0xFF0A5A44),
    star: _star,
    stars: false,
    sunX: 0.66,
    sunY: 0.52,
    sunR: 0.25,
  );
  static const night = SahneVistaPalette(
    skyTop: Color(0xFF1B2160),
    skyBottom: Color(0xFF3B4FB8),
    sun: Color(0xFFFF8A3D),
    ridgeFar: Color(0xFF33438F),
    ridgeMid: Color(0xFF24336E),
    ridgeNear: Color(0xFF1B2752),
    star: _star,
    stars: true,
    sunX: 0.5,
    sunY: 0.25,
    sunR: 0.1,
  );

  static SahneVistaPalette of(SahneVistaPhase phase) => switch (phase) {
    SahneVistaPhase.dawn => dawn,
    SahneVistaPhase.day => day,
    SahneVistaPhase.dusk => dusk,
    SahneVistaPhase.night => night,
  };
}

/// "Vay" katmanının sabit renkleri (VAY_KATMANI A1–A3, B5; 2026-10-29).
///
/// Tema belirteci değil, tema DIŞI ham renktir (ışık beyazı, gölge siyahı,
/// madalya altını): hepsi burada durur ki bileşen kütüphanesi
/// (`widgets/sahne/`) ham renk taşımasın (`sahne_design_guard_test`).
class SahneVayColors {
  const SahneVayColors._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Birincil düğmenin 4 px koyu tabanı (#B94D13).
  static const Color buttonBase = Color(0xFFB94D13);

  /// Düğme üst kenarındaki 1 px ışık (beyaz %40).
  static const Color buttonTopLight = Color(0x66FFFFFF);

  /// Kabartma kartın dış gölgesi (siyah %14).
  static const Color cardShadow = Color(0x24000000);

  /// Kilim kenar şeridi: açık yüzeyde #245C69 %7, koyu sahnede beyaz %9.
  static const Color kilimOnLight = Color(0x12245C69);
  static const Color kilimOnDark = Color(0x17FFFFFF);

  /// Madalya: #FFE6A0 → #D7A744, kenar, kazanılmış yıldız.
  static const Color medalTop = Color(0xFFFFE6A0);
  static const Color medalBottom = Color(0xFFD7A744);
  static const Color medalRim = Color(0xFFB98A2E);
  static const Color medalStar = Color(0xFF8A5A00);

  /// Işın diski (altın, merkezde ≈ %18).
  // Son kurul tur 3 (2026-10-29): %18 → %14; bkz. SahneMedalScene.discSize.
  static const Color rayCenter = Color(0x24FFC94A);
  static const Color rayEdge = Color(0x00FFC94A);

  // ── Vay 2A (2026-10-29) ──────────────────────────────────────────────

  /// Kabartmalı kartın gece dış gölgesi (siyah %32): gündüzde gölge kartın
  /// KENDİ renginden türer (gri plaka yerine renkli ışıma), gecede koyu
  /// zeminde renkli gölge çamur gibi duruyordu.
  static const Color cardShadowNight = Color(0x52000000);

  /// Doygun kartın altındaki dağ siluetinin rengi (siyah %14): kart bir oyun
  /// dünyasının parçası gibi okunur; beyaz yazı bu katmanın üstünde değil.
  static const Color tileRidge = Color(0x24000000);

  /// Günün çarkı dilimleri (Astra, 2026-10-29): siyah dilim YOK; marka
  /// paleti — altın, nane, gül, leylak. Rakam rengi hepsinde [wheelInk]
  /// (≥ 4,5:1, `vay_2a_test` ölçer).
  static const Color wheelGold = Color(0xFFFFC857);
  static const Color wheelMint = Color(0xFF37CBA0);
  static const Color wheelRose = Color(0xFFF36A9D);
  static const Color wheelLilac = Color(0xFFA69AF7);
  static const Color wheelInk = Color(0xFF17152D);

  /// Çark kasnağı: koyu mor gövde + altın ince çerçeve.
  static const Color wheelRim = Color(0xFF2A1F5C);
  static const Color wheelRimEdge = Color(0xFFE2B54A);

  /// Çark göbeği: maskotun durduğu krem disk.
  static const Color wheelHub = Color(0xFFFFF4DD);

  /// Yanlış şık ve yanlış geri bildirim şeridi: tuğla kırmızısı (#6B1F1A)
  /// gece-mor sahnede ağır duruyordu; şarap tonu daha sakin, metin
  /// (#F5F3EF) üstünde ≥ 7:1.
  static const Color optionWrongFill = Color(0xFF6E2438);
  static const Color feedbackWrongFill = Color(0xFF4F1D33);

  /// VS rozeti: altın disk (madalya altını) üstünde koyu yazı.
  static const Color vsInk = Color(0xFF2A1A00);
}
