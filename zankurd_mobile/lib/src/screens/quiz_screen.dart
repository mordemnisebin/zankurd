import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import '../widgets/app_panel.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/player_avatar.dart';
import '../widgets/kilim_pattern_painter.dart';
import 'quiz/quiz_effects.dart';
import 'quiz_result_screen.dart';

part 'quiz/quiz_widgets.dart';

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
    this.contestId,
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

  /// Günlük etkinlik (contest) quiz'i — sonuçta skor + ödül RPC.
  final String? contestId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
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
  StreamSubscription? _roomSub;
  Timer? _pollTimer;

  QuizQuestion get question => _questions[index];
  bool get answered => selectedAnswer.isNotEmpty;
  bool get isLastQuestion => index == widget.questions.length - 1;
  bool get _isSoloMode => widget.room.id == null;

  /// Gerçek online multiplayer: 1v1 veya takım oyunu (bot değil).
  bool get _isMultiplayer => widget.room.id != null;

  @override
  void initState() {
    super.initState();
    _isKu = context.langProvider.isKu;
    _questions = List.of(widget.questions);
    _loadCoinBalance();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
    if (widget.enableTimer) {
      _timerController.addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          if (!answered) {
            _answer('TIMEOUT');
          }
        }
      });
      int lastTickSecond = 15;
      _timerController.addListener(() {
        if (_timerController.isAnimating) {
          final remaining = (_timerController.value * 15).ceil();
          if (remaining != lastTickSecond) {
            lastTickSecond = remaining;
            if (remaining > 0 && remaining <= 5) {
              HapticFeedback.lightImpact();
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
        _myId = livePlayers
            .firstWhere(
              (p) => p.name == name,
              orElse: () => const Player(name: '', score: 0, state: ''),
            )
            .id;
        _realtimeSub = widget.repository
            .subscribeRoomBroadcast(widget.room.id!)
            .listen((payload) {
              if (!mounted) return;
              final senderId = payload['sender_id'] as String?;
              final senderName = payload['sender'] as String?;
              final isSelf = _myId != null && senderId != null
                  ? senderId == _myId
                  : senderName == name;
              if (senderName != null && !isSelf) {
                setState(() {
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
                        ? (_isKu ? 'Bersiv da' : 'Cevapladı')
                        : (_isKu ? 'Li benda bersivê ye' : 'Cevap bekliyor'),
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

        if (!widget.is1v1) {
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
                        state: p.state,
                      );
                    } else {
                      livePlayers.add(p);
                    }
                  }
                  livePlayers.sort((a, b) => b.score.compareTo(a.score));
                });
              });
        }
      } else {
        if (widget.is1v1) {
          // Bot fallback 1v1 match
          final rng = Random();
          final botNames = const [
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
      _startTimer();
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
        .catchError((_) {});
  }

  void _startTimer() {
    _questionStopwatch
      ..reset()
      ..start();
    if (widget.enableTimer) {
      _timerController.stop();
      _timerController.value = 1.0;
      _timerController.reverse();
    }
  }

  void _loadCoinBalance() {
    widget.repository.loadCoinBalance().then((balance) {
      if (mounted) setState(() => _coinBalance = balance);
    });
  }

  List<Player> _composeBotRacePlayers() {
    final players = [
      Player(
        name: _isKu ? 'Tu' : 'Sen',
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
    _roomSub?.cancel();
    _pollTimer?.cancel();
    _timerController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  /// İlerleme varken geri tuşunda onay sorar; yanlışlıkla çıkışı önler.
  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.s('Ji pêşbirkê derkevî?', 'Yarıştan çıkılsın mı?')),
        content: Text(
          context.s(
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
          title: Text('${context.s('Ode', 'Oda')} ${widget.room.code}'),
          actions: [
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
            ),
            IconButton(
              onPressed: _reportQuestion,
              icon: const Icon(Icons.report_gmailerrorred_outlined),
            ),
          ],
        ),
        body: Container(
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
              if (widget.enableTimer && !answered)
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
            ],
          ),
        ),
      ),
    );
  }

  // ─── Portrait layout: sabit header, kaydırılabilir orta, sabit alt bar ──

  Widget _buildPortraitLayout() {
    // Multiplayer'da açıklama sadece reveal phase'de gösterilir.
    final showExpl = _isMultiplayer
        ? (_mpPhase == _MultiplayerPhase.reveal)
        : _showExplanation;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            // ── Üst sabit alan ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                children: [
                  _buildScoreHeader(),
                  const SizedBox(height: 12),
                  _buildProgressBar(context),
                  _buildComboRow(),
                ],
              ),
            ),

            // ── Orta kaydırılabilir içerik ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  children: [
                    _buildQuestionSwitcher(context, showExplanation: showExpl),
                    // Multiplayer bekleme/reveal overlay
                    if (_isMultiplayer &&
                        answered &&
                        _mpPhase == _MultiplayerPhase.waiting)
                      _MultiplayerWaitingOverlay(isKu: _isKu),
                    if (_isMultiplayer && _mpPhase == _MultiplayerPhase.reveal)
                      _RevealCountdown(seconds: _revealCountdown, isKu: _isKu),
                    if (widget.is1v1) ...[
                      const SizedBox(height: 12),
                      _LiveScoreboard(players: livePlayers),
                    ],
                  ],
                ),
              ),
            ),

            // ── Alt sabit aksiyon alanı ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: _buildActionControls(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Landscape layout: mevcut yapı korunuyor ────────────────────────────

  Widget _buildLandscapeLayout() {
    final showExpl = _isMultiplayer
        ? (_mpPhase == _MultiplayerPhase.reveal)
        : _showExplanation;

    return Row(
      key: const ValueKey('quiz-landscape-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 10, 18),
            children: [
              _buildQuestionSwitcher(context, showExplanation: showExpl),
              if (_isMultiplayer &&
                  answered &&
                  _mpPhase == _MultiplayerPhase.waiting)
                _MultiplayerWaitingOverlay(isKu: _isKu),
              if (_isMultiplayer && _mpPhase == _MultiplayerPhase.reveal)
                _RevealCountdown(seconds: _revealCountdown, isKu: _isKu),
              const SizedBox(height: 12),
              _buildProgressBar(context),
              _buildComboRow(),
              const SizedBox(height: 12),
              _buildScoreHeader(),
            ],
          ),
        ),
        SizedBox(
          width: 280,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 18),
            children: [
              _buildActionControls(),
              const SizedBox(height: 12),
              _LiveScoreboard(players: livePlayers),
            ],
          ),
        ),
      ],
    );
  }

  /// Combo rozeti + puan uçuşu satırı. Rozet yokken yükseklik kaplamaz.
  Widget _buildComboRow() {
    return Padding(
      padding: EdgeInsets.only(top: comboTierFor(streak) != null ? 10 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ComboBadge(streak: streak, isKu: _isKu),
          const SizedBox(width: 10),
          ScoreFlyup(trigger: _flyupTrigger, points: _lastPointsEarned),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    if (widget.is1v1) {
      final myName = widget.room.id != null ? _myName : (_isKu ? 'Tu' : 'Sen');
      final player = livePlayers.firstWhere(
        (p) => _myId != null ? p.id == _myId : p.name == myName,
        orElse: () => Player(
          id: _myId,
          name: myName,
          score: score,
          state: '',
          streak: streak,
        ),
      );
      final opponent = livePlayers.firstWhere(
        (p) => _myId != null ? p.id != _myId : p.name != myName,
        orElse: () =>
            Player(name: _isKu ? 'Hevrik' : 'Rakip', score: 0, state: ''),
      );
      return _DuelScoreHeader(
        player: player,
        opponent: opponent,
        progress: '${index + 1}/${widget.questions.length}',
      );
    }
    return _ScoreHeader(
      score: score,
      streak: streak,
      progress: '${index + 1}/${widget.questions.length}',
      coinBalance: _coinBalance,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (index + 1) / widget.questions.length),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => LinearProgressIndicator(
        value: value,
        minHeight: 6,
        borderRadius: BorderRadius.circular(99),
        backgroundColor: AppTheme.surfaceHiColor(context),
        color: AppTheme.accent,
      ),
    );
  }

  Widget _buildQuestionSwitcher(BuildContext context, {bool? showExplanation}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(index),
        child: _buildQuestionPanel(context, showExplanation: showExplanation),
      ),
    );
  }

  Widget _buildActionControls() {
    final bool showRatingBar =
        widget.practice &&
        answered &&
        selectedAnswer == question.correctAnswer &&
        !completing;

    // Multiplayer'da "Sonraki" butonu devre dışı: geçiş otomatik.
    final bool canPressNext = _isMultiplayer
        ? false
        : (answered && !completing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWildcardRow(),
        const SizedBox(height: AppSpacing.xs),
        showRatingBar
            ? Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(3),
                      child: Text(
                        context.s('Zor', 'Zor'),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(4),
                      child: Text(
                        context.s('Navîn', 'Orta'),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.correct,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(5),
                      child: Text(
                        context.s('Hêsan', 'Kolay'),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppRadius.md,
                    ), // AppRadius.lg
                  ),
                  elevation: 2,
                  shadowColor: AppTheme.accent.withValues(alpha: 0.3),
                ),
                onPressed: canPressNext ? () => _next() : null,
                icon: Icon(
                  _isMultiplayer
                      ? Icons.hourglass_top_rounded
                      : isLastQuestion
                      ? Icons.flag_outlined
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _isMultiplayer &&
                          answered &&
                          _mpPhase != _MultiplayerPhase.reveal
                      ? context.s('Li benda hevrik...', 'Rakip bekleniyor...')
                      : isLastQuestion
                      ? context.s('Qediya', 'Bitir')
                      : context.s('Piştre', 'Sonraki'),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ],
    );
  }

  // ─── Joker satırı ────────────────────────────────────────────────────────

  Widget _buildWildcardRow() {
    final jokers = [
      WildcardType.fiftyFifty,
      WildcardType.audience,
      WildcardType.doubleAnswer,
      if (_isSoloMode) WildcardType.changeQuestion,
    ];
    return Row(
      children: [
        for (var i = 0; i < jokers.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          Expanded(child: _buildWildcardButton(jokers[i])),
        ],
      ],
    );
  }

  Widget _buildWildcardButton(WildcardType type) {
    final used = _wildcard.isUsed(type);
    // doubleAnswer "kullanıldı" = aktive edildi: görsel olarak vurgulanır
    final isActive = type == WildcardType.doubleAnswer && used;
    final canAfford = _coinBalance >= type.coinCost;
    final isEnabled = !used && canAfford && !answered;

    return _WildcardButton(
      type: type,
      isKu: _isKu,
      isEnabled: isEnabled,
      isActive: isActive,
      cantAfford: !used && !canAfford && !answered,
      onTap: () => _onWildcardTap(type),
    );
  }

  void _onWildcardTap(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty => _useFiftyFifty(),
    WildcardType.audience => _useAudience(),
    WildcardType.doubleAnswer => _activateDoubleAnswer(),
    WildcardType.changeQuestion => _changeQuestion(),
  };

  // ─── Joker mekanikleri ───────────────────────────────────────────────────

  Future<void> _trackWildcardMission() async {
    final store = await DailyMissionStore.load();
    final completed = await store.reportWildcardUsed();
    if (completed == null || !mounted) return;

    await widget.repository.claimMissionReward(
      missionKey: completed.missionKey,
      fallbackReward: completed.coinReward,
    );

    final xpStore = await XPStore.load();
    final leveledUp = await xpStore.addXP(100);
    try {
      await widget.repository.updateProfileXP(xpStore.totalXP);
    } catch (_) {
      SyncManager.instance.queueXP(xpStore.totalXP);
    }

    if (!mounted) return;
    MissionToast.show(context, completed);
    if (leveledUp) {
      final isKu = context.isKu;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKu
                ? 'Asta Te Bilind Bû! Ast Nû: ${xpStore.currentLevel}'
                : 'Tebrikler, seviye atladın! Yeni Seviye: ${xpStore.currentLevel}',
          ),
          backgroundColor: AppTheme.secondaryAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _useFiftyFifty() {
    final cost = WildcardType.fiftyFifty.coinCost;
    if (_wildcard.fiftyFiftyUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(fiftyFiftyUsed: true);
      // Gizlenecek yanlışlar rastgele seçilir; hep ilk ikisi gizlenirse
      // dikkatli oyuncu örüntüyü ezberler.
      hiddenAnswers =
          (question.answers.where((a) => a != question.correctAnswer).toList()
                ..shuffle())
              .take(2)
              .toSet();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_fifty_fifty')
        .catchError((_) => false);
  }

  void _useAudience() {
    final cost = WildcardType.audience.coinCost;
    if (_wildcard.audienceUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_audience')
        .catchError((_) => false);
  }

  Map<String, double> _buildAudiencePoll() {
    final seed = question.id.codeUnits.fold<int>(0, (s, u) => s + u);
    final rng = Random(seed);

    // 50/50 aktifse sadece görünür şıkları kullan
    final visible = question.answers
        .where((a) => !hiddenAnswers.contains(a))
        .toList();
    final wrongs = visible.where((a) => a != question.correctAnswer).toList();

    // Doğru cevap %50-70 oy alır
    final correctShare = 0.50 + rng.nextDouble() * 0.20;
    var remaining = 1.0 - correctShare;

    final poll = <String, double>{};
    for (var i = 0; i < wrongs.length; i++) {
      if (i == wrongs.length - 1) {
        poll[wrongs[i]] = remaining < 0 ? 0.0 : remaining;
      } else {
        final share = remaining * (0.15 + rng.nextDouble() * 0.45);
        poll[wrongs[i]] = share;
        remaining -= share;
      }
    }
    poll[question.correctAnswer] = correctShare;
    return poll;
  }

  void _activateDoubleAnswer() {
    final cost = WildcardType.doubleAnswer.coinCost;
    if (_wildcard.doubleAnswerActivated ||
        _coinBalance < cost ||
        answered ||
        _firstAttemptAnswer.isNotEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(doubleAnswerActivated: true);
    });
    widget.repository
        .spendCoins(cost, 'wildcard_double_answer')
        .catchError((_) => false);
  }

  void _changeQuestion() {
    final cost = WildcardType.changeQuestion.coinCost;
    if (!_isSoloMode ||
        _wildcard.changeQuestionUsed ||
        _coinBalance < cost ||
        answered) {
      return;
    }

    final category = question.category;
    final difficulty = question.difficulty;
    final usedIds = _questions.map((q) => q.id).toSet();

    // Önce aynı kategori + zorlukta aday ara
    var candidates = widget.repository.questions
        .where(
          (q) =>
              q.category == category &&
              q.difficulty == difficulty &&
              !usedIds.contains(q.id),
        )
        .toList();

    // Yeterli yoksa aynı kategoride herhangi bir zorluk
    if (candidates.isEmpty) {
      candidates = widget.repository.questions
          .where((q) => q.category == category && !usedIds.contains(q.id))
          .toList();
    }

    if (candidates.isEmpty) return; // değiştirilecek soru bulunamadı

    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final replacement = candidates[Random().nextInt(candidates.length)];

    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      _questions[index] = replacement;
      hiddenAnswers = const {};
      _audiencePoll = null;
      favorite = false;
      _favoriteTouched = false;
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
    widget.repository
        .spendCoins(cost, 'wildcard_change_question')
        .catchError((_) => false);
  }

  // ─── Soru paneli ─────────────────────────────────────────────────────────

  Widget _buildQuestionPanel(BuildContext context, {bool? showExplanation}) {
    final promptText = question.promptText;
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.width >= 700 && size.width > size.height;
    final questionIcon = CategoryVisuals.icon(question.category);
    // Soru paneli kategori renk kimliğini taşır: hafif zemin tonu,
    // renkli kenarlık/parıltı ve kategori gradyanlı ikon rozeti.
    final catIndex = widget.repository.categories.indexOf(question.category);
    final catGradient = AppTheme.categoryGradient(catIndex >= 0 ? catIndex : 0);
    final catColor = catGradient.colors.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          catColor.withValues(alpha: 0.07),
          AppTheme.surfaceHiColor(context),
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: catColor.withValues(alpha: 0.30), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: KilimPatternPainter(
                  drawPattern: true,
                  color: catColor,
                  opacity: 0.05,
                ),
              ),
            ),
          ),
          Positioned(
            top: -18,
            right: -12,
            child: IgnorePointer(
              child: Icon(
                key: const ValueKey('quiz-question-ghost-icon'),
                questionIcon,
                size: compactLandscape ? 88 : 112,
                color: catColor.withValues(
                  alpha: AppTheme.isLight(context) ? 0.08 : 0.11,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuizQuestionIconBadge(
                          icon: questionIcon,
                          gradient: catGradient,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _TinyTag(
                            label: CategoryNames.localized(
                              question.category,
                              context.isKu,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _TinyTag(
                            label: question.typeLabelLocalized(context.isKu),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircularTimer(
                    key: const ValueKey('quiz-circular-timer'),
                    animation: _timerController,
                    maxSeconds: 15,
                    isPaused: answered,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (compactLandscape && question.hasImage)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 164,
                      child: _QuestionImage(url: question.imageUrl!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuestionTextAndAnswers(
                        promptText: promptText,
                        promptFontSize: 20,
                        question: question,
                        selectedAnswer: selectedAnswer,
                        answered: answered,
                        hiddenAnswers: hiddenAnswers,
                        firstAttemptAnswer: _firstAttemptAnswer,
                        audiencePoll: _audiencePoll,
                        showExplanation: showExplanation ?? _showExplanation,
                        suspense: _suspense,
                        opponentSelectedAnswers: _opponentSelectedAnswers,
                        onAnswer: _answer,
                      ),
                    ),
                  ],
                )
              else ...[
                if (question.hasImage) ...[
                  _QuestionImage(url: question.imageUrl!),
                  const SizedBox(height: 14),
                ],
                _QuestionTextAndAnswers(
                  promptText: promptText,
                  promptFontSize: compactLandscape ? 20 : 24,
                  question: question,
                  selectedAnswer: selectedAnswer,
                  answered: answered,
                  hiddenAnswers: hiddenAnswers,
                  firstAttemptAnswer: _firstAttemptAnswer,
                  audiencePoll: _audiencePoll,
                  showExplanation: showExplanation ?? _showExplanation,
                  suspense: _suspense,
                  opponentSelectedAnswers: _opponentSelectedAnswers,
                  onAnswer: _answer,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 1v1 çevrimiçi maçta kendi skor satırını tazeler ve rakibe yayınlar.
  /// Cevap verme, sonraki soru ve bitiş akışları bu tek bloğu paylaşır.
  void _syncMyDuelState({required bool answeredNow, bool finished = false}) {
    if (!widget.is1v1 || widget.room.id == null) return;
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
            ? (_isKu ? 'Bersiv da' : 'Cevapladı')
            : (_isKu ? 'Li benda bersivê ye' : 'Cevap bekliyor'),
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
        .catchError((_) {});
  }

  void _checkMultiplayerSync() {
    if (!_isMultiplayer) return;
    final myName = _myName;
    final otherPlayers = livePlayers
        .where((p) => _myId != null ? p.id != _myId : p.name != myName)
        .toList();
    if (otherPlayers.isEmpty) return;

    final allOthersAnswered = otherPlayers.every(
      (p) => p.state == 'Cevapladı' || p.state == 'Bersiv da',
    );

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
        }
      }
    });
  }

  bool get _isHost {
    final uid = widget.repository.currentUserId;
    return uid != null && uid == widget.room.hostId;
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
      _mpPhase = _MultiplayerPhase.answering;
      _revealCountdown = 0;
      _syncMyDuelState(answeredNow: false);
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
  }

  Future<void> _pollRoomIndex() async {
    if (!_isMultiplayer) return;
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
      } catch (_) {}
    }
  }

  Future<void> _advanceAuthoritativeIndex() async {
    final nextIndex = index + 1;
    if (widget.repository is SupabaseZanKurdRepository) {
      final client = (widget.repository as SupabaseZanKurdRepository).client;
      try {
        await client
            .from('rooms')
            .update({'current_question_index': nextIndex})
            .eq('id', widget.room.id!);
      } catch (e) {
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
      widget.repository.finishGame(widget.room).catchError((_) {});
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
              .catchError((_) => 0);

    if (!mounted) return;
    context.read<SoundProvider>().playWin();

    Navigator.of(context).pushReplacement(
      AppRoute.replace(
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
    );
  }

  Future<void> _answer(String answer) async {
    if (answered) return;

    _timerController.stop();

    // Multiplayer'da açıklama reveal phase'de gösterilir, hemen değil.
    if (!_isMultiplayer) {
      _explanationController.forward(from: 0);
    }

    // Çift Cevap aktifse ve ilk deneme yanlışsa: göster ama kilitleme
    if (_wildcard.doubleAnswerActivated &&
        _firstAttemptAnswer.isEmpty &&
        answer != question.correctAnswer) {
      HapticFeedback.heavyImpact();
      setState(() => _firstAttemptAnswer = answer);
      return;
    }

    // Optimistically select it to disable buttons immediately.
    // TIMEOUT dışında kısa bir "gerilim tutuşu" ile sonuç açıklanması
    // geciktirilir (TV-şovu ritmi); testte beklemeden geçilir.
    final isTimeout = answer == 'TIMEOUT';
    setState(() {
      selectedAnswer = answer;
      _suspense = !isTimeout;
    });
    if (!isTimeout && !isFlutterTestEnvironment) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;

    final optionKey = question.optionKeyForAnswer(answer);
    final responseMs = _questionStopwatch.elapsedMilliseconds;

    try {
      final result = await widget.repository.submitAnswer(
        room: widget.room,
        question: question,
        selectedOptionOptionKey: optionKey,
        responseMs: responseMs,
      );

      if (!mounted) return;

      if (result['is_correct'] == true) {
        HapticFeedback.lightImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.heavyImpact();
        context.read<SoundProvider>().playWrong();
      }

      final isCorrect = result['is_correct'] == true;
      _trackMistake(isCorrect);
      final oldScore = score;
      setState(() {
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
        _recordAnswer(answer);
        _advanceBots();
        _syncMyDuelState(answeredNow: true);
        // Multiplayer: bekleme fazına geç
        if (_isMultiplayer) _mpPhase = _MultiplayerPhase.waiting;
      });
      _checkMultiplayerSync();
      // Altın kademe anı: ×10 seriye özel kutlama sesi (yeni asset yok).
      if (isCorrect && streak == 10 && mounted) {
        context.read<SoundProvider>().playWin();
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'submitAnswer failed');
      // Fallback local logic if network fails during answer submit
      if (!mounted) return;
      final correct = answer == question.correctAnswer;
      _trackMistake(correct);
      if (correct) {
        HapticFeedback.lightImpact();
        context.read<SoundProvider>().playCorrect();
      } else {
        HapticFeedback.heavyImpact();
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
        _recordAnswer(answer);
        _advanceBots();
        _syncMyDuelState(answeredNow: true);
        if (_isMultiplayer) _mpPhase = _MultiplayerPhase.waiting;
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
    if (isLastQuestion) {
      if (completing) return;
      setState(() => completing = true);
      widget.repository.finishGame(widget.room).catchError((_) {});
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
                .catchError((_) => 0);
      if (!mounted) return;
      context.read<SoundProvider>().playWin();
      Navigator.of(context).pushReplacement(
        AppRoute.replace(
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
      );
      return;
    }

    _explanationController.stop();
    _explanationController.reset();
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
      // Multiplayer phase sıfırla
      _mpPhase = _MultiplayerPhase.answering;
      _revealCountdown = 0;
      _syncMyDuelState(answeredNow: false);
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
  }

  void _recordAnswer(String answer) {
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
          title: Text(context.s('Pirsê ragihîne', 'Soruyu bildir')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.s('Sedem', 'Neden'),
              border: OutlineInputBorder(),
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
