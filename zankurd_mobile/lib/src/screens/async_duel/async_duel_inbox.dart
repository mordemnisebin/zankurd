import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../widgets/app_state.dart';
import '../../widgets/sahne/sahne.dart';
import '../../widgets/zk_back_button.dart';
import 'async_duel_result_screen.dart';

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
    super.key,
  });

  final ZanKurdRepository repository;
  final Listenable? refreshSignal;
  final int maxRows;

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
    await Navigator.of(context).push(
      AppRoute.to(
        AsyncDuelResultScreen(
          repository: widget.repository,
          view: AsyncDuelResultView.fromSummary(summary),
        ),
      ),
    );
    _reload();
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
    final all = items ?? const <AsyncDuelSummary>[];
    final unreadCount = all.where((s) => s.outcome != null && !s.seen).length;

    // 2026-09-29 Şahnê: tek bölüm başlığı (`SahneSectionHeader`), satırlar
    // liste grubunda (`SahneListRow`, Boyax yarış karosu). Okunmamış sayı
    // dolu turuncu kutu değil, yarış tonunda rol rozeti: dolu kırmızı/
    // turuncu rozet yok, Agir yalnız birincil eylemdir.
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
    return SahneBadge(label: '$count', tone: SahneBadgeTone.race);
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
    super.key,
  });

  final AsyncDuelSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final view = AsyncDuelResultView.fromSummary(summary);
    final statusLabel = asyncDuelStatusLabel(context, view);
    // Rakibi henüz belli olmayan satırda başlık durumun kendisidir
    // ("Rakip bekleniyor"); "Rakip / Rakip bekleniyor" aynı sözü iki kez
    // söylüyordu. Alt satır o zaman oyuncunun kendi skorunu verir.
    final knownOpponent = summary.opponentName;
    final myCorrect = view.myCorrect;
    final title = knownOpponent ?? statusLabel;
    final subtitle = knownOpponent != null
        ? statusLabel
        : (myCorrect != null
              ? '${context.t(K.you)} $myCorrect/${view.total}'
              : null);
    // Rozet yalnız TAMAMLANMIŞ ve henüz görülmemiş satırda anlamlıdır —
    // "bekleniyor/süresi doldu/yarım kaldı" satırında oyuncunun görmesi
    // gereken yeni bir sonuç yok.
    final showReadyChip =
        view.kind == AsyncDuelResultKind.completed && !summary.seen;
    final readyLabel = context.t(K.asyncDuelReady);
    final icon = switch (view.kind) {
      AsyncDuelResultKind.completed => AppIcons.trophy,
      AsyncDuelResultKind.waiting => AppIcons.hourglass,
      AsyncDuelResultKind.expired ||
      AsyncDuelResultKind.unfinished => AppIcons.clock,
    };

    return SahneListRow.icon(
      icon: icon,
      role: SahneRole.race,
      title: title,
      subtitle: subtitle,
      semanticLabel: [
        title,
        ?subtitle,
        if (showReadyChip) readyLabel,
      ].join('. '),
      chevron: !showReadyChip,
      trailing: showReadyChip
          ? SahneBadge(
              key: const ValueKey('async-duel-ready-badge'),
              label: readyLabel,
              tone: SahneBadgeTone.race,
            )
          : null,
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
    await Navigator.of(context).push(
      AppRoute.to(
        AsyncDuelResultScreen(
          repository: widget.repository,
          view: AsyncDuelResultView.fromSummary(summary),
        ),
      ),
    );
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
            final all = snapshot.data ?? const <AsyncDuelSummary>[];
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
