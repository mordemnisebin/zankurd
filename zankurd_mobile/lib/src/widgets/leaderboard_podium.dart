import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_icons.dart';
import '../utils/player_identity.dart';
import 'player_avatar.dart';
import 'sahne/sahne.dart';

/// Sıralamanın ilk üçü: ortada birinci (en uzun kaide), solda ikinci,
/// sağda üçüncü.
///
/// ## Karar tarihi
///
/// 2026-09-29 doğallık (K9) podyumu kaldırmıştı: büyük elmas avatarlar,
/// madalya halkası, taç ve altın hale üç kişilik bir haftada ekranın
/// tamamını kaplıyor, hiçbir şey kazanılmadan "kutlama" çiziyordu. 2026-10-01
/// tasarım denetimi (A8) ilk üçün listeden ayrışmasını istedi; bu kez süs
/// değil YAPI: üç pahlı kaide (Şahnê L pah), avatar, ad, puan. Hale, madalya
/// halkası ve elmas yok; yalnız birincinin üstünde küçük bir taç.
///
/// ## Kurallar
///
/// * Yalnız ÜÇ ve daha çok oyuncu varken çizilir (çağıran karar verir);
///   daha azında düz liste kalır — tek kişilik bir "podyum" kutlama değil
///   boşluk olurdu.
/// * Üç sütun sığmıyorsa ([fits]: 320 px'te büyük yazı) çizilmez, ilk üç de
///   liste satırı olarak kalır; adlar kırpılmaz.
/// * Rakam her zaman yazılıdır (kaidenin üstünde); sıra yalnız renkle ya da
///   yükseklikle anlatılmaz.
/// * "Bildir" düğmesi GÖRÜNÜRDÜR (Apple 1.2): liste satırındaki aynı
///   anahtar (`leaderboard-report-<id>`) ve aynı etiket; kendi kaidende
///   düğme yerine "Sen" rozeti durur.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.entries,
    required this.isKu,
    required this.selfId,
    required this.colorOverrides,
    required this.onReport,
  });

  /// Tam üç kayıt, sıra sırasıyla (1., 2., 3.).
  final List<LeaderboardEntry> entries;
  final bool isKu;

  /// Oturum sahibinin kimliği; ilk üçteyse kaidesi "Sen" taşır.
  final String? selfId;
  final Map<String, Color> colorOverrides;
  final void Function(LeaderboardEntry entry) onReport;

  static const double _gap = SahneSpace.x2;

  /// Sütun genişliğinin altına inmeyeceği değer (yazı ölçeğiyle büyür).
  static const double _minColumn = 80;

  /// [width] genişliğinde üç sütun, bu yazı ölçeğinde sığıyor mu?
  static bool fits(BuildContext context, double width) {
    final column = (width - 2 * _gap) / 3;
    return column >= MediaQuery.textScalerOf(context).scale(_minColumn);
  }

  @override
  Widget build(BuildContext context) {
    assert(entries.length == 3, 'Podyum tam üç kayıt ister');
    // Görsel sıra: 2 · 1 · 3. Anlam sırası (ekran okuyucu) 1 · 2 · 3.
    final order = [1, 0, 2];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: _PodiumColumn(
                entry: entries[order[i]],
                place: order[i],
                isKu: isKu,
                isSelf: selfId != null && entries[order[i]].playerId == selfId,
                colorOverride: colorOverrides[entries[order[i]].playerId],
                onReport: selfId != null && entries[order[i]].playerId == selfId
                    ? null
                    : () => onReport(entries[order[i]]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.entry,
    required this.place,
    required this.isKu,
    required this.isSelf,
    required this.colorOverride,
    required this.onReport,
  });

  final LeaderboardEntry entry;

  /// 0 = birinci, 1 = ikinci, 2 = üçüncü.
  final int place;
  final bool isKu;
  final bool isSelf;
  final Color? colorOverride;
  final VoidCallback? onReport;

  /// Kaide yükseklikleri: birinci en uzun. Dört katı; büyük yazıda kaide
  /// içeriğiyle birlikte uzar (en az bu kadar).
  static const _pedestal = [104.0, 92.0, 80.0];
  static const _avatarRadius = [32.0, 24.0, 24.0];

  String get _name => PlayerIdentity.resolveName(entry.displayName, isKu: isKu);

  Color _rankColor(SahneTokens t) {
    if (isSelf) return t.goldTx;
    return switch (place) {
      0 => t.goldTx,
      1 => t.silverTx,
      _ => t.bronzeTx,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = Tr.forKu(isSelf ? K.seninSiranPP : K.pPPPuan, isKu, {
      'p0': '${entry.rank}',
      'p1': _name,
      'p2': '${entry.totalScore}',
    });
    final first = place == 0;
    final pedestalShape = first
        ? SahneShape.withSide(SahneShape.l, t.gold, width: SahneRing.r1)
        : SahneShape.withSide(SahneShape.l, t.edge, width: 1);
    final pedestal = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _pedestal[place]),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: first ? t.goldTint : t.s1,
          shape: pedestalShape,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(
                  '${entry.rank}',
                  maxLines: 1,
                  style: SahneType.title.copyWith(
                    color: _rankColor(t),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (isSelf)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
                  child: SahneBadge(
                    label: Tr.forKu(K.you, isKu),
                    tone: SahneBadgeTone.gold,
                  ),
                )
              else
                Semantics(
                  button: true,
                  label: Tr.forKu(K.reportProfileTitle, isKu),
                  child: IconButton(
                    key: ValueKey('leaderboard-report-${entry.playerId}'),
                    onPressed: onReport,
                    icon: const Icon(AppIcons.flag, size: 16),
                    color: t.tx3,
                    // Android dokunma hedefi: 48 dp altına düşmez.
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: Tr.forKu(K.reportProfileTitle, isKu),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      key: ValueKey('leaderboard-rank-row-${entry.rank}'),
      container: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (first) ...[
                  const SahneGlyph(SahneGlyphKind.crown, size: 28),
                  const SizedBox(height: SahneSpace.x1),
                ],
                PlayerAvatar(
                  radius: _avatarRadius[place],
                  photoUrl: entry.avatarUrl,
                  iconId: entry.avatarIcon,
                  colorHex: entry.avatarColor,
                  frameId: entry.avatarFrame,
                  displayName: entry.displayName,
                  colorOverride: colorOverride,
                ),
                const SizedBox(height: SahneSpace.x2),
                _PodiumName(name: _name),
                const SizedBox(height: SahneSpace.x1),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${entry.totalScore}',
                      maxLines: 1,
                      style: SahneType.bodyStrong.copyWith(
                        color: isSelf ? t.goldTx : t.tx,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SahneSpace.x2),
              ],
            ),
          ),
          pedestal,
        ],
      ),
    );
  }
}

/// Podyum adı: en fazla üç satır, ortalı. Bir SÖZCÜK sütundan geniş çıkarsa
/// yazı sözcük sığana kadar küçülür (en çok %25) — sözcüğün ortasından
/// kırılıp "Abdurrahma/n" olmasın (320 px'te kırılıyordu); üç satıra da
/// sığmayan çok uzun ad son çare üç noktayla biter.
class _PodiumName extends StatelessWidget {
  const _PodiumName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final base = SahneType.captionStrong.copyWith(color: t.tx);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var style = base;
        final longest = name
            .split(RegExp(r'\s+'))
            .fold<String>('', (a, b) => b.length > a.length ? b : a);
        final painter = TextPainter(
          text: TextSpan(
            text: longest,
            style: base.copyWith(fontFamily: SahneType.text),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > constraints.maxWidth && painter.width > 0) {
          // %4 pay: ölçü ile çizim arasındaki yuvarlama farkı sözcüğü yine
          // kırabiliyordu.
          final factor = (constraints.maxWidth / painter.width * 0.96).clamp(
            0.75,
            1.0,
          );
          style = base.copyWith(fontSize: (base.fontSize ?? 14) * factor);
        }
        return Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
