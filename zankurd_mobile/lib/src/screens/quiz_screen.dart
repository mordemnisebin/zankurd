import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/avatar_presets.dart';
import '../config/bot_names.dart';
import '../config/category_visuals.dart';
import '../data/mistake_store.dart';
import '../data/sync_manager.dart';
import '../providers/sound_provider.dart';
import '../providers/untimed_mode_provider.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../data/seen_question_store.dart';
import '../data/zankurd_repository.dart';
import '../data/supabase_zankurd_repository.dart';
import '../game/bot_opponent.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/wildcard.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/analytics_service.dart';
import '../services/room_result_presentation.dart';
import '../services/tts_service.dart';
import 'quiz/word_ordering_widget.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import '../widgets/app_panel.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/player_avatar.dart';
import '../widgets/kilim_progress_bar.dart';
import '../widgets/quiz_tutorial_overlay.dart';
import 'quiz/quiz_effects.dart';
import 'quiz/quiz_feedback_overlay.dart';
import 'quiz/quiz_option_tile.dart';
import 'quiz/quiz_timer_widget.dart';
import 'quiz/quiz_wildcard_bar.dart';
import 'quiz_result_screen.dart';
import 'room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

part 'quiz/quiz_widgets.dart';
part 'quiz/quiz_screen_ui.dart';

enum QuizExperience { learning, competition }

// ─── Quiz yerleşim dalı seçimi ───────────────────────────────────────────
//
// Quiz'in iki yerleşimi var: dikey (stacked) akış ve telefonu yan çevirince
// devreye giren iki sütunlu "compact landscape" düzeni. İkincisi *yalnız*
// yüksekliği gerçekten kısıtlı, gerçekten yatay ekranlar için tasarlandı:
// soru solda, ilerleme ve birincil eylem sağda.
//
// Dal eskiden yalnız `constraints.maxWidth >= 700` ile seçiliyordu ve
// değişkenin adı `landscape` idi — ama yönelim hiç ölçülmüyordu. Bu yüzden
// 700px'ten geniş her viewport iki sütuna düşüyordu: bütün masaüstü
// tarayıcılar ve *dikey* tabletler dahil. Orada sağ sütun kısa kalıp tepeye
// yapıştığı için birincil eylem şıkların üstünde ve uzağında duruyor, ekranın
// altı boş kalıyordu (2026-07-31 denetimi ZKR-P1-001, 1440×900 ölçümü).
//
// Doğru ayrım genişlik değil, **kısa ve yatay** olmaktır:
//   • Masaüstü tarayıcılar genelde `width > height` olur ama telefon-yatay
//     değildir — yükseklikleri boldur, dikey akışı rahat taşırlar.
//   • Dikey tabletlerde zaten `height > width`.
// Bu yüzden koşul üç şart birden arar; yalnız biri yetmez.

/// Compact landscape dalının aradığı en küçük genişlik.
const double _compactLandscapeMinWidth = 700.0;

/// Compact landscape dalının kabul ettiği en büyük yükseklik. Telefonlar yan
/// çevrildiğinde ~375–430px'e iner; masaüstü ve tabletler bunun çok üstünde
/// kalır ve dikey akışı kullanır.
const double _compactLandscapeMaxHeight = 600.0;

/// Terminal 1v1 çağrısı sonsuza dek bekleyip geri dönüşü kilitlememeli.
const Duration _onlineResultRequestTimeout = Duration(seconds: 15);

/// İki sütunlu telefon-yatay düzeni bu viewport için uygun mu?
///
/// Beklenmeyen veya sonsuz bir yükseklik kısıtı gelirse güvenli varsayılan
/// dikey (stacked) akıştır — iki sütunlu düzen dar bir özel durumdur.
bool _useCompactLandscapeLayout(double width, double height) =>
    height.isFinite &&
    width >= _compactLandscapeMinWidth &&
    width > height &&
    height <= _compactLandscapeMaxHeight;

/// Multiplayer quiz turlarının ortak faz durumu.
enum _MultiplayerPhase {
  /// Oyuncular cevap veriyor.
  answering,

  /// Cevap verildi, diğer oyuncu bekleniyor.
  waiting,

  /// İki oyuncu da cevapladı veya süre bitti; doğru cevap gösteriliyor.
  reveal,
}

enum _OnlineResultPhase { idle, loading, retryableFailure }

typedef _QuizCoinSettlement = ({
  int coinsAwarded,
  bool rewardQueued,
  bool isDurable,
  String ownerUserId,
});

class _OpponentAnswer {
  const _OpponentAnswer({required this.name, required this.answer});

  final String name;
  final String answer;
}

class _ResolvedResumeAnswer {
  const _ResolvedResumeAnswer({
    required this.answer,
    required this.questionIndex,
    required this.selectedAnswer,
    required this.correctAnswer,
  });

  final ResumedAnswer answer;
  final int questionIndex;
  final String selectedAnswer;
  final String correctAnswer;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.repository,
    required this.room,
    required this.questions,
    this.practice = false,
    this.botRace = false,
    this.dailyQuiz = false,
    this.enableTimer = true,
    this.is1v1 = false,
    this.experience = QuizExperience.competition,
    this.contestId,
    this.versusBannerText,
    this.resumeSnapshot,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final List<QuizQuestion> questions;

  /// Yanlışlardan çalışma modu: coin ödülü verilmez.
  final bool practice;

  /// Tek kişilik yarışta simüle bot rakipler etkinleşir.
  final bool botRace;

  /// Günün yarışması akışından açıldıysa daily quiz sayacı işler.
  final bool dailyQuiz;

  final bool enableTimer;
  final bool is1v1;
  final QuizExperience experience;

  /// Günlük etkinlik (contest) quiz'i — sonuçta skor + ödül RPC.
  final String? contestId;

  /// Turnuva maçı gibi versus bağlamı olan akışlarda ekran üstünde
  /// gösterilen bant metni (örn. "Çaryeka Final · Li dijî Azad").
  final String? versusBannerText;

  /// Süreç yeniden açıldığında sunucudan gelen yetkili aktif-oda durumu.
  final RoomResumeSnapshot? resumeSnapshot;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool get _isLearningExperience =>
      widget.experience == QuizExperience.learning;

  /// Süresiz modun geçerli olabileceği tek yer: ödül üretmeyen tek kişilik
  /// turlar.
  ///
  /// Sınır keyfî değil, ödül yerleşiminin sınırıyla aynı:
  /// `_settleQuizReward` bu koşulda erken dönüp sıfır coin veriyor
  /// (`widget.practice || widget.room.id == null`). Yani burada sayacı
  /// kapatmak hiçbir sunucu ödülünü, lig puanını ya da rakip karşılaşmasını
  /// etkilemiyor — kapanan tek şey oyuncunun kendi üzerindeki baskı.
  ///
  /// Oda, 1v1, günlük tur, bot yarışı ve turnuva her hâlükârda sayaçlı
  /// kalır: orada süre puanın parçasıdır.
  bool get _isRewardNeutralSolo =>
      !widget.is1v1 &&
      !widget.dailyQuiz &&
      !widget.botRace &&
      (widget.practice || widget.room.id == null);

  /// Kullanıcı tercihi build sırasında okunur; `_untimedPreference`
  /// `didChangeDependencies` içinde tazelenir (sağlayıcı yoksa `false`).
  bool _untimedPreference = false;

  bool get _usesTimer =>
      widget.enableTimer &&
      !_isLearningExperience &&
      !(_untimedPreference && _isRewardNeutralSolo);

  /// Analytics'te "hangi modda oynanıyor" ayrımı için (quiz_start event'i).
  String get _quizModeLabel {
    if (_isLearningExperience) return 'learning';
    if (widget.practice) return 'practice';
    if (widget.is1v1) return '1v1';
    if (widget.dailyQuiz) return 'daily';
    if (widget.botRace) return 'bot_race';
    return 'solo';
  }

  int index = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correctCount = 0;
  int wrongCount = 0;
  String selectedAnswer = '';
  bool favorite = false;
  bool _favoriteTouched = false;
  bool completing = false;
  Set<String> hiddenAnswers = const {};
  final List<AnswerRecord> answerRecords = [];
  late List<Player> livePlayers = widget.room.players;
  StreamSubscription<List<Player>>? _playersSub;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  final Map<String, _OpponentAnswer> _opponentSelectedAnswers = {};
  final Set<String> _answeredPlayerKeys = {};
  Timer? _autoNextTimer;
  BotRace? _botRace;
  bool _isKu = true;
  String _myName = '';
  String? _myId;

  // Joker sistemi
  late List<QuizQuestion> _questions;
  WildcardState _wildcard = const WildcardState();
  String _firstAttemptAnswer = '';
  Map<String, double>? _audiencePoll;
  int _coinBalance = 0;

  // Timer ve animasyon durumları
  late final AnimationController _timerController;
  final Stopwatch _questionStopwatch = Stopwatch();
  // Açıklama gecikmesi bilinçli olarak Timer değil AnimationController:
  // ticker'ı frame ürettiği için pumpAndSettle 800ms'lik bekleyişi atlamaz
  // ve gerçek cihazda da reveal ritmi kare kare akar.
  late final AnimationController _explanationController;
  bool _showExplanation = false;
  bool _showConfetti = false;
  bool _showAnswerBurst = false; // her doğruda mini konfeti
  bool _suspense = false; // cevap sonrası kısa gerilim tutuşu
  int _shakeTrigger = 0; // yanlış cevapta artar → WrongFlash oynar
  int _flyupTrigger = 0; // doğru cevapta artar → ScoreFlyup oynar
  int _lastPointsEarned = 0;

  // Multiplayer phase state
  _MultiplayerPhase _mpPhase = _MultiplayerPhase.answering;
  Timer? _revealTimer;
  int _revealCountdown = 0;
  Timer? _revealTickTimer;
  Timer? _opponentWaitTimer;
  Timer? _advanceRetryTimer;
  Timer? _serverReadyRetryTimer;
  bool _opponentFinished = false;
  StreamSubscription? _roomSub;
  Timer? _pollTimer;
  bool _questionFlowStarted = false;
  double? _initialTimerFraction;
  bool _resumingOnlineSession = false;
  bool _exitInFlight = false;
  bool _reconcileInFlight = false;
  int _reconcileGeneration = 0;
  bool _terminalHandling = false;
  _OnlineResultPhase _onlineResultPhase = _OnlineResultPhase.idle;
  bool _onlineResultInFlight = false;
  bool _onlineResultOwnerChanged = false;
  int _onlineResultGeneration = 0;
  String _onlineResultOwnerId = '';
  bool _onlineResultFinishRequired = false;
  _QuizCoinSettlement? _legacyRewardSettlement;
  Future<void>? _legacyFinishInFlight;
  Future<_QuizCoinSettlement>? _legacySettlementInFlight;
  bool _legacyFinishRequired = false;
  bool _legacyResultInFlight = false;
  bool _legacyRetryRequested = false;
  int _legacyResultGeneration = 0;
  RoomEndState? _deferredEndState;
  int _exitGeneration = 0;
  bool _serverReadyWaiting = false;
  bool _clientReadyInFlight = false;
  bool _clientReadyMarked = false;
  int _serverReadyRetryCount = 0;
  bool _advanceInFlight = false;
  bool _advanceSequenceActive = false;
  bool _serverAnswerPending = false;
  int? _authoritativeRemainingMs;
  DateTime? _authoritativeRemainingCapturedAt;

  // TTS: cihaz Kürtçe TTS desteklemiyorsa canListen false kalır ve
  // dinleme butonu gizlenir. Konuşma durumu TtsService.speakingNotifier
  // üzerinden takip edilir (bkz. _ListenButton).
  bool _ttsCanListen = false;

  // Tutorial açıkken ertelenen multiplayer soru sayacı (bkz. _syncToQuestionIndex).
  bool _timerDeferredForTutorial = false;

  // 1v1 online eşleşmede her iki taraf da bu ekrana kendi hızında ulaşır
  // (matchmaking sonrası ayrı ayrı navigasyon); bariyer olmadan biri
  // hâlâ geçiş ekranındayken diğeri soruları görüp saymaya başlayabilir.
  // Bu yüzden karşı taraftan bir "hazır" broadcast'i gelene kadar (ya da
  // kısa bir zaman aşımına kadar) soru akışı başlatılmaz.
  bool _tutorialGateReady = false;
  bool _opponentClientReady = false;
  bool _questionVisualReady = false;
  Timer? _visualReadyFallbackTimer;
  Timer? _readyPingTimer;
  Timer? _readyTimeoutTimer;
  bool get _needsOpponentReadyGate =>
      !_usesServerHiddenAnswers &&
      widget.is1v1 &&
      _isMultiplayer &&
      !_resumingOnlineSession;

  // Quiz tutorial coach mark hedef anahtarları
  final GlobalKey _timerTargetKey = GlobalKey();
  final GlobalKey _answerAreaKey = GlobalKey();

  /// Doğru şıkkın karosu. Cevap açıklandığında [_revealCorrectAnswer] bunu
  /// görünür alana kaydırır.
  final GlobalKey _correctAnswerKey = GlobalKey();

  /// Cevap açıklandıktan sonra doğru şıkkı görünür alana getirir.
  ///
  /// Uzun şıklarda (tanım cümlesi biçiminde seçenekler) doğru cevap
  /// aksiyon barının altında kırpılı kalıyordu; kullanıcı yanlış yaptığında
  /// doğrusunu göremediği için tur öğretici olmaktan çıkıyordu
  /// (2026-07-25 canlı denetimi).
  void _revealCorrectAnswer() {
    if (isFlutterTestEnvironment) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _correctAnswerKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        // Öğrenme akışında doğru şıkkın hemen altında açıklama kutusu
        // belirir ve asıl öğretici içerik odur; karo yukarı alınarak
        // açıklama da aynı ekranda kalır. Yarışma akışında açıklama yok,
        // bu yüzden karo daha rahat bir konumda ortalanır.
        alignment: _isLearningExperience ? 0.12 : 0.35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  final GlobalKey _comboKey = GlobalKey();
  final GlobalKey _wildcardKey = GlobalKey();
  final GlobalKey _nextButtonKey = GlobalKey();

  QuizQuestion get question => _questions[index];
  bool get answered => selectedAnswer.isNotEmpty;
  bool get isLastQuestion => index == widget.questions.length - 1;
  bool get _isSoloMode => widget.room.id == null;

  /// Gerçek online multiplayer: 1v1 veya takım oyunu (bot değil).
  bool get _isMultiplayer => widget.room.id != null;
  bool get _usesServerHiddenAnswers =>
      _isMultiplayer && widget.repository.usesServerHiddenAnswers;

  bool _isMe(Player player) =>
      playerMatchesIdentity(player, id: _myId, legacyName: _myName);

  Iterable<Player> get _opponents =>
      livePlayers.where((player) => !_isMe(player));

  GameRoom get _resultRoom {
    final myIndex = livePlayers.indexWhere(_isMe);
    if (myIndex == -1) return widget.room;
    return widget.room.copyWith(players: [livePlayers[myIndex], ..._opponents]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tercih tur BAŞLARKEN okunur ve tur boyunca sabit kalır: oyuncu tur
    // ortasında ayarı değiştirse bile sayaç ortada belirip kaybolmamalı.
    _untimedPreference = UntimedModeProvider.isEnabledIn(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isKu = context.langProvider.isKu;
    // Sorular tura girerken bir kez seçili dile yansıtılır. Yansıtma tur
    // başında yapılır, her karede değil: dil tur ortasında değişirse
    // soruların yarısı bir dilde yarısı ötekinde kalırdı.
    //
    // Çevirisi olmayan sorular Kurmancî kalır — banka kademeli çevriliyor
    // ve eksik çeviri, boş ekrandan iyidir (bkz. QuizQuestion.localized).
    _questions = [
      for (final question in widget.questions) question.localized(isKu: _isKu),
    ];
    _myId = widget.repository.currentUserId;
    _onlineResultOwnerId = widget.repository.currentUserId?.trim() ?? '';
    livePlayers = List<Player>.of(widget.room.players);
    _serverReadyWaiting = _usesServerHiddenAnswers;
    final initialResume = _matchingResumeSnapshot(widget.resumeSnapshot);
    if (initialResume != null && _questions.isNotEmpty) {
      _resumingOnlineSession = true;
      _tutorialGateReady = true;
      _opponentClientReady = true;
      _applyResumeSnapshotData(initialResume, initial: true);
    }
    _questionVisualReady = _questions.isEmpty || !_questions[index].hasImage;
    if (!_questionVisualReady) {
      // Görsel yükleme kapısı için emniyet supabı: ağ askıda kalır veya
      // görsel callback'i hiç tetiklenmezse soru akışı ve sayaç sonsuza
      // kadar beklerdi (2026-07-25 canlı denetimi: ilk soruda sayaç hiç
      // başlamıyordu).
      _visualReadyFallbackTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _handleQuestionVisualReady();
      });
    }
    _loadCoinBalance();
    AnalyticsService.instance.logQuizStart(
      category: widget.room.category,
      mode: _quizModeLabel,
    );

    // Initialize TTS service
    _initializeTts();

    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.room.secondsPerQuestion),
      value: _initialTimerFraction ?? 1.0,
    );
    _explanationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _explanationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showExplanation = true);
      }
    });
    if (_usesTimer) {
      _timerController.addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          if (!answered) {
            _handleQuestionDeadline();
          }
        }
      });
      int lastTickSecond = widget.room.secondsPerQuestion;
      _timerController.addListener(() {
        if (_timerController.isAnimating) {
          final remaining =
              (_timerController.value * widget.room.secondsPerQuestion).ceil();
          if (remaining != lastTickSecond) {
            lastTickSecond = remaining;
            if (remaining > 0 && [5, 3, 1].contains(remaining)) {
              HapticFeedback.lightImpact();
              context.read<SoundProvider>().playTick();
            }
          }
        }
      });
    }

    widget.repository.getProfileName().then((name) {
      if (!mounted) return;
      setState(() {
        _myName = name;
      });

      if (widget.room.id != null) {
        // Real online multiplayer (1vs1 or Team Game)
        // Kimlik önce oturum kullanıcı kimliğinden çözülür. Görünen ad
        // benzersiz değildir: aynı adı seçen iki oyuncu olduğunda ada göre
        // eşleştirme skoru ve "hazır" sinyalini rakibe atıyordu. Ad yalnızca
        // kimlik yoksa (eski oda kayıtları) yedek olarak kullanılır.
        // Oturum kimliği varsa yalnız o yetkilidir. Oda listesindeki aynı
        // ada bakıp başka bir oyuncunun kimliğini kendimize atamak, iki
        // "Berfin"li maçta skor ve hazır sinyallerini tersine çeviriyordu.
        // Kimliksiz eski kayıtlarda [_isMe] ad yedeğini kullanır.
        _myId = widget.repository.currentUserId;
        _applyOwnAuthoritativePlayerState();
        _realtimeSub = widget.repository
            .subscribeRoomBroadcast(widget.room.id!)
            .listen((payload) {
              if (!mounted) return;
              final senderId = payload['sender_id'] as String?;
              final senderName = payload['sender'] as String?;
              final isSelf = playerMatchesIdentity(
                Player(
                  id: senderId,
                  name: senderName ?? '',
                  score: 0,
                  state: '',
                ),
                id: _myId,
                legacyName: name,
              );
              if (!_usesServerHiddenAnswers &&
                  senderName != null &&
                  !isSelf &&
                  payload['ready'] == true) {
                _handleOpponentReady();
                return;
              }
              if (senderName != null && !isSelf) {
                final senderKey = playerIdentityKey(
                  id: senderId,
                  legacyName: senderName,
                );
                if (!_usesServerHiddenAnswers &&
                    payload['advance_request'] == true &&
                    _isHost) {
                  unawaited(_next());
                  return;
                }
                int? newerQuestionIndex;
                setState(() {
                  if (payload['finished'] == true) {
                    _opponentFinished = true;
                    _answeredPlayerKeys.add(senderKey);
                  }
                  if (payload['answered'] == true) {
                    _answeredPlayerKeys.add(senderKey);
                  } else if (payload['answered'] == false) {
                    _answeredPlayerKeys.remove(senderKey);
                  }

                  final incomingPlayer = Player(
                    id: senderId,
                    name: senderName,
                    score: 0,
                    state: '',
                  );
                  final opponentIdx = livePlayers.indexWhere(
                    (player) => playersShareIdentity(player, incomingPlayer),
                  );
                  final updatedOpponent = Player(
                    id:
                        senderId ??
                        (opponentIdx != -1
                            ? livePlayers[opponentIdx].id
                            : null),
                    name: senderName,
                    score: (payload['score'] as num?)?.toInt() ?? 0,
                    streak: (payload['streak'] as num?)?.toInt() ?? 0,
                    state: payload['answered'] == true
                        ? Tr.forKu(K.answeredState, _isKu)
                        : Tr.forKu(K.waitingAnswerState, _isKu),
                  );
                  if (opponentIdx != -1) {
                    livePlayers[opponentIdx] = updatedOpponent;
                  } else {
                    livePlayers.add(updatedOpponent);
                  }
                  livePlayers.sort((a, b) => b.score.compareTo(a.score));

                  final oppAnswer = _usesServerHiddenAnswers
                      ? null
                      : payload['selected_answer'] as String?;
                  if (oppAnswer != null) {
                    _opponentSelectedAnswers[senderKey] = _OpponentAnswer(
                      name: senderName,
                      answer: oppAnswer,
                    );
                  } else if (payload['answered'] == false) {
                    _opponentSelectedAnswers.remove(senderKey);
                  }

                  final oppIndex = payload['question_index'] as int?;
                  if (oppIndex != null && oppIndex > index) {
                    newerQuestionIndex = oppIndex;
                  }
                });
                final targetIndex = newerQuestionIndex;
                if (targetIndex != null) {
                  if (_usesServerHiddenAnswers) {
                    unawaited(_reconcileOnlineRoom());
                  } else {
                    _syncToQuestionIndex(targetIndex);
                  }
                }
                if (_usesServerHiddenAnswers && payload['answered'] == true) {
                  unawaited(_reconcileOnlineRoom());
                  return;
                }
                _checkMultiplayerSync();
              }
            });

        if (widget.is1v1) {
          if (!_resumingOnlineSession && !_usesServerHiddenAnswers) {
            _startOpponentReadyHandshake();
          }
        } else {
          _playersSub = widget.repository
              .subscribeRoomPlayers(widget.room)
              .listen((players) {
                if (!mounted) return;
                setState(() {
                  for (final p in players) {
                    final idx = livePlayers.indexWhere(
                      (lp) => playersShareIdentity(lp, p),
                    );
                    final key = playerIdentityKey(id: p.id, legacyName: p.name);
                    if (idx != -1) {
                      livePlayers[idx] = livePlayers[idx].copyWith(
                        score: p.score,
                        streak: p.streak,
                        state: _answeredPlayerKeys.contains(key)
                            ? Tr.forKu(K.answeredState, _isKu)
                            : Tr.forKu(K.waitingAnswerState, _isKu),
                      );
                    } else {
                      livePlayers.add(
                        p.copyWith(
                          state: _answeredPlayerKeys.contains(key)
                              ? Tr.forKu(K.answeredState, _isKu)
                              : Tr.forKu(K.waitingAnswerState, _isKu),
                        ),
                      );
                    }
                  }
                  livePlayers.sort((a, b) => b.score.compareTo(a.score));
                });
                _checkMultiplayerSync();
              });
        }
      } else {
        if (widget.is1v1) {
          // Bot fallback 1v1 match
          final rng = Random();
          const botNames = BotNames.pool;
          final botName = botNames[rng.nextInt(botNames.length)];
          final botSkill = 0.65 + rng.nextDouble() * 0.25;
          _botRace = BotRace([
            BotOpponent(name: botName, skill: botSkill, random: rng),
          ]);
          livePlayers = _composeBotRacePlayers();
        } else if (widget.botRace) {
          _botRace = BotRace.standard();
          livePlayers = _composeBotRacePlayers();
        }
      }
    });

    // Boş listeyle açılırsa question getter'ı patlar; build'deki boş
    // durum ekranı gösterilir, sayaç ve tekrar-kaydı hiç başlatılmaz.
    if (_questions.isNotEmpty) {
      _markQuestionSeen();
      _loadFavoriteState();
    }

    if (_isMultiplayer) {
      if (widget.repository is SupabaseZanKurdRepository) {
        final client = (widget.repository as SupabaseZanKurdRepository).client;
        _roomSub = client
            .from('rooms')
            .stream(primaryKey: ['id'])
            .eq('id', widget.room.id!)
            .listen((rows) {
              if (!mounted) return;
              if (rows.isNotEmpty) {
                final row = rows.first;
                final dbIndex = row['current_question_index'] as int? ?? 0;
                _onRoomQuestionIndexChanged(dbIndex);
                if (row['status'] == 'finished') {
                  unawaited(_reconcileOnlineRoom());
                }
              }
            });
      }
      _ensureRoomPolling();
      final binding = WidgetsBinding.instance;
      binding.addPostFrameCallback((_) {
        if (mounted) unawaited(_reconcileOnlineRoom());
      });
      binding.scheduleFrame();
    }

    if (_resumingOnlineSession && _questionVisualReady) {
      scheduleMicrotask(_maybeStartQuestionFlow);
    }
  }

  RoomResumeSnapshot? _matchingResumeSnapshot(RoomResumeSnapshot? snapshot) {
    final roomId = widget.room.id;
    if (snapshot == null || roomId == null) return null;
    if (snapshot.room.id != roomId ||
        snapshot.room.status != RoomStatus.active) {
      return null;
    }
    return snapshot;
  }

  bool _hasAuthoritativeTiming(RoomResumeSnapshot snapshot) =>
      snapshot.questionStartedAt != null && snapshot.deadline != null;

  void _captureAuthoritativeTiming(RoomResumeSnapshot snapshot) {
    if (!_hasAuthoritativeTiming(snapshot)) {
      _authoritativeRemainingMs = null;
      _authoritativeRemainingCapturedAt = null;
      return;
    }
    _authoritativeRemainingMs = max(0, snapshot.remainingMs);
    _authoritativeRemainingCapturedAt = DateTime.now();
  }

  int? get _estimatedAuthoritativeRemainingMs {
    final remaining = _authoritativeRemainingMs;
    final capturedAt = _authoritativeRemainingCapturedAt;
    if (remaining == null || capturedAt == null) return null;
    return max(
      0,
      remaining - DateTime.now().difference(capturedAt).inMilliseconds,
    );
  }

  bool get _hasSafeCurrentReveal =>
      !_serverAnswerPending &&
      question.correctAnswer.isNotEmpty &&
      answerRecords.any((record) => record.id == question.id);

  bool get _serverQuestionGatesReady =>
      _tutorialGateReady && _questionVisualReady && _clientReadyMarked;

  void _applyResumeSnapshotData(
    RoomResumeSnapshot snapshot, {
    required bool initial,
  }) {
    if (_questions.isEmpty) return;
    final targetIndex = snapshot.currentQuestionIndex
        .clamp(0, _questions.length - 1)
        .toInt();
    if (!initial && targetIndex < index) return;

    final advanced = targetIndex > index;
    if (advanced) {
      _autoNextTimer?.cancel();
      _revealTimer?.cancel();
      _revealTickTimer?.cancel();
      _opponentWaitTimer?.cancel();
      _advanceRetryTimer?.cancel();
      selectedAnswer = '';
      favorite = false;
      _favoriteTouched = false;
      completing = false;
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
      _showExplanation = false;
      _suspense = false;
      _opponentSelectedAnswers.clear();
      _answeredPlayerKeys.clear();
      _opponentFinished = false;
      _mpPhase = _MultiplayerPhase.answering;
      _revealCountdown = 0;
      _serverAnswerPending = false;
      _advanceSequenceActive = false;
      _visualReadyFallbackTimer?.cancel();
      _questionVisualReady = !_questions[targetIndex].hasImage;
      if (!_questionVisualReady) {
        _visualReadyFallbackTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _handleQuestionVisualReady();
        });
      }
    }

    index = targetIndex;
    _captureAuthoritativeTiming(snapshot);
    score = snapshot.ownScore;
    streak = snapshot.streak;
    bestStreak = snapshot.bestStreak;
    correctCount = snapshot.correctCount;
    wrongCount = snapshot.wrongCount;

    final resolved = _resolveResumeAnswers(snapshot.answers);
    if (initial) answerRecords.clear();
    for (final item in resolved) {
      final baseQuestion = _questions[item.questionIndex];
      final revealedQuestion = baseQuestion.withRevealedAnswer(
        correctAnswer: item.correctAnswer,
        explanation: item.answer.explanation,
        explanationKu: item.answer.explanationKu,
        explanationTr: item.answer.explanationTr,
      );
      _questions[item.questionIndex] = revealedQuestion;

      final record = AnswerRecord(
        id: revealedQuestion.id,
        category: revealedQuestion.category,
        prompt: revealedQuestion.promptText,
        answers: revealedQuestion.answers,
        correctAnswer: item.correctAnswer,
        selectedAnswer: item.selectedAnswer,
        explanation: revealedQuestion.explanation,
        explanationKu: revealedQuestion.explanationKu,
        explanationTr: revealedQuestion.explanationTr,
        imageUrl: revealedQuestion.imageUrl,
        responseMs: item.answer.responseMs,
        pointsEarned: item.answer.pointsAwarded,
      );
      final existing = answerRecords.indexWhere(
        (candidate) => candidate.id == record.id,
      );
      if (existing == -1) {
        answerRecords.add(record);
      } else {
        answerRecords[existing] = record;
      }
    }
    answerRecords.sort((a, b) {
      final aIndex = _questions.indexWhere((question) => question.id == a.id);
      final bIndex = _questions.indexWhere((question) => question.id == b.id);
      return aIndex.compareTo(bIndex);
    });

    _ResolvedResumeAnswer? currentAnswer;
    for (final item in resolved) {
      if (item.questionIndex == index) currentAnswer = item;
    }
    final pendingSelection = _resolvePendingSelection(
      snapshot.pendingAnswer,
      expectedQuestionIndex: index,
    );
    if (currentAnswer != null) {
      selectedAnswer = currentAnswer.selectedAnswer;
      _serverAnswerPending = false;
      _suspense = false;
      _showExplanation = true;
      if (initial || advanced || _mpPhase != _MultiplayerPhase.reveal) {
        _mpPhase = _MultiplayerPhase.waiting;
      }
      _questionFlowStarted = true;
      _initialTimerFraction = null;
      _answeredPlayerKeys.add(
        playerIdentityKey(id: _myId, legacyName: _myName),
      );
    } else if (pendingSelection != null) {
      selectedAnswer = pendingSelection;
      _serverAnswerPending = true;
      _suspense = false;
      _showExplanation = false;
      _mpPhase = _MultiplayerPhase.waiting;
      _questionFlowStarted = true;
      _initialTimerFraction = null;
      _answeredPlayerKeys.add(
        playerIdentityKey(id: _myId, legacyName: _myName),
      );
    } else if (initial || advanced) {
      selectedAnswer = '';
      _suspense = false;
      _showExplanation = false;
      _mpPhase = _MultiplayerPhase.answering;
      _questionFlowStarted = false;
      final totalMs = widget.room.secondsPerQuestion * 1000;
      _initialTimerFraction = !_hasAuthoritativeTiming(snapshot)
          ? null
          : totalMs <= 0
          ? 0
          : (snapshot.remainingMs / totalMs).clamp(0.0, 1.0).toDouble();
    }
    if (_usesServerHiddenAnswers) {
      _serverReadyWaiting =
          (!_hasAuthoritativeTiming(snapshot) || !_clientReadyMarked) &&
          !answered;
      if (_serverReadyWaiting) {
        _questionFlowStarted = false;
        _initialTimerFraction = null;
      }
    }
    _applyOwnAuthoritativePlayerState();
  }

  String? _resolvePendingSelection(
    ResumedPendingAnswer? pending, {
    required int expectedQuestionIndex,
  }) {
    if (pending == null) return null;
    var questionIndex = _questions.indexWhere(
      (question) => question.id == pending.questionId,
    );
    if (questionIndex == -1 &&
        pending.questionId.trim().isEmpty &&
        pending.questionIndex >= 0 &&
        pending.questionIndex < _questions.length) {
      questionIndex = pending.questionIndex;
    }
    if (questionIndex != expectedQuestionIndex) return null;
    if (pending.selectedOptionKey == 'TIMEOUT') return 'TIMEOUT';
    return _questions[questionIndex].answerForOptionKey(
      pending.selectedOptionKey,
    );
  }

  List<_ResolvedResumeAnswer> _resolveResumeAnswers(
    List<ResumedAnswer> answers,
  ) {
    final byQuestionIndex = <int, _ResolvedResumeAnswer>{};
    for (final answer in answers) {
      var questionIndex = _questions.indexWhere(
        (question) => question.id == answer.questionId,
      );
      if (questionIndex == -1 &&
          answer.questionId.trim().isEmpty &&
          answer.questionIndex >= 0 &&
          answer.questionIndex < _questions.length) {
        questionIndex = answer.questionIndex;
      }
      if (questionIndex < 0 || questionIndex >= _questions.length) continue;

      final question = _questions[questionIndex];
      final selected = answer.selectedOptionKey == 'TIMEOUT'
          ? 'TIMEOUT'
          : question.answerForOptionKey(answer.selectedOptionKey);
      final correct = question.answerForOptionKey(answer.correctOptionKey);
      if (selected == null || correct == null) continue;
      byQuestionIndex[questionIndex] = _ResolvedResumeAnswer(
        answer: answer,
        questionIndex: questionIndex,
        selectedAnswer: selected,
        correctAnswer: correct,
      );
    }
    final resolved = byQuestionIndex.values.toList()
      ..sort((a, b) => a.questionIndex.compareTo(b.questionIndex));
    return resolved;
  }

  void _applyOwnAuthoritativePlayerState() {
    final myIndex = livePlayers.indexWhere(_isMe);
    if (myIndex == -1) return;
    final previous = livePlayers[myIndex];
    livePlayers[myIndex] = previous.copyWith(
      score: score,
      streak: streak,
      state: answered ? Tr.forKu(K.answeredState, _isKu) : previous.state,
    );
    livePlayers.sort((a, b) => b.score.compareTo(a.score));
  }

  /// Gösterilen sorunun gerçek favori durumunu yükler. Soru değiştiyse
  /// ya da kullanıcı bu arada kendisi işaretlediyse geç gelen yanıt
  /// yok sayılır.
  void _loadFavoriteState() {
    final id = question.id;
    widget.repository
        .isFavoriteQuestion(question)
        .then((saved) {
          if (mounted &&
              !_favoriteTouched &&
              question.id == id &&
              favorite != saved) {
            setState(() => favorite = saved);
          }
        })
        .catchError((error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'quiz favorite sync failed',
          );
        });
  }

  void _startTimer() {
    if (_usesServerHiddenAnswers &&
        _estimatedAuthoritativeRemainingMs == null) {
      return;
    }
    _questionStopwatch
      ..reset()
      ..start();
    if (_usesTimer) {
      var initialFraction = _initialTimerFraction;
      if (_usesServerHiddenAnswers) {
        final totalMs = widget.room.secondsPerQuestion * 1000;
        final remainingMs = _estimatedAuthoritativeRemainingMs ?? 0;
        initialFraction = totalMs <= 0
            ? 0
            : (remainingMs / totalMs).clamp(0.0, 1.0).toDouble();
      }
      _initialTimerFraction = null;
      _timerController.stop();
      _timerController.value = initialFraction ?? 1.0;
      if (_timerController.value <= 0) {
        scheduleMicrotask(() {
          if (mounted && !answered) _handleQuestionDeadline();
        });
        return;
      }
      _timerController.reverse();
    }
  }

  void _handleQuestionDeadline() {
    if (!mounted || answered) return;
    if (_usesServerHiddenAnswers) {
      if (_advanceSequenceActive) return;
      _timerController.stop();
      _questionStopwatch.stop();
      _advanceSequenceActive = true;
      unawaited(_advanceAuthoritativeIndex());
      return;
    }
    unawaited(_answer('TIMEOUT'));
  }

  void _startQuestionFlowOnce() {
    if (_questionFlowStarted || _questions.isEmpty) return;
    if (_usesServerHiddenAnswers &&
        (!_serverQuestionGatesReady ||
            _estimatedAuthoritativeRemainingMs == null)) {
      return;
    }
    _questionFlowStarted = true;
    _serverReadyWaiting = false;
    _startTimer();
  }

  /// Tutorial coach-mark'ı kapandı/atlandı — solo modda soru akışı hemen
  /// başlar, 1v1 online'da ise karşı tarafın da hazır olması beklenir.
  void _handleTutorialReady() {
    _tutorialGateReady = true;
    _maybeStartQuestionFlow();
    // Tutorial açıkken oda index senkronu sayacı ertelediyse şimdi başlat.
    if (_timerDeferredForTutorial && !_usesServerHiddenAnswers) {
      _timerDeferredForTutorial = false;
      if (!answered) _startTimer();
    }
  }

  void _maybeStartQuestionFlow() {
    if (!_tutorialGateReady) return;
    if (!_questionVisualReady) return;
    if (_usesServerHiddenAnswers) {
      unawaited(_ensureServerClientReady());
      return;
    }
    if (_needsOpponentReadyGate && !_opponentClientReady) return;
    _startQuestionFlowOnce();
  }

  Future<void> _ensureServerClientReady({bool force = false}) async {
    if (!_usesServerHiddenAnswers ||
        !_tutorialGateReady ||
        !_questionVisualReady ||
        _clientReadyInFlight ||
        _terminalHandling ||
        completing) {
      return;
    }
    if (_clientReadyMarked && !force) {
      if (_serverReadyWaiting) {
        _scheduleServerReadyRetry();
      } else if (answered) {
        _startOpponentWaitTimer();
      } else {
        _startQuestionFlowOnce();
      }
      return;
    }

    _clientReadyInFlight = true;
    try {
      final snapshot = await widget.repository.markRoomClientReady(widget.room);
      if (!mounted || _terminalHandling || completing) return;
      _clientReadyMarked = true;
      final matchingSnapshot = _matchingResumeSnapshot(snapshot);
      if (matchingSnapshot != null &&
          matchingSnapshot.currentQuestionIndex >= index) {
        _applyReconciledSnapshot(matchingSnapshot);
      } else {
        await _reconcileOnlineRoom();
      }
      if (!mounted) return;
      if (_serverReadyWaiting) {
        _scheduleServerReadyRetry();
      } else if (answered) {
        _startOpponentWaitTimer();
        _checkMultiplayerSync();
      } else {
        _startQuestionFlowOnce();
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz client ready failed');
      if (mounted) _scheduleServerReadyRetry(retryReadyMark: true);
    } finally {
      _clientReadyInFlight = false;
    }
  }

  void _scheduleServerReadyRetry({bool retryReadyMark = false}) {
    if (!_usesServerHiddenAnswers ||
        (!_serverReadyWaiting && !retryReadyMark) ||
        (!_clientReadyMarked && !retryReadyMark) ||
        _serverReadyRetryTimer != null) {
      return;
    }
    if (_serverReadyRetryCount >= 6) {
      _serverReadyRetryTimer = Timer(const Duration(seconds: 4), () async {
        _serverReadyRetryTimer = null;
        if (!mounted || _terminalHandling || completing) return;
        _serverReadyRetryCount = 0;
        if (!_clientReadyMarked) {
          await _ensureServerClientReady(force: true);
        } else if (_serverReadyWaiting) {
          await _reconcileOnlineRoom();
          if (mounted && _serverReadyWaiting) _scheduleServerReadyRetry();
        }
      });
      return;
    }
    _serverReadyRetryCount += 1;
    _serverReadyRetryTimer = Timer(const Duration(milliseconds: 350), () async {
      _serverReadyRetryTimer = null;
      if (!mounted || (!_serverReadyWaiting && !retryReadyMark)) return;
      if (retryReadyMark) {
        await _ensureServerClientReady(force: true);
      } else {
        await _reconcileOnlineRoom();
      }
      if (mounted && _serverReadyWaiting) _scheduleServerReadyRetry();
    });
  }

  void _handleQuestionVisualReady() {
    if (_questionVisualReady) return;
    _questionVisualReady = true;
    _visualReadyFallbackTimer?.cancel();
    _visualReadyFallbackTimer = null;
    _maybeStartQuestionFlow();
  }

  /// Matchmaking sonrası iki oyuncu da ayrı ayrı bu ekrana navigasyon
  /// yapar; biri diğerinden çok önce ulaşabilir. Karşı taraftan "ready"
  /// broadcast'i alınana (veya kısa bir süre sonra zaman aşımına
  /// uğrayana) kadar soru sayacı başlamaz — aksi halde bir oyuncu henüz
  /// geçiş ekranındayken diğeri soruları görüp cevaplamaya başlayabilir.
  void _startOpponentReadyHandshake() {
    _sendReadyPing();
    _readyPingTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_opponentClientReady) {
        _readyPingTimer?.cancel();
        return;
      }
      _sendReadyPing();
    });
    _readyTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _opponentClientReady) return;
      _handleOpponentReady();
    });
  }

  void _sendReadyPing() {
    final roomId = widget.room.id;
    if (roomId == null) return;
    widget.repository
        .sendRoomBroadcast(roomId, {
          'sender': _myName,
          'sender_id': _myId,
          'ready': true,
        })
        .catchError((error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'quiz ready broadcast failed',
          );
        });
  }

  void _handleOpponentReady() {
    if (_opponentClientReady) return;
    _readyPingTimer?.cancel();
    _readyTimeoutTimer?.cancel();
    if (mounted) {
      setState(() => _opponentClientReady = true);
    } else {
      _opponentClientReady = true;
    }
    _maybeStartQuestionFlow();
  }

  void _loadCoinBalance() {
    widget.repository.loadCoinBalance().then((balance) {
      if (mounted) setState(() => _coinBalance = balance);
    });
  }

  List<Player> _composeBotRacePlayers() {
    final players = [
      Player(
        name: Tr.forKu(K.you, _isKu),
        score: score,
        state: '—',
        streak: streak,
      ),
      ...?_botRace?.toPlayers(),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return players;
  }

  /// Bot rakipler de güncel soruya cevap verir ve tablo tazelenir.
  void _advanceBots() {
    final race = _botRace;
    if (race == null) return;
    race.answerAll(question.difficulty);
    livePlayers = _composeBotRacePlayers();
  }

  /// Gösterilen soruyu tekrar-önleme deposuna işler.
  void _markQuestionSeen() {
    final id = question.id;
    SeenQuestionStore.load().then((store) => store.markSeen([id]));
  }

  /// Yanlış cevabı yanlış defterine ekler, doğru cevap kaydı düşürür.
  void _trackMistake(bool correct) {
    final id = question.id;
    if (widget.practice && correct) {
      // In mistake practice, correct reviews are handled by the rating buttons
      return;
    }
    MistakeStore.load().then(
      (store) => correct
          ? store.markResolved(id)
          : store.markMistake(id, category: question.category),
    );
  }

  Future<void> _submitPracticeRating(int score) async {
    final id = question.id;
    final store = await MistakeStore.load();
    await store.markResolvedSM2(id, score);
    await _next();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconcileGeneration++;
    _playersSub?.cancel();
    _realtimeSub?.cancel();
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();
    _advanceRetryTimer?.cancel();
    _serverReadyRetryTimer?.cancel();
    _roomSub?.cancel();
    _pollTimer?.cancel();
    _readyPingTimer?.cancel();
    _readyTimeoutTimer?.cancel();
    _visualReadyFallbackTimer?.cancel();
    _timerController.dispose();
    _explanationController.dispose();
    // TTS: ekrandan çıkınca devam eden seslendirmeyi durdur.
    TtsService.instance?.stop();
    super.dispose();
  }

  /// Uygulama arka plana alınınca soru sayacını durdurur.
  ///
  /// Depoda tek bir `WidgetsBindingObserver` yoktu: telefon kilitlenince,
  /// bir bildirime dokununca ya da uygulama değiştirilince geri sayım
  /// işlemeye devam ediyordu. Oyuncu geri döndüğünde süresi bitmiş bir
  /// soruyla karşılaşıyor, hatta doğrudan "TIMEOUT" görüyordu — hiç
  /// kendi hatası olmadan (2026-07-31 denetimi).
  ///
  /// Yalnız tek kişilik akışlarda duraklatılır. Çevrimiçi turda süreyi
  /// sunucu ve rakip belirler; istemcinin tek taraflı durması iki oyuncuyu
  /// birbirinden ayırır, o yüzden orada sayaç akmaya devam eder.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isMultiplayer) {
      if (state == AppLifecycleState.resumed) {
        unawaited(_reconcileOnlineRoom());
        if (_usesServerHiddenAnswers) {
          _serverReadyRetryCount = 0;
          _serverReadyRetryTimer?.cancel();
          _serverReadyRetryTimer = null;
          unawaited(_ensureServerClientReady(force: true));
        }
      }
      return;
    }
    if (!_usesTimer || answered || completing) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_timerController.isAnimating) {
          _timerController.stop();
          _questionStopwatch.stop();
        }
      case AppLifecycleState.resumed:
        // Süre baştan başlamaz; kaldığı yerden akar.
        if (!_timerController.isAnimating && _timerController.value > 0) {
          _timerController.reverse();
          _questionStopwatch.start();
        }
    }
  }

  /// TTS servisini başlatır ve cihazda Kürtçe dil desteğinin olup olmadığını
  /// kontrol eder. Destek yoksa dinleme butonu gizlenir.
  Future<void> _initializeTts() async {
    try {
      final tts = await TtsService.load();
      if (mounted) {
        setState(() => _ttsCanListen = tts.isKurdishAvailable);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz tts init');
    }
  }

  /// Mevcut soruyu seslendirir. Zaten konuşuyorsa durdurur.
  /// Buton yalnızca Kürtçe TTS destekleniyorsa görünür (canListen true ise).
  /// Buton ikonunun durumu `TtsService.speakingNotifier` üzerinden takip
  /// edilir; burada yalnızca speak/stop tetiklenir.
  Future<void> _listenCurrentQuestion() async {
    final tts = TtsService.instance;
    if (tts == null || !tts.isKurdishAvailable) return;
    try {
      if (tts.isSpeaking) {
        await tts.stop();
        return;
      }
      await tts.speak(question.promptText);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz tts speak');
    }
  }

  /// İlerleme varken geri tuşunda onay sorar; yanlışlıkla çıkışı önler.
  Future<void> _confirmExit() async {
    if (_exitInFlight || _terminalHandling || completing) return;
    if (_isMultiplayer && !_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return;
    }
    final generation = ++_exitGeneration;
    final expectedOwnerId = _onlineResultOwnerId;
    final expectedRoute = ModalRoute.of(context);
    if (!_canContinueExit(generation, expectedOwnerId, expectedRoute)) return;
    _exitInFlight = true;
    var leaveConfirmed = false;
    var leaveFailed = false;
    RoomLeaveOutcome? outcome;
    try {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor(context)),
          ),
          // Kopya akışa göre değişir: öğrenme akışında kullanıcı "yarış"
          // başlatmamıştı, ders başlatmıştı.
          title: Text(
            _isLearningExperience
                ? context.t(K.leaveLessonQ)
                : context.t(K.leaveRaceQ),
          ),
          content: Text(
            _isMultiplayer
                ? context.t(K.leaveOnlineMatchBody)
                : _isLearningExperience
                ? context.t(K.leaveLessonBody)
                : context.t(K.leaveRaceBody),
          ),
          // Vurgu güvenli eylemdedir. Önceden "Çık" dolgulu birincil buton,
          // "Devam Et" ise düz metindi: ilerlemeyi silen yıkıcı eylem, göz
          // en çok oraya gittiği için varsayılan gibi duruyordu
          // (2026-07-25 canlı denetimi).
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(context.t(K.leaveAction)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t(K.continueAction)),
            ),
          ],
        ),
      );
      if (leave != true ||
          !_canContinueExit(generation, expectedOwnerId, expectedRoute)) {
        return;
      }
      if (!mounted) return;
      leaveConfirmed = true;

      if (_isMultiplayer) {
        // Zaman aşımı, diğer çevrimiçi çağrılarla aynı bütçeyi kullanır.
        // `_exitInFlight` yeniden girişi kapatıyor ve çevrimiçi maçta
        // `PopScope.canPop` false; çağrı hata vermeden asılı kalırsa quiz
        // geri düğmesine yanıt vermeyi tamamen bırakıyordu.
        final leaveOutcome = await widget.repository
            .leaveOnlineRoom(widget.room)
            .timeout(_onlineResultRequestTimeout);
        if (!_canContinueExit(generation, expectedOwnerId, expectedRoute)) {
          return;
        }
        if (!mounted) return;
        outcome = leaveOutcome;
        if (!outcome.completed) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        Navigator.of(context).pop();
      }
    } catch (error, stack) {
      leaveFailed = true;
      ErrorReporter.record(error, stack, reason: 'quiz online leave failed');
      if (!mounted) return;
      if (_canContinueExit(generation, expectedOwnerId, expectedRoute)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.roomLeaveFailed))));
      }
    } finally {
      _exitInFlight = false;
      if (mounted &&
          _canContinueExit(generation, expectedOwnerId, expectedRoute)) {
        final deferred = _deferredEndState;
        _deferredEndState = null;
        if (outcome?.completed == true) {
          _scheduleTerminalAction(
            () => _completeMultiplayerResult(requestFinish: false),
          );
        } else if ((!leaveConfirmed || leaveFailed) && deferred != null) {
          _scheduleTerminalAction(() => _handleRoomEndState(deferred));
        }
      }
    }
  }

  bool _canContinueExit(
    int generation,
    String expectedOwnerId,
    ModalRoute<dynamic>? expectedRoute,
  ) {
    if (!mounted || generation != _exitGeneration) return false;
    return _canContinueOnExpectedRoute(expectedOwnerId, expectedRoute);
  }

  bool _canContinueOnExpectedRoute(
    String expectedOwnerId,
    ModalRoute<dynamic>? expectedRoute,
  ) {
    if (!mounted ||
        expectedRoute == null ||
        ModalRoute.of(context) != expectedRoute ||
        !expectedRoute.isCurrent) {
      return false;
    }
    if (!_isMultiplayer) return true;
    return expectedOwnerId == _onlineResultOwnerId && _hasExpectedOnlineOwner;
  }

  bool get _hasExpectedOnlineOwner {
    final currentOwnerId = widget.repository.currentUserId?.trim() ?? '';
    return _onlineResultOwnerId.isNotEmpty &&
        currentOwnerId == _onlineResultOwnerId;
  }

  bool get _hasCurrentOnlineRoomContext =>
      _canContinueOnExpectedRoute(_onlineResultOwnerId, ModalRoute.of(context));

  void _scheduleTerminalAction(Future<void> Function() action) {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      unawaited(action());
    });
    binding.scheduleFrame();
  }

  /// Başlıkta görünecek tur adı.
  ///
  /// Sıra: oda kodu (çevrimiçi) → turun adı → kategori → genel "yarış".
  String _roundTitle(BuildContext context) {
    if (widget.room.id != null) {
      return '${context.t(K.roomWord)} ${widget.room.code}';
    }
    final name = widget.room.name.trim();
    // Varsayılan oda adı bir tur adı değil, depo sabitidir.
    if (name.isNotEmpty && name != 'Hevalên Zanînê') return name;
    if (widget.room.category.isEmpty) return context.t(K.raceWord);
    return CategoryNames.localized(widget.room.category, context.isKu);
  }

  @override
  Widget build(BuildContext context) {
    if (_onlineResultPhase != _OnlineResultPhase.idle) {
      return _buildOnlineResultGate(context);
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient(context),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.t(K.questionsLoadFailed),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final hasProgress = index > 0 || answered;
    final favoriteActionLabel = favorite
        ? context.t(K.removeAction)
        : context.t(K.save);
    return PopScope(
      canPop: !_isMultiplayer && !hasProgress && !_exitInFlight,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          // Solo/bot oyunda oda kodu anlamsız gürültü; turun adı gösterilir.
          //
          // Kategori adı doğrudan yazılıyordu ve günün dersinde yalan
          // oluyordu: o tur **karışık kategorilidir**, oda ise varsayılan
          // 'Ziman' ile kurulur. Ekranın tepesinde "Ziman" yazarken ilk
          // soru "Çand" etiketiyle geliyordu (2026-07-27, canlı gezinti).
          //
          // Turun kendi adı varsa (günün dersi, yarışma) o gösterilir;
          // yoksa kategoriye düşülür.
          title: Text(_roundTitle(context)),
          actions: [
            IconButton(
              onPressed: _toggleFavorite,
              tooltip: favoriteActionLabel,
              icon: Icon(AppIcons.bookmark, semanticLabel: favoriteActionLabel),
            ),
            IconButton(
              onPressed: _reportQuestion,
              tooltip: context.t(K.reportAction),
              icon: const Icon(AppIcons.triangleExclamation),
            ),
          ],
        ),
        body: Column(
          children: [
            // Turnuva/versus bandı: rakip adı + tur bilgisi (UI-only).
            if (widget.versusBannerText != null)
              SafeArea(
                bottom: false,
                child: _VersusBanner(text: widget.versusBannerText!),
              ),
            Expanded(
              child: QuizTutorialOverlay(
                isKu: _isKu,
                timerKey: _timerTargetKey,
                answerAreaKey: _answerAreaKey,
                comboKey: _comboKey,
                wildcardKey: _wildcardKey,
                nextButtonKey: _nextButtonKey,
                onReady: _handleTutorialReady,
                timerSeconds: widget.room.secondsPerQuestion,
                timed: _usesTimer,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.backgroundGradient(context),
                  ),
                  child: Stack(
                    children: [
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final useCompactLandscapeLayout =
                                _useCompactLandscapeLayout(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );
                            if (useCompactLandscapeLayout) {
                              return _buildCompactLandscapeLayout();
                            }
                            return _buildPortraitLayout();
                          },
                        ),
                      ),
                      // Vinyet yalnız aktif geri sayım baskısında: cevap verildikten
                      // (veya süre dolduktan) sonra kırmızı parlama sönmeli, yoksa
                      // açıklama okunurken ekran "alarm" modunda kalıyor (2026-07-05
                      // görsel QA bulgusu).
                      if (_usesTimer && !answered)
                        CriticalVignette(animation: _timerController),
                      WrongFlash(trigger: _shakeTrigger),
                      if (_showAnswerBurst)
                        ConfettiOverlay(
                          particleCount: 24,
                          duration: const Duration(milliseconds: 900),
                          onFinished: () {
                            setState(() {
                              _showAnswerBurst = false;
                            });
                          },
                        ),
                      if (_showConfetti)
                        ConfettiOverlay(
                          onFinished: () {
                            setState(() {
                              _showConfetti = false;
                            });
                          },
                        ),
                      if ((_serverReadyWaiting && !answered) ||
                          (_needsOpponentReadyGate &&
                              !_opponentClientReady &&
                              !_questionFlowStarted))
                        _OpponentWaitingOverlay(isKu: _isKu),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Portrait layout: sabit header, kaydırılabilir orta, sabit alt bar ──

  /// Çevrimiçi maçta kendi skor satırını tazeler ve diğer oyunculara yayınlar.
  /// Cevap verme, sonraki soru ve bitiş akışları bu tek bloğu paylaşır.
  void _syncMyDuelState({required bool answeredNow, bool finished = false}) {
    if (!_isMultiplayer) return;
    final myIdx = livePlayers.indexWhere(_isMe);
    if (myIdx != -1) {
      livePlayers[myIdx] = Player(
        id: _myId,
        name: _myName,
        score: score,
        streak: streak,
        state: answeredNow
            ? Tr.forKu(K.answeredState, _isKu)
            : Tr.forKu(K.waitingAnswerState, _isKu),
      );
    }
    widget.repository
        .sendRoomBroadcast(widget.room.id!, {
          'sender': _myName,
          'sender_id': _myId,
          'score': score,
          'streak': streak,
          'question_index': index,
          'answered': answeredNow,
          if (!_usesServerHiddenAnswers)
            'selected_answer': answeredNow ? selectedAnswer : null,
          if (finished) 'finished': true,
        })
        .catchError((error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'quiz duel state broadcast failed',
          );
        });
  }

  void _checkMultiplayerSync() {
    if (!_isMultiplayer) return;
    if (_usesServerHiddenAnswers && answered && _hasSafeCurrentReveal) {
      if (_mpPhase != _MultiplayerPhase.reveal) _startRevealPhase();
      return;
    }
    final otherPlayers = _opponents.toList();
    if (otherPlayers.isEmpty) return;

    final allOthersAnswered =
        _opponentFinished ||
        otherPlayers.every(
          (player) => _answeredPlayerKeys.contains(
            playerIdentityKey(id: player.id, legacyName: player.name),
          ),
        );

    if (answered && allOthersAnswered && _mpPhase != _MultiplayerPhase.reveal) {
      if (_usesServerHiddenAnswers && !_hasSafeCurrentReveal) {
        unawaited(_reconcileOnlineRoom());
        return;
      }
      _startRevealPhase();
    }
  }

  /// Multiplayer reveal phase: doğru cevap ve açıklama gösterilir.
  /// [_revealCountdown] saniye sonra otomatik olarak sonraki soruya geçilir.
  void _startRevealPhase() {
    if (_mpPhase == _MultiplayerPhase.reveal ||
        (_usesServerHiddenAnswers && !_hasSafeCurrentReveal)) {
      return;
    }
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();

    const revealDuration = 5;
    setState(() {
      _mpPhase = _MultiplayerPhase.reveal;
      _revealCountdown = revealDuration;
      // Açıklamayı açıklama controller aracılığıyla da tetikle
      // (tek oyunculu ile aynı animasyon ritmi).
      _showExplanation = true;
    });

    // Her saniye geri sayım güncelle
    _revealTickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _revealCountdown = (revealDuration - timer.tick).clamp(
          0,
          revealDuration,
        );
      });
    });

    // Server-hidden odada her iki üye de aynı expected-index CAS'ini
    // güvenle deneyebilir. Eski broadcast tabanlı odalarda mevcut host
    // koordinasyonu korunur.
    _revealTimer = Timer(const Duration(seconds: revealDuration), () {
      _revealTickTimer?.cancel();
      if (mounted) {
        if (_usesServerHiddenAnswers) {
          unawaited(_advanceAuthoritativeIndex());
        } else if (_isHost) {
          unawaited(_next());
        } else {
          _requestAuthoritativeAdvance();
        }
      }
    });
  }

  /// Rakip cevap vermese bile bekleme fazını sınırlı tutar. Host yaşıyorsa
  /// ilerleme isteğini host karşılar; host yoksa yerel fallback oyunu kilitlemez.
  void _startOpponentWaitTimer() {
    if (!_isMultiplayer) return;
    _opponentWaitTimer?.cancel();
    if (_usesServerHiddenAnswers) {
      if (_advanceSequenceActive) return;
      final remainingMs = _estimatedAuthoritativeRemainingMs;
      if (remainingMs == null) {
        unawaited(_reconcileOnlineRoom());
        return;
      }
      _opponentWaitTimer = Timer(Duration(milliseconds: remainingMs), () {
        if (!mounted || !answered || _mpPhase != _MultiplayerPhase.waiting) {
          return;
        }
        _advanceSequenceActive = true;
        unawaited(_advanceAuthoritativeIndex());
      });
      return;
    }
    _opponentWaitTimer = Timer(
      Duration(seconds: max(20, widget.room.secondsPerQuestion)),
      () {
        if (!mounted || !answered || _mpPhase != _MultiplayerPhase.waiting) {
          return;
        }
        for (final player in livePlayers) {
          if (!_isMe(player)) {
            _answeredPlayerKeys.add(
              playerIdentityKey(id: player.id, legacyName: player.name),
            );
          }
        }
        _startRevealPhase();
      },
    );
  }

  void _requestAuthoritativeAdvance() {
    if (!_isMultiplayer) return;
    widget.repository
        .sendRoomBroadcast(widget.room.id!, {
          'sender': _myName,
          'sender_id': _myId,
          'question_index': index,
          'advance_request': true,
        })
        .catchError((error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'quiz advance request broadcast failed',
          );
        });

    // Only the host may update the authoritative room index. If the host has
    // disappeared, keep this client playable after a bounded grace period.
    _advanceRetryTimer?.cancel();
    _advanceRetryTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _isHost || _mpPhase != _MultiplayerPhase.reveal) return;
      unawaited(_next());
    });
  }

  /// Bu istemci odanın ev sahibi mi?
  ///
  /// Eskiden `hostId` bilinmiyorsa "oyuncu listesinin İLKİ benim miyim?"
  /// diye bir yedek yol vardı. O yol yalnız KATILAN için çalışabiliyordu
  /// ve yanlış cevap veriyordu:
  ///
  ///   * `createOnlineRoom` ev sahibine her zaman `hostId: user.id`
  ///     veriyor — gerçek ev sahibinin `hostId`si asla null olmaz.
  ///   * `joinOnlineRoom`daki ev sahibi sorgusu try/catch içinde;
  ///     düşerse katılan `hostId: null` ile odaya giriyor.
  ///   * Liste sırası ev sahipliği garantisi taşımıyor (skora göre
  ///     sıralanabiliyor), yani katılan pekâlâ "ilk" olabiliyor.
  ///
  /// Sonuç: katılan kendini ev sahibi sanıp `finishGame` çağırıyordu ve
  /// sunucu `Only the room host can finish the game` ile reddediyordu —
  /// canlı logda görüldü (2026-08-01). İki istemcinin birden ev sahibi
  /// sanması soruyu iki kez ilerletme riskini de taşıyordu.
  ///
  /// Bilinmiyorsa "ev sahibi değilim" demek güvenli taraf: yapmadığı iş
  /// zararsız, yapmaması gereken iş zararlı.
  bool get _isHost {
    final uid = widget.repository.currentUserId;
    if (uid == null) return false;
    return uid == widget.room.hostId;
  }

  void _onRoomQuestionIndexChanged(int dbIndex) {
    if (!_isMultiplayer) return;
    if (dbIndex > index) {
      if (_usesServerHiddenAnswers) {
        unawaited(_reconcileOnlineRoom());
      } else {
        _syncToQuestionIndex(dbIndex);
      }
    }
  }

  void _syncToQuestionIndex(int targetIndex) {
    if (targetIndex >= _questions.length) {
      _finishGameMultiplayer();
      return;
    }

    // Önceki sorunun reveal/advance timer'ları hâlâ yaşıyor olabilir (dışarıdan
    // bir index senkronizasyonu — rakip broadcast'i, realtime veya poll —
    // burayı _startRevealPhase()'in kendi 5sn'lik zamanlayıcısı dolmadan
    // tetikleyebilir). İptal edilmezlerse, süreleri dolduğunda ARTIK GÜNCEL
    // index üzerinden bir adım daha ilerletip yeni soruyu atlarlar
    // (2026-07-21 canlı denetiminde bulunan "soru kendi kendine atlıyor" hatası).
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();

    _explanationController.stop();
    _explanationController.reset();
    setState(() {
      index = targetIndex;
      selectedAnswer = '';
      favorite = false;
      _favoriteTouched = false;
      completing = false;
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
      _showExplanation = false;
      _suspense = false;
      _opponentSelectedAnswers.clear();
      _answeredPlayerKeys.clear();
      _opponentFinished = false;
      _mpPhase = _MultiplayerPhase.answering;
      _revealCountdown = 0;
      _syncMyDuelState(answeredNow: false);
    });
    _markQuestionSeen();
    _loadFavoriteState();
    // Tutorial (coach-mark) açıkken sayaç arkadan işlemesin: ilk kez odaya
    // giren oyuncu rehberi okurken süre yememeli. Rehber kapanınca
    // _handleTutorialReady ertelenen sayacı başlatır.
    if (_tutorialGateReady) {
      _startTimer();
    } else {
      _timerDeferredForTutorial = true;
    }
  }

  Future<void> _pollRoomIndex() async {
    await _reconcileOnlineRoom();
  }

  void _ensureRoomPolling() {
    if (!_isMultiplayer || _pollTimer?.isActive == true) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollRoomIndex();
    });
  }

  Future<void> _reconcileOnlineRoom() async {
    if (_isMultiplayer && !_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return;
    }
    if (!_isMultiplayer ||
        widget.room.id == null ||
        _reconcileInFlight ||
        _terminalHandling ||
        completing) {
      return;
    }
    final expectedOwnerId = _onlineResultOwnerId;
    final expectedRoute = ModalRoute.of(context);
    final routeMatches =
        expectedRoute != null && ModalRoute.of(context) == expectedRoute;
    if (!routeMatches ||
        (!_exitInFlight &&
            !_canContinueOnExpectedRoute(expectedOwnerId, expectedRoute))) {
      return;
    }
    _reconcileInFlight = true;
    final generation = ++_reconcileGeneration;
    RoomResumeSnapshot? snapshot;
    List<Player>? players;
    RoomEndState? endState;

    try {
      await Future.wait<void>([
        () async {
          try {
            snapshot = await widget.repository.loadMyResumableRoom();
          } catch (error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'quiz room resume reconciliation failed',
            );
          }
        }(),
        () async {
          try {
            players = await widget.repository.loadRoomPlayers(widget.room);
          } catch (error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'quiz room players reconciliation failed',
            );
          }
        }(),
        () async {
          try {
            endState = await widget.repository.loadRoomEndState(widget.room);
          } catch (error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'quiz room end reconciliation failed',
            );
          }
        }(),
      ]).timeout(_onlineResultRequestTimeout);
      if (!mounted || generation != _reconcileGeneration) return;
      if (!_hasExpectedOnlineOwner) {
        _enterOwnerChangedResultGate();
        return;
      }
      if (_exitInFlight) {
        if (ModalRoute.of(context) != expectedRoute) return;
        final state = endState;
        if (state != null) await _handleRoomEndState(state);
        return;
      }
      if (!_canContinueOnExpectedRoute(expectedOwnerId, expectedRoute)) {
        return;
      }

      final matchingSnapshot = _matchingResumeSnapshot(snapshot);
      if (matchingSnapshot != null &&
          matchingSnapshot.currentQuestionIndex >= index) {
        _applyReconciledSnapshot(matchingSnapshot);
      }

      final loadedPlayers = players;
      if (loadedPlayers != null && loadedPlayers.isNotEmpty && mounted) {
        setState(() {
          livePlayers = List<Player>.of(loadedPlayers)
            ..sort((a, b) => b.score.compareTo(a.score));
          if (matchingSnapshot != null) {
            _applyOwnAuthoritativePlayerState();
          }
        });
      }

      final state = endState;
      if (state != null && mounted) {
        await _handleRoomEndState(state);
      }
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'quiz room reconciliation timed out',
      );
    } finally {
      if (generation == _reconcileGeneration) {
        _reconcileInFlight = false;
      }
    }
  }

  void _applyReconciledSnapshot(RoomResumeSnapshot snapshot) {
    if (!mounted || _questions.isEmpty) return;
    final oldIndex = index;
    final hasTiming = _hasAuthoritativeTiming(snapshot);
    setState(() {
      _applyResumeSnapshotData(snapshot, initial: false);
      if (_usesServerHiddenAnswers && hasTiming && _clientReadyMarked) {
        _serverReadyWaiting = false;
        _serverReadyRetryCount = 0;
      }
    });
    if (_usesServerHiddenAnswers && hasTiming && _clientReadyMarked) {
      _serverReadyRetryTimer?.cancel();
      _serverReadyRetryTimer = null;
    }
    if (index > oldIndex) {
      _markQuestionSeen();
      _loadFavoriteState();
    }

    if (_usesServerHiddenAnswers && !hasTiming) {
      _timerController.stop();
      _questionStopwatch.stop();
      _initialTimerFraction = null;
      _questionFlowStarted = false;
      if (!answered) _scheduleServerReadyRetry();
      return;
    }

    if (answered) {
      _timerController.stop();
      _questionStopwatch.stop();
      _initialTimerFraction = null;
      if (!_usesServerHiddenAnswers || _serverQuestionGatesReady) {
        if (_mpPhase != _MultiplayerPhase.reveal) {
          _startOpponentWaitTimer();
        }
        _checkMultiplayerSync();
      }
      return;
    }

    final totalMs = widget.room.secondsPerQuestion * 1000;
    final remainingMs = _usesServerHiddenAnswers
        ? (_estimatedAuthoritativeRemainingMs ?? 0)
        : snapshot.remainingMs;
    final serverFraction = totalMs <= 0
        ? 0.0
        : (remainingMs / totalMs).clamp(0.0, 1.0).toDouble();
    _initialTimerFraction = null;
    _timerController.stop();
    _timerController.value = serverFraction;
    if (_usesServerHiddenAnswers && !_serverQuestionGatesReady) {
      _initialTimerFraction = serverFraction;
      _questionFlowStarted = false;
      return;
    }
    _questionFlowStarted = true;
    _questionStopwatch
      ..reset()
      ..start();
    if (!_usesTimer) return;
    if (_timerController.value <= 0) {
      scheduleMicrotask(() {
        if (mounted && !answered) _handleQuestionDeadline();
      });
    } else {
      _timerController.reverse();
    }
  }

  Future<bool> _handleRoomEndState(RoomEndState state) async {
    if (state.status != RoomStatus.finished) {
      return false;
    }
    if (_exitInFlight) {
      _deferredEndState = state;
      return false;
    }
    if (_isMultiplayer && !_hasExpectedOnlineOwner) {
      _deferredEndState = state;
      _enterOwnerChangedResultGate();
      return false;
    }
    if (_isMultiplayer && !_hasCurrentOnlineRoomContext) {
      _deferredEndState = state;
      return false;
    }
    if (completing || _terminalHandling) return false;
    final reason = state.endedReason?.trim().toLowerCase();
    if (reason == 'completed' ||
        (reason == null && isLastQuestion && answered)) {
      await _completeMultiplayerResult(requestFinish: false);
      return true;
    }

    final expectedOwnerId = _onlineResultOwnerId;
    final expectedRoute = ModalRoute.of(context);
    if (!_canContinueOnExpectedRoute(expectedOwnerId, expectedRoute)) {
      _deferredEndState = state;
      return false;
    }

    _terminalHandling = true;
    _timerController.stop();
    _questionStopwatch.stop();
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();
    _advanceRetryTimer?.cancel();
    _serverReadyRetryTimer?.cancel();

    final forfeitedBy =
        state.forfeitedBy ??
        (reason == 'host_left' ? widget.room.hostId : null);
    final userForfeited = forfeitedBy != null && forfeitedBy == _myId;
    final bodyKey = forfeitedBy == null
        ? K.matchEndedByDeparture
        : userForfeited
        ? K.youForfeitedMatch
        : K.opponentForfeitedMatch;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(context.t(K.matchForfeitedTitle)),
        content: Text(context.t(bodyKey)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t(K.ok)),
          ),
        ],
      ),
    );
    if (!mounted) return true;
    if (!_canContinueOnExpectedRoute(expectedOwnerId, expectedRoute)) {
      _terminalHandling = false;
      _deferredEndState = state;
      return false;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    return true;
  }

  Future<void> _advanceAuthoritativeIndex({
    int? expectedQuestionIndex,
    int attempt = 0,
  }) async {
    if (!_usesServerHiddenAnswers ||
        _advanceInFlight ||
        _terminalHandling ||
        completing) {
      return;
    }
    final expected = expectedQuestionIndex ?? index;
    if (expected != index) return;
    _advanceSequenceActive = true;
    final wasRevealPhase = _mpPhase == _MultiplayerPhase.reveal;

    _advanceInFlight = true;
    RoomResumeSnapshot? snapshot;
    Object? failure;
    StackTrace? failureStack;
    try {
      snapshot = await widget.repository.advanceRoomQuestion(
        widget.room,
        expectedQuestionIndex: expected,
      );
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    } finally {
      _advanceInFlight = false;
    }
    if (!mounted || index != expected) return;

    if (failure != null) {
      ErrorReporter.record(
        failure,
        failureStack ?? StackTrace.current,
        reason: 'quiz authoritative advance failed',
      );
      await _reconcileOnlineRoom();
      if (mounted && index == expected && !completing) {
        _scheduleAdvanceRetry(expected, attempt);
      }
      return;
    }

    final matchingSnapshot = _matchingResumeSnapshot(snapshot);
    if (matchingSnapshot == null) {
      await _reconcileOnlineRoom();
      if (mounted && index == expected && !completing && !_terminalHandling) {
        _scheduleAdvanceRetry(expected, attempt);
      }
      return;
    }

    _applyReconciledSnapshot(matchingSnapshot);
    if (!mounted || index != expected) return;
    if (_hasSafeCurrentReveal) {
      if (wasRevealPhase) {
        _scheduleAdvanceRetry(expected, attempt);
      } else if (_mpPhase != _MultiplayerPhase.reveal) {
        _startRevealPhase();
      }
      return;
    }

    await _reconcileOnlineRoom();
    if (mounted && index == expected && !completing && !_terminalHandling) {
      _scheduleAdvanceRetry(expected, attempt);
    }
  }

  void _scheduleAdvanceRetry(int expectedQuestionIndex, int attempt) {
    if (!_usesServerHiddenAnswers ||
        expectedQuestionIndex != index ||
        completing ||
        _terminalHandling) {
      return;
    }
    _advanceRetryTimer?.cancel();
    if (attempt >= 5) {
      _advanceRetryTimer = Timer(const Duration(seconds: 4), () {
        _advanceRetryTimer = null;
        if (!mounted || expectedQuestionIndex != index) return;
        unawaited(
          _advanceAuthoritativeIndex(
            expectedQuestionIndex: expectedQuestionIndex,
          ),
        );
      });
      return;
    }
    _advanceRetryTimer = Timer(const Duration(milliseconds: 350), () {
      _advanceRetryTimer = null;
      if (!mounted || expectedQuestionIndex != index) return;
      unawaited(
        _advanceAuthoritativeIndex(
          expectedQuestionIndex: expectedQuestionIndex,
          attempt: attempt + 1,
        ),
      );
    });
  }

  /// Tur ödülünü ister; verilemezse kuyruğa alır.
  ///
  /// Çevrimdışı bitirilen turda `claim_quiz_reward` düşüyor ve coin
  /// sessizce kayboluyordu — XP aynı durumda kuyruğa giriyordu, coin
  /// girmiyordu. Kuyruğa giren miktar değil turun olgularıdır; ödülü yine
  /// sunucu hesaplar (2026-07-26).
  /// Son turda ödül kuyruğa alındı mı? Sonuç ekranı bunu oyuncuya söyler.
  bool _rewardQueued = false;

  Future<_QuizCoinSettlement> _settleCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) async {
    final rewardOwnerId = widget.repository.currentUserId?.trim() ?? '';
    // Alıştırma (yanlış tekrarı) bilerek ödülsüz: aynı sorular tekrar
    // çözülüyor, yeni bir tur değil.
    //
    // Solo tur ise 2026-08-10'a kadar burada erken dönüyordu ve sıfır
    // jeton veriyordu — yani ürünün ANA döngüsü, çevrimdışı tek başına
    // oynamak, hiçbir şey kazandırmıyordu. Artık `claim_solo_reward`
    // RPC'sine gidiyor: sunucu turu doğrulayamaz (çevrimdışı banka
    // istemcide) ama talebi günlük tavanla sınırlar.
    if (widget.practice) {
      return (
        coinsAwarded: 0,
        rewardQueued: false,
        isDurable: true,
        ownerUserId: rewardOwnerId,
      );
    }
    var amount = 0;
    var rewardQueued = false;
    var durable = false;
    // "Sunucu 0 verdi" ile "sunucuya ulaşılamadı" aynı şey değil.
    //
    // Eskiden yalnız `amount <= 0`a bakılıyordu. Sunucu düşük skora
    // meşru olarak 0 coin verdiğinde — 10 soruda 2 doğru gibi — sonuç
    // ekranı "Bağlantı yok — ödülün kaydedildi, bağlanınca verilecek."
    // diyordu. Bağlantı vardı; tur zaten sunucuda işlenmişti. Üstelik
    // aynı tur kuyruğa da giriyordu, yani senkron çalışınca ödül ikinci
    // kez istenebiliyordu. 2026-08-01'de iki cihazlı canlı maçın sonuç
    // ekranında görüldü.
    var awardFailed = false;
    try {
      amount = await widget.repository.awardQuizCoins(
        score: score,
        correctCount: correctCount,
        bestStreak: bestStreak,
        totalQuestions: totalQuestions,
        room: widget.room,
      );
      durable = true;
    } catch (error, stack) {
      awardFailed = true;
      ErrorReporter.record(error, stack, reason: 'awardQuizCoins failed');
    }
    if (awardFailed) {
      final currentOwnerId = widget.repository.currentUserId?.trim() ?? '';
      if (rewardOwnerId.isEmpty || currentOwnerId != rewardOwnerId) {
        ErrorReporter.record(
          StateError('Quiz reward owner changed before queue.'),
          StackTrace.current,
          reason: 'quiz reward owner changed before queue',
        );
        return (
          coinsAwarded: amount,
          rewardQueued: false,
          isDurable: false,
          ownerUserId: rewardOwnerId,
        );
      }
      // Kuyruk yoksa (oturum kapatılıp yeniden girilmişse SyncManager
      // kurulu değildir) tur yine de bitmelidir. Eskiden burada
      // `SyncManager.instance` çağrılıyordu ve fırlatan istisna
      // `_next()`/`_finishGameMultiplayer()` içinden yukarı kaçıp sonuç
      // ekranının açılmasını engelliyordu.
      final sync = SyncManager.maybeInstance;
      if (sync != null) {
        try {
          await sync.queueQuizReward(
            score: score,
            correctCount: correctCount,
            bestStreak: bestStreak,
            totalQuestions: totalQuestions,
            roomId: widget.room.id,
          );
          rewardQueued = true;
          durable = true;
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'queueQuizReward failed');
        }
      }
    }
    return (
      coinsAwarded: amount,
      rewardQueued: rewardQueued,
      isDurable: durable,
      ownerUserId: rewardOwnerId,
    );
  }

  Future<int> _claimCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) async {
    _rewardQueued = false;
    if (widget.practice) return 0;
    if (widget.room.id == null) return 0;
    final settlement = await _settleCoins(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
    );
    if (settlement.rewardQueued) {
      _rewardQueued = true;
    } else {
      _rewardQueued = false;
    }
    return settlement.coinsAwarded;
  }

  Future<void> _finishGameMultiplayer() async {
    if (completing ||
        _terminalHandling ||
        _onlineResultPhase != _OnlineResultPhase.idle) {
      return;
    }
    await _completeMultiplayerResult(requestFinish: true);
  }

  Future<void> _completeMultiplayerResult({required bool requestFinish}) {
    if (widget.is1v1) {
      return _reconcileCompletedRoomResult(requestFinish: requestFinish);
    }
    return _finishLegacyMultiplayerResult(requestFinish: requestFinish);
  }

  Future<void> _finishLegacyMultiplayerResult({
    required bool requestFinish,
  }) async {
    if (_legacyResultInFlight || completing || _terminalHandling) return;
    final expectedOwnerId = _onlineResultOwnerId;
    final expectedRoute = ModalRoute.of(context);
    if (!_canContinueOnExpectedRoute(expectedOwnerId, expectedRoute)) return;
    _legacyFinishRequired = requestFinish;
    final generation = ++_legacyResultGeneration;
    _legacyResultInFlight = true;
    setState(() => completing = true);

    try {
      RoomEndState? stateAfterFailure;
      if (requestFinish) {
        try {
          final pendingFinish = _legacyFinishInFlight ??= widget.repository
              .finishGame(widget.room);
          await pendingFinish.timeout(_onlineResultRequestTimeout);
          if (identical(_legacyFinishInFlight, pendingFinish)) {
            _legacyFinishInFlight = null;
          }
          _legacyFinishRequired = false;
        } on TimeoutException catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'quiz finish game timed out',
          );
          _showLegacyResultFailure(generation);
          return;
        } catch (error, stack) {
          _legacyFinishInFlight = null;
          ErrorReporter.record(error, stack, reason: 'quiz finish game failed');
          try {
            stateAfterFailure = await widget.repository
                .loadRoomEndState(widget.room)
                .timeout(_onlineResultRequestTimeout);
          } catch (stateError, stateStack) {
            ErrorReporter.record(
              stateError,
              stateStack,
              reason: 'quiz finish state verification failed',
            );
            _showLegacyResultFailure(generation);
            return;
          }
          if (!mounted) return;
          if (!_canContinueLegacyResult(
            generation,
            expectedOwnerId,
            expectedRoute,
          )) {
            _releaseLegacyCompleting(generation);
            return;
          }
          final verified = stateAfterFailure;
          if (verified.status != RoomStatus.finished) {
            _showLegacyResultFailure(generation);
            return;
          }
          _legacyFinishRequired = false;
          final reason = verified.endedReason?.trim().toLowerCase();
          if (reason != null && reason != 'completed') {
            _releaseLegacyCompleting(generation);
            await _handleRoomEndState(verified);
            return;
          }
        }
      }

      try {
        final finalPlayers = await widget.repository
            .loadRoomPlayers(widget.room)
            .timeout(_onlineResultRequestTimeout);
        if (!mounted) return;
        if (!_canContinueLegacyResult(
          generation,
          expectedOwnerId,
          expectedRoute,
        )) {
          _releaseLegacyCompleting(generation);
          return;
        }
        if (finalPlayers.isNotEmpty) {
          setState(() {
            livePlayers = List<Player>.of(finalPlayers)
              ..sort((a, b) => b.score.compareTo(a.score));
            final myPlayerIndex = livePlayers.indexWhere(_isMe);
            if (myPlayerIndex != -1) {
              final myPlayer = livePlayers[myPlayerIndex];
              if (myPlayer.score >= score) {
                score = myPlayer.score;
                streak = myPlayer.streak;
                bestStreak = max(bestStreak, myPlayer.streak);
              }
            }
            _applyOwnAuthoritativePlayerState();
          });
        }
      } on TimeoutException catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'quiz final players reconciliation timed out',
        );
        _showLegacyResultFailure(generation);
        return;
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'quiz final players reconciliation failed',
        );
      }
      if (!mounted) return;
      if (!_canContinueLegacyResult(
        generation,
        expectedOwnerId,
        expectedRoute,
      )) {
        _releaseLegacyCompleting(generation);
        return;
      }
      _syncMyDuelState(answeredNow: true, finished: true);

      var settlement = _legacyRewardSettlement;
      if (settlement == null) {
        for (var attempt = 0; attempt < 2 && settlement == null; attempt++) {
          final reusedPendingSettlement = _legacySettlementInFlight != null;
          final pendingSettlement = _legacySettlementInFlight ??= _settleCoins(
            score: score,
            correctCount: correctCount,
            bestStreak: bestStreak,
            totalQuestions: widget.questions.length,
          );
          late final _QuizCoinSettlement candidate;
          try {
            candidate = await pendingSettlement.timeout(
              _onlineResultRequestTimeout,
            );
          } on TimeoutException catch (error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'quiz legacy reward settlement timed out',
            );
            _showLegacyResultFailure(generation);
            return;
          } catch (error, stack) {
            if (identical(_legacySettlementInFlight, pendingSettlement)) {
              _legacySettlementInFlight = null;
            }
            ErrorReporter.record(
              error,
              stack,
              reason: 'quiz legacy reward settlement failed',
            );
            _showLegacyResultFailure(generation);
            return;
          }
          if (identical(_legacySettlementInFlight, pendingSettlement)) {
            _legacySettlementInFlight = null;
          }
          if (candidate.isDurable && candidate.ownerUserId == expectedOwnerId) {
            _legacyRewardSettlement = candidate;
          }
          if (!mounted) return;
          if (!_canContinueLegacyResult(
            generation,
            expectedOwnerId,
            expectedRoute,
          )) {
            _releaseLegacyCompleting(generation);
            return;
          }
          if (!candidate.isDurable && reusedPendingSettlement) {
            continue;
          }
          settlement = candidate;
        }
        if (settlement == null) {
          _showLegacyResultFailure(generation);
          return;
        }
        if (settlement.isDurable && settlement.ownerUserId == expectedOwnerId) {
          _legacyRewardSettlement = settlement;
        }
      }

      if (!mounted) return;
      if (!_canContinueLegacyResult(
        generation,
        expectedOwnerId,
        expectedRoute,
      )) {
        _releaseLegacyCompleting(generation);
        return;
      }
      context.read<SoundProvider>().playWin();
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          QuizResultScreen(
            repository: widget.repository,
            room: _resultRoom,
            score: score,
            correctCount: correctCount,
            wrongCount: wrongCount,
            totalQuestions: widget.questions.length,
            bestStreak: bestStreak,
            answerRecords: answerRecords,
            coinsAwarded: settlement.coinsAwarded,
            rewardQueued: settlement.rewardQueued,
            opponents: _opponents.toList(),
            practice: widget.practice,
            dailyQuiz: widget.dailyQuiz,
            contestId: widget.contestId,
          ),
        ),
        result: _completionResult(),
      );
    } finally {
      _legacyResultInFlight = false;
      if (_legacyRetryRequested) {
        _legacyRetryRequested = false;
        if (mounted &&
            _hasExpectedOnlineOwner &&
            _onlineResultPhase == _OnlineResultPhase.retryableFailure) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_retryTeamOnlineResultGate());
          });
          WidgetsBinding.instance.scheduleFrame();
        }
      }
    }
  }

  bool _canContinueLegacyResult(
    int generation,
    String expectedOwnerId,
    ModalRoute<dynamic>? expectedRoute,
  ) {
    if (!mounted || generation != _legacyResultGeneration) return false;
    if (!_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return false;
    }
    return _canContinueOnExpectedRoute(expectedOwnerId, expectedRoute);
  }

  void _releaseLegacyCompleting(int generation) {
    if (!mounted ||
        generation != _legacyResultGeneration ||
        _onlineResultPhase != _OnlineResultPhase.idle) {
      return;
    }
    setState(() => completing = false);
  }

  void _showLegacyResultFailure(int generation) {
    if (!mounted || generation != _legacyResultGeneration) return;
    if (!_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return;
    }
    _terminalHandling = true;
    completing = true;
    _stopTerminalActivity();
    setState(() {
      _onlineResultPhase = _OnlineResultPhase.retryableFailure;
      _onlineResultOwnerChanged = false;
    });
  }

  Future<void> _reconcileCompletedRoomResult({
    bool requestFinish = false,
  }) async {
    if (!_isMultiplayer || !widget.is1v1 || _onlineResultInFlight) return;
    if (requestFinish) _onlineResultFinishRequired = true;
    final roomId = widget.room.id?.trim() ?? '';
    final expectedOwnerId = _onlineResultOwnerId;
    final generation = ++_onlineResultGeneration;
    _onlineResultInFlight = true;
    _terminalHandling = true;
    completing = true;
    _stopTerminalActivity();
    if (mounted) {
      setState(() {
        _onlineResultPhase = _OnlineResultPhase.loading;
        _onlineResultOwnerChanged = false;
      });
    }

    try {
      if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;
      if (_onlineResultFinishRequired) {
        try {
          await widget.repository
              .finishGame(widget.room)
              .timeout(_onlineResultRequestTimeout);
          _onlineResultFinishRequired = false;
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'quiz finish game failed');
        }
        if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;
      }

      final snapshot = await widget.repository
          .loadRoomResult(widget.room)
          .timeout(_onlineResultRequestTimeout);
      if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;
      if (snapshot == null) {
        final endState = await widget.repository
            .loadRoomEndState(widget.room)
            .timeout(_onlineResultRequestTimeout);
        if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;
        final reason = endState.endedReason?.trim().toLowerCase();
        if (endState.status == RoomStatus.finished &&
            reason != null &&
            reason != 'completed') {
          _onlineResultPhase = _OnlineResultPhase.idle;
          _terminalHandling = false;
          completing = false;
          final handled = await _handleRoomEndState(endState);
          if (handled || !mounted) return;
          if (!_hasExpectedOnlineOwner) {
            _enterOwnerChangedResultGate();
          } else {
            _showOnlineResultFailure(generation);
          }
          return;
        }
        throw StateError('Exact room result is not available yet.');
      }
      validateRoomResultDeliveryContext(
        snapshot,
        expectedUserId: expectedOwnerId,
        expectedRoomId: roomId,
      );
      final presentation = buildRoomResultPresentation(
        snapshot,
        _questions,
        isKu: _isKu,
      );
      if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;
      if (!mounted) return;

      context.read<SoundProvider>().playWin();
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          RoomResultRecoveryScreen(
            repository: widget.repository,
            snapshot: snapshot,
            expectedUserId: expectedOwnerId,
          ),
        ),
        result: _completionResultFromPresentation(presentation),
      );
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'quiz exact room result recovery failed',
      );
      _showOnlineResultFailure(generation);
    } finally {
      if (generation == _onlineResultGeneration) {
        _onlineResultInFlight = false;
      }
    }
  }

  bool _canContinueOnlineResult(int generation, String expectedOwnerId) {
    if (!mounted || generation != _onlineResultGeneration) return false;
    final currentOwnerId = widget.repository.currentUserId?.trim() ?? '';
    if (expectedOwnerId.isEmpty || currentOwnerId != expectedOwnerId) {
      _showOnlineResultFailure(generation, ownerChanged: true);
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      _showOnlineResultFailure(generation);
      return false;
    }
    return true;
  }

  void _showOnlineResultFailure(int generation, {bool ownerChanged = false}) {
    if (!mounted || generation != _onlineResultGeneration) return;
    setState(() {
      _onlineResultPhase = _OnlineResultPhase.retryableFailure;
      _onlineResultOwnerChanged = ownerChanged;
    });
  }

  void _enterOwnerChangedResultGate() {
    if (!mounted || !_isMultiplayer) return;
    if (_onlineResultOwnerChanged &&
        _onlineResultPhase == _OnlineResultPhase.retryableFailure) {
      return;
    }
    _onlineResultGeneration++;
    _onlineResultInFlight = false;
    if (!widget.is1v1) _legacyResultGeneration++;
    _terminalHandling = true;
    completing = true;
    _stopTerminalActivity();
    setState(() {
      _onlineResultPhase = _OnlineResultPhase.retryableFailure;
      _onlineResultOwnerChanged = true;
    });
  }

  void _leaveOnlineResultGate() {
    if (!mounted || _onlineResultPhase != _OnlineResultPhase.retryableFailure) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retryOnlineResultGate() {
    if (!mounted || _onlineResultPhase != _OnlineResultPhase.retryableFailure) {
      return;
    }
    if (!_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return;
    }
    if (!widget.is1v1) {
      if (_legacyResultInFlight) {
        _legacyRetryRequested = true;
        return;
      }
      unawaited(_retryTeamOnlineResultGate());
      return;
    }
    setState(() {
      _onlineResultPhase = _OnlineResultPhase.idle;
      _onlineResultOwnerChanged = false;
      _terminalHandling = false;
      completing = false;
    });
    unawaited(_completeMultiplayerResult(requestFinish: false));
  }

  Future<void> _retryTeamOnlineResultGate() async {
    if (!mounted || widget.is1v1 || _onlineResultInFlight) return;
    if (!_hasExpectedOnlineOwner) {
      _enterOwnerChangedResultGate();
      return;
    }
    final expectedOwnerId = _onlineResultOwnerId;
    final generation = ++_onlineResultGeneration;
    _onlineResultInFlight = true;
    _terminalHandling = true;
    completing = true;
    setState(() {
      _onlineResultPhase = _OnlineResultPhase.loading;
      _onlineResultOwnerChanged = false;
    });

    try {
      final endState = await widget.repository
          .loadRoomEndState(widget.room)
          .timeout(_onlineResultRequestTimeout);
      if (!_canContinueOnlineResult(generation, expectedOwnerId)) return;

      if (endState.status != RoomStatus.finished) {
        setState(() {
          _onlineResultPhase = _OnlineResultPhase.idle;
          _onlineResultOwnerChanged = false;
          _terminalHandling = false;
          completing = false;
        });
        if (_legacyFinishInFlight != null || _legacyFinishRequired) {
          await _finishLegacyMultiplayerResult(requestFinish: true);
          return;
        }
        _ensureRoomPolling();
        unawaited(_reconcileOnlineRoom());
        if (_usesServerHiddenAnswers) {
          unawaited(_ensureServerClientReady(force: true));
        }
        return;
      }

      final reason = endState.endedReason?.trim().toLowerCase();
      setState(() {
        _onlineResultPhase = _OnlineResultPhase.idle;
        _onlineResultOwnerChanged = false;
        _terminalHandling = false;
        completing = false;
      });
      if (reason == 'completed' ||
          (reason == null && isLastQuestion && answered)) {
        await _finishLegacyMultiplayerResult(requestFinish: false);
        return;
      }
      final handled = await _handleRoomEndState(endState);
      if (handled || !mounted) return;
      if (!_hasExpectedOnlineOwner) {
        _enterOwnerChangedResultGate();
      } else {
        _showOnlineResultFailure(generation);
      }
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'quiz team result recovery failed',
      );
      _showOnlineResultFailure(generation);
    } finally {
      if (generation == _onlineResultGeneration) {
        _onlineResultInFlight = false;
      }
    }
  }

  void _stopTerminalActivity() {
    _timerController.stop();
    _questionStopwatch.stop();
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();
    _advanceRetryTimer?.cancel();
    _serverReadyRetryTimer?.cancel();
    _pollTimer?.cancel();
  }

  Map<String, dynamic> _completionResultFromPresentation(
    RoomResultPresentation presentation,
  ) {
    final opponentScore = presentation.opponents.fold<int>(
      0,
      (best, player) => max(best, player.score),
    );
    return {
      'completed': true,
      'score': presentation.score,
      'correct': presentation.correctCount,
      'opponentScore': opponentScore,
    };
  }

  Widget _buildOnlineResultGate(BuildContext context) {
    final loading = _onlineResultPhase == _OnlineResultPhase.loading;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !loading) {
          _leaveOnlineResultGate();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.t(K.resultTitle)),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      _onlineResultOwnerChanged
                          ? AppIcons.shield
                          : AppIcons.cloud,
                      size: 42,
                      color: AppTheme.gold,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.t(
                      loading
                          ? K.resultRecoveryLoading
                          : _onlineResultOwnerChanged
                          ? K.resultRecoveryOwnerChanged
                          : K.resultRecoveryFailed,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge,
                  ),
                  if (!loading) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _retryOnlineResultGate,
                      icon: const Icon(AppIcons.arrowsRotate),
                      label: Text(context.t(K.retry)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _leaveOnlineResultGate,
                      icon: const Icon(AppIcons.house),
                      label: Text(context.t(K.home)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _answer(String answer) async {
    if (answered) return;
    HapticFeedback.selectionClick();

    _timerController.stop();

    // Çift Cevap aktifse ve ilk deneme yanlışsa: göster ama kilitleme.
    // NOT: açıklama burada tetiklenmez — aksi halde reveal görüntüsü
    // (kırmızı şık + açıklama) oluşurken "Piştre" hâlâ devre dışı kalır ve
    // kullanıcı ikinci şıkkı seçmesi gerektiğini anlamadan takılı kalırdı
    // (2026-07-19 canlı denetim P0 bulgusu).
    if (!_usesServerHiddenAnswers &&
        _wildcard.doubleAnswerActivated &&
        _firstAttemptAnswer.isEmpty &&
        answer != question.correctAnswer) {
      HapticFeedback.heavyImpact();
      setState(() => _firstAttemptAnswer = answer);
      // Geri sayımı SÜRDÜR. `_answer` en başta `_timerController.stop()`
      // çağırıyor; bu erken çıkış onu yeniden başlatmadığı için ilk yanlış
      // denemeden sonra sayaç kalıcı olarak donuyordu. Soru hâlâ açık ve
      // oyuncu ikinci şıkkı seçecek, ama süre baskısı ortadan kalkıyordu:
      // Çift Cevap jokeri istemeden sınırsız süre de veriyordu
      // (2026-07-31 denetimi).
      //
      // `_startTimer` değil `reverse()`: süre baştan başlamamalı, kaldığı
      // yerden akmalı. Stopwatch da zaten çalışmaya devam ediyor.
      if (_usesTimer) _timerController.reverse();
      return;
    }

    // Multiplayer'da açıklama reveal phase'de gösterilir, hemen değil.
    if (!_isMultiplayer) {
      _explanationController.forward(from: 0);
    }

    // Optimistically select it to disable buttons immediately.
    // TIMEOUT dışında kısa bir "gerilim tutuşu" ile sonuç açıklanması
    // geciktirilir (TV-şovu ritmi); testte beklemeden geçilir.
    final isTimeout = answer == 'TIMEOUT';
    final questionIndex = index;
    setState(() {
      selectedAnswer = answer;
      _suspense = !isTimeout || _usesServerHiddenAnswers;
    });
    final responseMs = _questionStopwatch.elapsedMilliseconds;
    if (!isTimeout && !isFlutterTestEnvironment) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
    // Bekleme sırasında soru ilerlediyse (ör. hızlı "Piştre") sonucu
    // yeni soruya uygulama — eski cevabın skor bulaşmasını önler.
    if (!mounted || index != questionIndex) return;

    final optionKey = question.optionKeyForAnswer(answer);

    try {
      // Zaman aşımı: ağ takılırsa gerilim tutuşu sonsuza dek sürmez;
      // catch bloğundaki yerel değerlendirme devreye girer.
      final result = await widget.repository
          .submitAnswer(
            room: widget.room,
            question: question,
            selectedOptionOptionKey: optionKey,
            responseMs: responseMs,
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted || index != questionIndex) return;

      final pendingServerReveal =
          _usesServerHiddenAnswers &&
          (result['pending'] == true ||
              (result['accepted'] == true &&
                  !result.containsKey('correct_option') &&
                  !result.containsKey('is_correct')));
      if (pendingServerReveal) {
        setState(() {
          _suspense = false;
          _serverAnswerPending = true;
          _mpPhase = _MultiplayerPhase.waiting;
          _answeredPlayerKeys.add(
            playerIdentityKey(id: _myId, legacyName: _myName),
          );
        });
        _syncMyDuelState(answeredNow: true);
        _startOpponentWaitTimer();
        unawaited(_reconcileOnlineRoom());
        return;
      }

      QuizQuestion? revealedQuestion;
      if (_usesServerHiddenAnswers) {
        final correctAnswer = question.answerForOptionKey(
          result['correct_option'] as String?,
        );
        if (correctAnswer == null) {
          throw StateError('Server did not reveal a valid correct option');
        }
        revealedQuestion = question.withRevealedAnswer(
          correctAnswer: correctAnswer,
          explanation: result['explanation'] as String?,
          explanationKu: result['explanation_ku'] as String?,
          explanationTr: result['explanation_tr'] as String?,
        );
      }

      if (result['is_correct'] == true) {
        HapticFeedback.mediumImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.vibrate();
        context.read<SoundProvider>().playWrong();
      }

      final isCorrect = result['is_correct'] == true;
      _trackMistake(isCorrect);
      final oldScore = score;
      setState(() {
        if (revealedQuestion != null) {
          _questions[questionIndex] = revealedQuestion;
        }
        _serverAnswerPending = false;
        _suspense = false;
        score =
            result['new_score'] as int? ??
            (score + (result['points'] as int? ?? 0));
        final correct = isCorrect;
        final alreadyAnswered = result['already_answered'] == true;
        streak = result['new_streak'] as int? ?? (correct ? streak + 1 : 0);
        bestStreak = bestStreak < streak ? streak : bestStreak;
        if (!alreadyAnswered) {
          if (correct) {
            correctCount += 1;
          } else {
            wrongCount += 1;
          }
        }
        if (correct && streak >= 5 && streak % 5 == 0) {
          _showConfetti = true;
        }
        if (correct) {
          _showAnswerBurst = true;
          _lastPointsEarned = score - oldScore;
          _flyupTrigger += 1;
        } else {
          _shakeTrigger += 1;
        }
        _recordAnswer(
          answer,
          responseMs: responseMs,
          pointsEarned: result['points'] as int? ?? 0,
        );
        _advanceBots();
        _syncMyDuelState(answeredNow: true);
        // Multiplayer: bekleme fazına geç
        if (_isMultiplayer) {
          _mpPhase = _MultiplayerPhase.waiting;
          _startOpponentWaitTimer();
        }
      });
      _revealCorrectAnswer();
      _checkMultiplayerSync();
      // Altın kademe anı: ×10 seriye özel kutlama sesi (yeni asset yok).
      if (isCorrect && streak == 10 && mounted) {
        context.read<SoundProvider>().playWin();
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'submitAnswer failed');
      if (_usesServerHiddenAnswers) {
        if (!mounted || index != questionIndex) return;
        setState(() {
          selectedAnswer = '';
          _serverAnswerPending = false;
          _suspense = false;
        });
        await _reconcileOnlineRoom();
        if (!mounted || index != questionIndex || answered) return;
        final remainingMs = _estimatedAuthoritativeRemainingMs;
        if (remainingMs != null) {
          final totalMs = widget.room.secondsPerQuestion * 1000;
          _timerController.stop();
          _timerController.value = totalMs <= 0
              ? 0
              : (remainingMs / totalMs).clamp(0.0, 1.0).toDouble();
          if (remainingMs > 0 && _usesTimer) {
            _timerController.reverse();
            _questionStopwatch.start();
          } else if (remainingMs <= 0) {
            unawaited(_advanceAuthoritativeIndex());
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.answerSendFailed))));
        return;
      }
      // Fallback local logic if network fails during answer submit
      if (!mounted || index != questionIndex) return;
      final correct = answer == question.correctAnswer;
      _trackMistake(correct);
      if (correct) {
        HapticFeedback.mediumImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.vibrate();
        context.read<SoundProvider>().playWrong();
      }
      setState(() {
        _suspense = false;
        if (correct) {
          streak += 1;
          bestStreak = bestStreak < streak ? streak : bestStreak;
          correctCount += 1;
          final points = 100 + (streak * 10).clamp(0, 50);
          score += points;
          if (streak >= 5 && streak % 5 == 0) {
            _showConfetti = true;
          }
          _showAnswerBurst = true;
          _lastPointsEarned = points;
          _flyupTrigger += 1;
        } else {
          streak = 0;
          wrongCount += 1;
          _shakeTrigger += 1;
        }
        _recordAnswer(
          answer,
          responseMs: responseMs,
          pointsEarned: correct ? (100 + (streak * 10).clamp(0, 50)) : 0,
        );
        _advanceBots();
        _syncMyDuelState(answeredNow: true);
        if (_isMultiplayer) {
          _mpPhase = _MultiplayerPhase.waiting;
          _startOpponentWaitTimer();
        }
      });
      _revealCorrectAnswer();
      _checkMultiplayerSync();
      if (correct && streak == 10 && mounted) {
        context.read<SoundProvider>().playWin();
      }
    }
  }

  Future<void> _next() async {
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();
    if (isLastQuestion) {
      if (_isMultiplayer) {
        await _finishGameMultiplayer();
        return;
      }
      if (completing) return;
      setState(() => completing = true);
      widget.repository.finishGame(widget.room).catchError((error, stack) {
        ErrorReporter.record(error, stack, reason: 'quiz finish game failed');
      });
      _syncMyDuelState(answeredNow: true, finished: true);
      final coinsAwarded = await _claimCoins(
        score: score,
        correctCount: correctCount,
        bestStreak: bestStreak,
        totalQuestions: widget.questions.length,
      );
      if (!mounted) return;
      context.read<SoundProvider>().playWin();
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          QuizResultScreen(
            repository: widget.repository,
            room: _resultRoom,
            score: score,
            correctCount: correctCount,
            wrongCount: wrongCount,
            totalQuestions: widget.questions.length,
            bestStreak: bestStreak,
            answerRecords: answerRecords,
            coinsAwarded: coinsAwarded,
            rewardQueued: _rewardQueued,
            opponents: widget.is1v1 && widget.room.id != null
                ? _opponents.toList()
                : (_botRace?.toPlayers() ?? const []),
            practice: widget.practice,
            dailyQuiz: widget.dailyQuiz,
            contestId: widget.contestId,
          ),
        ),
        // Yarıda çıkıştan (null) ayırt etmek için tamamlanma sinyali.
        result: _completionResult(),
      );
      return;
    }

    _explanationController.stop();
    _explanationController.reset();
    // TTS: yeni soruya geçince önceki seslendirmeyi durdur.
    TtsService.instance?.stop();
    setState(() {
      index += 1;
      selectedAnswer = '';
      favorite = false;
      _favoriteTouched = false;
      completing = false;
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
      _showExplanation = false;
      _suspense = false;
      _opponentSelectedAnswers.clear();
      _answeredPlayerKeys.clear();
      // Multiplayer phase sıfırla
      _mpPhase = _MultiplayerPhase.answering;
      _revealCountdown = 0;
      _syncMyDuelState(answeredNow: false);
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
  }

  Map<String, dynamic> _completionResult() {
    final opponentScore = _opponents.fold<int>(
      0,
      (best, player) => max(best, player.score),
    );
    return {
      'completed': true,
      'score': score,
      'correct': correctCount,
      'opponentScore': opponentScore,
    };
  }

  void _recordAnswer(
    String answer, {
    required int responseMs,
    required int pointsEarned,
  }) {
    final existingIndex = answerRecords.indexWhere(
      (record) => record.id == question.id,
    );
    final record = AnswerRecord(
      id: question.id,
      category: question.category,
      prompt: question.promptText,
      answers: question.answers,
      correctAnswer: question.correctAnswer,
      selectedAnswer: answer,
      explanation: question.explanation,
      explanationKu: question.explanationKu,
      explanationTr: question.explanationTr,
      imageUrl: question.imageUrl,
      responseMs: responseMs,
      pointsEarned: pointsEarned,
    );

    if (existingIndex == -1) {
      answerRecords.add(record);
    } else {
      answerRecords[existingIndex] = record;
    }
  }

  Future<void> _toggleFavorite() async {
    final nextFavorite = !favorite;
    _favoriteTouched = true;
    setState(() => favorite = nextFavorite);
    try {
      final saved = await widget.repository.toggleFavoriteQuestion(
        question,
        nextFavorite,
      );
      if (!mounted) return;
      setState(() => favorite = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? context.t(K.questionSaved) : context.t(K.saveRemoved),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'toggleFavorite failed');
      if (!mounted) return;
      setState(() => favorite = !nextFavorite);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.questionSaveFailed))));
    }
  }

  Future<void> _reportQuestion() async {
    final controller = TextEditingController(
      text: context.t(K.reportReasonDefault),
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor(context)),
          ),
          title: Text(context.t(K.reportQuestion)),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.t(K.reasonLabel),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.t(K.cancel)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(context.t(K.sendAction)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null) return;

    try {
      await widget.repository.reportQuestion(question, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.reportSent))));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'reportQuestion failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.reportFailed))));
    }
  }
}
