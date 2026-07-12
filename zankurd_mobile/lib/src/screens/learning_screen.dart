import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import 'quiz_screen.dart';

/// Kurmancî ders kategorilerini ve dersleri gösterir.
class LearningScreen extends StatefulWidget {
  const LearningScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  static const _categories = [
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
  String _selectedCategory = _categories.first;
  Set<String> _completedIds = const {};
  List<Lesson> _currentLessons = const [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _refreshCompleted();
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
    } catch (_) {}
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
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryColor(context),
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.3,
          fontFamily: 'Rubik',
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
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
                  icon: Icons.school_rounded,
                  compact: true,
                ),
              ),
              // Kategori sekmeler
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _categories
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
                        icon: Icons.school_outlined,
                        title: ku ? 'Ders tune' : 'Ders yok',
                        message: ku
                            ? 'Di vê kategoriyê de hîn ders tune'
                            : 'Henüz ders yok',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      itemCount: lessons.length,
                      itemBuilder: (ctx, i) => _LessonCard(
                        lesson: lessons[i],
                        ku: ku,
                        completed: _completedIds.contains(lessons[i].id),
                        onTap: () async {
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryProgress(BuildContext context, bool ku) {
    final total = _currentLessons.length;
    final completed =
        _currentLessons.where((l) => _completedIds.contains(l.id)).length;
    final ratio = total > 0 ? completed / total : 0.0;
    final pct = (ratio * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.auto_stories_rounded,
                  size: 14, color: AppTheme.playGreen),
              const SizedBox(width: 6),
              Text(
                ku
                    ? 'Dersên qedandî: $completed / $total'
                    : 'Tamamlanan ders: $completed / $total',
                style: TextStyle(
                  color: AppTheme.textSubColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '%$pct',
                style: TextStyle(
                  color: AppTheme.playGreen,
                  fontSize: 12,
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
      'geography': ('Cografya', 'Coğrafya'),
      'emotions': ('Hestan', 'Duygular'),
      'time': ('Demjimêr', 'Zaman'),
    };
    final (kuLabel, trLabel) = labels[cat] ?? (cat, cat);
    return ku ? kuLabel : trLabel;
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
      child: GestureDetector(
        onTap: onTap,
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
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppTheme.textPrimaryColor(context),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
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
    required this.onTap,
  });

  final Lesson lesson;
  final bool ku;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AppPanel(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.playGreen, Color(0xFF3E9A55)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.playGreen.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _iconForLesson(lesson.slug),
                    color: Colors.white,
                    size: 28,
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
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.descriptionKu ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
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
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMutedColor(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForLesson(String slug) {
    const icons = {
      'alphabet': Icons.abc_rounded,
      'numbers': Icons.numbers_rounded,
      'colors': Icons.palette_rounded,
      'family': Icons.family_restroom_rounded,
      'greetings': Icons.waving_hand_rounded,
      'food': Icons.restaurant_rounded,
      'animals': Icons.pets_rounded,
      'geography': Icons.public_rounded,
      'grammar_noun': Icons.text_fields_rounded,
      'grammar_verb': Icons.dynamic_feed_rounded,
      'newroz': Icons.celebration_rounded,
      'body': Icons.accessibility_rounded,
      'clothing': Icons.checkroom_rounded,
      'weather': Icons.cloud_rounded,
      'time': Icons.schedule_rounded,
      'prepositions': Icons.location_on_rounded,
      'emotions': Icons.sentiment_satisfied_rounded,
      'house': Icons.home_rounded,
      'profession': Icons.work_rounded,
      'daily_phrases': Icons.chat_rounded,
    };
    return icons[slug] ?? Icons.school_rounded;
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

  void _onSpeakerTap(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.isKu
              ? 'Telafûz wê zû were zêdekirin'
              : 'Telaffuz yakında eklenecek',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
            enableTimer: true,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku ? 'Quiz nehate barkirin' : 'Quiz yüklenemedi',
            ),
          ),
        );
      }
    }
  }

  Widget _buildKuContentRow(LessonSlide slide, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            slide.contentKu,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _SpeakerButton(
          onTap: () => _onSpeakerTap(slide.contentKu),
        ),
      ],
    );
  }

  Widget _buildFlashcard(
    LessonSlide slide,
    BuildContext context,
    bool ku,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                context.isKu
                    ? 'Ji bo wergerê bitikîne'
                    : 'Çeviri için dokun',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildKuContentRow(slide, context),
          if (slide.exampleKu != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHiColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                slide.exampleKu!,
                style: TextStyle(
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

  Widget _buildFlashcardBack(
    LessonSlide slide,
    BuildContext context,
    bool ku,
  ) {
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            slide.contentTr ?? slide.contentKu,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
          .catchError((_) => false);
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
            icon: Icon(
              _flashcardMode
                  ? Icons.flip_to_front_rounded
                  : Icons.flip_to_back_rounded,
            ),
            tooltip: ku ? 'Moda kartan' : 'Flashcard modu',
            onPressed: _toggleFlashcard,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
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
                        style: TextStyle(
                          color: AppTheme.textSubColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
                        if (slide.imageUrl != null)
                          Container(
                            width: double.infinity,
                            height: 200,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(slide.imageUrl!),
                                fit: BoxFit.cover,
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
                                if (slide.contentTr != null &&
                                    slide.contentTr!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    slide.contentTr!,
                                    style: TextStyle(
                                      color: AppTheme.textSubColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                if (slide.exampleKu != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceHiColor(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      slide.exampleKu!,
                                      style: TextStyle(
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

/// Speaker / pronunciation button with subtle scale animation.
class _SpeakerButton extends StatefulWidget {
  const _SpeakerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<_SpeakerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTap() {
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          Icons.volume_up_rounded,
          color: AppTheme.playGreen,
          size: 22,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: _onTap,
        tooltip: context.isKu ? 'Telafûz' : 'Telaffuz',
      ),
    );
  }
}
