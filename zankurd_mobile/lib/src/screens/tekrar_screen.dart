import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'package:flutter/material.dart';

import '../data/mistake_store.dart';
import '../data/tekrar_plani.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'learner_lexicon_screen.dart';
import 'quiz_screen.dart';
import 'word_drill_screen.dart';

/// Tek "Tekrar" oturumu: bugün vadesi gelen kelimeler (Leitner) ve yanlış
/// defterindeki hazır sorular (iki oturumlu mezuniyet), en çok 12 öğe.
///
/// ## Akış
///
/// Önce kelimeler ([WordDrillScreen], kendi kartı ve kutu kuralı), sonra
/// sorular ([QuizScreen], öğrenme deneyimi, kendi mezuniyet kuralı). İki
/// aşama da kendi depolarına kendi kuralıyla yazar; bu ekran yalnız hangi
/// öğelerin hangi sırayla geleceğini ([TekrarPlan]) ve geçişi yönetir.
/// Sorular aşamasında bu ekranın yerine quiz konur (pushReplacement), bu
/// yüzden girişi açan kart, oturum bitince tek dönüşte tazelenir.
///
/// Hiçbir şey vadesi gelmemişse "Bugün tekrar yok" ve bir öneri gösterilir.
class TekrarScreen extends StatefulWidget {
  const TekrarScreen({
    required this.repository,
    required this.isKu,
    this.wordStore,
    this.mistakeStore,
    super.key,
  });

  final ZanKurdRepository repository;
  final bool isKu;

  /// Testlerde verilir; yoksa kullanıcının paylaşılan listesi.
  final WordListStore? wordStore;

  /// Testlerde verilir; yoksa paylaşılan yanlış defteri.
  final MistakeStore? mistakeStore;

  @override
  State<TekrarScreen> createState() => _TekrarScreenState();
}

/// Soru aşamasının rotası: yalnız hazır sorularla, sayaç/skor/joker olmayan
/// öğrenme deneyimi. Tek konuysa başlıkta o konu, değilse Karışık.
Route<void> tekrarQuestionRoute({
  required ZanKurdRepository repository,
  required bool isKu,
  required List<QuizQuestion> questions,
}) {
  final room = repository.createRoom().copyWith(
    name: Tr.forKu(K.tekrarTitle, isKu),
    questionCount: questions.length,
    category: reviewRoomCategory(questions),
  );
  return AppRoute.to<void>(
    QuizScreen(
      repository: repository,
      room: room,
      questions: questions,
      practice: true,
      enableTimer: false,
      experience: QuizExperience.learning,
    ),
  );
}

class _TekrarScreenState extends State<TekrarScreen> {
  WordListStore? _wordStore;
  TekrarPlan? _plan;
  bool _loading = true;

  /// 2026-10-28 kod denetimi: yükleme hatası "Bugün tekrar yok" diye
  /// gösteriliyordu; oyuncu tekrarı bittiğini sanıyordu.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loadFailed) setState(() => _loadFailed = false);
    try {
      final words = widget.wordStore ?? await WordListStore.load();
      final mistakes = widget.mistakeStore ?? await MistakeStore.load();
      final plan = TekrarPlan.build(
        wordStore: words,
        mistakeStore: mistakes,
        playable: widget.repository.playableQuestions,
      );
      if (!mounted) return;
      // Kelime yoksa kelime aşaması boş ekran olurdu: doğrudan sorulara.
      if (plan.words.isEmpty && plan.questions.isNotEmpty) {
        // Bu ekranın kendi giriş geçişi sürerken rota değiştirmek navigatörü
        // kilitli yakalıyordu: bir sonraki kareye bırak.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(_questionRoute(plan));
        });
        setState(() => _loading = true);
        return;
      }
      setState(() {
        _wordStore = words;
        _plan = plan;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tekrar_screen_load');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Route<void> _questionRoute(TekrarPlan plan) => tekrarQuestionRoute(
    repository: widget.repository,
    isKu: widget.isKu,
    questions: plan.questions,
  );

  void _toQuestions() {
    final plan = _plan;
    if (plan == null || plan.questions.isEmpty) return;
    Navigator.of(context).pushReplacement(_questionRoute(plan));
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final plan = _plan;
    if (_loading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: zkAppBar(context, title: Text(context.t(K.tekrarTitle))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: zkAppBar(context, title: Text(context.t(K.tekrarTitle))),
        body: SafeArea(
          top: false,
          child: AppErrorState(
            key: const ValueKey('tekrar-load-error'),
            title: context.t(K.loadFailedShort),
            message: context.t(K.genericErrorBody),
            retryLabel: context.t(K.retryShort),
            onRetry: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ),
      );
    }
    if (plan == null || plan.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: zkAppBar(context, title: Text(context.t(K.tekrarTitle))),
        body: SafeArea(
          top: false,
          child: AppEmptyState(
            key: const ValueKey('tekrar-empty'),
            icon: AppIcons.circleCheck,
            title: context.t(K.tekrarNone),
            message: context.t(K.tekrarNoneHint),
            actionLabel: context.t(K.tekrarOpenLexicon),
            actionIcon: AppIcons.magnifyingGlass,
            primaryAction: false,
            onAction: () => Navigator.of(
              context,
            ).push(AppRoute.to(const LearnerLexiconScreen())),
          ),
        ),
      );
    }
    final hasQuestions = plan.questions.isNotEmpty;
    return WordDrillScreen(
      store: _wordStore,
      words: plan.words,
      onDone: hasQuestions ? _toQuestions : null,
      doneLabel: hasQuestions
          ? context.t(K.tekrarToQuestions, {
              'count': groupThousands(plan.questions.length),
            })
          : null,
    );
  }
}
