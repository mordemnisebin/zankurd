import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/coin_prices.dart';
import '../data/achievement_store.dart';
import '../data/badge_service.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/quiz_result_progress_receipt_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../services/quiz_reward_settlement_service.dart';
import '../models/achievement.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../providers/reduced_motion_provider.dart';
import '../widgets/kilim_board.dart';
import '../widgets/zk_back_button.dart';
import '../widgets/rolling_count.dart';
import '../widgets/kilim_reveal.dart';
import '../widgets/learning_outcome_card.dart';
import '../theme/app_theme.dart';
import '../utils/percent_format.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/review_service.dart';
import '../utils/result_sharer.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/player_avatar.dart';
import '../widgets/roj_mascot.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';
import 'room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Seri kararının sonucu.
///
/// Karar (ve varsa coin harcaması) makbuzun kritik bölümünün DIŞINDA
/// verilir; buradan sonrası yalnız otomatik yerel yazımdır. Bu tip, iki
/// aşama arasındaki tek taşıyıcıdır.
class _StreakOutcome {
  const _StreakOutcome({required this.streak, required this.isNewDay});

  final int streak;
  final bool isNewDay;
}

typedef QuizResultReceiptRunner =
    Future<QuizResultProgressReceiptOutcome> Function({
      required String userId,
      required String roomId,
      required Future<void> Function() action,
    });

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    required this.repository,
    required this.room,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.bestStreak,
    required this.answerRecords,
    required this.coinsAwarded,
    this.opponents = const [],
    this.rewardQueued = false,
    this.dailyCapReached = false,
    this.practice = false,
    this.dailyQuiz = false,
    this.contestId,
    this.resultOwnerUserId,
    this.rewardSettlementState,
    this.receiptRunner,
    this.receiptStages,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int bestStreak;
  final List<AnswerRecord> answerRecords;
  final int coinsAwarded;

  /// Sıfır jeton, günlük tavana varıldığı İÇİN mi?
  ///
  /// Sunucu `claim_solo_reward` yanıtında bunu açıkça söylüyor. İstemci bir
  /// zamanlar yalnız miktarı okuyup gerisini atıyordu: tavana varan oyuncu
  /// "+0 jeton" görüyor ve sebebini hiçbir yerden öğrenemiyordu. Sıfır tek
  /// başına belirsizdir — tavan da sıfır verir, arıza da, göçün henüz
  /// uygulanmamış olması da (2026-08-12 denetimi).
  final bool dailyCapReached;

  /// Bot yarışındaki rakiplerin son durumu; boşsa panel gizlenir.
  final List<Player> opponents;

  /// Ödül sunucuya ulaşamadığı için kuyruğa alındı mı?
  ///
  /// Çevrimdışı bitirilen turda coin rozeti hiç görünmüyordu (rozet yalnız
  /// miktar sıfırdan büyükse çizilir) ve oyuncu turu boşuna oynadığını
  /// sanıyordu. Ödül artık kuyrukta beklediği için bunu söylemek doğru:
  /// kayıp değil, gecikme (2026-07-26).
  final bool rewardQueued;
  final bool practice;
  final bool dailyQuiz;
  final String? contestId;

  /// Yalnız sunucudan geri kazanılan/tamamlanan online sonuç tesliminde
  /// kullanılır. Eski solo ve online çağrılar bu alanları vermeden çalışır.
  final String? resultOwnerUserId;
  final QuizRewardSettlementState? rewardSettlementState;
  final QuizResultReceiptRunner? receiptRunner;

  /// Aşama kaydedici. Testler süreç ölümünü taklit edebilsin diye
  /// enjekte edilebilir; üretimde `SharedPreferences` üzerinden kurulur.
  final QuizResultProgressReceiptStore? receiptStages;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  ZanKurdRepository get repository => widget.repository;
  GameRoom get room => widget.room;
  int get score => widget.score;
  int get correctCount => widget.correctCount;
  int get wrongCount => widget.wrongCount;
  int get totalQuestions => widget.totalQuestions;
  int get bestStreak => widget.bestStreak;
  List<AnswerRecord> get answerRecords => widget.answerRecords;
  int get coinsAwarded => widget.coinsAwarded;
  List<Player> get opponents => widget.opponents;
  bool get practice => widget.practice;
  bool get dailyQuiz => widget.dailyQuiz;

  int _dailyStreak = 0;
  List<Achievement> _newAchievements = const [];
  Map<String, MasteryLevel> _promotions = const {};
  int _earnedXP = 0;
  _StreakOutcome? _pendingStreak;
  bool _showConfetti = false;
  bool _ackAttempted = false;
  bool _newRoomLoading = false;

  Future<void> _openNewRoom() async {
    if (_newRoomLoading) return;
    if (widget.room.entryFee > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t(K.newRoomAction)),
          content: Text(
            context.t(K.newRoomFeeConfirm, {
              'amount': '${widget.room.entryFee}',
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t(K.cancel)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.t(K.continueAction)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _newRoomLoading = true);
    try {
      final newRoom = await widget.repository.createOnlineRoom(
        category: widget.room.category,
        secondsPerQuestion: widget.room.secondsPerQuestion,
        questionCount: widget.room.questionCount,
        entryFee: widget.room.entryFee,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          RoomScreen(repository: widget.repository, initialRoom: newRoom),
        ),
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'new room create failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.roomOpenFailed))));
    } finally {
      if (mounted) setState(() => _newRoomLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Sonuç ekranının kendisi ilerleme yazımına bağlı değildir: skor,
    // doğru/yanlış ve cevap listesi zaten widget parametrelerinden gelir.
    // Yazım zinciri (seri, rozet, ustalık, görev, XP, mağaza değerlendirmesi)
    // yedi ayrı store ve bir platform kanalı üzerinden gider; herhangi
    // birinden kaçan istisna `initState`ten yukarı çıkıp tüm ekranı
    // düşürüyordu (2026-07-31 denetimi). Hata bildirilir, ekran yaşar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_deliverResult());
    });
    if (widget.contestId != null) {
      _claimContestReward();
    }
  }

  Future<void> _deliverResult() async {
    final ownerId = widget.resultOwnerUserId?.trim();
    final roomId = widget.room.id?.trim();
    final rewardState = widget.rewardSettlementState;
    final hasOwner = ownerId != null && ownerId.isNotEmpty;
    final hasRewardState = rewardState != null;

    if (hasOwner != hasRewardState ||
        ((hasOwner || hasRewardState) && (roomId == null || roomId.isEmpty))) {
      ErrorReporter.record(
        const FormatException('Incomplete online result delivery context.'),
        StackTrace.current,
        reason: 'quiz result delivery context',
      );
      return;
    }

    if (!hasOwner && !hasRewardState) {
      await _runProgressSafely();
      return;
    }
    if (!_hasValidOnlineResultContext(ownerId!) ||
        !_isCurrentResultOwner(ownerId)) {
      return;
    }

    final stages = widget.receiptStages ?? await _defaultStageRecorder();
    // Bu noktadan sonra oda kimliği kesin: yukarıdaki bağlam kontrolü
    // eksik/tutarsız teslimatı zaten elemişti.
    final resultRoomId = roomId!;

    // Aşama 1 — kullanıcı kararı. Makbuzun kritik bölümünün DIŞINDA.
    try {
      final resumed = await stages?.read(userId: ownerId, roomId: resultRoomId);
      if (resumed?.isTerminal != true) {
        final streak = await _resolveStreakDecision(
          resumed: resumed,
          // Makbuz anahtarıyla AYNI kimlik: tahsilat da, makbuz da aynı
          // sonuca bağlı olduğu için ikisi tek bir değişmezden türer.
          idempotencyKey: QuizResultProgressReceiptStore.keyFor(
            userId: ownerId,
            roomId: resultRoomId,
          ),
          recordStage: stages == null
              ? null
              : (stage, {bool freezeRequested = false}) => stages.write(
                  userId: ownerId,
                  roomId: resultRoomId,
                  receipt: QuizResultReceipt(
                    stage: stage,
                    freezeRequested: freezeRequested,
                  ),
                ),
        );
        _pendingStreak = streak;
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz result streak decision');
    }

    // Aşama 2 — otomatik yerel ilerleme. Yalnız burada kritik bölüm var.
    QuizResultProgressReceiptOutcome receiptOutcome;
    try {
      final runner = widget.receiptRunner ?? _runDefaultReceipt;
      receiptOutcome = await runner(
        userId: ownerId,
        roomId: resultRoomId,
        action: () async {
          if (!_isCurrentResultOwner(ownerId)) {
            throw StateError('Result owner changed before local progress.');
          }
          await _recordProgressAndAnalytics(_pendingStreak);
          if (!_isCurrentResultOwner(ownerId)) {
            throw StateError('Result owner changed during local progress.');
          }
        },
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz result receipt');
      return;
    }

    // `blockedProcessing` artık "sonsuza dek kilitli" değil, "önceki yazım
    // kesildiği için atlandı" demektir. Yerel ilerleme tekrarlanmaz —
    // depolar idempotent olmadığı için XP ve rozet ikiye katlanırdı — ama
    // akış burada durmaz.
    //
    // Durmaması gerekiyor çünkü ONAY ayrı bir güvenlik özelliğidir ve
    // sunucuda idempotenttir: `room_result_receipts` birincil anahtarı
    // `(room_id, player_id)`. Onayı belirsiz bir yerel yazım yüzünden
    // sonsuza dek engellemek, hiçbir şeyi kurtarmadan kurtarma ekranını
    // her soğuk açılışta geri getiriyordu (2026-08-03).
    if (receiptOutcome == QuizResultProgressReceiptOutcome.blockedProcessing) {
      ErrorReporter.record(
        StateError(
          'Result progress receipt was interrupted; local progress skipped.',
        ),
        StackTrace.current,
        reason: 'quiz result receipt incomplete',
      );
    }

    if (rewardState != QuizRewardSettlementState.claimed ||
        !_isCurrentResultOwner(ownerId) ||
        _ackAttempted) {
      return;
    }

    // Aşama 3 — sunucu onayı. Tek gerçekten yeniden denenebilir adım.
    _ackAttempted = true;
    try {
      await repository.acknowledgeRoomResult(widget.room);
      await stages?.write(
        userId: ownerId,
        roomId: resultRoomId,
        receipt: const QuizResultReceipt(
          stage: QuizResultReceiptStage.completed,
        ),
      );
    } catch (error, stack) {
      // Makbuz `acknowledgementPending` kalır; sonraki açılışta yeniden
      // denenir. Sunucu idempotent olduğu için bu güvenlidir.
      ErrorReporter.record(error, stack, reason: 'quiz result acknowledge');
    }
  }

  Future<QuizResultProgressReceiptStore?> _defaultStageRecorder() async {
    try {
      return QuizResultProgressReceiptStore(
        await SharedPreferences.getInstance(),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz result receipt stages');
      return null;
    }
  }

  Future<QuizResultProgressReceiptOutcome> _runDefaultReceipt({
    required String userId,
    required String roomId,
    required Future<void> Function() action,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return QuizResultProgressReceiptStore(
      preferences,
    ).runOnce(userId: userId, roomId: roomId, action: action);
  }

  bool _isCurrentResultOwner(String ownerId) {
    final currentUserId = repository.currentUserId?.trim();
    return currentUserId != null &&
        currentUserId.isNotEmpty &&
        currentUserId == ownerId;
  }

  bool _hasValidOnlineResultContext(String ownerId) {
    final playerIds = widget.room.players
        .map((player) => player.id?.trim() ?? '')
        .toList(growable: false);
    final hasValidPlayers =
        playerIds.length == 2 &&
        playerIds.every((id) => id.isNotEmpty) &&
        playerIds.toSet().length == 2 &&
        playerIds.where((id) => id == ownerId).length == 1;
    if (widget.room.status == RoomStatus.finished && hasValidPlayers) {
      return true;
    }
    ErrorReporter.record(
      const FormatException('Invalid online result room context.'),
      StackTrace.current,
      reason: 'quiz result delivery context',
    );
    return false;
  }

  Future<void> _runProgressSafely() async {
    try {
      await _recordProgressAndAnalytics(await _resolveStreakDecision());
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz result progress');
    }
  }

  Future<void> _recordProgressAndAnalytics(
    _StreakOutcome? streakOutcome,
  ) async {
    await _recordProgress(streakOutcome ?? await _fallbackStreak());
    try {
      await repository.logAnalyticsEvent('quiz_complete', {
        'category': widget.room.category,
        'correct_count': widget.correctCount,
        'total_questions': widget.totalQuestions,
        'score': widget.score,
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz result analytics');
    }
  }

  Future<void> _claimContestReward() async {
    final id = widget.contestId;
    if (id == null) return;
    try {
      // Skoru kaydet + sıralama; sonra rank/badge ödülünü talep et.
      await repository.submitContestEntry(
        contestId: id,
        correctCount: widget.correctCount,
      );
      await repository.claimContestReward(id);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz_result_save');
      // Silent fail — reward already claimed or network issue
    }
  }

  /// Kırılacak günlük seri için coin karşılığı dondurma teklif eder.
  /// Ödeme yapılıp seri korunursa yeni seri değerini, aksi halde null döner.
  // Sunucu RPC'siyle eşitliği bekçili tek kaynak; üç ayrı kopya vardı.
  static const _streakFreezeCost = CoinPrices.streakFreeze;

  /// Karar adımı hata verdiyse seri yine de kaydedilmeli.
  ///
  /// Aksi hâlde ilerlemeye `streak: 0` giderdi ve rozet/görev hesabı, hiç
  /// oynanmamış gibi yazılırdı — kullanıcının hatası olmayan bir hata,
  /// sessizce serisini sıfırlamış görünürdü. Dondurma teklifi olmayan
  /// yoldaki davranışın aynısı uygulanır.
  Future<_StreakOutcome> _fallbackStreak() async {
    final store = await StreakStore.load();
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final isNewDay = store.lastDay != todayKey;
    return _StreakOutcome(streak: await store.recordPlay(), isNewDay: isNewDay);
  }

  /// Seri kararını, makbuzun kritik bölümünün DIŞINDA çözer.
  ///
  /// Buradaki iki adım da kritik bölümde duramaz:
  ///
  /// * Diyalog sınırsız süre kullanıcı girdisi bekler. Kritik bölümde
  ///   beklerse "oyuncu cevap vermeden uygulamayı kapattı" makbuzu kalıcı
  ///   olarak kilitler.
  /// * `spend_coins` sunucuda idempotent DEĞİLDİR (`streak_freeze` için
  ///   dedup anahtarı yok, her çağrı yeni bir `-50` satırı yazar). Bu
  ///   yüzden hiçbir koşulda otomatik tekrarlanmamalıdır.
  ///
  /// [recordStage] verilirse her geçiş diske yazılır; kesinti sonrası
  /// nerede kalındığı okunabilir. Verilmezse (çevrimdışı/yerel quiz)
  /// makbuz yoktur ve karar sıradan biçimde alınır.
  Future<_StreakOutcome> _resolveStreakDecision({
    Future<void> Function(QuizResultReceiptStage stage, {bool freezeRequested})?
    recordStage,
    QuizResultReceipt? resumed,
    // Sonuç makbuzunun değişmez kimliği: `<user>:<room>`. Tahsilatın
    // idempotency anahtarı budur, yani aynı sonuç için yapılan her tekrar
    // aynı anahtarı taşır ve sunucu ikinci kez çekmez.
    String idempotencyKey = '',
  }) async {
    final isPremium = context.read<PremiumService>().isPremium;
    final streakStore = await StreakStore.load();
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final isNewDay = streakStore.lastDay != todayKey;

    // Kesintiden sonra yan etkili aşamalar ASLA tekrarlanmaz.
    switch (resumed?.stage) {
      // Coin isteği gönderilmiş ama sonucu bilinmiyor. Tekrar harcamak
      // yerine ileri çözülür: coin en fazla bir kez gider.
      case QuizResultReceiptStage.freezeApplying:
        ErrorReporter.record(
          StateError('Streak freeze spend outcome is unknown after restart.'),
          StackTrace.current,
          reason: 'streak_freeze_uncertain',
        );
        await recordStage?.call(QuizResultReceiptStage.freezeSkipped);
        return _StreakOutcome(
          streak: await streakStore.recordPlay(),
          isNewDay: isNewDay,
        );
      // Dondurma zaten uygulanmış; seri yeniden yazılmaz.
      case QuizResultReceiptStage.freezeApplied:
      case QuizResultReceiptStage.freezeSkipped:
      case QuizResultReceiptStage.progressApplying:
      case QuizResultReceiptStage.progressApplied:
      case QuizResultReceiptStage.acknowledgementPending:
      case QuizResultReceiptStage.completed:
        // Yeniden yazma yok: bu aşamalarda seri zaten bu turda
        // uygulanmıştır, yalnız görünen değeri okunur.
        return _StreakOutcome(
          streak: streakStore.effectiveStreak(now: today),
          isNewDay: isNewDay,
        );
      case null:
      case QuizResultReceiptStage.pendingUserDecision:
      case QuizResultReceiptStage.decisionRecorded:
        break;
    }

    if (!streakStore.willBreakOnPlay()) {
      await recordStage?.call(QuizResultReceiptStage.freezeSkipped);
      return _StreakOutcome(
        streak: await streakStore.recordPlay(),
        isNewDay: isNewDay,
      );
    }

    // Premium: ücretsiz ve otomatik; kullanıcı kararı yok.
    if (isPremium) {
      await recordStage?.call(QuizResultReceiptStage.freezeApplying);
      await streakStore.addFreeze();
      final streak = await streakStore.freezeAndRecordPlay();
      await recordStage?.call(QuizResultReceiptStage.freezeApplied);
      return _StreakOutcome(streak: streak, isNewDay: isNewDay);
    }

    // Karar bekleniyor. Bu aşamada hiçbir yan etki yoktur, bu yüzden
    // kesinti olursa soruyu yeniden sormak güvenlidir.
    await recordStage?.call(QuizResultReceiptStage.pendingUserDecision);
    final wantsFreeze = await _askForStreakFreeze();

    // Karar, UYGULANMADAN önce yazılır: aksi hâlde coin harcama ile
    // kararın kendisi aynı kesintide birlikte kaybolur.
    await recordStage?.call(
      QuizResultReceiptStage.decisionRecorded,
      freezeRequested: wantsFreeze,
    );
    if (!wantsFreeze) {
      await recordStage?.call(QuizResultReceiptStage.freezeSkipped);
      return _StreakOutcome(
        streak: await streakStore.recordPlay(),
        isNewDay: isNewDay,
      );
    }

    await recordStage?.call(
      QuizResultReceiptStage.freezeApplying,
      freezeRequested: true,
    );
    final charge = await _applyPaidStreakFreeze(streakStore, idempotencyKey);
    await recordStage?.call(
      charge.streak == null
          ? QuizResultReceiptStage.freezeSkipped
          : QuizResultReceiptStage.freezeApplied,
    );
    return _StreakOutcome(
      streak: charge.streak ?? await streakStore.recordPlay(),
      isNewDay: isNewDay,
    );
  }

  /// Yalnız sorar. Hiçbir yan etkisi yoktur — bu yüzden kesildiğinde
  /// yeniden sorulabilir.
  Future<bool> _askForStreakFreeze() async {
    if (!mounted) return false;
    int balance;
    try {
      balance = await repository.loadCoinBalance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_freeze_balance');
      return false;
    }
    if (!mounted || balance < _streakFreezeCost) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t(K.streakBreaking)),
        content: Text(
          context.t(K.streakFreezeAsk, {'cost': '$_streakFreezeCost'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.t(K.streakLetGo)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.t(K.streakFreezeAction, {'cost': '$_streakFreezeCost'}),
            ),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// Coini harcar ve dondurmayı uygular.
  ///
  /// Çağıran, bu çağrıdan ÖNCE `freezeApplying` aşamasını yazmış olmalıdır.
  /// Tahsilat, sonuç makbuzunun kimliğinden türeyen değişmez bir
  /// idempotency anahtarıyla yapılır: cevabı kaybolan bir istek aynı
  /// anahtarla tekrarlandığında sunucu yeni bir hareket yaratmaz.
  ///
  /// Dönen [StreakFreezeChargeResult.idempotent] bilgisi çağırana taşınır;
  /// göç uygulanmamış bir sunucuda eski (idempotent OLMAYAN) yola
  /// düşüldüğü için belirsiz tahsilat yine tekrarlanmamalıdır.
  Future<({int? streak, bool idempotent})> _applyPaidStreakFreeze(
    StreakStore store,
    String idempotencyKey,
  ) async {
    StreakFreezeChargeResult charge;
    try {
      charge = await repository.spendStreakFreeze(
        idempotencyKey: idempotencyKey,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_freeze_spend');
      return (streak: null, idempotent: false);
    }
    if (!charge.succeeded) {
      return (streak: null, idempotent: charge.idempotent);
    }
    // Coin ödendi: bir jeton verilip hemen uygulanır (seri +1 devam eder).
    await store.addFreeze();
    return (
      streak: await store.freezeAndRecordPlay(),
      idempotent: charge.idempotent,
    );
  }

  Future<void> _recordProgress(_StreakOutcome streakOutcome) async {
    // Dil, await'lerden önce okunur: bildirim metni async boşluğun
    // ötesinde `context`e dokunmadan seçilsin.
    final isKuNow = context.isKu;
    // Seri kararı bu adımdan ÖNCE, kritik bölümün dışında verildi ve
    // uygulandı. Buradan sonrası yalnız otomatik yerel yazımlardır.
    final streak = streakOutcome.streak;
    final isNewDay = streakOutcome.isNewDay;
    final mistakeStore = await MistakeStore.load();
    final achievementStore = await AchievementStore.load();
    final newAchievements = await achievementStore.recordQuizResult(
      category: room.category,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      bestStreak: bestStreak,
      dailyStreak: streak,
      userScore: score,
      practice: practice,
      dailyQuiz: dailyQuiz,
      remainingMistakes: mistakeStore.count,
      opponents: opponents,
    );

    // `BadgeService`in beş rozeti (streak_30, questions_500,
    // questions_1000, perfect_game, speed_demon) hiçbir yerden
    // çağrılmıyordu — `evaluate*` metotları vardı ama uygulama kodu
    // hiçbirini kullanmıyordu. Sonuç: bu beş rozet kullanıcı ne
    // yaparsa yapsın asla açılamıyordu (2026-08-14 denetimi). Tur
    // sonucunun zaten hesapladığı verilerle (seri, toplam soru,
    // doğru/toplam, yanıt süreleri) burada değerlendirilirler.
    final badgeService = await BadgeService.load();
    await badgeService.evaluateStreakBadges(streak);
    await badgeService.evaluateQuestionBadges(
      achievementStore.answeredQuestions,
    );
    await badgeService.evaluatePerfectGame(correctCount, totalQuestions);
    if (totalQuestions > 0) {
      final totalResponseMs = answerRecords.fold<int>(
        0,
        (sum, record) => sum + (record.responseMs ?? 0),
      );
      await badgeService.evaluateSpeedDemon(
        Duration(milliseconds: totalResponseMs),
      );
    }

    final masteryStore = await MasteryStore.load();
    final correctByCategory = <String, int>{};
    for (final record in answerRecords) {
      if (record.isCorrect) {
        correctByCategory[record.category] =
            (correctByCategory[record.category] ?? 0) + 1;
      }
    }
    final promotions = <String, MasteryLevel>{};
    for (final entry in correctByCategory.entries) {
      final newLevel = await masteryStore.addCorrect(entry.key, entry.value);
      if (newLevel != null) promotions[entry.key] = newLevel;
    }

    final missionStore = await DailyMissionStore.load();
    final completedMissions = await missionStore.reportQuizCompleted(
      correctAnswers: correctCount,
      category: room.category,
      streakAlive: streak > 0,
    );
    // XP ve Seviye Hesaplaması
    int earnedXP = (correctCount * 10) + 50;
    if (isNewDay) earnedXP += 30;
    earnedXP += completedMissions.fold(
      0,
      (sum, mission) => sum + mission.xpReward,
    );
    earnedXP += promotions.length * 200;

    final xpStore = await XPStore.load();
    final leveledUp = await xpStore.addXP(earnedXP);

    // Aynı XP sunucuya da bildirilir. Cihazdaki `XPStore` seviyeyi ve
    // ilerleme çubuğunu besler; `profiles.xp` ise sıralamanın, toplam puanın
    // ve lig rozetinin kaynağıdır. İkincisine hiç yazılmıyordu: RPC
    // 2026-07-25'te yazıldı ve hiçbir istemci kodu onu çağırmadı, dolayısıyla
    // üretimde her oyuncunun toplam puanı sıfırdı ve profil «Sıralama» ile
    // «Toplam Puan» yerine kalıcı olarak «—» gösteriyordu.
    //
    // BEKLENMEZ: miktar cihazda zaten yazıldı, sunucu yazımı en iyi çabadır
    // ve sonucu ekranın akışını durdurmamalı. Miktarı sunucu sınırlar.
    unawaited(repository.awardXp(earnedXP));

    // Doğru anda (yeterli quiz + iyi skor) bir kez mağaza değerlendirmesi iste.
    final accuracyPercent = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    final reviewService = await ReviewService.load();
    await reviewService.recordQuizCompletion(accuracyPercent: accuracyPercent);

    // Bugün oynandı: akşamki "hiç oynamadın" uyarısı susar, yarınki kurulur.
    // Uyarı `DateTimeComponents.time` ile her gün tekrarladığı ve gövdesi
    // koşulsuz olduğu için, iptal edilmezse oynanan günlerde de yalan
    // söylerdi (2026-07-31 denetimi).
    await NotificationService.instance?.refreshStreakWarningAfterPlay(
      isKu: isKuNow,
    );

    AnalyticsService.instance.logQuizComplete(
      category: room.category,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      xpEarned: earnedXP,
    );
    if (newAchievements.any(
      (achievement) => achievement.id == AchievementIds.firstGame,
    )) {
      AnalyticsService.instance.logFirstQuizCompleted();
    }
    for (final achievement in newAchievements) {
      AnalyticsService.instance.logBadgeEarned(achievement.id);
    }

    if (mounted) {
      setState(() {
        _dailyStreak = streak;
        _newAchievements = newAchievements;
        _promotions = promotions;
        _earnedXP = earnedXP;
        _showConfetti = promotions.isNotEmpty;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final mission in completedMissions) {
          MissionToast.show(context, mission);
        }
        if (leveledUp) {
          _showLevelUpDialog(context, xpStore.currentLevel);
        }
      });
    }
  }

  void _showLevelUpDialog(BuildContext context, int newLevel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t(K.levelUpTitle),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surfaceHiColor(context),
                      AppTheme.surfaceColor(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.medal,
                        color: AppColors.onAccentTint(context, AppTheme.gold),
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t(K.levelUpTitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(K.yeniBirSeviyeyeUlastin),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        context.t(K.seviyeP, {'p0': '$newLevel'}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSolid(AppTheme.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppColors.onSolid(AppTheme.gold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop({'score': score, 'correct': correctCount}),
                        child: Text(
                          context.t(K.devamEt2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const _resultPrimaryActionStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  /// Primary CTA'nın tek satırda yan eylemlerle birlikte güvenle yaşayıp
  /// yaşayamayacağını gerçek label genişliğiyle ölçer.
  ///
  /// Sabit bir cihaz breakpoint'i yerine mevcut genişlik + text scale
  /// kullanılır. Dar veya büyük metinli düzende primary üstte tam genişlikte
  /// kalır; yan eylemler aşağıdaki Wrap'e iner. Böylece ana label küçülmez,
  /// kesilmez ve ekran okuyucu sırası da primary → secondary olarak korunur.
  bool _shouldStackResultActions(
    BuildContext context, {
    required double availableWidth,
    required String primaryLabel,
    required int secondaryCount,
  }) {
    if (secondaryCount == 0) return false;

    final painter = TextPainter(
      text: TextSpan(
        text: primaryLabel,
        style: _resultPrimaryActionStyle.copyWith(
          fontFamily: AppTypography.fontFamily,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    // Icon + gap + horizontal button padding. Bu chrome mevcut FilledButton
    // anatomisinin güvenli üst sınırıdır; label'ın sığmadığı durumda
    // breakpoint tahmini yapmak yerine ölçümü stacked karara dönüştürür.
    const primaryChrome = 80.0;
    const sideActionWidth = 76.0;
    const actionGap = 10.0;
    final primaryNeeded = painter.width + primaryChrome;
    final secondaryNeeded = secondaryCount * sideActionWidth + actionGap;
    return primaryNeeded + secondaryNeeded > availableWidth;
  }

  Widget _buildResultPrimaryAction({
    required String key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppTheme.glowShadow(
          AppTheme.primaryCtaColor(context),
          intensity: 0.28,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: FilledButton.icon(
          key: ValueKey(key),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryCtaColor(context),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            elevation: 0,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: _resultPrimaryActionStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildResultActions({
    required String primaryKey,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onPrimaryPressed,
    required List<Widget> secondaryActions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = _shouldStackResultActions(
          context,
          availableWidth: constraints.maxWidth,
          primaryLabel: primaryLabel,
          secondaryCount: secondaryActions.length,
        );
        final primary = _buildResultPrimaryAction(
          key: primaryKey,
          label: primaryLabel,
          icon: primaryIcon,
          onPressed: onPrimaryPressed,
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (secondaryActions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: secondaryActions,
                  ),
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primary),
            if (secondaryActions.isNotEmpty) ...[
              const SizedBox(width: 10),
              ...secondaryActions,
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unanswered = (totalQuestions - correctCount - wrongCount).clamp(
      0,
      totalQuestions,
    );
    final wrongRecords = answerRecords
        .where((record) => !record.isCorrect && !record.isUnanswered)
        .toList(growable: false);
    final learningOutcome = LearningOutcome.fromRecords(answerRecords);
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    final isOnlineRoom = room.id != null;
    final nextActionLabel = context.t(isOnlineRoom ? K.home : K.playAgain);
    final nextActionIcon = isOnlineRoom
        ? AppIcons.house
        : AppIcons.arrowRotateLeft;

    void completeResultAction() {
      // Quiz rotası sonuç ekranıyla değiştirilir; çevrimiçi turda tek `pop`
      // bitmiş RoomScreen'i yeniden gösteriyordu. İlk rotaya dönmek solo
      // tekrar davranışını korurken çevrimiçi odanın eski rotasını temizler.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    void openReview(List<AnswerRecord> records) {
      Navigator.of(
        context,
      ).push(AppRoute.to(ReviewScreen(records: records, room: room)));
    }

    final primaryResultKey = wrongRecords.isNotEmpty
        ? 'result-primary-review-mistakes'
        : 'result-play-again-button';
    final primaryResultLabel = wrongRecords.isNotEmpty
        ? context.t(K.reviewMistakes)
        : nextActionLabel;
    final primaryResultIcon = wrongRecords.isNotEmpty
        ? AppIcons.squareCheck
        : nextActionIcon;
    final secondaryResultActions = <Widget>[
      if (isOnlineRoom)
        _ResultSideAction(
          key: const ValueKey('result-new-room-button'),
          icon: AppIcons.circlePlus,
          label: context.t(K.newRoom),
          onTap: _newRoomLoading ? null : _openNewRoom,
        ),
      if (wrongRecords.isNotEmpty)
        _ResultSideAction(
          key: const ValueKey('result-play-again-button'),
          icon: nextActionIcon,
          label: nextActionLabel,
          onTap: completeResultAction,
        ),
      _ResultSideAction(
        key: const ValueKey('result-share-button'),
        icon: AppIcons.shareNodes,
        label: context.t(K.share),
        onTap: () async {
          await ResultSharer.share(
            context,
            isKu: context.isKu,
            score: score,
            correctCount: correctCount,
            totalQuestions: totalQuestions,
            bestStreak: bestStreak,
            category: room.category,
            results: [for (final record in answerRecords) record.isCorrect],
          );
          final earned = await ResultSharer.claimDailyShareReward();
          if (earned && context.mounted) {
            HapticFeedback.mediumImpact();
            unawaited(repository.awardSpinCoins());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t(K.shareRewardEarned)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    ];

    final is1v1 = opponents.length == 1;
    bool isWinner = false;
    bool isDraw = false;
    if (is1v1) {
      final opp = opponents.first;
      if (score > opp.score) {
        isWinner = true;
      } else if (score == opp.score) {
        isDraw = true;
      }
    }

    // 1v1 sonuç gradyanları: AppTheme.correctDeep / wrongDeep token'ları
    // kullanılır (M-11 — hardcoded Color literal → adlandırılmış sabit).
    final headerGradient = is1v1
        ? (isWinner
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.correctHeader, AppTheme.correctDeep],
                )
              : isDraw
              // Berabere gradyanı bir zamanlar `surfaceHiColor` /
              // `surfaceColor` idi — temaya göre değişen yüzey tonları.
              // Açık temada ikisi de neredeyse beyaz, üstündeki başlık ve
              // skor ise sabit `Colors.white`: kart okunmuyordu. Kazanan
              // ve kaybeden hâlleri tema-bağımsız KOYU tonlar aldığı için
              // (correct/correctDeep, wrong/wrongDeep) kusur yalnız
              // beraberede doğuyordu, yani ancak iki oyuncu aynı skorla
              // bitirdiğinde. 2026-08-01'de canlı 0-0 biten oda maçında
              // görüldü.
              //
              // Berabere ne zafer ne yenilgi: yeşil ve kırmızının yanına
              // nötr, tema-bağımsız bir koyu ton konuyor. Beyaz metin
              // ikisinde de 12:1'in üstünde.
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceHi, AppTheme.surface],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.wrongHeader, AppTheme.wrongDeep],
                ))
        // Solo sonuç vitrini kimlik anıdır, eylem değil; turuncu yalnız
        // "sonraki adım" butonunda kalır — bu kural korunuyor.
        //
        // Değişen, iki ucun KARIŞIMI: marka yeşilinden koyu turuncuya inen
        // gradyan gerçek cihazda kutlama değil çamur veriyordu (yeşil→kahve
        // geçişi, 2026-08-03 görsel denetimi). Rengîn kutlama yüzeyi
        // mücevher mantığını kullanır: derin mürekkepten ametiste. İki uç da
        // beyaz metinle çok yüksek kontrast verir (15.67:1 ve 7.19:1) ve
        // hiçbiri eylem turuncusuyla yarışmaz.
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17233B), Color(0xFF6A38BE)],
          );

    final borderColor = is1v1
        ? (isWinner
              ? AppTheme.correct.withValues(alpha: 0.55)
              : isDraw
              ? AppTheme.borderColor(context)
              : AppTheme.wrong.withValues(alpha: 0.55))
        : AppTheme.brand.withValues(alpha: 0.45);

    final headerTitle = is1v1
        ? (isWinner
              ? context.t(K.youWon)
              : isDraw
              ? context.t(K.draw)
              : context.t(K.youLost))
        : context.t(K.raceFinished);

    final headerIcon = is1v1
        ? (isWinner
              ? AppIcons.trophy
              : isDraw
              ? AppIcons.scaleBalanced
              : AppIcons.faceFrown)
        : AppIcons.flag;

    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.isLight(context)
                  ? AppTheme.lightTextPrimary.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.isLight(context)
                    ? AppTheme.lightTextPrimary.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: ZkBackButton(
              onPressed: isOnlineRoom ? completeResultAction : null,
              color: AppTheme.isLight(context)
                  ? AppTheme.lightTextPrimary
                  : Colors.white,
            ),
          ),
        ),
        title: Text(context.t(K.resultTitle)),
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                // Sonuçtaki açıklamalar, öğrenme özeti ve birincil eylem
                // tek bir öğrenme yüzeyidir. Kısa ekranlarda da
                // erişilebilirlik ağacına birlikte girsinler; kayıt sayısı
                // oda soru sayısıyla sınırlı olduğu için geniş önbellek
                // güvenlidir.
                scrollCacheExtent: const ScrollCacheExtent.pixels(2500),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    // Kutlama katmanı: kilim dokusu başlığın arkasında
                    // merkezden dışa açılır.
                    //
                    // Tek kutlama kanalı konfetiydi; konfeti her uygulamada
                    // aynıdır ve ZanKurd'a ait bir şey söylemez (2026-07-25
                    // görsel denetimi). Marka dili zaten kilim motifine
                    // dayanıyor — kutlama da aynı dili konuşur.
                    //
                    // Yalnız kutlanacak bir sonuç varken çizilir: 1v1'de
                    // galibiyet, solo turda en az yarısı doğru. Kaybedilen
                    // turda kutlama deseni açmak, sonucu yanlış okur.
                    child: KilimReveal(
                      active: is1v1
                          ? isWinner
                          : (totalQuestions > 0 &&
                                correctCount * 2 >= totalQuestions),
                      // Sağlayıcı yoksa (ör. bu ekranı izole eden widget
                      // testleri) kutlama sessizce animasyonsuz çizilir.
                      // Dekoratif bir katman, barındırıldığı ağaç eksik
                      // diye ekranı çökertmemeli.
                      reducedMotion:
                          context
                              .watch<ReducedMotionProvider?>()
                              ?.reduceMotion ??
                          false,
                      color: kilimRevealColorFor(context, onBrand: !isDraw),
                      child: Container(
                        key: const ValueKey('result-score-header'),
                        decoration: BoxDecoration(
                          gradient: headerGradient,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: -8,
                              top: -38,
                              child: IgnorePointer(
                                child: Icon(
                                  headerIcon,
                                  size: 130,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            // 2026-07-23 M33: Roj maskotu sonuç ekranında hiç
                            // yoktu — marka kimliği en duygusal andan
                            // (skoru görme) eksikti. Skora göre ruh hâli
                            // değişir; yoğun bilgi sütununu bozmasın diye
                            // sol üst köşede küçük bir rozet olarak durur.
                            Positioned(
                              left: 0,
                              top: 0,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 0.85,
                                  child: RojMascot(
                                    size: 36,
                                    mood: accuracy >= 80
                                        ? RojMood.celebrate
                                        : accuracy >= 40
                                        ? RojMood.happy
                                        : RojMood.thinking,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Header row: icon + title
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        headerIcon,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        context.upper(headerTitle),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                // Mockup 8: doğruluk kademesine göre 3 yıldız
                                // (bu boşluk daha önce boştu, net yükseklik
                                // artışı yok — ~450px doğrulanmış).
                                // Yıldızlar turuncu hero üzerinde duruyor:
                                // altın (#E7B53C) turuncuda ~1.3:1, boş yıldız
                                // beyaz@0.18 ile görünmez haldeydi — skorun en
                                // özet göstergesi okunmuyordu (2026-07-22 UX
                                // denetimi). Koyu yarı saydam bir hap zemin
                                // hem doluyu hem boşu ayrıştırıyor.
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.heroScrim(),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        _ScoreStar(
                                          // Doluluk, rengin yanında ikinci
                                          // ve daha güçlü bir işarettir:
                                          // renk körü bir oyuncu için tek
                                          // ayırt edici olan da odur.
                                          earned:
                                              i <
                                              (accuracy >= 80
                                                  ? 3
                                                  : accuracy >= 50
                                                  ? 2
                                                  : 1),
                                          size: i == 1 ? 30 : 22,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                // BIG score number — sayarak çıkar.
                                //
                                // Skor birden beliriyordu; kazanma anının
                                // tamamı tek karede bitiyor ve geriye
                                // okunacak bir sayı kalıyordu. Tırmanışı
                                // izlemek kazanmanın kendisidir (bkz.
                                // `RollingCount`). Hareket azaltma açıkken
                                // sayım yapılmaz.
                                RollingCount(
                                  key: const ValueKey('result-score-count'),
                                  value: score,
                                  style: AppTypography.display.copyWith(
                                    color: Colors.white,
                                    fontSize: 72,
                                    height: 0.95,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                // Category & accuracy on one line
                                Text(
                                  '${CategoryNames.localized(room.category, context.isKu)} '
                                  '· ${context.percent(accuracy)} '
                                  '${context.t(K.accuracyLower)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                // Turda dokunan kilim.
                                //
                                // Sonuç ekranı doğru SAYISINI söylüyordu
                                // ("%70 doğruluk") ama turun kendisini
                                // göstermiyordu: hangi soruda takıldığı,
                                // seri mi tutturduğu yoksa dağınık mı
                                // gittiği tek bakışta okunmuyordu. Şerit
                                // soru ekranındakiyle AYNI nesnedir; oyuncu
                                // tur boyunca onun dokunuşunu izler,
                                // burada bitmiş hâlini görür.
                                //
                                // `showCurrent` kapalı: tur bitti, "sıradaki
                                // soru" vurgusu yalan olurdu.
                                //
                                // Renkler hero'ya göre elle verilir; tema
                                // yüzeyi turuncunun üstünde boş baklavayı
                                // dolu gibi gösteriyor (bkz. KilimBoard.
                                // trackColor).
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                  child: KilimBoard(
                                    key: const ValueKey('result-kilim-board'),
                                    total: totalQuestions,
                                    currentIndex: totalQuestions,
                                    showCurrent: false,
                                    height: 18,
                                    trackColor: Colors.white.withValues(
                                      alpha: 0.16,
                                    ),
                                    outlineColor: Colors.white.withValues(
                                      alpha: 0.30,
                                    ),
                                    results: [
                                      for (final record in answerRecords)
                                        record.isCorrect,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                // Ödül rozetleri.
                                //
                                // `Row` idi: sistem yazısı büyütüldüğünde iki
                                // rozet yan yana sığmıyor ve kartın dışına
                                // taşıyordu. `Wrap` sığmayanı alt satıra alır
                                // (2026-07-26).
                                // Ödül rozetleri skor SAYIMI bittikten
                                // sonra yerine oturur.
                                //
                                // Hepsi aynı anda beliriyordu: skor,
                                // yıldızlar, kilim ve ödüller tek karede
                                // gelince göz nereye bakacağını
                                // bilmiyor ve kazanılan şey kaynayıp
                                // gidiyordu. Ödül bir SONUÇtur; sonucu
                                // sebebinden önce göstermek anlatıyı
                                // tersine çevirir.
                                //
                                // Gecikme `Interval` ile verilir, ayrı
                                // bir zamanlayıcıyla değil: `Timer` +
                                // `setState` ekran erken kapatılırsa
                                // ölü bir State'e dokunur ve bu ekran
                                // zaten sonuç yazılırken kapatılabiliyor.
                                _RewardEntrance(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (coinsAwarded > 0)
                                        _ResultRewardChip(
                                          icon: AppIcons.coins,
                                          label:
                                              '+$coinsAwarded${context.t(K.coinAbbrev)}',
                                          color: AppTheme.gold,
                                        ),
                                      if (_earnedXP > 0)
                                        _ResultRewardChip(
                                          icon: AppIcons.bolt,
                                          label: '+$_earnedXP XP',
                                          // Koyu sonuç kartında accent (koyu
                                          // yeşil) soluk kalıyordu; kazanım
                                          // hissi için aydınlatılmış yeşil.
                                          color: Color.alphaBlend(
                                            Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            AppTheme.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Günlük tavana varıldıysa SEBEBİ söyle.
                                //
                                // Jeton rozeti yalnız miktar sıfırdan
                                // büyükken çiziliyor, dolayısıyla tavana
                                // varan tur ekranda hiçbir iz bırakmıyordu:
                                // oyuncu "+0" bile görmüyor, yalnız hiçbir
                                // şey görmüyordu. Sıfır tek başına
                                // belirsizdir — tavan da sıfır verir, arıza
                                // da. Sebebi yazmak, sessizliği bilgiye
                                // çevirir (2026-08-12 denetimi).
                                if (widget.dailyCapReached &&
                                    coinsAwarded <= 0) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    key: const ValueKey(
                                      'result-daily-cap-notice',
                                    ),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        AppIcons.coins,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.t(K.soloDailyCapReached),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                // Ödül kuyrukta bekliyorsa bunu söyle.
                                // Rozet yalnız miktar sıfırdan büyükse
                                // çizildiği için çevrimdışı turda ekranda
                                // hiçbir iz kalmıyor ve oyuncu turu boşuna
                                // oynadığını sanıyordu (2026-07-26).
                                if (widget.rewardSettlementState ==
                                        QuizRewardSettlementState.queued ||
                                    (widget.rewardSettlementState == null &&
                                        widget.rewardQueued &&
                                        coinsAwarded <= 0)) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        AppIcons.cloud,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.t(K.rewardPending),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (widget.rewardSettlementState ==
                                    QuizRewardSettlementState.unresolved) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        AppIcons.cloud,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.t(K.rewardUnresolved),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  height: 1,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                // Compact stats row: ✅ 17  ❌ 3  ⏱ 0  🔥 12
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    _StatPill(
                                      icon: AppIcons.circleCheck,
                                      value: '$correctCount',
                                      label: context.t(K.correct),
                                      color: AppTheme.correct,
                                    ),
                                    _StatPill(
                                      icon: AppIcons.circleXmark,
                                      value: '$wrongCount',
                                      label: context.t(K.wrong),
                                      color: AppTheme.wrong,
                                    ),
                                    if (unanswered > 0)
                                      _StatPill(
                                        icon: AppIcons.hourglass,
                                        value: '$unanswered',
                                        label: context.t(K.blank),
                                        color: AppTheme.textMutedColor(context),
                                      ),
                                    if (bestStreak > 0)
                                      _StatPill(
                                        icon: AppIcons.fire,
                                        value: '$bestStreak',
                                        label: context.t(K.streakLabel),
                                        color: AppTheme.gold,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (opponents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RaceStandings(
                      userScore: score,
                      userIdentity: room.players.isNotEmpty
                          ? room.players.first
                          : null,
                      opponents: opponents,
                    ),
                  ],
                  if (answerRecords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    LearningOutcomeCard(
                      outcome: learningOutcome,
                      onReview: learningOutcome.reviewRecords.isEmpty
                          ? null
                          : () => openReview(learningOutcome.reviewRecords),
                    ),
                  ],
                  if (_newAchievements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AchievementUnlocks(achievements: _newAchievements),
                  ],
                  if (_promotions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MasteryPromotions(promotions: _promotions),
                  ],
                  if (_dailyStreak > 0) ...[
                    const SizedBox(height: 16),
                    AppPanel(
                      cardType: CardType.secondary,
                      color: AppTheme.surfaceHiColor(context),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.fire,
                            color: AppColors.readableAccent(
                              context,
                              AppTheme.accent,
                            ),
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t(K.dailyStreakDays, {
                                    'days': '$_dailyStreak',
                                  }),
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.t(K.keepStreakTomorrow),
                                  style: TextStyle(
                                    color: AppTheme.textMutedColor(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // ── Actions ──────────────────────────────────────────
                  const SizedBox(height: 12),
                  _buildResultActions(
                    primaryKey: primaryResultKey,
                    primaryLabel: primaryResultLabel,
                    primaryIcon: primaryResultIcon,
                    onPrimaryPressed: wrongRecords.isNotEmpty
                        ? () => openReview(wrongRecords)
                        : completeResultAction,
                    secondaryActions: secondaryResultActions,
                  ),
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ExpansionTile(
                        key: const ValueKey('result-more-options'),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        childrenPadding: const EdgeInsets.only(bottom: 4),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          context.t(K.moreOptions),
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.textSubColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                key: const ValueKey('result-home-button'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst),
                                child: Text(
                                  context.t(K.home),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSubColor(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    AppRoute.to(
                                      LeaderboardScreen(repository: repository),
                                    ),
                                  );
                                },
                                child: Text(
                                  context.t(K.leaderboardLink),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Değerlendir: öne çıkan CTA değil, soluk link — her
                              // sonuç ekranında birincil aksiyonla yarışmasın.
                              TextButton(
                                key: const ValueKey('result-rate-button'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () =>
                                    ReviewService.openStoreListing(),
                                child: Text(
                                  context.t(K.rate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Turun bütün açıklamaları en sonda, bir arada.
                  //
                  // Eskiden her şıkkın altında tek tek açılıyordu; şık
                  // işaretlenir işaretlenmez paragraf beliriyor ve turun
                  // ritmi kesiliyordu (uygulama sahibinin tekrarlanan geri
                  // bildirimi, 2026-07-26). Kart birincil butonların
                  // *altında* durur: "Tekrar oyna" uzun bir okuma listesinin
                  // arkasında kalmamalı.
                  const SizedBox(height: 20),
                  _AllExplanationsCard(records: answerRecords),
                ],
              ),
              if (_showConfetti)
                ConfettiOverlay(
                  onFinished: () {
                    setState(() {
                      _showConfetti = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );

    return PopScope<void>(
      canPop: !isOnlineRoom,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isOnlineRoom) completeResultAction();
      },
      child: scaffold,
    );
  }
}

class _RaceStandings extends StatelessWidget {
  const _RaceStandings({
    required this.userScore,
    required this.opponents,
    this.userIdentity,
  });

  final int userScore;
  final Player? userIdentity;
  final List<Player> opponents;

  @override
  Widget build(BuildContext context) {
    // Repository katmanı yerel oyuncu için sabit 'Tu' adı üretir (i18n
    // katmanı değil); bu widget "sen" etiketini burada, gösterim anında
    // yerelleştirir — userIdentity'nin ham adı görmezden gelinir.
    final user = (userIdentity ?? const Player(name: '', score: 0, state: ''))
        .copyWith(name: context.t(K.you), score: userScore, state: 'Player');
    final standings = [user, ...opponents]
      ..sort((a, b) => b.score.compareTo(a.score));
    final userRank =
        standings.indexWhere((player) => player.state == 'Player') + 1;
    final leader = standings.first;
    final title = context.t(K.compareRivals);
    final summary = leader.state == 'Player'
        ? context.t(K.finishedAtRank, {'rank': '$userRank'})
        : context.t(K.leaderFinishedFirst, {
            'leader': leader.name,
            'rank': '$userRank',
          });

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.peopleGroup, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sabit `textMuted` karanlık tema rengi; açık temada okunmuyordu.
          Text(
            summary,
            style: TextStyle(color: AppTheme.textMutedColor(context)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < standings.length; i++)
            _RaceStandingRow(rank: i + 1, player: standings[i]),
        ],
      ),
    );
  }
}

class _AchievementUnlocks extends StatelessWidget {
  const _AchievementUnlocks({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    // Sonuç kartından görsel olarak daha zayıf: tam gold gradyan blok yerine
    // sade yüzey + ince gold sınır; rozet bilgisi ikincil kalır.
    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  AppIcons.medal,
                  color: AppColors.onAccentTint(context, AppTheme.gold),
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(K.newBadge),
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Icon(
                      achievement.icon,
                      color: AppColors.onAccentTint(context, AppTheme.gold),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title(context.isKu),
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          achievement.description(context.isKu),
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MasteryPromotions extends StatelessWidget {
  const _MasteryPromotions({required this.promotions});

  final Map<String, MasteryLevel> promotions;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Column(
      children: [
        for (final entry in promotions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              color: entry.value.badgeColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.value.badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      entry.value.icon,
                      color: AppColors.onAccentTint(
                        context,
                        entry.value.badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Anahtar tabanlı kayda taşınmadı ve taşınmamalı:
                          // iki dal yalnız *metin* değil, iki farklı veri
                          // araması yapıyor — `CategoryNames.localized`
                          // farklı argümanla, unvan da farklı alandan
                          // (`titleKu` / `titleTr`) okunuyor. Bu bir çeviri
                          // değil, dile göre kaynak seçimidir; kayıt defteri
                          // bunu ifade edemez.
                          ku
                              ? '${CategoryNames.localized(entry.key, true)} — ${entry.value.titleKu}!'
                              : '${CategoryNames.localized(entry.key, false)} — ${entry.value.titleTr}!',
                          style: TextStyle(
                            color: entry.value.badgeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          context.t(K.newTitleEarned),
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sonuç kahramanındaki üç puan yıldızından biri.
///
/// ## Kusur
///
/// Kazanılan ve kazanılmayan yıldız aynı KONTUR glifiyle çiziliyordu
/// (`AppIcons.star` → FontAwesome **Regular**); ikisini yalnız renk
/// ayırıyordu. Mor kahraman zemininde altın bir kontur "boş yıldız" gibi
/// okunuyor ve 5/5 doğru bir tur üç boş yıldızla kutlanıyordu — turun en
/// güçlü ödül anı, hiçbir şey kazanılmamış gibi görünüyordu (2026-08-12
/// simülatör turu, iPhone SE).
///
/// Sessizdi çünkü mantık doğruydu: %80 üstü zaten 3 yıldız hesaplıyordu.
/// Kusur hesapta değil, o hesabı taşıyan glifteydi ve hiçbir test bir
/// ikonun dolu mu boş mu çizildiğine bakmıyordu.
class _ScoreStar extends StatelessWidget {
  const _ScoreStar({required this.earned, required this.size});

  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      earned ? AppIcons.starSolid : AppIcons.star,
      size: size,
      color: earned ? AppTheme.gold : Colors.white.withValues(alpha: 0.32),
    );
  }
}

class _ResultRewardChip extends StatelessWidget {
  const _ResultRewardChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Çip hero gradyanının üzerinde durur, kendi %20'lik tonuyla değil:
    // zemin yeşilden turuncuya kayarken rengin kendisi yazı olarak
    // "+30c" için 2.77:1, "+100 XP" için 2.44:1 veriyordu (2026-07-27).
    //
    // Yanındaki `_StatPill` bu sorunu 2026-07-22'de çözmüştü — koyu perde
    // + beyaz metin, ölçümde 10:1'in üstünde. Ödül çipi o çözümü
    // kullanmıyordu; şimdi kullanıyor. Renk kimliği ikonda ve kenarlıkta
    // yaşamayı sürdürür.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.heroScrim(),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceStandingRow extends StatelessWidget {
  const _RaceStandingRow({required this.rank, required this.player});

  final int rank;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final isUser = player.state == 'Player';
    final color = isUser ? AppTheme.accent : AppTheme.gold;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.bgOf(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isUser
              ? AppTheme.accent.withValues(alpha: 0.45)
              : AppTheme.borderColor(context).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: AppColors.onAccentTint(context, color),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PlayerAvatar(
            radius: 15,
            photoUrl: player.avatarUrl,
            iconId: player.avatarIcon,
            colorHex: player.avatarColor,
            frameId: player.avatarFrame,
            displayName: player.name,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (player.streak > 0) ...[
            const Icon(AppIcons.fire, color: AppTheme.gold, size: 18),
            const SizedBox(width: 4),
            Text(
              '${player.streak}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '${player.score}',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sonuç yan eylemi — ikon + kısa etiket, primary CTA'yı boğmaz.
class _ResultSideAction extends StatelessWidget {
  const _ResultSideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? AppTheme.textPrimaryColor(context)
        : AppTheme.textMutedColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          // 64 piksellik kutuda "Tekrar oyna" iki kenara sıfır dayanıyordu;
          // etiket kutunun içinde değil, kutunun kenarında duruyordu
          // (2026-07-30 ekran turu, 68/69). Kurmancî karşılıkları daha da
          // uzun ("Dîsa bilîze", "Parve bike"). Kutu genişletildi, etikete
          // iç boşluk verildi; taşarsa kırpmak yerine küçülür — yarım
          // sözcük göstermek, küçük yazıdan kötüdür.
          width: 76,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHiColor(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline stat: icon + value + label, used in the score hero.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Pill turuncu hero gradyanının üzerinde durur; yüzey metin renkleri
    // (textPrimary/textMuted) burada okunmuyordu — "Doğru/Yanlış/Seri"
    // etiketleri turuncu üstü turuncuya düşüyordu (~1.8:1, 2026-07-22 UX
    // denetimi). Beyaz metin tek başına da yetmez (turuncuda ~2.2:1), bu
    // yüzden koyu yarı saydam bir zemin eklendi.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.heroScrim(),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Turun bütün açıklamalarını tek kartta toplayan bölüm.
///
/// Açıklama eskiden cevaptan hemen sonra sorunun altında açılıyordu.
/// Uygulama sahibi bunu birkaç kez sorun olarak bildirdi: şık işaretlenir
/// işaretlenmez altında bir paragraf beliriyor, tur duruyor ve okuma yükü
/// oyunun ritmini kesiyordu. Karar: tur sırasında yalnız doğru cevap
/// görünür, açıklamaların tamamı sorular bittiğinde burada bir arada gelir.
///
/// Boş ya da şablon açıklamalar hiç listelenmez — `getLocalizedExplanation`
/// onlar için boş döner ve boş bir satır göstermek, açıklama olmamasından
/// kötüdür.
class _AllExplanationsCard extends StatelessWidget {
  const _AllExplanationsCard({required this.records});

  final List<AnswerRecord> records;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final entries = <({int index, AnswerRecord record, String explanation})>[];
    for (var i = 0; i < records.length; i++) {
      // Önce sorunun **yazılmış** açıklaması, sonra kural motoru.
      //
      // Burası doğrudan motora gidiyordu ve bankada yazılı Kurmancî
      // açıklamayı hiç görmüyordu; motor eşleşme bulamayınca ham Türkçe
      // metni `Şirove: <cümle>` diye sarıyor ve sarmak çevirmek değil.
      // Açıklamaların **asıl gösterildiği yer** burasıdır: tur boyunca
      // hiçbir açıklama gösterilmez, hepsi burada toplanır (2026-07-27).
      final authored = isKu
          ? records[i].explanationKu
          : records[i].explanationTr;
      final text =
          (authored != null &&
              authored.trim().isNotEmpty &&
              !isTemplateExplanation(authored))
          ? authored
          : resolveRawExplanation(
              id: records[i].id,
              explanation: records[i].explanation,
              isKu: isKu,
            );
      if (text.trim().isEmpty) continue;
      entries.add((index: i + 1, record: records[i], explanation: text));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return AppPanel(
      key: const ValueKey('result-all-explanations'),
      cardType: CardType.secondary,
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.bookOpen, color: AppTheme.correct, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(K.allExplanations),
                  style: AppTypography.heading2.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.t(K.allExplanationsHint),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
            ),
          ),
          for (final entry in entries) ...[
            const SizedBox(height: 14),
            _ExplanationEntry(
              index: entry.index,
              record: entry.record,
              explanation: entry.explanation,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExplanationEntry extends StatelessWidget {
  const _ExplanationEntry({
    required this.index,
    required this.record,
    required this.explanation,
  });

  final int index;
  final AnswerRecord record;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    // Doğru/yanlış ayrımı renkle verilir: oyuncu hangi soruda takıldığını
    // listeyi okumadan bulabilsin.
    final tone = record.isUnanswered
        ? AppTheme.gold
        : (record.isCorrect ? AppTheme.correct : AppTheme.wrong);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${record.prompt}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.t(K.correctAnswerLabel)}: ${record.correctAnswer}',
            style: AppTypography.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textSubColor(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ödül rozetlerini skor sayımından SONRA yerine oturtur.
///
/// Gecikme ayrı bir zamanlayıcı yerine `Interval` ile verilir: `Timer` +
/// `setState` ikilisi ekran erken kapatıldığında ölü bir State'e dokunur
/// ve sonuç ekranı tam da ödüller yazılırken kapatılabiliyor.
///
/// Hareket azaltma açıkken giriş animasyonu yapılmaz; rozetler doğrudan
/// yerinde çizilir. Sağlayıcı yoksa (izole widget testleri) animasyon
/// sessizce oynar — dekoratif bir davranış, ağacı eksik diye ekranı
/// çökertmemeli.
class _RewardEntrance extends StatelessWidget {
  const _RewardEntrance({required this.child});

  final Widget child;

  /// Skor sayımının tipik süresi kadar beklenir (bkz. `RollingCount`).
  static const _total = Duration(milliseconds: 1500);
  static const _start = 0.62;

  @override
  Widget build(BuildContext context) {
    final reduced =
        context.watch<ReducedMotionProvider?>()?.reduceMotion ?? false;
    if (reduced) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _total,
      curve: const Interval(_start, 1, curve: Curves.easeOutBack),
      builder: (context, value, child) => Opacity(
        // `easeOutBack` 1'i aşar; opaklık kırpılmazsa assert atar.
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: child,
    );
  }
}
