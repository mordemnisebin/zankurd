import 'package:flutter/material.dart';

import '../data/story_progress_store.dart';
import '../l10n/lang.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../theme/app_theme.dart';

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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.borderColor(context)),
      ),
      builder: (ctx) => _MiniGuideView(guide: guide, isKu: context.isKu),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      appBar: AppBar(
        title: Text(ku ? widget.story.titleKu : widget.story.titleTr),
        actions: [
          if (widget.guide != null)
            IconButton(
              key: const ValueKey('story-open-guide'),
              tooltip: ku ? 'Rêber' : 'Rehber',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: _openGuide,
            ),
          IconButton(
            key: const ValueKey('story-restart'),
            tooltip: ku ? 'Ji nû ve' : 'Yeniden başlat',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: _loading || _node == null
              ? const Center(child: CircularProgressIndicator())
              : _buildNode(context, ku, _node!),
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, bool ku, StoryNode node) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (_feedbackKu != null || _feedbackTr != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.playGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppTheme.playGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              ku ? (_feedbackKu ?? '') : (_feedbackTr ?? ''),
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        Text(
          node.textKu,
          key: const ValueKey('story-text-ku'),
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          node.textTr,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textMutedColor(context),
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (node.isEnding)
          FilledButton.icon(
            key: const ValueKey('story-ending-restart'),
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: Text(ku ? 'Dîsa bilîze' : 'Tekrar oyna'),
          )
        else
          for (final choice in node.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _choose(choice),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ku ? choice.labelKu : choice.labelTr,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _MiniGuideView extends StatelessWidget {
  const _MiniGuideView({required this.guide, required this.isKu});

  final MiniGuide guide;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKu ? guide.titleKu : guide.titleTr,
              style: AppTypography.heading1.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _label(context, isKu ? 'Peyvên nû' : 'Yeni kelimeler'),
            for (final w in guide.newWords)
              Text(
                '• ${w.ku} — ${w.tr}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, isKu ? 'Not' : 'Dilbilgisi'),
            Text(
              isKu ? guide.grammarKu : guide.grammarTr,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, isKu ? 'Mînak' : 'Örnekler'),
            for (final e in guide.examples)
              Text(
                '• ${e.ku} — ${e.tr}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, isKu ? 'Nota çandî' : 'Kültürel not'),
            Text(
              isKu ? guide.cultureKu : guide.cultureTr,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(isKu ? 'Dest bi dersê bike' : 'Derse başla'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppTheme.playGreen,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
