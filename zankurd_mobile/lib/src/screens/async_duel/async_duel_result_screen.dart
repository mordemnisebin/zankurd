import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/xp_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../models/avatar_identity.dart';
import '../../models/public_profile.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/join_deep_link.dart';
import '../../utils/player_identity.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/dialog_action_pair.dart';
import '../../widgets/sahne/sahne.dart';
import 'async_duel_play_screen.dart';
import 'async_duel_review.dart';

/// Sonuç ekranının dört bitiş durumu.
///
/// [completed]: iki taraf da bitirdi, karşılaştırma kesin. [waiting]: BEN
/// bitirdim, rakip henüz değil. [expired]: 24 saat doldu ve rakip hiç
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
    this.opponentProfile,
    this.invitedProfile,
    this.challengeCode,
    this.invitedName,
    this.canCancel = false,
    this.isForfeit = false,
  });

  final String duelId;
  final AsyncDuelResultKind kind;
  final int? myCorrect;
  final int? opponentCorrect;
  final AsyncDuelOutcome? outcome;
  final String? opponentName;

  /// Rakibin / davetlinin fotoğraf-simge-kod kimliği (yoksa baş harf).
  final PublicProfile? opponentProfile;
  final PublicProfile? invitedProfile;

  /// Benim açtığım meydan okumanın `D…` kodu (paylaşım için); rastgele
  /// düellolarda ve rakibin açtığı düellolarda null.
  final String? challengeCode;

  /// Arkadaşa meydan okumada davet ettiğim arkadaşın adı; bağlantı
  /// meydan okumasında null.
  final String? invitedName;

  /// Kimsenin katılmadığı kendi açık düellomu geri çekebilirim
  /// ([AsyncDuelSummary.canCancel]). Yalnız gelen kutusundan açılan görünümde
  /// dolar; turun hemen ardındaki sonuçta gösterilmez.
  final bool canCancel;

  /// Hükmen sonuç (kind daima [AsyncDuelResultKind.completed]): süre doldu,
  /// bir taraf turunu bitirmedi. Skor karşılaştırması yoktur; başlık
  /// "Kazandın · hükmen" / "Kaybettin · hükmen", altında tek satır neden.
  final bool isForfeit;

  /// Hükmen KAYBEDEN benim: turum yok, XP yok, sunucuda talep edecek sonuç
  /// satırı da yok.
  bool get isForfeitLoss => isForfeit && outcome == AsyncDuelOutcome.loss;

  /// Bağlantı meydan okumasını (kimse almadan) paylaşabilirim: turum bitti,
  /// skorum belli, kod elimde, belirli bir arkadaşa gitmedi.
  bool get canShareLink =>
      kind == AsyncDuelResultKind.waiting &&
      challengeCode != null &&
      invitedName == null &&
      myCorrect != null;

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
        opponentProfile: start.opponentProfile,
        challengeCode: start.role == AsyncDuelRole.creator
            ? start.challengeCode
            : null,
        invitedName: start.invitedName,
        invitedProfile: start.invitedProfile,
      );
    }
    return AsyncDuelResultView._(
      duelId: start.duelId,
      kind: AsyncDuelResultKind.completed,
      myCorrect: result.myCorrect,
      opponentCorrect: result.opponentCorrect,
      outcome: result.outcome,
      opponentName: start.opponentName,
      opponentProfile: start.opponentProfile,
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
    // Hükmen sonuç `myCorrect == null`dan ÖNCE okunur: hükmen kaybeden
    // turunu bitirmemiştir ama "Yarım kaldı" değil "Kaybettin · hükmen" der.
    // Rakibin skoru olmayan sonuç da hükmendir: rakip turunu bitirmedi, ya
    // da eski sunucu `forfeit` bayrağını göndermedi. "5–null" yazmaktansa
    // hükmen metni gösterilir.
    if (summary.outcome != null &&
        (summary.isForfeit ||
            summary.opponentCorrect == null ||
            myCorrect == null)) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.completed,
        myCorrect: myCorrect,
        opponentCorrect: summary.opponentCorrect,
        outcome: summary.outcome,
        opponentName: summary.opponentName,
        opponentProfile: summary.opponentProfile,
        isForfeit: true,
      );
    }
    if (myCorrect == null) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.unfinished,
        opponentName: summary.opponentName,
        opponentProfile: summary.opponentProfile,
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
        opponentProfile: summary.opponentProfile,
      );
    }
    if (summary.status == AsyncDuelStatus.expired) {
      return AsyncDuelResultView._(
        duelId: summary.duelId,
        kind: AsyncDuelResultKind.expired,
        myCorrect: myCorrect,
        opponentName: summary.opponentName,
        opponentProfile: summary.opponentProfile,
      );
    }
    // open/matched, outcome henüz yok: rakip hâlâ oynuyor ya da hiç
    // katılmadı — ikisi de oyuncu için aynı "bekleniyor" görünümüdür.
    return AsyncDuelResultView._(
      duelId: summary.duelId,
      kind: AsyncDuelResultKind.waiting,
      myCorrect: myCorrect,
      opponentName: summary.opponentName,
      opponentProfile: summary.opponentProfile,
      // Yalnız hâlâ kimsenin almadığı meydan okuma yeniden paylaşılır.
      challengeCode:
          summary.role == AsyncDuelRole.creator &&
              summary.status == AsyncDuelStatus.open
          ? summary.challengeCode
          : null,
      invitedName: summary.invitedName,
      invitedProfile: summary.invitedProfile,
      canCancel: summary.canCancel,
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
      if (view.isForfeit) {
        return view.outcome == AsyncDuelOutcome.win
            ? context.t(K.asyncDuelWonForfeit)
            : context.t(K.asyncDuelLostForfeit);
      }
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

class _AsyncDuelResultScreenState extends State<AsyncDuelResultScreen>
    with WidgetsBindingObserver {
  /// Bekleme ekranı ("Rakibin oynayınca sonuç burada görünecek") sözünü
  /// tutar: rakip bitirince ekran kendiliğinden sonuca geçer. Eskiden ekran
  /// durağandı; iki simülatörlü turda rakip bitirdiği halde kum saati
  /// kaldı (2026-10-27). Açıkken [_waitingPollInterval]'da bir ve uygulama
  /// öne her geldiğinde düello listesine bakılır.
  static const Duration _waitingPollInterval = Duration(seconds: 10);
  Timer? _waitingPoll;
  bool _waitingCheckInFlight = false;
  bool _replacedByResult = false;

  /// Kendi fotoğrafım/simgem (skor kartında "Sen" avatarı). Yüklenene dek
  /// ya da okunamazsa null: baş harf/simge avatarı çizilir.
  AvatarIdentity? _myIdentity;

  /// Kendi profil adım: "Sen" avatarının baş harfi bundan gelir. Yoksa
  /// avatar "Sen"in S'sini çiziyordu, lobide aynı oyuncu T idi (iki
  /// simülatör turu, 2026-10-22).
  String? _myName;

  /// Soru soru karşılaştırma (2026-10-24, `get_async_duel_review`). Yalnız
  /// bitmiş düelloda ([AsyncDuelResultKind.completed], hükmen dahil)
  /// istenir. `null` + [_reviewLoading] false + [_reviewFailed] false =
  /// bölüm yok (sunucu göçü uygulanmamış ya da düello incelenemez): ne
  /// bölüm ne de rövanş düğmesi çizilir — uygunluğu bilmeden düğme
  /// göstermek boşa basılan bir düğme olurdu.
  AsyncDuelReview? _review;
  bool _reviewLoading = false;
  bool _reviewFailed = false;
  bool _rematchStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runSideEffectsOnce());
    unawaited(_loadMyIdentity());
    if (widget.view.kind == AsyncDuelResultKind.completed) {
      unawaited(_loadReview());
    }
    if (widget.view.kind == AsyncDuelResultKind.waiting) {
      WidgetsBinding.instance.addObserver(this);
      _waitingPoll = Timer.periodic(
        _waitingPollInterval,
        (_) => unawaited(_checkOpponentFinished()),
      );
    }
  }

  @override
  void dispose() {
    _waitingPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkOpponentFinished());
    }
  }

  /// Rakip bitirdiyse bekleme ekranını sonuç ekranıyla değiştirir. Hata
  /// sessizce bir sonraki denemeye bırakılır: bekleme ekranı zaten doğru
  /// bir durum gösteriyor, ağ kesintisi onu bozmamalı.
  Future<void> _checkOpponentFinished() async {
    if (_waitingCheckInFlight || _replacedByResult) return;
    _waitingCheckInFlight = true;
    try {
      final duels = await widget.repository.loadMyAsyncDuels();
      if (!mounted || _replacedByResult) return;
      for (final summary in duels) {
        if (summary.duelId != widget.view.duelId) continue;
        final view = AsyncDuelResultView.fromSummary(summary);
        // Bitti ya da süresi doldu (hükmen dahil): bekleme bitmiştir. Yalnız
        // "bitti"ye bakmak, rakip hiç oynamadan süresi dolan düelloda kum
        // saatini sonsuza dek bırakıyordu (2026-10-28 gece kod denetimi).
        if (view.kind == AsyncDuelResultKind.waiting) return;
        _replacedByResult = true;
        _waitingPoll?.cancel();
        unawaited(
          Navigator.of(context).pushReplacement(
            AppRoute.to(
              AsyncDuelResultScreen(repository: widget.repository, view: view),
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Bir sonraki tıkta yeniden denenir.
    } finally {
      _waitingCheckInFlight = false;
    }
  }

  Future<void> _loadReview() async {
    setState(() {
      _reviewLoading = true;
      _reviewFailed = false;
    });
    try {
      final review = await widget.repository.loadAsyncDuelReview(
        widget.view.duelId,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _reviewLoading = false;
      });
    } catch (error, stack) {
      if (!mounted) return;
      // "Henüz bitmedi / katılımcı değilsin" beklenen reddir: bölüm sessizce
      // yoktur. Gerisi geçici hata sayılır ve "Yeniden dene" gösterilir.
      final expected =
          classifyAsyncDuelReviewError(error) ==
          AsyncDuelReviewError.notAvailable;
      if (!expected) {
        ErrorReporter.record(error, stack, reason: 'async duel review failed');
      }
      setState(() {
        _reviewLoading = false;
        _reviewFailed = !expected;
      });
    }
  }

  /// Rövanş: aynı rakibe arkadaş meydan okuması açar ve oyuna geçer. Sunucu
  /// `can_rematch` demeden düğme zaten kapalıdır; yine de çift dokunuş tek
  /// düello açar.
  void _startRematch(String opponentId) {
    if (_rematchStarted) return;
    _rematchStarted = true;
    unawaited(
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          AsyncDuelPlayScreen(
            repository: widget.repository,
            entry: AsyncDuelEntry.createChallenge(friendId: opponentId),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMyIdentity() async {
    try {
      final identity = await widget.repository.loadAvatarIdentity();
      if (mounted) setState(() => _myIdentity = identity);
      final name = (await widget.repository.getProfileName()).trim();
      if (mounted && name.isNotEmpty) setState(() => _myName = name);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'duel result own identity');
    }
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
    // Hükmen kaybeden: sunucuda sonuç satırı da talep edilecek XP de yok.
    if (view.isForfeitLoss) return;
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
    Widget? scoreboard;
    int xp = 0;
    switch (view.kind) {
      case AsyncDuelResultKind.completed:
        final outcome = view.outcome ?? AsyncDuelOutcome.draw;
        final win = outcome == AsyncDuelOutcome.win;
        // Aramızda engel varsa rakibin adı ve fotoğrafı gizlenir (sunucu da
        // incelemede kimliği vermez); düello sonucu yine görünür.
        final blocked = _review?.opponentBlocked ?? false;
        final rawOpponentName = blocked ? null : view.opponentName;
        final opponentProfile = blocked ? null : view.opponentProfile;
        final opponentName = rawOpponentName == null
            ? context.t(K.asyncDuelOpponent)
            : context.playerDisplayName(
                rawOpponentName,
                tag: opponentProfile?.playerTag,
              );
        xp = _completedXp(view);
        if (view.isForfeit) {
          // Hükmen: karşılaştırılacak skor yok; kahraman tek satır neden
          // söyler (kaybeden ben ya da rakip).
          final forfeitName = rawOpponentName == null
              ? context.t(K.asyncDuelOpponent)
              : opponentName;
          hero = SahneResultHero(
            emblem: win
                ? const SahneResultEmblem.win(size: 64)
                : const SahneResultEmblem.state(icon: AppIcons.flag),
            title: win
                ? context.t(K.asyncDuelWonForfeit)
                : context.t(K.asyncDuelLostForfeit),
            titleRole: win ? SahneRole.gold : null,
            body: win
                ? context.t(K.asyncDuelForfeitOpponentReason, {
                    'name': forfeitName,
                  })
                : context.t(K.asyncDuelForfeitMyReason),
            celebrate: win,
            tone: SahneResultTone.race,
          );
          break;
        }
        if (view.myCorrect != null && view.opponentCorrect != null) {
          scoreboard = Padding(
            padding: const EdgeInsets.symmetric(vertical: SahneSpace.x1),
            child: _DuelScoreboard(
              myName: context.t(K.you),
              myCorrect: view.myCorrect!,
              opponentName: opponentName,
              opponentCorrect: view.opponentCorrect!,
              total: view.total,
              outcome: outcome,
              myIdentity: _myIdentity,
              myRawName: _myName,
              opponentProfile: opponentProfile,
              opponentRawName: rawOpponentName,
            ),
          );
        }
        // 2026-09-29 doğallık: sonuçta iki amblem üst üsteydi (taç/bayrak/
        // terazi + iki avatarlı VS amblemi). Avatarlar yalnız "sen" ve
        // rakibin baş harfiydi; aynı bilgi skor satırında ("Sen 2 – 0
        // Rojda") yazılı. Tek amblem kalır: sonucun kendisi.
        hero = SahneResultHero(
          emblem: switch (outcome) {
            AsyncDuelOutcome.win => const SahneResultEmblem.win(size: 64),
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
          subtitleSize: win ? 32 : null,
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
          body: view.challengeCode == null
              ? context.t(K.asyncDuelWaitingBody)
              : view.invitedName != null
              ? context.t(K.challengeFriendWaitBody, {
                  'name': context.playerDisplayName(
                    view.invitedName!,
                    tag: view.invitedProfile?.playerTag,
                  ),
                })
              : context.t(K.challengeLinkWaitBody),
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
      balanced: true,
      neutral: true,
      stats: scoreboard,
      // Sıfır XP ("+0 XP") gösterilmez: yanlış ya da süresi dolmuş sıfır
      // doğrulu düello ödülsüz biter.
      rewards: xp > 0
          ? SahneResultRewards(
              label: context.t(K.kazanildi),
              xp: xp,
              xpLabel: context.t(K.asyncDuelXp, {'xp': '$xp'}),
            )
          : null,
      sections: [
        ..._reviewSections(context, view),
        if (view.canCancel)
          Padding(
            padding: const EdgeInsets.only(top: SahneSpace.x3),
            child: Center(
              child: SahneButton.text(
                key: const ValueKey('async-duel-result-cancel'),
                label: context.t(K.asyncDuelCancelAction),
                arrow: false,
                onPressed: () => unawaited(_confirmCancel(view)),
              ),
            ),
          ),
      ],
      primary: view.canShareLink
          ? SahneResultAction(
              key: const ValueKey('async-duel-result-share'),
              label: context.t(K.share),
              icon: AppIcons.shareNodes,
              onPressed: () => unawaited(_shareChallenge(view)),
            )
          : canStartNew
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

  /// Rövanş düğmesi + soru soru karşılaştırma. Yalnız bitmiş düelloda;
  /// yüklenirken başlık + gösterge, hatada "Yeniden dene", RPC yoksa hiçbiri.
  List<Widget> _reviewSections(BuildContext context, AsyncDuelResultView view) {
    if (view.kind != AsyncDuelResultKind.completed) return const [];
    final t = SahneTokens.of(context);
    final review = _review;
    if (_reviewLoading) {
      return [
        SahneSectionHeader(title: context.t(K.asyncDuelReviewTitle)),
        const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              key: ValueKey('async-duel-review-loading'),
              strokeWidth: 2,
            ),
          ),
        ),
      ];
    }
    if (_reviewFailed) {
      return [
        SahneSectionHeader(title: context.t(K.asyncDuelReviewTitle)),
        Text(
          context.t(K.asyncDuelReviewLoadFailed),
          key: const ValueKey('async-duel-review-failed'),
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SahneButton.text(
            key: const ValueKey('async-duel-review-retry'),
            label: context.t(K.retry),
            arrow: false,
            onPressed: () => unawaited(_loadReview()),
          ),
        ),
      ];
    }
    if (review == null) return const [];

    final opponentId = review.opponentId;
    // U12 (2026-10-28 tur 4): rövanş yoksa pasif düğme + uyarı çizilmez;
    // ekranda ölü bir eylem ve gerekçe satırı kalıyordu. Yok ise hiçbir şey.
    final canRematch = review.canRematch && opponentId != null;
    final rawName = review.opponentBlocked
        ? null
        : (review.opponentName ?? widget.view.opponentName);
    final opponentLabel = rawName == null
        ? context.t(K.asyncDuelOpponent)
        : context.playerDisplayName(
            rawName,
            tag: widget.view.opponentProfile?.playerTag,
          );
    return [
      if (canRematch)
        Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x1),
          child: SahneButton.secondary(
            buttonKey: const ValueKey('async-duel-result-rematch'),
            label: context.t(K.asyncDuelRematch),
            icon: AppIcons.arrowsRotate,
            expand: true,
            onPressed: () => _startRematch(opponentId),
          ),
        ),
      AsyncDuelReviewSection(review: review, opponentLabel: opponentLabel),
    ];
  }

  /// Kimsenin katılmadığı düelloyu onaydan sonra geri çeker ve ekranı
  /// kapatır (liste dönüşte yenilenir). RPC yoksa ya da çağrı başarısızsa
  /// ekran açık kalır ve nedeni söylenir.
  Future<void> _confirmCancel(AsyncDuelResultView view) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t(K.asyncDuelCancelTitle)),
        content: Text(dialogContext.t(K.asyncDuelCancelBody)),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.t(K.cancel)),
            ),
            confirm: SahneButton.primary(
              key: const ValueKey('async-duel-cancel-confirm'),
              label: dialogContext.t(K.asyncDuelCancelConfirm),
              arrow: false,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cancelled = await widget.repository.cancelAsyncDuel(view.duelId);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.t(cancelled ? K.asyncDuelCancelled : K.asyncDuelCancelFailed),
        ),
      ),
    );
    if (cancelled) navigator.pop();
  }

  /// Meydan okuma bağlantısını sistem paylaşım sayfasıyla gönderir (odalar
  /// aynı mekanizmayı kullanır: `RoomScreen._shareRoomInvite`). Sayfa
  /// açılamazsa metin panoya gider ki davet boşa gitmesin.
  Future<void> _shareChallenge(AsyncDuelResultView view) async {
    final code = view.challengeCode;
    final correct = view.myCorrect;
    if (code == null || correct == null) return;
    final text = context.t(K.challengeShareText, {
      'n': '$correct',
      'link': JoinDeepLink.shareUrl(code),
    });
    final size = MediaQuery.sizeOf(context);
    // iPad paylaşım sayfası bir çıkış noktası ister: alt perdenin ortası.
    final origin = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 48),
      width: 1,
      height: 1,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'async duel share failed');
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.challengeLinkCopied))));
    }
  }
}

/// Tamamlanmış düellonun iki oyunculu skor kartı: avatar, ad, "doğru/7".
///
/// Kusur (7. kurul, Opus + ChatGPT): zafer ekranının alt yarısı boştu; tek
/// "+130 XP" kartı vardı ve "kime karşı, kaç doğru" yalnız başlığın altındaki
/// tek satırda okunuyordu. Modelde soru-soru doğru/yanlış dizisi YOK
/// ([AsyncDuelResultView] yalnız iki doğru sayısı taşır), bu yüzden şerit
/// uydurulmaz: iki oyuncu yan yana, kazananın sayısı Zêr.
class _DuelScoreboard extends StatelessWidget {
  const _DuelScoreboard({
    required this.myName,
    this.myRawName,
    required this.myCorrect,
    required this.opponentName,
    required this.opponentCorrect,
    required this.total,
    required this.outcome,
    this.myIdentity,
    this.opponentProfile,
    this.opponentRawName,
  });

  final String myName;
  final String? myRawName;
  final int myCorrect;
  final String opponentName;
  final int opponentCorrect;
  final int total;
  final AsyncDuelOutcome outcome;
  final AvatarIdentity? myIdentity;
  final PublicProfile? opponentProfile;

  /// Rakibin HAM adı (avatar baş harfi/rengi için; gösterilen ad değil).
  final String? opponentRawName;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget side(
      String name,
      int correct,
      bool winner,
      AvatarIdentity? identity,
      String? avatarName,
    ) => Expanded(
      child: Semantics(
        container: true,
        label: '$name, $correct/$total ${context.t(K.correct)}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar.fromIdentity(
              radius: 28,
              identity: identity,
              displayName: avatarName ?? name,
            ),
            const SizedBox(height: SahneSpace.x2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.captionStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(
              '$correct/$total',
              style: SahneType.headline.copyWith(
                color: winner ? t.goldTx : t.tx,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              context.t(K.correct),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ],
        ),
      ),
    );
    return SahneSurfaceCard(
      key: const ValueKey('async-duel-result-scoreboard'),
      padding: const EdgeInsets.symmetric(
        horizontal: SahneSpace.x4,
        vertical: SahneSpace.x4,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            side(
              myName,
              myCorrect,
              outcome == AsyncDuelOutcome.win,
              myIdentity,
              myRawName,
            ),
            VerticalDivider(width: SahneSpace.x4 * 2 + 1, color: t.line),
            side(
              opponentName,
              opponentCorrect,
              outcome == AsyncDuelOutcome.loss,
              opponentProfile?.avatar,
              opponentRawName,
            ),
          ],
        ),
      ),
    );
  }
}
