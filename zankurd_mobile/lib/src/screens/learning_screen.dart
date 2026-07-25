import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/lesson.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../services/placement_scoring.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'story_screen.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/todays_review_card.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Kurmancî ders kategorilerini ve dersleri gösterir.
class LearningScreen extends StatefulWidget {
  const LearningScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  // M-9: Kurmancî ders kategorilerinin DB anahtar (ID) listesi.
  // Bu değerler `lessons` tablosundaki `category` sütunuyla eşleşir;
  // backend şemасı değişirse burası da güncellenmeli.
  // Yeni kategori eklemek için listeye eklemek yeterli — UI otomatik güncellenir.
  static const _kLearningCategoryIds = [
    'everyday',
    'grammar',
    'culture',
    'food',
    'animals',
    'geography',
    'emotions',
    'time',
  ];

  late Future<List<Lesson>> _lessonsFuture;
  String _selectedCategory = _kLearningCategoryIds.first;
  Set<String> _completedIds = const {};
  List<Lesson> _currentLessons = const [];
  PlacementLevel? _placementLevel;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _refreshCompleted();
    _loadPlacementLevel();
  }

  Future<void> _loadPlacementLevel() async {
    try {
      final store = await PlacementStore.load();
      if (mounted) setState(() => _placementLevel = store.level);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_load_progress');
    }
  }

  void _loadLessons() {
    _lessonsFuture = widget.repository
        .loadLessonsByCategory(_selectedCategory)
        .then((lessons) {
          if (mounted) setState(() => _currentLessons = lessons);
          return lessons;
        });
  }

  Future<void> _refreshCompleted() async {
    try {
      final ids = await widget.repository.loadCompletedLessonIds();
      if (mounted) setState(() => _completedIds = ids);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_load_placement');
    }
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _loadLessons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(ku ? 'Fêr Bibe' : 'Öğren'),
        titleTextStyle: AppTypography.heading1.copyWith(
          color: AppTheme.textPrimaryColor(context),
          fontSize: 22,
          letterSpacing: -0.3,
        ),
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: Column(
            children: [
              // Ekran kimliği: playGreen "öğrenme" bandı — Xwendin'in imzası.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  0,
                ),
                child: ScreenIdentityHeader(
                  title: ku ? 'Kurmancî hîn bibe' : 'Kurmancî öğren',
                  subtitle: ku
                      ? 'Ders bi ders, mijar bi mijar'
                      : 'Ders ders, konu konu ilerle',
                  accent: AppTheme.playGreen,
                  icon: AppIcons.graduationCap,
                  compact: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: _LearningSectionHeading(
                  title: ku ? 'Armanca îro' : 'Bugünkü hedefin',
                  subtitle: ku
                      ? 'Dubarekirin û dersa dawî li vir in.'
                      : 'Tekrarların ve kaldığın ders burada.',
                ),
              ),
              // Akıllı tekrar (SM-2) ürün yüzü: yalnız hazır tekrar varsa
              // dokunulabilir kart, yoksa sakin bir tamamlandı durumu.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  0,
                ),
                child: TodaysReviewCard(
                  repository: widget.repository,
                  isKu: ku,
                ),
              ),
              // Hikâye modu girişi (metin tabanlı, sessiz). Ünite başında mini
              // rehber de buradan açılır.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  0,
                ),
                // Dar ekranlarda (360px) ikon+metin taşmasını önlemek için
                // tam genişlik: intrinsic genişlik dar viewport'ta sığmıyordu.
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('learning-story-entry'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoryScreen(
                          story: cayxaneStory,
                          guide: cayxaneGuide,
                        ),
                      ),
                    ),
                    icon: const Icon(AppIcons.bookOpenReader, size: 18),
                    label: Text(
                      ku ? 'Çîrok: Li Çayxanê' : 'Hikâye: Çay Evinde',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: _LearningSectionHeading(
                  title: ku ? 'Rêyên hînbûnê' : 'Öğrenme yolları',
                  subtitle: ku
                      ? 'Mijarek hilbijêre û gav bi gav pêşve here.'
                      : 'Bir konu seç ve adım adım ilerle.',
                ),
              ),
              // Kategori sekmeler
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _kLearningCategoryIds
                      .map(
                        (cat) => _CategoryTab(
                          key: ValueKey('learning-tab-$cat'),
                          label: _categoryLabel(cat, ku),
                          isSelected: cat == _selectedCategory,
                          onTap: () => _selectCategory(cat),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  0,
                ),
                child: _LearningModeBar(
                  isKu: ku,
                  hasLesson: _currentLessons.isNotEmpty,
                  onPractice: _openCategoryPractice,
                  onFlashcards: _openCategoryFlashcards,
                  onLesson: _openCategoryFlashcards,
                ),
              ),
              // Kategori ilerleme göstergesi
              _buildCategoryProgress(context, ku),
              // Derslerin listesi
              Expanded(
                child: FutureBuilder<List<Lesson>>(
                  future: _lessonsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.playGreen,
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return AppErrorState(
                        title: ku ? 'Barnebû' : 'Yüklenemedi',
                        message: ku
                            ? 'Ders nehatin barkirin'
                            : 'Dersler yüklenemedi',
                        retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar',
                        onRetry: () => setState(() => _loadLessons()),
                      );
                    }
                    final lessons = snap.data ?? [];
                    if (lessons.isEmpty) {
                      return AppEmptyState(
                        icon: AppIcons.graduationCap,
                        title: ku ? 'Ders tune' : 'Ders yok',
                        message: ku
                            ? 'Di vê kategoriyê de hîn ders tune'
                            : 'Henüz ders yok',
                      );
                    }
                    final firstOpenIndex = lessons.indexWhere(
                      (lesson) => !_completedIds.contains(lesson.id),
                    );
                    // Seviye belirlemeye göre önerilen başlangıç düğümü.
                    // Yalnız görsel işaret: kilit/tamamlanma değişmez.
                    final placementIndex =
                        PlacementScoring.recommendedStartIndex(
                          _placementLevel,
                          lessons.length,
                        );
                    // Öneri kilitli bir düğüme düşerse kullanıcıyı erişemeyeceği
                    // bir karta yönlendirme; ilk açık dersi işaretle.
                    final recommendedIndex =
                        firstOpenIndex >= 0 && placementIndex > firstOpenIndex
                        ? firstOpenIndex
                        : placementIndex;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      itemCount: lessons.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == lessons.length) {
                          return _MasteryGoal(
                            completed: firstOpenIndex == -1,
                            ku: ku,
                          );
                        }
                        final completed = _completedIds.contains(lessons[i].id);
                        final current =
                            i ==
                            (firstOpenIndex < 0
                                ? lessons.length
                                : firstOpenIndex);
                        final locked = !completed && !current;
                        return _LearningPathNode(
                          key: ValueKey('learning-path-node-${lessons[i].id}'),
                          index: i,
                          completed: completed,
                          current: current,
                          locked: locked,
                          child: _LessonCard(
                            lesson: lessons[i],
                            ku: ku,
                            completed: completed,
                            locked: locked,
                            recommended: i == recommendedIndex,
                            onTap: () async {
                              if (locked) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonDetailScreen(
                                    lesson: lessons[i],
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                              _refreshCompleted();
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCategoryPractice() async {
    if (_currentLessons.isEmpty || !mounted) return;
    final lesson = _currentLessons.first;
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: lesson.category,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 10,
      );
      if (!mounted || questions.isEmpty) return;
      final room = widget.repository
          .createRoom(category: lesson.category)
          .copyWith(questionCount: questions.length);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_category_practice');
    }
  }

  Future<void> _openCategoryFlashcards() async {
    if (_currentLessons.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          lesson: _currentLessons.first,
          repository: widget.repository,
        ),
      ),
    );
    _refreshCompleted();
  }

  Widget _buildCategoryProgress(BuildContext context, bool ku) {
    final total = _currentLessons.length;
    final completed = _currentLessons
        .where((l) => _completedIds.contains(l.id))
        .length;
    final ratio = total > 0 ? completed / total : 0.0;
    final pct = (ratio * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                AppIcons.bookOpenReader,
                size: 14,
                color: AppTheme.playGreen,
              ),
              const SizedBox(width: 6),
              // Kategori başına ders sayısı arttıkça metin uzayabilir; dar
              // ekranda (360px) taşmasın diye Expanded + ellipsis.
              Expanded(
                child: Text(
                  ku
                      ? 'Dersên qedandî: $completed / $total'
                      : 'Tamamlanan ders: $completed / $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textSubColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '%$pct',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.playGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppTheme.surfaceHiColor(context),
              color: AppTheme.playGreen,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String cat, bool ku) {
    const labels = {
      'everyday': ('Roj-beroj', 'Günlük'),
      'grammar': ('Gramer', 'Dilbilgisi'),
      'culture': ('Çand', 'Kültür'),
      'food': ('Xwarin', 'Yemek'),
      'animals': ('Ajal', 'Hayvanlar'),
      'geography': ('Erdnîgarî', 'Coğrafya'),
      'emotions': ('Hestan', 'Duygular'),
      'time': ('Demjimêr', 'Zaman'),
    };
    final (kuLabel, trLabel) = labels[cat] ?? (cat, cat);
    return ku ? kuLabel : trLabel;
  }
}

class _LearningModeBar extends StatelessWidget {
  const _LearningModeBar({
    required this.isKu,
    required this.hasLesson,
    required this.onPractice,
    required this.onFlashcards,
    required this.onLesson,
  });

  final bool isKu;
  final bool hasLesson;
  final VoidCallback onPractice;
  final VoidCallback onFlashcards;
  final VoidCallback onLesson;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.question,
            label: isKu ? 'Pirsan' : 'Soru çöz',
            color: AppTheme.playCyan,
            enabled: hasLesson,
            onTap: onPractice,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.paintbrush,
            label: isKu ? 'Kart' : 'Flaş kart',
            color: AppTheme.violet,
            enabled: hasLesson,
            onTap: onFlashcards,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.bookOpen,
            label: isKu ? 'Ders' : 'Dersler',
            color: AppTheme.playGreen,
            enabled: true,
            onTap: onLesson,
          ),
        ),
      ],
    );
  }
}

class _LearningModeButton extends StatelessWidget {
  const _LearningModeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // 2026-07-23 canlı UX denetimi: içerideki Text(label) ayrıca kendi
      // semantics düğümünü ekleyip çift okumaya yol açıyordu (M28 devamı).
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: enabled ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: enabled ? Colors.white : color.withValues(alpha: 0.4),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: enabled
                      ? Colors.white
                      : AppTheme.textPrimaryColor(
                          context,
                        ).withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningSectionHeading extends StatelessWidget {
  const _LearningSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // Xwendin kimliği: seçili sekme düz playGreen dolgu taşır.
            color: isSelected ? AppTheme.playGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : AppTheme.borderColor(context).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppTheme.textPrimaryColor(context),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.ku,
    required this.completed,
    required this.locked,
    required this.onTap,
    this.recommended = false,
  });

  final Lesson lesson;
  final bool ku;
  final bool completed;
  final bool locked;
  final VoidCallback onTap;

  /// Seviye belirlemeye göre önerilen başlangıç düğümü mü. Yalnız görsel bir
  /// işarettir; kilit/tamamlanma durumunu değiştirmez.
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        onTap: locked ? null : onTap,
        key: recommended && !completed
              ? const ValueKey("learning-next-step")
              : null,
          cardType: recommended && !completed
              ? CardType.primary
              : CardType.secondary,
          child: Row(
            children: [
              Container(
                width: 56,
                constraints: const BoxConstraints(minHeight: 56),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.playGreen, Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Center(
                  child: Icon(
                    _iconForLesson(lesson.slug),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.titleKu,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.descriptionKu ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                    if (recommended && !completed) ...[
                      const SizedBox(height: 6),
                      Container(
                        key: const ValueKey('lesson-recommended-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Icon(
                              AppIcons.star,
                              size: 12,
                              color: AppTheme.gold,
                            ),
                            Text(
                              ku ? 'Pêşniyara te' : 'Sana önerilen',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                            Text(
                              ku ? 'Bidomîne' : 'Devam et',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (completed)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.correctGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.correct.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else if (locked)
                Icon(AppIcons.lock, color: AppTheme.textMutedColor(context))
              else
                Icon(
                  AppIcons.chevronRight,
                  color: AppTheme.textMutedColor(context),
                ),
            ],
          ),
        ),
    );
  }

  IconData _iconForLesson(String slug) {
    const icons = {
      'alphabet': AppIcons.font,
      'numbers': AppIcons.hashtag,
      'colors': AppIcons.palette,
      'family': AppIcons.peopleRoof,
      'greetings': AppIcons.hand,
      'food': AppIcons.utensils,
      'animals': AppIcons.paw,
      'geography': AppIcons.globe,
      'grammar_noun': AppIcons.font,
      'grammar_verb': AppIcons.barsStaggered,
      'newroz': AppIcons.champagneGlasses,
      'body': AppIcons.personCircleCheck,
      'clothing': AppIcons.shirt,
      'weather': AppIcons.cloud,
      'time': AppIcons.clock,
      'prepositions': AppIcons.locationDot,
      'emotions': AppIcons.faceSmile,
      'house': AppIcons.house,
      'profession': AppIcons.briefcase,
      'daily_phrases': AppIcons.comment,
    };
    return icons[slug] ?? AppIcons.graduationCap;
  }
}

class _LearningPathNode extends StatelessWidget {
  const _LearningPathNode({
    required this.index,
    required this.completed,
    required this.current,
    required this.locked,
    required this.child,
    super.key,
  });

  final int index;
  final bool completed;
  final bool current;
  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? AppTheme.playGreen
        : current
        ? AppTheme.brand
        : AppTheme.borderColor(context);
    return Stack(
      children: [
        Positioned(
          left: 27,
          top: 0,
          bottom: 0,
          child: Container(width: 3, color: color.withValues(alpha: 0.45)),
        ),
        Padding(
          padding: EdgeInsets.only(left: index.isEven ? 0 : AppSpacing.lg),
          child: Opacity(opacity: locked ? 0.58 : 1, child: child),
        ),
      ],
    );
  }
}

class _MasteryGoal extends StatelessWidget {
  const _MasteryGoal({required this.completed, required this.ku});

  final bool completed;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('learning-mastery-goal'),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: completed ? 0.20 : 0.09),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.medal, color: AppTheme.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ku ? 'Armanca mastery ya kategoriyê' : 'Kategori mastery hedefi',
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ders slaytlarını gösterir ve ilerleme izler.
class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    required this.lesson,
    required this.repository,
    super.key,
  });

  final Lesson lesson;
  final ZanKurdRepository repository;

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with TickerProviderStateMixin {
  late Future<List<LessonSlide>> _slidesFuture;
  int _currentSlideIndex = 0;

  // Flashcard modu
  bool _flashcardMode = false;
  bool _isFlipped = false;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _slidesFuture = widget.repository.loadLessonSlides(widget.lesson.id);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlashcard() {
    setState(() {
      _flashcardMode = !_flashcardMode;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _toggleFlip() {
    if (!_flashcardMode) return;
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _startMiniQuiz() async {
    final ku = context.isKu;
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: widget.lesson.category,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 5,
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku
                  ? 'Ji bo vê kategoriyê pirs nehatin dîtin'
                  : 'Bu kategori için soru bulunamadı',
            ),
          ),
        );
        return;
      }

      final room = widget.repository
          .createRoom(category: widget.lesson.category)
          .copyWith(questionCount: questions.length);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            practice: true,
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_load_story');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ku ? 'Quiz nehate barkirin' : 'Quiz yüklenemedi'),
          ),
        );
      }
    }
  }

  Widget _buildKuContentRow(LessonSlide slide, BuildContext context) {
    return Text(
      slide.contentKu,
      style: AppTypography.bodyLarge.copyWith(
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildFlashcard(LessonSlide slide, BuildContext context, bool ku) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final showFront = _flipAnimation.value < 0.5;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: showFront
                ? _buildFlashcardFront(slide, context)
                : Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildFlashcardBack(slide, context, ku),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFlashcardFront(LessonSlide slide, BuildContext context) {
    return AppPanel(
      cardType: CardType.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.handPointer,
                size: 14,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                context.isKu ? 'Ji bo wergerê bitikîne' : 'Çeviri için dokun',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildKuContentRow(slide, context),
          if (slide.exampleKu case final exampleKu?) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHiColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                exampleKu,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textSubColor(context),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlashcardBack(LessonSlide slide, BuildContext context, bool ku) {
    return AppPanel(
      gradient: const LinearGradient(
        colors: [AppTheme.playCyan, Color(0xFF2A9D8F)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ku ? 'Werger' : 'Çeviri',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            slide.contentTr ?? slide.contentKu,
            style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _markCompleted() async {
    final success = await widget.repository.markLessonCompleted(
      widget.lesson.id,
    );
    if (success && mounted) {
      widget.repository
          .logAnalyticsEvent('lesson_completed', {
            'lesson_id': widget.lesson.id,
            'lesson_slug': widget.lesson.slug,
            'category': widget.lesson.category,
          })
          .catchError((error, stack) {
            ErrorReporter.record(error, stack, reason: 'log_lesson_completed');
            return false;
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.isKu ? 'Ders qediya!' : 'Ders tamamlandı'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.titleKu),
        actions: [
          IconButton(
            icon: Icon(_flashcardMode ? AppIcons.clone : AppIcons.layerGroup),
            tooltip: ku ? 'Moda kartan' : 'Flashcard modu',
            onPressed: _toggleFlashcard,
          ),
        ],
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: FutureBuilder<List<LessonSlide>>(
          future: _slidesFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.playGreen),
              );
            }
            if (snap.hasError) {
              return Center(
                child: AppErrorState(
                  title: ku ? 'Barnebû' : 'Yüklenemedi',
                  message: ku
                      ? 'Slaytên dersê nehatin barkirin'
                      : 'Slaytlar yüklenemedi',
                  retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar',
                  onRetry: () => setState(() {}),
                ),
              );
            }
            final slides = snap.data ?? [];
            if (slides.isEmpty) {
              return Center(child: Text(ku ? 'Slayt tune' : 'Slayt yok'));
            }
            final slide = slides[_currentSlideIndex];
            final isLast = _currentSlideIndex == slides.length - 1;

            return Column(
              children: [
                // Slayt ilerleme göstergesi
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_currentSlideIndex + 1) / slides.length,
                            minHeight: 6,
                            backgroundColor: AppTheme.surfaceHiColor(context),
                            color: AppTheme.playGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_currentSlideIndex + 1}/${slides.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textSubColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Slide content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (slide.imageUrl case final imgUrl?)
                          Container(
                            width: double.infinity,
                            height: 200,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imgUrl.startsWith('asset://')
                                  ? Image.asset(
                                      imgUrl.replaceFirst('asset://', ''),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox(),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppTheme.surfaceHiColor(context),
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.brand.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: AppTheme.surfaceHiColor(context),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          AppIcons.image,
                                          color: AppTheme.textMutedColor(context),
                                          size: 32,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        if (_flashcardMode)
                          _buildFlashcard(slide, context, ku)
                        else
                          AppPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildKuContentRow(slide, context),
                                if (slide.contentTr case final contentTr?
                                    when contentTr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    contentTr,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppTheme.textSubColor(context),
                                    ),
                                  ),
                                ],
                                if (slide.exampleKu case final exampleKu?) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceHiColor(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      exampleKu,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppTheme.textSubColor(context),
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Navigation
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      if (_currentSlideIndex > 0)
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              setState(() => _currentSlideIndex--);
                            },
                            child: Text(ku ? 'Paş' : 'Geri'),
                          ),
                        ),
                      if (_currentSlideIndex > 0) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: isLast
                              ? _markCompleted
                              : () {
                                  setState(() => _currentSlideIndex++);
                                },
                          child: Text(
                            isLast
                                ? (ku ? 'Biqedîne' : 'Tamamla')
                                : (ku ? 'Pêş' : 'İleri'),
                          ),
                        ),
                      ),
                      if (isLast) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.playCyan,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _startMiniQuiz,
                            child: Text(ku ? 'Quiz-a Kurt' : 'Mini Quiz'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
