import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../models/quiz_question.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../quiz/quiz_option_tile.dart';
import '../quiz/quiz_timer_controller.dart';
import '../quiz/quiz_timer_widget.dart';
import 'async_duel_result_screen.dart';

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
class AsyncDuelPlayScreen extends StatefulWidget {
  const AsyncDuelPlayScreen({
    required this.repository,
    this.category,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? category;

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
    final elapsedMs = _stopwatch.elapsedMilliseconds;
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
      final start = await widget.repository.startAsyncDuel(
        category: widget.category,
      );
      if (!mounted) return;
      setState(() {
        _duel = start;
        _loading = false;
        _index = 0;
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
    _stopwatch
      ..reset()
      ..start();
    _timerController.start();
  }

  void _handleAnswerTap(String answer) {
    if (_phase != _Phase.idle || _exitInFlight) return;
    final responseMs = _stopwatch.elapsedMilliseconds;
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
    final duel = _duel!;
    final view = result == null
        ? AsyncDuelResultView.unknownAfterFinish(duel.duelId)
        : AsyncDuelResultView.fromAnswer(duel, result);
    Navigator.of(context).pushReplacement(
      AppRoute.to(
        AsyncDuelResultScreen(repository: widget.repository, view: view),
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (_exitInFlight) return;
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t(K.asyncDuelQuitTitle)),
        content: Text(dialogContext.t(K.asyncDuelQuitBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(dialogContext.t(K.asyncDuelQuit)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t(K.asyncDuelKeepPlaying)),
          ),
        ],
      ),
    );
    if (quit != true || !mounted) return;
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
      for (var i = 0; i < duel.questions.length; i++) {
        if (_confirmedIndices.contains(i)) continue;
        final pendingChoice = _pendingChoice;
        final pendingMs = _pendingResponseMs;
        final resendPending =
            i == _index && pendingChoice != null && pendingMs != null;
        await _sendQuietly(
          duelId: duel.duelId,
          index: i,
          choice: resendPending ? pendingChoice : 'TIMEOUT',
          responseMs: resendPending ? pendingMs : _questionDurationMs,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Kapatma düğmesi şart: `AppRoute` iOS'ta kaydırarak geri gitmeyi
      // sunmuyor; bağlantı yavaşken oyuncu bu ekranda mahsur kalırdı.
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('async-duel-loading-close'),
            icon: const Icon(AppIcons.xmark),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_startError != null) {
      return _StartErrorView(
        tooMany: _startError.toString().contains('Too many open duels'),
        onRetry: _loadDuel,
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

    return PopScope(
      key: const ValueKey('async-duel-play'),
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _exitInFlight
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  key: const ValueKey('async-duel-quit'),
                  icon: const Icon(AppIcons.xmark),
                  onPressed: () => unawaited(_confirmExit()),
                ),
          centerTitle: true,
          title: Text(
            '${_index + 1}/$total',
            key: const ValueKey('async-duel-progress'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: QuizTimerWidget(
                  animation: _timerController.animation,
                  maxSeconds: _questionSeconds,
                  isPaused: disabled,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duel.role == AsyncDuelRole.opponent
                      ? '${context.t(K.you)} · '
                            '${duel.opponentName ?? context.t(K.asyncDuelOpponent)}'
                      : context.t(K.asyncDuelSub),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textSubColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  question.promptText,
                  style: AppTypography.heading2.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_phase == _Phase.error) ...[
                  Text(
                    context.t(K.asyncDuelAnswerFailed),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.wrong,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton(
                    onPressed: () => unawaited(_retryPendingAnswer()),
                    child: Text(context.t(K.retry)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Expanded(
                  child: ListView(
                    children: [
                      for (final (i, answer) in answers.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                            dimmed:
                                _revealedAnswerText != null &&
                                answer != _revealedAnswerText &&
                                _selectedAnswer != answer,
                            onTap: () => _handleAnswerTap(answer),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartErrorView extends StatelessWidget {
  const _StartErrorView({required this.tooMany, required this.onRetry});

  final bool tooMany;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t(
                    tooMany ? K.asyncDuelTooMany : K.asyncDuelStartFailed,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.t(K.close)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(context.t(K.retry)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
