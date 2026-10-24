import 'package:flutter/material.dart';

import '../data/mistake_store.dart';
import '../data/tekrar_plani.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../screens/tekrar_screen.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'sahne/sahne.dart';

export '../data/tekrar_plani.dart' show reviewRoomCategory;

/// Bir tekrar oturumunun en çok öğe sayısı (kelime + soru birlikte).
const int kReviewSessionCap = kTekrarSessionCap;

/// Tek "Tekrar · bugün N" girişi — kelime (Leitner) ve yanlış sorusu
/// (SM-2) tekrarının ortak ürün yüzü.
///
/// N, bugün vadesi gelen kelimelerle açılabilir hazır soruların toplamıdır
/// ([TekrarPlan.dueTotal]). Hazır öğe varsa dokunulabilir bir kart, yoksa
/// "Bugün tekrar yok" + öneri gösterir. Karta dokununca [TekrarScreen]
/// açılır: önce kelimeler, sonra sorular.
///
/// Eskiden üç ayrı giriş vardı ("Kelimelerim" içindeki tekrar kartı, bu
/// kartın yalnız soru sayan hâli, kart modları); kullanıcı hangisini
/// kullanacağını ayıramıyordu (2026-10-24).
class TodaysReviewCard extends StatefulWidget {
  const TodaysReviewCard({
    required this.repository,
    required this.isKu,
    this.onStartReview,
    this.onStartPlan,
    this.wordStore,
    this.mistakeStore,
    this.refreshSignal,
    this.hideWhenEmpty = false,
    super.key,
  });

  final ZanKurdRepository repository;
  final bool isKu;

  /// Hazır tekrar yokken hiçbir şey çizme.
  ///
  /// Öğrenme ekranı hiç ders çözmemiş birine "Tekrarlar tamam" diyordu —
  /// yapılmamış bir işin bittiğini söyleyen bir satır. Orada kart yalnız
  /// gerçekten tekrar bekliyorsa görünür.
  final bool hideWhenEmpty;

  /// Test/özelleştirme için: verilirse oturum açmak yerine bu çağrılır
  /// (yalnız plandaki sorularla).
  final void Function(List<QuizQuestion> questions)? onStartReview;

  /// [onStartReview]'in kelimeleri de gören hâli: planın tamamı.
  final void Function(TekrarPlan plan)? onStartPlan;

  /// Testlerde verilir; yoksa paylaşılan depolar.
  final WordListStore? wordStore;
  final MistakeStore? mistakeStore;

  /// Sekme yeniden seçildiğinde hazır sayısını tazelemek için.
  final Listenable? refreshSignal;

  @override
  State<TodaysReviewCard> createState() => _TodaysReviewCardState();
}

class _TodaysReviewCardState extends State<TodaysReviewCard> {
  TekrarPlan? _plan;
  bool _loading = true;
  bool _starting = false;
  int _refreshGeneration = 0;

  int get _readyCount => _plan?.dueTotal ?? 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.refreshSignal?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant TodaysReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_refresh);
    super.dispose();
  }

  /// Planı iki depodan kurar. Sayı ile eylem aynı listeden beslenir: kart
  /// neyi vaat ediyorsa dokunuş onu açar.
  ///
  /// ## Soru tarafı kusurları (kural korunur)
  ///
  /// * 2026-08-06: çevrimiçi maç yanlışları veritabanı UUID'siyle kaydedilir,
  ///   paketli bankanın kimliği `offline_0005` biçimindedir; çözümlenemeyen
  ///   kimlik sayılırsa kart sıfırdan büyük sayı gösterip dokunuşta hiçbir
  ///   şey yapmıyordu. Yalnız çözümlenen sorular sayılır.
  /// * 2026-10-15: kaynak `playableQuestions` olmalı (karantinadaki soru
  ///   sayılmaz) ve oturum en gecikenden başlayıp sınırlıdır.
  Future<TekrarPlan> _buildPlan() async {
    final words = widget.wordStore ?? await WordListStore.load();
    final mistakes = widget.mistakeStore ?? await MistakeStore.load();
    return TekrarPlan.build(
      wordStore: words,
      mistakeStore: mistakes,
      playable: widget.repository.playableQuestions,
    );
  }

  Future<void> _refresh() async {
    final generation = ++_refreshGeneration;
    try {
      final plan = await _buildPlan();
      if (mounted && generation == _refreshGeneration) {
        setState(() {
          _plan = plan;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'todays_review_card');
      if (mounted && generation == _refreshGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startReview() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final plan = await _buildPlan();
      if (!mounted) return;
      if (plan.isEmpty) {
        await _refresh();
        return;
      }

      final onPlan = widget.onStartPlan;
      final onStart = widget.onStartReview;
      if (onPlan != null || onStart != null) {
        onPlan?.call(plan);
        onStart?.call(plan.questions);
        return;
      }

      await Navigator.of(context).push(
        AppRoute.to(
          TekrarScreen(
            repository: widget.repository,
            isKu: widget.isKu,
            wordStore: widget.wordStore,
            mistakeStore: widget.mistakeStore,
          ),
        ),
      );
      if (mounted) await _refresh();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'todays_review_start');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Tr.forKu(K.quizLoadFail, widget.isKu))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_readyCount == 0 && widget.hideWhenEmpty) {
      return const SizedBox.shrink();
    }
    final ku = widget.isKu;
    return _readyCount > 0
        ? _buildReady(context, ku)
        : _buildEmpty(context, ku);
  }

  /// "4 kelime · 3 soru"; tek tür varsa yalnız o ("3 soru", "4 kelime").
  String _breakdown(bool ku) {
    final plan = _plan!;
    if (plan.dueWords > 0 && plan.dueQuestions > 0) {
      return Tr.forKu(K.tekrarBreakdown, ku, {
        'words': '${plan.dueWords}',
        'questions': '${plan.dueQuestions}',
      });
    }
    return plan.dueWords > 0
        ? Tr.forKu(K.wordsCount, ku, {'count': '${plan.dueWords}'})
        : Tr.forKu(K.tekrarQuestionsOnly, ku, {
            'count': '${plan.dueQuestions}',
          });
  }

  // 2026-09-29 Şahnê: öğrenme rolünün satırı — 36'lık M karo (Zimrût tonu
  // + Zimrût metni ikon), üst satır kalın açıklama Zimrût metni, alt satır
  // Gövde 700; chevron üçüncül.
  //
  // 2026-09-29 doğallık (K7): sağda sayıyı ikinci kez yazan rozet vardı;
  // sayı yalnız cümlede kalır. 2026-10-24: üst satır "Tekrar · bugün N",
  // alt satır kelime/soru dökümü.
  Widget _tile(SahneTokens t, IconData icon) => DecoratedBox(
    decoration: ShapeDecoration(color: t.learnTint, shape: SahneShape.m),
    child: SizedBox.square(
      dimension: 36,
      child: Icon(icon, color: t.learnTx, size: 20),
    ),
  );

  Widget _buildReady(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    final line = Tr.forKu(K.tekrarTodayLine, ku, {'count': '$_readyCount'});
    final breakdown = _breakdown(ku);
    final semanticLabel = [
      line,
      breakdown,
      Tr.forKu(K.strengthenMemory, ku),
    ].join('. ');
    return Semantics(
      key: const ValueKey('todays-review-card'),
      container: true,
      button: true,
      enabled: !_starting,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: _starting ? null : _startReview,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _starting ? null : _startReview,
          excludeFromSemantics: true,
          customBorder: SahneShape.m,
          child: Padding(
            key: const ValueKey('todays-review-status-row'),
            padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  _tile(t, AppIcons.arrowsRotate),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.captionStrong.copyWith(
                            color: t.learnTx,
                          ),
                        ),
                        Text(
                          breakdown,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.bodyStrong.copyWith(color: t.tx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    final title = Tr.forKu(K.tekrarNone, ku);
    final detail = Tr.forKu(K.tekrarNoneHint, ku);
    return Semantics(
      key: const ValueKey('todays-review-empty'),
      label: '$title. $detail',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('todays-review-status-row'),
        padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              _tile(t, AppIcons.circleCheck),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.body.copyWith(color: t.tx2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
