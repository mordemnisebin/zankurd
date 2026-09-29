import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/xp_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/sahne/sahne.dart';
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

  /// 2026-09-29 Şahnê: C iskeleti (oyun sahnesi, her temada gece). Üstte
  /// kapat + ortada bağlam ("Sırayla düello"); içerik ortada bir sonuç
  /// kahramanı; alt perdede ikincil "Kapat" + TEK birincil "Yeni düello".
  /// Kazanma Zêr taç + altın başlık; kaybetme ve beraberlik nötr; yarış
  /// kimliği Boyax (VS amblemi; zaferde kilim şeridi). Rast/Şaş ailesi
  /// kullanılmaz.
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
    final celebrate =
        view.kind == AsyncDuelResultKind.completed &&
        view.outcome == AsyncDuelOutcome.win;

    return SahneStageScaffold(
      key: const ValueKey('async-duel-result'),
      closeLabel: context.t(K.close),
      beam: false,
      center: Text(context.t(K.asyncDuel)),
      dock: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _ResultDock(
            onClose: () => Navigator.of(context).pop(),
            onNew: canStartNew
                ? () {
                    Navigator.of(context).pushReplacement(
                      AppRoute.to(
                        AsyncDuelPlayScreen(repository: widget.repository),
                      ),
                    );
                  }
                : null,
          ),
        ),
      ),
      // İçerik kısa ekranda ortada durur; %200 yazıda uzarsa sayfa kayar.
      // Işınlar kahramanın dışına taşar; kısa içerikte kaydırma alanı
      // kırpmadığı için üst satırın üstüne boyanmasın diye gövde kırpılır.
      body: LayoutBuilder(
        builder: (context, constraints) => ClipRect(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.page,
              vertical: SahneSpace.x4,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - SahneSpace.x8),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: SahneResultBackdropPainter(
                                rays: celebrate,
                                raysCenterY: 60,
                                bg: SahneTokens.night.bg,
                                ridge: SahneTokens.night.s1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: SahneSpace.x6),
                        child: SizedBox(width: double.infinity, child: content),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alt perde: ikincil "Kapat" + birincil "Yeni düello"; yarım kalan
/// düelloda yalnız "Kapat". Büyük yazıda alt alta iner, birincil üstte.
class _ResultDock extends StatelessWidget {
  const _ResultDock({required this.onClose, required this.onNew});

  final VoidCallback onClose;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final close = SahneButton.secondary(
      label: context.t(K.close),
      onPressed: onClose,
      expand: true,
    );
    final onNew = this.onNew;
    if (onNew == null) return close;
    final create = SahneButton.primary(
      key: const ValueKey('async-duel-result-new'),
      label: context.t(K.asyncDuelNew),
      onPressed: onNew,
      expand: true,
    );
    if (MediaQuery.textScalerOf(context).scale(16) >= 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          create,
          const SizedBox(height: SahneSpace.x2),
          close,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 2, child: close),
        const SizedBox(width: SahneSpace.x3),
        Expanded(flex: 3, child: create),
      ],
    );
  }
}

/// Sonuç kahramanının ortak iskeleti: amblem → Başlık 28 → isteğe bağlı
/// büyük sayı / skor satırı → açıklama → (zaferde) kilim şeridi → XP çipi.
class _DuelHero extends StatelessWidget {
  const _DuelHero({
    required this.emblem,
    required this.title,
    this.titleColor,
    this.children = const [],
  });

  final Widget emblem;
  final String title;
  final Color? titleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        emblem,
        const SizedBox(height: SahneSpace.x4),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: SahneType.title.copyWith(color: titleColor ?? t.tx),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Durum amblemi: 72'lik Kulis pahlı karesi, içinde ikincil metin ikon.
/// 2026-09-29 doğallık (K5): eskiden elmastı (avatarla aynı bileşen).
class _StateDiamond extends StatelessWidget {
  const _StateDiamond({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneAvatar(size: 72, icon: icon, color: t.s2, foreground: t.tx2);
  }
}

/// Zêr XP çipi (ödül rolü).
class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return SahneStatChip(
      gold: true,
      leading: const SahneGlyph(SahneGlyphKind.bolt),
      label: context.t(K.asyncDuelXp, {'xp': '$xp'}),
    );
  }
}

/// Yarış kimliğinin kilim göz şeridi (Boyax, %70) — yalnız galibiyette.
///
/// 2026-09-29 doğallık (K4): şerit bekleyen, süresi dolan, kaybedilen ve
/// berabere biten düelloda da skorun altındaydı. Her durumda aynı süs bir
/// şablon izi oluyordu; şerit, sonuç ışınlarıyla aynı anda (zaferde) açılır.
class _RaceStrip extends StatelessWidget {
  const _RaceStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: SahneKilimStrip(
        color: SahneTokens.of(context).raceTx.withValues(alpha: 0.7),
      ),
    );
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final outcome = view.outcome ?? AsyncDuelOutcome.draw;
    final title = switch (outcome) {
      AsyncDuelOutcome.win => context.t(K.youWon),
      AsyncDuelOutcome.loss => context.t(K.youLost),
      AsyncDuelOutcome.draw => context.t(K.draw),
    };
    final opponentName = view.opponentName ?? context.t(K.asyncDuelOpponent);
    final initial = opponentName.trim().isEmpty
        ? '?'
        : opponentName.trim().characters.first.toUpperCase();
    final xp = _completedXp(view);
    final win = outcome == AsyncDuelOutcome.win;

    return _DuelHero(
      emblem: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: win
                ? const SahneGlyph(SahneGlyphKind.crown, size: 44)
                : ExcludeSemantics(
                    child: Icon(
                      outcome == AsyncDuelOutcome.draw
                          ? AppIcons.scaleBalanced
                          : AppIcons.flag,
                      size: 36,
                      color: t.tx2,
                    ),
                  ),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneVsEmblem(opponentInitial: initial),
        ],
      ),
      title: title,
      titleColor: win ? t.goldTx : null,
      children: [
        const SizedBox(height: SahneSpace.x2),
        Text(
          '${context.t(K.you)} ${view.myCorrect} – ${view.opponentCorrect} '
          '$opponentName',
          textAlign: TextAlign.center,
          style: SahneType.headline.copyWith(
            color: t.tx,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (outcome != AsyncDuelOutcome.draw &&
            view.myCorrect != null &&
            view.myCorrect == view.opponentCorrect) ...[
          const SizedBox(height: SahneSpace.x1),
          Text(
            context.t(K.asyncDuelTieBreak),
            key: const ValueKey('async-duel-result-tiebreak'),
            textAlign: TextAlign.center,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ],
        if (win) ...[const SizedBox(height: SahneSpace.x3), const _RaceStrip()],
        const SizedBox(height: SahneSpace.x4),
        _XpChip(xp: xp),
      ],
    );
  }
}

class _WaitingBody extends StatelessWidget {
  const _WaitingBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return _DuelHero(
      emblem: const _StateDiamond(icon: AppIcons.hourglass),
      title: context.t(K.asyncDuelTurnDone),
      children: [
        if (view.myCorrect case final myCorrect?)
          Text(
            '$myCorrect/${view.total}',
            key: const ValueKey('async-duel-result-score'),
            style: SahneType.screen.copyWith(color: t.gold),
          ),
        const SizedBox(height: SahneSpace.x2),
        Text(
          context.t(K.asyncDuelWaitingBody),
          textAlign: TextAlign.center,
          style: SahneType.body.copyWith(color: t.tx2),
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
    final t = SahneTokens.of(context);
    final xp = _expiredXp(view);
    return _DuelHero(
      emblem: const _StateDiamond(icon: AppIcons.clock),
      title: context.t(K.asyncDuelExpired),
      children: [
        const SizedBox(height: SahneSpace.x2),
        Text(
          context.t(K.asyncDuelExpiredBody),
          textAlign: TextAlign.center,
          style: SahneType.body.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x4),
        _XpChip(xp: xp),
      ],
    );
  }
}

class _UnfinishedBody extends StatelessWidget {
  const _UnfinishedBody({required this.view});

  final AsyncDuelResultView view;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return _DuelHero(
      emblem: const _StateDiamond(icon: AppIcons.triangleExclamation),
      title: context.t(K.asyncDuelUnfinished),
      children: [
        const SizedBox(height: SahneSpace.x2),
        Text(
          context.t(K.asyncDuelUnfinishedBody),
          textAlign: TextAlign.center,
          style: SahneType.body.copyWith(color: t.tx2),
        ),
      ],
    );
  }
}
