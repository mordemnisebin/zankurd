import 'package:flutter/material.dart';

import '../data/story_progress_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';
import '../widgets/screen_identity_header.dart';
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
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.guide != null)
            IconButton(
              key: const ValueKey('story-open-guide'),
              tooltip: context.t(K.guide),
              icon: const Icon(AppIcons.bookOpen),
              onPressed: _openGuide,
            ),
          IconButton(
            key: const ValueKey('story-restart'),
            tooltip: context.t(K.restart),
            icon: const Icon(AppIcons.arrowsRotate),
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
    // Ekran bir zamanlar düz metin + çerçeveli iki kutudan ibaretti:
    // uygulamanın geri kalanı kartlı ve renkliyken hikâye ekranı
    // yarım kalmış bir taslak gibi duruyor, alt yarısı da bomboş
    // kalıyordu (2026-07-27, canlı gezinti).
    //
    // Anlatı artık kendi kartında, seçenekler ise quiz şıklarıyla aynı
    // dili konuşuyor: yüzey, kenarlık ve yön oku. Renk hikâyenin
    // kimliğinden (yeşil) gelir, quizin doğru/yanlış renkleriyle
    // karışmaz.
    const accent = AppTheme.playGreen;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        ScreenIdentityHeader(
          title: ku ? widget.story.titleKu : widget.story.titleTr,
          subtitle: context.t(K.storySubtitle),
          accent: accent,
          icon: AppIcons.bookOpen,
          compact: true,
        ),
        const SizedBox(height: AppSpacing.md),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.07),
              AppTheme.surfaceHiColor(context),
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.bookOpen, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    context.t(K.storyWord),
                    style: AppTypography.caption.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Hikâye anlatısı ile seçimler arasına tek kilim ayracı: "bölüm
        // ayracı" semantiği (triangleRhythm). Motif bilgi taşır — anlatının
        // bittiği, kararın başladığı yeri işaretler (2026-08-19).
        const KilimDivider(colors: [AppTheme.playGreen, AppTheme.gold]),
        const SizedBox(height: AppSpacing.lg),
        if (node.isEnding)
          FilledButton.icon(
            key: const ValueKey('story-ending-restart'),
            onPressed: _restart,
            icon: const Icon(AppIcons.arrowRotateLeft),
            label: Text(context.t(K.playAgain)),
          )
        else
          for (final choice in node.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => _choose(choice),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Gövde her zaman Kurmancî cümleyi üstte, çevirisini
                        // altta gösterir; şıklar ise yalnız arayüz dilini
                        // gösteriyordu. Türkçe arayüzde öğrenci Kurmancî
                        // bir cümle okuyup Türkçe şıklardan seçiyordu —
                        // yani alıştırmanın Kurmancî üretim kısmı hiç
                        // yoktu (2026-07-27). Şık da gövdeyle aynı biçimi
                        // alır: Kurmancî önde, çeviri altında.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                choice.labelKu,
                                key: ValueKey(
                                  'story-choice-ku-${choice.nextNodeId}',
                                ),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                choice.labelTr,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          AppIcons.chevronRight,
                          size: 18,
                          color: accent,
                        ),
                      ],
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
            _label(context, Tr.forKu(K.yeniKelimeler, isKu)),
            for (final w in guide.newWords)
              Text(
                '• ${w.ku} — ${w.tr}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, Tr.forKu(K.dilbilgisi, isKu)),
            Text(
              isKu ? guide.grammarKu : guide.grammarTr,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, Tr.forKu(K.ornekler, isKu)),
            for (final e in guide.examples)
              Text(
                '• ${e.ku} — ${e.tr}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, Tr.forKu(K.kulturelNot, isKu)),
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
                child: Text(Tr.forKu(K.derseBasla, isKu)),
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
