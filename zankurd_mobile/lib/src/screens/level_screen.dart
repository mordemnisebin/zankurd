import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_level.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state.dart';
import '../widgets/zk_back_button.dart';
import '../widgets/app_panel.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/percent_format.dart';
import 'quiz_screen.dart';
import '../config/category_visuals.dart';
import '../config/subcategory_config.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({
    required this.repository,
    required this.category,
    this.subCategory,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;
  final String? subCategory;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  bool _loading = false;
  Set<int> _playedLevels = const {};
  QuizLevel? _retryLevel;
  _LevelLoadState _loadState = _LevelLoadState.ready;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = await LevelProgressStore.load();
    if (!mounted) return;
    setState(() {
      _playedLevels = {
        for (var n = 1; n <= 5; n++)
          if (store.isPlayed(widget.category, widget.subCategory, n)) n,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final levels = widget.repository.levelsForCategory(widget.category);
    final accent = CategoryVisuals.color(widget.category);

    return Scaffold(
      appBar: zkAppBar(context),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            children: [
              _CategoryHero(
                category: widget.category,
                subCategory: widget.subCategory,
                accent: accent,
                isKu: ku,
                completedLevels: _playedLevels.length,
                totalLevels: levels.length,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                child: switch (_loadState) {
                  _LevelLoadState.error => AppErrorState(
                    title: context.t(K.loadFailedShort),
                    message: context.t(K.buSeviyeninSorulariYuklenemedi),
                    retryLabel: context.t(K.retryShort),
                    onRetry: _retrySelectedLevel,
                  ),
                  _LevelLoadState.empty => AppEmptyState(
                    icon: AppIcons.bookOpen,
                    title: context.t(K.noQuestionsForCategory),
                    message: context.t(K.buSeviyeninSorulariYuklenemedi),
                    actionLabel: context.t(K.retryShort),
                    onAction: _retrySelectedLevel,
                  ),
                  _LevelLoadState.ready => _LevelPath(
                    levels: levels,
                    disabled: _loading,
                    isKu: ku,
                    playedLevels: _playedLevels,
                    onOpen: _openLevel,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLevel(QuizLevel level) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _retryLevel = level;
      _loadState = _LevelLoadState.ready;
    });
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: level.category,
        difficultyMin: level.difficultyMin,
        difficultyMax: level.difficultyMax,
        subCategory: widget.subCategory,
        limit: level.questionCount,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() => _loadState = _LevelLoadState.empty);
        return;
      }
      final room = widget.repository
          .createRoom(category: level.category)
          .copyWith(
            // Kategori KİMLİĞİ değil, kullanıcının dilindeki ADI.
            //
            // Burada `level.category` doğrudan yazılıyordu: kimlikler
            // Kurmancî kökenli olduğu için Türkçe arayüzde soru ekranının
            // başlığı "Ziman 1. Seviye" çıkıyor, aynı ekranın kategori çipi
            // ise "Dil" diyordu. Aynı kategori iki adla, tek ekranda
            // (2026-08-16 simülatör taraması).
            name:
                '${CategoryNames.localized(level.category, context.isKu)} '
                '${level.number}. ${context.t(K.progressLevelLabel)}',
            questionCount: questions.length,
          );
      final result = await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            // Kategori seviyeleri bir öğrenme yolunun basamaklarıdır,
            // yarışma değil: süre baskısı olmadan her cevaptan sonra
            // açıklama gösterilir. Varsayılan `competition` bırakıldığında
            // "Ziman → Rêziman → Destpêk" gibi apaçık ders akışlarında
            // kullanıcı yanlışının nedenini hiç öğrenemiyordu
            // (2026-07-25 canlı denetimi). Ana ekranın "Günün Dersi"
            // akışı zaten bu ayarda.
            experience: QuizExperience.learning,
            enableTimer: false,
          ),
        ),
      );
      // Yoldaki düğümü yalnız quiz gerçekten bitince işaretle: sonuç ekranı
      // skor haritasıyla döner; yarıda bırakma null döner ve tik almamalı.
      if (result is Map) {
        final store = await LevelProgressStore.load();
        await store.markPlayed(
          widget.category,
          widget.subCategory,
          level.number,
        );
      }
      await _loadProgress();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'level questions load failed');
      if (!mounted) return;
      setState(() => _loadState = _LevelLoadState.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retrySelectedLevel() {
    final level = _retryLevel;
    if (level != null) _openLevel(level);
  }
}

enum _LevelLoadState { ready, empty, error }

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.completedLevels,
    required this.totalLevels,
    required this.category,
    this.subCategory,
    required this.accent,
    required this.isKu,
  });

  final String category;
  final String? subCategory;
  final Color accent;
  final bool isKu;
  final int completedLevels;
  final int totalLevels;

  @override
  Widget build(BuildContext context) {
    String title = CategoryNames.localized(category, isKu);
    String subtitle = Tr.forKu(K.kolaydanZoraDogruIlerle, isKu);

    if (subCategory != null) {
      final list = SubcategoryConfig.forCategory(category);
      final sub = list.firstWhere(
        (element) => element.id == subCategory,
        orElse: () => const SubcategoryInfo(
          id: '',
          nameKu: '',
          nameTr: '',
          descriptionKu: '',
          descriptionTr: '',
        ),
      );
      if (sub.id.isNotEmpty) {
        title =
            '${CategoryNames.localized(category, isKu)} · ${isKu ? sub.nameKu : sub.nameTr}';
        subtitle = isKu ? sub.descriptionKu : sub.descriptionTr;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Hero(
        tag: 'category_hero_${category}_$subCategory',
        child: Material(
          type: MaterialType.transparency,
          child: AppPanel(
            cardType: CardType.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.iconTileBg(context, accent),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        CategoryVisuals.icon(category),
                        color: AppColors.readableAccent(context, accent),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.heading2.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppTheme.textSubColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (totalLevels > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _HeroProgress(
                    completed: completedLevels,
                    total: totalLevels,
                    isKu: isKu,
                    accent: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero içindeki ince ilerleme şeridi: "2/5 seviye tamam".
///
/// Başlık şeridinin boş kalan alanı süs yerine gerçek bir durum bilgisiyle
/// doldurulur; kullanıcı bu alt kategoride nerede olduğunu haritaya
/// bakmadan görür.
class _HeroProgress extends StatelessWidget {
  const _HeroProgress({
    required this.completed,
    required this.total,
    required this.isKu,
    required this.accent,
  });

  final int completed;
  final int total;
  final bool isKu;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Semantics(
      label: Tr.forKu(K.progressLevelsCompleted, isKu, {
        'completed': '$completed',
        'total': '$total',
      }),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Tr.forKu(K.pPSeviye, isKu, {
                      'p0': '$completed',
                      'p1': '$total',
                    }),
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textSubColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  PercentFormat.ratio(ratio, isKu: isKu),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.readableAccent(context, accent),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                color: accent,
                backgroundColor: AppTheme.surfaceHiColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seviyeleri sakin, tek sütunlu bir eğitim ilerleme listesinde gösterir.
class _LevelPath extends StatelessWidget {
  const _LevelPath({
    required this.levels,
    required this.disabled,
    required this.isKu,
    required this.playedLevels,
    required this.onOpen,
  });

  final List<QuizLevel> levels;
  final bool disabled;
  final bool isKu;
  final Set<int> playedLevels;
  final ValueChanged<QuizLevel> onOpen;

  bool _isUnlocked(int number) {
    if (number <= 1) return true;
    return playedLevels.contains(number - 1);
  }

  int? get _nextNumber {
    for (final level in levels) {
      if (!playedLevels.contains(level.number)) return level.number;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          _LevelNode(
            key: ValueKey('level-node-${levels[i].number}'),
            level: levels[i],
            disabled: disabled,
            isKu: isKu,
            played: playedLevels.contains(levels[i].number),
            isNext: levels[i].number == _nextNumber,
            locked: !_isUnlocked(levels[i].number),
            onTap: () => onOpen(levels[i]),
          ),
          if (i != levels.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    super.key,
    required this.level,
    required this.disabled,
    required this.isKu,
    required this.played,
    required this.isNext,
    required this.locked,
    required this.onTap,
  });

  final QuizLevel level;
  final bool disabled;
  final bool isKu;
  final bool played;
  final bool isNext;
  final bool locked;
  final VoidCallback onTap;

  void _explainLock(BuildContext context) {
    final previous = level.number - 1;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.oncePSeviyeyiTamamla, {'p0': '$previous.'}),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = disabled || locked;
    final name = LevelNames.localized(level.title, isKu);
    const accent = AppTheme.playGreen;
    final muted = AppTheme.textMutedColor(context);
    final indicatorColor = locked
        ? muted
        : AppColors.readableAccent(context, accent);

    return Semantics(
      button: true,
      enabled: !blocked,
      onTap: blocked ? null : onTap,
      label: locked
          ? context.t(K.pKilitliOncekiSeviyeyi, {'p0': name})
          : isNext
          ? context.t(K.homePathNext, {'name': name})
          : name,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled
                ? null
                : locked
                ? () => _explainLock(context)
                : onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              key: ValueKey('level-card-${level.number}'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isNext
                      ? accent.withValues(alpha: 0.48)
                      : AppTheme.borderColor(context),
                  width: isNext ? 1.2 : 1,
                ),
                boxShadow: isNext ? AppTheme.cardShadow(context) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHiColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: locked
                            ? AppTheme.borderColor(context)
                            : accent.withValues(
                                alpha: played || isNext ? 0.42 : 0.24,
                              ),
                      ),
                    ),
                    child: locked
                        ? Icon(AppIcons.lock, color: muted, size: 18)
                        : played
                        ? Icon(AppIcons.check, color: indicatorColor, size: 18)
                        : Text(
                            '${level.number}',
                            style: AppTypography.heading2.copyWith(
                              color: indicatorColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _DifficultyStars(
                              filled: level.difficultyMax.clamp(1, 5),
                              color: locked ? muted : accent,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                '${level.questionCount} ${context.t(K.soru)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (!locked)
                    Icon(
                      AppIcons.chevronRight,
                      color: isNext ? indicatorColor : muted,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zorluğu metin yerine 5'li yıldız dizisiyle gösterir.
///
/// 2026-07-23 canlı UX denetimi M16: yıldızlar "ilerleme" ile
/// karıştırılabiliyordu (asıl ilerleme rozeti ayrı bir tik işaretiyle
/// gösteriliyor). Tooltip + Semantics ile "zorluk" anlamı netleştirildi.
class _DifficultyStars extends StatelessWidget {
  const _DifficultyStars({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final label = Tr.forKu(K.zorlukUzerindenPYildiz, isKu, {'p0': '$filled'});
    return Tooltip(
      message: Tr.forKu(K.zorluk, isKu),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          // Zorluk yıldızla gösteriliyordu. Yıldız, quiz uygulamalarında
          // neredeyse her yerde *kazanılmış başarıyı* anlatır; hiç
          // oynamamış oyuncu seviye kartında "2/5 dolu yıldız" görünce
          // bunu kendi skoru sanıyordu (2026-07-25 canlı denetimi).
          // Yükselen çubuklar zorluğu tek anlama gelecek biçimde anlatır.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 3,
                    height: 4.0 + i * 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1.5),
                      color: i <= filled
                          ? color
                          : AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
