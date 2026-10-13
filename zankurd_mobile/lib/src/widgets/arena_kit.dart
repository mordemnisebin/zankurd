import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/kilim_motifs.dart';
import 'sahne/sahne.dart';

/// Rengîn Editorial Arena'nın oyunlaştırma bileşenleri.
///
/// Play hub, görevler, streak, liderlik, turnuva, yarışma, çark ve mağaza
/// birbirinden habersiz büyümüştü: sekiz ekran, sekiz ayrı kart anatomisi,
/// hepsi aynı beyaz yüzeyde. Ortak bir dil olmayınca "oyunlaştırma" yalnız
/// ikon ve sayı olarak kalıyordu.
///
/// Buradaki bileşenler o dili tek yerde toplar. Ama tek bir kartı sekiz
/// ekrana kopyalamazlar: her biri bağlamına uyarlanabilir parametreler
/// alır, çünkü liderlik ile mağaza aynı şeyi anlatmıyor.
///
/// 2026-09-29 Şahnê: hepsi Şahnê bileşenlerinin dilinde — ödül jetonu stat
/// çipi, durum çipi rol rozeti, arena başlığı sahne kartı, görev kartı
/// yüzey kartı + ilerleme çubuğu, madalya karosu. Renk rol taşır; ödül
/// her zaman Zêr'dir ve türler GLİF ŞEKLİYLE ayrışır (jeton, şimşek,
/// alev, yıldız, taç), renkle değil.

/// Ödül türü — hepsi ayrı görsel kimlik taşır.
///
/// Coin, XP ve streak aynı ikon anatomisinde görünüyordu; oyuncu üç farklı
/// ekonomiyi tek bir sarı sayı olarak okuyordu. Şahnê'de hepsi ödüldür
/// (Zêr) ve ayrım ŞEKİLDEDİR: her türün kendi dolu glifi ([glyph]) ve
/// kendi çizgi ikonu ([icon]) vardır.
enum RewardKind { xp, coin, streak, level, rank }

extension RewardKindVisuals on RewardKind {
  /// Türün rengi. 2026-09-29 Şahnê: ödülün tek rengi Zêr'dir (jeton, XP,
  /// seri, seviye, sıra); türler glifle ayrışır. Belirteç iki temada
  /// aynıdır.
  Color get color => SahneTokens.night.gold;

  /// Türün dolu ödül glifi — türü ayıran asıl kanal.
  SahneGlyphKind get glyph => switch (this) {
    RewardKind.xp => SahneGlyphKind.bolt,
    RewardKind.coin => SahneGlyphKind.coin,
    RewardKind.streak => SahneGlyphKind.flame,
    RewardKind.level => SahneGlyphKind.star,
    RewardKind.rank => SahneGlyphKind.crown,
  };

  IconData get icon => switch (this) {
    RewardKind.xp => AppIcons.bolt,
    RewardKind.coin => AppIcons.coins,
    RewardKind.streak => AppIcons.fire,
    RewardKind.level => AppIcons.medal,
    RewardKind.rank => AppIcons.trophy,
  };
}

/// Ödül jetonu: değer + tür, tek satırda okunur.
///
/// 2026-09-29 Şahnê: stat çipi görünüşü ([SahneStatChip]) — M pah, Kulis
/// tonu, solda türün Zêr glifi, değer kalın açıklama + tablo rakamı,
/// etiket açıklama (ikincil metin). [compact]: 28 yükseklik, 16'lık glif.
/// [onSolid]: çip kendi zeminini taşıdığı için renkli yüzeyde de aynı
/// çizilir (geriye uyum).
class RewardToken extends StatelessWidget {
  const RewardToken({
    required this.kind,
    required this.value,
    this.label,
    this.compact = false,
    this.onSolid = false,
    super.key,
  });

  final RewardKind kind;
  final String value;
  final String? label;
  final bool compact;

  /// Dolu renkli bir yüzeyin üstünde mi duruyor (geriye uyum).
  final bool onSolid;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label: label == null ? value : '$value $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: t.s2,
            shape: compact ? SahneShape.s : SahneShape.m,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 28 : 36),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: compact ? SahneSpace.x1 : SahneSpace.x2,
                end: compact ? SahneSpace.x2 : SahneSpace.x3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SahneGlyph(kind.glyph, size: compact ? 16 : 20),
                  const SizedBox(width: SahneSpace.x1),
                  // Esnek olmalı: `987654/1000000` gibi bir değer %200
                  // yazıda dar telefonda hiçbir biçimde sığmıyor ve jeton
                  // satırı taşırıyordu. Kısaltma son çare — ama taşma şeridi
                  // hiçbir şey göstermez, kısaltma en azından öneki gösterir.
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.captionStrong.copyWith(
                        color: t.tx,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(width: SahneSpace.x1),
                    Flexible(
                      child: Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Durum çipi — renk TEK kanal değil; her durumun ikonu da vardır.
enum ArenaStatus { upcoming, live, joined, completed, locked, offline, loading }

/// 2026-09-29 Şahnê: rol rozeti dili — 28, S pah, ton zemin + ton metni,
/// ikon + kalın açıklama. Canlı Zimrût, katıldın Zêr, bitti Rast, çevrimdışı
/// Zêr (dikkat, hata değil), öteki durumlar nötr Kulis. Ton zemini opaktır:
/// renkli yüzeyde ([onSolid]) de aynı okunur.
class ArenaStatusChip extends StatelessWidget {
  const ArenaStatusChip({
    required this.status,
    required this.label,
    this.onSolid = false,
    this.role,
    super.key,
  });

  final ArenaStatus status;
  final String label;
  final bool onSolid;

  /// Kartın rolü. Yarış kartında ([SahneRole.race]) "canlı/bugün" durumu
  /// Boyax tonunu alır: lal sahnede yeşil bir rozet rol dilini bozuyordu
  /// (yarışma "Bugün", 2026-09-29).
  final SahneRole? role;

  IconData get _icon => switch (status) {
    ArenaStatus.upcoming => AppIcons.clock,
    ArenaStatus.live => AppIcons.circle,
    ArenaStatus.joined => AppIcons.circleCheck,
    ArenaStatus.completed => AppIcons.flag,
    ArenaStatus.locked => AppIcons.lock,
    ArenaStatus.offline => AppIcons.cloud,
    ArenaStatus.loading => AppIcons.hourglass,
  };

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (bg, fg) = switch (status) {
      ArenaStatus.live =>
        role == SahneRole.race
            ? (t.raceTint, t.raceTx)
            : (t.learnTint, t.learnTx),
      ArenaStatus.joined => (t.goldTint, t.goldTx),
      ArenaStatus.completed => (t.okTint, t.okTx),
      ArenaStatus.offline => (t.goldTint, t.goldTx),
      ArenaStatus.upcoming ||
      ArenaStatus.locked ||
      ArenaStatus.loading => (t.s2, t.tx2),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — durum çipi (etiket); salt
        // görsel, dokunma hedefi değil.
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: fg),
              const SizedBox(width: SahneSpace.x1),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arena başlığı — play hub, turnuva, yarışma ve liderlik paylaşır.
///
/// Ortak anatomi: amblem + başlık + durum + isteğe bağlı jetonlar + CTA.
///
/// 2026-09-29 Şahnê: sahne kartı ([SahneStageCard]) — iki temada da gece
/// degradesi + rol radyali, üst kenarda rol renkli kilim şeridi, L pah.
/// [accent] ham renk olarak boyanmaz, rolüne çevrilir ([sahneRoleFor];
/// lal → yarış sahnesi). Eski beyaz-üstüne-altın başlık 2,56:1 kalıyordu
/// (erişilebilirlik kılavuzu testi, "ZanKurd Kupası"); gece sahnesinde
/// başlık birincil metindir. [motif] geriye uyum için kalır; desen artık
/// yalnız üst şerittir.
class ArenaHero extends StatelessWidget {
  const ArenaHero({
    required this.title,
    required this.accent,
    required this.icon,
    this.subtitle,
    this.status,
    this.tokens = const [],
    this.action,
    this.motif = KilimMotif.triangleRhythm,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final IconData icon;
  final Widget? status;
  final List<Widget> tokens;
  final Widget? action;
  final KilimMotif motif;

  @override
  Widget build(BuildContext context) {
    final role = sahneRoleFor(accent);
    return SizedBox(
      width: double.infinity,
      child: SahneStageCard(
        role: role,
        child: Builder(
          builder: (context) {
            // Sahne kartının içi gece belirteçleridir.
            final t = SahneTokens.of(context);
            final race = role == SahneRole.race;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: t.roleTint(role),
                          shape: SahneShape.m,
                        ),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            icon,
                            size: 24,
                            color: race
                                ? SahneStageColors.raceSoft
                                : t.roleText(role),
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
                          // Başlık kesilmez: uzun Kurmancî kupa adı iki
                          // satırda "…" ile bitiyordu. Sarar; tek uzun söz
                          // harf harf bölünmez.
                          Semantics(
                            header: true,
                            child: SahneUnbrokenText(
                              title,
                              style: SahneType.headline.copyWith(color: t.tx),
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: SahneType.caption.copyWith(
                                color: race ? SahneStageColors.raceSoft : t.tx2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Durum çipi başlığın yanında değil, ödül jetonlarıyla aynı
                // satırda ve ORTA hizada durur: başlığın yanında başlığı
                // daraltıp kesiyordu, jetonlarla (36) ayrı satırda 28'lik
                // çip hizasız kalıyordu. Wrap sarar, satır taşmaz.
                if (status != null || tokens.isNotEmpty) ...[
                  const SizedBox(height: SahneSpace.x3),
                  Wrap(
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [?status, ...tokens],
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: SahneSpace.x4),
                  SizedBox(width: double.infinity, child: action!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Görev ilerleme kartı.
///
/// Görevler "metin + ince çizgi" olarak çiziliyordu; ödül ve tamamlanma
/// durumu görsel olarak yoktu. Burada ilerleme, ödül ve durum aynı kartta
/// okunur.
///
/// 2026-09-29 Şahnê: yüzey kartı (Perde, L pah; gündüzde 1 px kenar,
/// tamamlanınca Halka 1 Zêr kaş), ikon rolün metin renginde, başlık Gövde
/// 700, ilerleme [SahneProgressBar] (sağda "2/3", tablo rakamı). Ödül alma
/// düğmesi Kulis tonlu ikincil düğmedir: bir listede birden çok görev
/// alınabilir olabilir, ekranın tek birincil eylemi değildir.
class MissionProgressCard extends StatelessWidget {
  const MissionProgressCard({
    required this.title,
    required this.current,
    required this.target,
    required this.accent,
    required this.icon,
    this.reward,
    this.claimed = false,
    this.onClaim,
    this.claiming = false,
    super.key,
  });

  final String title;
  final int current;
  final int target;
  final Color accent;
  final IconData icon;
  final Widget? reward;
  final bool claimed;
  final VoidCallback? onClaim;
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final done = ratio >= 1.0;
    final role = sahneRoleFor(accent);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(
          SahneShape.l,
          done ? t.gold : t.edge,
          width: done ? SahneRing.r1 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: t.roleText(role)),
                const SizedBox(width: SahneSpace.x2),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ),
                ?reward,
              ],
            ),
            const SizedBox(height: SahneSpace.x2),
            // Sayı, ilerlemeyi rengin yanında ikinci kanal olarak verir.
            SahneProgressBar(
              value: ratio,
              tone: role == SahneRole.learn
                  ? SahneProgressTone.learn
                  : SahneProgressTone.gold,
              trailing: '$current/$target',
              semanticLabel: title,
            ),
            if (done && onClaim != null) ...[
              const SizedBox(height: SahneSpace.x2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Sunucudan sonuç gelmeden başarı gösterilmez: düğme
                  // yükleniyorken kilitlenir.
                  onPressed: claimed || claiming ? null : onClaim,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.s2,
                    foregroundColor: t.tx,
                    disabledBackgroundColor: t.s1,
                    disabledForegroundColor: t.tx3,
                    minimumSize: const Size(48, 48),
                    shape: SahneShape.m,
                  ),
                  child: claiming
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.tx3,
                          ),
                        )
                      // Karakter değil ikon: `✓` (U+2713) yazı tipinde yok
                      // ve sistem yazı tipine düşüyordu.
                      : claimed
                      ? Icon(AppIcons.check, size: 20, color: t.okTx)
                      : const SahneGlyph(SahneGlyphKind.coin, size: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sıralama madalyası — ilk üç için madalya karosu, gerisi için sade numara.
///
/// 2026-09-29 Şahnê: madalya rengi dolgu (altın, gümüş, bronz) içinde koyu
/// tablo rakamı; dördüncüden sonra yalnız ikincil metin rengi rakam. Sıra
/// hiçbir zaman yalnız renkle anlatılmaz: rakam her zaman yazılıdır.
///
/// 2026-09-29 doğallık (K5): madalya elmastı; elmas yalnız soru ilerlemesi
/// ve ders sayacında kalır. Madalya boyuna uygun pahlı kare
/// ([SahneShape.forSize]); rakam için iç alan da genişledi.
class RankMedal extends StatelessWidget {
  const RankMedal({required this.rank, this.size = 40, super.key});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final number = Text(
      '$rank',
      maxLines: 1,
      style: SahneType.bodyStrong.copyWith(
        color: rank <= 3 ? t.onGold : t.tx2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (rank > 3) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: number),
        ),
      );
    }
    final fill = switch (rank) {
      1 => t.gold,
      2 => SahneStageColors.silver,
      _ => SahneStageColors.bronze,
    };
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: SahneShape.forSize(size),
        ),
        child: Center(
          child: SizedBox.square(
            dimension: size * 0.6,
            child: FittedBox(fit: BoxFit.scaleDown, child: number),
          ),
        ),
      ),
    );
  }
}
