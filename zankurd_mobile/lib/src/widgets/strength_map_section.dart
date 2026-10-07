import 'package:flutter/material.dart';

import '../data/mastery_store.dart';
import '../data/mistake_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/strength_analysis.dart';
import '../utils/error_reporter.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Profildeki "Güçlü ve Geliştirilecek Alanlar" bölümü.
///
/// Ham verileri store'lardan okur, [StrengthAnalysis] ile açıklanabilir
/// içgörülere çevirir. Renk tek başına anlam taşımaz: her satır ikon + metin
/// de taşır. Az veride kesin yargı üretmez, nazik bir bilgi mesajı gösterir.
class StrengthMapSection extends StatefulWidget {
  const StrengthMapSection({required this.isKu, this.refreshSignal, super.key});

  final bool isKu;
  final Listenable? refreshSignal;

  // MockZanKurdRepository._allCategories (gerçek kategori kümesi) ile aynı
  // kalmalı. Bu liste eskiden yalnız sekiz kategoriyi taşıyordu; `Sînema`
  // (2026-07'de eklendi) ve `Teknolojî` (2026-07-26'da dolduruldu) eksikti.
  // profile_widgets.dart'taki `_kProfileAnalysisCategories` aynı kusur için
  // zaten düzeltilmişti (2026-08-14 denetimi) ama bu widget'ın kendi
  // kopyası o konsolidasyonun DIŞINDA kalmıştı — bu iki kategoride ne kadar
  // oynanırsa oynansın "Güçlü ve Geliştirilecek Alanlar" paneli onları hiç
  // aday olarak görmüyordu.
  static const _categories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
    'Sînema',
    'Teknolojî',
    'Cîhan',
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
        readyReviews: mistakeStore.getReadyReviewCountByCategory(),
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'strength_map_section');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _result == null) return const SizedBox.shrink();
    final ku = widget.isKu;
    final result = _result!;

    // 2026-09-29 Şahnê: yüzey kartı (Perde, L pah, gündüzde 1 px kenar);
    // başlık Gövde 700 + öğrenme rolünün ikonu; grup etiketleri kalın
    // açıklama (güçlü: Zêr kupa, geliştirilecek: ikincil metin bayrak —
    // Agir yalnız birincil eylemin dolgusudur); satırda Rast ✓ ya da bayrak.
    final t = SahneTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('strength-map-section'),
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.chartLine, color: t.learnTx, size: 20),
                const SizedBox(width: SahneSpace.x2),
                Expanded(
                  child: Text(
                    Tr.forKu(K.strengthMapTitle, ku),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x3),
            if (result.insufficientData)
              _buildHint(context, ku)
            else ...[
              if (result.strengths.isNotEmpty) ...[
                _buildGroupLabel(
                  context,
                  Tr.forKu(K.strengthStrong, ku),
                  AppIcons.trophy,
                  t.goldTx,
                ),
                for (final i in result.strengths.take(3))
                  _buildRow(context, ku, i, InsightTone.strength),
                const SizedBox(height: SahneSpace.x3),
              ],
              if (result.improvements.isNotEmpty) ...[
                _buildGroupLabel(
                  context,
                  Tr.forKu(K.strengthToImprove, ku),
                  AppIcons.arrowTrendUp,
                  t.tx2,
                ),
                for (final i in result.improvements.take(3))
                  _buildRow(context, ku, i, InsightTone.improve),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHint(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    return Row(
      children: [
        Icon(AppIcons.circleInfo, size: 20, color: t.tx3),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(
            Tr.forKu(K.strengthEmpty, ku),
            style: SahneType.body.copyWith(color: t.tx2),
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
      padding: const EdgeInsets.only(bottom: SahneSpace.x1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: SahneSpace.x2),
          Flexible(
            child: Text(
              label,
              style: SahneType.captionStrong.copyWith(color: tint),
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
    final t = SahneTokens.of(context);
    final name = CategoryNames.localized(insight.category, ku);
    final isStrength = tone == InsightTone.strength;
    // Renk + ikon + metin birlikte anlam taşır.
    final icon = isStrength ? AppIcons.circleCheck : AppIcons.flag;
    final tint = isStrength ? t.okTx : t.tx2;
    final String action;
    if (isStrength) {
      action = Tr.forKu(K.strengthKeepForm, ku);
    } else if (insight.readyReviews > 0) {
      action = Tr.forKu(K.strengthReviewReady, ku);
    } else {
      action = Tr.forKu(K.strengthPractice, ku);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.x1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: SahneSpace.x2),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.bodyStrong.copyWith(color: t.tx),
            ),
          ),
          Flexible(
            child: Text(
              action,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ),
        ],
      ),
    );
  }
}
