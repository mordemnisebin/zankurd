import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_route.dart';
import '../../widgets/app_panel.dart';
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

    return KeyedSubtree(
      key: const ValueKey('play-hub-async-duel-inbox'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sayı rozeti başlığın hemen yanında: `ScreenSectionHeading`in
          // `trailing`i dar ekranda (390 pt'de bile, kenar boşluğu düşünce)
          // alt satıra iniyor ve küçük bir rozet sahipsiz görünüyordu.
          Semantics(
            header: true,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    context.t(K.asyncDuelInbox),
                    style: AppTypography.heading2.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _UnreadCountBadge(count: unreadCount),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (items == null && !_failed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (items == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(K.asyncDuelLoadFailed),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: Text(context.t(K.retry)),
                  ),
                ],
              ),
            )
          else if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                context.t(K.asyncDuelInboxEmpty),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textSubColor(context),
                ),
              ),
            )
          else ...[
            for (final summary in all.take(widget.maxRows))
              _AsyncDuelSummaryRow(
                key: ValueKey('async-duel-row-${summary.duelId}'),
                summary: summary,
                onTap: () => _openResult(summary),
              ),
            if (all.length > widget.maxRows)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _openSeeAll,
                  child: Text(context.t(K.asyncDuelSeeAll)),
                ),
              ),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.brand,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        '$count',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Bir düello özetinin satırı — kutuda ve tam listede ortak.
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

    // `AppPanel`in kendi `onTap`i, dokunma alanını ayrı bir Stack
    // katmanıyla (görünmez bir üst `InkWell`) üstlenir — bu, rozetin
    // kendi `Container`ına dokunan bir testin "hedeflenen widget'a hiç
    // değmedi" uyarısı almasına yol açıyordu (dokunma yine de doğru
    // çalışıyordu, ama uyarı yanlış bir kusur izlenimi veriyordu).
    // `favorite_questions_screen.dart`daki gibi `InkWell`i doğrudan
    // panelin ÇOCUĞU yapmak aynı satırı tek, düz bir ağaçla tıklanabilir
    // kılar.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        onTap: onTap,
        excludeSemantics: true,
        child: AppPanel(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.panelRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textSubColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (showReadyChip)
                    Container(
                      key: const ValueKey('async-duel-ready-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        context.t(K.asyncDuelReady),
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: AppTheme.textMutedColor(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    return Scaffold(
      appBar: zkAppBar(context, title: Text(context.t(K.asyncDuelInbox))),
      body: SafeArea(
        child: FutureBuilder<List<AsyncDuelSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.t(K.asyncDuelLoadFailed)),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _reload,
                      child: Text(context.t(K.retry)),
                    ),
                  ],
                ),
              );
            }
            final all = snapshot.data ?? const <AsyncDuelSummary>[];
            if (all.isEmpty) {
              return Center(child: Text(context.t(K.asyncDuelInboxEmpty)));
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                for (final summary in all)
                  _AsyncDuelSummaryRow(
                    key: ValueKey('async-duel-row-${summary.duelId}'),
                    summary: summary,
                    onTap: () => _openResult(summary),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
