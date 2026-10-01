import 'package:flutter/material.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../config/category_visuals.dart';
import '../services/placement_scoring.dart';
import '../theme/app_icons.dart';
import '../widgets/category_kicker_mark.dart';
import '../widgets/sahne/sahne.dart';
import 'quiz/quiz_option_tile.dart';
import 'quiz_screen.dart' show QuizQuestionImage;

/// Kısa, baskısız seviye belirleme sınavı.
///
/// Süre, skor, joker, coin veya yarışma baskısı yoktur; ses de yoktur.
/// Kullanıcı istediğinde "Şimdilik geç" diyebilir. Sonuç [PlacementStore]'a
/// sürümlü olarak yazılır ve öğrenme yolundaki önerilen başlangıç noktasını
/// belirler. Yarıda kapatılırsa hiçbir veri yazılmaz (bozulma olmaz).
///
/// ## Şahnê (2026-09-29)
///
/// Soru ekranıyla aynı C iskeleti (`SahneStageScaffold`, her zaman gece):
/// üst satırda kapat | ekranın adı | "Şimdilik geç"; altında ilerleme
/// çubuğu; gövdede üst etiket + soru (Başlık 28/32) + quiz'in şık
/// çubukları (`QuizOptionTile`). İlerleme bir ÇUBUKTUR, elmas dizisi değil:
/// sınav baskısızdır ve doğru/yanlış göstermez — elmasların ✓/✗'i cevabı
/// ele verirdi. Sonuç sahnede: seviye, puan, öneri ve tek birincil
/// "Başla".
class LevelPlacementScreen extends StatefulWidget {
  const LevelPlacementScreen({
    required this.repository,
    this.onFinished,
    this.questionCount = 12,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Sınav bittiğinde belirlenen seviye; "Şimdilik geç" ile null döner.
  final void Function(PlacementLevel? level)? onFinished;
  final int questionCount;

  @override
  State<LevelPlacementScreen> createState() => _LevelPlacementScreenState();
}

class _LevelPlacementScreenState extends State<LevelPlacementScreen> {
  late final List<QuizQuestion> _questions;
  final List<PlacementItem> _answers = [];
  int _index = 0;
  PlacementResult? _result;
  bool _inputLocked = false;

  @override
  void initState() {
    super.initState();
    _questions = PlacementScoring.selectQuestions(
      widget.repository.playableQuestions,
      count: widget.questionCount,
    );
  }

  @visibleForTesting
  QuizQuestion get currentQuestionForTest => _questions[_index];

  void _answer(QuizQuestion question, String choice) {
    if (_inputLocked || _result != null) return;
    _inputLocked = true;
    _answers.add(
      PlacementItem(
        difficulty: question.difficulty,
        correct: choice == question.correctAnswer,
      ),
    );
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }

    setState(() => _index++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _result != null) return;
      setState(() => _inputLocked = false);
    });
  }

  Future<void> _finish() async {
    try {
      final result = PlacementScoring.evaluate(
        _answers,
        totalQuestions: _questions.length,
      );
      final store = await PlacementStore.load();
      await store.saveResult(result.level);
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted && _result == null) {
        setState(() => _inputLocked = false);
      }
    }
  }

  Future<void> _skip() async {
    if (_inputLocked) return;
    setState(() => _inputLocked = true);
    try {
      final store = await PlacementStore.load();
      await store.markSkipped();
      widget.onFinished?.call(null);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _inputLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final result = _result;
    if (_questions.isNotEmpty && result != null) {
      return _buildResultScaffold(context, ku, result);
    }
    final skipLabel = context.t(K.placementSkip);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final useCompactSkip =
        MediaQuery.sizeOf(context).width < 380 || textScale > 1.05;
    final question = _questions.isNotEmpty
        ? _questions[_index].localized(isKu: ku)
        : null;

    return SahneStageScaffold(
      closeLabel: context.t(K.close),
      // 2026-09-29 doğallık (K2): soru arkasındaki hayalet kategori çizimi
      // kalktı; yalnız huzme ve ufuk kalır (bkz. quiz_screen `_stageLight`).
      light: question == null
          ? null
          : SahneCategoryLight.of(
              CategoryVisuals.canonicalName(question.category),
            ),
      ridge: true,
      center: Semantics(header: true, child: Text(context.t(K.placementTitle))),
      score: useCompactSkip
          ? _SkipIconButton(
              key: const ValueKey('placement-skip-compact'),
              label: skipLabel,
              onPressed: _inputLocked ? null : _skip,
            )
          : _SkipTextButton(
              key: const ValueKey('placement-skip'),
              label: skipLabel,
              onPressed: _inputLocked ? null : _skip,
            ),
      progress: question == null
          ? null
          : SahneProgressBar(
              value: (_index + 1) / _questions.length,
              semanticLabel: context.t(K.placementProgress, {
                'index': '${_index + 1}',
                'total': '${_questions.length}',
              }),
            ),
      body: Builder(
        builder: (context) => _questions.isEmpty
            ? _buildUnavailable(context)
            : _buildQuestion(context, question!),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    final t = SahneTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x6),
        child: Text(
          context.t(K.placementNoQuestions),
          textAlign: TextAlign.center,
          style: SahneType.body.copyWith(color: t.tx),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizQuestion question) {
    // Banka Kurmancî sabittir; `.localized` olmadan Türkçe turda da
    // Kurmancî soru/şık metni basılıyordu — quiz_screen.dart'ın 2026-07'de
    // kurduğu desenin aynısı burada eksikti (2026-08-14 denetimi).
    // Çevirisi eksik sorularda alanlar Kurmancî kalır (bkz. `answersFor`).
    final t = SahneTokens.of(context);
    final category = CategoryNames.localized(question.category, context.isKu);
    final progress = context.t(K.placementProgress, {
      'index': '${_index + 1}',
      'total': '${_questions.length}',
    });
    return SahneStageScroll(
      // Yeni soruda başa dön, üst kenar ilerleme çubuğunun altında sönsün
      // (bkz. `SahneStageScroll`).
      scrollKey: const ValueKey('placement-scroll'),
      resetKey: _index,
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x4,
        SahneSpace.page,
        SahneSpace.x6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst etiket (quiz'le aynı): kategori • soru sırası. İlerleme
              // metni ("SORU 1/12") ekranda kalır; çubuk görsel özettir.
              Row(
                children: [
                  CategoryKickerMark(
                    category: question.category,
                    fallbackColor: t.tx2,
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      '$category · $progress',
                      style: SahneType.eyebrow.copyWith(color: t.tx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SahneSpace.x2),
              if (question.hasImage) ...[
                QuizQuestionImage(
                  key: const ValueKey('placement-question-image'),
                  url: question.imageUrl!,
                  alt: question.imageAltFor(isKu: context.isKu),
                ),
                const SizedBox(height: SahneSpace.x3),
              ],
              QuizQuestionPrompt(question.prompt),
              const SizedBox(height: SahneSpace.x4),
              for (final (index, answer) in question.displayAnswers.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                  // Quiz'in şık çubuğu: harf karosu renksiz, cevaptan önce
                  // renk yok (bkz. `answer_option_color_semantics_test`).
                  // Sınav doğru/yanlış göstermez: çubuk yalnız dokunulur.
                  child: QuizOptionTile(
                    index: index,
                    answer: answer,
                    selected: false,
                    correct: false,
                    disabled: _inputLocked,
                    onTap: _inputLocked
                        ? null
                        : () => _answer(question, answer),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sonuç ortak şablondadır ([SahneResultScaffold], 2026-10-01 A6):
  /// seviye amblemi → "Seviyen" → seviye adı → "9/12 doğru" → öneri, alt
  /// perdede tek birincil "Başla". Ödül ve sayım karosu yok: sınav
  /// baskısızdır, jeton ya da XP vermez.
  Widget _buildResultScaffold(
    BuildContext context,
    bool ku,
    PlacementResult result,
  ) {
    final level = result.level;
    // Seviye bir öğrenme sonucudur (Zimrût); en üst seviye ödül (Zêr).
    final (icon, role) = switch (level) {
      PlacementLevel.destpek => (AppIcons.leaf, SahneRole.learn),
      PlacementLevel.navin => (AppIcons.arrowTrendUp, SahneRole.learn),
      PlacementLevel.pesketi => (AppIcons.medal, SahneRole.gold),
    };
    return SahneResultScaffold(
      closeLabel: context.t(K.close),
      contextLabel: context.t(K.placementTitle),
      hero: SahneResultHero(
        // Seviye rozeti: 56'lık pahlı kare, rolün ton zemini + rol ikonu.
        // 2026-09-29 doğallık (K5): eskiden elmastı; elmas yalnız soru
        // ilerlemesi ve ders sayacında kalır.
        emblem: Builder(
          // Sahne bağlamı (gece) için: ekranın kendi bağlamı gündüz olabilir.
          builder: (context) {
            final t = SahneTokens.of(context);
            return Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.roleTint(role),
                  shape: SahneShape.withSide(
                    SahneShape.forSize(56),
                    t.roleText(role),
                    width: SahneRing.r2,
                  ),
                ),
                child: SizedBox.square(
                  dimension: 56,
                  child: Icon(icon, color: t.roleText(role), size: 28),
                ),
              ),
            );
          },
        ),
        // K8: büyük harfli künye yalnız soru satırında; burada cümle düzeni.
        eyebrow: context.t(K.placementYourLevel),
        title: ku ? level.labelKu : level.labelTr,
        titleKey: const ValueKey('placement-result-level'),
        titleRole: role,
        caption: context.t(K.placementScore, {
          'correct': '${result.correctCount}',
          'total': '${result.totalCount}',
        }),
        body: _resultHint(ku, level),
      ),
      primary: SahneResultAction(
        key: const ValueKey('placement-continue'),
        label: context.t(K.start),
        onPressed: () {
          widget.onFinished?.call(result.level);
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  String _resultHint(bool ku, PlacementLevel level) {
    final key = switch (level) {
      PlacementLevel.destpek => K.placementAdviceBasic,
      PlacementLevel.navin => K.placementAdviceMid,
      PlacementLevel.pesketi => K.placementAdviceAdvanced,
    };
    return Tr.forKu(key, ku);
  }
}

/// "Şimdilik geç" — üst satırın sağında metin bağlantısı (Agir metni +
/// chevron). Görsel 44, dokunma kutusu 48 — bileşen verir.
class _SkipTextButton extends StatelessWidget {
  const _SkipTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      // Anahtarın düğümü (`placement-skip`) tek bir adlı düğmedir.
      Semantics(
        container: true,
        button: true,
        enabled: onPressed != null,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: SahneButton.text(label: label, onPressed: onPressed),
      );
}

/// Dar ekranda ya da büyük yazıda "Şimdilik geç": ileri ikonu, 44'lük
/// Şahnê ikon düğmesi (dokunma 48); söz Semantics'te ve ipucunda.
class _SkipIconButton extends StatelessWidget {
  const _SkipIconButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SahneIconButton(
    icon: AppIcons.forward,
    semanticLabel: label,
    onPressed: onPressed,
  );
}
