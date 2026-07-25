import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/avatar_presets.dart';
import '../config/category_visuals.dart';
import '../data/mistake_store.dart';
import '../data/sync_manager.dart';
import '../providers/sound_provider.dart';
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
import '../services/analytics_service.dart';
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
import 'package:zankurd_mobile/src/theme/app_icons.dart';

part 'quiz/quiz_widgets.dart';
part 'quiz/quiz_screen_ui.dart';

enum QuizExperience { learning, competition }

/// Multiplayer quiz turlarının ortak faz durumu.
enum _MultiplayerPhase {
  /// Oyuncular cevap veriyor.
  answering,

  /// Cevap verildi, diğer oyuncu bekleniyor.
  waiting,

  /// İki oyuncu da cevapladı veya süre bitti; doğru cevap gösteriliyor.
  reveal,
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

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  bool get _isLearningExperience =>
      widget.experience == QuizExperience.learning;
  bool get _usesTimer => widget.enableTimer && !_isLearningExperience;

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
  final Map<String, String> _opponentSelectedAnswers = {};
  final Set<String> _answeredPlayerNames = {};
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
  Timer? _authoritativeAdvanceFallbackTimer;
  bool _opponentFinished = false;
  StreamSubscription? _roomSub;
  Timer? _pollTimer;
  bool _questionFlowStarted = false;

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
  bool get _needsOpponentReadyGate => widget.is1v1 && _isMultiplayer;

  // Quiz tutorial coach mark hedef anahtarları
  final GlobalKey _timerTargetKey = GlobalKey();
  final GlobalKey _answerAreaKey = GlobalKey();
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
      _isMultiplayer && widget.repository is SupabaseZanKurdRepository;

  @override
  void initState() {
    super.initState();
    _isKu = context.langProvider.isKu;
    _questions = List.of(widget.questions);
    _questionVisualReady = _questions.isEmpty || !_questions.first.hasImage;
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
      value: 1.0,
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
            _answer('TIMEOUT');
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
        livePlayers = List.of(widget.room.players);
        // Kimlik önce oturum kullanıcı kimliğinden çözülür. Görünen ad
        // benzersiz değildir: aynı adı seçen iki oyuncu olduğunda ada göre
        // eşleştirme skoru ve "hazır" sinyalini rakibe atıyordu. Ad yalnızca
        // kimlik yoksa (eski oda kayıtları) yedek olarak kullanılır.
        final sessionUserId = widget.repository.currentUserId;
        final matchById = sessionUserId == null
            ? null
            : livePlayers.where((p) => p.id == sessionUserId).firstOrNull;
        _myId =
            matchById?.id ??
            livePlayers.where((p) => p.name == name).firstOrNull?.id;
        _realtimeSub = widget.repository
            .subscribeRoomBroadcast(widget.room.id!)
            .listen((payload) {
              if (!mounted) return;
              final senderId = payload['sender_id'] as String?;
              final senderName = payload['sender'] as String?;
              final isSelf = _myId != null && senderId != null
                  ? senderId == _myId
                  : senderName == name;
              if (senderName != null && !isSelf && payload['ready'] == true) {
                _handleOpponentReady();
                return;
              }
              if (senderName != null && !isSelf) {
                if (payload['advance_request'] == true && _isHost) {
                  _advanceAuthoritativeIndex();
                  return;
                }
                setState(() {
                  if (payload['finished'] == true) {
                    _opponentFinished = true;
                    _answeredPlayerNames.add(senderName);
                  }
                  if (payload['answered'] == true) {
                    _answeredPlayerNames.add(senderName);
                  } else if (payload['answered'] == false) {
                    _answeredPlayerNames.remove(senderName);
                  }

                  final opponentIdx = livePlayers.indexWhere(
                    (p) => senderId != null
                        ? p.id == senderId
                        : p.name == senderName,
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
                        ? QuizStrings.answered(_isKu)
                        : QuizStrings.waiting(_isKu),
                  );
                  if (opponentIdx != -1) {
                    livePlayers[opponentIdx] = updatedOpponent;
                  } else {
                    livePlayers.add(updatedOpponent);
                  }
                  livePlayers.sort((a, b) => b.score.compareTo(a.score));

                  final oppAnswer = payload['selected_answer'] as String?;
                  if (oppAnswer != null) {
                    _opponentSelectedAnswers[senderName] = oppAnswer;
                  } else if (payload['answered'] == false) {
                    _opponentSelectedAnswers.remove(senderName);
                  }

                  final oppIndex = payload['question_index'] as int?;
                  if (oppIndex != null && oppIndex > index) {
                    _syncToQuestionIndex(oppIndex);
                  }
                });
                _checkMultiplayerSync();
              }
            });

        if (widget.is1v1) {
          _startOpponentReadyHandshake();
        } else {
          _playersSub = widget.repository
              .subscribeRoomPlayers(widget.room)
              .listen((players) {
                if (!mounted) return;
                setState(() {
                  for (final p in players) {
                    final idx = livePlayers.indexWhere(
                      (lp) => lp.name == p.name,
                    );
                    if (idx != -1) {
                      livePlayers[idx] = livePlayers[idx].copyWith(
                        score: p.score,
                        streak: p.streak,
                        state: _answeredPlayerNames.contains(p.name)
                            ? QuizStrings.answered(_isKu)
                            : QuizStrings.waiting(_isKu),
                      );
                    } else {
                      livePlayers.add(
                        p.copyWith(
                          state: _answeredPlayerNames.contains(p.name)
                              ? QuizStrings.answered(_isKu)
                              : QuizStrings.waiting(_isKu),
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
          const botNames = [
            'Rojda',
            'Baran',
            'Dilan',
            'Hogir',
            'Azad',
            'Berfin',
            'Narin',
            'Sero',
            'Çiçek',
            'Welat',
          ];
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
                final dbIndex =
                    rows.first['current_question_index'] as int? ?? 0;
                _onRoomQuestionIndexChanged(dbIndex);
              }
            });
      }
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _pollRoomIndex();
      });
    }
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
    _questionStopwatch
      ..reset()
      ..start();
    if (_usesTimer) {
      _timerController.stop();
      _timerController.value = 1.0;
      _timerController.reverse();
    }
  }

  void _startQuestionFlowOnce() {
    if (_questionFlowStarted || _questions.isEmpty) return;
    _questionFlowStarted = true;
    _startTimer();
  }

  /// Tutorial coach-mark'ı kapandı/atlandı — solo modda soru akışı hemen
  /// başlar, 1v1 online'da ise karşı tarafın da hazır olması beklenir.
  void _handleTutorialReady() {
    _tutorialGateReady = true;
    _maybeStartQuestionFlow();
    // Tutorial açıkken oda index senkronu sayacı ertelediyse şimdi başlat.
    if (_timerDeferredForTutorial) {
      _timerDeferredForTutorial = false;
      if (!answered) _startTimer();
    }
  }

  void _maybeStartQuestionFlow() {
    if (!_tutorialGateReady) return;
    if (_needsOpponentReadyGate && !_opponentClientReady) return;
    if (!_questionVisualReady) return;
    _startQuestionFlowOnce();
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
        name: QuizStrings.you(_isKu),
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
    _playersSub?.cancel();
    _realtimeSub?.cancel();
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();
    _opponentWaitTimer?.cancel();
    _authoritativeAdvanceFallbackTimer?.cancel();
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
              ? context.s('Ji dersê derkevî?', 'Dersten çıkılsın mı?')
              : context.s('Ji pêşbirkê derkevî?', 'Yarıştan çıkılsın mı?'),
        ),
        content: Text(
          _isLearningExperience
              ? context.s(
                  'Pêşketina te ya vê dersê winda dibe.',
                  'Bu dersteki ilerlemen kaybolur.',
                )
              : context.s(
                  'Pêşketina te ya vê pêşbirkê winda dibe.',
                  'Bu yarıştaki ilerlemen kaybolur.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.s('Bidomîne', 'Devam Et')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.s('Derkeve', 'Çık')),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                context.s(
                  'Pirs nehatin barkirin. Ji kerema xwe dîsa biceribîne.',
                  'Sorular yüklenemedi. Lütfen tekrar dene.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final hasProgress = index > 0 || answered;
    return PopScope(
      canPop: !hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          // Solo/bot oyunda oda kodu anlamsız gürültü; kategori adı göster.
          title: Text(
            widget.room.id == null
                ? (widget.room.category.isEmpty
                      ? context.s('Pêşbirk', 'Yarışma')
                      : CategoryNames.localized(
                          widget.room.category,
                          context.isKu,
                        ))
                : '${context.s('Ode', 'Oda')} ${widget.room.code}',
          ),
          actions: [
            IconButton(
              onPressed: _toggleFavorite,
              tooltip: context.s('Tomar bike', 'Kaydet'),
              icon: Icon(favorite ? AppIcons.bookmark : AppIcons.bookmark),
            ),
            IconButton(
              onPressed: _reportQuestion,
              tooltip: context.s('Raporte bike', 'Bildir'),
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
                            final landscape = constraints.maxWidth >= 700;
                            if (landscape) {
                              return _buildLandscapeLayout();
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
                      if (_needsOpponentReadyGate &&
                          !_opponentClientReady &&
                          !_questionFlowStarted)
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
    final myIdx = livePlayers.indexWhere(
      (p) => _myId != null ? p.id == _myId : p.name == _myName,
    );
    if (myIdx != -1) {
      livePlayers[myIdx] = Player(
        id: _myId,
        name: _myName,
        score: score,
        streak: streak,
        state: answeredNow
            ? QuizStrings.answered(_isKu)
            : QuizStrings.waiting(_isKu),
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
    final myName = _myName;
    final otherPlayers = livePlayers
        .where((p) => _myId != null ? p.id != _myId : p.name != myName)
        .toList();
    if (otherPlayers.isEmpty) return;

    final allOthersAnswered =
        _opponentFinished ||
        otherPlayers.every((p) => _answeredPlayerNames.contains(p.name));

    if (answered && allOthersAnswered && _mpPhase != _MultiplayerPhase.reveal) {
      _startRevealPhase();
    }
  }

  /// Multiplayer reveal phase: doğru cevap ve açıklama gösterilir.
  /// [_revealCountdown] saniye sonra otomatik olarak sonraki soruya geçilir.
  void _startRevealPhase() {
    _autoNextTimer?.cancel();
    _revealTimer?.cancel();
    _revealTickTimer?.cancel();

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

    // Reveal süresi bitince host olan taraf index'i DB'de artırır.
    _revealTimer = Timer(const Duration(seconds: revealDuration), () {
      _revealTickTimer?.cancel();
      if (mounted) {
        if (_isHost) {
          _advanceAuthoritativeIndex();
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
    _opponentWaitTimer = Timer(
      Duration(seconds: max(20, widget.room.secondsPerQuestion)),
      () {
        if (!mounted || !answered || _mpPhase != _MultiplayerPhase.waiting) {
          return;
        }
        for (final player in livePlayers) {
          final isMe = _myId != null
              ? player.id == _myId
              : player.name == _myName;
          if (!isMe) _answeredPlayerNames.add(player.name);
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
    _authoritativeAdvanceFallbackTimer?.cancel();
    _authoritativeAdvanceFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _isHost || _mpPhase != _MultiplayerPhase.reveal) return;
      _next();
    });
    _advanceAuthoritativeIndex();
  }

  bool get _isHost {
    final uid = widget.repository.currentUserId;
    if (uid == null) return false;
    if (widget.room.hostId != null) return uid == widget.room.hostId;
    return widget.room.players.isNotEmpty &&
        widget.room.players.first.id == uid;
  }

  void _onRoomQuestionIndexChanged(int dbIndex) {
    if (!_isMultiplayer) return;
    if (dbIndex > index) {
      _syncToQuestionIndex(dbIndex);
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
      _answeredPlayerNames.clear();
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
    if (!_isMultiplayer) return;
    if (widget.room.id == null) return;
    if (widget.repository is SupabaseZanKurdRepository) {
      final client = (widget.repository as SupabaseZanKurdRepository).client;
      try {
        final row = await client
            .from('rooms')
            .select('current_question_index')
            .eq('id', widget.room.id!)
            .single();
        final dbIndex = row['current_question_index'] as int? ?? 0;
        if (mounted && dbIndex > index) {
          _onRoomQuestionIndexChanged(dbIndex);
        }
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'quiz room index poll failed',
        );
      }
    }
  }

  Future<void> _advanceAuthoritativeIndex() async {
    if (!_isHost) return;
    final nextIndex = index + 1;
    if (widget.repository is SupabaseZanKurdRepository) {
      final client = (widget.repository as SupabaseZanKurdRepository).client;
      try {
        await client
            .from('rooms')
            .update({'current_question_index': nextIndex})
            .eq('id', widget.room.id!);
      } catch (e, s) {
        ErrorReporter.record(e, s, reason: 'QuizScreen room sync failed');
        // Fallback
        _next();
      }
    } else {
      _next();
    }
  }

  Future<void> _finishGameMultiplayer() async {
    if (completing) return;
    setState(() => completing = true);

    if (_isHost) {
      widget.repository.finishGame(widget.room).catchError((error, stack) {
        ErrorReporter.record(error, stack, reason: 'quiz finish game failed');
      });
    }

    _syncMyDuelState(answeredNow: true, finished: true);

    final coinsAwarded = widget.practice
        ? 0
        : await widget.repository
              .awardQuizCoins(
                score: score,
                correctCount: correctCount,
                bestStreak: bestStreak,
                totalQuestions: widget.questions.length,
                room: widget.room,
              )
              .catchError((error, stack) {
                ErrorReporter.record(
                  error,
                  stack,
                  reason: 'awardQuizCoins solo failed',
                );
                return 0;
              });

    if (!mounted) return;
    context.read<SoundProvider>().playWin();

    // result: quiz rotası değiştirilirken çağıranın await'ine "tamamlandı"
    // sinyali taşır (yarıda çıkışta null döner — bkz. level_screen).
    Navigator.of(context).pushReplacement(
      AppRoute.to(
        QuizResultScreen(
          repository: widget.repository,
          room: widget.room,
          score: score,
          correctCount: correctCount,
          wrongCount: wrongCount,
          totalQuestions: widget.questions.length,
          bestStreak: bestStreak,
          answerRecords: answerRecords,
          coinsAwarded: coinsAwarded,
          opponents: livePlayers.where((p) => p.name != _myName).toList(),
          practice: widget.practice,
          dailyQuiz: widget.dailyQuiz,
          contestId: widget.contestId,
        ),
      ),
      result: _completionResult(),
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
      _suspense = !isTimeout;
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
          _suspense = false;
        });
        _timerController.forward();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isKu
                  ? 'Bersiv nehat şandin. Ji kerema xwe dîsa biceribîne.'
                  : 'Cevap gönderilemedi. Lütfen yeniden deneyin.',
            ),
          ),
        );
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
      if (completing) return;
      setState(() => completing = true);
      widget.repository.finishGame(widget.room).catchError((error, stack) {
        ErrorReporter.record(error, stack, reason: 'quiz finish game failed');
      });
      _syncMyDuelState(answeredNow: true, finished: true);
      final coinsAwarded = widget.practice
          ? 0
          : await widget.repository
                .awardQuizCoins(
                  score: score,
                  correctCount: correctCount,
                  bestStreak: bestStreak,
                  totalQuestions: widget.questions.length,
                  room: widget.room,
                )
                .catchError((error, stack) {
                  ErrorReporter.record(
                    error,
                    stack,
                    reason: 'awardQuizCoins multiplayer failed',
                  );
                  return 0;
                });
      if (!mounted) return;
      context.read<SoundProvider>().playWin();
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          QuizResultScreen(
            repository: widget.repository,
            room: widget.room,
            score: score,
            correctCount: correctCount,
            wrongCount: wrongCount,
            totalQuestions: widget.questions.length,
            bestStreak: bestStreak,
            answerRecords: answerRecords,
            coinsAwarded: coinsAwarded,
            opponents: widget.is1v1 && widget.room.id != null
                ? livePlayers.where((p) => p.name != _myName).toList()
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
      _answeredPlayerNames.clear();
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
    final opponentScore = livePlayers
        .where((player) => player.name != _myName)
        .fold<int>(0, (best, player) => max(best, player.score));
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
            saved
                ? context.s('Pirs hat tomarkirin.', 'Soru kaydedildi.')
                : context.s('Tomar hate rakirin.', 'Kayıt kaldırıldı.'),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'toggleFavorite failed');
      if (!mounted) return;
      setState(() => favorite = !nextFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Pirs nehate tomarkirin.', 'Soru kaydedilemedi.'),
          ),
        ),
      );
    }
  }

  Future<void> _reportQuestion() async {
    final controller = TextEditingController(
      text: context.s('Şaşiya bersiv an naverokê', 'Cevap veya içerik hatası'),
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
          title: Text(context.s('Pirsê ragihîne', 'Soruyu bildir')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.s('Sedem', 'Neden'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.s('Betal bike', 'Vazgeç')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(context.s('Bişîne', 'Gönder')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Rapor hat şandin.', 'Soru raporu gönderildi.'),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'reportQuestion failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('Rapor nehat şandin.', 'Rapor gönderilemedi.'),
          ),
        ),
      );
    }
  }
}
