import 'package:flutter/material.dart';

import '../game/avatar_frames.dart';
import '../l10n/strings.dart';
import '../models/leaderboard_entry.dart';
import '../utils/player_identity.dart';
import 'player_avatar.dart';
import 'sahne/sahne.dart';
import '../utils/number_format.dart';

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
/// * Kaide (2026-10-20 kurul): avatar kaidenin ÜSTÜNDE oturur; ad ve puan
///   kaidenin içinde, rakamın altında. Yükseklikler açık basamaklı
///   (1 > 2 > 3). Bayrak simgesi yok: sütuna dokununca (`onReport`: oyuncu alt sayfası)
///   "Profili bildir" menüsü açılır (Apple 1.2 yolu korunur). Kendi
///   kaidende menü yok, "Sen" rozeti durur.
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
  static const _pedestal = [152.0, 124.0, 100.0];
  static const _avatarRadius = [32.0, 24.0, 24.0];

  String get _name => PlayerIdentity.resolveNameWithTag(
    entry.displayName,
    isKu: isKu,
    tag: entry.playerTag,
  );

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = Tr.forKu(isSelf ? K.seninSiranPP : K.pPPPuan, isKu, {
      'p0': '${entry.rank}',
      'p1': _name,
      'p2': groupThousands(entry.totalScore),
    });
    final first = place == 0;
    // Kurul 3. tur (2026-10-20, 06): kaideler liste grubuyla AYNI kart
    // işleme (Perde + 1 px kenar + L pah). Eskiden birinci kaide altın
    // dolgu ve altın halkaydı; liste ise nötr kartta kalıyor, sıralama
    // sekmesi (turuncu seçili) ile üç ayrı vurgu dili çıkıyordu. Birinciyi
    // artık yalnız taç ve altın rakam ayırır.
    final pedestal = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _pedestal[place]),
      child: DecoratedBox(
        // Zêr ilk üç (2026-10-20 B): kaide madalya tonunda, üstte madalya
        // renginde şerit; kendi satırın altın vurgusu aşağıda sürer.
        decoration: ShapeDecoration(
          color: t.medalTint(place),
          shape: SahneShape.withSide(
            SahneShape.l,
            t.medalBar(place),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.x1,
            SahneSpace.x2,
            SahneSpace.x1,
            SahneSpace.x2,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2026-10-29 vay 2B (B8): sıra rakamı madalya diskinde
                // (altın / gümüş / bronz degrade, koyu rakam ≥ 4.5:1).
                _MedalDisc(place: place, rank: entry.rank),
                const SizedBox(height: SahneSpace.x1),
                _PodiumName(name: _name),
                const SizedBox(height: SahneSpace.x1),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      groupThousands(entry.totalScore),
                      maxLines: 1,
                      style: SahneType.bodyStrong.copyWith(
                        color: isSelf ? t.goldTx : t.tx,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (isSelf) ...[
                  const SizedBox(height: SahneSpace.x1),
                  SahneBadge(
                    label: Tr.forKu(K.you, isKu),
                    tone: SahneBadgeTone.gold,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final column = Column(
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
              // Madalya halkası (7. kurul): ilk üçün avatarı altın / gümüş /
              // bronz ince halkayla ayrışır. Halka avatarın kendi pahlı
              // şeklini izler (yuvarlak değil); oyuncunun seçtiği çerçeve
              // içeride aynen kalır.
              DecoratedBox(
                key: ValueKey('podium-medal-ring-${place + 1}'),
                decoration: ShapeDecoration(
                  shape: SahneShape.withSide(
                    SahneShape.forSize(_avatarRadius[place] * 2 + 8),
                    frameColor(
                      const [
                        AvatarFrame.gold,
                        AvatarFrame.silver,
                        AvatarFrame.bronze,
                      ][place],
                    ),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: PlayerAvatar(
                    radius: _avatarRadius[place],
                    photoUrl: entry.avatarUrl,
                    iconId: entry.avatarIcon,
                    colorHex: entry.avatarColor,
                    frameId: entry.avatarFrame,
                    showcaseTitle: entry.showcaseTitle,
                    displayName: entry.displayName,
                    colorOverride: colorOverride,
                  ),
                ),
              ),
              const SizedBox(height: SahneSpace.x2),
            ],
          ),
        ),
        pedestal,
      ],
    );

    final onReport = this.onReport;
    return Semantics(
      key: ValueKey('leaderboard-rank-row-${entry.rank}'),
      container: true,
      label: label,
      hint: onReport == null ? null : Tr.forKu(K.reportTapHint, isKu),
      button: onReport != null,
      onTap: onReport,
      onLongPress: onReport,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onReport,
        onLongPress: onReport,
        child: column,
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

/// Kaidenin tepesindeki madalya: 44 px degrade disk + koyu rakam.
class _MedalDisc extends StatelessWidget {
  const _MedalDisc({required this.place, required this.rank});

  final int place;
  final int rank;

  static const _colors = [
    (Color(0xFFFFE6A0), Color(0xFFD7A744), Color(0xFF4A3000)),
    (Color(0xFFF1F4F7), Color(0xFFAEB8C2), Color(0xFF26313B)),
    (Color(0xFFF6C9A4), Color(0xFFD08A57), Color(0xFF3D1C06)),
  ];

  @override
  Widget build(BuildContext context) {
    final (top, bottom, ink) = _colors[place.clamp(0, 2)];
    final size = place == 0 ? 48.0 : 42.0;
    return DecoratedBox(
      key: ValueKey('podium-medal-${place + 1}'),
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(color: Color.lerp(bottom, ink, 0.25)!, width: 1.5),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        shadows: [
          BoxShadow(
            color: bottom.withValues(alpha: 0.45),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$rank',
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: SahneType.headline.copyWith(
                color: ink,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
