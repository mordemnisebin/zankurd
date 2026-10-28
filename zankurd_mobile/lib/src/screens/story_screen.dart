import 'dart:async';

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/story_progress_store.dart';
import '../data/streak_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../services/analytics_service.dart';
import '../utils/error_reporter.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Dallanan hikâye oynatıcısı. İlerleme yerelde kaydedilir; hikâye yeniden
/// başlatılabilir. Opsiyonel bir [guide] verilirse başta/istenince mini
/// rehber gösterilebilir.
///
/// 2026-10-25 (kurul: Codex + Gemini 4 Argon, hikâye 8/10): ekran yalnız son
/// cümleyi gösteriyordu; önceki konuşma kayboluyordu. Geçilen düğümler
/// sohbet akışı olarak kalır: anlatı solda, oyuncunun seçtiği cümle sağda
/// balon (Duolingo Stories / Babbel diyalog kalıbı). Kurmancî metne
/// dokununca sözlük açılır; kaydı olan ifade seslendirilir.
class StoryScreen extends StatefulWidget {
  const StoryScreen({required this.story, this.guide, super.key});

  final Story story;
  final MiniGuide? guide;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

/// Geçilmiş bir adım: anlatı düğümü ve oyuncunun seçimi.
typedef _StoryTurn = ({StoryNode node, StoryChoice choice});

class _StoryScreenState extends State<StoryScreen> {
  StoryNode? _node;
  final List<_StoryTurn> _history = [];
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Yeni adım eklenince akışın sonuna kayar.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  String? _feedbackKu;
  String? _feedbackTr;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Seçim/yeniden başlatma sürerken ikinci dokunuş yok sayılır (çift
  /// dokunuş iki kez ilerletiyordu).
  bool _busy = false;

  /// Geçmiş başlangıçtan kesintisiz biliniyor mu? Yolu olmayan eski bir
  /// kayıttan devam edilince yalnız yeni seçimler tam yol gibi yazılıp
  /// sonraki açılışta yanlış geri oynatılıyordu (Codex incelemesi
  /// 2026-10-25); bilinmiyorsa yol hiç yazılmaz.
  bool _pathKnown = true;

  Future<void> _restore() async {
    var node = widget.story.start;
    final history = <_StoryTurn>[];
    var pathKnown = true;
    try {
      final store = await StoryProgressStore.load();
      final savedId = store.currentNodeId(widget.story.id);
      node = widget.story.node(savedId) ?? widget.story.start;
      // Kaldığı yerden açılınca önceki konuşma da görünsün (2026-10-25:
      // yalnız son düğüm geri geliyordu). Yol kayıtlı düğüme varmazsa
      // (eski kayıt, başka cihazdan eşitleme) akış boş başlar.
      var walk = widget.story.start;
      for (final i in store.path(widget.story.id) ?? const <int>[]) {
        if (i < 0 || i >= walk.choices.length) break;
        final choice = walk.choices[i];
        final next = widget.story.follow(walk, choice);
        if (next == null) break;
        history.add((node: walk, choice: choice));
        walk = next;
      }
      if (walk.id != node.id) history.clear();
      pathKnown = walk.id == node.id;
    } catch (error, stack) {
      // Kayıt okunamazsa yükleyici sonsuza dek kalmasın: baştan başla.
      ErrorReporter.record(error, stack, reason: 'story restore failed');
      history.clear();
      pathKnown = node.id == widget.story.start.id;
    }
    if (mounted) {
      setState(() {
        _node = node;
        _pathKnown = pathKnown;
        _history
          ..clear()
          ..addAll(history);
        _loading = false;
      });
      if (history.isNotEmpty) _scrollToEnd();
    }
  }

  Future<void> _choose(StoryChoice choice) async {
    if (_busy) return;
    final next = widget.story.follow(_node!, choice);
    if (next == null) return; // koruma
    setState(() => _busy = true);
    final path = [
      for (final turn in _history) turn.node.choices.indexOf(turn.choice),
      _node!.choices.indexOf(choice),
    ];
    try {
      final store = await StoryProgressStore.load();
      await store.saveNode(
        widget.story.id,
        next.id,
        path: _pathKnown ? path : null,
      );
      if (next.isEnding) {
        await store.markCompleted(widget.story.id);
        unawaited(StreakStore.recordActivity());
        AnalyticsService.instance.logStoryComplete(
          storyId: widget.story.id,
          nodeId: next.id,
        );
      }
    } catch (error, stack) {
      // Kayıt yazılamasa da hikâye bellekte ilerler.
      ErrorReporter.record(error, stack, reason: 'story saveNode failed');
    } finally {
      if (mounted && _busy) {
        setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    final current = _node!;
    setState(() {
      _history.add((node: current, choice: choice));
      _node = next;
      _feedbackKu = choice.feedbackKu;
      _feedbackTr = choice.feedbackTr;
      _busy = false;
    });
    _scrollToEnd();
  }

  Future<void> _restart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final store = await StoryProgressStore.load();
      await store.restart(widget.story.id, widget.story.start.id);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'story restart failed');
    } finally {
      if (mounted && _busy) {
        setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    setState(() {
      _history.clear();
      _pathKnown = true;
      _node = widget.story.start;
      _feedbackKu = null;
      _feedbackTr = null;
      _busy = false;
    });
  }

  Future<void> _openMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final t = SahneTokens.of(buttonContext);
    PopupMenuItem<String> item(
      Key key,
      String value,
      IconData icon,
      String label, {
      bool enabled = true,
    }) => PopupMenuItem<String>(
      key: key,
      value: value,
      height: 48,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.tx),
          const SizedBox(width: SahneSpace.x3),
          Flexible(child: Text(label)),
        ],
      ),
    );
    final choice = await showMenu<String>(
      context: buttonContext,
      position: position,
      items: [
        if (widget.guide != null)
          item(
            const ValueKey('story-open-guide'),
            'guide',
            AppIcons.bookOpen,
            buttonContext.t(K.guide),
          ),
        item(
          const ValueKey('story-restart'),
          'restart',
          AppIcons.arrowsRotate,
          buttonContext.t(K.restart),
          enabled: !_busy,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'guide':
        _openGuide();
      case 'restart':
        unawaited(_restart());
    }
  }

  void _openGuide() {
    final guide = widget.guide;
    if (guide == null) return;
    final t = SahneTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 2026-09-30 simülatör: büyük yazıda rehber sayfası ekran boyuna
      // uzuyor ve başlığı durum çubuğunun altına giriyordu (saatle üst
      // üste). Güvenli alan içinde açılır; 1.0 ölçekte sayfa kısa kaldığı
      // için kusur turda görünmüyordu.
      useSafeArea: true,
      backgroundColor: t.s1,
      shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      builder: (ctx) => _MiniGuideView(guide: guide, isKu: context.isKu),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: B iskeleti. Hikâyenin adı ve "Yolunu seç" çubukta;
    // içerikteki eski kimlik bandı kalktı. Rehber ve yeniden başlat çubuğun
    // sağında 44'lük plakalardır (dokunma alanı 48).
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(ku ? widget.story.titleKu : widget.story.titleTr),
        // U10 (2026-10-28 tur 4): çubuğun sağında EN ÇOK BİR eylem. Rehber ve
        // yeniden başlat tek "⋯" menüsünde.
        actions: [
          Builder(
            builder: (buttonContext) => SahneIconButton(
              key: const ValueKey('story-menu'),
              icon: AppIcons.ellipsis,
              semanticLabel: context.t(K.moreOptions),
              onPressed: () => _openMenu(buttonContext),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading || _node == null
            ? Center(child: CircularProgressIndicator(color: t.learnTx))
            : _buildNode(context, ku, _node!),
      ),
    );
  }

  Widget _buildNode(BuildContext context, bool ku, StoryNode node) {
    final t = SahneTokens.of(context);
    final feedback = ku ? _feedbackKu : _feedbackTr;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x2,
        SahneSpace.page,
        SahneSpace.x6,
      ),
      children: [
        // Geçilen adımlar: anlatı solda, oyuncunun cümlesi sağda.
        for (var i = 0; i < _history.length; i++) ...[
          _NarrationBubble(
            key: ValueKey('story-history-$i'),
            node: _history[i].node,
          ),
          const SizedBox(height: SahneSpace.x2),
          _PlayerBubble(choice: _history[i].choice),
          const SizedBox(height: SahneSpace.x3),
        ],
        // Önceki seçimin karşılığı: yüzey kartında, öğrenme tonlu ikonla.
        if (feedback != null && feedback.isNotEmpty) ...[
          SahneSurfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: t.learnTint,
                    shape: SahneShape.m,
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(AppIcons.comment, size: 20, color: t.learnTx),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    feedback,
                    style: SahneType.body.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SahneSpace.cardGap),
        ],
        // Anlatı: sahne kartı (gece, öğrenme rolü). Kurmancî cümle Manşet,
        // çevirisi altında ikincil metinde.
        SizedBox(
          width: double.infinity,
          child: SahneStageCard(
            child: Builder(
              builder: (context) {
                final s = SahneTokens.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(K.storyWord),
                            style: SahneType.eyebrow.copyWith(
                              color: s.eyebrowTx,
                            ),
                          ),
                        ),
                        LexiconSpeakButton(text: node.textKu),
                      ],
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    LexiconText(
                      node.textKu,
                      key: const ValueKey('story-text-ku'),
                      style: SahneType.headline.copyWith(color: s.tx),
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    Text(
                      node.textTr,
                      style: SahneType.body.copyWith(color: s.tx2),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: SahneSpace.x4),
        if (node.isEnding) ...[
          if (widget.guide != null && widget.guide!.newWords.isNotEmpty) ...[
            SahneSurfaceCard(
              key: const ValueKey('story-ending-words'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.yeniKelimeler),
                    style: SahneType.captionStrong.copyWith(color: t.eyebrowTx),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  for (final w in widget.guide!.newWords)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• ${w.ku} — ${w.tr}',
                            style: SahneType.body.copyWith(color: t.tx),
                          ),
                        ),
                        LexiconSpeakButton(text: w.ku),
                        if (LearnerLexicon.lookup(w.ku) case final entry?)
                          WordSaveButton(entryId: entry.id),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: SahneSpace.x4),
          ],
          SahneButton.primary(
            key: const ValueKey('story-ending-restart'),
            onPressed: _busy ? null : _restart,
            icon: AppIcons.arrowRotateLeft,
            arrow: false,
            label: context.t(K.playAgain),
            expand: true,
          ),
        ] else
          // Seçenekler tek liste grubunda: Kurmancî cümle önde, çevirisi
          // altında. Gövde her zaman Kurmancî cümleyi üstte gösterir; şık da
          // aynı biçimi alır — Türkçe arayüzde öğrenci Kurmancî okuyup
          // Türkçe seçiyordu, alıştırmanın üretim kısmı yoktu (2026-07-27).
          SahneListGroup(
            children: [
              for (final choice in node.choices)
                _StoryChoiceRow(
                  choice: choice,
                  onTap: _busy ? null : () => _choose(choice),
                ),
            ],
          ),
      ],
    );
  }
}

/// Geçilmiş anlatı: solda, sönük yüzey balonu (Kurmancî + çevirisi).
class _NarrationBubble extends StatelessWidget {
  const _NarrationBubble({required this.node, super.key});

  final StoryNode node;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: t.s1,
            shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              SahneSpace.x3,
              SahneSpace.x2,
              SahneSpace.x1,
              SahneSpace.x2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LexiconText(
                        node.textKu,
                        style: SahneType.body.copyWith(color: t.tx),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.textTr,
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                    ],
                  ),
                ),
                LexiconSpeakButton(text: node.textKu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Oyuncunun seçtiği cümle: sağda, öğrenme tonlu balon.
class _PlayerBubble extends StatelessWidget {
  const _PlayerBubble({required this.choice});

  final StoryChoice choice;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        alignment: AlignmentDirectional.centerEnd,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: t.learnTint,
            shape: SahneShape.withSide(SahneShape.m, t.learnEdge, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  choice.labelKu,
                  textAlign: TextAlign.end,
                  style: SahneType.bodyStrong.copyWith(color: t.learnTx),
                ),
                Text(
                  choice.labelTr,
                  textAlign: TextAlign.end,
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hikâye seçeneği: liste grubunda bir satır — Kurmancî cümle (Gövde 700),
/// çevirisi (Açıklama, ikincil) ve chevron. En az 64; metin sarar.
class _StoryChoiceRow extends StatelessWidget {
  const _StoryChoiceRow({required this.choice, required this.onTap});

  final StoryChoice choice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            SahneSpace.x4,
            SahneSpace.x3,
            SahneSpace.x3,
            SahneSpace.x3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      choice.labelKu,
                      key: ValueKey('story-choice-ku-${choice.nextNodeId}'),
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                    Text(
                      choice.labelTr,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              ExcludeSemantics(
                child: Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniGuideView extends StatelessWidget {
  const _MiniGuideView({required this.guide, required this.isKu});

  final MiniGuide guide;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final item = SahneType.body.copyWith(color: t.tx);
    final note = SahneType.body.copyWith(color: t.tx2);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x5,
        SahneSpace.page,
        MediaQuery.viewInsetsOf(context).bottom + SahneSpace.x4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                isKu ? guide.titleKu : guide.titleTr,
                style: SahneType.headline.copyWith(color: t.tx),
              ),
            ),
            const SizedBox(height: SahneSpace.x4),
            _label(context, Tr.forKu(K.yeniKelimeler, isKu)),
            for (final w in guide.newWords)
              Row(
                children: [
                  Expanded(child: Text('• ${w.ku} — ${w.tr}', style: item)),
                  LexiconSpeakButton(text: w.ku),
                  if (LearnerLexicon.lookup(w.ku) case final entry?)
                    WordSaveButton(entryId: entry.id),
                ],
              ),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.dilbilgisi, isKu)),
            Text(isKu ? guide.grammarKu : guide.grammarTr, style: note),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.ornekler, isKu)),
            for (final e in guide.examples)
              Row(
                children: [
                  Expanded(child: Text('• ${e.ku} — ${e.tr}', style: item)),
                  LexiconSpeakButton(text: e.ku),
                ],
              ),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.kulturelNot, isKu)),
            Text(isKu ? guide.cultureKu : guide.cultureTr, style: note),
            const SizedBox(height: SahneSpace.x5),
            SahneButton.primary(
              onPressed: () => Navigator.of(context).maybePop(),
              label: Tr.forKu(K.anladim, isKu),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Rehber bölüm etiketi: kalın açıklama, öğrenme metni rengi.
  Widget _label(BuildContext context, String text) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x1),
      child: Text(
        text,
        style: SahneType.captionStrong.copyWith(color: t.eyebrowTx),
      ),
    );
  }
}
