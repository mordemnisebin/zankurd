import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';

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

/// Ödül türü — hepsi ayrı görsel kimlik taşır.
///
/// Coin, XP ve streak aynı renkte ve aynı ikon anatomisinde görünüyordu;
/// oyuncu üç farklı ekonomiyi tek bir sarı sayı olarak okuyordu.
enum RewardKind { xp, coin, streak, level, rank }

extension RewardKindVisuals on RewardKind {
  Color get color => switch (this) {
    // XP ilerlemedir: safir.
    RewardKind.xp => const Color(0xFF1E4FA6),
    // Coin ekonomidir: altın — ödül/para için ayrılmış tek ton.
    RewardKind.coin => AppTheme.gold,
    // Streak süreklilikdir: madder/ateş.
    RewardKind.streak => const Color(0xFFBC4318),
    // Level ustalıktır: ametist.
    RewardKind.level => const Color(0xFF6A38BE),
    // Rank rekabettir: zümrüt.
    RewardKind.rank => const Color(0xFF0E7A57),
  };

  IconData get icon => switch (this) {
    RewardKind.xp => Icons.bolt_rounded,
    RewardKind.coin => Icons.monetization_on_rounded,
    RewardKind.streak => Icons.local_fire_department_rounded,
    RewardKind.level => Icons.workspace_premium_rounded,
    RewardKind.rank => Icons.leaderboard_rounded,
  };
}

/// Ödül jetonu: değer + tür, tek satırda okunur.
///
/// Renk tek kanal değildir — her türün kendi ikonu da vardır, böylece
/// renk körü kullanıcı XP ile coin'i ayırt edebilir.
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

  /// Dolu renkli bir yüzeyin üstünde mi duruyor.
  final bool onSolid;

  @override
  Widget build(BuildContext context) {
    final tone = kind.color;
    final fg = onSolid ? Colors.white : AppColors.readableAccent(context, tone);
    final bg = onSolid
        ? Colors.white.withValues(alpha: 0.18)
        : tone.withValues(alpha: AppTheme.isLight(context) ? 0.12 : 0.22);

    return Semantics(
      label: label == null ? value : '$value $label',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: fg.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(kind.icon, size: compact ? 13 : 15, color: fg),
              const SizedBox(width: 5),
              // Esnek olmalı: `987654/1000000` gibi bir değer %200 yazıda
              // dar telefonda hiçbir biçimde sığmıyor ve jeton satırı
              // taşırıyordu. Kısaltma son çare — ama taşma şeridi hiçbir
              // şey göstermez, kısaltma en azından öneki gösterir ve
              // düzen ayakta kalır.
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Durum çipi — renk TEK kanal değil; her durumun ikonu da vardır.
enum ArenaStatus { upcoming, live, joined, completed, locked, offline, loading }

class ArenaStatusChip extends StatelessWidget {
  const ArenaStatusChip({
    required this.status,
    required this.label,
    this.onSolid = false,
    super.key,
  });

  final ArenaStatus status;
  final String label;
  final bool onSolid;

  (Color, IconData) get _visual => switch (status) {
    ArenaStatus.upcoming => (const Color(0xFF2A5A8C), Icons.schedule_rounded),
    ArenaStatus.live => (const Color(0xFF0E7A57), Icons.circle),
    ArenaStatus.joined => (const Color(0xFF6A38BE), Icons.check_circle_rounded),
    ArenaStatus.completed => (const Color(0xFF0E7A57), Icons.flag_rounded),
    ArenaStatus.locked => (const Color(0xFF3A4557), Icons.lock_rounded),
    ArenaStatus.offline => (const Color(0xFF9C6300), Icons.cloud_off_rounded),
    ArenaStatus.loading => (
      const Color(0xFF3A4557),
      Icons.hourglass_top_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = _visual;
    final fg = onSolid ? Colors.white : AppColors.readableAccent(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: onSolid
            ? Colors.white.withValues(alpha: 0.18)
            : tone.withValues(alpha: AppTheme.isLight(context) ? 0.12 : 0.22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arena başlığı — play hub, turnuva, yarışma ve liderlik paylaşır.
///
/// Ortak anatomi: amblem + başlık + durum + isteğe bağlı jetonlar + CTA.
/// Her ekran aynı hero'yu yalnız rengini değiştirerek kullanmaz; hangi
/// parçaların görüneceğini bağlam belirler.
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
    final deep = Color.lerp(accent, const Color(0xFF17233B), 0.55)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, deep],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Tek baskın motif alanı — tabanda, ölçülü.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 30,
              child: CustomPaint(
                painter: KilimPainter(
                  motif: motif,
                  color: Colors.white,
                  opacity: 0.12,
                  count: 10,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CategoryEmblem(icon: icon, color: Colors.white, size: 46),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Durum çipi ESNEK olmalı. `ArenaStatusChip`in kendi
                    // etiketi zaten kısalabiliyordu, ama hero onu esnemeyen
                    // bir çocuk olarak veriyordu: çip sınırsız genişlik
                    // alıyor, kısaltma hiç devreye girmiyor ve satır
                    // taşıyordu. Turnuva hero'sunda uzun bir durum
                    // etiketiyle 46 piksel taştı (2026-08-04).
                    if (status != null) Flexible(flex: 2, child: status!),
                  ],
                ),
                if (tokens.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(spacing: 8, runSpacing: 8, children: tokens),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(width: double.infinity, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Görev ilerleme kartı.
///
/// Görevler "metin + ince çizgi" olarak çiziliyordu; ödül ve tamamlanma
/// durumu görsel olarak yoktu. Burada ilerleme, ödül ve durum aynı kartta
/// okunur — ama her göreve rastgele dolu renk verilmez, aksan kontrollüdür.
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
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final done = ratio >= 1.0;
    final tone = AppColors.readableAccent(context, accent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? accent.withValues(alpha: 0.55)
              : AppTheme.borderColor(context),
          width: done ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tone),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              ?reward,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: AppTheme.borderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Sayı, ilerlemeyi rengin yanında ikinci kanal olarak verir.
              Text(
                '$current/$target',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textSubColor(context),
                ),
              ),
            ],
          ),
          if (done && onClaim != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Sunucudan sonuç gelmeden başarı gösterilmez: düğme
                // yükleniyorken kilitlenir.
                onPressed: claimed || claiming ? null : onClaim,
                child: claiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    // Karakter değil ikon: `✓` (U+2713) Rubik'te yok ve
                    // sistem yazı tipine düşüyordu (ui_glyph_coverage_test).
                    : Icon(
                        claimed
                            ? Icons.check_rounded
                            : Icons.card_giftcard_rounded,
                        size: 18,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sıralama madalyası — ilk üç için elmas, gerisi için sade numara.
class RankMedal extends StatelessWidget {
  const RankMedal({required this.rank, this.size = 40, super.key});

  final int rank;
  final double size;

  Color get _tone => switch (rank) {
    1 => AppTheme.gold,
    2 => const Color(0xFF8A93A6),
    3 => const Color(0xFFA9622E),
    _ => const Color(0xFF3A4557),
  };

  @override
  Widget build(BuildContext context) {
    final podium = rank <= 3;
    final tone = _tone;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (podium)
            CustomPaint(
              size: Size.square(size),
              painter: KilimPainter(
                motif: KilimMotif.diamond,
                color: tone,
                opacity: 0.85,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: 0.14),
              ),
            ),
          // İlk üçte rakam DOLU bir disk üstünde durur.
          //
          // Beyaz rakam doğrudan kilim elmasının üstüne çiziliyordu; elmas
          // dolu değil desenli olduğu için rakam açık zeminde kayboluyordu
          // ve madalya boş bir şekle dönüşüyordu. Sıralamada bu hiç
          // görülmedi çünkü liste yalnız 4 ve sonrasını çiziyor; yarışma
          // ödül basamaklarında ilk üç kullanılınca ortaya çıktı
          // (2026-08-04). Sıra yalnız renkle anlatılamaz — rakam
          // okunabilir kalmalı.
          if (podium)
            Container(
              width: size * 0.52,
              height: size * 0.52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$rank',
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSolid(tone),
                  ),
                ),
              ),
            )
          else
            Text(
              '$rank',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.readableAccent(context, tone),
              ),
            ),
        ],
      ),
    );
  }
}
