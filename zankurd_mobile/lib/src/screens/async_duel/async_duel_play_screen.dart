import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../models/avatar_identity.dart';
import '../../models/quiz_question.dart';
import '../../services/guest_save_prompt.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/player_identity.dart';
import '../../data/streak_store.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/quiz_top_bar.dart';
import '../../widgets/sahne/sahne.dart';
import '../quiz/quiz_option_tile.dart';
import '../quiz/quiz_timer_controller.dart';
import 'async_duel_inbox.dart';
import 'async_duel_result_screen.dart';
import '../../widgets/dialog_action_pair.dart';

/// Tek bir sorunun yaşam döngüsündeki adım.
///
/// [idle]: soru ekranda, oyuncu bir şıkka dokunabilir, sayaç işliyor.
/// [submitting]: bir cevap (dokunma ya da TIMEOUT) sunucuya gönderildi,
/// yanıt bekleniyor; sayaç DURDURULMUŞTUR. [revealed]: yanıt geldi, doğru
/// şık kısa süre gösteriliyor. [error]: `answerAsyncDuel` başarısız oldu;
/// tekrar dene düğmesi bekleniyor.
enum _Phase { idle, submitting, revealed, error }

/// Sırayla düellonun oyun ekranı: sunucunun seçtiği 7 soru, soru başına
/// 20 saniye. Doğru cevap oda maçlarıyla aynı sözleşmeyle GİZLİDİR — yalnız
/// `answerAsyncDuel` cevaplandıktan sonra açıklanır.
/// Çıkışta kalan soruların gönderimine tanınan toplam süre.
@visibleForTesting
Duration asyncDuelQuitSendTimeout = const Duration(seconds: 10);

class AsyncDuelPlayScreen extends StatefulWidget {
  const AsyncDuelPlayScreen({
    required this.repository,
    this.category,
    this.entry,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? category;

  /// Düelloyu nasıl başlatacağı. `null` → rastgele ([category] ile).
  /// Meydan okuma oluşturma/kabul etme için [AsyncDuelEntry].
  final AsyncDuelEntry? entry;

  @override
  State<AsyncDuelPlayScreen> createState() => _AsyncDuelPlayScreenState();
}

class _AsyncDuelPlayScreenState extends State<AsyncDuelPlayScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _questionSeconds = 20;
  static const _questionDurationMs = _questionSeconds * 1000;
  static const _revealPause = Duration(milliseconds: 1200);

  bool _loading = true;
  Object? _startError;
  AsyncDuelStart? _duel;

  late final QuizTimerController _timerController;
  final Stopwatch _stopwatch = Stopwatch();

  /// Yarım bırakılıp dönülen soruda sunucunun SUNUM anından bu yana işleyen
  /// süre ([ZanKurdRepository.presentAsyncDuelQuestion]); yerel kronometreye
  /// eklenir. Yeni soruda sıfırlanır.
  int _presentOffsetMs = 0;

  int get _elapsedMs => _stopwatch.elapsedMilliseconds + _presentOffsetMs;

  int _index = 0;
  _Phase _phase = _Phase.idle;
  String? _selectedAnswer;
  String? _revealedAnswerText;
  String? _pendingChoice;
  int? _pendingResponseMs;

  /// Sunucunun cevabı ONAYLADIĞI sorular (başarılı yanıt ya da 'Already
  /// answered'). Gönderilmiş ama yanıtı gelmemiş ya da ağ hatasıyla düşmüş
  /// soru burada DEĞİLDİR: çıkışta o soru yeniden gönderilir; aksi hâlde
  /// düello 6/7'de sonsuza dek yarım kalırdı.
  final Set<int> _confirmedIndices = {};

  /// Elmas dizisinin hücreleri: sunucunun söylediği doğru/yanlış. Sonucu
  /// bilinmeyen (yanıtı ağda kaybolan) soru bekleyen çizgi kalır —
  /// bilinmeyeni doğru ya da yanlış diye göstermek yalan olurdu.
  List<SahneDiamondState?> _results = const [];

  /// Havadaki cevap isteği (açıklama duraklaması dahil). Çıkış onu bekler ki
  /// aynı soru iki kez gönderilmesin.
  Future<void>? _inFlight;
  bool _exitInFlight = false;

  QuizQuestion get _currentQuestion => _duel!.questions[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerController = QuizTimerController(
      vsync: this,
      duration: const Duration(seconds: _questionSeconds),
      onTimeout: _handleTimeout,
    );
    unawaited(_loadDuel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerController.dispose();
    super.dispose();
  }

  /// Uygulama arka plana gidip dönerse duvar saati esas alınır.
  ///
  /// Ticker arka planda akmaz, yani görsel sayaç donar; ama `Stopwatch`
  /// sistem saatiyle çalışır ve durmaz. Bu KASITLI: oyuncu arka plana
  /// kaçıp cevabı arayıp dönerse gerçek geçen süre onu yine de yakalar.
  /// Zamanı çalan yalnız cevaplanmamış (`_phase == idle`) bir soru vardır;
  /// diğer aşamalarda (gönderiliyor/açıklandı/hata) sayaç zaten durmuştur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _reconcileTimerAfterResume();
  }

  void _reconcileTimerAfterResume() {
    if (_duel == null || _phase != _Phase.idle || _exitInFlight) return;
    final elapsedMs = _elapsedMs;
    if (elapsedMs >= _questionDurationMs) {
      _handleTimeout();
      return;
    }
    final remaining = (_questionDurationMs - elapsedMs) / _questionDurationMs;
    _timerController.sync(remaining);
  }

  Future<void> _loadDuel() async {
    setState(() {
      _loading = true;
      _startError = null;
    });
    try {
      final entry =
          widget.entry ?? AsyncDuelEntry.random(category: widget.category);
      final start = switch (entry.kind) {
        AsyncDuelEntryKind.random => await widget.repository.startAsyncDuel(
          category: entry.category,
        ),
        AsyncDuelEntryKind.createChallenge =>
          await widget.repository.createAsyncDuelChallenge(
            category: entry.category,
            friendId: entry.friendId,
          ),
        AsyncDuelEntryKind.acceptChallenge =>
          await widget.repository.acceptAsyncDuelChallenge(entry.code!),
        AsyncDuelEntryKind.resume => await widget.repository.resumeAsyncDuel(
          entry.duelId!,
        ),
      };
      if (!mounted) return;
      // Yeniden açılan kabul edilmiş meydan okumada 7 sorum zaten bitmiş:
      // oynanacak bir şey yok, sonuç listesine geç (hata/boş ekran yok).
      if (start.alreadyFinished ||
          start.answeredCount >= start.questions.length) {
        unawaited(
          Navigator.of(context).pushReplacement(
            AppRoute.to(AsyncDuelListScreen(repository: widget.repository)),
          ),
        );
        return;
      }
      final resumeAt = start.answeredCount;
      setState(() {
        _duel = start;
        _results = List<SahneDiamondState?>.filled(
          start.questions.length,
          null,
        );
        _loading = false;
        _index = resumeAt;
        _phase = _Phase.idle;
        _selectedAnswer = null;
        _revealedAnswerText = null;
      });
      _confirmedIndices.clear();
      _beginQuestion();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'async duel start failed');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _startError = error;
      });
    }
  }

  void _beginQuestion() {
    _presentOffsetMs = 0;
    _stopwatch
      ..reset()
      ..start();
    _timerController.start();
    unawaited(_presentCurrentQuestion());
  }

  /// Soruyu ekrana koyduğumu sunucuya bildirir. Sunucu süreyi bu andan ölçer
  /// ve ilk kaydı DEĞİŞTİRMEZ: uygulamayı kapatıp açmak saati sıfırlamaz.
  /// Yarım bırakılıp dönülen soruda sunucu saati işlemiştir; sayaç buna
  /// eşitlenir (süre geçmişse hemen TIMEOUT) ve kısa bir not gösterilir.
  /// Hata/eksik RPC sessizce geçilir: cevap eski ölçümle sürer.
  Future<void> _presentCurrentQuestion() async {
    final duelId = _duel?.duelId;
    if (duelId == null) return;
    final index = _index;
    final int? serverElapsed;
    try {
      serverElapsed = await widget.repository.presentAsyncDuelQuestion(
        duelId,
        index,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'async duel present failed');
      return;
    }
    if (serverElapsed == null ||
        !mounted ||
        _exitInFlight ||
        _index != index ||
        _phase != _Phase.idle) {
      return;
    }
    final localMs = _stopwatch.elapsedMilliseconds;
    // Normal ilk sunum: sunucu ile yerel saat ağ gecikmesi kadar ayrışır.
    if (serverElapsed <= localMs + 1500) return;
    _presentOffsetMs = serverElapsed - localMs;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.t(K.asyncDuelResumedQuestionNote))),
    );
    if (serverElapsed >= _questionDurationMs) {
      _handleTimeout();
      return;
    }
    _timerController.sync(
      (_questionDurationMs - serverElapsed) / _questionDurationMs,
    );
  }

  void _handleAnswerTap(String answer) {
    if (_phase != _Phase.idle || _exitInFlight) return;
    final responseMs = _elapsedMs;
    final choice = _currentQuestion.optionKeyForAnswer(answer);
    unawaited(
      _submitAnswer(selected: answer, choice: choice, responseMs: responseMs),
    );
  }

  void _handleTimeout() {
    if (_phase != _Phase.idle || _exitInFlight) return;
    unawaited(
      _submitAnswer(
        selected: null,
        choice: 'TIMEOUT',
        responseMs: _questionDurationMs,
      ),
    );
  }

  Future<void> _submitAnswer({
    required String? selected,
    required String choice,
    required int responseMs,
  }) async {
    _timerController.pause();
    _stopwatch.stop();
    setState(() {
      _phase = _Phase.submitting;
      _selectedAnswer = selected;
      _pendingChoice = choice;
      _pendingResponseMs = responseMs;
    });
    await (_inFlight = _sendAnswer(choice: choice, responseMs: responseMs));
  }

  Future<void> _retryPendingAnswer() async {
    final choice = _pendingChoice;
    final responseMs = _pendingResponseMs;
    if (choice == null || responseMs == null || _exitInFlight) return;
    setState(() => _phase = _Phase.submitting);
    await (_inFlight = _sendAnswer(choice: choice, responseMs: responseMs));
  }

  Future<void> _sendAnswer({
    required String choice,
    required int responseMs,
  }) async {
    final duelId = _duel!.duelId;
    final index = _index;
    try {
      final response = await widget.repository.answerAsyncDuel(
        duelId: duelId,
        questionIndex: index,
        choice: choice,
        responseMs: responseMs,
      );
      _confirmedIndices.add(index);
      if (!mounted || _exitInFlight) return;
      await _handleAnswerResponse(response);
    } catch (error, stack) {
      // Yeniden gönderimde 'Already answered' gelmesi, ilk isteğin aslında
      // sunucuya ULAŞTIĞI ama yanıtının bu istemciye hiç dönmediği anlamına
      // gelir (ağ kopması). Doğru şıkkı açıklayacak bir yanıtımız yok;
      // oyuncuyu açıklamasız sonraki soruya geçiriyoruz.
      if (error.toString().contains('Already answered')) {
        _confirmedIndices.add(index);
        if (!mounted || _exitInFlight) return;
        _advanceOrFinishUnknown(index);
        return;
      }
      ErrorReporter.record(error, stack, reason: 'async duel answer failed');
      if (!mounted || _exitInFlight) return;
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _handleAnswerResponse(AsyncDuelAnswer response) async {
    setState(() {
      _phase = _Phase.revealed;
      if (_index < _results.length) {
        _results[_index] = response.correct
            ? SahneDiamondState.correct
            : SahneDiamondState.wrong;
      }
      _revealedAnswerText = _currentQuestion.answerForOptionKey(
        response.correctOption,
      );
    });
    await Future<void>.delayed(_revealPause);
    // Çıkış onaylandıysa ekran ilerlemez: bir sonraki soru açılıp sayacı
    // başlasaydı oyuncu, çıkış döngüsü o soruyu TIMEOUT ile gönderirken
    // ona cevap verebilir ve aynı soru iki kez gönderilirdi.
    if (!mounted || _exitInFlight) return;
    if (response.finished) {
      _goToResult(response.result);
      return;
    }
    _advanceToNextQuestion();
  }

  /// Bkz. `_sendAnswer`'daki 'Already answered' yorumu: bu sorunun gerçek
  /// sonucunu (bitti mi, kaçıncı soru) bilmiyoruz. Son soruysa yine de bir
  /// sonuç ekranı açabilmek için "bekleniyor" görünümüne düşülür; değilse
  /// sıradaki soruya geçilir.
  void _advanceOrFinishUnknown(int index) {
    final total = _duel!.questions.length;
    if (index + 1 >= total) {
      _goToResult(null);
      return;
    }
    _advanceToNextQuestion();
  }

  void _advanceToNextQuestion() {
    setState(() {
      _index++;
      _phase = _Phase.idle;
      _selectedAnswer = null;
      _revealedAnswerText = null;
      _pendingChoice = null;
      _pendingResponseMs = null;
    });
    _beginQuestion();
  }

  void _goToResult(AsyncDuelResult? result) {
    unawaited(StreakStore.recordActivity());
    final duel = _duel!;
    final view = result == null
        ? AsyncDuelResultView.unknownAfterFinish(duel.duelId)
        : AsyncDuelResultView.fromAnswer(duel, result);
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      AppRoute.to(
        AsyncDuelResultScreen(repository: widget.repository, view: view),
      ),
    );
    // Misafire üç oyunda bir "hesabını kaydet" önerisi (düello de sayılır).
    // Bu ekran kapandığı için sayfa gezginin kendi bağlamından, sonuç
    // ekranının ilk karesinden sonra açılır. Oyunu asla engellemez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        unawaited(GuestSavePrompt.afterGame(navigator.context));
      }
    });
  }

  Future<void> _confirmExit() async {
    if (_exitInFlight) return;
    // Diyalog açıkken soru sayacı DURUR (2026-10-21): "Yarıştan çık?" sorusunu
    // düşünen oyuncunun süresi akıp soruyu yakıyordu (19 → 7). Duvar saati
    // (`_stopwatch`) da durur ki sunucuya giden `responseMs` ile ekrandaki
    // sayaç ayrışmasın; cevap süresini sunucu yeniden hesaplamaz, istemci
    // bildirir.
    final pauseForDialog =
        _phase == _Phase.idle && _timerController.isAnimating;
    if (pauseForDialog) {
      _timerController.pause();
      _stopwatch.stop();
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t(K.asyncDuelQuitTitle)),
        content: Text(dialogContext.t(K.asyncDuelQuitBody)),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(dialogContext.t(K.asyncDuelQuit)),
            ),
            confirm: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.t(K.asyncDuelKeepPlaying)),
            ),
          ),
        ],
      ),
    );
    if (quit != true || !mounted) {
      if (pauseForDialog &&
          mounted &&
          _phase == _Phase.idle &&
          !_exitInFlight) {
        _stopwatch.start();
        _timerController.resume();
      }
      return;
    }
    await _quitAndTimeoutRemaining();
  }

  /// Yarım bırakılan düello de sonuçlansın diye sunucunun onaylamadığı
  /// TÜM sorular gönderilir, sonra ekran kapanır.
  ///
  /// Önce havadaki istek beklenir (aynı soru iki kez gitmesin). Gönderimi
  /// ağ hatasıyla düşmüş soru oyuncunun KENDİ seçimiyle yeniden gider —
  /// oyuncu o soruyu cevaplamıştı; kalanlar TIMEOUT'tur. Tek tek hata
  /// yutulur (kaydedilir): ilk hatada vazgeçmek düelloyu daha da yarım
  /// bırakırdı.
  Future<void> _quitAndTimeoutRemaining() async {
    setState(() => _exitInFlight = true);
    _timerController.pause();
    _stopwatch.stop();
    final inFlight = _inFlight;
    if (inFlight != null) await inFlight;
    final duel = _duel;
    if (duel != null) {
      // Gönderimler PARALEL ve toplam süre sınırlı (2026-10-21): sırayla
      // beklemek yavaş ağda her RPC için 15 sn demekti; ekran dakikalarca
      // `_exitInFlight` ile tutuluyordu. Süre aşılırsa ekran yine kapanır;
      // ulaşmayan sorular sunucudaki süre dolumuyla tamamlanır.
      final sends = <Future<void>>[];
      for (var i = 0; i < duel.questions.length; i++) {
        if (_confirmedIndices.contains(i)) continue;
        final pendingChoice = _pendingChoice;
        final pendingMs = _pendingResponseMs;
        final resendPending =
            i == _index && pendingChoice != null && pendingMs != null;
        sends.add(
          _sendQuietly(
            duelId: duel.duelId,
            index: i,
            choice: resendPending ? pendingChoice : 'TIMEOUT',
            responseMs: resendPending ? pendingMs : _questionDurationMs,
          ),
        );
      }
      try {
        await Future.wait(sends).timeout(asyncDuelQuitSendTimeout);
      } on TimeoutException {
        ErrorReporter.record(
          TimeoutException('async duel quit sends'),
          StackTrace.current,
          reason: 'async duel quit timed out; closing anyway',
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Çıkış döngüsünün tek gönderimi. 'Already answered' beklenen bir
  /// sonuçtur (önceki istek aslında ulaşmıştı); hata olarak kaydedilmez.
  Future<void> _sendQuietly({
    required String duelId,
    required int index,
    required String choice,
    required int responseMs,
  }) async {
    try {
      await widget.repository.answerAsyncDuel(
        duelId: duelId,
        questionIndex: index,
        choice: choice,
        responseMs: responseMs,
      );
      _confirmedIndices.add(index);
    } catch (error, stack) {
      if (error.toString().contains('Already answered')) {
        _confirmedIndices.add(index);
        return;
      }
      ErrorReporter.record(
        error,
        stack,
        reason: 'async duel quit timeout failed',
      );
    }
  }

  /// 2026-09-29 Şahnê: C iskeleti (oyun sahnesi, her temada gece) — soru
  /// ekranıyla aynı dil: kapat | ortada sayaç elması | altında 7'li elmas
  /// dizisi; sahne zemininde sorunun kategori çizimi (%14) ve ışık huzmesi.
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Kapatma düğmesi şart: `AppRoute` iOS'ta kaydırarak geri gitmeyi
      // sunmuyor; bağlantı yavaşken oyuncu bu ekranda mahsur kalırdı.
      return SahneStageScaffold(
        closeKey: const ValueKey('async-duel-loading-close'),
        closeLabel: context.t(K.close),
        onClose: () => Navigator.of(context).pop(),
        center: Text(context.t(K.asyncDuel)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_startError != null) {
      final challengeError = classifyAsyncDuelChallengeError(_startError!);
      return _StartErrorView(
        tooMany: challengeError == AsyncDuelChallengeError.tooMany,
        message: asyncDuelStartErrorMessage(context, _startError!),
        onRetry: asyncDuelChallengeErrorIsTerminal(challengeError)
            ? null
            : _loadDuel,
      );
    }
    return _buildPlayScaffold(context);
  }

  Widget _buildPlayScaffold(BuildContext context) {
    final duel = _duel!;
    final question = _currentQuestion;
    final answers = question.displayAnswers;
    final total = duel.questions.length;
    final suspenseVisual =
        _phase == _Phase.submitting || _phase == _Phase.error;
    final disabled = _phase != _Phase.idle || _exitInFlight;
    final progressLabel = '${_index + 1}/$total';

    return PopScope(
      key: const ValueKey('async-duel-play'),
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: SahneStageScaffold(
        closeKey: const ValueKey('async-duel-quit'),
        closeLabel: context.t(K.close),
        onClose: () => unawaited(_confirmExit()),
        // Kurul 3. tur (2026-10-20): üst çubuk soru ekranıyla (16) AYNI
        // yerleşim: kategori ışığı + dağ sırtı ufku, sağda sayaç ve ⋯
        // yuvası. Düello sorusunda kaydet/bildir yok; yuva boş ama yer
        // tutar, böylece sayaç iki ekranda aynı x'te durur.
        light: SahneCategoryLight.of(
          CategoryVisuals.canonicalName(question.category),
        ),
        ridge: true,
        // 2026-10-20 renk ve canlılık (B): üst bant sorunun konusunun renginde
        // (ders ve yarışma ekranıyla aynı; renk uygulama temasından okunur).
        band: CategoryVisuals.tone(
          question.category,
        ).fill(night: Theme.of(context).brightness == Brightness.dark),
        bandProgress: SahneProgressBar(
          key: const ValueKey('async-duel-progress-bar'),
          // `_results` toplam uzunlukta ve boş (`null`) başlar: yalnız
          // cevaplananlar dolu sayılır.
          value: total == 0
              ? 0
              : (_results.where((r) => r != null).length / total).clamp(
                  0.0,
                  1.0,
                ),
          height: 6,
          fillColor: SahneVivid.onFill,
          trackColor: SahneVivid.glassTrack,
          semanticLabel: progressLabel,
        ),
        // 2026-09-29 doğallık (K2): soru arkasındaki hayalet kategori
        // çizimi kalktı (bkz. quiz_screen `_stageLight`).
        //
        // 2026-10-19 sadeleşme: üst satır soru ekranıyla aynı (kapat | ortada
        // düello adı | sağda kalan saniye); 60 px'lik elmas sayaç ve 7'li
        // elmas dizisi kalktı, yerine 4 px'lik ince ilerleme çubuğu geldi.
        center: QuizStageCenter(
          category: question.category,
          index: _index,
          total: total,
          textKey: const ValueKey('async-duel-progress'),
          onBand: true,
        ),
        // Çıkış gönderilirken sayaç yerine bekleme göstergesi: kalan
        // sorular sunucuya TIMEOUT olarak gidiyor.
        score: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _exitInFlight
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SahneVivid.onFill,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _timerController.animation,
                      builder: (context, _) {
                        final fraction = _timerController.animation.value;
                        final seconds = (fraction * _questionSeconds).ceil();
                        return SahneStageTimer(
                          secondsLeft: seconds,
                          // Cevap gönderildikten sonra sayaç durur; gerilim rengi
                          // de söner.
                          hotSeconds: disabled ? -1 : 5,
                          onBand: true,
                          semanticLabel:
                              '$seconds ${context.t(K.secondsShortUnit)}',
                        );
                      },
                    ),
              const SizedBox(width: SahneSpace.x1),
              const SizedBox.square(
                key: ValueKey('async-duel-more-slot'),
                dimension: sahneTapTarget,
              ),
            ],
          ),
        ),
        // Cevap gönderilemediyse alt perdede TEK birincil: tekrar dene.
        dock: _phase == _Phase.error
            ? SahneButton.primary(
                label: context.t(K.retry),
                icon: AppIcons.arrowsRotate,
                arrow: false,
                expand: true,
                onPressed: () => unawaited(_retryPendingAnswer()),
              )
            : null,
        // Tek kaydırılabilir gövde: soru metni + şıklar birlikte kayar. Eski
        // Column + Expanded(ListView) düzeninde uzun bir soru %200 yazıda
        // şık listesine yer bırakmıyor, ekran alttan taşıyordu.
        body: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            // Kurul 2026-10-20: şıklar alta (baş parmak bölgesi), soru boş
            // alanda ortalanır — ders ve yarışma ekranıyla AYNI yerleşim.
            return LayoutBuilder(
              builder: (context, constraints) {
                final reserve = quizAnswerBottomReserve(
                  context,
                  constraints.maxHeight,
                );
                return SahneStageScroll(
                  scrollKey: const ValueKey('async-duel-scroll'),
                  // Yeni soruda başa dön; üst kenar elmas şeridin altında sönsün.
                  resetKey: _index,
                  padding: EdgeInsets.fromLTRB(
                    SahneSpace.page,
                    SahneSpace.x4,
                    SahneSpace.page,
                    reserve,
                  ),
                  child: ConstrainedBox(
                    key: const ValueKey('async-duel-answers-anchored'),
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0.0,
                        constraints.maxHeight - SahneSpace.x4 - reserve,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Sıra ve kategori ortak üst satırda; burada yalnız
                        // rakip bağlamı (boş yuva soruyu ortalar). Rakip adı
                        // biliniyorsa avatarıyla birlikte ("Sen · Rojda"):
                        // "Rojda'ya karşı" Türkçe ek uyumu gerektirdiği için
                        // yeni cümle kurulmadı (NEEDS_JURY).
                        Padding(
                          padding: const EdgeInsets.only(bottom: SahneSpace.x4),
                          child: duel.role == AsyncDuelRole.opponent
                              ? _RivalLine(
                                  name: duel.opponentName == null
                                      ? context.t(K.asyncDuelOpponent)
                                      : context.playerDisplayName(
                                          duel.opponentName,
                                          tag: duel.opponentProfile?.playerTag,
                                        ),
                                  rawName: duel.opponentName,
                                  identity: duel.opponentProfile?.avatar,
                                  you: context.t(K.you),
                                )
                              : Text(
                                  context.t(K.asyncDuelSub),
                                  style: SahneType.caption.copyWith(
                                    color: t.tx2,
                                  ),
                                ),
                        ),
                        _QuestionText(text: question.promptText),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: SahneSpace.x4),
                            if (_phase == _Phase.error) ...[
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.triangleExclamation,
                                    size: 20,
                                    color: t.errTx,
                                  ),
                                  const SizedBox(width: SahneSpace.x2),
                                  Expanded(
                                    child: Text(
                                      context.t(K.asyncDuelAnswerFailed),
                                      style: SahneType.bodyStrong.copyWith(
                                        color: t.errTx,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: SahneSpace.x3),
                            ],
                            for (final (i, answer) in answers.indexed)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SahneSpace.x2,
                                ),
                                child: QuizOptionTile(
                                  key: ValueKey('async-duel-option-$i'),
                                  index: i,
                                  answer: answer,
                                  selected: _selectedAnswer == answer,
                                  correct:
                                      _revealedAnswerText != null &&
                                      answer == _revealedAnswerText,
                                  disabled: disabled,
                                  suspense: suspenseVisual,
                                  optionCount: answers.length,
                                  tone: CategoryVisuals.tone(question.category),
                                  dimmed:
                                      _revealedAnswerText != null &&
                                      answer != _revealedAnswerText &&
                                      _selectedAnswer != answer,
                                  onTap: () => _handleAnswerTap(answer),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Alt başlık satırı: avatar + "Sen · Rakip adı".
class _RivalLine extends StatelessWidget {
  const _RivalLine({
    required this.name,
    required this.you,
    this.rawName,
    this.identity,
  });

  final String name;
  final String you;

  /// HAM rakip adı ve fotoğraf/simge kimliği (avatar için); yoksa baş harf.
  final String? rawName;
  final AvatarIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      key: const ValueKey('async-duel-rival-line'),
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar.fromIdentity(
          radius: 12,
          identity: identity,
          displayName: rawName ?? name,
        ),
        const SizedBox(width: SahneSpace.x2),
        Flexible(
          child: Text(
            '$you · $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
      ],
    );
  }
}

/// Soru metni: Soru 24/30; 24'te dört satırı aşarsa Manşet 22/28'e iner.
/// Karar karakter sayısıyla değil, gerçek ölçümle (`TextPainter`) verilir.
class _QuestionText extends StatelessWidget {
  const _QuestionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: SahneType.question.copyWith(fontFamily: SahneType.display),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 4,
        )..layout(maxWidth: constraints.maxWidth);
        final style = painter.didExceedMaxLines
            ? SahneType.headline
            : SahneType.question;
        painter.dispose();
        return Semantics(
          header: true,
          child: Text(text, style: style.copyWith(color: t.tx)),
        );
      },
    );
  }
}

/// Başlatma hatasının oyuncuya gösterilen DÜRÜST metni. Meydan okuma
/// hatalarının her biri ayrı bir cümledir (süresi dolmuş, başkası almış,
/// kendi bağlantım…); bilinmeyen hata genel "başlatılamadı"dır.
String asyncDuelStartErrorMessage(BuildContext context, Object error) {
  final key = switch (classifyAsyncDuelChallengeError(error)) {
    AsyncDuelChallengeError.notFound => K.challengeErrNotFound,
    AsyncDuelChallengeError.own => K.challengeErrOwn,
    AsyncDuelChallengeError.taken => K.challengeErrTaken,
    AsyncDuelChallengeError.expired => K.challengeErrExpired,
    AsyncDuelChallengeError.notForYou => K.challengeErrNotForYou,
    AsyncDuelChallengeError.notReady => K.challengeErrNotReady,
    AsyncDuelChallengeError.notAFriend => K.challengeErrNotAFriend,
    AsyncDuelChallengeError.tooMany => K.asyncDuelTooMany,
    AsyncDuelChallengeError.noQuestions ||
    AsyncDuelChallengeError.other => K.asyncDuelStartFailed,
  };
  return context.t(key);
}

class _StartErrorView extends StatelessWidget {
  const _StartErrorView({
    required this.tooMany,
    required this.message,
    required this.onRetry,
  });

  final bool tooMany;
  final String message;

  /// `null` → yeniden denemek anlamsız (bağlantı geçersiz); yalnız Kapat.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SahneStageScaffold(
      closeLabel: context.t(K.close),
      onClose: () => Navigator.of(context).pop(),
      center: Text(context.t(K.asyncDuel)),
      beam: false,
      dock: Row(
        children: [
          Expanded(
            flex: 2,
            child: onRetry == null
                ? SahneButton.primary(
                    key: const ValueKey('async-duel-start-error-close'),
                    label: context.t(K.close),
                    arrow: false,
                    onPressed: () => Navigator.of(context).pop(),
                    expand: true,
                  )
                : SahneButton.secondary(
                    label: context.t(K.close),
                    onPressed: () => Navigator.of(context).pop(),
                    expand: true,
                  ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              flex: 3,
              child: SahneButton.primary(
                label: context.t(K.retry),
                icon: AppIcons.arrowsRotate,
                arrow: false,
                onPressed: onRetry,
                expand: true,
              ),
            ),
          ],
        ],
      ),
      body: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SahneSpace.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SahneAvatar(
                    size: 72,
                    icon: tooMany ? AppIcons.hourglass : AppIcons.cloud,
                    color: t.s2,
                    foreground: t.tx2,
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  Text(
                    message,
                    key: const ValueKey('async-duel-start-error'),
                    textAlign: TextAlign.center,
                    style: SahneType.headline.copyWith(color: t.tx),
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
