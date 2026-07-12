import 'package:flutter/material.dart';

import '../data/mastery_store.dart';
import '../data/mistake_store.dart';
import '../services/strength_analysis.dart';
import '../theme/app_theme.dart';

/// Profildeki "Güçlü ve Geliştirilecek Alanlar" bölümü.
///
/// Ham verileri store'lardan okur, [StrengthAnalysis] ile açıklanabilir
/// içgörülere çevirir. Renk tek başına anlam taşımaz: her satır ikon + metin
/// de taşır. Az veride kesin yargı üretmez, nazik bir bilgi mesajı gösterir.
class StrengthMapSection extends StatefulWidget {
  const StrengthMapSection({required this.isKu, this.refreshSignal, super.key});

  final bool isKu;
  final Listenable? refreshSignal;

  static const _categories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
  ];

  @override
  State<StrengthMapSection> createState() => _StrengthMapSectionState();
}

class _StrengthMapSectionState extends State<StrengthMapSection> {
  StrengthMapResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshSignal?.addListener(_load);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final mistakeStore = await MistakeStore.load();
      final masteryStore = await MasteryStore.load();
      final mistakes = mistakeStore.getMistakesCountByCategory();
      final mastery = {
        for (final c in StrengthMapSection._categories)
          c: masteryStore.correctCount(c),
      };
      final result = StrengthAnalysis.analyze(
        categories: StrengthMapSection._categories,
        masteryCorrect: mastery,
        mistakes: mistakes,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _trCategory(String ku) => switch (ku) {
    'Ziman' => 'Dil',
    'Çand' => 'Kültür',
    'Dîrok' => 'Tarih',
    'Cografya' => 'Coğrafya',
    'Muzîk' => 'Müzik',
    _ => ku,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading || _result == null) return const SizedBox.shrink();
    final ku = widget.isKu;
    final result = _result!;

    return Container(
      key: const ValueKey('strength-map-section'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: AppTheme.playGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ku
                      ? 'Hêz û Cihên Pêşketinê'
                      : 'Güçlü ve Geliştirilecek Alanlar',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (result.insufficientData)
            _buildHint(context, ku)
          else ...[
            if (result.strengths.isNotEmpty) ...[
              _buildGroupLabel(
                context,
                ku ? 'Xurt' : 'Güçlü',
                Icons.emoji_events_outlined,
                AppTheme.gold,
              ),
              for (final i in result.strengths.take(3))
                _buildRow(context, ku, i, InsightTone.strength),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (result.improvements.isNotEmpty) ...[
              _buildGroupLabel(
                context,
                ku ? 'Cihên pêşketinê' : 'Geliştirilecek',
                Icons.trending_up_rounded,
                AppTheme.brandOrange,
              ),
              for (final i in result.improvements.take(3))
                _buildRow(context, ku, i, InsightTone.improve),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHint(BuildContext context, bool ku) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppTheme.textMutedColor(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ku
                ? 'Ji bo analîzê hê hindik dane heye. Piçekî bêtir bilîze!'
                : 'Analiz için henüz az veri var. Biraz daha oyna!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textMutedColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupLabel(
    BuildContext context,
    String label,
    IconData icon,
    Color tint,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: tint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    bool ku,
    CategoryInsight insight,
    InsightTone tone,
  ) {
    final name = ku ? insight.category : _trCategory(insight.category);
    final isStrength = tone == InsightTone.strength;
    // Renk + ikon + metin birlikte anlam taşır.
    final icon = isStrength
        ? Icons.check_circle_outline_rounded
        : Icons.flag_outlined;
    final tint = isStrength ? AppTheme.playGreen : AppTheme.brandOrange;
    final String action;
    if (isStrength) {
      action = ku ? 'Ji xwe bawer be' : 'Formunu koru';
    } else if (insight.readyReviews > 0) {
      action = ku ? 'Dubarekirin amade' : 'Tekrar hazır';
    } else {
      action = ku ? 'Piçek pratîk baş e' : 'Biraz pratik iyi gelir';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              action,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
