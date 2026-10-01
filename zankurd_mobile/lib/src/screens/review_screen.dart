import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.records,
    required this.room,
    this.practiceAvailable = true,
    super.key,
  });

  final List<AnswerRecord> records;
  final GameRoom room;
  final bool practiceAvailable;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isFlashcardMode = false;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final correct = widget.records.where((r) => r.isCorrect).length;
    final wrong = widget.records
        .where((r) => !r.isCorrect && !r.isUnanswered)
        .length;
    final empty = widget.records.where((r) => r.isUnanswered).length;

    // 2026-09-29 Şahnê: B iskeleti. "Cevaplar" çubukta (2026-10-01'de tek
    // satırlık özet kalktı: karolar aynı sayıları söylüyor); eski camgöbeği kimlik bandı ve
    // kilim ayracı kalktı. İçerik: üç sayaç karosu → görünüm rayı → (varsa)
    // TEK birincil "Tekrara başla" → cevap kartları ya da hafıza kartı.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        // Alt başlık yok: aynı üç sayıyı hemen altındaki karolar zaten
        // söylüyor (2026-10-01 tasarım denetimi: özet satırı karoları
        // tekrarlıyordu).
        title: Text(context.t(K.answersTitle)),
      ),
      body: SafeArea(
        top: false,
        child: widget.records.isEmpty
            ? AppEmptyState(
                icon: AppIcons.squareCheck,
                title: context.t(K.answersEmptyTitle),
                message: context.t(K.answersEmptyBody),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  SahneSpace.x6,
                ),
                children: [
                  _SummaryStrip(correct: correct, wrong: wrong, empty: empty),
                  const SizedBox(height: SahneSpace.x4),
                  // Görünüm bir okuma denetimidir: isteğe bağlı tekrar
                  // eyleminin önünde durur. 320 px / %200 yazıda da Liste /
                  // Hafıza Kartları erişilebilir kalır.
                  SahneRail.fit(
                    children: [
                      _ViewModeChip(
                        label: context.t(K.listView),
                        selected: !_isFlashcardMode,
                        onTap: () => setState(() => _isFlashcardMode = false),
                      ),
                      _ViewModeChip(
                        label: context.t(K.flashcards),
                        selected: _isFlashcardMode,
                        onTap: () => setState(() => _isFlashcardMode = true),
                      ),
                    ],
                  ),
                  if (wrong > 0 && widget.practiceAvailable) ...[
                    const SizedBox(height: SahneSpace.x3),
                    SahneButton.primary(
                      key: const ValueKey('review-practice-cta'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: AppIcons.arrowsRotate,
                      arrow: false,
                      label: context.t(K.tekraraBasla),
                      expand: true,
                    ),
                  ],
                  const SizedBox(height: SahneSpace.x4),
                  if (_isFlashcardMode)
                    _FlashcardView(records: widget.records)
                  else
                    for (var i = 0; i < widget.records.length; i++) ...[
                      _ReviewCard(record: widget.records[i], index: i),
                      if (i != widget.records.length - 1)
                        const SizedBox(height: SahneSpace.cardGap),
                    ],
                ],
              ),
      ),
    );
  }
}

/// Görünüm rayının çipi: [SahneRailChip] (sığan rayda eşit genişlik;
/// görsel 44, dokunma 48). Ekran okuyucu seçili durumunu duyar.
class _ViewModeChip extends StatelessWidget {
  const _ViewModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      SahneRailChip(label: label, selected: selected, onTap: onTap);
}

/// Sayaç karoları: doğru ✓ (Rast), yanlış ✗ (Şaş), boş (kum saati,
/// ikincil). Karolar ortak sonuç şablonundandır ([SahneResultStats],
/// 2026-10-01 A6): tur sonucundaki karolarla aynı biçim, aynı büyük yazı
/// davranışı. Burada tek fark kural: bu ekran cevap incelemesidir, sıfır
/// karo HİÇ çizilmez ("0 Boş" hiçbir şey söylemeyen bir kutuydu); kalan
/// karolar genişliği paylaşır, kayıt varken en az biri sıfırdan büyüktür.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.correct,
    required this.wrong,
    required this.empty,
  });

  final int correct;
  final int wrong;
  final int empty;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneResultStats(
      stats: [
        SahneResultStat(
          leading: Icon(AppIcons.circleCheck, size: 20, color: t.okTx),
          value: correct,
          label: context.t(K.correct),
        ),
        SahneResultStat(
          leading: Icon(AppIcons.circleXmark, size: 20, color: t.errTx),
          value: wrong,
          label: context.t(K.wrong),
        ),
        SahneResultStat(
          leading: Icon(AppIcons.hourglass, size: 20, color: t.tx2),
          value: empty,
          label: context.t(K.blank),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.record, required this.index});

  final AnswerRecord record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final bool isCorrect = record.isCorrect;
    final bool isUnanswered = record.isUnanswered;
    final selectedText = record.selectedAnswer?.trim();
    final showTypedAnswer =
        selectedText != null &&
        selectedText.isNotEmpty &&
        selectedText != 'TIMEOUT' &&
        !record.answers.contains(selectedText);
    // Yazılmış açıklama > override > şablon eleme > kural motoru.
    //
    // Burası doğrudan kural motoruna gidiyordu ve sorunun elle yazılmış
    // Kurmancî açıklamasını hiç görmüyordu: Kurmancî turda özet
    // "Şirove: <Türkçe cümle>" gösteriyordu. Motor yedektir, kaynak
    // değil (2026-07-27).
    final isKu = context.isKu;
    final authored = isKu ? record.explanationKu : record.explanationTr;
    final String explanationText =
        (authored != null &&
            authored.trim().isNotEmpty &&
            !isTemplateExplanation(authored))
        ? authored
        : resolveRawExplanation(
            id: record.id,
            explanation: record.explanation,
            isKu: isKu,
          );

    final Widget status = isUnanswered
        ? SahneStatusBadge.blank(label: context.t(K.blankBadge))
        : SahneStatusBadge(
            correct: isCorrect,
            label: context.t(isCorrect ? K.correctBadge : K.wrongBadge),
          );

    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            children: [
              status,
              Text(
                context.t(K.questionIndex, {'index': '${index + 1}'}),
                style: SahneType.captionStrong.copyWith(color: t.tx3),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x4),
          if (record.hasImage) ...[
            _RecordImage(url: record.imageUrl!),
            const SizedBox(height: SahneSpace.x4),
          ],
          Text(
            record.prompt,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x3),
          for (final answer in record.answers)
            _AnswerLine(
              text: answer,
              state: answer == record.correctAnswer
                  ? _AnswerState.correct
                  : answer == record.selectedAnswer
                  ? _AnswerState.wrong
                  : _AnswerState.idle,
            ),
          if (showTypedAnswer)
            _AnswerLine(
              key: const ValueKey('review-typed-answer'),
              text: context.t(K.yourAnswer, {'answer': selectedText}),
              state: record.isCorrect
                  ? _AnswerState.correct
                  : _AnswerState.wrong,
            ),
          if (explanationText.isNotEmpty) ...[
            // Açıklama bir şık değildir: dolgusuz, ince bir çizgiyle
            // şıklardan ayrılır; ampul öğrenme rolünün metin renginde.
            const SizedBox(height: SahneSpace.x2),
            SizedBox(height: 1, child: ColoredBox(color: t.line)),
            const SizedBox(height: SahneSpace.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.lightbulb, color: t.learnTx, size: 20),
                const SizedBox(width: SahneSpace.x2),
                Expanded(
                  child: Text(
                    explanationText,
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _AnswerState { correct, wrong, idle }

/// Cevap satırı — sonucu gösterilmiş şık: doğru şık Rast tonu + Halka 2 +
/// ✓, seçilen yanlış şık Şaş tonu + Halka 2 + ✗, ötekiler Kulis tonu ve
/// ikincil metin. Durum hiçbir zaman yalnız renkle verilmez.
class _AnswerLine extends StatelessWidget {
  const _AnswerLine({super.key, required this.text, required this.state});

  final String text;
  final _AnswerState state;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (Color bg, Color fg, Color? ring, IconData? icon) = switch (state) {
      _AnswerState.correct => (t.okTint, t.okTx, t.okTx, AppIcons.check),
      _AnswerState.wrong => (t.errTint, t.errTx, t.errTx, AppIcons.xmark),
      _AnswerState.idle => (t.s2, t.tx2, null, null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x2),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: bg,
          shape: ring == null
              ? SahneShape.m
              : SahneShape.withSide(SahneShape.m, ring, width: SahneRing.r2),
        ),
        child: ConstrainedBox(
          // a11y-tap-target: noninteractive — cevap satırı; salt görsel,
          // dokunma hedefi değil.
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x4,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: SahneType.bodyStrong.copyWith(color: fg),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: SahneSpace.x2),
                  Icon(icon, color: fg, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soru görseli: L pahlı, 180 yüksekliğinde; yüklenirken ve hata hâlinde
/// Kulis tonlu yer tutucu.
class _RecordImage extends StatelessWidget {
  const _RecordImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget placeholder(Widget child) => ColoredBox(
      color: t.s2,
      child: Center(child: child),
    );
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.l),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: url.startsWith('asset://')
            ? Image.asset(
                url.replaceFirst('asset://', ''),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              )
            : CachedNetworkImage(
                // Gözden geçirme kartı küçük; tam çözünürlük belleğe açmak
                // gereksiz (2026-07-31).
                memCacheWidth: 720,
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => placeholder(
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.learnTx,
                    ),
                  ),
                ),
                errorWidget: (context, _, _) =>
                    placeholder(Icon(AppIcons.image, color: t.tx3, size: 32)),
              ),
      ),
    );
  }
}

class _FlashcardView extends StatefulWidget {
  const _FlashcardView({required this.records});

  final List<AnswerRecord> records;

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  void _nextCard() {
    if (_currentIndex < widget.records.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  void _toggleFlip() {
    setState(() => _isFlipped = !_isFlipped);
  }

  String _flashcardSemanticLabel(
    BuildContext context,
    AnswerRecord record,
    String explanationText,
  ) {
    final isKu = context.isKu;
    if (!_isFlipped) {
      return [
        Tr.forKu(K.flashcardFront, isKu),
        record.prompt,
        context.t(K.cevabiGormekIcinDokun),
      ].join('. ');
    }

    final label = <String>[
      Tr.forKu(K.flashcardBack, isKu),
      context.t(K.dogruCevap),
      record.correctAnswer,
    ];
    if (explanationText.isNotEmpty) {
      label
        ..add(context.t(K.aciklama))
        ..add(explanationText);
    }
    return label.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final record = widget.records[_currentIndex];
    final isKu = context.isKu;
    final explanationText = isKu
        ? (record.explanationKu ?? record.explanation)
        : (record.explanationTr ?? record.explanation);
    final reduceMotion = sahneMotionReduced(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: SahneSpace.x2),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: SahneSpace.x1,
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.records.length}',
                style: SahneType.bodyStrong.copyWith(
                  color: t.tx,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  Tr.forKu(
                    _isFlipped ? K.flashcardBack : K.flashcardFront,
                    isKu,
                  ),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          key: const ValueKey('review-flashcard'),
          container: true,
          button: true,
          enabled: true,
          label: _flashcardSemanticLabel(context, record, explanationText),
          excludeSemantics: true,
          onTap: _toggleFlip,
          child: GestureDetector(
            onTap: _toggleFlip,
            child: AnimatedSwitcher(
              // Hareketi azalt açıkken kart dönmeden değişir.
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final rotate = Tween(
                  begin: math.pi,
                  end: 0.0,
                ).animate(animation);
                return AnimatedBuilder(
                  animation: rotate,
                  child: child,
                  builder: (context, child) {
                    final isUnder = (ValueKey(_isFlipped) != child?.key);
                    var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                    tilt *= isUnder ? -1.0 : 1.0;
                    final value = isUnder
                        ? math.min(rotate.value, math.pi / 2)
                        : rotate.value;
                    return Transform(
                      transform: Matrix4.rotationY(value)..setEntry(3, 2, tilt),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                );
              },
              child: _isFlipped
                  ? _buildBackCard(context, record, explanationText)
                  : _buildFrontCard(context, record),
            ),
          ),
        ),
        const SizedBox(height: SahneSpace.x4),
        Row(
          children: [
            Expanded(
              child: SahneButton.secondary(
                icon: AppIcons.arrowLeft,
                label: context.t(K.back),
                onPressed: _currentIndex > 0 ? _prevCard : null,
                expand: true,
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            Expanded(
              child: SahneButton.secondary(
                arrow: true,
                label: context.t(K.next),
                onPressed: _currentIndex < widget.records.length - 1
                    ? _nextCard
                    : null,
                expand: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Ön yüz: yüzey kartı (L pah) — kategori rozeti, soru (Manşet, ortada)
  /// ve "Cevabı görmek için dokun" ipucu (Zimrût metni).
  Widget _buildFrontCard(BuildContext context, AnswerRecord record) {
    final t = SahneTokens.of(context);
    return SizedBox(
      key: const ValueKey(false),
      width: double.infinity,
      child: SahneSurfaceCard(
        padding: const EdgeInsets.all(SahneSpace.x5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Kategori kimliği veri katmanında Kurmancî sabittir
                  // (bkz. `CategoryNames`); Türkçe turda ham "Ziman" gibi
                  // çevrilmeden basılıyordu (2026-08-14 denetimi).
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SahneBadge(
                        label: CategoryNames.localized(
                          record.category,
                          context.isKu,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Icon(AppIcons.layerGroup, size: 20, color: t.learnTx),
                ],
              ),
              const SizedBox(height: SahneSpace.x5),
              Text(
                record.prompt,
                textAlign: TextAlign.center,
                style: SahneType.headline.copyWith(color: t.tx),
              ),
              const SizedBox(height: SahneSpace.x6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: SahneSpace.x2,
                runSpacing: SahneSpace.x1,
                children: [
                  Icon(AppIcons.arrowsRotate, size: 16, color: t.learnTx),
                  Text(
                    context.t(K.cevabiGormekIcinDokun),
                    style: SahneType.captionStrong.copyWith(color: t.learnTx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arka yüz: sahne kartı (gece) — "Doğru Cevap:" (Rast metni, ✓) ve
  /// Rast tonlu cevap kutusu; varsa açıklama (Zimrût metni etiket).
  Widget _buildBackCard(
    BuildContext context,
    AnswerRecord record,
    String explanationText,
  ) {
    return SizedBox(
      key: const ValueKey(true),
      width: double.infinity,
      child: SahneStageCard(
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.x5,
          SahneSpace.x6,
          SahneSpace.x5,
          SahneSpace.x5,
        ),
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.circleCheck, color: t.okTx, size: 20),
                      const SizedBox(width: SahneSpace.x2),
                      Expanded(
                        child: Text(
                          context.t(K.dogruCevap),
                          style: SahneType.captionStrong.copyWith(
                            color: t.okTx,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.okTint,
                        shape: SahneShape.m,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(SahneSpace.x3),
                        child: Text(
                          record.correctAnswer,
                          style: SahneType.bodyStrong.copyWith(color: t.tx),
                        ),
                      ),
                    ),
                  ),
                  if (explanationText.isNotEmpty) ...[
                    const SizedBox(height: SahneSpace.x4),
                    Row(
                      children: [
                        Icon(AppIcons.lightbulb, color: t.learnTx, size: 20),
                        const SizedBox(width: SahneSpace.x2),
                        Expanded(
                          child: Text(
                            // Ürün terimi şîrove (`K.explanationTitle`);
                            // etiket "Ravahî" deyince aynı açıklama iki adla
                            // durur.
                            context.t(K.aciklama),
                            style: SahneType.captionStrong.copyWith(
                              color: t.learnTx,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SahneSpace.x1),
                    Text(
                      explanationText,
                      style: SahneType.body.copyWith(color: t.tx2),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
