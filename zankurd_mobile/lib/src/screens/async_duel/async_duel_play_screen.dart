import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../config/category_visuals.dart';
import '../../game/reveal_timing.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../models/avatar_identity.dart';
import '../../models/quiz_question.dart';
import '../../services/answer_feedback.dart';
import '../../services/guest_save_prompt.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/player_identity.dart';
import '../../data/daily_mission_store.dart';
import '../../data/streak_store.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/quiz_stage_kit.dart';
import '../../widgets/quiz_top_bar.dart';
import '../../widgets/sahne/sahne.dart';
import '../quiz/quiz_fit.dart';
import '../quiz/quiz_option_tile.dart';
import '../quiz/quiz_timer_controller.dart';
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

  bool _loading = true;
  Object? _startError;
  AsyncDuelStart? _duel;

  late final QuizTimerController _timerController;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _revealTimer;
  Completer<void>? _revealDone;

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

  /// Oynanan sorular. Turnuvada sunulmamış soru yer tutucudur; içeriği
  /// sunumda gelir ve buraya yazılır.
  List<QuizQuestion> _questions = const [];

  QuizQuestion get _currentQuestion => _questions[_index];

  /// Turnuva: sorunun içeriği sunucudan bekleniyor (soru ve sayaç henüz
  /// yok) ya da sunum başarısız oldu (yeniden dene).
  bool _awaitingQuestion = false;
  bool _presentFailed = false;

  /// Sunucu puanlı turnuva maçı mı? (2026-10-27) Aynı oyun akışı; RPC'ler
  /// turnuvanınkidir ve bitince sonuç ekranı yerine şemaya dönülür.
  bool get _isTournament => widget.entry?.isTournament ?? false;

  Future<AsyncDuelAnswer> _answer({
    required String id,
    required int index,
    required String choice,
    required int responseMs,
  }) => _isTournament
      ? widget.repository.answerTournamentQuestion(
          matchId: id,
          questionIndex: index,
          choice: choice,
        )
      : widget.repository.answerAsyncDuel(
          duelId: id,
          questionIndex: index,
          choice: choice,
          responseMs: responseMs,
        );

  /// Turnuva maçından şemaya dönüş: çağıran şemayı yeniden okur.
  void _popToTournament() {
    Navigator.of(context).pop(<String, Object?>{'completed': true});
  }

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
    _resumedTimer?.cancel();
    _revealTimer?.cancel();
    final revealDone = _revealDone;
    if (revealDone != null && !revealDone.isCompleted) revealDone.complete();
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
    if (_duel == null ||
        _phase != _Phase.idle ||
        _exitInFlight ||
        _awaitingQuestion ||
        _presentFailed) {
      return;
    }
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
        AsyncDuelEntryKind.tournament =>
          await widget.repository.startTournamentMatch(entry.duelId!),
      };
      if (!mounted) return;
      // Turnuva maçını zaten bitirmişim (ör. son cevabın yanıtı kayboldu):
      // oynanacak soru yok, şema durumu gösterir.
      if (_isTournament &&
          (start.alreadyFinished ||
              start.answeredCount >= start.questions.length)) {
        _popToTournament();
        return;
      }
      _duel = start;
      _questions = start.questions;
      // Yeniden açılan kabul edilmiş meydan okumada 7 sorum zaten bitmiş:
      // oynanacak bir şey yok, sonuç listesine geç (hata/boş ekran yok).
      if (start.alreadyFinished ||
          start.answeredCount >= start.questions.length) {
        if (!await _goToResult(null)) {
          throw StateError('Final duel result unavailable');
        }
        return;
      }
      final resumeAt = start.answeredCount;
      setState(() {
        _duel = start;
        _questions = [
          for (final question in start.questions)
            question.forRound(start.duelId),
        ];
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
      _confirmedIndices
        ..clear()
        ..addAll(Iterable<int>.generate(resumeAt));
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
    if (_isTournament || widget.repository is AsyncDuelContentPort) {
      unawaited(_presentTournamentQuestion());
      return;
    }
    _presentOffsetMs = 0;
    _stopwatch
      ..reset()
      ..start();
    _timerController.start();
    // Sunucu sunumu dönene kadar kalan süre bilinmez (yarım kalan soruya
    // dönüşte sunucu saati işlemiştir): sayaç "–" gösterir, tahmin yazmaz.
    setState(() => _timeSynced = false);
    unawaited(
      _presentCurrentQuestion().whenComplete(() {
        if (mounted && !_timeSynced) setState(() => _timeSynced = true);
      }),
    );
  }

  /// Kalan süre sunucuyla eşitlendi mi (bkz. [_beginQuestion]).
  bool _timeSynced = true;

  /// Turnuva: soru İÇERİĞİ sunumla gelir; soru ve sayaç ancak sunucu
  /// sunumu kaydettikten sonra görünür (sunucu süreyi o andan ölçer).
  /// Yarım bırakılıp dönülen soruda sunucu saati işlemiştir: sayaç buna
  /// eşitlenir, süre geçmişse hemen TIMEOUT.
  Future<void> _presentTournamentQuestion() async {
    final duel = _duel;
    if (duel == null) return;
    final index = _index;
    _timerController.pause();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _awaitingQuestion = true;
      _presentFailed = false;
    });
    final TournamentPresent presented;
    try {
      final repository = widget.repository;
      presented = !_isTournament && repository is AsyncDuelContentPort
          ? await (repository as AsyncDuelContentPort).presentAsyncDuelContent(
              duel.duelId,
              index,
            )
          : await repository.presentTournamentQuestion(duel.duelId, index);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tournament present failed');
      if (!mounted || _index != index || _exitInFlight) return;
      setState(() {
        _awaitingQuestion = false;
        _presentFailed = true;
      });
      return;
    }
    if (!mounted || _index != index || _exitInFlight) return;
    // Eski sunucu başlangıçta tam içerik verir. Yalnız gerçekten dolu
    // mevcut soru fallback olabilir; yeni sunucunun yer tutucusu açılamaz.
    final question =
        presented.question ??
        (!_isTournament && _questions[index].prompt.isNotEmpty
            ? _questions[index]
            : null);
    // İçerik yoksa (beklenmedik sunucu yanıtı) yer tutucu soru açılmaz ve
    // sayaç başlamaz: oyuncu cevaplanamaz bir soruda süre yakardı.
    if (question == null || index >= _questions.length) {
      setState(() {
        _awaitingQuestion = false;
        _presentFailed = true;
      });
      return;
    }
    setState(() {
      _questions[index] = question.forRound(duel.duelId);
      _awaitingQuestion = false;
    });
    _presentOffsetMs = presented.elapsedMs;
    _stopwatch.start();
    _timerController.start();
    if (presented.elapsedMs > 1500) _showResumedNotice();
    if (presented.elapsedMs >= _questionDurationMs) {
      _handleTimeout();
      return;
    }
    if (presented.elapsedMs > 0) {
      _timerController.sync(
        (_questionDurationMs - presented.elapsedMs) / _questionDurationMs,
      );
    }
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
    _showResumedNotice();
    if (serverElapsed >= _questionDurationMs) {
      _handleTimeout();
      return;
    }
    _timerController.sync(
      (_questionDurationMs - serverElapsed) / _questionDurationMs,
    );
  }

  Timer? _resumedTimer;

  /// Yarım kalan soruya dönüldüğü bilgisi gösteriliyor mu.
  bool _resumedVisible = false;

  /// Kurul C31 + tur 3 (2026-10-30): yarım kalan soruya dönüşte süre bilgisi.
  ///
  /// Önce en altta küçük bir SnackBar'dı (görülmüyordu); sonra sahnenin
  /// üstünde bir kaplamaydı ve soru kartının ilk satırını ~4 sn örtüyordu.
  /// Şimdi üst çubuktaki mod çipi 5 sn kehribar "Süre işliyor" olur — sayacın
  /// hemen yanında, hiçbir şeyi örtmez ve çipin yüksekliği aynı olduğundan
  /// yerleşimi itmez. Tam cümle ekran okuyucuya duyurulur.
  void _showResumedNotice() {
    if (!mounted) return;
    _resumedTimer?.cancel();
    setState(() => _resumedVisible = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.t(K.asyncDuelResumedQuestionNote),
      Directionality.of(context),
    );
    _resumedTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _resumedVisible = false);
    });
  }

  void _handleAnswerTap(String answer) {
    if (_phase != _Phase.idle ||
        _exitInFlight ||
        _awaitingQuestion ||
        _presentFailed) {
      return;
    }
    final responseMs = _elapsedMs;
    final choice = _currentQuestion.optionKeyForAnswer(answer);
    unawaited(
      _submitAnswer(selected: answer, choice: choice, responseMs: responseMs),
    );
  }

  void _handleTimeout() {
    if (_phase != _Phase.idle ||
        _exitInFlight ||
        _awaitingQuestion ||
        _presentFailed) {
      return;
    }
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
      final response = await _answer(
        id: duelId,
        index: index,
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
        await _advanceOrFinishUnknown(index);
        return;
      }
      // Son cevap işlenmiş ama HTTP yanıtı kaybolmuş olabilir. Doğru
      // toplamını yalnız mevcut sunucu sonuç okumasından kurtar.
      if (!_isTournament &&
          index + 1 >= _questions.length &&
          mounted &&
          !_exitInFlight) {
        if (await _goToResult(null)) return;
      }
      ErrorReporter.record(error, stack, reason: 'async duel answer failed');
      if (!mounted || _exitInFlight) return;
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _handleAnswerResponse(AsyncDuelAnswer response) async {
    // Ana soru ekranıyla aynı ses + titreşim (kapışma U18). Süre dolumunda
    // da yanlış geri bildirimi verilir: QuizScreen de öyle yapar.
    playAnswerFeedback(context, correct: response.correct);
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
    // Ekran kapanırsa Future.delayed'in gizli Timer'ı yaşamaya devam eder.
    // Süreyi sahiplen; dispose hem Timer'ı iptal eder hem bekleyeni çözer.
    final revealDone = Completer<void>();
    _revealDone = revealDone;
    _revealTimer = Timer(
      RevealTiming.individual(correct: response.correct),
      revealDone.complete,
    );
    await revealDone.future;
    _revealDone = null;
    _revealTimer = null;
    // Çıkış onaylandıysa ekran ilerlemez: bir sonraki soru açılıp sayacı
    // başlasaydı oyuncu, çıkış döngüsü o soruyu TIMEOUT ile gönderirken
    // ona cevap verebilir ve aynı soru iki kez gönderilirdi.
    if (!mounted || _exitInFlight) return;
    if (response.finished) {
      if (!await _goToResult(response.result) && mounted) {
        setState(() => _phase = _Phase.error);
      }
      return;
    }
    _advanceToNextQuestion();
  }

  /// Bkz. `_sendAnswer`'daki 'Already answered' yorumu: bu sorunun gerçek
  /// sonucunu (bitti mi, kaçıncı soru) bilmiyoruz. Son soruda toplamı
  /// sunucu listesinden tekrar okuruz; okunamazsa yeniden deneme görünür.
  /// Ara sorularda sıradaki soruya geçilir.
  Future<void> _advanceOrFinishUnknown(int index) async {
    final total = _questions.length;
    if (index + 1 >= total) {
      if (!await _goToResult(null) && mounted) {
        setState(() => _phase = _Phase.error);
      }
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

  /// Bu yarış günlük görevlere bir kez işlendi mi.
  bool _missionReported = false;

  /// Sırayla düello ve sunucu puanlı kupa maçı BİTTİĞİNDE günlük görevleri
  /// ilerletir. Eskiden yalnız normal quiz sonuç akışı çağırıyordu: yarış
  /// tamamlayan kullanıcı "yarış tamamla" ve "doğru cevap" görevlerini
  /// ilerletemiyordu (Codex denetimi 2026-10-29). XP burada verilmez: ödül
  /// ana ekranda "Ödülü al" ile tek kez yazılır.
  Future<void> _reportMissionProgress(int myCorrect) async {
    if (_missionReported) return;
    try {
      final store = await DailyMissionStore.load();
      await store.reportQuizCompleted(
        completionId:
            '${_isTournament ? 'tournament' : 'async-duel'}:${_duel!.duelId}',
        correctAnswers: myCorrect,
        category: _questions.isEmpty
            ? (widget.category ?? '')
            : _questions.first.category,
        streakAlive: true,
      );
      _missionReported = true;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'async_duel_mission_report');
      rethrow;
    }
  }

  Future<bool> _goToResult(AsyncDuelResult? result) async {
    final duel = _duel!;
    AsyncDuelSummary? recovered;
    if (result == null && !_isTournament) {
      try {
        final summaries = await widget.repository.loadMyAsyncDuels();
        for (final summary in summaries) {
          // list_my_async_duels.my_correct yalnız async_duel_results'tan
          // gelir; sonuç satırı ancak bütün cevaplar kaydolunca oluşur.
          // Kısmi turda null'dır, final yanıt kaybıyla karıştırılmaz.
          if (summary.duelId == duel.duelId && summary.myCorrect != null) {
            recovered = summary;
            break;
          }
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'async duel final recovery');
      }
      if (recovered == null) return false;
    }
    final myCorrect = result?.myCorrect ?? recovered?.myCorrect;
    if (myCorrect != null) {
      try {
        await _reportMissionProgress(myCorrect);
      } catch (_) {
        return false;
      }
    }
    if (!mounted || _exitInFlight) return false;
    unawaited(StreakStore.recordActivity());
    if (_isTournament) {
      _popToTournament();
      return true;
    }
    final view = recovered != null
        ? AsyncDuelResultView.fromSummary(recovered)
        : AsyncDuelResultView.fromAnswer(duel, result!);
    Navigator.of(context).pushReplacement(
      AppRoute.to(
        AsyncDuelResultScreen(
          repository: widget.repository,
          view: view,
          pendingGuestSave: GuestSavePrompt.countGame(context),
        ),
      ),
    );
    return true;
  }

  Future<void> _confirmExit() async {
    if (_exitInFlight) return;
    // Diyalog açıkken soru sayacı DURUR (2026-10-21): "Yarıştan çık?" sorusunu
    // düşünen oyuncunun süresi akıp soruyu yakıyordu (19 → 7). 2026-10-29:
    // sunucu saati durmadığı için yalnız görsel sayaç durur (aşağıya bkz.).
    final pauseForDialog =
        _phase == _Phase.idle && _timerController.isAnimating;
    // Yalnız GÖRSEL sayaç durur; duvar saati (`_stopwatch`) işlemeye devam
    // eder. Süreyi sunucu sunum anından ölçer ve diyalog sırasında akar:
    // kronometre durdurulunca dönüşte ekranda süre varmış gibi görünüp
    // 25 sn'yi aşmış doğru cevap yanlış sayılıyordu (Codex denetimi
    // 2026-10-29). Dönüşte `_reconcileTimerAfterResume` sayacı eşitler,
    // süre dolmuşsa zaman aşımını işler.
    if (pauseForDialog) {
      _timerController.pause();
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.t(
            _isTournament ? K.tournamentQuitTitle : K.asyncDuelQuitTitle,
          ),
        ),
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
        _reconcileTimerAfterResume();
      }
      return;
    }
    await _quitAndTimeoutRemaining();
  }

  /// Sıralı RPC sözleşmesi: bir indeks onaylanmadan sonraki gönderilmez.
  /// Havadaki cevap dahil toplam bütçe dolunca yeni istek başlatılmaz;
  /// yarım kalan düello mevcut "Yarım kaldı" sonucuyla açıkça gösterilir.
  Future<void> _quitAndTimeoutRemaining() async {
    setState(() => _exitInFlight = true);
    _timerController.pause();
    _stopwatch.stop();
    final duel = _duel;
    var stopped = false;
    Future<void> sendRemaining() async {
      final inFlight = _inFlight;
      if (inFlight != null) await inFlight;
      if (duel == null || stopped) return;
      for (var i = 0; i < _questions.length; i++) {
        if (stopped) return;
        if (_confirmedIndices.contains(i)) continue;
        final pendingChoice = _pendingChoice;
        final pendingMs = _pendingResponseMs;
        final resendPending =
            i == _index && pendingChoice != null && pendingMs != null;
        for (var attempt = 0; attempt < 2 && !stopped; attempt++) {
          await _sendQuietly(
            duelId: duel.duelId,
            index: i,
            choice: resendPending ? pendingChoice : 'TIMEOUT',
            responseMs: resendPending ? pendingMs : _questionDurationMs,
          );
          if (_confirmedIndices.contains(i)) break;
        }
        if (!_confirmedIndices.contains(i)) return;
      }
    }

    try {
      await sendRemaining().timeout(asyncDuelQuitSendTimeout);
    } on TimeoutException catch (error, stack) {
      stopped = true;
      ErrorReporter.record(error, stack, reason: 'async duel quit incomplete');
    }
    stopped = true;
    if (!mounted) return;
    final completed =
        duel != null && _confirmedIndices.length >= _questions.length;
    if (_isTournament) {
      Navigator.of(context).pop(<String, Object?>{'completed': completed});
    } else if (duel != null && !completed) {
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          AsyncDuelResultScreen(
            repository: widget.repository,
            view: AsyncDuelResultView.fromSummary(
              AsyncDuelSummary(
                duelId: duel.duelId,
                status: AsyncDuelStatus.open,
                role: duel.role,
                createdAt: DateTime.now(),
                seen: false,
              ),
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
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
      await _answer(
        id: duelId,
        index: index,
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
        center: Text(
          context.t(_isTournament ? K.tournamentTitle : K.asyncDuel),
        ),
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
    final progressLabel =
        '${groupThousands(_index + 1)}/${groupThousands(total)}';

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
        // K6+ (2026-10-28): konu renkli üst bant kalktı; her modda aynı
        // lacivert sahne. İlerleme çubuğu `progress` yuvasında.
        progress: SahneProgressBar(
          key: const ValueKey('async-duel-progress-bar'),
          // `_results` toplam uzunlukta ve boş (`null`) başlar: yalnız
          // cevaplananlar dolu sayılır.
          value: total == 0
              ? 0
              : (_results.where((r) => r != null).length / total).clamp(
                  0.0,
                  1.0,
                ),
          height: 4,
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
          // Kurul C14 (Astra + Sol): rozet yalnız "Düello" diyordu; canlı
          // düellodan ayrılmıyordu. Mod adı tam yazar.
          modeLabel: _resumedVisible
              ? context.t(K.asyncDuelResumedChip)
              : context.t(_isTournament ? K.tournament : K.asyncDuelChip),
          modeHighlight: _resumedVisible,
          // Y3: "Sen oyna, rakip sonra" üst çubukta küçük alt satır; rakip
          // baştan bellidir ya da yoksa (meydan okuyan) yalnız bu satır.
          subtitle: !_isTournament && _duel!.role != AsyncDuelRole.opponent
              ? context.t(K.asyncDuelSub)
              : null,
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AnimatedBuilder(
                      animation: _timerController.animation,
                      builder: (context, _) {
                        final fraction = _timerController.animation.value;
                        final seconds = (fraction * _questionSeconds).ceil();
                        return SahneStageTimer(
                          secondsLeft: seconds,
                          maxSeconds: _questionSeconds,
                          pending: !_timeSynced || _phase == _Phase.revealed,
                          // Cevap gönderildikten sonra sayaç durur; gerilim rengi
                          // de söner.
                          hotSeconds: disabled ? -1 : 5,
                          semanticLabel:
                              '${groupThousands(seconds)} ${context.t(K.secondsShortUnit)}',
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
        // Cevap gönderilemediyse (ya da turnuvada soru sunulamadıysa) alt
        // perdede TEK birincil: tekrar dene.
        dock: _presentFailed
            ? SahneButton.primary(
                key: const ValueKey('tournament-present-retry'),
                label: context.t(K.retry),
                icon: AppIcons.arrowsRotate,
                arrow: false,
                expand: true,
                onPressed: () => unawaited(_presentTournamentQuestion()),
              )
            : _phase == _Phase.error
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
        body: (_awaitingQuestion || _presentFailed)
            // Turnuva: soru içeriği sunucudan gelene dek soru da şık da yok.
            ? Center(
                key: const ValueKey('tournament-question-pending'),
                child: _presentFailed
                    ? Padding(
                        padding: const EdgeInsets.all(SahneSpace.page),
                        child: Text(
                          context.t(K.loadFailedShort),
                          textAlign: TextAlign.center,
                          style: SahneType.bodyStrong.copyWith(
                            color: SahneTokens.of(context).tx2,
                          ),
                        ),
                      )
                    : const CircularProgressIndicator(),
              )
            : Builder(
                builder: (context) {
                  final t = SahneTokens.of(context);
                  // Kurul 2026-10-20: şıklar alta (baş parmak bölgesi), soru boş
                  // alanda ortalanır — ders ve yarışma ekranıyla AYNI yerleşim.
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final fitPlan = _planFit(context, constraints, answers);
                      final fit = fitPlan.fit;
                      return Stack(
                        children: [
                          SahneStageScroll(
                            scrollKey: const ValueKey('async-duel-scroll'),
                            // Yeni soruda başa dön; üst kenar elmas şeridin altında sönsün.
                            resetKey: _index,
                            balance: _isTournament ? 0 : quizQuestionBalance,
                            // 2026-10-29 son kurul tur 2 (B): cevaptan sonra
                            // soru ve şıklar yerinde kalır (ders/yarışla aynı).
                            holdBalance: _selectedAnswer != null,
                            // Y3 (2026-10-29 tur 6): bu ekranda alt perde yok; ders ve
                            // yarışta o yükseklik (≈ 70 + güvenli alan) gövdeden
                            // düşer ve dengeli yerleşim ([quizQuestionBalance])
                            // ona göre konumlanır. Aynı yer burada boş ayrılır:
                            // soru kartı her modda aynı üstte durur.
                            padding: EdgeInsets.fromLTRB(
                              SahneSpace.page,
                              fit.outerPad,
                              SahneSpace.page,
                              fitPlan.bottomPad,
                            ),
                            // K6: soru ÜSTTEN başlar (şıkları alta oturtan boşluk
                            // kalktı).
                            child: QuizFitScope(
                              fit: fit,
                              child: ConstrainedBox(
                                key: const ValueKey(
                                  'async-duel-answers-anchored',
                                ),
                                constraints: const BoxConstraints(),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Sıra ve kategori ortak üst satırda; burada yalnız
                                    // rakip bağlamı (boş yuva soruyu ortalar). Rakip adı
                                    // biliniyorsa avatarıyla birlikte ("Sen · Rojda"):
                                    // "Rojda'ya karşı" Türkçe ek uyumu gerektirdiği için
                                    // yeni cümle kurulmadı (NEEDS_JURY).
                                    Padding(
                                      // Y3: meydan okuyanda bu satır boştur ve boşluk da
                                      // yoktur (soru kartı diğer modlarla aynı yerde).
                                      padding: EdgeInsets.only(
                                        bottom:
                                            _isTournament ||
                                                duel.role ==
                                                    AsyncDuelRole.opponent
                                            ? SahneSpace.x4
                                            : 0,
                                      ),
                                      // Turnuva maçında rakip baştan bellidir: rolden
                                      // bağımsız rakip satırı, üstünde tur adı.
                                      child: _isTournament
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (widget.entry?.roundLabel !=
                                                    null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: SahneSpace.x1,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          AppIcons.trophy,
                                                          size: 16,
                                                          color: t.goldTx,
                                                        ),
                                                        const SizedBox(
                                                          width: SahneSpace.x1,
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            widget
                                                                .entry!
                                                                .roundLabel!,
                                                            key: const ValueKey(
                                                              'tournament-match-round',
                                                            ),
                                                            style: SahneType
                                                                .captionStrong
                                                                .copyWith(
                                                                  color:
                                                                      t.goldTx,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                _RivalLine(
                                                  name:
                                                      duel.opponentName == null
                                                      ? context.t(
                                                          K.asyncDuelOpponent,
                                                        )
                                                      : context.playerDisplayName(
                                                          duel.opponentName,
                                                          tag: duel
                                                              .opponentProfile
                                                              ?.playerTag,
                                                        ),
                                                  rawName: duel.opponentName,
                                                  identity: duel
                                                      .opponentProfile
                                                      ?.avatar,
                                                  you: context.t(K.you),
                                                ),
                                              ],
                                            )
                                          : duel.role == AsyncDuelRole.opponent
                                          ? _RivalLine(
                                              name: duel.opponentName == null
                                                  ? context.t(
                                                      K.asyncDuelOpponent,
                                                    )
                                                  : context.playerDisplayName(
                                                      duel.opponentName,
                                                      tag: duel
                                                          .opponentProfile
                                                          ?.playerTag,
                                                    ),
                                              rawName: duel.opponentName,
                                              identity:
                                                  duel.opponentProfile?.avatar,
                                              you: context.t(K.you),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    QuizPromptCard(
                                      padding: fit.promptPad,
                                      child: MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          textScaler: QuizFitScope.scaled(
                                            MediaQuery.textScalerOf(context),
                                            fit.questionScale,
                                          ),
                                        ),
                                        child: Semantics(
                                          header: true,
                                          child: QuizQuestionPrompt(
                                            question.promptText,
                                          ),
                                        ),
                                      ),
                                    ),
                                    MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        textScaler: QuizFitScope.scaled(
                                          MediaQuery.textScalerOf(context),
                                          fit.optionScale,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(height: fit.sectionGap),
                                          for (final (i, answer)
                                              in answers.indexed)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: fit.optionGap,
                                              ),
                                              child: QuizOptionTile(
                                                key: ValueKey(
                                                  'async-duel-option-$i',
                                                ),
                                                index: i,
                                                answer: answer,
                                                selected:
                                                    _selectedAnswer == answer,
                                                correct:
                                                    _revealedAnswerText !=
                                                        null &&
                                                    answer ==
                                                        _revealedAnswerText,
                                                disabled: disabled,
                                                isCompact:
                                                    MediaQuery.sizeOf(
                                                      context,
                                                    ).height <
                                                    700,
                                                suspense: suspenseVisual,
                                                optionCount: answers.length,
                                                dimmed:
                                                    _revealedAnswerText !=
                                                        null &&
                                                    answer !=
                                                        _revealedAnswerText &&
                                                    _selectedAnswer != answer,
                                                onTap: () =>
                                                    _handleAnswerTap(answer),
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
                          // "Cevap gönderilemedi" uyarısı gövdenin ALTINA
                          // asılı yüzer bir satırdır: eskiden soru ile şıklar
                          // arasına giriyor, şıkları ~40 pt aşağı itiyordu
                          // (soru sığma bekçisi, 2026-10-29).
                          if (_phase == _Phase.error)
                            PositionedDirectional(
                              start: SahneSpace.page,
                              end: SahneSpace.page,
                              bottom: SahneSpace.x2,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: SahneTokens.of(context).s2,
                                  shape: SahneShape.m,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(SahneSpace.x2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.triangleExclamation,
                                        size: 20,
                                        color: SahneTokens.of(context).errTx,
                                      ),
                                      const SizedBox(width: SahneSpace.x2),
                                      Expanded(
                                        child: Text(
                                          context.t(K.asyncDuelAnswerFailed),
                                          style: SahneType.bodyStrong.copyWith(
                                            color: SahneTokens.of(
                                              context,
                                            ).errTx,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  /// Soru + şıkların kademesi ve alt payı (soru sığma). Bu ekranda alt perde
  /// yok; ders/yarışla aynı yükseklik boş ayrılır ([quizDocklessBottomReserve])
  /// AMA yalnız içerik tam boyda o payla da sığıyorsa. Sığmıyorsa pay
  /// kalkar ve kademe dar alana göre seçilir: kayma yok.
  ({QuizFit fit, double bottomPad}) _planFit(
    BuildContext context,
    BoxConstraints constraints,
    List<String> answers,
  ) {
    final question = _questions[_index];
    final safe = MediaQuery.paddingOf(context).bottom;
    final width = constraints.maxWidth - 2 * SahneSpace.page;
    final base = MediaQuery.textScalerOf(context);
    // Rakip satırı (+ turnuvada tur adı) soru kartının üstünde durur.
    final duel = _duel;
    var above = 0.0;
    if (_isTournament) {
      above +=
          (widget.entry?.roundLabel != null ? base.scale(20) + 4 : 0) +
          math.max(24.0, base.scale(20)) +
          SahneSpace.x4;
    } else if (duel != null && duel.role == AsyncDuelRole.opponent) {
      // +8: rakip satırının avatarı ve ad satırı hizalama payı.
      above += math.max(24.0, base.scale(26)) + SahneSpace.x4 + 8;
    }
    // QuizFit.estimate üst ve alt `outerPad`i (nominalde 16) zaten sayar.
    final reserve = SahneSpace.x6 + quizDocklessBottomReserve + safe;
    QuizFit pick(double extraBottom) => QuizFit.choose(
      context: context,
      prompt: question.promptText,
      answers: answers,
      width: width,
      available: constraints.maxHeight - above - extraBottom,
      listenButton: false,
      titleLineBudget: QuizQuestionPrompt.maxTitleLines,
      short: MediaQuery.sizeOf(context).height < 700,
    );
    final roomy = pick(reserve - SahneSpace.x4);
    if (roomy.isNominal) return (fit: roomy, bottomPad: reserve);
    // Gövde kısıtı alt çubuk/güvenli alan düşülmüş geldiği için sıkı kipte
    // ek pay yok.
    final tight = pick(0);
    return (fit: tight, bottomPad: tight.outerPad);
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
      // "Sen vs [avatar] Rojda": avatar rakibindir, bu yüzden adının hemen
      // önünde durur. Eski "[avatar] Sen · Rojda" dizilişi simülatörde
      // "ben Rojda'yım" diye okundu (2026-10-27 E2E). "vs" Yarış kartındaki
      // "RO vs ?" göstergesiyle aynı, dilden bağımsız işarettir.
      children: [
        Text('$you vs', style: SahneType.caption.copyWith(color: t.tx2)),
        const SizedBox(width: SahneSpace.x2),
        PlayerAvatar.fromIdentity(
          radius: 12,
          identity: identity,
          displayName: rawName ?? name,
        ),
        const SizedBox(width: SahneSpace.x2),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
      ],
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
