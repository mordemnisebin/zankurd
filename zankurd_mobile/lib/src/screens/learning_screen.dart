import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../data/sync_manager.dart';
import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/lesson.dart';
import '../services/lesson_listening_speaker.dart';
import '../services/placement_scoring.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/percent_format.dart';
import '../utils/error_reporter.dart';
import 'story_screen.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/lesson_listening_card.dart';
import '../widgets/lesson_recall_card.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/story_catalog.dart';
import '../widgets/todays_review_card.dart';
import '../widgets/zk_back_button.dart';
import 'learner_lexicon_screen.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      // AppBar başlıksız: ekranın adını `ScreenIdentityHeader` taşıyor.
      //
      // Burada başlık da verilince iki yakın anlamlı başlık üst üste
      // biniyordu — "Öğren" ve hemen altında "Kurmancî öğren" (2026-07-30
      // ekran turu, 55/56). Kimlik bandı kullanan on ekranın sekizi AppBar
      // başlığını zaten boş bırakıyor; aykırı olan buydu. Oyuncu hangi
      // sekmede olduğunu alt gezinme çubuğundan görüyor.
      appBar: zkAppBar(context),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              // `Column`un varsayılanı `center`dır ve bölüm başlıkları
              // metin genişliğinde daralan `Column`lar olduğu için ekranın
              // ortasına kaçıyordu: sayfa başlığı "Öğren" solda, hemen
              // altındaki "Bugünkü hedefin" ve "Öğrenme yolları" ortada
              // duruyordu (2026-07-30 ekran turu, 55/56). Uygulamanın geri
              // kalanında bütün bölüm başlıkları sola dayalı.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Design 2.0: öğrenme kimliği ayrı bir kart değil,
                // Rêya Zanînê sahnesinin sakin giriş başlığıdır.
                _LearningSceneHeader(
                  title: context.t(K.learnKurmanci),
                  subtitle: context.t(K.learnSubtitle),
                ),
                // Akıllı tekrar (SM-2) en üstte, ama yalnız gerçekten tekrar
                // bekliyorsa: vadesi gelmiş soru, yeni dersten daha acildir.
                // Hiç ders çözmemiş birine "Tekrarlar tamam" yazmak
                // yapılmamış bir işi bitmiş gösteriyordu (2026-09-27).
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    0,
                  ),
                  child: TodaysReviewCard(
                    repository: widget.repository,
                    isKu: ku,
                    hideWhenEmpty: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    0,
                  ),
                  child: ScreenSectionHeading(
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
                      colors: [Colors.white, Colors.white, Colors.transparent],
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
                // Kategori ilerleme göstergesi
                _buildCategoryProgress(context, ku),
                // Ana ders yolu ilk ekranda görünür. Yardımcı içerikler
                // aynı kaydırma yüzeyinde, derslerin ardından gelir.
                _buildLessons(context, ku, embedded: true),
                // Konuyu pekiştirmenin iki yolu, derslerin hemen altında
                // ve adıyla. Eskiden konu çiplerinin altında üç simgeli
                // bir şerit vardı ("Soru çöz / Flaş kart / Dersler"): sekme
                // mi düğme mi olduğu belli değildi, "Dersler" yolun kendisini
                // tekrar ediyordu ve üçü de konunun İLK dersini açıyordu.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xs,
                  ),
                  child: _TopicActions(
                    isKu: ku,
                    enabled: _currentLessons.isNotEmpty,
                    onPractice: _openCategoryPractice,
                    onFlashcards: _openCategoryFlashcards,
                  ),
                ),
                // Metin tabanlı günlük hikâyeler. Her kart kendi yerel
                // ilerlemesini gösterir ve dönüşte durumu yeniler. Liste
                // alt alta: yana kayan şerit ikinci hikâyeyi yarım
                // gösteriyordu ("Kend…").
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    0,
                  ),
                  child: SizedBox(
                    key: const ValueKey('learning-story-entry'),
                    width: double.infinity,
                    child: StoryCatalog(
                      isKu: ku,
                      onOpen: (story, guide) => Navigator.of(context).push(
                        AppRoute(
                          page: StoryScreen(story: story, guide: guide),
                        ),
                      ),
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
                  child: AppPanel(
                    key: const ValueKey('learning-lexicon-entry'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    onTap: _openLexicon,
                    semanticLabel:
                        '${context.t(K.lexiconTitle)}. '
                        '${context.t(K.lexiconSubtitle)}',
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.playGreen.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            AppIcons.magnifyingGlass,
                            size: 18,
                            color: AppTheme.playGreen,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(K.lexiconTitle),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.t(K.lexiconSubtitle),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.textSubColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          AppIcons.chevronRight,
                          size: 16,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _recommendedLessonIndex(List<Lesson> lessons) {
    final placementIndex = PlacementScoring.recommendedStartIndex(
      _placementLevel,
      lessons.length,
    );
    return learningRecommendedIndex(
      lessons: lessons,
      completedLessonIds: _completedIds,
      placementIndex: placementIndex,
    );
  }

  String _lessonTitle(Lesson lesson, bool ku) =>
      ku ? lesson.titleKu : (lesson.titleTr ?? lesson.titleKu);

  String? _placementContextLabel(BuildContext context, bool ku) {
    if (_placementLevel == null || _completedIds.isNotEmpty) return null;
    return context.t(K.currentLevel, {
      'name': ku ? _placementLevel!.labelKu : _placementLevel!.labelTr,
    });
  }

  String _lessonStateSemanticLabel(
    BuildContext context,
    Lesson lesson,
    bool ku, {
    required bool completed,
    required bool current,
    required bool locked,
  }) {
    final state = completed
        ? context.t(K.dersTamamlandi)
        : current
        ? context.t(K.next)
        : locked
        ? context.t(K.locked)
        : '';
    final parts = <String>[
      if (current) context.t(K.recommendedForYou),
      _lessonTitle(lesson, ku),
      if (state.isNotEmpty) state,
    ];
    return parts.join('. ');
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
        final firstOpenIndex = _recommendedLessonIndex(lessons);
        return ListView.builder(
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          // Yolun sonundaki "Kategori ustalık hedefi" durağı kalktı: ne
          // olduğu, neye yaradığı ekranda yazmıyordu (2026-09-27).
          itemCount: lessons.length,
          itemBuilder: (ctx, i) {
            final completed = _completedIds.contains(lessons[i].id);
            final current =
                i == (firstOpenIndex < 0 ? lessons.length : firstOpenIndex);
            final locked = !completed && !current;
            final placementContext = current
                ? _placementContextLabel(ctx, ku)
                : null;
            return _LearningPathNode(
              key: ValueKey('learning-path-node-${lessons[i].id}'),
              completed: completed,
              current: current,
              locked: locked,
              child: _LessonCard(
                lesson: lessons[i],
                ku: ku,
                completed: completed,
                locked: locked,
                recommended: current,
                supportingLabel: placementContext,
                semanticLabel: _lessonStateSemanticLabel(
                  ctx,
                  lessons[i],
                  ku,
                  completed: completed,
                  current: current,
                  locked: locked,
                ),
                onTap: locked ? () {} : () => _openLesson(lessons[i]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.of(context).push(
      AppRoute(
        page: LessonDetailScreen(lesson: lesson, repository: widget.repository),
      ),
    );
    _refreshCompleted();
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
      if (!mounted) return;
      if (questions.isEmpty) {
        _showPracticeLoadFailure(context.t(K.noQuestionsFound));
        return;
      }
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
      if (mounted) {
        _showPracticeLoadFailure(context.t(K.quizLoadFail));
      }
    }
  }

  void _showPracticeLoadFailure(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: context.t(K.retryShort),
          onPressed: _openCategoryPractice,
        ),
      ),
    );
  }

  Future<void> _openCategoryFlashcards() {
    return _openCategoryLessonDetail(initialFlashcardMode: true);
  }

  /// Oyuncunun sıradaki dersi; hepsi bittiyse konunun son dersi.
  ///
  /// Kelime kartları eskiden her zaman konunun İLK dersini açıyordu:
  /// ikinci derse gelmiş biri kartlarda hep "Selamlaşma"yı görüyordu.
  Lesson? _recommendedLesson() {
    if (_currentLessons.isEmpty) return null;
    final index = _recommendedLessonIndex(_currentLessons);
    return _currentLessons[index < 0 ? _currentLessons.length - 1 : index];
  }

  Future<void> _openLexicon() {
    return Navigator.of(
      context,
    ).push(AppRoute(page: const LearnerLexiconScreen()));
  }

  Future<void> _openCategoryLessonDetail({
    required bool initialFlashcardMode,
  }) async {
    final lesson = _recommendedLesson();
    if (lesson == null || !mounted) return;
    await Navigator.of(context).push(
      AppRoute(
        page: LessonDetailScreen(
          lesson: lesson,
          repository: widget.repository,
          initialFlashcardMode: initialFlashcardMode,
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
      // Ürünün geri kalanı dilbilgisine `Rêziman` diyor (K.dilbilgisi).
      'grammar': ('Rêziman', 'Dilbilgisi'),
      'culture': ('Çand', 'Kültür'),
      'food': ('Xwarin', 'Yemek'),
      'animals': ('Ajal', 'Hayvanlar'),
      'geography': ('Erdnîgarî', 'Coğrafya'),
      'emotions': ('Hest', 'Duygular'),
      // `Demjimêr` saat demek; konu günleri, ayları ve zaman dilimlerini
      // kapsıyor ("Roj û Meh", "Serdem û Demjimêr"): `Dem`.
      'time': ('Dem', 'Zaman'),
    };
    final (kuLabel, trLabel) = labels[cat] ?? (cat, cat);
    return ku ? kuLabel : trLabel;
  }
}

/// Konuyu pekiştirmenin iki yolu: o konudan soru çözmek ve kelime kartları.
///
/// Ekranın birincil eylemi hâlâ yolun üzerindeki önerilen derstir. Ama
/// 2026-09-27'den önce ikisi de aynı soluk çerçeveli (outlined) yeşildi —
/// sahip ekranı renksiz buldu ve "Soru çöz" ile "Flaş kart" göz açısıyla
/// ayırt edilemiyordu. Artık ikisi de DOLU ve birbirinden ayrışır: pratik
/// yolun rengiyle (playGreen) aynı ailede, kartlar kendi tonal altın
/// kimliğinde — turuncu (asıl CTA rengi) yine hiçbirine verilmez.
class _TopicActions extends StatelessWidget {
  const _TopicActions({
    required this.isKu,
    required this.enabled,
    required this.onPractice,
    required this.onFlashcards,
  });

  final bool isKu;
  final bool enabled;
  final VoidCallback onPractice;
  final VoidCallback onFlashcards;

  @override
  Widget build(BuildContext context) {
    final practice = _TopicActionButton(
      key: const ValueKey('learning-topic-practice'),
      icon: AppIcons.circleQuestion,
      label: Tr.forKu(K.soruCoz, isKu),
      tone: _TopicActionTone.practice,
      onTap: enabled ? onPractice : null,
    );
    final flashcards = _TopicActionButton(
      key: const ValueKey('learning-topic-flashcards'),
      icon: AppIcons.layerGroup,
      label: Tr.forKu(K.flasKart, isKu),
      tone: _TopicActionTone.flashcards,
      onTap: enabled ? onFlashcards : null,
    );
    return LayoutBuilder(
      key: const ValueKey('learning-topic-actions'),
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        if (constraints.maxWidth < 320 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              practice,
              const SizedBox(height: AppSpacing.xs),
              flashcards,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: practice),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: flashcards),
          ],
        );
      },
    );
  }
}

/// Konu eylemi kimliği: "Soru çöz" dolu playGreen, "Flaş kart" tonal altın.
///
/// 2026-09-03'te "Kaydet" turuncu-on-kahve pasif hâlde okunmuyordu; aynı
/// kusurun burada tekrarı iki farklı şeyle önlenir — pasif hâl her iki
/// tonda da aynı nötr `AppColors.disabledSurface` + soluk metne düşer (bkz.
/// `fill_in_blank_widget.dart`daki aynı desen), etkin hâl ise tona göre
/// ayrışır ki iki düğme birbirinin klonu görünmesin.
enum _TopicActionTone { practice, flashcards }

class _TopicActionButton extends StatelessWidget {
  const _TopicActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tone,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final _TopicActionTone tone;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final disabled = onTap == null;
    final Color background;
    final Color foreground;
    BorderSide? side;
    switch (tone) {
      case _TopicActionTone.practice:
        background = AppTheme.playGreen;
        foreground = Colors.white;
      case _TopicActionTone.flashcards:
        // Düz altın zemin ne beyaz ne ink metni AA eşiğinin üstünde tutar
        // (altın orta tonlu bir aksan); bunun yerine yüzeyle harmanlanmış
        // TONAL bir altın kullanılır — ink/cream metin bu tonda okunur
        // (bkz. `learning_color_identity_test.dart` kontrast bekçisi).
        // Karanlık temada oran biraz yüksek: koyu yüzeyde aynı %22 daha az
        // fark ediyor.
        background = Color.alphaBlend(
          AppTheme.gold.withValues(alpha: isLight ? 0.22 : 0.26),
          AppTheme.surfaceColor(context),
        );
        foreground = AppTheme.textPrimaryColor(context);
        // Pasifken çerçeve de kalkar: altın halka + soluk metin "etkin ama
        // gri" gibi karışık bir izlenim veriyordu.
        side = disabled
            ? null
            : BorderSide(color: AppTheme.gold.withValues(alpha: 0.55));
    }

    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.disabledSurface(context),
          disabledForegroundColor: AppTheme.textMutedColor(context),
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}

class _LearningSceneHeader extends StatelessWidget {
  const _LearningSceneHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // 2026-09-27: sahip ekranı "renksiz" buldu — başlık soluk bir ikon
    // karosu + düz metindi, uygulamanın geri kalanındaki orman kimlik
    // bandından (bkz. `AppTheme.identityHeaderGradient`; ayarlar/oturum
    // ekranları zaten onu taşıyor) kopuktu. Anahtar yine en dıştaki
    // widget'ta kalır — yatay sayfa boşluğunu veren bu `Padding` — ki
    // `learning_screen_test.dart` içindeki yapısal bekçiler bozulmasın;
    // içine artık düz bir Row yerine gradyanlı bir kimlik kartı girer.
    return Padding(
      key: const ValueKey('learning-scene-header'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.identityHeaderGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppTheme.cardShadow(context),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                AppIcons.graduationCap,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İki satır: maskot başlığa ayrılan eni daralttı ve
                  // Kurmancî başlık tek satırda "Kurmancî hîn bi…" diye
                  // kesiliyordu (2026-09-27 tur görüntüsü). Başlık küçültülüp
                  // sığdırılmaz; gerekirse alt satıra iner.
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading2.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Zana yalnız dekoratif eşlik eder; başlığın kendi semantics'i
            // zaten title+subtitle'ı taşıyor — maskot ikinci bir "resim"
            // düğümü olarak duyurulmasın.
            const ExcludeSemantics(child: RojMascot(size: 48)),
          ],
        ),
      ),
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
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: largeText ? 0 : 6),
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: largeText ? 0 : 8,
            ),
            decoration: BoxDecoration(
              // 2026-09-27: seçili sekme eskiden playGreen'in yalnız %14'ü
              // kadar soluk bir zemindi (bkz. `AppColors.iconTileBg`) — sahip
              // ekranı renksiz buldu. Artık DOLU: yolun üzerindeki birincil
              // adımla (bkz. `_LessonCard.isPrimary`) aynı doygun yeşili
              // taşır, çerçevesizdir; seçili olmayanlar kendi yüzey rengiyle
              // ve ince bir kenarlıkla ayrışır.
              color: isSelected
                  ? AppTheme.playGreen
                  : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: isSelected
                  ? null
                  : Border.all(color: AppTheme.borderColor(context), width: 1),
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
    this.supportingLabel,
    this.semanticLabel,
  });

  final Lesson lesson;
  final bool ku;
  final bool completed;
  final bool locked;
  final VoidCallback onTap;
  final bool recommended;
  final String? supportingLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isPrimary = recommended && !completed && !locked;
    final accent = isPrimary
        ? AppTheme.primaryCtaColor(context)
        : AppTheme.playGreen;
    final titleColor = isPrimary
        ? Colors.white
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = isPrimary
        ? Colors.white.withValues(alpha: 0.82)
        : AppTheme.textMutedColor(context);
    final iconColor = locked
        ? AppTheme.textMutedColor(context)
        : isPrimary
        ? Colors.white
        : AppColors.readableAccent(context, accent);
    final enabled = !locked;

    return Padding(
      key: ValueKey('learning-route-stop-${lesson.id}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        key: recommended && !completed
            ? const ValueKey('learning-next-step')
            : null,
        button: enabled,
        enabled: enabled,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Material(
            color: isPrimary ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: enabled ? onTap : null,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
                child: Row(
                  children: [
                    if (recommended && !completed) ...[
                      Container(
                        width: 3,
                        height: 54,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Container(
                      width: 48,
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppColors.iconTileBg(context, accent),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Icon(
                          iconForLesson(lesson),
                          color: iconColor,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ku
                                ? lesson.titleKu
                                : (lesson.titleTr ?? lesson.titleKu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lesson.descriptionKu ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                          if (supportingLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              supportingLabel!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: subtitleColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (recommended && !completed) ...[
                            const SizedBox(height: 5),
                            Row(
                              key: const ValueKey('lesson-recommended-badge'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.bookOpen,
                                  size: 12,
                                  color: isPrimary
                                      ? Colors.white
                                      : AppTheme.playGreen,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    context.t(K.recommendedForYou),
                                    style: AppTypography.caption.copyWith(
                                      color: isPrimary
                                          ? Colors.white
                                          : AppColors.readableAccent(
                                              context,
                                              accent,
                                            ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (completed)
                      Icon(
                        AppIcons.circleCheck,
                        color: AppColors.readableAccent(context, accent),
                        size: 20,
                      )
                    else if (locked)
                      Icon(
                        AppIcons.lock,
                        color: AppTheme.textMutedColor(context),
                        size: 18,
                      )
                    else
                      Icon(
                        AppIcons.chevronRight,
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppTheme.textMutedColor(context),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
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
    required this.completed,
    required this.current,
    required this.locked,
    required this.child,
    super.key,
  });

  final bool completed;
  final bool current;
  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectorColor = completed
        ? AppTheme.playGreen.withValues(alpha: 0.60)
        : current
        ? AppTheme.playGreen
        : AppTheme.borderColor(context).withValues(alpha: 0.55);

    return Stack(
      children: [
        Positioned(
          left: 7,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1.5,
            decoration: BoxDecoration(
              color: connectorColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 24,
          child: _LearningPathMarker(
            completed: completed,
            current: current,
            locked: locked,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: AppSpacing.xs),
          child: Opacity(opacity: locked ? 0.72 : 1.0, child: child),
        ),
      ],
    );
  }
}

class _LearningPathMarker extends StatelessWidget {
  const _LearningPathMarker({
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
      return Container(
        width: 15,
        height: 15,
        decoration: const BoxDecoration(
          color: AppTheme.playGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(AppIcons.check, size: 9, color: Colors.white),
      );
    }

    if (current) {
      return Container(
        width: 15,
        height: 15,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.bgOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.playGreen, width: 2),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.playGreen,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: locked
          ? Icon(
              AppIcons.lock,
              size: 7,
              color: AppTheme.textMutedColor(context),
            )
          : null,
    );
  }
}

class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    required this.lesson,
    required this.repository,
    this.initialFlashcardMode = false,
    this.listeningSpeaker,
    super.key,
  });

  final Lesson lesson;
  final ZanKurdRepository repository;
  final bool initialFlashcardMode;
  final LessonListeningSpeaker? listeningSpeaker;

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with TickerProviderStateMixin {
  late Future<List<LessonSlide>> _slidesFuture;
  int _currentSlideIndex = 0;

  // Flashcard modu
  late bool _flashcardMode;
  bool _isFlipped = false;
  bool _miniQuizLoading = false;
  bool _miniQuizEmpty = false;
  String? _miniQuizErrorMessage;
  LessonListeningSpeaker? _listeningSpeaker;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flashcardMode = widget.initialFlashcardMode;
    _listeningSpeaker = widget.listeningSpeaker;
    _loadSlides();
    if (_listeningSpeaker == null &&
        LearnerLexicon.entriesForSource(widget.lesson.id).length >= 2) {
      unawaited(_loadListeningSpeaker());
    }
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadListeningSpeaker() async {
    try {
      final speaker = await TtsLessonListeningSpeaker.load();
      if (!mounted) return;
      setState(() => _listeningSpeaker = speaker);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_tts_load');
    }
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
      final questions = await widget.repository.loadLearningQuizQuestions(
        category: quizCategory,
        learningLessonId: widget.lesson.id,
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
      // (2026-08-14 denetimi). Aynı ders idempotent kuyruğa girer.
      unawaited(_queueLessonCompletion(widget.lesson.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.lessonCompleteFailed))),
      );
    }
  }

  Future<void> _queueLessonCompletion(String lessonId) async {
    final manager = SyncManager.maybeInstance;
    if (manager == null) return;
    try {
      await manager.queueLessonCompletion(lessonId);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'lesson completion queue');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      appBar: zkAppBar(
        context,
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
            final recallEntries = LearnerLexicon.entriesForSource(
              widget.lesson.id,
            );

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
                        if (!_flashcardMode &&
                            isLast &&
                            recallEntries.length >= 2 &&
                            _listeningSpeaker != null) ...[
                          const SizedBox(height: 12),
                          LessonListeningCard(
                            entries: recallEntries,
                            speaker: _listeningSpeaker!,
                          ),
                        ],
                        if (!_flashcardMode &&
                            isLast &&
                            recallEntries.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          LessonRecallCard(entries: recallEntries),
                        ],
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
