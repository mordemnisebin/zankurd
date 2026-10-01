import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/category_visuals.dart';
import '../config/coin_prices.dart';
import '../data/achievement_store.dart';
import '../data/badge_service.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/quiz_result_progress_receipt_store.dart';
import '../data/streak_store.dart';
import '../data/xp_award_publisher.dart';
import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../services/quiz_reward_settlement_service.dart';
import '../models/achievement.dart';
import '../models/answer_record.dart';
import '../models/daily_mission.dart';
import '../models/quiz_question.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../widgets/learning_outcome_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/percent_format.dart';
import '../utils/player_identity.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/review_service.dart';
import '../utils/result_sharer.dart';
import '../widgets/confetti_overlay.dart';
import 'leaderboard_screen.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';
import 'room_screen.dart';
import 'spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../widgets/dialog_action_pair.dart';

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
    this.sourceQuestions = const [],
    this.opponents = const [],
    this.rewardQueued = false,
    this.dailyCapReached = false,
    this.practice = false,
    this.dailyQuiz = false,
    this.isLearningExperience = false,
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

  /// Turda gerçekten kullanılan soru nesneleri.
  ///
  /// Çevrimiçi oda soruları sunucu UUID'si taşıyabilir ve yerel
  /// [ZanKurdRepository.playableQuestions] bankasında bulunmayabilir. Sonuç
  /// ekranı Review → Practice döngüsünü ikinci bir ağ çağrısına bağlamamak
  /// için bu listeyi kaynak olarak taşır. Eski çağrılar boş bırakabilir;
  /// o durumda yerel oynanabilir banka geriye dönük yedek olarak kullanılır.
  final List<QuizQuestion> sourceQuestions;

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
  final bool isLearningExperience;
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
  bool get isLearningExperience => widget.isLearningExperience;

  int _dailyStreak = 0;
  List<Achievement> _newAchievements = const [];
  Map<String, MasteryLevel> _promotions = const {};
  int _earnedXP = 0;
  int _currentLevel = 1;
  int _xpInCurrentLevel = 0;
  int _xpNeededForNextLevel = 1;
  double _levelProgress = 0;
  bool _levelJourneyReady = false;
  List<DailyMission> _completedMissions = const [];
  _StreakOutcome? _pendingStreak;
  bool _showConfetti = false;
  bool _ackAttempted = false;
  bool _newRoomLoading = false;

  Future<void> _openNewRoom() async {
    if (_newRoomLoading) return;
    if (widget.room.entryFee > 0) {
      // Bakiye ONAYDAN ÖNCE bilinir: yetmeyen oyuncuya "ücret düşecek,
      // devam?" diye sorup sonra sunucunun reddini genel bir hata olarak
      // göstermek, tekrar denetilen ama hiç değişmeyecek bir yoldu.
      int? balance;
      try {
        balance = await widget.repository.loadCoinBalance();
      } catch (error, stack) {
        // Bakiye okunamadıysa karar sunucuya kalır; ret aşağıda
        // anlamlı mesajla gösterilir.
        ErrorReporter.record(error, stack, reason: 'new_room_balance');
      }
      if (!mounted) return;
      final missing = balance == null
          ? 0
          : coinShortfall(cost: widget.room.entryFee, balance: balance);
      if (missing > 0) {
        await _showNewRoomShortfall(missing, balance!);
        return;
      }
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
            DialogActionPair(
              cancel: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.t(K.cancel)),
              ),
              confirm: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.t(K.continueAction)),
              ),
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
      // Sunucu ücrete yetmeyen bakiyeyi 'Insufficient coins' ile reddeder
      // (bakiye okuması ile ret arasında harcama olmuş olabilir): "Oda
      // açılamadı" demek tekrar denemeye çağırır, oysa çözüm jeton kazanmak.
      final short = e.toString().contains('Insufficient coins');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(short ? K.insufficientCoins : K.roomOpenFailed),
          ),
          action: short
              ? SnackBarAction(
                  label: context.t(K.earnCoins),
                  onPressed: _openSpinWheel,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _newRoomLoading = false);
    }
  }

  Future<void> _openSpinWheel() async {
    await Navigator.of(context).push(
      AppRoute<void>(page: SpinWheelScreen(repository: widget.repository)),
    );
  }

  /// Ücretli odanın tekrarı için bakiye yetmiyor: eksik miktar ve gerçek
  /// sonraki adım (jeton kazan). Onay penceresi hiç açılmaz.
  Future<void> _showNewRoomShortfall(int missing, int balance) async {
    final goEarn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t(K.newRoomAction)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(K.yourBalance, {'coins': '$balance'}),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SahneSpace.x2),
            SahneShortfallNote(
              key: const ValueKey('result-new-room-shortfall'),
              missing: missing,
              alert: true,
              center: true,
            ),
          ],
        ),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t(K.cancel)),
            ),
            confirm: SahneButton.primary(
              key: const ValueKey('result-new-room-earn-coins'),
              label: context.t(K.earnCoins),
              arrow: false,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
    if (goEarn == true && mounted) await _openSpinWheel();
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
    final premium = context.read<PremiumService>();
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

    // Premium: ücretsiz ve otomatik; kullanıcı kararı yok. Kapı
    // bellekteki bayrağa değil taze entitlement'a bakar — bayat `true`
    // ile bedava dondurma verilmez.
    //
    // Doğrulama BAŞARISIZ olursa bu satır artık yanlışlıkla ücretli yola
    // düşmez: 2026-09-25 öncesi `false` dönüyor, çevrimdışı bir abone
    // "abone değil" sanılıp coin'e gidiyordu. Üç hâl ayrıldı: kesin cevap
    // ve bilinmeyen. Bilinmeyende kullanıcıdan karar istenir, çünkü
    // "abonelik kalktı" demek de doğru olmaz.
    final refresh = await premium.refreshEntitlement();
    if (refresh is EntitlementRefreshKnown) {
      if (refresh.isPremium) {
        await recordStage?.call(QuizResultReceiptStage.freezeApplying);
        await streakStore.addFreeze();
        final streak = await streakStore.freezeAndRecordPlay();
        await recordStage?.call(QuizResultReceiptStage.freezeApplied);
        return _StreakOutcome(streak: streak, isNewDay: isNewDay);
      }
    } else {
      // Son bilinen durum bellekte duruyor; ölümcül bir hata değil, bu
      // yüzden kayıt aşaması ilerletilmez ve tekrar denene bilir kalınır.
      ErrorReporter.record(
        StateError('premium entitlement could not be verified'),
        StackTrace.current,
        reason: 'streak_freeze_entitlement_unknown',
      );
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
    if (!mounted) return false;
    if (balance < _streakFreezeCost) {
      // Bakiye yetmiyorsa teklif edilecek bir şey yok, ama seri BU turda
      // kırılıyor: oyuncuya söylenir (yalnız bilgi, karar istemez; akış ve
      // makbuz aşamaları değişmez — soru her zaman `false` döner).
      await _showStreakFreezeShortfall(
        missing: coinShortfall(cost: _streakFreezeCost, balance: balance),
      );
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t(K.streakBreaking)),
        content: Text(
          context.t(K.streakFreezeAsk, {'cost': '$_streakFreezeCost'}),
        ),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t(K.streakLetGo)),
            ),
            confirm: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                context.t(K.streakFreezeAction, {'cost': '$_streakFreezeCost'}),
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// Seri kırılacak ama bakiye korumaya yetmiyor: eksik miktar ve jeton
  /// kazanma yolu. Hiçbir yan etkisi yoktur; kesintide yeniden gösterilmesi
  /// güvenlidir (`pendingUserDecision` aşamasındayız).
  Future<void> _showStreakFreezeShortfall({required int missing}) async {
    final goEarn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t(K.streakBreaking)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t(K.streakFreezeNoCoins), textAlign: TextAlign.center),
            const SizedBox(height: SahneSpace.x2),
            SahneShortfallNote(
              key: const ValueKey('result-streak-shortfall'),
              missing: missing,
              alert: true,
              center: true,
            ),
          ],
        ),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t(K.gotIt)),
            ),
            confirm: SahneButton.primary(
              key: const ValueKey('result-streak-earn-coins'),
              label: context.t(K.earnCoins),
              arrow: false,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
    // Çark, sonuç akışını beklemeden açılır; akış `false` ile sürer.
    if (goEarn == true && mounted) unawaited(_openSpinWheel());
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
    final answeredByCategory = <String, int>{};
    for (final record in answerRecords) {
      if (!record.isUnanswered) {
        answeredByCategory[record.category] =
            (answeredByCategory[record.category] ?? 0) + 1;
      }
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
    for (final entry in answeredByCategory.entries) {
      await masteryStore.recordAnswered(
        entry.key,
        entry.value,
        correct: correctByCategory[entry.key] ?? 0,
      );
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
    // Oda turunda XP sunucu skorundan yazılır; istemci delta göndermez.
    final roomId = widget.room.id?.trim() ?? '';
    unawaited(
      XpAwardPublisher.publish(
        repository: repository,
        delta: earnedXP,
        roomId: roomId.isEmpty ? null : roomId,
      ),
    );

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
    // Huni: ilk 1v1 tamamlama Firebase'de ilk-oluşumla bölümlenir.
    // Oda kimliği boşsa solo turdur, işaretlenmez.
    if ((widget.room.id?.trim() ?? '').isNotEmpty) {
      AnalyticsService.instance.logActivationStep('online_match_completed');
    }
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
        _currentLevel = xpStore.currentLevel;
        _xpInCurrentLevel = xpStore.xpInCurrentLevel;
        _xpNeededForNextLevel = xpStore.xpNeededForNextLevel;
        _levelProgress = xpStore.levelProgress;
        _levelJourneyReady = true;
        _showConfetti = promotions.isNotEmpty;
        // 2026-09-29 Şahnê: tamamlanan görevler yüzen bildirim olarak
        // değil, turun kazanımları arasında satır olarak görünür. Sonuç
        // ekranında birincil eylem alt perdededir; yüzen bildirim tam onun
        // üstüne binip "Tekrar oyna"yı üç saniye örtüyordu (tur karesi
        // 68, 2026-09-29).
        _completedMissions = completedMissions;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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
        final dialog = _LevelUpDialog(
          level: newLevel,
          onContinue: () => Navigator.of(
            context,
          ).pop({'score': score, 'correct': correctCount}),
        );
        // Hareketi azalt açıkken pencere yaylanmadan, yalnız belirerek
        // gelir.
        if (sahneMotionReduced(context)) {
          return FadeTransition(opacity: anim1, child: dialog);
        }
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(opacity: anim1, child: dialog),
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
    // Kusur 1: başlık hep `room.category`yi yazıyordu, ama bu alan odanın
    // varsayılan/ilk kategorisidir — GERÇEKTEN çözülen soruların kategorisi
    // değil. "Günün dersi" akışı (`home_screen.dart` `_startDailyQuiz`)
    // `category`yi hiç güncellemez; sonuç ekranı Müzik+Dil+Coğrafya+Kültür
    // karışık beş sorudan sonra "Dil · %80 doğruluk" yazıyordu (2026-09-27
    // simülatör turu). Tek doğru kaynak turda GERÇEKTEN cevaplanan
    // sorulardır (`learningOutcome.categoryBreakdown`, `answerRecords`ten
    // türer). Kategori adı yalnız tur TEK kategoriliyse anlamlıdır; birden
    // çok kategoriye yayılmışsa yerine turun adı yazılır — "günün dersi"
    // akışında bu zaten `room.name` alanına yazılmış olan "Günün Dersi"
    // başlığıdır (`K.dailyLesson`).
    //
    // 2026-09-29 doğallık: karışık turda `room.name` doğrudan yazılıyordu;
    // yerel/solo odanın varsayılan adı Kurmancî "Hevalên Zanînê" olduğu için
    // Türkçe sonuç ekranının tepesinde çevrilmemiş bir yer tutucu
    // duruyordu. Ad, soru ekranının başlığıyla AYNI kuraldan geçer
    // (`quizRoundTitle`): turun kendi adı. Adı yoksa bağlamda yalnız soru
    // sayısı durur — genel "Yarış" sözü hemen altındaki "Yarış tamamlandı"
    // başlığını tekrarlardı.
    final isMixedCategoryRound = learningOutcome.categoryBreakdown.length > 1;
    final raceWord = context.t(K.raceWord);
    final String? roundLabel;
    if (isMixedCategoryRound) {
      final title = quizRoundTitle(
        roomId: null,
        roomCode: '',
        roomName: room.name,
        category: '',
        isKu: context.isKu,
        roomWord: context.t(K.roomWord),
        raceWord: raceWord,
      );
      roundLabel = title == raceWord ? null : title;
    } else {
      roundLabel = CategoryNames.localized(room.category, context.isKu);
    }

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

    Future<void> openReview(List<AnswerRecord> records) async {
      final sourceById = <String, QuizQuestion>{
        for (final question in repository.playableQuestions)
          question.id: question,
        for (final question in widget.sourceQuestions) question.id: question,
      };
      final practiceQuestions = records
          .map((record) => sourceById[record.id])
          .whereType<QuizQuestion>()
          .toList(growable: false);
      final startPractice = await Navigator.of(context).push<bool>(
        AppRoute.to(
          ReviewScreen(
            records: records,
            room: room,
            practiceAvailable: practiceQuestions.isNotEmpty,
          ),
        ),
      );
      if (startPractice != true ||
          !context.mounted ||
          practiceQuestions.isEmpty) {
        return;
      }

      final practiceRoom = repository.createRoom().copyWith(
        name: context.t(K.myMistakes),
        questionCount: practiceQuestions.length,
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: repository,
            room: practiceRoom,
            questions: practiceQuestions,
            practice: true,
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
    }

    Future<void> shareResult() async {
      await ResultSharer.share(
        context,
        isKu: context.isKu,
        score: score,
        correctCount: correctCount,
        totalQuestions: totalQuestions,
        bestStreak: bestStreak,
        // Karışık turda ekrandaki başlıkla aynı: tek bir kategori adı
        // turu yanlış anlatırdı.
        category: isMixedCategoryRound ? room.name : room.category,
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
    }

    final learningContinue = isLearningExperience && !isOnlineRoom;
    final primaryResultKey = learningContinue
        ? 'result-primary-learning-continue'
        : isOnlineRoom
        ? 'result-primary-home'
        : 'result-play-again-button';
    final primaryResultLabel = learningContinue
        ? context.t(K.continueAction)
        : nextActionLabel;

    // Kusur 1 (2026-09-27): bu yan eylem ve `LearningOutcomeCard`daki
    // "Yanlış cevabı gözden geçir" düğmesi AYNI `openReview` çağrısına
    // gidiyordu — `LearningOutcome.fromRecords`e bakılırsa `reviewCategory`
    // null iken kartın `reviewRecords`ı zaten TÜM yanlışlardır (bkz. o
    // fabrika metodundaki `selectedWrong`). Yani kart görünürken
    // (`answerRecords.isNotEmpty`) ve kart tek bir konuya değil TÜM
    // yanlışlara işaret ederken (`reviewCategory == null`), bu yan eylem
    // kartın altında birebir aynı eylemi ikinci kez sunuyordu. `reviewCategory`
    // doluyken kart yalnız O KONUNUN yanlışlarını gösterir — o zaman ikisi
    // farklı kapsamdır ("bu konudakiler" ↔ "hepsi") ve yan eylem kalmalı.
    //
    // 2026-10-02: `reviewCategory` artık YANLIŞI olan her turda dolu (zayıf
    // konu eşiğe bağlı değil; bkz. `LearningOutcome.fromRecords`). "Kart hepsini
    // açıyor" koşulu bu yüzden kategori adının boşluğundan değil kapsamdan
    // okunur: kartın açacağı kayıtlar tüm yanlışlara eşitse (tek konuda
    // toplanmışsa ya da konusuz kayıtlarsa) yan düğme aynı eylemi tekrarlar.
    final learningOutcomeAlreadyOffersAllMistakes =
        answerRecords.isNotEmpty &&
        learningOutcome.reviewRecords.isNotEmpty &&
        learningOutcome.reviewRecords.length >= wrongRecords.length;
    // 2026-09-29 Şahnê: "Paylaş" alt perdede birincil eylemin yanında durur
    // (maketteki `.sh-dock--2`). Geri kalan yan eylemler öğrenme özetinin
    // ALTINDA, ikincil düğme olarak kalır — öğrenme içgörüsü onlardan önce
    // okunur.
    final secondaryResultActions = <_ResultAction>[
      if (wrongRecords.isNotEmpty &&
          !learningContinue &&
          !learningOutcomeAlreadyOffersAllMistakes)
        _ResultAction(
          key: const ValueKey('result-review-mistakes-button'),
          icon: AppIcons.squareCheck,
          label: context.t(K.reviewMistakes),
          onTap: () => openReview(wrongRecords),
        ),
      if (isOnlineRoom)
        _ResultAction(
          key: const ValueKey('result-new-room-button'),
          icon: AppIcons.circlePlus,
          label: context.t(K.newRoom),
          onTap: _newRoomLoading ? null : _openNewRoom,
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

    // 2026-09-29 Şahnê: 1v1 sonucu Rast/Şaş (durum) ailesiyle boyanmaz —
    // kazanmak bir "doğru cevap" değildir. Kazanma Zêr taç + altın başlık,
    // beraberlik ve kaybetme nötr; yarış kimliği Boyax kilim şeridindedir.
    // Eski yeşil/kırmızı başlık gradyanları kalktı (bkz.
    // `quiz_result_header_contrast_test.dart`).
    final duelOutcome = !is1v1
        ? null
        : isWinner
        ? _DuelOutcome.win
        : isDraw
        ? _DuelOutcome.draw
        : _DuelOutcome.loss;

    final headerTitle = isLearningExperience
        ? context.t(K.learningResultTitle)
        : is1v1
        ? (isWinner
              ? context.t(K.youWon)
              : isDraw
              ? context.t(K.draw)
              : context.t(K.youLost))
        : context.t(K.raceFinished);

    // Kutlama (sonuç ışınları) yalnız kutlanacak bir sonuç varken çizilir:
    // 1v1'de galibiyet, solo turda üç yıldız. Kaybedilen turda kutlama
    // ışığı açmak sonucu yanlış okur.
    //
    // 2026-09-29 doğallık (K9): solo eşiği "en az yarısı doğru"ydu; 3/5'lik
    // sıradan bir tur da güneş ışınlarıyla açılıyordu ve parıltı her
    // sonuçta olunca hiçbir şeyi kutlamıyordu. Işın yalnız üç yıldızda
    // (%80+) — yıldızların saydığı eşikle aynı.
    final starsEarned = accuracy >= 80
        ? 3
        : accuracy >= 50
        ? 2
        : 1;
    final celebrate = is1v1 ? isWinner : starsEarned == 3;

    final accuracyText =
        '${context.percent(accuracy)} ${context.t(K.accuracyLower)}';
    final notices = <Widget>[
      // Günlük tavana varıldıysa SEBEBİ söyle.
      //
      // Jeton rozeti yalnız miktar sıfırdan büyükken çiziliyor, dolayısıyla
      // tavana varan tur ekranda hiçbir iz bırakmıyordu: oyuncu "+0" bile
      // görmüyor, yalnız hiçbir şey görmüyordu. Sıfır tek başına
      // belirsizdir — tavan da sıfır verir, arıza da. Sebebi yazmak,
      // sessizliği bilgiye çevirir (2026-08-12 denetimi).
      if (widget.dailyCapReached && coinsAwarded <= 0)
        _HeroNotice(
          key: const ValueKey('result-daily-cap-notice'),
          icon: AppIcons.coins,
          text: context.t(K.soloDailyCapReached),
        ),
      // Ödül kuyrukta bekliyorsa bunu söyle. Rozet yalnız miktar sıfırdan
      // büyükse çizildiği için çevrimdışı turda ekranda hiçbir iz kalmıyor
      // ve oyuncu turu boşuna oynadığını sanıyordu (2026-07-26).
      if (widget.rewardSettlementState == QuizRewardSettlementState.queued ||
          (widget.rewardSettlementState == null &&
              widget.rewardQueued &&
              coinsAwarded <= 0))
        _HeroNotice(icon: AppIcons.cloud, text: context.t(K.rewardPending)),
      if (widget.rewardSettlementState == QuizRewardSettlementState.unresolved)
        _HeroNotice(icon: AppIcons.cloud, text: context.t(K.rewardUnresolved)),
    ];

    final hasRewards = SahneResultRewards.hasAny(
      coins: coinsAwarded,
      xp: _earnedXP,
      progress: _levelJourneyReady,
    );
    final breakdown = learningOutcome.categoryBreakdown;
    final hasGains =
        _newAchievements.isNotEmpty ||
        _promotions.isNotEmpty ||
        _completedMissions.isNotEmpty ||
        _dailyStreak > 0;

    // 2026-10-01 (A6): kahraman, sayımlar ve ödül ortak sonuç şablonundan
    // ([SahneResultScaffold]) gelir; burada yalnız bu ekrana özgü bölümler
    // sıralanır. Sıra artık şablonun sırası: kahraman → sayımlar → ödül.
    final sections = <Widget>[
      if (opponents.isNotEmpty)
        _RaceStandings(
          userScore: score,
          userIdentity: room.players.isNotEmpty ? room.players.first : null,
          opponents: opponents,
        ),
      if (answerRecords.isNotEmpty) ...[
        if (breakdown.isNotEmpty) ...[
          SahneSectionHeader(title: context.t(K.resultLearnedTitle)),
          _CategoryLearnings(breakdown: breakdown),
          // Yorumu olmayan kart çizilmez (bkz. [LearningOutcomeCard]): boşluk
          // da onunla birlikte gider.
          if (learningOutcome.hasSpotlight)
            const SizedBox(height: SahneSpace.cardGap),
        ] else
          const SizedBox(height: SahneSpace.sectionTop),
        LearningOutcomeCard(
          outcome: learningOutcome,
          // Kategori listesi gösteriliyorsa sayımlar orada: kart yalnız
          // yorumu taşır.
          showCounts: breakdown.isEmpty,
          onReview: learningOutcome.reviewRecords.isEmpty
              ? null
              : () => openReview(learningOutcome.reviewRecords),
        ),
      ],
      if (secondaryResultActions.isNotEmpty) ...[
        const SizedBox(height: SahneSpace.cardGap),
        _SecondaryActions(actions: secondaryResultActions),
      ],
      if (hasGains)
        _RoundGains(
          achievements: _newAchievements,
          promotions: _promotions,
          missions: _completedMissions,
          dailyStreak: _dailyStreak,
        ),
      // Turun bütün açıklamaları en sonda, bir arada.
      //
      // Eskiden her şıkkın altında tek tek açılıyordu; şık işaretlenir
      // işaretlenmez paragraf beliriyor ve turun ritmi kesiliyordu
      // (uygulama sahibinin tekrarlanan geri bildirimi, 2026-07-26).
      // Birincil eylem alt perdede her an görünür: "Tekrar oyna" uzun bir
      // okuma listesinin arkasında kalmaz.
      _AllExplanationsCard(records: answerRecords),
      const SizedBox(height: SahneSpace.sectionTop),
      _MoreOptions(
        onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onLeaderboard: () {
          Navigator.of(
            context,
          ).push(AppRoute.to(LeaderboardScreen(repository: repository)));
        },
        onRate: () => ReviewService.openStoreListing(),
      ),
    ];

    final scaffold = SahneResultScaffold(
      // Çevrimiçi turda kapatmak da ana eylem gibi ilk rotaya döner; solo
      // turda yalnız sonuç rotası kapanır (`PopScope` aşağıda).
      onClose: isOnlineRoom ? completeResultAction : null,
      closeLabel: context.t(K.close),
      // Orta yuva bağlamdır: "Yarış tamamlandı" zaten içerikte başlık,
      // ekran adı ("Sonuç") tekrarlanmaz.
      contextLabel: [
        ?roundLabel,
        context.t(K.questionCount, {'count': '$totalQuestions'}),
      ].join(' • '),
      hero: SahneResultHero(
        key: const ValueKey('result-score-header'),
        emblem: switch (duelOutcome) {
          null => SizedBox(height: 44, child: _ScoreStars(earned: starsEarned)),
          _DuelOutcome.win => const SahneResultEmblem.win(),
          _DuelOutcome.draw => const SahneResultEmblem.state(
            icon: AppIcons.scaleBalanced,
          ),
          _DuelOutcome.loss => const SahneResultEmblem.state(
            icon: AppIcons.flag,
          ),
        },
        title: headerTitle,
        titleRole: duelOutcome == _DuelOutcome.win ? SahneRole.gold : null,
        // Öğrenme turunda puan üretilmez (`score` hep 0); büyük sayı "0"
        // yazınca 3 doğru yapan kullanıcıya başarısız gibi görünüyordu
        // (2026-09-10 simülatör turu). Öğrenmede sayı, doğru cevap
        // sayısıdır: "3/5".
        value: isLearningExperience ? correctCount : score,
        suffix: isLearningExperience ? '/$totalQuestions' : '',
        caption: isLearningExperience
            ? accuracyText
            : '${context.t(K.scoreWord).toLowerCase()} • $accuracyText',
        celebrate: celebrate,
        tone: duelOutcome == null
            ? SahneResultTone.reward
            : SahneResultTone.race,
        notices: notices,
      ),
      stats: ResultStatTiles(
        correct: correctCount,
        wrong: wrongCount,
        unanswered: unanswered,
        streak: bestStreak,
      ),
      rewards: hasRewards
          ? SahneResultRewards(
              coins: coinsAwarded,
              coinLabel: '+$coinsAwarded',
              coinSemanticLabel: '+$coinsAwarded ${context.t(K.coinWord)}',
              xp: _earnedXP,
              progress: _levelJourneyReady
                  ? KeyedSubtree(
                      key: const ValueKey('result-level-journey-progress'),
                      child: SahneResultLevelProgress(
                        levelLabel: context.t(K.seviyeP, {
                          'p0': '$_currentLevel',
                        }),
                        xpInLevel: _xpInCurrentLevel,
                        xpNeeded: _xpNeededForNextLevel,
                        progress: _levelProgress,
                      ),
                    )
                  : null,
            )
          : null,
      sections: sections,
      primary: SahneResultAction(
        key: ValueKey(primaryResultKey),
        label: primaryResultLabel,
        icon: learningContinue ? null : nextActionIcon,
        onPressed: completeResultAction,
      ),
      secondary: SahneResultAction(
        key: const ValueKey('result-share-button'),
        label: context.t(K.share),
        icon: AppIcons.shareNodes,
        onPressed: shareResult,
      ),
      overlay: _showConfetti
          ? ConfettiOverlay(
              onFinished: () {
                setState(() {
                  _showConfetti = false;
                });
              },
            )
          : null,
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

enum _DuelOutcome { win, draw, loss }

/// Kahramanın üç puan yıldızı: 32 · 44 · 32, alta hizalı, 8 aralık.
///
/// ## Kusur (tarih)
///
/// Kazanılan ve kazanılmayan yıldız bir zamanlar aynı KONTUR glifiyle
/// çiziliyordu; ikisini yalnız renk ayırıyordu ve 5/5 doğru bir tur üç boş
/// yıldızla kutlanıyordu (2026-08-12 simülatör turu). Şahnê'de kazanılan
/// yıldız DOLU Zêr glif, kazanılmayan Ray (`s3`) tonunda — ayrımı renk
/// değil doluluk taşır (bkz. `quiz_result_star_fill_test.dart`).
class _ScoreStars extends StatelessWidget {
  const _ScoreStars({required this.earned});

  final int earned;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: SahneSpace.x2),
          SahneGlyph(
            SahneGlyphKind.star,
            size: i == 1 ? 44 : 32,
            filled: i < earned,
          ),
        ],
      ],
    );
  }
}

/// Kahramanın altındaki bilgi satırı (günlük tavan, bekleyen ödül).
class _HeroNotice extends StatelessWidget {
  const _HeroNotice({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: Center(child: Icon(icon, size: 16, color: t.tx2)),
        ),
        const SizedBox(width: SahneSpace.x2),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
      ],
    );
  }
}

/// Tur sayımları — doğru ✓ / yanlış ✗ / (boş ⧗) / seri alev. Karoların
/// kendisi ortak şablondadır ([SahneResultStats]); burada yalnız bu turun
/// kuralı verilir: doğru/yanlış çifti turun omurgası olduğu için sıfırken de
/// durur, boş ve seri karoları sıfırken çizilmez (anlamsız sıfır yok).
@visibleForTesting
class ResultStatTiles extends StatelessWidget {
  const ResultStatTiles({
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.streak,
    super.key,
  });

  final int correct;
  final int wrong;
  final int unanswered;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneResultStats(
      stats: [
        SahneResultStat(
          leading: Icon(AppIcons.check, size: 20, color: t.okTx),
          value: correct,
          label: context.t(K.correct),
          showWhenZero: true,
        ),
        SahneResultStat(
          leading: Icon(AppIcons.xmark, size: 20, color: t.errTx),
          value: wrong,
          label: context.t(K.wrong),
          showWhenZero: true,
        ),
        SahneResultStat(
          leading: Icon(AppIcons.hourglass, size: 20, color: t.tx2),
          value: unanswered,
          label: context.t(K.blank),
        ),
        SahneResultStat(
          leading: const SahneGlyph(SahneGlyphKind.flame),
          value: streak,
          label: context.t(K.streakLabel),
        ),
      ],
    );
  }
}

/// "Kategorilere göre performans" — turda görülen her kategori bir liste
/// satırı: 36'lık küçük resim (çizimi olmayan kategoride Zimrût ikon
/// karosu), "doğru/cevaplanan" değeri ve durum karesi (✓ yarısı ya da
/// fazlası doğru, ✗ değilse). Söz ekran okuyucuya gider.
class _CategoryLearnings extends StatelessWidget {
  const _CategoryLearnings({required this.breakdown});

  final List<CategoryTally> breakdown;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return SahneListGroup(
      children: [
        for (final tally in breakdown)
          _categoryRow(
            context,
            tally,
            CategoryNames.localized(tally.category, isKu),
          ),
      ],
    );
  }

  Widget _categoryRow(BuildContext context, CategoryTally tally, String name) {
    final ok = tally.correct * 2 >= tally.answered;
    final statusLabel = context.t(ok ? K.correct : K.wrong);
    final fraction = '${tally.correct}/${tally.answered}';
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneRowValue(fraction),
        const SizedBox(width: SahneSpace.x3),
        SahneStatusBadge.square(correct: ok, label: statusLabel),
      ],
    );
    final semantic = '$name, $fraction, $statusLabel';
    // 2026-09-29 doğallık (K1): liste satırında çizim yok; kategori kendi
    // tonu + ikonuyla çizimsiz küçüğe düşer (bkz. matchmaking `_categoryRow`).
    return SahneListRow.thumb(
      image: null,
      icon: CategoryVisuals.icon(tally.category),
      tone: CategoryVisuals.tone(tally.category),
      title: name,
      trailing: trailing,
      semanticLabel: semantic,
    );
  }
}

/// Öğrenme özetinin altındaki ikincil eylemler (yanlışları incele, yeni
/// oda). İkincil düğme (Kulis): turun birincil eylemi alt perdededir.
class _ResultAction {
  const _ResultAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// İkincil eylemleri eşit genişlikte yan yana dizer; bir etiket kendi
/// payına sığmıyorsa ya da yazı büyükse alt alta iner — küçültmek yerine
/// büyütmek (Kusur 2, 2026-09-27: kare kutuda etiket ~8px'e küçülüyordu).
class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.actions});

  final List<_ResultAction> actions;

  @override
  Widget build(BuildContext context) {
    Widget button(_ResultAction action) => SahneButton.secondary(
      key: action.key,
      icon: action.icon,
      label: action.label,
      onPressed: action.onTap,
      expand: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SahneSpace.x3;
        final share =
            (constraints.maxWidth - gap * (actions.length - 1)) /
            actions.length;
        final scaler = MediaQuery.textScalerOf(context);
        final tooNarrow = actions.any((action) {
          final painter = TextPainter(
            text: TextSpan(
              text: action.label,
              style: SahneType.button.copyWith(fontFamily: SahneType.display),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          // İkon 20 + aralık 8 + yan boşluk 12 × 2.
          return painter.width + 20 + 8 + 24 > share;
        });
        if (actions.length == 1 || !(tooNarrow || scaler.scale(16) >= 24)) {
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: button(actions[i])),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: SahneSpace.x2),
              button(actions[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Satırın 36'lık avatar yuvası: oyuncunun seçtiği kimlik.
Widget _avatarOf(Player player) => PlayerAvatar(
  radius: 18,
  photoUrl: player.avatarUrl,
  iconId: player.avatarIcon,
  colorHex: player.avatarColor,
  frameId: player.avatarFrame,
  displayName: player.name,
);

/// Bot yarışında rakiplerle karşılaştırma: bölüm başlığı + özet +
/// sıralama. "Sen" satırı grubun dışında tek başına durur (maketteki
/// Sıralama); rakipler liste grubunda, sıra numarası ve elmas avatarla.
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
    final t = SahneTokens.of(context);
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
    final summary = leader.state == 'Player'
        ? context.t(K.finishedAtRank, {'rank': '$userRank'})
        : context.t(K.leaderFinishedFirst, {
            'leader': context.playerDisplayName(leader.name),
            'rank': '$userRank',
          });

    // Ardışık rakipler tek grupta; "Sen" satırı iki grubun arasında.
    final blocks = <Widget>[];
    var pending = <Widget>[];
    void flush() {
      if (pending.isEmpty) return;
      if (blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: SahneSpace.x2));
      }
      blocks.add(SahneListGroup(children: pending));
      pending = <Widget>[];
    }

    for (var i = 0; i < standings.length; i++) {
      final player = standings[i];
      final streakLine = player.streak > 0
          ? '${context.t(K.streakLabel)} ${player.streak}'
          : null;
      if (player.state == 'Player') {
        flush();
        if (blocks.isNotEmpty) {
          blocks.add(const SizedBox(height: SahneSpace.x2));
        }
        blocks.add(
          SahneListRow.me(
            rank: i + 1,
            title: player.name,
            avatar: userIdentity == null ? null : _avatarOf(player),
            subtitle: streakLine,
            trailing: SahneRowValue('${player.score}'),
          ),
        );
      } else {
        final name = player.name.trim();
        pending.add(
          SahneListRow.rank(
            rank: i + 1,
            title: context.playerDisplayName(player.name),
            initial: name.isEmpty ? null : context.playerInitial(player.name),
            icon: AppIcons.user,
            // Oyuncunun kendi kimliği (fotoğraf, ikon, renk, çerçeve)
            // satırın 36'lık avatar yuvasında.
            avatar: _avatarOf(player),
            subtitle: streakLine,
            trailing: SahneRowValue('${player.score}'),
          ),
        );
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.compareRivals)),
        Text(summary, style: SahneType.body.copyWith(color: t.tx2)),
        const SizedBox(height: SahneSpace.x3),
        ...blocks,
      ],
    );
  }
}

/// Turun kazanımları: yeni rozetler, ustalık unvanları, tamamlanan günlük
/// görevler ve günlük seri —
/// Zêr ikon karolu tek liste grubu. Rozet varsa başlığı "Yeni Rozet".
class _RoundGains extends StatelessWidget {
  const _RoundGains({
    required this.achievements,
    required this.promotions,
    required this.missions,
    required this.dailyStreak,
  });

  final List<Achievement> achievements;
  final Map<String, MasteryLevel> promotions;
  final List<DailyMission> missions;
  final int dailyStreak;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (achievements.isNotEmpty)
          SahneSectionHeader(title: context.t(K.newBadge))
        else
          const SizedBox(height: SahneSpace.sectionTop),
        SahneListGroup(
          children: [
            for (final achievement in achievements)
              SahneListRow.icon(
                icon: achievement.icon,
                role: SahneRole.gold,
                title: achievement.title(context.isKu),
                subtitle: achievement.description(context.isKu),
              ),
            for (final entry in promotions.entries)
              SahneListRow.icon(
                icon: entry.value.icon,
                role: SahneRole.gold,
                // Anahtar tabanlı kayda taşınmadı ve taşınmamalı: iki dal
                // yalnız *metin* değil, iki farklı veri araması yapıyor —
                // `CategoryNames.localized` farklı argümanla, unvan da
                // farklı alandan (`titleKu` / `titleTr`) okunuyor. Bu bir
                // çeviri değil, dile göre kaynak seçimidir; kayıt defteri
                // bunu ifade edemez.
                title: ku
                    ? '${CategoryNames.localized(entry.key, true)} — ${entry.value.titleKu}!'
                    : '${CategoryNames.localized(entry.key, false)} — ${entry.value.titleTr}!',
                subtitle: context.t(K.newTitleEarned),
              ),
            for (final mission in missions)
              SahneListRow.icon(
                icon: AppIcons.listCheck,
                role: SahneRole.gold,
                title: context.t(K.gorevTamamlandi),
                subtitle:
                    '${context.isKu ? mission.labelKu : mission.labelTr}'
                    ' — +${mission.xpReward} XP',
              ),
            if (dailyStreak > 0)
              SahneListRow.icon(
                icon: AppIcons.fire,
                role: SahneRole.gold,
                title: context.t(K.dailyStreakDays, {'days': '$dailyStreak'}),
                subtitle: context.t(K.keepStreakTomorrow),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Diğer seçenekler": seyrek çıkış yolları (ana sayfa, sıralama,
/// değerlendir) kapalı bir açılır satırda; metin bağlantısı olarak durur,
/// birincil eylemle yarışmaz.
class _MoreOptions extends StatelessWidget {
  const _MoreOptions({
    required this.onHome,
    required this.onLeaderboard,
    required this.onRate,
  });

  final VoidCallback onHome;
  final VoidCallback onLeaderboard;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: const ValueKey('result-more-options'),
        shape: SahneShape.m,
        collapsedShape: SahneShape.m,
        iconColor: t.tx2,
        collapsedIconColor: t.tx2,
        tilePadding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
        childrenPadding: const EdgeInsets.only(bottom: SahneSpace.x1),
        title: Text(
          context.t(K.moreOptions),
          textAlign: TextAlign.center,
          style: SahneType.captionStrong.copyWith(color: t.tx2),
        ),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: SahneSpace.x3,
            runSpacing: SahneSpace.x1,
            children: [
              SahneButton.text(
                key: const ValueKey('result-home-button'),
                label: context.t(K.home),
                arrow: false,
                onPressed: onHome,
              ),
              SahneButton.text(
                label: context.t(K.leaderboardLink),
                arrow: false,
                onPressed: onLeaderboard,
              ),
              // Değerlendir: öne çıkan CTA değil, sakin bir bağlantı — her
              // sonuç ekranında birincil aksiyonla yarışmasın.
              SahneButton.text(
                key: const ValueKey('result-rate-button'),
                label: context.t(K.rate),
                arrow: false,
                onPressed: onRate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seviye atlama penceresi — sahne dilinde: Perde yüzey, L pah, Zêr taç,
/// "Seviye atladın!", "Seviye N" Zêr plakası ve tek birincil "Devam Et".
/// Gündüz temasında da gece çizilir.
///
/// 2026-09-29 doğallık (K10, K4): başlığın altında aynı şeyi ikinci kez
/// söyleyen bir satır vardı ("Seviye atladın!" → "Yeni bir seviyeye
/// ulaştın!"); söz tekrarı kalktı, yeni seviye plakada okunur. Üst kenardaki
/// kilim şeridi de kalktı: taç ve altın plaka anı zaten taşıyor.
class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.level, required this.onContinue});

  final int level;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return Dialog(
            backgroundColor: t.s1,
            elevation: 0,
            shape: SahneShape.l,
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: SahneSpace.x6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.x6,
                SahneSpace.x8,
                SahneSpace.x6,
                SahneSpace.x6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SahneGlyph(SahneGlyphKind.crown, size: 56),
                  const SizedBox(height: SahneSpace.x4),
                  Semantics(
                    header: true,
                    child: Text(
                      context.t(K.levelUpTitle),
                      textAlign: TextAlign.center,
                      style: SahneType.headline.copyWith(color: t.goldTx),
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x5),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: t.gold,
                      shape: SahneShape.m,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SahneSpace.x5,
                        vertical: SahneSpace.x2,
                      ),
                      child: Text(
                        context.t(K.seviyeP, {'p0': '$level'}),
                        textAlign: TextAlign.center,
                        // Zêr dolgunun üstündeki metin Zêr'in kendi
                        // "üstü" belirtecidir (koyu mürekkep).
                        style: SahneType.headline.copyWith(color: t.onGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x6),
                  SahneButton.primary(
                    label: context.t(K.devamEt2),
                    expand: true,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Turun bütün açıklamalarını tek bölümde toplar.
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
///
/// 2026-09-29 Şahnê: bölüm başlığı (`SahneSectionHeader`) + ipucu + liste
/// grubu; her satırın solunda durum karesi (✓ / ✗ / boş için ⧗). Eski sol
/// renk çubuğu kalktı — durum renkle değil şekil ve sözle verilir.
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

    final t = SahneTokens.of(context);
    return Column(
      key: const ValueKey('result-all-explanations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.allExplanations)),
        Text(
          context.t(K.allExplanationsHint),
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x3),
        SahneListGroup(
          dividerIndent: SahneSpace.x3 + 28 + SahneSpace.x3,
          children: [
            for (final entry in entries)
              ResultExplanationEntry(
                index: entry.index,
                record: entry.record,
                explanation: entry.explanation,
              ),
          ],
        ),
      ],
    );
  }
}

@visibleForTesting
class ResultExplanationEntry extends StatelessWidget {
  const ResultExplanationEntry({
    required this.index,
    required this.record,
    required this.explanation,
    super.key,
  });

  final int index;
  final AnswerRecord record;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Durum şekille ve sözle: oyuncu hangi soruda takıldığını listeyi
    // okumadan bulabilsin.
    final Widget status = record.isUnanswered
        ? Semantics(
            label: context.t(K.blank),
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: t.s2, shape: SahneShape.s),
              child: SizedBox.square(
                dimension: 28,
                child: Icon(AppIcons.hourglass, size: 16, color: t.tx2),
              ),
            ),
          )
        : SahneStatusBadge.square(
            correct: record.isCorrect,
            label: context.t(record.isCorrect ? K.correct : K.wrong),
          );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x3,
        SahneSpace.x3,
        SahneSpace.x4,
        SahneSpace.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2026-09-30 simülatör: soru 3 satırda "…" ile kesiliyordu;
                // oyuncu altındaki cevabı ve açıklamayı soruyu hatırlamadan
                // okuyordu (bu liste tam da "neden" diye açıklamaların
                // toplandığı yer). Soru metni artık tam görünür; uzun soru
                // listeyi uzatır, kaydırma zaten var.
                Text(
                  '$index. ${record.prompt}',
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(
                  '${context.t(K.correctAnswerLabel)}: ${record.correctAnswer}',
                  style: SahneType.captionStrong.copyWith(color: t.okTx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(explanation, style: SahneType.body.copyWith(color: t.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
