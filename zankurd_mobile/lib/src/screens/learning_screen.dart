import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/lesson.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../services/placement_scoring.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/percent_format.dart';
import '../utils/error_reporter.dart';
import 'story_screen.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/todays_review_card.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Öğrenme yolunda "şu an aktif/önerilen" düğümün indeksi.
///
/// Yerleştirme sınavı yalnız hiçbir ders tamamlanmamışken öğrenme yoluna
/// GERÇEK bir başlangıç noktası önerir — ileri seviyeye yerleşen kullanıcı
/// en baştan başlamaz. `PlacementScoring.recommendedStartIndex`in kendi
/// belgesi önceki dersleri "tamamlandı" YAPMADIĞINI söylüyor; burada da
/// öyle — yalnız erişilebilir/işaretli kılınırlar, sahte bir tamamlanma
/// uydurulmaz.
///
/// Bir kez gerçek ilerleme kaydedildiyse (herhangi bir ders tamamlandıysa)
/// doğal sıralı ilerleme placement'ın önüne geçer ve bir daha geri
/// dönülmez.
///
/// ESKİ KUSUR (2026-08-14 denetimi): öneri kilitli bir düğüme düşerse HER
/// ZAMAN ilk açık derse geriliyordu — bu, ileri seviyeli hiçbir kullanıcıda
/// yerleştirmenin görünür bir etkisi olmadığı anlamına geliyordu (sınav
/// sonucu yolu değiştirmiyordu). İlk ders tamamlanır tamamlanmaz da aynı
/// geri dönüş öneriyi o tamamlanan derste sonsuza dek KİLİTLİYORDU —
/// "Sana önerilen" rozeti bir daha hiçbir karta düşmüyordu.
int learningRecommendedIndex({
  required List<Lesson> lessons,
  required Set<String> completedLessonIds,
  required int placementIndex,
}) {
  if (completedLessonIds.isEmpty) return placementIndex;
  return lessons.indexWhere(
    (lesson) => !completedLessonIds.contains(lesson.id),
  );
}

/// Öğrenme konusunu (`Lesson.category`) soru bankası kategorisine çevirir.
///
/// İki taraf FARKLI isim uzayında yaşıyordu: dersler konuşma/dilbilgisi
/// konularıyla (`everyday`, `grammar`, `food`, `animals`, `emotions`,
/// `time`) etiketlenir, soru bankası ise geniş konu alanlarıyla (`Ziman`,
/// `Çand`, `Cografya`...). `loadLevelQuestions(category: lesson.category)`
/// hiçbir zaman eşleşmiyordu; havuz boş kalınca depo TÜM kategorilerin
/// karışımına düşüyordu — "Soru Çöz" ve mini quiz dersle hiç ilgisi
/// olmayan rastgele sorular getiriyordu (2026-08-14 denetimi).
///
/// `culture`/`geography` soru bankasında birebir karşılığı olan (Çand,
/// Cografya) tek konulardır — uydurulmadı. Geri kalan altısı (günlük
/// konuşma, dilbilgisi, yemek, hayvan, duygu, zaman kelime dağarcığı)
/// hepsi temelde Kürtçe SÖZ VARLIĞI dersleridir; bankanın buna karşılık
/// gelen tek geniş kategorisi `Ziman`dır (dil).
String quizCategoryForLesson(String lessonCategory) => switch (lessonCategory) {
  'culture' => 'Çand',
  'geography' => 'Cografya',
  _ => 'Ziman',
};

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
  bool _lessonsLoading = false;

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
    if (_lessonsLoading) return;
    _lessonsLoading = true;
    _lessonsFuture = widget.repository
        .loadLessonsByCategory(_selectedCategory)
        .then(
          (lessons) {
            if (mounted) {
              setState(() {
                _currentLessons = lessons;
                _lessonsLoading = false;
              });
            }
            return lessons;
          },
          onError: (Object error, StackTrace stack) {
            if (mounted) setState(() => _lessonsLoading = false);
            ErrorReporter.record(error, stack, reason: 'learning_load_lessons');
            throw error;
          },
        );
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
    if (_lessonsLoading) return;
    setState(() {
      _selectedCategory = category;
      _loadLessons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final unifiedScroll = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Scaffold(
      extendBodyBehindAppBar: true,
      // AppBar başlıksız: ekranın adını `ScreenIdentityHeader` taşıyor.
      //
      // Burada başlık da verilince iki yakın anlamlı başlık üst üste
      // biniyordu — "Öğren" ve hemen altında "Kurmancî öğren" (2026-07-30
      // ekran turu, 55/56). Kimlik bandı kullanan on ekranın sekizi AppBar
      // başlığını zaten boş bırakıyor; aykırı olan buydu. Oyuncu hangi
      // sekmede olduğunu alt gezinme çubuğundan görüyor.
      appBar: AppBar(),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final content = Column(
                // `Column`un varsayılanı `center`dır ve bölüm başlıkları
                // metin genişliğinde daralan `Column`lar olduğu için ekranın
                // ortasına kaçıyordu: sayfa başlığı "Öğren" solda, hemen
                // altındaki "Bugünkü hedefin" ve "Öğrenme yolları" ortada
                // duruyordu (2026-07-30 ekran turu, 55/56). Uygulamanın geri
                // kalanında bütün bölüm başlıkları sola dayalı.
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      title: context.t(K.learnKurmanci),
                      subtitle: context.t(K.learnSubtitle),
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
                      title: context.t(K.todaysGoal),
                      subtitle: context.t(K.todaysGoalSub),
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
                          AppRoute(
                            page: StoryScreen(
                              story: cayxaneStory,
                              guide: cayxaneGuide,
                            ),
                          ),
                        ),
                        icon: const Icon(AppIcons.bookOpenReader, size: 18),
                        label: Text(
                          context.t(K.storyTeahouse),
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
                      title: context.t(K.learningPaths),
                      subtitle: context.t(K.learningPathsSub),
                    ),
                  ),
                  // Kategori sekmeler
                  //
                  // Sağ kenarda solma maskesi: satır ekrana sığmıyor ve
                  // son çip kelime ortasından kesiliyordu ("Ha…"). Sert
                  // kesik "yazı taştı" gibi okunuyor; solma ise
                  // "devamı var, kaydır" der (2026-07-31 denetimi).
                  SizedBox(
                    height: 60,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        // Son %8'de opaklıktan saydama iner.
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.92, 1.0],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
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
                  // Derslerin listesi. Büyük erişilebilirlik yazısında bütün
                  // ekran tek yüzey olarak kayar; normal ölçekte üst araçlar
                  // sabit, ders listesi bağımsız kalır.
                  if (unifiedScroll)
                    _buildLessons(context, ku, embedded: true)
                  else
                    Expanded(child: _buildLessons(context, ku)),
                ],
              );
              return unifiedScroll
                  ? SingleChildScrollView(child: content)
                  : content;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLessons(BuildContext context, bool ku, {bool embedded = false}) {
    return FutureBuilder<List<Lesson>>(
      future: _lessonsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: embedded ? 180 : null,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.playGreen),
            ),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: context.t(K.loadFailedShort),
            message: context.t(K.lessonsLoadFail),
            retryLabel: context.t(K.retryShort),
            onRetry: () => setState(() => _loadLessons()),
          );
        }
        final lessons = snap.data ?? [];
        if (lessons.isEmpty) {
          return AppEmptyState(
            icon: AppIcons.graduationCap,
            title: context.t(K.noLesson),
            message: context.t(K.noLessonInCategory),
            actionLabel: context.t(K.retryShort),
            onAction: _loadLessons,
          );
        }
        final placementIndex = PlacementScoring.recommendedStartIndex(
          _placementLevel,
          lessons.length,
        );
        final firstOpenIndex = learningRecommendedIndex(
          lessons: lessons,
          completedLessonIds: _completedIds,
          placementIndex: placementIndex,
        );
        final recommendedIndex = firstOpenIndex;
        return ListView.builder(
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          itemCount: lessons.length + 1,
          itemBuilder: (ctx, i) {
            if (i == lessons.length) {
              return _MasteryGoal(completed: firstOpenIndex == -1, ku: ku);
            }
            final completed = _completedIds.contains(lessons[i].id);
            final current =
                i == (firstOpenIndex < 0 ? lessons.length : firstOpenIndex);
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
                    AppRoute(
                      page: LessonDetailScreen(
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
    );
  }

  Future<void> _openCategoryPractice() async {
    if (_currentLessons.isEmpty || !mounted) return;
    final lesson = _currentLessons.first;
    final quizCategory = quizCategoryForLesson(lesson.category);
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: quizCategory,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 10,
      );
      if (!mounted || questions.isEmpty) return;
      final room = widget.repository
          .createRoom(category: quizCategory)
          .copyWith(questionCount: questions.length);
      await Navigator.of(context).push(
        AppRoute(
          page: QuizScreen(
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
      AppRoute(
        page: LessonDetailScreen(
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
                  context.t(K.lessonsCompleted, {
                    'completed': '$completed',
                    'total': '$total',
                  }),
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
                // Sabit Türkçe önek Kurmancî arayüzde de "%0" yazıyordu;
                // aynı ekranda ana ekran "0%" gösterirken (2026-07-27).
                context.percent(pct),
                style: AppTypography.caption.copyWith(
                  color: AppColors.readableAccent(context, AppTheme.playGreen),
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
      'everyday': ('Rojane', 'Günlük'),
      'grammar': ('Gramer', 'Dilbilgisi'),
      'culture': ('Çand', 'Kültür'),
      'food': ('Xwarin', 'Yemek'),
      'animals': ('Ajal', 'Hayvanlar'),
      'geography': ('Erdnîgarî', 'Coğrafya'),
      'emotions': ('Hest', 'Duygular'),
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
    // Üçü de aynı işin üç kipi: eşit ağırlıkta, tek renk ailesinde.
    //
    // Önce üçü ayrı renkteydi (camgöbeği / mor / yeşil) ve her biri dolu
    // zeminliydi. Aynı ekranda hemen altlarında turuncu "önerilen ders"
    // kartı da vardı; dört doygun renk aynı anda dikkat istiyordu ve gözün
    // nereye gideceği belirsizdi (2026-07-30 ekran turu, 55/56). Vurgu
    // asıl eylemde kalsın diye üçü de öğrenme kimliğinin tonuna çekildi.
    return Row(
      children: [
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.question,
            label: Tr.forKu(K.soruCoz, isKu),
            enabled: hasLesson,
            onTap: onPractice,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.paintbrush,
            label: Tr.forKu(K.flasKart, isKu),
            enabled: hasLesson,
            onTap: onFlashcards,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LearningModeButton(
            icon: AppIcons.bookOpen,
            label: Tr.forKu(K.lessons, isKu),
            // Diğer ikisi (Soru Çöz/Flaş Kart) `hasLesson`e bakıyordu, bu
            // hep `true` idi: kategoride ders yokken düğme AÇIK
            // görünüyor, dokununca `_openCategoryFlashcards`in erken
            // dönüşü (`if (_currentLessons.isEmpty) return;`) yüzünden
            // sessizce hiçbir şey olmuyordu (2026-08-14 denetimi).
            enabled: hasLesson,
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
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            // Tonlu (dolu değil) yüzey: üç kip birer ikincil eylem olarak
            // okunur, asıl vurgu önerilen ders kartında kalır.
            color: AppTheme.playGreen.withValues(alpha: enabled ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppTheme.playGreen.withValues(
                alpha: enabled ? 0.32 : 0.12,
              ),
            ),
          ),
          child: Column(
            children: [
              // Tonlu zeminde metin/ikon rengi `onTintedSurface`ten gelir:
              // gerçek zemin harmanlanmış renktir, düz yüzeye göre seçilen
              // tonlar orada eşiğin altına düşüyordu.
              Icon(
                icon,
                color: enabled
                    ? AppColors.onTintedSurface(context)
                    : AppColors.onTintedSurface(
                        context,
                        secondary: true,
                      ).withValues(alpha: 0.45),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: enabled
                      ? AppColors.onTintedSurface(context)
                      : AppColors.onTintedSurface(
                          context,
                          secondary: true,
                        ).withValues(alpha: 0.45),
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
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: largeText ? 0 : 12,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: largeText ? 0 : 8,
          ),
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
    // Önerilen ders kartı `CardType.primary` ile marka gradyanına boyanır;
    // metinler ise açık zemin için seçilmiş koyu/gri renklerdi. Turuncu
    // gradyan üzerinde açıklama satırı okunmuyordu ve ok işareti kayboluyordu
    // — hem de ekranın en önemli kartında (2026-07-27, canlı gezinti).
    final onGradient = recommended && !completed;
    final titleColor = onGradient
        ? Colors.white
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = onGradient
        ? Colors.white.withValues(alpha: 0.86)
        : AppTheme.textMutedColor(context);
    final trailingColor = onGradient
        ? Colors.white.withValues(alpha: 0.9)
        : AppTheme.textMutedColor(context);

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
                  iconForLesson(lesson),
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
                    // Ders adının Türkçesi modelde var (`titleTr`) ve depo
                    // onu dolduruyor, ama kart her zaman Kurmancî adı
                    // yazıyordu: Türkçe arayüzde ders listesi
                    // "Silavkirin / Nasandin" diye görünüyordu
                    // (2026-07-27, karanlık tema taraması).
                    ku ? lesson.titleKu : (lesson.titleTr ?? lesson.titleKu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.descriptionKu ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: subtitleColor),
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
                        // Rozet gradyanın üstünde duruyor: altın altın
                        // üstünde kayboluyordu.
                        // Beyaz perde kartı açıyordu ve rozetin beyaz
                        // metni 3.70:1'e düşüyordu — rozet, üstünde
                        // durduğu karttan daha az okunur hâle geliyordu.
                        // Koyu perde ters yönde çalışır: zemin koyulaşır,
                        // metin belirginleşir (2026-07-27).
                        color: AppColors.heroScrim(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          const Icon(
                            AppIcons.star,
                            size: 12,
                            color: Colors.white,
                          ),
                          Text(
                            // Rozette iki ayrı etiket yan yana duruyordu
                            // ("Sana önerilen" + "Devam et") ve tek bir
                            // cümleymiş gibi okunuyordu: "Pêşniyara te
                            // Bidomîne". Rozetin işi tavsiyeyi söylemek;
                            // "devam et" zaten kartın kendisi ve ucundaki
                            // ok (2026-07-27 Kurmancî taraması).
                            context.t(K.recommendedForYou),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
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
              Icon(AppIcons.lock, color: trailingColor)
            else
              Icon(AppIcons.chevronRight, color: trailingColor),
          ],
        ),
      ),
    );
  }
}

/// Sunucunun gönderdiği Material ikon adı (`icon_name`, ör. `numbers`,
/// `waving_hand`) → uygulamanın kendi ikon kümesi.
///
/// `2026-07-06_lesson_seed.sql`deki gerçek 15 dersin HER SATIRINDA bu
/// sütun dolu; ders başına ayrı, anlamlı bir ikon taşır.
const Map<String, IconData> _lessonIconNameMap = {
  'waving_hand': AppIcons.hand,
  'numbers': AppIcons.hashtag,
  'person': AppIcons.user,
  'local_fire_department': AppIcons.fire,
  'music_note': AppIcons.music,
  'restaurant': AppIcons.utensils,
  'eco': AppIcons.leaf,
  'pets': AppIcons.paw,
  'forest': AppIcons.tree,
  'landscape': AppIcons.mountain,
  'map': AppIcons.locationDot,
  'favorite': AppIcons.heart,
  'calendar_today': AppIcons.calendarDays,
  'wb_sunny': AppIcons.sun,
};

/// Ders KONUSUNDAN (`Lesson.category`) ikon — sunucu/mock her ikisinde de
/// aynı sekiz aile kullanılır (`_kLearningCategoryIds`).
const Map<String, IconData> _lessonCategoryIconMap = {
  'everyday': AppIcons.comment,
  'grammar': AppIcons.barsStaggered,
  'culture': AppIcons.peopleGroup,
  'food': AppIcons.utensils,
  'animals': AppIcons.paw,
  'geography': AppIcons.globe,
  'emotions': AppIcons.faceSmile,
  'time': AppIcons.clock,
};

/// Yerel (mock) banka için: bugünkü numaralı slug'lar (`everyday_1`) VE
/// ileride eklenebilecek anlamsal adlar.
const Map<String, IconData> _lessonMockSlugIconMap = {
  'alphabet': AppIcons.font,
  'numbers': AppIcons.hashtag,
  'colors': AppIcons.palette,
  'family': AppIcons.peopleRoof,
  'greetings': AppIcons.hand,
  'grammar_noun': AppIcons.font,
  'grammar_verb': AppIcons.barsStaggered,
  'newroz': AppIcons.champagneGlasses,
  'body': AppIcons.personCircleCheck,
  'clothing': AppIcons.shirt,
  'weather': AppIcons.cloud,
  'prepositions': AppIcons.locationDot,
  'house': AppIcons.house,
  'profession': AppIcons.briefcase,
  'daily_phrases': AppIcons.comment,
};

/// Ders için ikon: önce sunucunun tam `icon_name`i, sonra konu ailesi
/// (`category`), sonra yerel banka slug eşleşmesi denenir; hiçbiri
/// tutmazsa mezuniyet külahına düşülür.
///
/// ESKİ KUSUR (2026-08-14 denetimi): harita yalnız SLUG'a bakıyordu ve
/// yalnız mock'un numaralı ailelerini (`everyday_1` → `everyday`)
/// tanıyordu. `2026-07-06_lesson_seed.sql`deki 15 gerçek dersin
/// slug'ları Kurmancî bileşik sözcüklerdir (`silav-u-nasin`, `hejmar`,
/// `cinavk`...) — hiçbiri ne tam ne aile olarak eşleşmiyordu, hepsi aynı
/// yedek ikona düşüyordu. Oysa sunucu tam da bu ders için özel seçilmiş
/// bir `icon_name` (`waving_hand`, `numbers`...) VE `category` (mock ile
/// aynı sekiz aile) gönderiyordu — bu iki alan hiç kullanılmıyordu.
IconData iconForLesson(Lesson lesson) {
  final byIconName = lesson.iconName == null
      ? null
      : _lessonIconNameMap[lesson.iconName];
  if (byIconName != null) return byIconName;
  final byCategory = _lessonCategoryIconMap[lesson.category];
  if (byCategory != null) return byCategory;
  final exact = _lessonMockSlugIconMap[lesson.slug];
  if (exact != null) return exact;
  // `everyday_2` → `everyday`
  final family = lesson.slug.replaceFirst(RegExp(r'_\d+$'), '');
  return _lessonMockSlugIconMap[family] ?? AppIcons.graduationCap;
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
    final connectorColor = completed
        ? AppTheme.gold
        : current
        ? AppTheme.brand
        : AppTheme.borderColor(context).withValues(alpha: 0.35);

    return Stack(
      children: [
        // Dikey dokuma yolu bağlantı çizgisi
        Positioned(
          left: 9,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: connectorColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Baklava düğüm (Kilim diamond node)
        Positioned(
          left: 2,
          top: 22,
          child: _KilimPathDiamond(
            completed: completed,
            current: current,
            locked: locked,
          ),
        ),
        // Kart içeriği
        Padding(
          padding: EdgeInsets.only(
            left: 26 + (index.isEven ? 0.0 : 8.0),
            bottom: AppSpacing.xs,
          ),
          child: Opacity(opacity: locked ? 0.62 : 1.0, child: child),
        ),
      ],
    );
  }
}

/// Ders yolundaki kültürel kilim baklava düğümü.
class _KilimPathDiamond extends StatelessWidget {
  const _KilimPathDiamond({
    required this.completed,
    required this.current,
    required this.locked,
  });

  final bool completed;
  final bool current;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      // Tamamlanan: Altın dolgulu baklava düğüm
      return Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFD97706), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: const Icon(AppIcons.check, size: 10, color: Colors.white),
          ),
        ),
      );
    }

    if (current) {
      // Aktif/Sıradaki: Parlayan marka rengi baklava
      return Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: AppTheme.brand,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brand.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    // Kilitli: Şeffaf / tema kenarlıklı sessiz baklava
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHiColor(context),
          borderRadius: BorderRadius.circular(2.5),
          border: Border.all(
            color: AppTheme.borderColor(context).withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Icon(
            AppIcons.lock,
            size: 8,
            color: AppTheme.textMutedColor(context),
          ),
        ),
      ),
    );
  }
}

class _MasteryGoal extends StatelessWidget {
  const _MasteryGoal({required this.completed, required this.ku});

  final bool completed;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 9,
          top: 0,
          bottom: 24,
          child: Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: completed ? 1.0 : 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 14,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: completed
                    ? AppTheme.gold
                    : AppTheme.surfaceHiColor(context),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppTheme.gold, width: 1.2),
              ),
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Icon(
                  AppIcons.medal,
                  size: 9,
                  color: completed ? Colors.white : AppTheme.gold,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Container(
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
                    context.t(K.categoryMasteryGoal),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  bool _miniQuizLoading = false;
  bool _miniQuizEmpty = false;
  String? _miniQuizErrorMessage;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _loadSlides();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  void _loadSlides() {
    _slidesFuture = widget.repository.loadLessonSlides(widget.lesson.id);
  }

  void _retrySlides() {
    if (!mounted) return;
    setState(() {
      _currentSlideIndex = 0;
      _loadSlides();
    });
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
    if (_miniQuizLoading) return;
    setState(() {
      _miniQuizLoading = true;
      _miniQuizEmpty = false;
      _miniQuizErrorMessage = null;
    });
    final quizCategory = quizCategoryForLesson(widget.lesson.category);
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: quizCategory,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 5,
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        setState(() {
          _miniQuizLoading = false;
          _miniQuizEmpty = true;
        });
        return;
      }

      final room = widget.repository
          .createRoom(category: quizCategory)
          .copyWith(questionCount: questions.length);

      if (!mounted) return;

      await Navigator.of(context).push(
        AppRoute(
          page: QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            practice: true,
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
      if (mounted) setState(() => _miniQuizLoading = false);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_load_story');
      if (mounted) {
        setState(() {
          _miniQuizLoading = false;
          _miniQuizErrorMessage = context.t(K.quizLoadFail);
        });
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
              Icon(
                AppIcons.handPointer,
                size: 14,
                color: AppTheme.textMutedColor(context),
              ),
              const SizedBox(width: 6),
              Text(
                context.t(K.ceviriIcinDokun),
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
                  context.t(K.translation),
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
          content: Text(context.t(K.dersTamamlandi)),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else if (!success && mounted) {
      // Sunucuya yazılamadı: "tamamlandı" demeden, ekranı kapatmadan
      // kullanıcının tekrar deneyebilmesi için son slaytta bırak
      // (2026-08-14 denetimi).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.lessonCompleteFailed))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      appBar: AppBar(
        // Ders başlığı arayüz diline uyar; Kurmancî adı yedek kalır.
        title: Text(
          ku
              ? widget.lesson.titleKu
              : (widget.lesson.titleTr ?? widget.lesson.titleKu),
        ),
        actions: [
          IconButton(
            icon: Icon(_flashcardMode ? AppIcons.clone : AppIcons.layerGroup),
            tooltip: context.t(K.flashcardMode),
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
                  title: context.t(K.loadFailedShort),
                  message: context.t(K.slidesLoadFail),
                  retryLabel: context.t(K.retryShort),
                  onRetry: _retrySlides,
                ),
              );
            }
            final slides = snap.data ?? [];
            if (slides.isEmpty) {
              return Center(
                child: AppEmptyState(
                  icon: AppIcons.bookOpen,
                  title: context.t(K.noSlides),
                  message: context.t(K.slidesLoadFail),
                  actionLabel: context.t(K.retryShort),
                  onAction: _retrySlides,
                ),
              );
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
                        if (_miniQuizEmpty)
                          AppEmptyState(
                            icon: AppIcons.bookOpen,
                            title: context.t(K.noQuestionsForCategory),
                            message: context.t(K.quizLoadFail),
                            actionLabel: context.t(K.retryShort),
                            onAction: _startMiniQuiz,
                          ),
                        if (_miniQuizErrorMessage != null)
                          AppErrorState(
                            title: context.t(K.loadFailedShort),
                            message: _miniQuizErrorMessage!,
                            retryLabel: context.t(K.retryShort),
                            onRetry: _startMiniQuiz,
                          ),
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
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(),
                                    )
                                  : CachedNetworkImage(
                                      memCacheWidth: 720,
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
                                            color: AppTheme.brand.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: AppTheme.surfaceHiColor(
                                              context,
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              AppIcons.image,
                                              color: AppTheme.textMutedColor(
                                                context,
                                              ),
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
                            child: Text(context.t(K.backStep)),
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
                                ? (context.t(K.finish))
                                : (context.t(K.nextStep)),
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
                            onPressed: _miniQuizLoading ? null : _startMiniQuiz,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                context.t(K.miniQuiz),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
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
