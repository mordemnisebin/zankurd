import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/player_identity.dart';
import '../../widgets/app_state.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/sahne/sahne.dart';
import '../../widgets/zk_back_button.dart';
import 'async_duel_nudge_button.dart';
import 'async_duel_play_screen.dart';
import 'async_duel_result_screen.dart';
import 'async_duel_time.dart';

/// "Sıra sende" satırları (gelen meydan okuma + yarım kalan turum) listenin
/// BAŞINDA ve en YAKIN bitişten başlayarak: bekleyen bir hamle, bitmiş
/// sonuçlardan önce görülmeli; süresi en az kalan en üstte. Bitişi bilinmeyen
/// (eski sunucu) satırlar bu grubun sonuna, sunucu sırasıyla düşer. Kalan
/// satırlar sunucunun (yeniden eskiye) sırasındadır.
List<AsyncDuelSummary> asyncDuelInboxOrder(List<AsyncDuelSummary> items) {
  final turn = <MapEntry<int, AsyncDuelSummary>>[
    for (var i = 0; i < items.length; i++)
      if (items[i].isMyTurn) MapEntry(i, items[i]),
  ];
  // List.sort kararlı değildir: eşit bitişte sunucu sırası dizinle korunur.
  turn.sort((a, b) {
    final ea = a.value.expiresAt;
    final eb = b.value.expiresAt;
    if (ea != null && eb != null) {
      final byExpiry = ea.compareTo(eb);
      if (byExpiry != 0) return byExpiry;
    } else if (ea != null) {
      return -1;
    } else if (eb != null) {
      return 1;
    }
    return a.key.compareTo(b.key);
  });
  return [for (final e in turn) e.value, ...items.where((s) => !s.isMyTurn)];
}

/// Oyuncunun HEMEN yapacağı bir şey var mı: "Sıra sende" (gelen meydan okuma
/// ya da yarım kalan turum) ya da sonucu hazır, görülmemiş düello. Yarış
/// sekmesinde bu satırlar kahramanın ÜSTÜNDE durur; "Düellolarım" kutusu
/// onları tekrarlamaz.
bool asyncDuelNeedsAttention(AsyncDuelSummary s) =>
    s.isMyTurn || (s.outcome != null && !s.seen);

/// Bir gelen kutusu satırına dokunma: gelen meydan okumayı kabul edip oyna,
/// diğerlerinde sonucu aç. Dönüşte çağıran listeyi tazeler.
Future<void> openAsyncDuelSummary(
  BuildContext context,
  ZanKurdRepository repository,
  AsyncDuelSummary summary,
) async {
  final code = summary.challengeCode;
  final Widget page;
  if (summary.incomingChallenge && code != null) {
    page = AsyncDuelPlayScreen(
      repository: repository,
      entry: AsyncDuelEntry.acceptChallenge(code),
    );
  } else if (summary.canResume) {
    // Yarım kalan tur: ölü bir "Yarım kaldı" sonucu yerine kaldığı sorudan
    // devam edilir.
    page = AsyncDuelPlayScreen(
      repository: repository,
      entry: AsyncDuelEntry.resume(summary.duelId),
    );
  } else {
    page = AsyncDuelResultScreen(
      repository: repository,
      view: AsyncDuelResultView.fromSummary(summary),
    );
  }
  await Navigator.of(context).push(AppRoute.to(page));
}

/// Play Hub'daki "Düellolarım" kutusu — en çok [maxRows] satır, daha
/// fazlası varsa tam listeye giden bir "Hemû" düğmesi.
///
/// [refreshSignal] her tetiklendiğinde liste yeniden çekilir (kabuk bunu
/// Yarış sekmesine dönülünce yapar). Yeniden çekerken ESKİ satırlar ekranda
/// kalır: sekmeye her dönüşte satırların yerini bir yükleme çarkının alması
/// sayfayı zıplatırdı. Çark yalnız ilk yüklemede görünür.
class AsyncDuelInboxSection extends StatefulWidget {
  const AsyncDuelInboxSection({
    required this.repository,
    this.refreshSignal,
    this.maxRows = 3,
    this.excludeNeedsAttention = false,
    super.key,
  });

  final ZanKurdRepository repository;
  final Listenable? refreshSignal;
  final int maxRows;

  /// `true` → sırası gelen / sonucu hazır düellolar bu kutuda yer almaz
  /// ([AsyncDuelTurnSection] onları sayfanın üstünde gösterir).
  final bool excludeNeedsAttention;

  @override
  State<AsyncDuelInboxSection> createState() => _AsyncDuelInboxSectionState();
}

class _AsyncDuelInboxSectionState extends State<AsyncDuelInboxSection> {
  List<AsyncDuelSummary>? _items;
  bool _failed = false;

  /// Üst üste gelen yüklemelerde yalnız EN SON isteğin yanıtı yazılır;
  /// geç dönen eski bir yanıt yeni listeyi ezmesin.
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reload);
    unawaited(_fetch());
  }

  @override
  void didUpdateWidget(covariant AsyncDuelInboxSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final epoch = ++_loadEpoch;
    try {
      final items = await widget.repository.loadMyAsyncDuels();
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _items = items;
        _failed = false;
      });
    } catch (_) {
      // Depo hatayı zaten kaydeder (bkz. `loadMyAsyncDuels`); burada yalnız
      // görünüm karar verir. Elde eski liste varsa o kalır.
      if (!mounted || epoch != _loadEpoch) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _openResult(AsyncDuelSummary summary) async {
    await openAsyncDuelSummary(context, widget.repository, summary);
    if (mounted) _reload();
  }

  Future<void> _openSeeAll() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(AsyncDuelListScreen(repository: widget.repository)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final all = asyncDuelInboxOrder(
      (items ?? const <AsyncDuelSummary>[])
          .where(
            (s) =>
                !(widget.excludeNeedsAttention && asyncDuelNeedsAttention(s)),
          )
          .toList(),
    );
    // Okunmamış = sonucu hazır ve görülmemiş VEYA sırası bende olan
    // meydan okuma.
    final unreadCount = all
        .where((s) => s.isMyTurn || (s.outcome != null && !s.seen))
        .length;

    // 2026-09-29 Şahnê: tek bölüm başlığı (`SahneSectionHeader`), satırlar
    // liste grubunda (`SahneListRow`, Boyax yarış karosu). Okunmamış sayı
    // dolu turuncu kutu değil, yarış tonunda rol rozeti: dolu kırmızı/
    // turuncu rozet yok, Agir yalnız birincil eylemdir.
    // 2026-10-19 sadeleşme (ikinci tur): boş kutu ya da ilk yükleme çarkı
    // Yarış sekmesine "henüz hiçbir şey yok" başlığı ekliyordu. Kutu yalnız
    // gösterecek satırı varken (ya da yükleme hatasında, "tekrar dene" için)
    // çizilir; anahtar yine de yerinde durur.
    if ((items == null && !_failed) || (items != null && all.isEmpty)) {
      return const SizedBox.shrink(key: ValueKey('play-hub-async-duel-inbox'));
    }
    return KeyedSubtree(
      key: const ValueKey('play-hub-async-duel-inbox'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SahneSectionHeader(title: context.t(K.asyncDuelInbox)),
              ),
              if (unreadCount > 0)
                Padding(
                  // Başlık satırının (üstü 24, satır 28) ortasına hizalı.
                  padding: const EdgeInsets.only(
                    top: SahneSpace.sectionTop + 2,
                    left: SahneSpace.x2,
                  ),
                  child: _UnreadCountBadge(count: unreadCount),
                ),
            ],
          ),
          if (items == null && !_failed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: SahneSpace.x3),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (items == null)
            _InboxNotice(
              text: context.t(K.asyncDuelLoadFailed),
              action: SahneButton.text(
                label: context.t(K.retry),
                arrow: false,
                onPressed: _reload,
              ),
            )
          else if (all.isEmpty)
            _InboxNotice(text: context.t(K.asyncDuelInboxEmpty))
          else ...[
            SahneListGroup(
              children: [
                for (final summary in all.take(widget.maxRows))
                  _AsyncDuelSummaryRow(
                    key: ValueKey('async-duel-row-${summary.duelId}'),
                    summary: summary,
                    repository: widget.repository,
                    onNudged: _reload,
                    onTap: () => _openResult(summary),
                  ),
              ],
            ),
            if (all.length > widget.maxRows)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SahneButton.text(
                  label: context.t(K.asyncDuelSeeAll),
                  onPressed: _openSeeAll,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Yarış sekmesinin üstündeki "Sıra sende" / "Sonuç hazır" satırları.
///
/// 2026-10-21 iki simülatör turu: sırası gelen düello "Düellolarım"
/// kutusunda, sayfanın en altındaydı; kaydırmayan oyuncu bekleyen hamlesini
/// görmüyordu. Satırlar Hızlı düello kahramanının üstünde (oda daveti
/// kartının altında) durur. Bekleyen yoksa hiçbir şey çizilmez.
class AsyncDuelTurnSection extends StatefulWidget {
  const AsyncDuelTurnSection({
    required this.repository,
    this.refreshSignal,
    this.maxRows = 2,
    super.key,
  });

  final ZanKurdRepository repository;
  final Listenable? refreshSignal;
  final int maxRows;

  @override
  State<AsyncDuelTurnSection> createState() => _AsyncDuelTurnSectionState();
}

class _AsyncDuelTurnSectionState extends State<AsyncDuelTurnSection> {
  List<AsyncDuelSummary> _items = const [];
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reload);
    unawaited(_fetch());
  }

  @override
  void didUpdateWidget(covariant AsyncDuelTurnSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final epoch = ++_epoch;
    try {
      final all = await widget.repository.loadMyAsyncDuels();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _items = asyncDuelInboxOrder(
          all.where(asyncDuelNeedsAttention).toList(),
        );
      });
    } catch (_) {
      // Eski satırlar kalır; "Düellolarım" kutusu hatayı kendisi gösterir.
    }
  }

  Future<void> _open(AsyncDuelSummary summary) async {
    await openAsyncDuelSummary(context, widget.repository, summary);
    if (mounted) _reload();
  }

  Future<void> _openSeeAll() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(AsyncDuelListScreen(repository: widget.repository)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('play-hub-async-duel-turn'));
    }
    // Üst bölüm yalnız [maxRows] satır gösterir; alttaki "Düellolarım" kutusu
    // dikkat isteyenleri dışladığı için üçüncü bekleyen düello hiçbir yerde
    // görünmüyordu (Codex denetimi 2026-10-29). Fazlası varsa "Tümü" bağlantısı.
    final hidden = _items.length - widget.maxRows;
    return Padding(
      key: const ValueKey('play-hub-async-duel-turn'),
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.cardGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SahneListGroup(
            children: [
              for (final summary in _items.take(widget.maxRows))
                _AsyncDuelSummaryRow(
                  key: ValueKey('async-duel-row-${summary.duelId}'),
                  summary: summary,
                  onTap: () => _open(summary),
                ),
            ],
          ),
          if (hidden > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SahneButton.text(
                key: const ValueKey('async-duel-turn-see-all'),
                label:
                    '${context.t(K.asyncDuelSeeAll)} (${groupThousands(_items.length)})',
                arrow: false,
                onPressed: _openSeeAll,
              ),
            ),
        ],
      ),
    );
  }
}

/// Boş ya da yüklenemedi durumu: sakin bir yüzey kartı, ikincil metin ve
/// isteğe bağlı metin bağlantısı (tekrar dene).
class _InboxNotice extends StatelessWidget {
  const _InboxNotice({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x4,
        SahneSpace.x3,
        SahneSpace.x2,
        SahneSpace.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: SahneType.body.copyWith(color: t.tx2)),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SahneBadge(label: groupThousands(count), tone: SahneBadgeTone.race);
  }
}

/// Bir düello özetinin satırı — kutuda ve tam listede ortak.
///
/// Standart liste satırı: Boyax yarış karosu (tamamlanmışta kupa, bekleyende
/// kum saati, yarım/süresi dolmuşta saat), başlık rakip adı ya da durum,
/// alt satır durum ya da oyuncunun skoru; sağda "Sonuç hazır" rozeti ya da
/// chevron.
class _AsyncDuelSummaryRow extends StatelessWidget {
  const _AsyncDuelSummaryRow({
    required this.summary,
    required this.onTap,
    this.repository,
    this.onNudged,
    super.key,
  });

  final AsyncDuelSummary summary;
  final VoidCallback onTap;

  /// Verilirse "Rakip bekleniyor" satırında "Dürt" düğmesi çizilir
  /// ([AsyncDuelSummary.canNudge]); verilmezse satır eskisi gibidir.
  final ZanKurdRepository? repository;

  /// Dürtme gitti ya da sunucu durumu değişti: liste tazelenir.
  final VoidCallback? onNudged;

  @override
  Widget build(BuildContext context) {
    final view = AsyncDuelResultView.fromSummary(summary);
    final statusLabel = asyncDuelStatusLabel(context, view);
    // Rakibi henüz belli olmayan satırda başlık durumun kendisidir
    // ("Rakip bekleniyor"); "Rakip / Rakip bekleniyor" aynı sözü iki kez
    // söylüyordu. Alt satır o zaman oyuncunun kendi skorunu verir.
    final rawOpponent = summary.opponentName;
    final knownOpponent = rawOpponent == null
        ? null
        : context.playerDisplayName(
            rawOpponent,
            tag: summary.opponentProfile?.playerTag,
          );
    final myCorrect = view.myCorrect;
    final invited = summary.invitedName;
    final incoming = summary.incomingChallenge;
    final linkChallenge = summary.isWaitingLinkChallenge;
    final String title;
    final String? subtitle;
    if (incoming) {
      // "Sıra sende": gelen meydan okuma. Başlık eylemin kendisi, alt satır
      // kimin çağırdığı.
      title = context.t(K.challengeYourTurn);
      subtitle = knownOpponent == null
          ? null
          : context.t(K.challengeIncomingBy, {'name': knownOpponent});
    } else if (linkChallenge) {
      // Kimsenin almadığı bağlantı: satıra dokunmak sonuç ekranını
      // (Paylaş'lı) açar.
      title = context.t(K.challengeLinkRow);
      subtitle = myCorrect != null
          ? '${context.t(K.you)} ${groupThousands(myCorrect)}/${groupThousands(view.total)}'
          : null;
    } else if (summary.canResume) {
      // Kurul C30 (3/3): "Yarım kaldı" satırında hangi oyunun yarım kaldığı
      // (oyun türü) yazmıyordu; başlık rakip, alt satır "Sırayla düello ·
      // Yarım kaldı". Tur 3 (2026-10-30): davet edilen ama henüz oynamamış
      // rakipte (invited, knownOpponent yok) önceki dal önce yakalıyordu ve
      // önek yine çıkmıyordu; yarım kalan tur artık her durumda bu daldadır.
      final name =
          knownOpponent ??
          (invited == null
              ? null
              : context.playerDisplayName(
                  invited,
                  tag: summary.invitedProfile?.playerTag,
                ));
      title = name ?? statusLabel;
      subtitle = name != null
          ? '${context.t(K.asyncDuel)} · $statusLabel'
          : context.t(K.asyncDuel);
    } else if (invited != null && knownOpponent == null) {
      title = context.playerDisplayName(
        invited,
        tag: summary.invitedProfile?.playerTag,
      );
      subtitle = statusLabel;
    } else {
      title = knownOpponent ?? statusLabel;
      subtitle = knownOpponent != null
          ? statusLabel
          : (myCorrect != null
                ? '${context.t(K.you)} ${groupThousands(myCorrect)}/${groupThousands(view.total)}'
                : null);
    }
    // Rozet yalnız TAMAMLANMIŞ ve henüz görülmemiş satırda anlamlıdır —
    // "bekleniyor/süresi doldu/yarım kaldı" satırında oyuncunun görmesi
    // gereken yeni bir sonuç yok. Gelen meydan okumada rozet "Oyna".
    final resumable = summary.canResume;
    final showReadyChip =
        incoming ||
        resumable ||
        (view.kind == AsyncDuelResultKind.completed && !summary.seen);
    // "Sıra sende" (yarım kalan turum) rozeti: eskiden "Devam et" diyordu;
    // oyuncuya asıl söylenmesi gereken, hamlenin ondan beklendiği ve süresi.
    // Kurul C30 (3/3): yarım kalan turda açık bir "Devam et" eylemi yoktu
    // (rozet "Sıra sende" diyordu; "Rakip bul" düğmesi daha baskındı).
    final readyLabel = incoming
        ? context.t(K.challengePlay)
        : resumable
        ? context.t(K.continueAction)
        : context.t(K.asyncDuelReady);
    // Kalan süre: sırası bende olan satırda metin + ince çubuk, rakip
    // beklenen satırda yalnız metin. Süre bilinmiyorsa (eski sunucu) yok.
    final left = summary.timeLeft(DateTime.now());
    final timeLabel = asyncDuelTimeLeftLabel(context, left);
    final forfeitReason =
        summary.isForfeit && view.kind == AsyncDuelResultKind.completed
        ? (view.outcome == AsyncDuelOutcome.win
              ? context.t(K.asyncDuelForfeitOpponentReason, {
                  'name': knownOpponent ?? context.t(K.asyncDuelOpponent),
                })
              : context.t(K.asyncDuelForfeitMyReason))
        : null;
    final Widget? footer;
    if (forfeitReason != null) {
      footer = Text(
        forfeitReason,
        key: const ValueKey('async-duel-forfeit-reason'),
        style: SahneType.caption.copyWith(color: SahneTokens.of(context).tx2),
      );
    } else if (summary.isMyTurn && left != null) {
      footer = AsyncDuelTimeLeft(
        key: const ValueKey('async-duel-time-left'),
        left: left,
        // Kurul 3 D13 (3/3): yarım kalan turda "24 sa kaldı"nın altındaki
        // dolu çubuğun neyi ölçtüğü okunmuyordu; süre metni ve "Süre dolunca
        // düello kapanır" bilgiyi zaten taşır, çubuk yalnız yeni turda kalır.
        showBar: !resumable,
        closesOnExpiry: resumable,
      );
    } else if (summary.isWaitingOpponent && left != null) {
      final timeLeftText = AsyncDuelTimeLeft(
        key: const ValueKey('async-duel-time-left'),
        left: left,
      );
      // Rakibin sırası: süre metninin altında "Dürt". Düğme kendi alt
      // ağacında yaşar; satır dokunuşu (sonuç ekranı) ondan ayrıdır.
      footer = repository != null && summary.canNudge(DateTime.now())
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                timeLeftText,
                AsyncDuelNudgeButton(
                  key: ValueKey('async-duel-nudge-${summary.duelId}'),
                  repository: repository!,
                  summary: summary,
                  onChanged: onNudged,
                ),
              ],
            )
          : timeLeftText;
    } else {
      footer = null;
    }
    final icon = switch (view.kind) {
      _ when incoming => AppIcons.peopleGroup,
      AsyncDuelResultKind.completed => AppIcons.trophy,
      AsyncDuelResultKind.waiting => AppIcons.hourglass,
      AsyncDuelResultKind.expired ||
      AsyncDuelResultKind.unfinished => AppIcons.clock,
    };

    final semanticLabel = [
      title,
      ?subtitle,
      ?forfeitReason,
      if (footer != null && forfeitReason == null) ?timeLabel,
      if (showReadyChip) readyLabel,
    ].join('. ');
    // Kurul 3 D13: yarım kalan turda "Devam et" küçük bir rozetti, yanındaki
    // "Rakip bul" düğmesi daha baskındı. Yarım turda gerçek (tonlu) bir
    // düğmedir; satır dokunuşuyla aynı eylem.
    final t = SahneTokens.of(context);
    final trailing = resumable && !incoming
        ? SahneButton.tonal(
            key: const ValueKey('async-duel-ready-badge'),
            label: readyLabel,
            tint: t.raceTint,
            foreground: t.raceTx,
            onPressed: onTap,
          )
        : showReadyChip
        ? SahneBadge(
            key: const ValueKey('async-duel-ready-badge'),
            label: readyLabel,
            tone: SahneBadgeTone.race,
          )
        : null;
    // Rakibin kimliği biliniyorsa satırın başında ONUN fotoğrafı/simgesi
    // durur; bilinmiyorsa (bekleyen düello ya da sunucu SQL'i uygulanmadı)
    // durum ikonu kalır.
    final opponentProfile = summary.opponentProfile;
    if (opponentProfile != null) {
      return SahneListRow.leading(
        leading: PlayerAvatar.fromIdentity(
          key: const ValueKey('async-duel-opponent-avatar'),
          radius: 20,
          identity: opponentProfile.avatar,
          displayName: rawOpponent,
        ),
        title: title,
        subtitle: subtitle,
        semanticLabel: semanticLabel,
        chevron: !showReadyChip,
        trailing: trailing,
        footer: footer,
        onTap: onTap,
      );
    }
    return SahneListRow.icon(
      icon: icon,
      role: SahneRole.race,
      title: title,
      subtitle: subtitle,
      semanticLabel: semanticLabel,
      chevron: !showReadyChip,
      trailing: trailing,
      footer: footer,
      onTap: onTap,
    );
  }
}

/// "Hemû" düğmesinden açılan, kesilmemiş tam düello listesi.
class AsyncDuelListScreen extends StatefulWidget {
  const AsyncDuelListScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<AsyncDuelListScreen> createState() => _AsyncDuelListScreenState();
}

class _AsyncDuelListScreenState extends State<AsyncDuelListScreen> {
  late Future<List<AsyncDuelSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadMyAsyncDuels();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadMyAsyncDuels();
    });
  }

  Future<void> _openResult(AsyncDuelSummary summary) async {
    await openAsyncDuelSummary(context, widget.repository, summary);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    // B iskeleti: `zkAppBar` çubuğu (48'lik geri + Manşet başlık); sayfa
    // adı içerikte tekrarlanmaz.
    return Scaffold(
      backgroundColor: SahneTokens.of(context).bg,
      appBar: zkAppBar(context, title: Text(context.t(K.asyncDuelInbox))),
      body: SafeArea(
        child: FutureBuilder<List<AsyncDuelSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppErrorState(
                icon: AppIcons.cloud,
                title: context.t(K.asyncDuelInbox),
                message: context.t(K.asyncDuelLoadFailed),
                retryLabel: context.t(K.retry),
                onRetry: _reload,
              );
            }
            final all = asyncDuelInboxOrder(
              snapshot.data ?? const <AsyncDuelSummary>[],
            );
            if (all.isEmpty) {
              return AppEmptyState(
                icon: AppIcons.hourglass,
                title: context.t(K.asyncDuelInbox),
                message: context.t(K.asyncDuelInboxEmpty),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x2,
                SahneSpace.page,
                SahneSpace.x6,
              ),
              children: [
                SahneListGroup(
                  children: [
                    for (final summary in all)
                      _AsyncDuelSummaryRow(
                        key: ValueKey('async-duel-row-${summary.duelId}'),
                        summary: summary,
                        repository: widget.repository,
                        onNudged: _reload,
                        onTap: () => _openResult(summary),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
