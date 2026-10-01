import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/xp_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/player_identity.dart';
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

  /// 2026-10-01 (A6): ortak sonuç şablonu ([SahneResultScaffold]): kahraman
  /// (amblem → başlık → skor → bağlam), ödül (yalnız XP > 0 iken) ve alt
  /// perdede ikincil "Kapat" + TEK birincil "Yeni düello". Yarım kalan
  /// düelloda tek eylem "Kapat"tır ve birincil olur. Kazanma Zêr taç +
  /// altın başlık; kaybetme ve beraberlik nötr; yarış kimliği Boyax
  /// (zaferde kilim şeridi). Rast/Şaş ailesi kullanılmaz.
  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final t = SahneTokens.of(context);
    final close = SahneResultAction(
      label: context.t(K.close),
      onPressed: () => Navigator.of(context).pop(),
    );
    final canStartNew = view.kind != AsyncDuelResultKind.unfinished;

    final SahneResultHero hero;
    int xp = 0;
    switch (view.kind) {
      case AsyncDuelResultKind.completed:
        final outcome = view.outcome ?? AsyncDuelOutcome.draw;
        final win = outcome == AsyncDuelOutcome.win;
        final rawOpponentName = view.opponentName;
        final opponentName = rawOpponentName == null
            ? context.t(K.asyncDuelOpponent)
            : context.playerDisplayName(rawOpponentName);
        xp = _completedXp(view);
        // 2026-09-29 doğallık: sonuçta iki amblem üst üsteydi (taç/bayrak/
        // terazi + iki avatarlı VS amblemi). Avatarlar yalnız "sen" ve
        // rakibin baş harfiydi; aynı bilgi skor satırında ("Sen 2 – 0
        // Rojda") yazılı. Tek amblem kalır: sonucun kendisi.
        hero = SahneResultHero(
          emblem: switch (outcome) {
            AsyncDuelOutcome.win => const SahneResultEmblem.win(),
            AsyncDuelOutcome.loss => const SahneResultEmblem.state(
              icon: AppIcons.flag,
            ),
            AsyncDuelOutcome.draw => const SahneResultEmblem.state(
              icon: AppIcons.scaleBalanced,
            ),
          },
          title: switch (outcome) {
            AsyncDuelOutcome.win => context.t(K.youWon),
            AsyncDuelOutcome.loss => context.t(K.youLost),
            AsyncDuelOutcome.draw => context.t(K.draw),
          },
          titleRole: win ? SahneRole.gold : null,
          subtitle:
              '${context.t(K.you)} ${view.myCorrect} – ${view.opponentCorrect} '
              '$opponentName',
          extras: [
            if (outcome != AsyncDuelOutcome.draw &&
                view.myCorrect != null &&
                view.myCorrect == view.opponentCorrect)
              Text(
                context.t(K.asyncDuelTieBreak),
                key: const ValueKey('async-duel-result-tiebreak'),
                textAlign: TextAlign.center,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
          ],
          // Kilim şeridi ve ışınlar yalnız zaferde (2026-09-29 K4).
          celebrate: win,
          tone: SahneResultTone.race,
        );
      case AsyncDuelResultKind.waiting:
        hero = SahneResultHero(
          emblem: const SahneResultEmblem.state(icon: AppIcons.hourglass),
          title: context.t(K.asyncDuelTurnDone),
          // Sonuç bilinmiyorsa ([myCorrect] null) skor GÖSTERİLMEZ: "0/7"
          // oyuncuya yanlış bir sonuç söylerdi.
          value: view.myCorrect,
          suffix: '/${view.total}',
          valueKey: const ValueKey('async-duel-result-score'),
          body: context.t(K.asyncDuelWaitingBody),
          tone: SahneResultTone.race,
        );
      case AsyncDuelResultKind.expired:
        xp = _expiredXp(view);
        hero = SahneResultHero(
          emblem: const SahneResultEmblem.state(icon: AppIcons.clock),
          title: context.t(K.asyncDuelExpired),
          body: context.t(K.asyncDuelExpiredBody),
          tone: SahneResultTone.race,
        );
      case AsyncDuelResultKind.unfinished:
        hero = SahneResultHero(
          emblem: const SahneResultEmblem.state(
            icon: AppIcons.triangleExclamation,
          ),
          title: context.t(K.asyncDuelUnfinished),
          body: context.t(K.asyncDuelUnfinishedBody),
          tone: SahneResultTone.race,
        );
    }

    return SahneResultScaffold(
      key: const ValueKey('async-duel-result'),
      closeLabel: context.t(K.close),
      contextLabel: context.t(K.asyncDuel),
      hero: hero,
      // Sıfır XP ("+0 XP") gösterilmez: yanlış ya da süresi dolmuş sıfır
      // doğrulu düello ödülsüz biter.
      rewards: xp > 0
          ? SahneResultRewards(
              xp: xp,
              xpLabel: context.t(K.asyncDuelXp, {'xp': '$xp'}),
            )
          : null,
      primary: canStartNew
          ? SahneResultAction(
              key: const ValueKey('async-duel-result-new'),
              label: context.t(K.asyncDuelNew),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  AppRoute.to(
                    AsyncDuelPlayScreen(repository: widget.repository),
                  ),
                );
              },
            )
          : close,
      secondary: canStartNew ? close : null,
    );
  }
}
