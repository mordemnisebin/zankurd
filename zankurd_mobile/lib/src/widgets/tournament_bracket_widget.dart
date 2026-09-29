import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../l10n/strings.dart';
import '../models/tournament.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_icons.dart';
import 'player_avatar.dart';
import 'sahne/sahne.dart';

/// Visual single-elimination tournament bracket with connecting lines,
/// player avatars, scores, and winner highlighting.
///
/// Supports 8 or 16 player brackets shown across 3-4 rounds.
class TournamentBracketWidget extends StatelessWidget {
  const TournamentBracketWidget({
    required this.bracket,
    required this.userId,
    required this.ku,
    this.onTapMatch,
    super.key,
  });

  final TournamentBracket bracket;
  final String userId;
  final bool ku;
  final void Function(TournamentMatch match, int roundIndex)? onTapMatch;

  List<String> get _roundNames => ku
      ? const ['Dawiya 16an', 'Çaryeka Fînalê', 'Nîv-Fînal', 'Fînal']
      : const ['Son 16', 'Çeyrek Final', 'Yarı Final', 'Final'];

  @override
  Widget build(BuildContext context) {
    if (bracket.rounds.isEmpty) return const SizedBox.shrink();

    final totalRounds = bracket.rounds.length;

    // 2026-07-22 canlı UX denetimi: bracket yatay scroll düzeltmesi
    // IntrinsicHeight kaldırıldı (double-pass layout önlendi),
    // dinamik kart genişliği + sağ kenar fade overlay eklendi.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dinamik kart genişliği: mevcut alanı turlara böl, clamp(120, 160)
        // M-10: connectorWidth 28→20 — dar ekranlarda toplam genişliği azaltır;
        // yatay scroll korunur, kart alanı biraz genişler.
        const connectorWidth = 20.0;
        final totalConnectorWidth = (totalRounds - 1) * connectorWidth;
        final availableForCards = constraints.maxWidth - totalConnectorWidth;
        final cardWidth = (availableForCards / totalRounds).clamp(120.0, 160.0);

        // Minimum yükseklik: ilk turdaki en fazla maç sayısına göre hesapla
        final maxMatches = bracket.rounds.first.matches.length;
        const cardHeight =
            100.0; // tahmini kart yüksekliği (header + 2 oyuncu + padding)
        final minBracketHeight = maxMatches * cardHeight + 64.0;

        return Stack(
          children: [
            // Yatay kaydırılabilir bracket
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: SahneSpace.x3),
              child: SizedBox(
                height: minBracketHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < totalRounds; i++) ...[
                      if (i > 0)
                        _ConnectorColumn(
                          roundIndex: i,
                          roundCount: totalRounds,
                          bracketHeight: minBracketHeight,
                        ),
                      _RoundColumn(
                        round: bracket.rounds[i],
                        roundName: _roundNames[i],
                        userId: userId,
                        ku: ku,
                        isActive: i == bracket.currentRound,
                        isCompleted: i < bracket.currentRound,
                        matchCount: bracket.rounds[i].matches.length,
                        cardWidth: cardWidth,
                        bracketHeight: minBracketHeight,
                        onTapMatch: (match) => onTapMatch?.call(match, i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 2026-07-22 canlı UX denetimi: yatay scroll ipucu — sağ kenar gradyanı
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 32,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        SahneTokens.of(context).bg.withValues(alpha: 0),
                        SahneTokens.of(context).bg,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Vertical column for one round showing all match cards.
class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.round,
    required this.roundName,
    required this.userId,
    required this.ku,
    required this.isActive,
    required this.isCompleted,
    required this.matchCount,
    required this.cardWidth,
    required this.bracketHeight,
    required this.onTapMatch,
  });

  final TournamentRound round;
  final String roundName;
  final String userId;
  final bool ku;
  final bool isActive;
  final bool isCompleted;
  final int matchCount;
  final double cardWidth;
  final double bracketHeight;
  final void Function(TournamentMatch match) onTapMatch;

  @override
  Widget build(BuildContext context) {
    final spacingFactor = matchCount <= 2 ? 3.0 : (matchCount <= 4 ? 1.5 : 0.7);

    return SizedBox(
      height: bracketHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Round header — 2026-09-29 Şahnê: S pahlı rozet; süren tur Zêr
          // tonu, biten tur Kulis, gelecek tur yalnız üçüncül metin.
          Builder(
            builder: (context) {
              final t = SahneTokens.of(context);
              final (bg, fg) = isActive
                  ? (t.goldTint, t.goldTx)
                  : isCompleted
                  ? (t.s2, t.tx2)
                  : (Colors.transparent, t.tx3);
              return DecoratedBox(
                decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SahneSpace.x2,
                    vertical: SahneSpace.x1,
                  ),
                  child: Text(
                    roundName,
                    style: SahneType.captionStrong.copyWith(color: fg),
                  ),
                ),
              );
            },
          ),
          // Match cards below header — scrollable to handle varying content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: spacingFactor * 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final match in round.matches)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: spacingFactor * 4,
                      ),
                      child: _BracketMatchCard(
                        match: match,
                        userId: userId,
                        ku: ku,
                        cardWidth: cardWidth,
                        onTap: () => onTapMatch(match),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connector lines between rounds showing the bracket links.
class _ConnectorColumn extends StatelessWidget {
  const _ConnectorColumn({
    required this.roundIndex,
    required this.roundCount,
    required this.bracketHeight,
  });

  final int roundIndex;
  final int roundCount;
  final double bracketHeight;

  @override
  Widget build(BuildContext context) {
    // 2026-07-22 canlı UX denetimi: bracketHeight doğrudan kullanılıyor
    // (IntrinsicHeight + double.infinity kaldırıldı)
    return SizedBox(
      width: 28,
      height: bracketHeight,
      child: CustomPaint(
        size: Size(28, bracketHeight),
        painter: _ConnectorPainter(
          roundIndex: roundIndex,
          roundCount: roundCount,
          color: SahneTokens.of(context).line,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.roundIndex,
    required this.roundCount,
    required this.color,
  });

  final int roundIndex;
  final int roundCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final matchCountPrev = 16 >> roundIndex; // 16, 8, 4, 2
    final matchCountCurr = 16 >> (roundIndex + 1); // 8, 4, 2, 1

    if (matchCountPrev <= 0 || matchCountCurr <= 0) return;

    // Draw horizontal connecting lines
    final rowHeight = size.height / matchCountPrev;

    for (int i = 0; i < matchCountCurr; i++) {
      final topY = (i * 2) * rowHeight + rowHeight / 2;
      final bottomY = (i * 2 + 1) * rowHeight + rowHeight / 2;
      final midY = (topY + bottomY) / 2;
      final midX = size.width / 2;

      // Vertical line connecting top and bottom match outputs
      canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);

      // Horizontal lines from edges to vertical
      canvas.drawLine(Offset(0, topY), Offset(midX, topY), paint);
      canvas.drawLine(Offset(0, bottomY), Offset(midX, bottomY), paint);

      // Horizontal line from vertical to next round
      canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single match card in the bracket with player avatars, names, scores,
/// and winner gold highlight.
class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.match,
    required this.userId,
    required this.ku,
    required this.cardWidth,
    required this.onTap,
  });

  final TournamentMatch match;
  final String userId;
  final bool ku;
  final double cardWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.status == 'completed';
    final hasPlayers =
        match.playerOneId.isNotEmpty && match.playerTwoId.isNotEmpty;
    final isUserMatch =
        match.playerOneId == userId || match.playerTwoId == userId;

    final t = SahneTokens.of(context);
    final p1Won = isCompleted && match.winnerId == match.playerOneId;
    final p2Won = isCompleted && match.winnerId == match.playerTwoId;

    return Semantics(
      button: true,
      label: Tr.forKu(K.matchSemantics, ku, {
        'one': match.playerOneName,
        'two': match.playerTwoName,
      }),
      // 2026-07-23 canlı UX denetimi: _PlayerSlot içindeki oyuncu adı
      // Text'leri ayrıca kendi semantics düğümünü ekleyip çift okumaya
      // yol açıyordu (M28 devamı).
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // 350 ms kenarlık/gölge geçişi süsüdür. Tercih açıkken kart
        // anında durur; yoksa şemadaki her maç ayarı yok saymış olur —
        // çevrimdışı şerit (`OfflineBanner`) aynı kapıdan geçiyor.
        child: AnimatedContainer(
          duration: ReducedMotionProvider.isReducedIn(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          width: cardWidth,
          padding: const EdgeInsets.all(SahneSpace.x1),
          // 2026-09-29 Şahnê: maç kartı yüzeydir (Perde, M pah); kullanıcının
          // maçı Halka 2 Zêr ("Sen" altındır), biten maç gündüz kenarı.
          // Bulanık gölge yok.
          decoration: ShapeDecoration(
            color: t.s1,
            shape: SahneShape.withSide(
              SahneShape.m,
              isUserMatch ? t.goldTx : t.edge,
              width: isUserMatch ? SahneRing.r2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayerSlot(
                name: match.playerOneName,
                playerId: match.playerOneId,
                score: match.playerOneScore,
                isWinner: p1Won,
                isUser: match.playerOneId == userId,
                isCompleted: isCompleted,
                ku: ku,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SahneSpace.x1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // `Spacer` YOK: iki yanında birer Spacer varken esnek
                    // çip satırın yalnız üçte birini alıyor ve skor
                    // okunamayacak kadar küçülüyordu. `center` hizası
                    // zaten ortalar.
                    // Esnek olmalı: "340 – 280" %200 yazıda 120 piksellik
                    // karta sığmıyor ve satırı 16 piksel taşırıyordu.
                    // Skor kısaltılamaz (kısaltılmış skor yanlış bilgi),
                    // o yüzden çip esner ve metin gerekince küçülür.
                    Flexible(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: isCompleted ? t.goldTint : t.s2,
                          shape: SahneShape.s,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SahneSpace.x2,
                          ),
                          // Maç bittiyse SKORLAR burada durur.
                          //
                          // Skor eskiden hiçbir yerde görünmüyordu: oyuncu
                          // satırındaki dal yalnız maç tamamlanmamışken
                          // çalışıyordu ve skor ancak tamamlandıktan sonra
                          // oluşuyor. Skoru oyuncu satırına koymayı denedik;
                          // dar kartta adı yiyordu ("R…", "Şi…") ve ad
                          // oyuncunun kimliğidir. Ortadaki çip zaten iki
                          // satırın arasında ve tam da sonucun yeri
                          // (2026-08-04).
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isCompleted
                                  ? '${match.playerOneScore} – ${match.playerTwoScore}'
                                  : hasPlayers
                                  ? 'VS'
                                  : '—',
                              maxLines: 1,
                              softWrap: false,
                              style: SahneType.captionStrong.copyWith(
                                color: isCompleted ? t.goldTx : t.tx2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _PlayerSlot(
                name: match.playerTwoName,
                playerId: match.playerTwoId,
                score: match.playerTwoScore,
                isWinner: p2Won,
                isUser: match.playerTwoId == userId,
                isCompleted: isCompleted,
                ku: ku,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual player row inside a bracket match card.
class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.name,
    required this.playerId,
    required this.score,
    required this.isWinner,
    required this.isUser,
    required this.isCompleted,
    required this.ku,
  });

  final String name;
  final String playerId;
  final int score;
  final bool isWinner;
  final bool isUser;
  final bool isCompleted;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final placeholder = Tr.forKu(K.unknownPlayer, ku);
    final displayName = name == 'TBD' || name.isEmpty ? placeholder : name;
    final isDimmed = isCompleted && !isWinner;
    final hasPlayer = name.isNotEmpty && name != 'TBD';

    // 2026-09-29 Şahnê: kazanan satırı Zêr tonu + Halka 1 altın, adı Zêr
    // metni + kupa; kaybeden üçüncül metin, üstü çizili + ✗ (yalnız renkle
    // değil). Kullanıcının adı kalın. Avatar elmas.
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isWinner ? t.goldTint : Colors.transparent,
        shape: isWinner
            ? SahneShape.withSide(SahneShape.s, t.gold, width: SahneRing.r1)
            : SahneShape.s,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x1,
          vertical: SahneSpace.x1,
        ),
        child: Row(
          children: [
            // Player avatar
            if (hasPlayer)
              PlayerAvatar(
                radius: 12,
                displayName: displayName,
                iconId: _playerIconId(playerId),
                colorHex: _playerColorHex(playerId),
              )
            else
              SahneDiamondAvatar(
                size: 24,
                icon: AppIcons.user,
                foreground: t.tx3,
              ),
            const SizedBox(width: SahneSpace.x2),
            // Player name
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (isUser ? SahneType.captionStrong : SahneType.caption)
                    .copyWith(
                      // Ham altın, kartın altın tonlu zemininde karanlık
                      // temada kayboluyordu: kazananın adı hiç görünmüyordu
                      // (2026-08-04). Şahnê: Zêr metni (`goldTx`).
                      color: isWinner
                          ? t.goldTx
                          : isDimmed
                          ? t.tx3
                          : t.tx,
                      decoration: isDimmed ? TextDecoration.lineThrough : null,
                      decorationColor: t.tx3,
                    ),
              ),
            ),
            // Maç bittiyse kazanan kupayı, kaybeden çarpıyı alır: kazanan/
            // kaybeden yalnız renkle anlatılmaz (2026-08-04).
            if (isWinner)
              Icon(AppIcons.trophy, size: 16, color: t.goldTx)
            else if (isCompleted && hasPlayer)
              Icon(AppIcons.circleXmark, size: 16, color: t.tx3),
          ],
        ),
      ),
    );
  }
}

/// Deterministic icon selection for bot players based on playerId.
String? _playerIconId(String playerId) {
  if (playerId.isEmpty || playerId == 'TBD') return null;
  const icons = [
    'tembur',
    'dengbej',
    'ciya',
    'roj',
    'pirtuk',
    'newroz',
    'ster',
    'pen',
    'cihan',
    'mertal',
    'tac',
    'gul',
    'dar',
    'cav',
    'birusk',
    'kupa',
  ];
  final hash = playerId.hashCode.abs();
  return icons[hash % icons.length];
}

/// Oyuncu kimliğine bağlı deterministik avatar rengi.
///
/// Eskiden burada 16 hex'lik KENDİ listesi vardı ve hepsi jenerik
/// Tailwind tonlarıydı (`#7C3AED` violet-600, `#2563EB` blue-600,
/// `#10B981` emerald-500, `#EC4899` pink-500 …). `avatar_presets.dart`
/// tam da bunu reddediyor: "Marka ailesinden — jenerik Tailwind tonları
/// yerine kategori paletiyle aynı kimlik." Karar orada verilmiş ama
/// turnuva bracket'i kendi listesini tutmaya devam etmişti, yani aynı
/// oyuncu profil ekranında marka tonu, bracket'te Tailwind moru
/// görünüyordu (2026-08-01, canlı turnuva ekranı).
///
/// `avatarNamePalette` zaten isim/kimlik hash'i için tasarlanmış 12 marka
/// tonu tutuyor ve beyaz harfle okunur doygunlukta seçilmiş.
String? _playerColorHex(String playerId) {
  if (playerId.isEmpty || playerId == 'TBD') return null;
  final color =
      avatarNamePalette[playerId.hashCode.abs() % avatarNamePalette.length];
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
