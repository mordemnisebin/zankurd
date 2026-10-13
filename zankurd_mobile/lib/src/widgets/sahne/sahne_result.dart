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
  });

  final String label;
  final VoidCallback onPressed;

  /// Eylemin sabit anahtarı (testler ve erişilebilirlik düğümü bunu arar).
  final Key? key;

  /// `null` → ikon yok; birincil eylemde sağda ok çizilir.
  final IconData? icon;
}

/// Sonuç sahnesinin içerik genişliği tavanı: tablet ve masaüstünde satırlar
/// ekran boyunca uzayıp okunmaz hâle gelmesin.
const double kSahneResultMaxWidth = 560;

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
  });

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
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          SahneSpace.page,
          (constraints.maxWidth - kSahneResultMaxWidth) / 2,
        );
        final items = <Widget>[
          hero,
          if (stats != null) ...[const SizedBox(height: SahneSpace.x3), stats!],
          if (rewards != null) ...[
            const SizedBox(height: SahneSpace.x3),
            rewards!,
          ],
          if (short && rewards != null)
            const SizedBox(height: SahneSpace.x6)
          else if (!short)
            const SizedBox(height: SahneSpace.x2),
          ...sections,
        ];
        final Widget scroll;
        if (short) {
          // Kısa içerik sahnede ortada durur; %200 yazıda uzarsa sayfa
          // kayar.
          scroll = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              side,
              SahneSpace.x4,
              side,
              SahneSpace.x4,
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
            padding: EdgeInsets.fromLTRB(
              side,
              SahneSpace.x2,
              side,
              SahneSpace.x6,
            ),
            children: items,
          );
        }
        // Işınlar kahramanın dışına taşar; üst satırın (kapat, bağlam)
        // üstüne boyanmasın diye gövde kırpılır.
        return ClipRect(child: Stack(children: [scroll, ?overlay]));
      },
    );

    return SahneStageScaffold(
      onClose: onClose,
      closeLabel: closeLabel,
      // Sonuçta dar huzme yerine sonuç ışınları (kahramanın arkasında).
      beam: false,
      center: contextLabel == null ? null : Text(contextLabel!),
      dock: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSahneResultMaxWidth),
          child: SahneResultDock(primary: primary, secondary: secondary),
        ),
      ),
      body: body,
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
  const SahneResultEmblem.win({super.key}) : icon = null, _win = true;

  /// Nötr durum amblemi (berabere, kayıp, bekleme…).
  const SahneResultEmblem.state({super.key, required IconData this.icon})
    : _win = false;

  final IconData? icon;
  final bool _win;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SizedBox(
      height: 44,
      child: Center(
        child: _win
            ? const SahneGlyph(SahneGlyphKind.crown, size: 44)
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
    this.caption,
    this.body,
    this.extras = const [],
    this.celebrate = false,
    this.tone = SahneResultTone.reward,
    this.notices = const [],
  });

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
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        const SizedBox(height: SahneSpace.x2),
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
            style: SahneType.title.copyWith(
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
              style: SahneType.screen.copyWith(color: t.gold),
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: SahneType.headline.copyWith(
              color: t.tx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (caption != null) ...[
          const SizedBox(height: SahneSpace.x1),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: SahneType.caption.copyWith(color: t.tx2),
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
                  rays: celebrate,
                  // Işınlar puan sayısının (ya da puansızsa başlığın)
                  // ortasından çıkar.
                  raysCenterY: value != null ? 104 : 84,
                  bg: t.bg,
                  ridge: t.s1,
                ),
              ),
            ),
          ),
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

/// Bir sayım karosu: simge + sayı + söz.
class SahneResultStat {
  const SahneResultStat({
    required this.leading,
    required this.value,
    required this.label,
    this.showWhenZero = false,
  });

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

/// Sayım karoları — maketteki `.sh-stats`; en az 56 yüksek, L pah yüzey.
/// Durum hiçbir zaman yalnız renkle verilmez: ikon şekli ve söz birlikte.
///
/// Karolar eşit genişlikte yan yana durur; dar ekranda ya da büyük yazıda
/// bir karo 96'dan darsa ikişerli satıra iner (sayı ve söz harf harf
/// bölünmez). Görünür karo yoksa hiçbir şey çizilmez.
class SahneResultStats extends StatelessWidget {
  const SahneResultStats({super.key, required this.stats});

  final List<SahneResultStat> stats;

  /// Çizilecek bir karo var mı? Çağıran, boş şerit için yer ayırmasın diye
  /// önceden sorar.
  static bool hasVisible(List<SahneResultStat> stats) =>
      stats.any((stat) => stat.visible);

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final stat in stats)
        if (stat.visible) _StatTile(stat: stat),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SahneSpace.x2;
        final minTile = MediaQuery.textScalerOf(context).scale(96);
        var perRow = tiles.length;
        while (perRow > 1 &&
            (constraints.maxWidth - gap * (perRow - 1)) / perRow < minTile) {
          perRow = perRow > 2 ? 2 : 1;
        }
        // 2026-09-30 simülatör: karolar `Wrap` içinde kendi boyunda
        // duruyordu; "Li pey hev" iki satıra kırılınca üçüncü karo öteki
        // ikisinden uzun çıkıyordu. Satırdaki karolar eşit yükseklikte
        // (`IntrinsicHeight` + uzatma); eksik kalan son satır boş
        // `SizedBox` ile aynı genişliği korur. Normal ölçekte sözler tek
        // satırdı, tur ve testler orada koştuğu için kusur sessiz kaldı.
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += perRow) {
          final chunk = tiles.sublist(i, math.min(i + perRow, tiles.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < perRow; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
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
              if (i > 0) const SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final SahneResultStat stat;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      container: true,
      label: '${stat.value} ${stat.label}',
      excludeSemantics: true,
      child: SahneSurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x3,
          vertical: SahneSpace.x2,
        ),
        child: ConstrainedBox(
          // a11y-tap-target: noninteractive — istatistik karosu; salt
          // görsel, dokunma hedefi değil.
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              SizedBox.square(dimension: 20, child: stat.leading),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
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
  });

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

  @override
  Widget build(BuildContext context) {
    final hasChips = coins > 0 || xp > 0;
    if (!hasChips && progress == null) return const SizedBox.shrink();
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasChips)
            // Ödül çipleri skor SAYIMI bittikten sonra yerine oturur: ödül
            // bir SONUÇtur, sebebinden önce gösterilmez (bkz.
            // [SahneRewardEntrance]).
            SahneRewardEntrance(
              child: Wrap(
                spacing: SahneSpace.x2,
                runSpacing: SahneSpace.x2,
                children: [
                  if (coins > 0)
                    SahneStatChip(
                      gold: true,
                      leading: const SahneGlyph(SahneGlyphKind.coin),
                      label: coinLabel ?? '+$coins',
                      semanticLabel: coinSemanticLabel,
                    ),
                  if (xp > 0)
                    SahneStatChip(
                      gold: true,
                      leading: const SahneGlyph(SahneGlyphKind.bolt),
                      label: xpLabel ?? '+$xp XP',
                    ),
                ],
              ),
            ),
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
      onTap: primary.onPressed,
      child: SahneButton.primary(
        label: primary.label,
        icon: primary.icon,
        arrow: primary.icon == null,
        expand: true,
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
