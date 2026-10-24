import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/learner_lexicon.dart';
import '../data/lesson_completion_store.dart';
import '../data/learning_lesson_aliases.dart';
import '../data/sync_manager.dart';
import '../data/word_list_store.dart';
import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../services/lesson_listening_speaker.dart';
import '../services/placement_scoring.dart';
import '../services/question_set_policy.dart';
import '../utils/app_route.dart';
import 'level_placement_screen.dart';
import '../data/streak_store.dart';
import '../utils/error_reporter.dart';
import 'story_screen.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/lesson_listening_card.dart';
import '../widgets/lesson_vocab_tiles.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/lesson_recall_card.dart';
import '../widgets/story_catalog.dart';
import '../widgets/todays_review_card.dart';
import '../widgets/zk_back_button.dart';
import 'learner_lexicon_screen.dart';
import 'my_words_screen.dart';
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
/// öneri yerleştirme noktasından ileriye doğru ilk tamamlanmamış dersi
/// izler; yerleştirme noktasının gerisine bir daha düşmez.
///
/// ESKİ KUSUR (2026-08-14 denetimi): öneri kilitli bir düğüme düşerse HER
/// ZAMAN ilk açık derse geriliyordu — bu, ileri seviyeli hiçbir kullanıcıda
/// yerleştirmenin görünür bir etkisi olmadığı anlamına geliyordu (sınav
/// sonucu yolu değiştirmiyordu). İlk ders tamamlanır tamamlanmaz da aynı
/// geri dönüş öneriyi o tamamlanan derste sonsuza dek KİLİTLİYORDU —
/// "Sana önerilen" rozeti bir daha hiçbir karta düşmüyordu.
///
/// ESKİ KUSUR 2 (2026-10-15): bir ders tamamlanınca `indexWhere` her zaman
/// BAŞTAN aranıyordu. Yerleştirmenin 2'yi önerdiği biri 2. dersi bitirince
/// öneri 0'a geri dönüyor, 3 ve sonrası kilitli kalıyordu; 0 ve 1 ise
/// yerleştirme önerisinin ÖNÜNDE oldukları için hiç açılmamıştı. Artık
/// öneri yerleştirme noktasından ileriye doğru aranır, hiç geriye gitmez;
/// yalnız o noktadan sonra açık ders kalmadıysa baştaki ilk açığa düşer.
int learningRecommendedIndex({
  required List<Lesson> lessons,
  required Set<String> completedLessonIds,
  required int placementIndex,
}) {
  if (completedLessonIds.isEmpty) return placementIndex;
  final start = placementIndex.clamp(0, lessons.length);
  for (var i = start; i < lessons.length; i++) {
    if (!completedLessonIds.contains(lessons[i].id)) return i;
  }
  return lessons.indexWhere(
    (lesson) => !completedLessonIds.contains(lesson.id),
  );
}

/// Etkin dersten sonra görünen kilitli ders sayısı; kalanı "+N ders daha".
const int _kVisibleLockedLessons = 3;

/// Ders kilitli mi: tamamlanmamış ve önerilen dersin ARKASINDA olan kilitlidir.
/// Önerilene kadar (kendisi dahil) her ders açıktır; tamamlananlar açık kalır.
/// [recommendedIndex] -1 ise hepsi tamamlanmıştır, hiçbiri kilitli değildir.
bool learningLessonLocked({
  required int index,
  required bool completed,
  required int recommendedIndex,
}) => !completed && recommendedIndex >= 0 && index > recommendedIndex;

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
  bool _showAllLocked = false;
  PlacementLevel? _placementLevel;
  bool _placementPrompt = false;
  bool _lessonsLoading = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _refreshCompleted();
    _loadPlacementLevel();
    _loadWordList();
  }

  /// "Kelimelerim" satırının alt yazısı: vadesi gelen kelime varsa onu,
  /// yoksa kayıtlı kelime sayısını gösterir; ikisi de yoksa alt yazı yok.
  Future<void> _loadWordList() async {
    try {
      final store = await WordListStore.load();
      if (mounted) {
        setState(() {
          _wordCount = store.count;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_word_list');
    }
  }

  Future<void> _loadPlacementLevel() async {
    try {
      final store = await PlacementStore.load();
      if (mounted) {
        setState(() {
          _placementLevel = store.level;
          _placementPrompt = store.shouldPrompt;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_load_progress');
    }
  }

  Future<void> _openPlacement() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(LevelPlacementScreen(repository: widget.repository)));
    if (mounted) await _loadPlacementLevel();
  }

  Future<void> _dismissPlacementPrompt() async {
    setState(() => _placementPrompt = false);
    try {
      final store = await PlacementStore.load();
      await store.markSkipped();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_skip_placement');
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
      _showAllLocked = false;
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
      appBar: zkAppBar(
        context,
        title: Text(context.t(K.learnKurmanci)),
        backgroundColor: t.learnFill,
        foregroundColor: SahneVivid.onFill,
        glassBack: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
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
              // Seviye belirlenmemiş ve geçilmemişse yumuşak, kapatılabilir
              // davet. Ekranın tek birincil eylemi yoldaki etkin ders olduğu
              // için düğme ikincildir.
              if (_placementPrompt) ...[
                _page(
                  _PlacementPromptCard(
                    isKu: ku,
                    onStart: _openPlacement,
                    onDismiss: _dismissPlacementPrompt,
                  ),
                ),
                const SizedBox(height: SahneSpace.x3),
              ],
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
              const SizedBox(height: SahneSpace.sectionTop),
              // Pratik bölümü (tur 11): iki düğme + hikâyeler + sözlük,
              // ders listesinden belirgin boşlukla ayrı ve ikincil. Konuyu pekiştirmenin iki yolu ve
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
                    SahneListRow.icon(
                      key: const ValueKey('learning-my-words-entry'),
                      icon: AppIcons.bookmark,
                      role: SahneRole.learn,
                      title: context.t(K.wordsTitle),
                      // Vadesi gelen sayısı burada DEĞİL: tekrar girişi tektir
                      // ("Tekrar · bugün N" kartı), Kelimelerim yalnız liste.
                      subtitle: _wordCount > 0
                          ? context.t(K.wordsCount, {'count': '$_wordCount'})
                          : null,
                      chevron: true,
                      onTap: _openMyWords,
                    ),
                    // Seviye testi: yalnızca ilk açılış kartında ve
                    // Ayarlar'ın derinindeydi; kart kapatılınca öğrenme
                    // alanından bulunamıyordu (erişim haritası, 2026-10-21).
                    SahneListRow.icon(
                      key: const ValueKey('learning-retake-placement'),
                      icon: AppIcons.gaugeHigh,
                      role: SahneRole.learn,
                      title: context.t(K.retakePlacement),
                      chevron: true,
                      onTap: _openPlacement,
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
        //
        // 2026-09-29 doğallık (K5, K7): dersler solda elmas düğümlü bir yol
        // çizgisine dizilmiş ayrı kartlardı; her kartın başında bir ikon
        // karosu vardı. Elmas yalnız soru ilerlemesi ve ders sayacında
        // kalır, kilitli ders tek işaret (kilit) taşır. Artık etkin ders
        // sahne kartı, öteki dersler onun önünde ve arkasında ikonsuz
        // satırlardan oluşan liste grupları; satırın sağında ilerleme
        // (✓ tamamlandı, kilit) durur, satırın tamamı dokunulur.
        final blocks = <Widget>[];
        var run = <Widget>[];
        void closeRun() {
          if (run.isEmpty) return;
          blocks.add(SahneListGroup(children: run));
          run = <Widget>[];
        }

        // Kurul 3. tur (2026-10-20): uzun sönük kilitli ders listesi
        // ilerlemeyi zayıf gösteriyordu (55/56). Sıradaki en çok
        // [_kVisibleLockedLessons] kilitli ders görünür; kalanı tek
        // "+N ders daha" satırında toplanır, dokununca açılır.
        var lockedShown = 0;
        var lockedHidden = 0;
        for (var i = 0; i < lessons.length; i++) {
          final isLocked = learningLessonLocked(
            index: i,
            completed: _completedIds.contains(lessons[i].id),
            recommendedIndex: firstOpenIndex,
          );
          if (isLocked) {
            if (!_showAllLocked && lockedShown >= _kVisibleLockedLessons) {
              lockedHidden++;
              continue;
            }
            lockedShown++;
          }
          final stop = _pathStop(
            ctx,
            ku,
            lessons: lessons,
            index: i,
            firstOpenIndex: firstOpenIndex,
            completedCount: completedCount,
          );
          if (stop.current) {
            closeRun();
            blocks.add(stop.widget);
          } else {
            run.add(stop.widget);
          }
        }
        if (lockedHidden > 0) {
          run.add(
            SahneListRow.plain(
              key: const ValueKey('learning-locked-more'),
              dense: true,
              title: context.t(K.lessonsMoreCount, {'n': '$lockedHidden'}),
              onTap: () => setState(() => _showAllLocked = true),
              trailing: Icon(
                AppIcons.lock,
                size: 20,
                // D aşaması (3 model): kilit öğrenme alanının Zimrût'una
                // doğru kayık, düşük doygunluk; açık satırdan geride.
                color: Color.lerp(t.tx2, t.learnTx, 0.4),
              ),
            ),
          );
        }
        closeRun();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < blocks.length; i++) ...[
              if (i > 0) const SizedBox(height: SahneSpace.cardGap),
              blocks[i],
            ],
          ],
        );
      },
    );
  }

  /// Yolun bir durağı: etkin ders sahne kartı ([current]), ötekiler liste
  /// satırı. Anahtarlar (`learning-path-node-…`, `learning-route-stop-…`)
  /// ekranın test sözleşmesidir.
  ({Widget widget, bool current}) _pathStop(
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
    final locked = learningLessonLocked(
      index: index,
      completed: completed,
      recommendedIndex: firstOpenIndex,
    );
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
        meta: _placementContextLabel(context, ku) ?? lesson.description(ku),
        done: completedCount,
        total: lessons.length,
        semanticLabel: semanticLabel,
        onTap: () => _openLesson(lesson),
      );
    } else {
      card = _LessonRow(
        lesson: lesson,
        step: index + 1,
        title: _lessonTitle(lesson, ku),
        completed: completed,
        semanticLabel: semanticLabel,
        onTap: locked ? null : () => _openLesson(lesson),
      );
    }
    return (
      current: current,
      widget: KeyedSubtree(
        key: ValueKey('learning-path-node-${lesson.id}'),
        child: KeyedSubtree(
          key: ValueKey('learning-route-stop-${lesson.id}'),
          child: card,
        ),
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
    final lessons = List<Lesson>.of(_currentLessons);
    final lesson = lessons.first;
    final quizCategory = quizCategoryForLesson(lesson.category);
    try {
      final levelQuestions = await widget.repository.loadLevelQuestions(
        category: quizCategory,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 10,
      );
      if (!mounted) return;
      if (levelQuestions.isEmpty) {
        _showPracticeLoadFailure(context.t(K.noQuestionsFound));
        return;
      }
      final start = _recommendedLessonIndex(
        lessons,
      ).clamp(0, lessons.length - 1);
      final orderedLessons = [
        ...lessons.sublist(start),
        ...lessons.sublist(0, start),
      ];
      final perLesson = [
        for (final item in orderedLessons)
          await widget.repository.loadLearningQuizQuestions(
            category: quizCategory,
            learningLessonId: item.slug,
            limit: 5,
          ),
      ];
      if (!mounted) return;
      final topicQuestions = <QuizQuestion>[
        for (var i = 0; i < 5; i++)
          for (final batch in perLesson)
            if (i < batch.length) batch[i],
      ];
      final questions = QuestionSetPolicy.diverseWithoutLeaks([
        ...topicQuestions,
        ...levelQuestions,
      ], limit: 10);
      final room = widget.repository
          .createRoom(category: quizCategory)
          .copyWith(
            name: _categoryLabel(_selectedCategory, context.isKu),
            questionCount: questions.length,
          );
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
      _refreshCompleted();
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

  Future<void> _openLexicon() async {
    await Navigator.of(
      context,
    ).push(AppRoute(page: const LearnerLexiconScreen()));
    // Sözlükte kelime kaydedilmiş olabilir.
    if (mounted) await _loadWordList();
  }

  Future<void> _openMyWords() async {
    await Navigator.of(
      context,
    ).push(AppRoute(page: MyWordsScreen(repository: widget.repository)));
    if (mounted) await _loadWordList();
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
/// "Seviyeni bul" daveti: kart + ikincil "Başla" + metin "Şimdilik geç".
class _PlacementPromptCard extends StatelessWidget {
  const _PlacementPromptCard({
    required this.isKu,
    required this.onStart,
    required this.onDismiss,
  });

  final bool isKu;
  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // 2026-10-20 sadeleşme (tur 11): kart (başlık + açıklama + iki eylem,
    // ~130 px) ilk ekranda sıradaki dersle yarışıyordu; Codex, Opus ve
    // ChatGPT aynı şeyi söyledi. Artık tek satırlık ince şerit: ikon +
    // başlık + "Teste başla ›"; "Şimdilik geç" ikincil, yalnız çarpı.
    // Açıklama cümlesi kalktı (başlık + eylem aynı şeyi söylüyor). Seviye
    // biliniyorsa ya da geçildiyse hiç çizilmez (`_placementPrompt`).
    return SahneSurfaceCard(
      key: const ValueKey('learning-placement-prompt'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x4,
        0,
        SahneSpace.x1,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dar alan ya da büyük yazıda tek satıra sığmaz: başlık sözcük
          // ortasından kesilir, eylem harf harf alt alta kırılırdı (320 pt
          // + 2x yazı). O durumda iki satır: ikon + başlık (sarabilir) +
          // çarpı üstte, "Teste başla ›" altta tek satır.
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          // Tek satıra sığıp sığmadığı ÖLÇÜLÜR: sabit eşik (400) yaygın
          // telefonlarda şeridi hep iki satıra indirip boş bant bırakıyordu,
          // 320 eşiği ise Kurmancî eylemi ("Dest bi azmûnê bike") iki satıra
          // kırıyordu (simülatör + ekran turu, 2026-10-22).
          double textWidth(String text, TextStyle style) {
            final painter = TextPainter(
              // Aile açıkça yazılır: ölçü, çizilen yazı tipiyle aynı olsun
              // (painter_font_test).
              text: TextSpan(
                text: text,
                style: style.copyWith(fontFamily: style.fontFamily),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            return painter.width;
          }

          final needed =
              18 +
              SahneSpace.x2 +
              textWidth(context.t(K.placementCardTitle), SahneType.bodyStrong) +
              textWidth(context.t(K.placementCardStart), SahneType.bodyStrong) +
              40 + // metin düğmesinin dolgusu ve oku
              48 + // çarpı
              SahneSpace.x2;
          final stacked = needed > constraints.maxWidth || scale > 1.3;
          final icon = Icon(AppIcons.compass, size: 18, color: t.learnTx);
          final title = Semantics(
            header: true,
            child: Text(
              context.t(K.placementCardTitle),
              maxLines: stacked ? null : 1,
              overflow: stacked ? TextOverflow.visible : TextOverflow.ellipsis,
              style: SahneType.bodyStrong.copyWith(color: t.tx),
            ),
          );
          final start = SahneButton.text(
            buttonKey: const ValueKey('learning-placement-start'),
            label: context.t(K.placementCardStart),
            onPressed: onStart,
          );
          final dismiss = IconButton(
            key: const ValueKey('learning-placement-dismiss'),
            tooltip: context.t(K.placementSkip),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(AppIcons.xmark, size: 18, color: t.tx3),
            onPressed: onDismiss,
          );
          if (!stacked) {
            return Row(
              children: [
                icon,
                const SizedBox(width: SahneSpace.x2),
                Expanded(child: title),
                Flexible(child: start),
                dismiss,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(child: title),
                  dismiss,
                ],
              ),
              Align(alignment: AlignmentDirectional.centerStart, child: start),
              const SizedBox(height: SahneSpace.x2),
            ],
          );
        },
      ),
    );
  }
}

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
        // İki düğme aynı boyda: Kurmancîde "Pirsan bibersivîne" iki satıra
        // inerken yanındaki tek satırlık düğme kısa kalıyordu.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: practice),
              const SizedBox(width: SahneSpace.x3),
              Expanded(child: flashcards),
            ],
          ),
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
  Widget build(BuildContext context) => SahneRailChip(
    label: label,
    selected: isSelected,
    onTap: onTap,
    vivid: true,
  );
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
    final t = SahneTokens.of(context);
    // 2026-10-19 sadeleşme (ikinci tur): etkin ders gece degradeli sahne
    // kartı ve 80 px'lik "0/21" elmasıydı; ekranın en ağır lekesi ve elmas
    // yalnız soru ilerlemesinde kalmalıydı. Artık sakin yüzey kartı: rozet +
    // kapsül ilerleme, ders adı, bağlam, ince çubuk ve TEK birincil "Başla"
    // düğmesi aynı kartta.
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
        // Tasarım kurulu 2026-10-22 (ChatGPT, Gemini 3.1 Pro, Claude Opus):
        // sıradaki ders kartı yalnız kenarıyla değil DOLU Zimrût yüzeyle
        // öne çıkar (Duolingo'daki ilerleme hissi); yazı beyaz, sağ altta
        // kep filigranı. Agir yalnız "Başla"da kalır; eski 2 px Agir çerçeve
        // dolu yüzeyde gereksiz ağırlık olurdu.
        child: DecoratedBox(
          key: const ValueKey('learning-active-frame'),
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: SahneShape.withSide(SahneShape.l, t.learnFill, width: 2),
          ),
          child: SahneSurfaceCard(
            color: t.learnFill,
            edgeColor: t.learnFill,
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -8,
                  top: 34,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: -10 * math.pi / 180,
                      child: const Icon(
                        AppIcons.graduationCap,
                        size: 96,
                        color: SahneVivid.watermark,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            // Dolu Zimrût üstünde cam çip, beyaz yazı
                            // (turuncu rozet yazısı yeşilde okunmuyordu).
                            child: DecoratedBox(
                              key: const ValueKey('lesson-recommended-badge'),
                              decoration: const ShapeDecoration(
                                color: SahneVivid.glass,
                                shape: StadiumBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SahneSpace.x3,
                                  vertical: SahneSpace.x1,
                                ),
                                child: Text(
                                  context.t(K.recommendedForYou),
                                  style: SahneType.captionStrong.copyWith(
                                    color: SahneVivid.onFill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: SahneSpace.x2),
                        // Kapsül ilerleme "tamamlanan / toplam ders".
                        DecoratedBox(
                          key: const ValueKey('learning-progress-capsule'),
                          decoration: const ShapeDecoration(
                            color: SahneVivid.glass,
                            shape: StadiumBorder(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SahneSpace.x3,
                              vertical: SahneSpace.x1,
                            ),
                            child: Text(
                              '$done/$total',
                              style: SahneType.captionStrong.copyWith(
                                color: SahneVivid.onFill,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: SahneType.headline.copyWith(
                          color: SahneVivid.onFill,
                        ),
                      ),
                    ),
                    if (metaText != null && metaText.isNotEmpty) ...[
                      const SizedBox(height: SahneSpace.x1),
                      Text(
                        metaText,
                        style: SahneType.caption.copyWith(
                          color: SahneVivid.onFillSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: SahneSpace.x3),
                    SahneProgressBar(
                      value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
                      height: 4,
                      semanticLabel: title,
                      trackColor: SahneVivid.glassTrack,
                      fillColor: SahneVivid.onFill,
                      edgeColor: Colors.transparent,
                    ),
                    const SizedBox(height: SahneSpace.x4),
                    SahneButton.primary(
                      label: context.t(K.start),
                      onPressed: onTap,
                      expand: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yolun öteki durakları — ikonsuz liste satırı: ders adı (+ varsa
/// açıklama), sağda ilerleme. Tamamlanan ders yeniden açılabilir (✓,
/// satırın tamamı dokunulur); kilitli ders ikincil metinde, kilit ikonuyla
/// ve dokunulamaz. Durum ekran okuyucuya satırın kendi sözüyle okunur.
///
/// 2026-09-29 doğallık (K7): satırın başındaki 44'lük ders ikonu karosu ve
/// sağdaki ok kalktı; ikon çoğu derste aynı konu ikonuydu (Günlük: hep
/// konuşma balonu) ve satırı şablon bir menüye çeviriyordu.
class _LessonRow extends StatefulWidget {
  const _LessonRow({
    required this.lesson,
    required this.step,
    required this.title,
    required this.completed,
    required this.semanticLabel,
    required this.onTap,
  });

  final Lesson lesson;

  /// Yoldaki sıra numarası (1'den): satırın başındaki durak işareti.
  final int step;
  final String title;
  final bool completed;
  final String semanticLabel;

  /// `null`: kilitli.
  final VoidCallback? onTap;

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow> {
  /// Kilitli satıra her dokunuşta artar; kilit simgesi titrer (dizesiz geri
  /// bildirim: "bu ders henüz açık değil" sessiz kalmasın).
  int _nudge = 0;

  void _nudgeLock() {
    HapticFeedback.selectionClick();
    setState(() => _nudge++);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final title = widget.title;
    final completed = widget.completed;
    final semanticLabel = widget.semanticLabel;
    final onTap = widget.onTap;
    final t = SahneTokens.of(context);
    final locked = onTap == null;
    final description = lesson.description(context.isKu)?.trim();
    // 2026-10-22 görsellik taraması (iki denetçi): liste düz kilitli metin
    // satırlarıydı. Başta yoldaki sırayı gösteren durak işareti: bitti =
    // dolu Zimrût + tik, açık = açık Zimrût + numara, kilitli = sönük
    // numara. Eskiden kalkan konu ikonu (hep aynı ikon) geri gelmedi.
    final row = SahneListRow.leading(
      leading: _LessonStepMark(
        step: widget.step,
        completed: completed,
        locked: locked,
      ),
      leadingWidth: 32,
      title: title,
      // Kilitli satır açıklamasız: soluk liste ilerlemeyi bastırmasın
      // (tur 11). Açıklama dersin kendi ekranında okunur.
      subtitle: locked || description == null || description.isEmpty
          ? null
          : description,
      enabled: !locked,
      onTap: onTap,
      semanticLabel: semanticLabel,
      trailing: locked
          ? TweenAnimationBuilder<double>(
              key: ValueKey('lesson-lock-$_nudge'),
              tween: Tween(begin: _nudge == 0 ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 360),
              builder: (context, v, child) => Transform.translate(
                offset: Offset(6 * math.sin(v * math.pi * 4) * (1 - v), 0),
                child: child,
              ),
              child: Icon(
                AppIcons.lock,
                size: 16,
                color: Color.lerp(t.tx2, t.learnTx, 0.4),
              ),
            )
          // Tamamlanan ders tikini baştaki durak işareti taşır.
          : null,
    );
    if (!locked) return row;
    return GestureDetector(
      key: ValueKey('lesson-locked-${lesson.id}'),
      behavior: HitTestBehavior.opaque,
      // Titreşim yalnız görsel geri bildirim; okuyucu satırı zaten
      // "kilitli" etiketiyle okur (etiketsiz dokunma düğümü üretmesin).
      excludeFromSemantics: true,
      onTap: _nudgeLock,
      child: row,
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
  // 2026-10-06 başlangıç yolu: alfabe, aile, kendini tanıtma, selamlaşma II.
  'sort_by_alpha': AppIcons.font,
  'family_restroom': AppIcons.peopleRoof,
  'badge': AppIcons.user,
  'forum': AppIcons.comment,
  // 2026-10-08 başlangıç yolu II: renkler, vücut, ev, giysiler, hava, soru, fiil.
  'palette': AppIcons.palette,
  'accessibility_new': AppIcons.personCircleCheck,
  'home': AppIcons.house,
  'checkroom': AppIcons.shirt,
  'cloud': AppIcons.cloud,
  'help': AppIcons.question,
  'directions_run': AppIcons.bolt,
  // 2026-10-08 başlangıç yolu III: meslek, şehir, alışveriş, okul, ulaşım, geçmiş.
  'work': AppIcons.briefcase,
  'location_city': AppIcons.buildingColumns,
  'shopping_cart': AppIcons.cartShopping,
  'school': AppIcons.graduationCap,
  'directions_bus': AppIcons.paperPlane,
  'history': AppIcons.clock,
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
    if (_listeningSpeaker == null && _lexiconEntries.length >= 2) {
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

  /// Dersin sözlük çiftleri. Kimlik değil slug: sunucu dersinde `id` UUID'dir
  /// (bkz. `LearningLessonAliases.lexiconEntriesFor`).
  List<LearnerLexiconEntry> get _lexiconEntries =>
      LearningLessonAliases.lexiconEntriesFor(
        widget.lesson.slug,
        fallbackKey: widget.lesson.id,
      );

  Future<void> _loadListeningSpeaker() async {
    try {
      final speaker = await LessonAudio.shared();
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

  /// Slayt değişince kart ÖN yüzle (animasyonsuz) açılır; yoksa bir önceki
  /// kartın cevap yüzü sonraki kartta kalıyordu.
  void _goToSlide(int index) {
    setState(() {
      _currentSlideIndex = index;
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
        // Kimlik değil slug: yerel derste ikisi aynıdır, sunucu dersinde
        // `id` bir UUID'dir ve ölçme bankasında karşılığı yoktur (bkz.
        // `LearningLessonAliases`).
        learningLessonId: widget.lesson.slug,
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

  Widget _buildKuContentRow(
    LessonSlide slide,
    BuildContext context, {
    bool lookup = true,
  }) {
    final t = SahneTokens.of(context);
    // Kart kipinde dokunuş kartı çevirir; sözcük dokunuşu orada kapalı.
    if (!lookup) {
      return Text(slide.contentKu, style: SahneType.body.copyWith(color: t.tx));
    }
    // Kurmancî sözcüğe dokununca sözlük maddesi açılır. `• terim: anlam`
    // çiftleri düz kalır (terim ve anlamı zaten yan yana yazılı); başlık ve
    // örnek satırlardaki sözcükler dokunulabilir.
    // `• terim: anlam` satırları sesli kelime kartı, harf satırı karo
    // olur (bkz. LessonContentBlocks); öteki satırlar dokunulabilir kalır.
    return LessonContentBlocks(text: slide.contentKu);
  }

  /// Örnek cümle: Kulis (`s2`) tonlu M pahlı kutu, ikincil metin.
  Widget _buildExample(String example, BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x3),
        // Örnek cümlenin sesi varsa yanında dinle düğmesi (2026-10-22,
        // ders örnekleri seslendirildi); yoksa düğme yer kaplamaz.
        child: Row(
          children: [
            Expanded(
              child: Text(
                example,
                style: SahneType.caption.copyWith(
                  color: t.tx2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            LexiconSpeakButton(text: example),
          ],
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
            _buildKuContentRow(slide, context, lookup: false),
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

  /// Çift dokunuşta ikinci RPC ve ikinci `Navigator.pop` (fazladan bir ekran
  /// geri atılır) olmasın diye süren çağrı varken düğme pasiftir.
  bool _completing = false;

  Future<void> _markCompleted() async {
    if (_completing) return;
    setState(() => _completing = true);
    final lessonId = widget.lesson.id;
    var success = false;
    // Sunucu onaylamadıysa dersi yine de bitmiş say: önce yerele yazılır,
    // sonra eşitleme kuyruğuna girer; bağlantı gelince kendiliğinden gider.
    // Yerel yazım da olmazsa (kuyruk yok / disk yazmadı) dürüstçe hata göster.
    var savedOffline = false;
    try {
      success = await widget.repository.markLessonCompleted(lessonId);
      if (!success) savedOffline = await _queueLessonCompletion(lessonId);
      if (success || savedOffline) unawaited(StreakStore.recordActivity());
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mark_lesson_completed');
    }
    if (mounted && !(success || savedOffline)) {
      setState(() => _completing = false);
    }
    if ((success || savedOffline) && mounted) {
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
          content: Text(
            context.t(success ? K.dersTamamlandi : K.lessonSavedOffline),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      // Ne sunucuya ne yerele yazılabildi: "tamamlandı" demeden, ekranı
      // kapatmadan kullanıcının tekrar deneyebilmesi için son slaytta bırak.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.lessonCompleteFailed))),
      );
    }
  }

  /// Dersi yerele yazıp eşitleme kuyruğuna alır; yerel yazım olduysa `true`.
  ///
  /// Kuyruk sahibi yoksa (oturum açık değil / kuyruk kurulmadı) yine de
  /// bekleyen kümeye yazılır; ilk gerçek girişte `queueScopedOfflineLessons`
  /// onu sunucuya taşır.
  Future<bool> _queueLessonCompletion(String lessonId) async {
    try {
      final manager = SyncManager.maybeInstance;
      if (manager != null) {
        await manager.queueLessonCompletion(lessonId);
        return true;
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'lesson completion queue');
    }
    try {
      return await LessonCompletionStore.addPending(lessonId);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'lesson completion local');
      return false;
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
        backgroundColor: t.learnFill,
        foregroundColor: SahneVivid.onFill,
        glassBack: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        // Ders başlığı arayüz diline uyar; Kurmancî adı yedek kalır.
        title: Text(
          ku
              ? widget.lesson.titleKu
              : (widget.lesson.titleTr ?? widget.lesson.titleKu),
        ),
        actions: [
          SahneIconButton(
            glass: true,
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
            final recallEntries = _lexiconEntries;

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
                    semanticLabel: ku
                        ? widget.lesson.titleKu
                        : (widget.lesson.titleTr ?? widget.lesson.titleKu),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(SahneSpace.page),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_miniQuizEmpty)
                          // "Soru yok" bir HATA değildir: tekrar denemek
                          // sonucu değiştirmez. Eskiden "Quiz yüklenemedi" +
                          // yalnız "Tekrar dene" vardı, yani çıkışsız bir
                          // sokaktı. Şimdi durum açıkça söylenir ve kapatılır;
                          // ders akışı (Geri / Tamamla) altta duruyor.
                          AppEmptyState(
                            key: const ValueKey('mini-quiz-empty'),
                            icon: AppIcons.bookOpen,
                            title: context.t(K.noQuestionsForCategory),
                            message: context.t(K.miniQuizNone),
                            actionLabel: context.t(K.close),
                            primaryAction: false,
                            onAction: () =>
                                setState(() => _miniQuizEmpty = false),
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
                                // Türkçe açıklama yalnız Türkçe arayüzde: Kurmancî
                                // arayüzde Kurmancî metnin altında Türkçe düz
                                // yazı çıkıyordu. Alan bir "öğrenci ipucu" diye
                                // işaretli değil (sunucuda `content_tr` serbest
                                // metin); dokunarak çevrilen kart arkası ise
                                // kullanıcının isteğidir ve dilden bağımsız kalır.
                                if (slide.contentTr case final contentTr?
                                    when !ku && contentTr.isNotEmpty) ...[
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
                  child: LessonSlideNavigation(
                    showBack: _currentSlideIndex > 0,
                    isLast: isLast,
                    onBack: () => _goToSlide(_currentSlideIndex - 1),
                    onNext: isLast
                        ? (_completing ? null : _markCompleted)
                        : () => _goToSlide(_currentSlideIndex + 1),
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
@visibleForTesting
class LessonSlideNavigation extends StatelessWidget {
  const LessonSlideNavigation({
    required this.showBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onMiniQuiz,
    super.key,
  });

  final bool showBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback? onNext;
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
        // 2026-09-30 simülatör: büyük yazıda "Paş" ve "Biqedîne" yan yana
        // yarım genişliğe düşüyor, "Biqedîn/e" kelime ortasından
        // kırılıyordu (tur ve testler 1.0 ölçekte koşuyordu). Büyük yazıda
        // düğmeler alt alta, tam genişlikte: birincil üstte, ikincil
        // "Mini Quiz" ve "Paş" altında.
        if (largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              next,
              if (isLast) ...[const SizedBox(height: SahneSpace.x2), miniQuiz],
              if (showBack) ...[const SizedBox(height: SahneSpace.x2), back],
            ],
          );
        }
        final oneRow = isLast && constraints.maxWidth >= 560;
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
    // Görsel süstür (ders/soru metni zaten okunur); ekran okuyucuya etiketsiz
    // bir "görsel" düğümü olarak çıkmaz.
    return ExcludeSemantics(
      child: ClipPath(
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
      ),
    );
  }
}

/// Ders yolunda durak işareti (bkz. [_LessonRow]).
class _LessonStepMark extends StatelessWidget {
  const _LessonStepMark({
    required this.step,
    required this.completed,
    required this.locked,
  });

  final int step;
  final bool completed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Kurul 2. tur (iki denetçi): üç durum zor ayrılıyordu, kilitli numara
    // çok sönüktü. Açık durak Zimrût kenarlı, kilitli numara okunur tonda.
    final fill = completed
        ? t.learn
        : locked
        ? t.s2
        : t.learnTint;
    final ink = completed
        ? Colors.white
        : locked
        ? Color.lerp(t.tx2, t.tx, 0.35)!
        : t.learnTx;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('lesson-step-mark'),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: fill,
          shape: SahneShape.withSide(
            SahneShape.s,
            completed
                ? t.learn
                : locked
                ? t.line
                : t.learnTx,
            width: locked ? 1 : 1.5,
          ),
        ),
        child: completed
            ? Icon(AppIcons.check, size: 16, color: ink)
            : Text(
                '$step',
                style: SahneType.captionStrong.copyWith(color: ink),
              ),
      ),
    );
  }
}
