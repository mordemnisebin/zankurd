import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../providers/remote_availability.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../utils/player_identity.dart';
import '../../widgets/sahne/sahne.dart';
import '../async_duel/async_duel_challenge_sheet.dart';
import '../async_duel/async_duel_inbox.dart';
import '../async_duel/async_duel_play_screen.dart';
import '../async_duel/async_duel_result_screen.dart';
import '../matchmaking_screen.dart';

/// Ana ekranın düello kartı: "Günün dersi"nin hemen altında, öğrenme
/// ekranının ikinci yüzünü (yarış) gösterir.
///
/// ## Niçin var
///
/// 2026-10-13 sunucu verisi: kurulumdan sonraki hafta neredeyse kimse geri
/// gelmiyordu (436 hesabın 413'ü misafir). Ürünün tek rakipsiz yüzü olan
/// sırayla düello yalnız Yarış sekmesindeydi; Ana ekran yalnız öğrenmeyi
/// gösteriyordu. Sonucu hazır bir düello dönüş sebebidir; kart onu ilk
/// ekrana taşır.
///
/// ## İki durum
///
/// * Varsayılan: sırayla düello vaadi ("sen şimdi oyna, rakibin sonra") ve
///   iki yol — "Yeni düello" ([AsyncDuelPlayScreen], Yarış sekmesindeki
///   "Sırayla düello" satırıyla AYNI hedef) ve sakin metin düğmesi "Hızlı
///   düello" ([MatchmakingScreen], Yarış sekmesinin "Rakip bul"uyla aynı).
/// * Sonuç hazır: rakibi bitirmiş, benim henüz görmediğim düelloların sayısı
///   (`outcome != null && !seen` — "Düellolarım" kutusunun okunmamış
///   rozetiyle aynı kural). Kart sayıyla açılır; tek düelloysa doğrudan
///   sonucu, birden çoksa tam listeyi açar.
///
/// ## Üçüncü durum: "Sıra sende" (2026-10-13)
///
/// Rastgele düelloda "sıra sende" diye bir durum yoktur (oyuncu 7 soruyu
/// hemen oynar, bekleyen rakiptir). Arkadaşa meydan okuma bunu GERÇEK
/// yapar: bir arkadaş turunu bitirip beni davet ettiyse (`incomingChallenge`)
/// kart "Sıra sende" ile açılır ve "Oyna" hemen kabul edip oyuna sokar.
/// "Sıra sende" "Sonuç hazır"dan önce gelir (bekleyen hamle, bitmiş
/// sonuçtan önemli); ikisi birlikteyse ikincisi alt satırda sayıyla anılır.
///
/// Kartta ayrıca sakin bir "Arkadaşına meydan oku" metin düğmesi vardır
/// (seçim sayfası: bağlantı / arkadaş). Sunucuda meydan okuma RPC'leri
/// yoksa düğme çizilmez ([asyncDuelChallengeAvailable]).
///
/// ## Ucuzluk
///
/// Sayı `loadMyAsyncDuels` ile YALNIZ kart açılırken, Ana sayfa tazeleme
/// sinyalinde ([refreshToken] değişince) ve kartın kendi açtığı ekrandan
/// dönünce çekilir; yoklama döngüsü yoktur. Hata ya da yükleme sürerken
/// varsayılan durum görünür (sayı uydurulmaz).
///
/// ## Renk
///
/// Rol Boyax (yarış); düğmeler ikincil/metin — Agir dolgu yalnız "Günün
/// dersi" düğmesindedir (ekranda tek birincil eylem).
///
/// Bayrak kapalıyken ([kAsyncDuelEnabled]) ya da sunucuya ulaşılamıyorken
/// ([RemoteAvailability.socialLocked]) kart çizilmez: ölü düğme yerine yok.
class HomeDuelCard extends StatefulWidget {
  const HomeDuelCard({
    required this.repository,
    this.refreshToken = 0,
    this.asyncDuelEnabled = kAsyncDuelEnabled,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Değiştiğinde sayı yeniden çekilir (Ana sayfanın tazeleme sayacı).
  final int refreshToken;

  /// Testler ve ekran turu bayrağı kapalıyken de açabilsin diye parametre
  /// (bkz. `PlayHubScreen.asyncDuelEnabled`).
  final bool asyncDuelEnabled;

  @override
  State<HomeDuelCard> createState() => _HomeDuelCardState();
}

class _HomeDuelCardState extends State<HomeDuelCard> {
  /// Sonucu hazır (rakip bitirmiş, ben görmemişim) düellolar. Yüklenene dek
  /// ya da hatada boş: kart varsayılan durumda kalır.
  List<AsyncDuelSummary> _ready = const [];

  /// Bana gelen, kabul etmediğim arkadaş meydan okumaları ("Sıra sende").
  List<AsyncDuelSummary> _incoming = const [];

  /// Meydan okuma RPC'leri sunucuda var mı; belli olana dek gizli.
  bool _challengeAvailable = false;

  /// Üst üste gelen çekimlerde yalnız en son yanıt yazılır.
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.asyncDuelEnabled) {
      unawaited(
        asyncDuelChallengeAvailable(widget.repository).then((available) {
          if (mounted && available) setState(() => _challengeAvailable = true);
        }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant HomeDuelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) unawaited(_load());
  }

  Future<void> _load() async {
    if (!widget.asyncDuelEnabled) return;
    // Sunucuya ulaşılamıyorken çekim boşuna hata kaydı üretirdi.
    if (RemoteAvailability.read(context)?.socialLocked ?? false) return;
    final epoch = ++_epoch;
    try {
      final all = await widget.repository.loadMyAsyncDuels();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _incoming = [
          for (final s in all)
            if (s.incomingChallenge && s.challengeCode != null) s,
        ];
        _ready = [
          for (final s in all)
            if (s.outcome != null && !s.seen) s,
        ];
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_duel_card_load');
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _ready = const [];
        _incoming = const [];
      });
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(AppRoute.to(page));
    if (mounted) unawaited(_load());
  }

  void _openNewDuel() =>
      unawaited(_push(AsyncDuelPlayScreen(repository: widget.repository)));

  void _openQuickDuel() =>
      unawaited(_push(MatchmakingScreen(repository: widget.repository)));

  void _openChallengeSheet() => unawaited(
    showAsyncDuelChallengeSheet(
      context,
      widget.repository,
    ).then((_) => mounted ? _load() : null),
  );

  void _openIncoming() {
    if (_incoming.length == 1) {
      unawaited(
        _push(
          AsyncDuelPlayScreen(
            repository: widget.repository,
            entry: AsyncDuelEntry.acceptChallenge(
              _incoming.single.challengeCode!,
            ),
          ),
        ),
      );
    } else {
      unawaited(_push(AsyncDuelListScreen(repository: widget.repository)));
    }
  }

  void _openReady() {
    if (_ready.length == 1) {
      unawaited(
        _push(
          AsyncDuelResultScreen(
            repository: widget.repository,
            view: AsyncDuelResultView.fromSummary(_ready.single),
          ),
        ),
      );
    } else {
      unawaited(_push(AsyncDuelListScreen(repository: widget.repository)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.asyncDuelEnabled ||
        RemoteAvailability.socialLockedWatch(context)) {
      return const SizedBox.shrink();
    }
    final readyCount = _ready.length;
    final incomingCount = _incoming.length;
    final hasIncoming = incomingCount > 0;
    final pending = readyCount > 0 || hasIncoming;

    final String eyebrow;
    final String headline;
    final String? meta;
    if (hasIncoming) {
      eyebrow = context.t(K.asyncDuelInbox);
      headline = incomingCount == 1
          ? context.t(K.challengeYourTurn)
          : '${context.t(K.challengeYourTurn)} · $incomingCount';
      final inviter = _incoming.first.opponentName;
      if (incomingCount == 1 && inviter != null) {
        meta = context.t(K.challengeIncomingBy, {
          'name': context.playerDisplayName(inviter),
        });
      } else if (readyCount > 0) {
        meta = '${context.t(K.asyncDuelReady)} · $readyCount';
      } else {
        meta = null;
      }
    } else if (pending) {
      eyebrow = context.t(K.asyncDuelInbox);
      headline = readyCount == 1
          ? context.t(K.asyncDuelReady)
          : '${context.t(K.asyncDuelReady)} · $readyCount';
      final opponent = _ready.first.opponentName;
      meta = readyCount == 1 && opponent != null
          ? context.playerDisplayName(opponent)
          : null;
    } else {
      eyebrow = context.t(K.asyncDuel);
      headline = context.t(K.asyncDuelSub);
      meta = null;
    }

    return Padding(
      key: ValueKey(
        hasIncoming
            ? 'home-duel-card-your-turn'
            : pending
            ? 'home-duel-card-ready'
            : 'home-duel-card',
      ),
      padding: const EdgeInsets.only(top: SahneSpace.cardGap),
      child: Semantics(
        container: true,
        label: '$eyebrow. $headline',
        child: SahneStageCard(
          role: SahneRole.race,
          child: Builder(
            builder: (context) {
              final t = SahneTokens.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    eyebrow,
                    style: SahneType.captionStrong.copyWith(
                      color: SahneStageColors.raceSoft,
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Semantics(
                    header: true,
                    child: Text(
                      headline,
                      style: SahneType.headline.copyWith(color: t.tx),
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: SahneSpace.x1),
                    Text(
                      meta,
                      key: const ValueKey('home-duel-meta'),
                      style: SahneType.caption.copyWith(
                        color: SahneStageColors.raceSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: SahneSpace.x4),
                  if (hasIncoming)
                    SahneButton.secondary(
                      key: const ValueKey('home-duel-primary'),
                      icon: AppIcons.hourglass,
                      label: incomingCount == 1
                          ? context.t(K.challengePlay)
                          : context.t(K.asyncDuelInbox),
                      expand: true,
                      onPressed: _openIncoming,
                    )
                  else if (pending)
                    SahneButton.secondary(
                      key: const ValueKey('home-duel-primary'),
                      icon: AppIcons.trophy,
                      label: readyCount == 1
                          ? context.t(K.resultTitle)
                          : context.t(K.asyncDuelInbox),
                      expand: true,
                      onPressed: _openReady,
                    )
                  else
                    SahneButton.secondary(
                      key: const ValueKey('home-duel-primary'),
                      icon: AppIcons.hourglass,
                      label: context.t(K.asyncDuelNew),
                      expand: true,
                      onPressed: _openNewDuel,
                    ),
                  // İkincil eylemler sakin metin düğmeleri (Agir dolgu
                  // yalnız "Günün dersi"nde). Dar ekranda ve büyük yazıda
                  // alt satıra sarar.
                  Wrap(
                    alignment: _challengeAvailable
                        ? WrapAlignment.spaceBetween
                        : WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_challengeAvailable)
                        SahneButton.text(
                          key: const ValueKey('home-duel-challenge'),
                          label: context.t(K.challengeEntry),
                          arrow: false,
                          onPressed: _openChallengeSheet,
                        ),
                      if (pending)
                        SahneButton.text(
                          key: const ValueKey('home-duel-secondary'),
                          label: context.t(K.asyncDuelNew),
                          onPressed: _openNewDuel,
                        )
                      else
                        SahneButton.text(
                          key: const ValueKey('home-duel-secondary'),
                          label: context.t(K.quickDuel),
                          onPressed: _openQuickDuel,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
