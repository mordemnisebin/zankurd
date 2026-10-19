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

    final String title;
    final String subtitle;
    if (hasIncoming) {
      title = incomingCount == 1
          ? context.t(K.challengeYourTurn)
          : '${context.t(K.challengeYourTurn)} · $incomingCount';
      final inviter = _incoming.first.opponentName;
      if (incomingCount == 1 && inviter != null) {
        subtitle = context.t(K.challengeIncomingBy, {
          'name': context.playerDisplayName(inviter),
        });
      } else if (readyCount > 0) {
        subtitle = '${context.t(K.asyncDuelReady)} · $readyCount';
      } else {
        subtitle = context.t(K.asyncDuelInbox);
      }
    } else if (pending) {
      title = readyCount == 1
          ? context.t(K.asyncDuelReady)
          : '${context.t(K.asyncDuelReady)} · $readyCount';
      final opponent = _ready.first.opponentName;
      subtitle = readyCount == 1 && opponent != null
          ? context.playerDisplayName(opponent)
          : context.t(K.asyncDuelInbox);
    } else {
      title = context.t(K.asyncDuel);
      subtitle = context.t(K.asyncDuelSub);
    }

    // Sağdaki TEK ikincil düğme. Bekleyen bir şey varsa (sıra sende, sonuç
    // hazır) düğme o eylemi yapar; yoksa menüyü açar. Bekleyen durumda
    // menü, düğmenin yanındaki ⋯ ile de erişilir: işlev kaybı yok.
    final String buttonLabel;
    final IconData buttonIcon;
    final VoidCallback buttonAction;
    if (hasIncoming) {
      buttonLabel = incomingCount == 1
          ? context.t(K.challengePlay)
          : context.t(K.asyncDuelInbox);
      buttonIcon = AppIcons.hourglass;
      buttonAction = _openIncoming;
    } else if (pending) {
      buttonLabel = readyCount == 1
          ? context.t(K.resultTitle)
          : context.t(K.asyncDuelInbox);
      buttonIcon = AppIcons.trophy;
      buttonAction = _openReady;
    } else {
      buttonLabel = context.t(K.challengePlay);
      buttonIcon = AppIcons.hourglass;
      buttonAction = _openMenu;
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
        label: '$title. $subtitle',
        child: SahneSurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x4,
            vertical: SahneSpace.x3,
          ),
          child: Builder(
            builder: (context) {
              final t = SahneTokens.of(context);
              final texts = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: SahneType.bodyStrong.copyWith(
                        color: pending ? t.raceTx : t.tx,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    key: const ValueKey('home-duel-meta'),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              );
              final button = SahneButton.secondary(
                key: const ValueKey('home-duel-primary'),
                icon: buttonIcon,
                label: buttonLabel,
                onPressed: buttonAction,
              );
              // Menü yalnız bekleyen durumda ayrı bir ⋯ düğmesidir;
              // varsayılan durumda düğmenin kendisi menüyü açar.
              final more = pending
                  ? SahneIconButton(
                      key: const ValueKey('home-duel-more'),
                      icon: AppIcons.ellipsis,
                      semanticLabel: context.t(K.moreOptions),
                      onPressed: _openMenu,
                    )
                  : null;
              return LayoutBuilder(
                builder: (context, c) {
                  // Dar ekran ya da büyük yazıda düğme metnin altına iner.
                  final stacked =
                      c.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) >= 24;
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?more,
                      if (more != null) const SizedBox(width: SahneSpace.x1),
                      Flexible(child: button),
                    ],
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        texts,
                        const SizedBox(height: SahneSpace.x3),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: actions,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: texts),
                      const SizedBox(width: SahneSpace.x3),
                      actions,
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Düello menüsü: Yeni düello / Arkadaşına meydan oku / Hızlı düello.
  /// Eski kartın üç yolu burada toplanır; hedefleri değişmedi.
  void _openMenu() {
    unawaited(
      // Kurul 3. tur (2026-10-20): ortak alt sayfa kabuğu.
      showSahneSheet<void>(
        context: context,
        title: context.t(K.asyncDuel),
        builder: (sheetContext) {
          void go(VoidCallback action) {
            Navigator.of(sheetContext).pop();
            action();
          }

          return Column(
            key: const ValueKey('home-duel-menu'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SahneListGroup(
                children: [
                  SahneListRow.icon(
                    key: const ValueKey('home-duel-new'),
                    icon: AppIcons.hourglass,
                    role: SahneRole.race,
                    title: context.t(K.asyncDuelNew),
                    subtitle: context.t(K.asyncDuelSub),
                    chevron: true,
                    onTap: () => go(_openNewDuel),
                  ),
                  if (_challengeAvailable)
                    SahneListRow.icon(
                      key: const ValueKey('home-duel-challenge'),
                      icon: AppIcons.peopleGroup,
                      role: SahneRole.race,
                      title: context.t(K.challengeEntry),
                      subtitle: context.t(K.challengeEntrySub),
                      chevron: true,
                      onTap: () => go(_openChallengeSheet),
                    ),
                  SahneListRow.icon(
                    key: const ValueKey('home-duel-secondary'),
                    icon: AppIcons.bolt,
                    role: SahneRole.race,
                    title: context.t(K.quickDuel),
                    chevron: true,
                    onTap: () => go(_openQuickDuel),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
