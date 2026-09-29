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
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'story_screen.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/lesson_listening_card.dart';
import '../widgets/lesson_recall_card.dart';
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
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: B iskeleti. Sayfa adı ("Kurmancî öğren") ve alt
    // satırı çubukta durur; içerikte başlık kartı yok. Eskiden çubuk boştu
    // ve ad, altında orman gradyanlı bir kimlik kartında yazıyordu — iki
    // katlı bir başlık. Maket (4 · Öğrenme yolu): çubuk → konu rayı → yol.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.learnKurmanci))),
      body: SafeArea(
        top: false,
        // Kısa bir sayfa: hepsi bir kerede kurulur (tembel liste, sözlük
        // girişini ve hikâyeleri ilk kaydırmaya dek kurmuyordu).
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: SahneSpace.x2,
            bottom: SahneSpace.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Akıllı tekrar (SM-2) en üstte, ama yalnız gerçekten tekrar
              // bekliyorsa: vadesi gelmiş soru, yeni dersten daha acildir.
              // Hiç ders çözmemiş birine "Tekrarlar tamam" yazmak yapılmamış
              // bir işi bitmiş gösteriyordu (2026-09-27).
              _page(
                TodaysReviewCard(
                  repository: widget.repository,
                  isKu: ku,
                  hideWhenEmpty: true,
                ),
              ),
              // Konu rayı sayfa kenarına taşar (kendi 16'lık kenarını verir);
              // sağdaki solma "devamı var, kaydır" der.
              SahneRail(
                children: [
                  for (final cat in _kLearningCategoryIds)
                    _CategoryTab(
                      key: ValueKey('learning-tab-$cat'),
                      label: _categoryLabel(cat, ku),
                      isSelected: cat == _selectedCategory,
                      onTap: () => _selectCategory(cat),
                    ),
                ],
              ),
              const SizedBox(height: SahneSpace.x4),
              // Ana ders yolu ilk ekranda görünür. Yardımcı içerikler aynı
              // kaydırma yüzeyinde, derslerin ardından gelir.
              _page(_buildLessons(context, ku)),
              const SizedBox(height: SahneSpace.x4),
              // Konuyu pekiştirmenin iki yolu, derslerin hemen altında ve
              // adıyla: "Soru çöz" ve "Flaş kart". İkisi de ikincil (Kulis);
              // ekranın TEK birincil eylemi yoldaki etkin derstir.
              _page(
                _TopicActions(
                  isKu: ku,
                  enabled: _currentLessons.isNotEmpty,
                  onPractice: _openCategoryPractice,
                  onFlashcards: _openCategoryFlashcards,
                ),
              ),
              const SizedBox(height: SahneSpace.sectionTop),
              // Metin tabanlı günlük hikâyeler: kendi bölüm başlığı ve liste
              // grubuyla gelir (ortak `StoryCatalog`); her satır kendi yerel
              // ilerlemesini gösterir ve dönüşte durumu yeniler.
              _page(
                SizedBox(
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
              const SizedBox(height: SahneSpace.cardGap),
              _page(
                SahneListGroup(
                  children: [
                    SahneListRow.icon(
                      key: const ValueKey('learning-lexicon-entry'),
                      icon: AppIcons.magnifyingGlass,
                      role: SahneRole.learn,
                      title: context.t(K.lexiconTitle),
                      chevron: true,
                      onTap: _openLexicon,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sayfa kenarı (16). Konu rayı bunun dışında kalır: kenara taşar.
  static Widget _page(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
    child: child,
  );

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

  Widget _buildLessons(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    return FutureBuilder<List<Lesson>>(
      future: _lessonsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator(color: t.learnTx)),
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
        final completedCount = lessons
            .where((l) => _completedIds.contains(l.id))
            .length;
        // Yolun sonundaki "Kategori ustalık hedefi" durağı kalktı: ne
        // olduğu, neye yaradığı ekranda yazmıyordu (2026-09-27).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lessons.length; i++)
              _pathStop(
                ctx,
                ku,
                lessons: lessons,
                index: i,
                firstOpenIndex: firstOpenIndex,
                completedCount: completedCount,
              ),
          ],
        );
      },
    );
  }

  Widget _pathStop(
    BuildContext context,
    bool ku, {
    required List<Lesson> lessons,
    required int index,
    required int firstOpenIndex,
    required int completedCount,
  }) {
    final lesson = lessons[index];
    final completed = _completedIds.contains(lesson.id);
    final current =
        index == (firstOpenIndex < 0 ? lessons.length : firstOpenIndex);
    final locked = !completed && !current;
    final semanticLabel = _lessonStateSemanticLabel(
      context,
      lesson,
      ku,
      completed: completed,
      current: current,
      locked: locked,
    );
    final Widget card;
    if (current) {
      card = _CurrentLessonCard(
        lesson: lesson,
        title: _lessonTitle(lesson, ku),
        meta: _placementContextLabel(context, ku) ?? lesson.descriptionKu,
        done: completedCount,
        total: lessons.length,
        semanticLabel: semanticLabel,
        onTap: () => _openLesson(lesson),
      );
    } else {
      card = _LessonRow(
        lesson: lesson,
        title: _lessonTitle(lesson, ku),
        completed: completed,
        semanticLabel: semanticLabel,
        onTap: locked ? null : () => _openLesson(lesson),
      );
    }
    return _LearningPathNode(
      key: ValueKey('learning-path-node-${lesson.id}'),
      state: completed
          ? SahnePathNodeState.done
          : current
          ? SahnePathNodeState.inProgress
          : SahnePathNodeState.locked,
      first: index == 0,
      last: index == lessons.length - 1,
      child: KeyedSubtree(
        key: ValueKey('learning-route-stop-${lesson.id}'),
        child: card,
      ),
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
/// Ekranın birincil eylemi yolun üzerindeki etkin derstir (sahne kartındaki
/// Agir düğme). 2026-09-29 Şahnê: iki eylem de İKİNCİL düğmedir (Kulis tonu,
/// ikonlu, tam genişlik) — eskiden biri dolu yeşil, öteki altın harmanlıydı;
/// Şahnê'de renk yalnız rol taşır ve Agir tek birincildedir. Yan yana
/// sığmazlarsa (dar ekran, büyük yazı) alt alta sarar.
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
    final practice = KeyedSubtree(
      key: const ValueKey('learning-topic-practice'),
      child: SahneButton.secondary(
        icon: AppIcons.circleQuestion,
        label: Tr.forKu(K.soruCoz, isKu),
        onPressed: enabled ? onPractice : null,
        expand: true,
      ),
    );
    final flashcards = KeyedSubtree(
      key: const ValueKey('learning-topic-flashcards'),
      child: SahneButton.secondary(
        icon: AppIcons.layerGroup,
        label: Tr.forKu(K.flasKart, isKu),
        onPressed: enabled ? onFlashcards : null,
        expand: true,
      ),
    );
    return LayoutBuilder(
      key: const ValueKey('learning-topic-actions'),
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
        if (constraints.maxWidth < 320 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              practice,
              const SizedBox(height: SahneSpace.x2),
              flashcards,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: practice),
            const SizedBox(width: SahneSpace.x3),
            Expanded(child: flashcards),
          ],
        );
      },
    );
  }
}

/// Konu rayının çipi: görsel 44, dokunma alanı 48 ([SahneRailChip]);
/// ekran okuyucu tek bir "seçili / seçili değil" düğmesi görür.
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
  Widget build(BuildContext context) =>
      SahneRailChip(label: label, selected: isSelected, onTap: onTap);
}

/// Yolun etkin durağı — sahne kartı (maketteki `SahneStageCard.lesson`):
/// "SANA ÖNERİLEN" rozeti, ders adı, bağlam satırı (yerleştirme seviyesi
/// ya da dersin açıklaması), konu ilerlemesi elması (tamamlanan / toplam
/// ders) ve tam genişlik TEK birincil düğme.
///
/// Kartın her yeri dokunulabilir (düğme de aynı işi yapar): ekran okuyucu
/// tek bir düğme duyar ("Sana önerilen. Selamlaşma. Sonraki").
class _CurrentLessonCard extends StatelessWidget {
  const _CurrentLessonCard({
    required this.lesson,
    required this.title,
    required this.meta,
    required this.done,
    required this.total,
    required this.semanticLabel,
    required this.onTap,
  });

  final Lesson lesson;
  final String title;
  final String? meta;
  final int done;
  final int total;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metaText = meta?.trim();
    return Semantics(
      key: const ValueKey('learning-next-step'),
      button: true,
      enabled: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SahneStageCard.lesson(
          tag: SahneBadge(
            key: const ValueKey('lesson-recommended-badge'),
            label: context.t(K.recommendedForYou),
          ),
          title: title,
          meta: metaText == null || metaText.isEmpty ? null : metaText,
          done: done,
          total: total,
          actionLabel: context.t(K.start),
          onAction: onTap,
        ),
      ),
    );
  }
}

/// Yolun öteki durakları — yüzey kartı: 44'lük ders ikonu karosu + ad
/// (+ varsa açıklama) + sağda durum. Tamamlanan ders yeniden açılabilir
/// (chevron); kilitli ders ikincil metinde, kilit ikonuyla ve
/// dokunulamaz. Durum soldaki yol elmasında da (✓ / çizgi) görünür.
class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.title,
    required this.completed,
    required this.semanticLabel,
    required this.onTap,
  });

  final Lesson lesson;
  final String title;
  final bool completed;
  final String semanticLabel;

  /// `null`: kilitli.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final locked = onTap == null;
    final description = lesson.descriptionKu?.trim();
    final large = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return Semantics(
      button: !locked,
      enabled: !locked,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: SahneSurfaceCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x3,
          SahneSpace.x4,
          SahneSpace.x3,
        ),
        child: Row(
          children: [
            // Büyük yazı ölçeğinde (≥ 1.5) ikon karosu çizilmez: ders adı
            // dar sütunda harf harf bölünüyordu ("Nasandi / n"). Durum
            // yol elmasında ve sağdaki ikonda kalır.
            if (!large) ...[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: locked ? t.s2 : t.learnTint,
                  shape: SahneShape.m,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    iconForLesson(lesson),
                    size: 24,
                    color: locked ? t.tx2 : t.learnTx,
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SahneType.bodyStrong.copyWith(
                      color: locked ? t.tx2 : t.tx,
                    ),
                  ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            Icon(
              locked ? AppIcons.lock : AppIcons.chevronRight,
              size: 20,
              color: t.tx3,
            ),
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

/// Öğrenme yolunun bir durağı: solda 24'lük yol elması ([SahnePathNode])
/// ve durakları birbirine bağlayan ince yol çizgisi (Ray), sağda kart.
///
/// Elmas kartın dikey ortasındadır; çizgi ilk durakta elmastan başlar,
/// son durakta elmasta biter. Kilitli elmasın içi zemin rengidir: çizgi
/// arkasından geçmez. Durum kartın kendi sözünde okunur; elmas ekran
/// okuyucuya ayrıca duyurulmaz.
class _LearningPathNode extends StatelessWidget {
  const _LearningPathNode({
    required this.state,
    required this.first,
    required this.last,
    required this.child,
    super.key,
  });

  final SahnePathNodeState state;
  final bool first;
  final bool last;
  final Widget child;

  static const double _rail = 24;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final gap = last ? 0.0 : SahneSpace.cardGap;
    Widget segment(bool visible) => Expanded(
      child: visible
          ? Center(
              child: SizedBox(
                width: 1.5,
                height: double.infinity,
                child: ColoredBox(color: t.s3),
              ),
            )
          : const SizedBox.shrink(),
    );
    return Stack(
      children: [
        // Yol çizgisi: aradaki boşluk dahil bütün yüksekliği kaplar.
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: _rail,
          child: ExcludeSemantics(
            child: Column(
              children: [
                segment(!first),
                // Elmasın merkezi kartın dikey ortasında: alt yarıda
                // boşluk (gap) de çizgiye dahildir.
                segment(!last),
                if (gap > 0)
                  SizedBox(
                    height: gap,
                    child: Center(
                      child: SizedBox(
                        width: 1.5,
                        height: double.infinity,
                        child: ColoredBox(color: t.s3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: gap,
          width: _rail,
          child: ExcludeSemantics(
            child: Center(
              child: SahnePathNode(state: state, semanticLabel: ''),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: _rail + SahneSpace.x2,
            bottom: gap,
          ),
          child: child,
        ),
      ],
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
    // Hareketi azalt açıkken kart dönmeden yüz değiştirir.
    if (sahneMotionReduced(context)) {
      _flipController.value = _isFlipped ? 0 : 1;
    } else if (_isFlipped) {
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
    final t = SahneTokens.of(context);
    return Text(slide.contentKu, style: SahneType.body.copyWith(color: t.tx));
  }

  /// Örnek cümle: Kulis (`s2`) tonlu M pahlı kutu, ikincil metin.
  Widget _buildExample(String example, BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Text(
          example,
          style: SahneType.caption.copyWith(
            color: t.tx2,
            fontStyle: FontStyle.italic,
          ),
        ),
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

  /// Ön yüz: yüzey kartı (L pah) — "Çeviri için dokun" ipucu + Kurmancî
  /// içerik + örnek.
  Widget _buildFlashcardFront(LessonSlide slide, BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _flashcardMinHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.handPointer, size: 16, color: t.tx3),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    context.t(K.ceviriIcinDokun),
                    style: SahneType.caption.copyWith(color: t.tx3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),
            _buildKuContentRow(slide, context),
            if (slide.exampleKu case final exampleKu?) ...[
              const SizedBox(height: SahneSpace.x3),
              _buildExample(exampleKu, context),
            ],
          ],
        ),
      ),
    );
  }

  /// Kartın iki yüzü aynı en az yükseklikte: dönünce boy zıplamasın.
  static const double _flashcardMinHeight = 176;

  /// Arka yüz: sahne kartı (gece, öğrenme rolü) — "Çeviri" rozeti +
  /// çeviri. Eskiden palet dışı camgöbeği bir degradeydi.
  Widget _buildFlashcardBack(LessonSlide slide, BuildContext context, bool ku) {
    return SizedBox(
      width: double.infinity,
      child: SahneStageCard(
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return ConstrainedBox(
              // Sahne kartının üst boşluğu 4 fazla (20 / 16).
              constraints: const BoxConstraints(
                minHeight: _flashcardMinHeight - SahneSpace.x1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SahneBadge(label: context.t(K.translation)),
                  const SizedBox(height: SahneSpace.x3),
                  Text(
                    slide.contentTr ?? slide.contentKu,
                    style: SahneType.body.copyWith(color: t.tx),
                  ),
                ],
              ),
            );
          },
        ),
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
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        // Ders başlığı arayüz diline uyar; Kurmancî adı yedek kalır.
        title: Text(
          ku
              ? widget.lesson.titleKu
              : (widget.lesson.titleTr ?? widget.lesson.titleKu),
        ),
        actions: [
          SahneIconButton(
            icon: _flashcardMode ? AppIcons.clone : AppIcons.layerGroup,
            semanticLabel: context.t(K.flashcardMode),
            onPressed: _toggleFlashcard,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<LessonSlide>>(
          future: _slidesFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: t.learnTx));
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Slayt ilerlemesi: öğrenme tonlu çubuk + "2/5".
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.page,
                    SahneSpace.x2,
                    SahneSpace.page,
                    0,
                  ),
                  child: SahneProgressBar(
                    value: (_currentSlideIndex + 1) / slides.length,
                    trailing: '${_currentSlideIndex + 1}/${slides.length}',
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(SahneSpace.page),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: SahneSpace.x4,
                            ),
                            child: _SlideImage(url: imgUrl),
                          ),
                        if (_flashcardMode)
                          _buildFlashcard(slide, context, ku)
                        else
                          SahneSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildKuContentRow(slide, context),
                                if (slide.contentTr case final contentTr?
                                    when contentTr.isNotEmpty) ...[
                                  const SizedBox(height: SahneSpace.x2),
                                  Text(
                                    contentTr,
                                    style: SahneType.caption.copyWith(
                                      color: t.tx2,
                                    ),
                                  ),
                                ],
                                if (slide.exampleKu case final exampleKu?) ...[
                                  const SizedBox(height: SahneSpace.x3),
                                  _buildExample(exampleKu, context),
                                ],
                              ],
                            ),
                          ),
                        if (!_flashcardMode &&
                            isLast &&
                            recallEntries.length >= 2 &&
                            _listeningSpeaker != null) ...[
                          const SizedBox(height: SahneSpace.cardGap),
                          LessonListeningCard(
                            entries: recallEntries,
                            speaker: _listeningSpeaker!,
                          ),
                        ],
                        if (!_flashcardMode &&
                            isLast &&
                            recallEntries.isNotEmpty) ...[
                          const SizedBox(height: SahneSpace.cardGap),
                          LessonRecallCard(entries: recallEntries),
                        ],
                      ],
                    ),
                  ),
                ),
                // Gezinme: tek birincil (İleri / Tamamla) + ikincil Geri;
                // son slaytta ikincil "Mini Quiz". Üçü yan yana ancak geniş
                // ekranda sığar; telefonda "Mini Quiz" üstte tam genişlikte
                // durur — uzun Kurmancî etiket ("Quiz-a Kurt") küçültülmez,
                // tek satırda okunur.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.page,
                    SahneSpace.x2,
                    SahneSpace.page,
                    SahneSpace.x3,
                  ),
                  child: _SlideNavigation(
                    showBack: _currentSlideIndex > 0,
                    isLast: isLast,
                    onBack: () => setState(() => _currentSlideIndex--),
                    onNext: isLast
                        ? _markCompleted
                        : () => setState(() => _currentSlideIndex++),
                    onMiniQuiz: _miniQuizLoading ? null : _startMiniQuiz,
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

/// Ders slaytlarının alt gezinmesi (bkz. [LessonDetailScreen]).
class _SlideNavigation extends StatelessWidget {
  const _SlideNavigation({
    required this.showBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onMiniQuiz,
  });

  final bool showBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onMiniQuiz;

  @override
  Widget build(BuildContext context) {
    final back = SahneButton.secondary(
      label: context.t(K.backStep),
      onPressed: onBack,
      expand: true,
    );
    final next = SahneButton.primary(
      label: isLast ? context.t(K.finish) : context.t(K.nextStep),
      onPressed: onNext,
      expand: true,
    );
    final miniQuiz = SahneButton.secondary(
      icon: AppIcons.circleQuestion,
      label: context.t(K.miniQuiz),
      onPressed: onMiniQuiz,
      expand: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
        final oneRow = isLast && constraints.maxWidth >= 560 && !largeText;
        final row = Row(
          children: [
            if (showBack) ...[
              Expanded(child: back),
              const SizedBox(width: SahneSpace.x2),
            ],
            Expanded(child: next),
            if (oneRow) ...[
              const SizedBox(width: SahneSpace.x2),
              Expanded(child: miniQuiz),
            ],
          ],
        );
        if (!isLast || oneRow) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            miniQuiz,
            const SizedBox(height: SahneSpace.x2),
            row,
          ],
        );
      },
    );
  }
}

/// Slayt görseli: L pahlı, 200 yüksekliğinde; yüklenirken ve hata
/// hâlinde Kulis tonlu yer tutucu.
class _SlideImage extends StatelessWidget {
  const _SlideImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget placeholder(Widget child) => ColoredBox(
      color: t.s2,
      child: Center(child: child),
    );
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.l),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: url.startsWith('asset://')
            ? Image.asset(
                url.replaceFirst('asset://', ''),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              )
            : CachedNetworkImage(
                memCacheWidth: 720,
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => placeholder(
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.learnTx,
                    ),
                  ),
                ),
                errorWidget: (context, _, _) =>
                    placeholder(Icon(AppIcons.image, color: t.tx3, size: 32)),
              ),
      ),
    );
  }
}
