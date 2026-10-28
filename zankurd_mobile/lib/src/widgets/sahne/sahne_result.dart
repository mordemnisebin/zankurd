import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../../providers/reduced_motion_provider.dart';
import '../../theme/sahne.dart';
import '../rolling_count.dart';
import 'sahne_buttons.dart';
import 'sahne_cards.dart';
import 'sahne_chips.dart';
import 'sahne_foundation.dart';
import 'sahne_glyphs.dart';
import 'sahne_page.dart';
import 'sahne_painters.dart';
import 'sahne_progress.dart';

// ─── Sonuç şablonu ───────────────────────────────────────────────────────────
//
// 2026-10-01 tasarım denetimi (A6): uygulamanın bitiş ekranları — tur
// sonucu (solo, alıştırma, günün dersi, öğrenme, oda, 1v1), sırayla düello,
// seviye belirleme, tur özeti — puanı, doğru/yanlış sayımlarını, ödülü ve
// sonraki eylemi her biri kendi sırasıyla ve kendi aralıklarıyla diziyordu.
// Oyuncu aynı türden bir "bitti" anını her ekranda başka bir yerde arıyordu.
//
// Şablon TEK sıra koyar:
//
//   1. Kahraman  — amblem, sonuç başlığı, puan, bir satır bağlam
//   2. Sayımlar  — doğru / yanlış / boş / seri karoları
//   3. Ödül      — jeton, XP, seviye çubuğu; YALNIZ sıfırdan büyükse
//   4. Bölümler  — ekranın kendi içeriği (kategoriler, sıralama, rozetler…)
//   5. Alt perde — solda ikincil, sağda TEK birincil eylem
//
// Anlamsız sıfır gösterilmez: boş bir ödül kartı, "0 boş" karosu, "+0 XP"
// çipi çizilmez (bkz. [SahneResultStat.showWhenZero],
// [SahneResultRewards.hasAny]).

/// Alt perdenin ya da bölüm içi eylem satırının bir eylemi.
class SahneResultAction {
  const SahneResultAction({
    required this.label,
    required this.onPressed,
    this.key,
    this.icon,
    this.loading = false,
  });

  final String label;

  /// Eylem sürerken düğmede döner gösterge; yeni dokunuş yutulur.
  final bool loading;
  final VoidCallback onPressed;

  /// Eylemin sabit anahtarı (testler ve erişilebilirlik düğümü bunu arar).
  final Key? key;

  /// `null` → ikon yok; birincil eylemde sağda ok çizilir.
  final IconData? icon;
}

/// Sonuç sahnesinin içerik genişliği tavanı: tablet ve masaüstünde satırlar
/// ekran boyunca uzayıp okunmaz hâle gelmesin.
const double kSahneResultMaxWidth = 560;

/// Sonuç şablonunda ana bloklar (kahraman, sayımlar, ödül, ilk bölüm) arası
/// tek boşluk: yıldız/puan/alt satır grubu ile kartlar aynı ritimde durur.
/// Kahraman bloğunun kendi alt dolgusu 16 olduğundan kahraman→sayımlar
/// arasına bu değerden 16 az eklenir.
const double kSahneResultRhythmGap = 20;

/// Büyük puan ile hemen altındaki satır ("puan · %67 doğruluk") arası.
/// Tur 9b (Gemini + Grok): 64 punto rakamın alt boşluğu ile 14 punto alt satır
/// 8 ile yapışık duruyordu; 8 pt eklendi.
const double kSahneResultValueGap = SahneSpace.x4;

/// Sonucun tonu (2026-10-21): doğruluğa göre sahnenin ne kadar kutladığı.
///
/// ## Kusur
///
/// 2/10 bitiren oyuncu da gradyan, altın hale, altın puan ve ışınlı bir
/// kutlama sahnesi görüyordu; kutlama yersizdi. Rakiplerde (Duolingo, Trivia
/// Crack) düşük puanda sahne sakin ve cesaretlendiricidir.
///
/// ## Karar
///
/// [high] tam kutlama (varsayılan); [mid] ışın ve parıltı yok, yıldız var;
/// [low] hale yok, gradyan bir kademe sakin, puan nötr beyaz.
enum SahneResultMood {
  high,
  mid,
  low;

  /// Doğruluk yüzdesinden ton: ≥ %70 yüksek, %40-69 orta, < %40 düşük.
  static SahneResultMood fromAccuracy(int accuracy) => accuracy >= 70
      ? high
      : accuracy >= 40
      ? mid
      : low;
}

/// Sonuç sahnesinin rengi (2026-10-20 renk ve canlılık işi).
///
/// ## Kusur
///
/// Sonuç ekranı düz grafit bir zemindi; kazanma anı (Duolingo seri, Kahoot
/// podyum, TRT ilk üç) rakiplerde tam ekran bir sahneyken burada gri
/// kartların üstüne büyük bir altın sayıydı. Sadeleştirme turları kutlamayı
/// da söndürmüştü.
///
/// ## Karar
///
/// Zemin MODUN renginde gradyandır: yarışta Boyax → koyu, öğrenmede Zimrût →
/// koyu; gündüzde doygun, gecede bir basamak koyu. Puanın arkasında sıcak
/// altın hale ve düşük saydamlıkta ışınlar; dağ sırtı %16 siyah gölge. Altın
/// puan ve yıldızlar bu zeminde de ≥ 3:1 okunur (büyük metin).
class SahneResultScene extends InheritedWidget {
  const SahneResultScene({
    super.key,
    required this.accent,
    required this.night,
    required super.child,
    this.mood = SahneResultMood.high,
  });

  /// Sonucun tonu; [SahneResultMood.low]'da hale kalkar, gradyan sakinleşir.
  final SahneResultMood mood;

  /// [SahneRole.race] (Boyax) ya da [SahneRole.learn] (Zimrût).
  final SahneRole accent;

  /// Dış temanın gece olup olmadığı (sahne kendi içinde hep gece
  /// belirteçleriyle çizilir; gradyanın tonu dış temadan seçilir).
  final bool night;

  /// Tepeden dibe sahne renkleri (4 durak).
  List<Color> get colors {
    final full = switch ((accent, night)) {
      (SahneRole.learn, false) => SahneVivid.learnSceneDay,
      (SahneRole.learn, true) => SahneVivid.learnSceneNight,
      (_, false) => SahneVivid.raceSceneDay,
      (_, true) => SahneVivid.raceSceneNight,
    };
    if (mood != SahneResultMood.low) return full;
    // Bir kademe sakin: üst duraklar tabana doğru çekilir.
    final base = full.last;
    return [
      for (final c in full) Color.lerp(c, base, SahneVivid.calmSceneMix)!,
    ];
  }

  /// Puanın arkasındaki sıcak hale; düşük sonuçta yok.
  Color? get glow => mood == SahneResultMood.low
      ? null
      : night
      ? SahneVivid.glowNight
      : SahneVivid.glowDay;

  static SahneResultScene? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SahneResultScene>();

  @override
  bool updateShouldNotify(SahneResultScene oldWidget) =>
      accent != oldWidget.accent ||
      night != oldWidget.night ||
      mood != oldWidget.mood;
}

/// Sonuç şablonunun iskeleti — Şahnê C iskeleti (gece sahnesi) üzerinde
/// kahraman → sayımlar → ödül → bölümler sırası ve alt perde.
///
/// İçerik kısaysa (yalnız kahraman ve ödül; ör. rakibi bekleyen düello)
/// sahnede dikey ortalanır; sayımlar ya da bölümler varsa üstten dizilir ve
/// sayfa kayar.
class SahneResultScaffold extends StatelessWidget {
  const SahneResultScaffold({
    super.key,
    required this.hero,
    required this.primary,
    this.stats,
    this.rewards,
    this.sections = const [],
    this.secondary,
    this.contextLabel,
    this.closeLabel,
    this.onClose,
    this.overlay,
    this.balanced = false,
    this.neutral = false,
    this.accent = SahneRole.race,
    this.mood = SahneResultMood.high,
  });

  /// Nötr sahne (2026-10-28, jüri K7): mod renginde (Boyax/bordo) tam
  /// ekran gradyan yerine soru sahnesinin nötr zemini. Başarı vurguları
  /// altın/yeşil kalır; kırmızı yalnız yanlış sayısında. Kusur: yarış
  /// sonucu ekranın tamamını bordoya boyuyor, "kırmızı = hata" okunuyordu.
  final bool neutral;

  /// Sonucun tonu (bkz. [SahneResultMood]).
  final SahneResultMood mood;

  /// Sahnenin mod rengi: yarış Boyax (varsayılan), öğrenme Zimrût
  /// ([SahneRole.learn]). Bkz. [SahneResultScene].
  final SahneRole accent;

  /// Dikeyde dengele (tur 9b): içerik sayımlar/ödül taşısa da ekranda dikey
  /// ortalanır; ara boşluklar 16-24. Sıralı düello zaferinde skor + ödül
  /// kartlarından sonra ekranın ~%35'i boş kalıyordu (Opus + ChatGPT). Uzun
  /// içerikte sayfa yine kayar.
  final bool balanced;

  /// Kahraman ([SahneResultHero]).
  final Widget hero;

  /// Sayım karoları ([SahneResultStats]); boşsa hiçbir şey çizilmez.
  final Widget? stats;

  /// Ödül kartı ([SahneResultRewards]); `null` → çizilmez.
  final Widget? rewards;

  /// Ekranın kendi bölümleri; sırayla, kendi boşluklarıyla.
  final List<Widget> sections;

  /// Birincil eylem — ekranın TEK dolgulu düğmesi.
  final SahneResultAction primary;

  /// İkincil eylem (Paylaş, Kapat…); `null` → alt perdede yalnız birincil.
  final SahneResultAction? secondary;

  /// Üst satırın ortasındaki bağlam ("Dil • 5 soru", "Sırayla düello").
  final String? contextLabel;
  final String? closeLabel;
  final VoidCallback? onClose;

  /// Gövdenin üstüne binen katman (konfeti).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final short = stats == null && sections.isEmpty;
    final centered = short || balanced;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          SahneSpace.page,
          (constraints.maxWidth - kSahneResultMaxWidth) / 2,
        );
        final items = <Widget>[
          hero,
          // Ritim (kurul tur 6b): kahraman → sayımlar → ödül → ilk bölüm
          // arası HEP 20. Kahramanın kendi alt dolgusu 16'dır; uzun sonuçta
          // eklenen boşluk onu 20'ye tamamlar. Kısa (ortalanan) sonuçta
          // eski 12 korunur.
          if (stats != null) ...[
            SizedBox(
              height: balanced
                  ? SahneSpace.x6 - SahneSpace.x4
                  : kSahneResultRhythmGap - SahneSpace.x4,
            ),
            stats!,
          ],
          if (rewards != null) ...[
            SizedBox(
              height: balanced
                  ? SahneSpace.x4
                  : short
                  ? SahneSpace.x3
                  : stats == null
                  ? kSahneResultRhythmGap - SahneSpace.x4
                  : kSahneResultRhythmGap,
            ),
            rewards!,
          ],
          if (balanced)
            const SizedBox(height: SahneSpace.x4)
          else if (short && rewards != null)
            const SizedBox(height: SahneSpace.x6)
          else if (!short)
            const SizedBox(height: SahneSpace.x2),
          ...sections,
        ];
        final Widget scroll;
        if (centered) {
          // Kısa içerik sahnede ortada durur; %200 yazıda uzarsa sayfa
          // kayar.
          scroll = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              side,
              SahneSpace.x4,
              side,
              SahneSpace.x4 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - SahneSpace.x8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: items,
                ),
              ),
            ),
          );
        } else {
          scroll = ListView(
            // Bölümler tek bir öğrenme yüzeyidir; kısa ekranlarda da
            // erişilebilirlik ağacına birlikte girsinler. Kayıt sayısı tur
            // soru sayısıyla sınırlı olduğu için geniş önbellek güvenlidir.
            scrollCacheExtent: const ScrollCacheExtent.pixels(2500),
            // Gövde zaten alt perdenin ÜSTÜNDE biter (`SahneStageScaffold`
            // perde boyunu gövdeden düşer); listenin kendi alt boşluğu yalnız
            // 16'dır: son bölüm perdenin 16 üstünde durur (perde boyu bir daha
            // eklenmez — eskiden güvenli alanlı telefonda çifte boşluk vardı).
            padding: EdgeInsets.fromLTRB(
              side,
              SahneSpace.x2,
              side,
              SahneSpace.x4,
            ),
            children: items,
          );
        }
        // Işınlar kahramanın dışına taşar; üst satırın (kapat, bağlam)
        // üstüne boyanmasın diye gövde kırpılır.
        //
        // Kurul 4. tur (2026-10-20, 68/200): 2. turda eklenen alt solma
        // bandı kalktı. "Nerelerde zorlandın?" kartı artık özetin altında
        // olduğundan perdenin kestiği şey sıradan bir konu satırıdır; bant
        // o satırı (yanlış konu) pasif gösteriyordu. Satır sönmez; yanlış
        // durumu yalnız kırmızı ✗ karesiyle söylenir. Gövde perdenin
        // ÜSTÜNDE biter, yani liste dibi perde boyu kadar boşluk bırakır.
        final Widget scrolling = scroll;
        return ClipRect(child: Stack(children: [scrolling, ?overlay]));
      },
    );

    final night = Theme.of(context).brightness == Brightness.dark;
    final scene = SahneResultScene(
      accent: accent,
      night: night,
      mood: mood,
      child: const SizedBox.shrink(),
    );
    return SahneResultScene(
      accent: accent,
      night: night,
      mood: mood,
      child: SahneStageScaffold(
        onClose: onClose,
        closeLabel: closeLabel,
        // Sonuçta dar huzme yerine sonuç ışınları (kahramanın arkasında).
        beam: false,
        scene: neutral ? null : scene.colors,
        sceneGlow: neutral ? null : scene.glow,
        center: contextLabel == null ? null : Text(contextLabel!),
        dock: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSahneResultMaxWidth),
            child: SahneResultDock(primary: primary, secondary: secondary),
          ),
        ),
        body: body,
      ),
    );
  }
}

/// Sonucun yarış kimliği: solo/öğrenme sonucu Zêr (ödül), düello Boyax
/// (yarış). Kilim şeridinin ve kahraman vurgusunun rengini belirler.
enum SahneResultTone { reward, race }

/// Kahramanın amblemi: kazanınca Zêr taç; berabere, kaybedince ve durum
/// ekranlarında (bekleniyor, süresi doldu, yarım kaldı) nötr ikon (ikincil
/// metin). Rast/Şaş ailesi kullanılmaz: kazanmak bir "doğru cevap" değildir.
///
/// 44 yüksekliğinde bir yuvadır; her sonuç türünde amblem aynı yerde ve aynı
/// boydadır (eskiden düello 72'lik pahlı kare, tur sonucu 44'lük yıldızlar
/// çiziyordu).
class SahneResultEmblem extends StatelessWidget {
  const SahneResultEmblem.win({super.key, this.size = 44})
    : icon = null,
      _win = true;

  /// Nötr durum amblemi (berabere, kayıp, bekleme…).
  const SahneResultEmblem.state({super.key, required IconData this.icon})
    : _win = false,
      size = 44;

  final IconData? icon;
  final bool _win;

  /// Taç boyu (varsayılan 44; sıralı düello zaferinde 64).
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SizedBox(
      height: size,
      child: Center(
        child: _win
            ? SahneGlyph(SahneGlyphKind.crown, size: size)
            : ExcludeSemantics(child: Icon(icon, size: 36, color: t.tx2)),
      ),
    );
  }
}

/// Sonuç kahramanı — maketteki "5 · Sonuç" (`.sh-res`).
///
/// Kart DEĞİL: doğrudan sahnenin üstünde durur. Yukarıdan aşağı: amblem
/// (üç puan yıldızı, taç, durum karesi…) → [eyebrow] → Başlık 28 → büyük
/// puan (Ekran 64 Zêr) → [subtitle] → [caption] → [body] → [extras] →
/// (yalnız [celebrate]'te) kilim göz şeridi → [notices]. Arkada sonuç
/// ışınları (yalnız kutlanacak sonuçta) ve alçak bir dağ sırtı ufku.
class SahneResultHero extends StatelessWidget {
  const SahneResultHero({
    super.key,
    required this.emblem,
    required this.title,
    this.titleRole,
    this.titleKey,
    this.eyebrow,
    this.value,
    this.suffix = '',
    this.valueKey,
    this.subtitle,
    this.subtitleSize,
    this.caption,
    this.body,
    this.extras = const [],
    this.celebrate = false,
    this.lightGlow = false,
    this.calm = false,
    this.tone = SahneResultTone.reward,
    this.notices = const [],
  });

  /// Renkli sahnede ([SahneResultScene]) hafif ışınlar ve parıltılar, tam
  /// kutlama ([celebrate]) olmayan iyi sonuçta da açılır (solo turda iki
  /// yıldız). Işınlar düşük saydamlıktadır; kilim şeridi yine yalnız
  /// [celebrate]'te çizilir. Kaybedilen sonuçta kapalı kalır.
  final bool lightGlow;

  /// Düşük sonuçta (bkz. [SahneResultMood.low]) puan altın değil nötr yazılır.
  final bool calm;

  final Widget emblem;
  final String title;

  /// Başlığın rol rengi (kazanmada [SahneRole.gold], seviyede öğrenme/ödül);
  /// `null` → düz metin. Renk çağıranda DEĞİL burada çözülür: kahraman gece
  /// sahnesinin içindedir, çağıranın bağlamı ise gündüz temasında olabilir.
  final SahneRole? titleRole;

  /// Başlık metninin anahtarı (testler sonucu bu anahtardan okur).
  final Key? titleKey;

  /// Başlığın üstünde küçük bağlam ("Seviyen").
  final String? eyebrow;

  /// Büyük puan; sayarak çıkar ([RollingCount]). `null` → puan satırı yok.
  final int? value;
  final String suffix;
  final Key? valueKey;

  /// Puanın altında Başlık 22 satırı ("Sen 5 – 3 Rojda").
  final String? subtitle;

  /// [subtitle] punto (varsayılan Başlık 22; düello zaferinde 32).
  final double? subtitleSize;

  /// Açıklama 14 satırı ("puan • %67 doğruluk").
  final String? caption;

  /// Gövde metni (düellonun bekleme açıklaması).
  final String? body;

  /// Alt satırlara eklenecek özel parçalar (eşit doğruda süre notu).
  final List<Widget> extras;

  /// Işınlar ve kilim şeridi yalnız kutlanacak sonuçta açılır: kaybedilen
  /// ya da sıradan bir turda kutlama ışığı sonucu yanlış okutur.
  final bool celebrate;
  final SahneResultTone tone;

  /// Günlük tavan, bekleyen ödül gibi bilgi satırları.
  final List<Widget> notices;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Renkli sahnede (bkz. [SahneResultScene]) puan büyür: sonuç anı bir
    // sahnedir, tablo değil.
    final scenic = SahneResultScene.maybeOf(context) != null;
    final shine = celebrate || (scenic && lightGlow);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        const SizedBox(height: SahneSpace.x3),
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            textAlign: TextAlign.center,
            style: SahneType.captionStrong.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x1),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            key: titleKey,
            textAlign: TextAlign.center,
            // 2026-10-19 sadeleşme (ikinci tur): başlık 28 yerine 22; ekranın
            // tek büyük sesi puandır (64).
            style: SahneType.headline.copyWith(
              color: titleRole == null ? t.tx : t.roleText(titleRole!),
            ),
          ),
        ),
        if (value != null)
          // Puan sayarak çıkar: tırmanışı izlemek kazanmanın kendisidir (bkz.
          // `RollingCount`). Hareket azaltma açıkken sayım yapılmaz.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RollingCount(
              key: valueKey ?? const ValueKey('result-score-count'),
              value: value!,
              suffix: suffix,
              style: SahneType.screen.copyWith(
                color: calm ? t.tx : t.gold,
                fontSize: scenic ? 88 : null,
              ),
            ),
          ),
        if (subtitle != null) ...[
          SizedBox(
            height: value != null ? kSahneResultValueGap : SahneSpace.x2,
          ),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: SahneType.headline.copyWith(
              color: t.tx,
              fontSize: subtitleSize,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (caption != null) ...[
          SizedBox(
            height: value != null && subtitle == null
                ? kSahneResultValueGap
                : SahneSpace.x2,
          ),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: SahneType.caption.copyWith(
              color: t.heroCaptionTx,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (body != null) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: SahneType.body.copyWith(color: t.tx2),
          ),
        ],
        for (final extra in extras) ...[
          const SizedBox(height: SahneSpace.x1),
          extra,
        ],
        // Kilim göz şeridi yalnız ZAFERDE puanın altında durur; rengi rolü
        // izler: solo ödül altını, düello yarış lalı. Her sonucun altında
        // aynı süs bir kimlik değil şablon izi olurdu (2026-09-29 K4).
        if (celebrate) ...[
          const SizedBox(height: SahneSpace.x2),
          SizedBox(
            width: 160,
            child: SahneKilimStrip(
              color: (tone == SahneResultTone.race ? t.raceTx : t.gold)
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
        for (final notice in notices) ...[
          const SizedBox(height: SahneSpace.x2),
          notice,
        ],
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: SahneResultBackdropPainter(
                  rays: shine,
                  // Işınlar puan sayısının (ya da puansızsa başlığın)
                  // ortasından çıkar.
                  raysCenterY: value != null ? (scenic ? 128 : 104) : 84,
                  tinted: scenic,
                  bg: t.bg,
                  // Gece Perde açıldığı için (tur 6b) sırtın dolgusu aynı
                  // belirgin ton için zemine doğru karıştırılır; aksi hâlde
                  // kahraman bloğunun altında sert bir bant görünüyordu.
                  ridge: t.bg.computeLuminance() < 0.2
                      ? Color.lerp(t.bg, t.s1, 0.62)!
                      : t.s1,
                ),
              ),
            ),
          ),
        ),
        // R5 (2026-10-28 tur 2): puanın arkasında kontrollü altın ışıma ve
        // dört parıltı; yalnız kutlanan/iyi sonuçta. Bir kez belirir (döngü
        // yok: testler yerleşir, pil yanmaz); hareket azaltmada baştan
        // durağan.
        if (scenic && shine && !calm)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: value != null ? (scenic ? 128 : 104) - 150 : 84 - 150,
            height: 300,
            child: const _ScoreCelebration(),
          ),
        Padding(
          padding: const EdgeInsets.only(
            top: SahneSpace.x2,
            bottom: SahneSpace.x4,
          ),
          child: SizedBox(width: double.infinity, child: content),
        ),
      ],
    );
  }
}

/// Puanın arkasındaki altın ışıma + parıltılar (R5, 2026-10-28 tur 2).
///
/// Işıma radyal altın (merkez ≈ %34, kenar 0); parıltılar ışımanın içinde
/// dört noktada, kademeli belirir. Hareket azaltma açıkken ([sahneMotionReduced])
/// animasyon yoktur: son kare durağan çizilir.
class _ScoreCelebration extends StatefulWidget {
  const _ScoreCelebration();

  @override
  State<_ScoreCelebration> createState() => _ScoreCelebrationState();
}

class _ScoreCelebrationState extends State<_ScoreCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (sahneMotionReduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final glow = Curves.easeOut.transform(_c.value);
            double pop(double from) => Curves.easeOutBack.transform(
              ((_c.value - from) / (1 - from)).clamp(0.0, 1.0),
            );
            return Stack(
              key: const ValueKey('result-score-celebration'),
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 0.85 + 0.15 * glow,
                  child: Opacity(
                    opacity: glow,
                    child: SizedBox.square(
                      dimension: 280,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              t.gold.withValues(alpha: 0.34),
                              t.gold.withValues(alpha: 0.12),
                              t.gold.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final spark in const [
                  (-118.0, -34.0, 20.0, 0.30),
                  (112.0, -58.0, 24.0, 0.15),
                  (-96.0, 52.0, 14.0, 0.45),
                  (104.0, 46.0, 18.0, 0.0),
                ])
                  Transform.translate(
                    offset: Offset(spark.$1, spark.$2),
                    child: Transform.scale(
                      scale: pop(spark.$4),
                      child: _Sparkle(size: spark.$3, color: t.gold),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dört kollu küçük parıltı (dekoratif, ekran okuyucudan gizli).
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SparklePainter(color)),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final k = w * 0.1;
    final path = Path()
      ..moveTo(c.dx, 0)
      ..quadraticBezierTo(c.dx + k, c.dy - k, w, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, h)
      ..quadraticBezierTo(c.dx - k, c.dy + k, 0, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// Bir sayım karosu: simge + sayı + söz.
class SahneResultStat {
  const SahneResultStat({
    required this.leading,
    required this.value,
    required this.label,
    this.showWhenZero = false,
    this.tint,
    this.accent,
  });

  /// Renkli çip (2026-10-20 renk ve canlılık): sayımlar tek gri kart yerine
  /// her biri kendi renginde ton dolgulu çiptir — doğru yeşil, yanlış
  /// kırmızı, seri altın. [tint] çip dolgusu, [accent] etiketin rengi. İki
  /// alan da verilen sayımlar çip düzeninde çizilir; durum yine yalnız
  /// renkle değil ikon şekli ve sözle söylenir.
  final Color? tint;
  final Color? accent;

  final Widget leading;
  final int value;
  final String label;

  /// Sıfırken de çizilsin mi? Varsayılan HAYIR: "0 boş", "0 seri" bir bilgi
  /// değil gürültüdür (tur özetinde sıfır karolar bu yüzden bir kez
  /// gizlendi). Doğru/yanlış çifti turun omurgasıdır; ikisi birlikte
  /// toplamı anlatır, o yüzden çağıran onlara `true` verebilir.
  final bool showWhenZero;

  bool get visible => value > 0 || showWhenZero;
}

/// Sayımlar — TEK kompakt satır (doğru / yanlış / boş / seri).
///
/// 2026-10-19 sadeleşme (ikinci tur): sayımlar üç dört ayrı yüzey karosuydu;
/// ekran "kutu üstüne kutu" görünüyor, ödül kartı ve konu listesiyle birlikte
/// sonuç ekranı beş altı kart yığınına dönüyordu. Artık TEK yüzey kartı,
/// içinde ince ayırıcılarla eşit sütunlar: simge + sayı + söz. Durum hiçbir
/// zaman yalnız renkle verilmez: ikon şekli ve söz birlikte.
///
/// Dar ekranda ya da büyük yazıda bir sütun 96'dan darsa sütunlar aynı kartın
/// içinde ikişerli satıra iner (sayı ve söz harf harf bölünmez). Görünür
/// sayım yoksa hiçbir şey çizilmez.
class SahneResultStats extends StatelessWidget {
  const SahneResultStats({super.key, required this.stats});

  final List<SahneResultStat> stats;

  /// Çizilecek bir sayım var mı? Çağıran, boş şerit için yer ayırmasın diye
  /// önceden sorar.
  static bool hasVisible(List<SahneResultStat> stats) =>
      stats.any((stat) => stat.visible);

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final stat in stats)
        if (stat.visible) _StatTile(stat: stat),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final chips = stats.any((stat) => stat.visible && stat.tint != null);
    final grid = LayoutBuilder(
      builder: (context, constraints) {
        // 96 dar geliyordu: iPhone Air'de (≈388 pt) dört sütuna inilince
        // ikon + sayı + etiket sığmıyor, sözcük ortadan kırılıyordu
        // ("Doğr/u", "Üst/üste"; 2026-10-27, iki cihazlı düello).
        final minTile = MediaQuery.textScalerOf(context).scale(112);
        var perRow = items.length;
        // Büyük yazıda bile en az ikişerli; yalnız gerçekten dar kutuda
        // (< 240) tek sütuna inilir.
        final minCols = math.min(
          items.length,
          constraints.maxWidth >= 240 ? 2 : 1,
        );
        while (perRow > minCols && constraints.maxWidth / perRow < minTile) {
          perRow = perRow > 2 ? 2 : 1;
        }
        // Satırdaki sütunlar eşit yükseklikte (`IntrinsicHeight`):
        // "Li pey hev" iki satıra kırılınca öteki sütunlar kısa kalmasın
        // (2026-09-30 simülatör). Eksik son satır boş `SizedBox` ile aynı
        // genişliği korur.
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += perRow) {
          final chunk = items.sublist(i, math.min(i + perRow, items.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < perRow; j++) ...[
                    if (j > 0 && chips)
                      const SizedBox(width: SahneSpace.x2)
                    else if (j > 0)
                      VerticalDivider(
                        width: SahneSpace.x3 * 2 + 1,
                        thickness: 1,
                        indent: SahneSpace.x1,
                        endIndent: SahneSpace.x1,
                        color: t.line,
                      ),
                    Expanded(
                      child: j < chunk.length ? chunk[j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: SahneSpace.x2),
              rows[i],
            ],
          ],
        );
      },
    );
    if (chips) return grid;
    return SahneSurfaceCard(
      // 7. kurul (Gemini): ikon+sayı+söz kutu kenarına sıkışıktı; yatay iç
      // boşluk x4, dikey x3.
      padding: const EdgeInsets.symmetric(
        horizontal: SahneSpace.x4,
        vertical: SahneSpace.x3,
      ),
      child: grid,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final SahneResultStat stat;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    if (stat.tint != null) {
      return Semantics(
        container: true,
        label: '${stat.value} ${stat.label}',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: stat.tint, shape: SahneShape.m),
          child: ConstrainedBox(
            // a11y-tap-target: noninteractive — sayım çipi; salt görsel.
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SahneSpace.x3,
                vertical: SahneSpace.x2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(dimension: 20, child: stat.leading),
                  const SizedBox(width: SahneSpace.x2),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${stat.value}',
                          style: SahneType.headline.copyWith(
                            color: SahneVivid.onFill,
                            height: 1.1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          stat.label,
                          style: SahneType.captionStrong.copyWith(
                            color: stat.accent ?? t.tx2,
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
      );
    }
    return Semantics(
      container: true,
      label: '${stat.value} ${stat.label}',
      excludeSemantics: true,
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — sayım; salt görsel, dokunma
        // hedefi değil.
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(dimension: 20, child: stat.leading),
            const SizedBox(width: SahneSpace.x2),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stat.value}',
                    style: SahneType.bodyStrong.copyWith(
                      color: t.tx,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    stat.label,
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

/// Ödül kartı — maketteki `.sh-rew`: yüzey kartı; üstte Zêr ödül çipleri
/// (+jeton, +XP), altında isteğe bağlı seviye/ilerleme bloğu.
///
/// Yalnız bir ödül varken çizilir ([hasAny]); sıfır ödül boş bir kart ya da
/// "+0" çipi olarak gösterilmez. Ödülün sıfır olma SEBEBİ (günlük tavan,
/// kuyrukta bekleyen ödül) kahramandaki bilgi satırlarında söylenir.
class SahneResultRewards extends StatelessWidget {
  const SahneResultRewards({
    super.key,
    this.coins = 0,
    this.xp = 0,
    this.coinLabel,
    this.coinSemanticLabel,
    this.xpLabel,
    this.progress,
    this.label,
  });

  /// Ödül satırının sözü ("Kazanıldı"): çipler tek başına durunca kartta
  /// ne olduğu belli olmuyordu (kalabalık sonuçta karta yalnız "+40"
  /// düşüyordu). Verilirse söz tam genişlikte üstte, çipler altında.
  final String? label;

  final int coins;
  final int xp;

  /// Çip sözleri; verilmezse "+30" / "+100 XP".
  final String? coinLabel;
  final String? coinSemanticLabel;
  final String? xpLabel;

  /// Seviye satırı + ilerleme çubuğu bloğu; `null` → yok.
  final Widget? progress;

  /// Gösterilecek bir ödül var mı?
  static bool hasAny({int coins = 0, int xp = 0, bool progress = false}) =>
      coins > 0 || xp > 0 || progress;

  Widget _chipsRow(BuildContext context) {
    final t = SahneTokens.of(context);
    // Ödül çipleri skor SAYIMI bittikten sonra yerine oturur: ödül bir
    // SONUÇtur, sebebinden önce gösterilmez (bkz. [SahneRewardEntrance]).
    final chips = SahneRewardEntrance(
      child: Wrap(
        spacing: SahneSpace.x2,
        runSpacing: SahneSpace.x2,
        alignment: WrapAlignment.start,
        children: [
          // Dolu Zêr çipler (2026-10-20): ödül kartı altın tonlu, çipler
          // dolu altın + koyu yazı (≥ 9:1).
          if (coins > 0)
            SahneStatChip(
              tint: t.gold,
              foreground: t.onGold,
              leading: SahneGlyph(SahneGlyphKind.coin, color: t.onGold),
              label: coinLabel ?? '+$coins',
              semanticLabel: coinSemanticLabel,
            ),
          if (xp > 0)
            SahneStatChip(
              tint: t.gold,
              foreground: t.onGold,
              leading: SahneGlyph(SahneGlyphKind.bolt, color: t.onGold),
              label: xpLabel ?? '+$xp XP',
            ),
        ],
      ),
    );
    final text = label;
    if (text == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: chips);
    }
    final labelText = Text(
      text,
      style: SahneType.bodyStrong.copyWith(color: SahneVivid.rewardLabel),
    );
    // Söz HER ZAMAN tam genişlikte üst satırda, çipler altında. Yan yana
    // düzende Kurmancî "Hat qezenckirin" çiplerin artığı olan dar sütuna
    // sığmayıp iki satıra kırılıyordu (tur 6, 70_result_ku); genişlik/ölçek
    // eşiğine bağlı her düzen bir sonraki dilde yine kırılırdı.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelText,
        const SizedBox(height: SahneSpace.x2),
        Align(alignment: AlignmentDirectional.centerStart, child: chips),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = coins > 0 || xp > 0;
    if (!hasChips && progress == null) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      // Zêr "Kazanıldı" kartı (2026-10-20): altın tonlu zemin ve kenar.
      color: t.gold.withValues(alpha: 0.24),
      edgeColor: t.gold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasChips) _chipsRow(context),
          if (progress != null) ...[
            if (hasChips) const SizedBox(height: SahneSpace.x3),
            progress!,
          ],
        ],
      ),
    );
  }
}

/// Seviye satırı + Zêr ilerleme çubuğu: "Seviye 3 ........ 120 / 400 XP".
class SahneResultLevelProgress extends StatelessWidget {
  const SahneResultLevelProgress({
    super.key,
    required this.levelLabel,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.progress,
  });

  final String levelLabel;
  final int xpInLevel;
  final int xpNeeded;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: SahneSpace.x3,
          children: [
            Text(levelLabel, style: SahneType.bodyStrong.copyWith(color: t.tx)),
            Text(
              '$xpInLevel / $xpNeeded XP',
              style: SahneType.caption.copyWith(
                color: t.tx2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: SahneSpace.x2),
        SahneProgressBar(
          value: progress,
          tone: SahneProgressTone.gold,
          semanticLabel: levelLabel,
        ),
      ],
    );
  }
}

/// Ödül çiplerini skor sayımından SONRA yerine oturtur.
///
/// Gecikme ayrı bir zamanlayıcı yerine `Interval` ile verilir: `Timer` +
/// `setState` ikilisi ekran erken kapatıldığında ölü bir State'e dokunur
/// ve sonuç ekranı tam da ödüller yazılırken kapatılabiliyor.
///
/// Hareket azaltma açıkken giriş animasyonu yapılmaz; çipler doğrudan
/// yerinde çizilir. Sağlayıcı yoksa (izole widget testleri) animasyon
/// sessizce oynar — dekoratif bir davranış, ağacı eksik diye ekranı
/// çökertmemeli.
class SahneRewardEntrance extends StatelessWidget {
  const SahneRewardEntrance({super.key, required this.child});

  final Widget child;

  /// Skor sayımının tipik süresi kadar beklenir (bkz. `RollingCount`).
  static const _total = Duration(milliseconds: 1500);
  static const _start = 0.62;

  @override
  Widget build(BuildContext context) {
    final reduced =
        context.watch<ReducedMotionProvider?>()?.reduceMotion ?? false;
    if (reduced) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _total,
      curve: const Interval(_start, 1, curve: Curves.easeOutBack),
      builder: (context, value, child) => Opacity(
        // `easeOutBack` 1'i aşar; opaklık kırpılmazsa assert atar.
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: value,
          alignment: AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Alt perde — maketteki `.sh-dock--2`: solda ikincil eylem, sağda TEK
/// birincil. İkincil yoksa birincil tek başına tam genişlik. Büyük yazıda
/// alt alta iner, birincil üstte.
class SahneResultDock extends StatelessWidget {
  const SahneResultDock({super.key, required this.primary, this.secondary});

  final SahneResultAction primary;
  final SahneResultAction? secondary;

  @override
  Widget build(BuildContext context) {
    final primaryButton = _DockAction(
      key: primary.key,
      label: primary.label,
      onTap: primary.loading ? () {} : primary.onPressed,
      child: SahneButton.primary(
        label: primary.label,
        icon: primary.icon,
        arrow: primary.icon == null,
        expand: true,
        loading: primary.loading,
        onPressed: primary.onPressed,
      ),
    );
    final other = secondary;
    if (other == null) return primaryButton;
    final secondaryButton = _DockAction(
      key: other.key,
      label: other.label,
      onTap: other.onPressed,
      child: SahneButton.secondary(
        label: other.label,
        icon: other.icon,
        expand: true,
        onPressed: other.onPressed,
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(16) >= 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          primaryButton,
          const SizedBox(height: SahneSpace.x2),
          secondaryButton,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: secondaryButton),
          const SizedBox(width: SahneSpace.x3),
          Expanded(flex: 3, child: primaryButton),
        ],
      ),
    );
  }
}

/// Alt perde düğmesinin dokunma kutusu: görsel 52, dokunma ve ekran
/// okuyucu alanı en az 56 (sonuç eyleminin 54'lük tabanı,
/// `quiz_result_visual_test`). Ekran okuyucu tek bir düğme okur.
class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(child: child),
        ),
      ),
    );
  }
}
