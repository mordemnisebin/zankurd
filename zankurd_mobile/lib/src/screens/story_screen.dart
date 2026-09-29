import 'package:flutter/material.dart';

import '../data/story_progress_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Metin tabanlı dallanan hikâye oynatıcısı (SES YOK). İlerleme yerelde
/// kaydedilir; hikâye yeniden başlatılabilir. Opsiyonel bir [guide] verilirse
/// başta/istenince mini rehber gösterilebilir.
class StoryScreen extends StatefulWidget {
  const StoryScreen({required this.story, this.guide, super.key});

  final Story story;
  final MiniGuide? guide;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  StoryNode? _node;
  String? _feedbackKu;
  String? _feedbackTr;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final store = await StoryProgressStore.load();
    final savedId = store.currentNodeId(widget.story.id);
    final node = widget.story.node(savedId) ?? widget.story.start;
    if (mounted) {
      setState(() {
        _node = node;
        _loading = false;
      });
    }
  }

  Future<void> _choose(StoryChoice choice) async {
    final next = widget.story.follow(_node!, choice);
    if (next == null) return; // koruma
    final store = await StoryProgressStore.load();
    await store.saveNode(widget.story.id, next.id);
    if (!mounted) return;
    setState(() {
      _node = next;
      _feedbackKu = choice.feedbackKu;
      _feedbackTr = choice.feedbackTr;
    });
  }

  Future<void> _restart() async {
    final store = await StoryProgressStore.load();
    await store.restart(widget.story.id);
    if (!mounted) return;
    setState(() {
      _node = widget.story.start;
      _feedbackKu = null;
      _feedbackTr = null;
    });
  }

  void _openGuide() {
    final guide = widget.guide;
    if (guide == null) return;
    final t = SahneTokens.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
        actions: [
          if (widget.guide != null)
            SahneIconButton(
              key: const ValueKey('story-open-guide'),
              icon: AppIcons.bookOpen,
              semanticLabel: context.t(K.guide),
              onPressed: _openGuide,
            ),
          SahneIconButton(
            key: const ValueKey('story-restart'),
            icon: AppIcons.arrowsRotate,
            semanticLabel: context.t(K.restart),
            onPressed: _restart,
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
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x2,
        SahneSpace.page,
        SahneSpace.x6,
      ),
      children: [
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
                    Text(
                      sahneUpper(context, context.t(K.storyWord)),
                      style: SahneType.eyebrow.copyWith(color: s.learnTx),
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    Text(
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
        if (node.isEnding)
          SahneButton.primary(
            key: const ValueKey('story-ending-restart'),
            onPressed: _restart,
            icon: AppIcons.arrowRotateLeft,
            arrow: false,
            label: context.t(K.playAgain),
            expand: true,
          )
        else
          // Seçenekler tek liste grubunda: Kurmancî cümle önde, çevirisi
          // altında. Gövde her zaman Kurmancî cümleyi üstte gösterir; şık da
          // aynı biçimi alır — Türkçe arayüzde öğrenci Kurmancî okuyup
          // Türkçe seçiyordu, alıştırmanın üretim kısmı yoktu (2026-07-27).
          SahneListGroup(
            children: [
              for (final choice in node.choices)
                _StoryChoiceRow(choice: choice, onTap: () => _choose(choice)),
            ],
          ),
      ],
    );
  }
}

/// Hikâye seçeneği: liste grubunda bir satır — Kurmancî cümle (Gövde 700),
/// çevirisi (Açıklama, ikincil) ve chevron. En az 64; metin sarar.
class _StoryChoiceRow extends StatelessWidget {
  const _StoryChoiceRow({required this.choice, required this.onTap});

  final StoryChoice choice;
  final VoidCallback onTap;

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
              Text('• ${w.ku} — ${w.tr}', style: item),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.dilbilgisi, isKu)),
            Text(isKu ? guide.grammarKu : guide.grammarTr, style: note),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.ornekler, isKu)),
            for (final e in guide.examples)
              Text('• ${e.ku} — ${e.tr}', style: item),
            const SizedBox(height: SahneSpace.x3),
            _label(context, Tr.forKu(K.kulturelNot, isKu)),
            Text(isKu ? guide.cultureKu : guide.cultureTr, style: note),
            const SizedBox(height: SahneSpace.x5),
            SahneButton.primary(
              onPressed: () => Navigator.of(context).maybePop(),
              label: Tr.forKu(K.derseBasla, isKu),
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
        style: SahneType.captionStrong.copyWith(color: t.learnTx),
      ),
    );
  }
}
