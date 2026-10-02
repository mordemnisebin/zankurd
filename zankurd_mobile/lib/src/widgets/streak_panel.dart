import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'arena_kit.dart';
import 'branded_loader.dart';
import 'sahne/sahne.dart';

/// Bir günün streak açısından durumu.
///
/// Renk tek kanal değildir: her durumun kendi şekli/ikonu da vardır, çünkü
/// "kaçırdım" ile "henüz gelmedi" arasındaki fark yalnız tonla anlatılırsa
/// renk körü oyuncu için kaybolur.
enum StreakDayState { completed, today, missed, upcoming, frozen }

/// Gün durumunun ekran okuyucu anonsu için l10n anahtarı.
///
/// `Semantics.label` eskiden `'$label: ${state.name}'` üretiyordu — yani
/// TalkBack/VoiceOver "Pt: completed" gibi ham İngilizce enum adını
/// okuyordu (2026-08-14 denetimi). Görsel ikon/renk dilden bağımsız
/// kalabilir ama anons kalamaz; bu yüzden saf bir eşleme fonksiyonu.
String streakDayStateKey(StreakDayState state) => switch (state) {
  StreakDayState.completed => K.streakDayStateCompleted,
  StreakDayState.today => K.streakDayStateToday,
  StreakDayState.missed => K.streakDayStateMissed,
  StreakDayState.upcoming => K.streakDayStateUpcoming,
  StreakDayState.frozen => K.streakDayStateFrozen,
};

/// Streak-freeze'in o andaki durumu.
///
/// Sekiz ayrı durum var ve altısı "düğme sönük" olarak çiziliyordu; oyuncu
/// coin'i yetmediği için mi, gerek olmadığı için mi, yoksa sunucu
/// ulaşılamadığı için mi kullanamadığını ayırt edemiyordu.
enum StreakFreezeState {
  available,
  notNeeded,
  insufficientCoins,
  applying,
  applied,
  uncertain,
  offline,
  unavailable,
}

/// Streak yüzeyi: seri, haftalık ritim, sonraki milestone ve freeze durumu.
///
/// Önceki hâli tek bir alev ikonu ve bir sayıydı. Sayı "7" diyordu ama
/// oyuncu hangi günleri oynadığını, bugün oynayıp oynamadığını, serinin
/// kırılmak üzere olup olmadığını ve dondurma hakkının ne durumda olduğunu
/// göremiyordu — yani seriyi KORUMAK için gereken hiçbir bilgi ekranda
/// yoktu.
class StreakPanel extends StatelessWidget {
  const StreakPanel({
    required this.current,
    required this.days,
    required this.freezeState,
    required this.freezeLabel,
    required this.dayLabels,
    this.freezeActionLabel,
    this.nextMilestone,
    this.freezeCost,
    this.onFreeze,
    this.dayUnitLabel = '',
    super.key,
  });

  /// Mevcut seri (gün).
  final int current;

  /// Son yedi günün durumu, en eskiden bugüne.
  final List<StreakDayState> days;

  final StreakFreezeState freezeState;

  /// Freeze durumunun yerelleştirilmiş etiketi.
  final String freezeLabel;

  /// Yedi günün yerelleştirilmiş kısaltmaları.
  final List<String> dayLabels;

  /// Koruma düğmesinin yerelleştirilmiş etiketi; yoksa düğme çizilmez.
  final String? freezeActionLabel;

  /// Bir sonraki kilometre taşı; yoksa gösterilmez.
  final int? nextMilestone;

  /// Dondurmanın coin maliyeti; yalnız gerçekten ücretliyse verilir.
  final int? freezeCost;

  final VoidCallback? onFreeze;

  /// "gün"/"roj" — jetonun birim etiketi.
  final String dayUnitLabel;

  /// Freeze durumunun okunur etiketi ve gün kısaltmaları ÇAĞIRANDAN gelir.
  ///
  /// Panel içine satır içi iki-dilli üçlü ifade yazmak metni bileşene
  /// gömer ve
  /// `l10n_migration_guard`in saydığı satır içi iki-dil kullanımını
  /// artırır. Bileşen sunumsal kalmalı: neyi çizeceğini bilir, hangi dilde
  /// yazacağını bilmez.
  static ArenaStatus _statusFor(StreakFreezeState state) => switch (state) {
    StreakFreezeState.available => ArenaStatus.live,
    StreakFreezeState.notNeeded => ArenaStatus.completed,
    StreakFreezeState.insufficientCoins => ArenaStatus.locked,
    StreakFreezeState.applying => ArenaStatus.loading,
    StreakFreezeState.applied => ArenaStatus.joined,
    // Belirsiz işlem: sunucudan cevap gelmedi. "Uygulandı" DEMEZ.
    StreakFreezeState.uncertain => ArenaStatus.upcoming,
    StreakFreezeState.offline => ArenaStatus.offline,
    StreakFreezeState.unavailable => ArenaStatus.locked,
  };

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: yüzey kartı (Perde, L pah, gündüzde 1 px kenar);
    // seri jetonu alev glifli stat çipi; hafta gün karoları; kilometre taşı
    // Zêr ilerleme çubuğu ("5/7" sağda); koruma ikincil düğme (Kulis).
    final t = SahneTokens.of(context);
    final labels = dayLabels;
    final chipStatus = _statusFor(freezeState);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                RewardToken(
                  kind: RewardKind.streak,
                  value: '$current',
                  label: dayUnitLabel,
                ),
                const SizedBox(width: SahneSpace.x2),
                // Esnek olmalı: uzun Kurmancî durum etiketi %200 yazıda
                // satırı 356 piksel taşırıyordu. `Spacer` esnemeyen bir
                // çipin yanında hiçbir şeyi kurtaramaz.
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ArenaStatusChip(
                      status: chipStatus,
                      label: freezeLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x3),
            // Haftalık ritim: her gün renk + şekil/ikon taşır.
            //
            // Yedi işaret 200% yazıda dar telefona sığmıyordu; satır yatay
            // kaydırılabilir. Günleri kırpmak ya da küçültmek ritmi
            // okunmaz hâle getirirdi — asıl bilgi tam da o dizidir.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < days.length && i < labels.length; i++)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: i == days.length - 1 ? 0 : SahneSpace.x2,
                      ),
                      child: _DayMark(state: days[i], label: labels[i]),
                    ),
                ],
              ),
            ),
            if (nextMilestone != null && nextMilestone! > current) ...[
              const SizedBox(height: SahneSpace.x3),
              // Hedef sayıyla da yazılır; çubuk tek başına ölçü vermez.
              SahneProgressBar(
                value: (current / nextMilestone!).clamp(0.0, 1.0),
                tone: SahneProgressTone.gold,
                trailing: '$current/${nextMilestone!}',
                semanticLabel: dayUnitLabel.isEmpty ? null : dayUnitLabel,
              ),
            ],
            if (freezeState == StreakFreezeState.available &&
                onFreeze != null &&
                freezeActionLabel != null) ...[
              const SizedBox(height: SahneSpace.x3),
              SahneButton.secondary(
                label: freezeCost == null
                    ? freezeActionLabel!
                    : '${freezeActionLabel!} · $freezeCost',
                icon: AppIcons.shield,
                expand: true,
                onPressed: onFreeze,
              ),
            ],
            if (freezeState == StreakFreezeState.applying) ...[
              const SizedBox(height: SahneSpace.x3),
              const Center(child: BrandedLoader(size: 20, strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({required this.state, required this.label});

  final StreakDayState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Gün karosu: tamamlanan gün Zêr dolu + ✓ (seri ödüldür), bugün Zêr
    // tonu + Halka 2, kaçırılan Ray + ✗, gelecek yalnız çizgi, dondurulan
    // Kulis + kalkan. Durum yalnız renkle verilmez: her birinin ikonu ayrı.
    //
    // 2026-09-29 doğallık (K5): günler elmastı. Elmas yalnız soru
    // ilerlemesi ve ders sayacında kalır; gün, boyuna uygun pahlı kare
    // ([SahneShape.forSize], 32 → M).
    final (Color bg, Color fg, IconData icon, Color? ring) = switch (state) {
      StreakDayState.completed => (t.gold, t.onGold, AppIcons.check, null),
      StreakDayState.today => (
        t.goldTint,
        t.goldTx,
        AppIcons.calendarDays,
        t.goldTx,
      ),
      StreakDayState.missed => (t.s3, t.tx2, AppIcons.xmark, null),
      StreakDayState.upcoming => (t.s1, t.tx3, AppIcons.clock, t.s3),
      // Dondurulmuş gün: seri korunmuş ama oynanmamış. Tamamlanmışla aynı
      // görünmemeli, kaçırılmışla da.
      StreakDayState.frozen => (t.s2, t.tx, AppIcons.shield, null),
    };

    return Semantics(
      label: '$label: ${context.t(streakDayStateKey(state))}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 32,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: bg,
                  shape: ring == null
                      ? SahneShape.forSize(32)
                      : SahneShape.withSide(
                          SahneShape.forSize(32),
                          ring,
                          width: SahneRing.r2,
                        ),
                ),
                child: Icon(icon, size: 14, color: fg),
              ),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(label, style: SahneType.caption.copyWith(color: t.tx2)),
          ],
        ),
      ),
    );
  }
}
