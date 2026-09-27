import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/xp_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/zk_back_button.dart';
import 'async_duel_play_screen.dart';

/// Sonuç ekranının dört bitiş durumu.
///
/// [completed]: iki taraf da bitirdi, karşılaştırma kesin. [waiting]: BEN
/// bitirdim, rakip henüz değil. [expired]: 48 saat doldu ve rakip hiç
/// çıkmadı. [unfinished]: BEN kendi 7 sorumu bitirmedim — kendi hatam,
/// düello süresi dolunca kendiliğinden kapanacak.
enum AsyncDuelResultKind { completed, waiting, expired, unfinished }

/// Sonuç ekranının girdi görünüm modeli.
///
/// İki kaynaktan kurulabilir: [fromAnswer] oyun ekranındaki son cevaptan
/// hemen sonra (taze veri, `AsyncDuelStart`in taşıdığı rakip adıyla);
/// [fromSummary] "Düellolarım" listesindeki bir satırdan (gecikmeli veri,
/// `list_my_async_duels` özetiyle). İkisi de aynı dört duruma düşer ki
/// oyun ekranından çıkan sonuç ile listeden açılan sonuç aynı görünsün.
class AsyncDuelResultView {
  const AsyncDuelResultView._({
    required this.duelId,
    required this.kind,
    this.myCorrect,
    this.opponentCorrect,
    this.outcome,
    this.opponentName,
  });

  final String duelId;
  final AsyncDuelResultKind kind;
  final int? myCorrect;
  final int? opponentCorrect;
  final AsyncDuelOutcome? outcome;
  final String? opponentName;

  /// Sırayla düellonun soru sayısı — sözleşmede sabit 7 (bkz.
  /// `lib/src/models/async_duel.dart`); hiçbir çağıranın özelleştirmesi
  /// gerekmediği için kurucudan değil doğrudan burada verilir.
  final int total = 7;

  /// Son (7.) soru cevaplandığında `answerAsyncDuel`ın döndürdüğü
  /// karşılaştırmadan kurulur. `result.waiting` true ise rakip henüz
  /// bitirmedi ([AsyncDuelResultKind.waiting]); false ise karşılaştırma
  /// kesinleşmiştir ([AsyncDuelResultKind.completed]).
  factory AsyncDuelResultView.fromAnswer(
    AsyncDuelStart start,
    AsyncDuelResult result,
  ) {
    if (result.waiting) {
      return AsyncDuelResultView._(
        duelId: start.duelId,
        kind: AsyncDuelResultKind.waiting,
        myCorrect: result.myCorrect,
        opponentName: start.opponentName,
      );
    }
    return AsyncDuelResultView._(
      duelId: start.duelId,
      kind: AsyncDuelResultKind.completed,
      myCorrect: result.myCorrect,
      opponentCorrect: result.opponentCorrect,
      outcome: result.outcome,
      opponentName: start.opponentName,
    );
  }

  /// "Düellolarım" listesindeki bir satırdan kurulur.
  ///
  /// `myCorrect == null` HER ZAMAN [AsyncDuelResultKind.unfinished] demektir
  /// — ben kendi 7 sorumu bitirmedim — ve bu, `status`tan ÖNCE kontrol
  /// edilir: süresi dolmuş ama benim de bitirmediğim bir düello "rakip
  /// çıkmadı" değil, "nîvco ma" olarak okunmalı (kusur bende).
  factory AsyncDuelResultView.fromSummary(AsyncDuelSummary summary) {
    final myCorrect = summary.myCorrect;
    if (myCorrect == null) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.unfinished,
        opponentName: summary.opponentName,
      );
    }
    if (summary.outcome != null) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.completed,
        myCorrect: myCorrect,
        opponentCorrect: summary.opponentCorrect,
        outcome: summary.outcome,
        opponentName: summary.opponentName,
      );
    }
    if (summary.status == AsyncDuelStatus.expired) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.expired,
        myCorrect: myCorrect,
        opponentName: summary.opponentName,
      );
    }
    // open/matched, outcome henüz yok: rakip hâlâ oynuyor ya da hiç
    // katılmadı — ikisi de oyuncu için aynı "bekleniyor" görünümüdür.
    return AsyncDuelResultView._(
      duelId: summary.duelId,
      kind: AsyncDuelResultKind.waiting,
      myCorrect: myCorrect,
      opponentName: summary.opponentName,
    );
  }

  /// Tur bitti ama sonucu bilmiyoruz: son cevabın yanıtı ağda kayboldu
  /// ('Already answered' ile anlaşıldı) ya da sunucu `result`u boş döndü.
  ///
  /// "Bekleniyor" görünümüne düşülür ve skor GÖSTERİLMEZ ([myCorrect]
  /// null): bilinmeyen doğru sayısı yerine "0/7" yazmak oyuncuya yanlış bir
  /// sonuç söylerdi. Gerçek sonuç "Düellolarım"dan okunur.
  factory AsyncDuelResultView.unknownAfterFinish(String duelId) {
    return AsyncDuelResultView._(
      duelId: duelId,
      kind: AsyncDuelResultKind.waiting,
    );
  }
}

/// Tamamlanmış bir düellonun ekranda gösterilecek XP'si.
///
/// Sunucudan gelen `claimAsyncDuelXp` dönüşü `profiles.xp` TOPLAMIdır, bu
/// turda kazanılan miktar değil (bkz. `ZanKurdRepository.claimAsyncDuelXp`
/// belgesi) — o toplam yalnız yerel seviye çubuğuna uygulanır. Ekrandaki
/// "+xp" rozeti bu yüzden sözleşmedeki sabit formülle AYRICA hesaplanır:
/// doğru başına 20, galibiyet bonusu 30 (bkz. `MockZanKurdRepository`deki
/// aynı formül).
int _completedXp(AsyncDuelResultView view) =>
    (view.myCorrect ?? 0) * 20 +
    (view.outcome == AsyncDuelOutcome.win ? 30 : 0);

/// Süresi dolmuş bir düellonun XP'si: yalnız kendi doğruların — rakip hiç
/// çıkmadığı için galibiyet bonusu yoktur.
int _expiredXp(AsyncDuelResultView view) => (view.myCorrect ?? 0) * 20;

/// Bir düello özetinin kısa durum etiketi — "Düellolarım" satırlarıyla
/// sonuç ekranının aynı sınıflandırmayı ([AsyncDuelResultView.fromSummary])
/// paylaşması için burada, tek yerde tutulur.
String asyncDuelStatusLabel(BuildContext context, AsyncDuelResultView view) {
  switch (view.kind) {
    case AsyncDuelResultKind.waiting:
      return context.t(K.asyncDuelWaiting);
    case AsyncDuelResultKind.expired:
      return context.t(K.asyncDuelExpired);
    case AsyncDuelResultKind.unfinished:
      return context.t(K.asyncDuelUnfinished);
    case AsyncDuelResultKind.completed:
      final headline = switch (view.outcome!) {
        AsyncDuelOutcome.win => context.t(K.youWon),
        AsyncDuelOutcome.loss => context.t(K.youLost),
        AsyncDuelOutcome.draw => context.t(K.draw),
      };
      return '$headline · ${view.myCorrect}–${view.opponentCorrect}';
  }
}

/// Sırayla düellonun tek sonuç ekranı — dört duruma da bu widget bakar.
class AsyncDuelResultScreen extends StatefulWidget {
  const AsyncDuelResultScreen({
    required this.repository,
    required this.view,
    super.key,
  });

  final ZanKurdRepository repository;
  final AsyncDuelResultView view;

  @override
  State<AsyncDuelResultScreen> createState() => _AsyncDuelResultScreenState();
}

class _AsyncDuelResultScreenState extends State<AsyncDuelResultScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_runSideEffectsOnce());
  }

  /// Ekran açılınca bir kez: görüldü işareti ve XP talebi.
  ///
  /// İkisi de arayüzü bloklamaz — kullanıcı sonucu hemen görür, sunucu
  /// yazımları arka planda dener. Hatalar yutulmaz, `ErrorReporter` ile
  /// kaydedilir; sessizce kaybolan bir XP talebi oyuncunun hiç
  /// öğrenemeyeceği bir kayıptır.
  Future<void> _runSideEffectsOnce() async {
    final view = widget.view;
    if (view.kind == AsyncDuelResultKind.completed) {
      try {
        await widget.repository.markAsyncDuelSeen(view.duelId);
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'async duel mark seen failed',
        );
      }
    }
    if (view.kind == AsyncDuelResultKind.completed ||
        view.kind == AsyncDuelResultKind.expired) {
      try {
        final total = await widget.repository.claimAsyncDuelXp(view.duelId);
        if (!mounted) return;
        if (widget.repository.xpAwardIsServerTotal) {
          final store = await XPStore.load();
          await store.applyServerTotal(total);
        }
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'async duel claim xp failed',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final content = switch (view.kind) {
      AsyncDuelResultKind.completed => _CompletedBody(view: view),
      AsyncDuelResultKind.waiting => _WaitingBody(view: view),
      AsyncDuelResultKind.expired => _ExpiredBody(view: view),
      AsyncDuelResultKind.unfinished => _UnfinishedBody(view: view),
    };
    final canStartNew = view.kind != AsyncDuelResultKind.unfinished;

    return Scaffold(
      key: const ValueKey('async-duel-result'),
      appBar: zkAppBar(context, title: Text(context.t(K.asyncDuel))),
      // İçerik kısa ekranda ortada, düğmeler altta durur; %200 yazıda içerik
      // uzarsa sayfa kayar. Düğmeler yan yana sığmazsa alt alta iner (Row
      // %200 yazıda sağdan taşıyordu).
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.page),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    Expanded(child: Center(child: content)),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.t(K.close)),
                        ),
                        if (canStartNew)
                          FilledButton(
                            key: const ValueKey('async-duel-result-new'),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                AppRoute.to(
                                  AsyncDuelPlayScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                            },
                            child: Text(context.t(K.asyncDuelNew)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    final outcome = view.outcome ?? AsyncDuelOutcome.draw;
    final title = switch (outcome) {
      AsyncDuelOutcome.win => context.t(K.youWon),
      AsyncDuelOutcome.loss => context.t(K.youLost),
      AsyncDuelOutcome.draw => context.t(K.draw),
    };
    final icon = switch (outcome) {
      AsyncDuelOutcome.win => AppIcons.trophy,
      AsyncDuelOutcome.loss => AppIcons.faceFrown,
      AsyncDuelOutcome.draw => AppIcons.scaleBalanced,
    };
    final opponentName = view.opponentName ?? context.t(K.asyncDuelOpponent);
    final xp = _completedXp(view);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppTheme.brand),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${context.t(K.you)} ${view.myCorrect} – ${view.opponentCorrect} '
          '$opponentName',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
        if (outcome != AsyncDuelOutcome.draw &&
            view.myCorrect != null &&
            view.myCorrect == view.opponentCorrect) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.t(K.asyncDuelTieBreak),
            key: const ValueKey('async-duel-result-tiebreak'),
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          context.t(K.asyncDuelXp, {'xp': '$xp'}),
          style: AppTypography.heading2.copyWith(color: AppTheme.gold),
        ),
      ],
    );
  }
}

class _WaitingBody extends StatelessWidget {
  const _WaitingBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.hourglass, size: 56, color: AppTheme.brand),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.t(K.asyncDuelTurnDone),
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        if (view.myCorrect case final myCorrect?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$myCorrect/${view.total}',
            key: const ValueKey('async-duel-result-score'),
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.t(K.asyncDuelWaitingBody),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
      ],
    );
  }
}

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    final xp = _expiredXp(view);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.clock, size: 56, color: AppTheme.textMutedColor(context)),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.t(K.asyncDuelExpired),
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.t(K.asyncDuelExpiredBody),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.t(K.asyncDuelXp, {'xp': '$xp'}),
          style: AppTypography.heading2.copyWith(color: AppTheme.gold),
        ),
      ],
    );
  }
}

class _UnfinishedBody extends StatelessWidget {
  const _UnfinishedBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          AppIcons.triangleExclamation,
          size: 56,
          color: AppTheme.textMutedColor(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.t(K.asyncDuelUnfinished),
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.t(K.asyncDuelUnfinishedBody),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
      ],
    );
  }
}
