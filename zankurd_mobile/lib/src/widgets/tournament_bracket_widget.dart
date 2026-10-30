import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../l10n/strings.dart';
import '../models/public_profile.dart';
import '../models/tournament.dart';
import '../utils/player_identity.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_icons.dart';
import 'player_avatar.dart';
import 'sahne/sahne.dart';

/// Eski RPC sıfır puanda bilgi vermez; bilinmeyene "oynamadı" denmez.
String? tournamentSubmissionLabel(
  bool? submitted,
  int score,
  bool ku, {
  bool completed = false,
}) => switch (submitted) {
  true => Tr.forKu(K.cupSubmissionPlayed, ku, {'score': groupThousands(score)}),
  false => Tr.forKu(
    completed ? K.cupSubmissionForfeitNotPlayed : K.cupSubmissionNotPlayed,
    ku,
  ),
  null => null,
};

/// Tur adları SONDAN sayılır: son tur her zaman Final'dir. Tur sayısı
/// şemadan türetilir; 16 oyunculuk varsayım (Son 16 ile başlama) 4 kişilik
/// gerçek turnuvada ilk turu "Son 16" diye yazıyordu.
List<String> tournamentRoundNames(bool ku, int totalRounds) {
  final namesFromFinal = ku
      ? const ['Fînal', 'Nîv-Fînal', 'Çaryeka Fînalê', 'Dawiya 16an']
      : const ['Final', 'Yarı Final', 'Çeyrek Final', 'Son 16'];
  return List.generate(totalRounds, (i) {
    final distanceFromFinal = totalRounds - 1 - i;
    if (distanceFromFinal < namesFromFinal.length) {
      return namesFromFinal[distanceFromFinal];
    }
    return Tr.forKu(K.tournamentRoundGeneric, ku, {'n': groupThousands(i + 1)});
  });
}

/// Dikey, sıkışık turnuva şeması: tur başlığı + o turun maç kartları, turlar
/// üst üste.
///
/// 2026-10-29 gerçek cihaz turu (iPhone 17 Pro, 402×874): eski düzen turları
/// YATAY dizip sabit yükseklikli (264 px) bir kutuya koyuyordu. İkinci yarı
/// final maçı kutunun altında yarım kalıyor, Final sütunu sağ kenardaki
/// solma gradyanının arkasında kayboluyordu; oyuncu şemayı göremiyordu.
/// Dört kişilik şema dar telefonda yatay sığmaz; dikey düzen yükseklikten
/// değil sayfanın kaydırmasından yararlanır, hiçbir turu gizlemez ve yazı
/// ölçeği büyüyünce kendiliğinden uzar (iç kaydırma ya da sabit yükseklik
/// YOK). Bağlantı çizgileri kalktı: tur sırası başlıklardan okunur.
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

  @override
  Widget build(BuildContext context) {
    if (bracket.rounds.isEmpty) return const SizedBox.shrink();

    // Sunucu bir sonraki turun maçlarını ancak kazananlar belli olunca kurar;
    // henüz kurulmamış turlar (ör. yarı finalde Final) BOŞ kartla gösterilir.
    // Yoksa oyuncu şemada final olduğunu hiç görmüyordu (2026-10-29 turu).
    final rounds = [...bracket.rounds];
    final totalRounds = bracket.totalRounds;
    // Kurul 1 (C32, 2026-10-29): bir finalist belli iken Final'in iki tarafı
    // da "Belirsiz" yazıyordu. Önceki turun TAMAMLANMIŞ maçının kazananı
    // yerine yazılır; belli olmayan taraf "n. maçın kazananı" der.
    while (rounds.length < totalRounds) {
      final prev = rounds.last.matches;
      final count = prev.length <= 1 ? 1 : (prev.length + 1) ~/ 2;
      // Kurul 3 D17 (Sol, nesnel): finalist yarı finalde kendi avatarıyla,
      // Final kartında varsayılan avatarla görünüyordu; profil de taşınır.
      ({String id, String name, PublicProfile? profile}) side(int index) {
        if (index >= prev.length) return (id: '', name: 'TBD', profile: null);
        final m = prev[index];
        if (m.status == 'completed' && m.winnerId.isNotEmpty) {
          if (m.winnerId == m.playerOneId) {
            return (
              id: m.playerOneId,
              name: m.playerOneName,
              profile: m.playerOneProfile,
            );
          }
          if (m.winnerId == m.playerTwoId) {
            return (
              id: m.playerTwoId,
              name: m.playerTwoName,
              profile: m.playerTwoProfile,
            );
          }
        }
        return (id: '', name: 'TBD:${index + 1}', profile: null);
      }

      rounds.add(
        TournamentRound(
          roundNumber: rounds.length + 1,
          status: 'pending',
          matches: [
            for (var m = 0; m < count; m++)
              TournamentMatch(
                id: 'placeholder-${rounds.length}-$m',
                playerOneId: side(2 * m).id,
                playerOneName: side(2 * m).name,
                playerTwoId: side(2 * m + 1).id,
                playerTwoName: side(2 * m + 1).name,
                playerOneProfile: side(2 * m).profile,
                playerTwoProfile: side(2 * m + 1).profile,
                playerOneScore: 0,
                playerTwoScore: 0,
                status: 'pending',
                winnerId: '',
              ),
          ],
        ),
      );
    }
    final names = tournamentRoundNames(ku, totalRounds);

    return Column(
      key: const ValueKey('tournament-bracket-vertical'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < totalRounds; i++) ...[
          if (i > 0) const SizedBox(height: SahneSpace.x3),
          _RoundSection(
            round: rounds[i],
            roundName: names[i],
            userId: userId,
            ku: ku,
            isActive: i == bracket.currentRound,
            isCompleted: i < bracket.currentRound,
            onTapMatch: (match) => onTapMatch?.call(match, i),
          ),
        ],
      ],
    );
  }
}

/// Bir tur: başlık rozeti + alt alta maç kartları.
class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.round,
    required this.roundName,
    required this.userId,
    required this.ku,
    required this.isActive,
    required this.isCompleted,
    required this.onTapMatch,
  });

  final TournamentRound round;
  final String roundName;
  final String userId;
  final bool ku;
  final bool isActive;
  final bool isCompleted;
  final void Function(TournamentMatch match) onTapMatch;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Süren tur Zêr tonu, biten tur Kulis, gelecek tur yalnız üçüncül metin.
    final (bg, fg) = isActive
        ? (t.goldTint, t.goldTx)
        : isCompleted
        ? (t.s2, t.tx2)
        : (t.s2, t.tx3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DecoratedBox(
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
          ),
        ),
        for (final match in round.matches)
          Padding(
            padding: const EdgeInsets.only(top: SahneSpace.x2),
            child: _BracketMatchCard(
              match: match,
              userId: userId,
              ku: ku,
              // Henüz kurulmamış (iki oyuncusu da boş) kart dokunulamaz: buton
              // gibi okunup hiçbir şey yapmıyordu.
              // Kurul 1 (C32): bir tarafı tahmin edilmiş yer tutucu da
              // gerçek maç değildir; dokunulamaz.
              onTap:
                  match.id.startsWith('placeholder-') ||
                      (match.playerOneId.isEmpty && match.playerTwoId.isEmpty)
                  ? null
                  : () => onTapMatch(match),
            ),
          ),
      ],
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.match,
    required this.userId,
    required this.ku,
    required this.onTap,
  });

  final TournamentMatch match;
  final String userId;
  final bool ku;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.status == 'completed';
    final hasPlayers =
        match.playerOneId.isNotEmpty && match.playerTwoId.isNotEmpty;
    final isUserMatch =
        match.playerOneId == userId || match.playerTwoId == userId;

    final resultLabel = match.isForfeit
        ? Tr.forKu(K.cupAdvancedByForfeit, ku)
        : match.closedWithoutSubmission
        ? Tr.forKu(K.cupExpiredUnplayed, ku)
        : isCompleted || match.bothSubmitted
        ? '${groupThousands(match.playerOneScore)} – ${groupThousands(match.playerTwoScore)}'
        : hasPlayers && match.deadline?.isBefore(DateTime.now()) == true
        ? Tr.forKu(K.tournamentWaitingOpponentExpired, ku)
        : hasPlayers
        ? Tr.forKu(K.matchAwaitingResultShort, ku)
        : '—';
    final oneLabel = tournamentSubmissionLabel(
      match.hasPlayerOneSubmitted,
      match.playerOneScore,
      ku,
      completed: isCompleted,
    );
    final twoLabel = tournamentSubmissionLabel(
      match.hasPlayerTwoSubmitted,
      match.playerTwoScore,
      ku,
      completed: isCompleted,
    );
    final t = SahneTokens.of(context);
    final p1Won = isCompleted && match.winnerId == match.playerOneId;
    final p2Won = isCompleted && match.winnerId == match.playerTwoId;

    final semanticsLabel = Tr.forKu(K.matchSemantics, ku, {
      'one': [
        match.playerOneName,
        if (match.playerOneId == userId) Tr.forKu(K.you, ku),
        ?oneLabel,
      ].join(', '),
      'two': [
        match.playerTwoName,
        if (match.playerTwoId == userId) Tr.forKu(K.you, ku),
        ?twoLabel,
      ].join(', '),
    });
    return Semantics(
      button: onTap != null,
      label: '$semanticsLabel, $resultLabel',
      // 2026-07-23 canlı UX denetimi: _PlayerSlot içindeki oyuncu adı
      // Text'leri ayrıca kendi semantics düğümünü ekleyip çift okumaya
      // yol açıyordu (M28 devamı).
      excludeSemantics: true,
      // İç dokunuş dışlandı; ekran okuyucu eylemi buradan alır.
      onTap: onTap,
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
                profile: match.playerOneProfile,
                submissionLabel: oneLabel,
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
                              resultLabel,
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
                profile: match.playerTwoProfile,
                submissionLabel: twoLabel,
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
    this.submissionLabel,
    required this.isWinner,
    this.profile,
    required this.isUser,
    required this.isCompleted,
    required this.ku,
  });

  final String name;
  final String playerId;

  /// Gerçek turnuvada oyuncunun herkese açık kimliği; yoksa (bot/yerel)
  /// kimlikten türetilen simge ve renk çizilir.
  final PublicProfile? profile;
  final String? submissionLabel;
  final bool isWinner;
  final bool isUser;
  final bool isCompleted;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final placeholder = Tr.forKu(K.unknownPlayer, ku);
    final winnerOf = name.startsWith('TBD:')
        ? Tr.forKu(K.bracketWinnerOf, ku).replaceAll('{n}', name.substring(4))
        : null;
    final displayName =
        winnerOf ??
        (name == 'TBD' || name.isEmpty
            ? placeholder
            : PlayerIdentity.resolveNameWithTag(
                profile?.displayName ?? name,
                isKu: ku,
                tag: profile?.playerTag,
              ));
    final isDimmed = isCompleted && !isWinner;
    final hasPlayer = name.isNotEmpty && !name.startsWith('TBD');

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
              profile != null
                  ? PlayerAvatar.fromIdentity(
                      radius: 12,
                      identity: profile!.avatar,
                      displayName: profile!.displayName ?? name,
                    )
                  : PlayerAvatar(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
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
                                decoration: isDimmed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: t.tx3,
                              ),
                        ),
                      ),
                      if (isUser)
                        Text(
                          ' (${Tr.forKu(K.you, ku)})',
                          style: SahneType.captionStrong.copyWith(
                            color: t.goldTx,
                          ),
                        ),
                    ],
                  ),
                  if (playerId.isNotEmpty && submissionLabel != null)
                    Text(
                      submissionLabel!,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                ],
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
