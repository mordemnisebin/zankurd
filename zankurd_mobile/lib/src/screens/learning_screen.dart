import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
import '../widgets/learn_path.dart';
import '../widgets/zk_back_button.dart';
import 'learner_lexicon_screen.dart';
import 'my_words_screen.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../services/app_haptics.dart';
import 'alphabet_screen.dart';
import 'stories_screen.dart';
import 'tekrar_screen.dart';

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

/// Ders yolunda bir ünitedeki ders sayısı.
const int _kLessonsPerUnit = 5;

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
  final _reviewRefresh = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _refreshCompleted();
    _loadPlacementLevel();
    _loadWordList();
  }

  @override
  void dispose() {
    _reviewRefresh.dispose();
    super.dispose();
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
    // Önceki kategorinin pratik kartları yeni kategori yüklenirken
    // erişilebilir kalmamalı.
    _currentLessons = const [];
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
            if (mounted) {
              setState(() {
                _currentLessons = const [];
                _lessonsLoading = false;
              });
            }
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
        accent: t.learnFill,
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
              // Akıllı tekrar (SM-2) en üstte, ama yalnız gerçekten tekrar
              // bekliyorsa: vadesi gelmiş soru, yeni dersten daha acildir.
              // Hiç ders çözmemiş birine "Tekrarlar tamam" yazmak yapılmamış
              // bir işi bitmiş gösteriyordu (2026-09-27).
              _page(
                TodaysReviewCard(
                  repository: widget.repository,
                  isKu: ku,
                  hideWhenEmpty: true,
                  refreshSignal: _reviewRefresh,
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
              _page(
                _buildLessons(
                  context,
                  ku,
                  // 2026-10-28 tur 3 T13: "Seviyeni bul" daveti kahramanın
                  // ÜSTÜNDE değil ALTINDA: önce ne yapacağını gör.
                  afterHero: _placementPrompt
                      ? _PlacementPromptCard(
                          isKu: ku,
                          onStart: _openPlacement,
                          onDismiss: _dismissPlacementPrompt,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: SahneSpace.sectionTop),
              // Pratik merkezi (2026-10-27, rakip kıyası): Duolingo'da
              // Practice, Busuu'da Review sekmesi gibi tekrar, kelimeler ve
              // ses araçları tek yerde ve ders yolunun hemen ardında. Eskiden
              // sözlük/alfabe/kelimelerim sayfanın dibindeydi, tekrar yalnız
              // vadesi gelince görünüyordu, kaydedilen sorular yalnız
              // Profil'deydi.
              _page(SahneSectionHeader(title: context.t(K.practiceSection))),
              // 2x2 kompakt ızgara (2026-10-28 kurul K8): beş satırlık liste
              // ilk ekranı uzatıyordu. "Kaydedilen sorular" Profil'de duruyor
              // (Profil → Öğrenme), burada ikinci kez yer tutmaz.
              _page(
                _PracticeGrid(
                  key: const ValueKey('learning-practice-hub'),
                  tiles: [
                    // T13: "Soru çöz" / "Kartlarla çalış" ikili düğmesi
                    // kalktı (aynı eylemler iki yerde, ders listesi ile
                    // Pratik arasında); araç olarak ızgaraya katıldı.
                    _PracticeTileData(
                      key: const ValueKey('learning-topic-practice'),
                      icon: AppIcons.circleQuestion,
                      title: Tr.forKu(K.soruCoz, ku),
                      onTap: !_lessonsLoading && _currentLessons.isNotEmpty
                          ? _openCategoryPractice
                          : null,
                    ),
                    _PracticeTileData(
                      key: const ValueKey('learning-topic-flashcards'),
                      icon: AppIcons.layerGroup,
                      title: Tr.forKu(K.flasKart, ku),
                      onTap: !_lessonsLoading && _currentLessons.isNotEmpty
                          ? _openCategoryFlashcards
                          : null,
                    ),
                    _PracticeTileData(
                      key: const ValueKey('learning-practice-review'),
                      icon: AppIcons.arrowsRotate,
                      title: context.t(K.tekrarTitle),
                      onTap: _openTekrar,
                    ),
                    _PracticeTileData(
                      key: const ValueKey('learning-lexicon-entry'),
                      icon: AppIcons.magnifyingGlass,
                      title: context.t(K.lexiconTitle),
                      onTap: _openLexicon,
                    ),
                    // Alfabe ve sesler (2026-10-27): harf-ses başvurusu;
                    // eskiden yalnız ilk dersin içindeydi.
                    _PracticeTileData(
                      key: const ValueKey('learning-alphabet-entry'),
                      icon: AppIcons.volumeHigh,
                      title: context.t(K.alphabetTitle),
                      onTap: () => Navigator.of(
                        context,
                      ).push(AppRoute.to(const AlphabetScreen())),
                    ),
                    _PracticeTileData(
                      key: const ValueKey('learning-my-words-entry'),
                      icon: AppIcons.bookmark,
                      title: context.t(K.wordsTitle),
                      // Vadesi gelen sayısı burada DEĞİL: tekrar girişi tektir.
                      subtitle: _wordCount > 0
                          ? context.t(K.wordsCount, {'count': '$_wordCount'})
                          : null,
                      onTap: _openMyWords,
                    ),
                  ],
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
                    limit: 3,
                    onShowAll: () => Navigator.of(
                      context,
                    ).push(AppRoute.to(const StoriesScreen())),
                    onOpen: (story, guide) async {
                      await Navigator.of(context).push(
                        AppRoute(
                          page: StoryScreen(story: story, guide: guide),
                        ),
                      );
                      if (!mounted) return;
                      _reviewRefresh.value++;
                      await _loadWordList();
                    },
                  ),
                ),
              ),
              // "Seviyeni yeniden belirle" buradan kalktı (2026-10-28 kurul K8):
              // Ayarlar'da var; ilk açılış daveti `_PlacementPromptCard` kalır.
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

  Widget _buildLessons(BuildContext context, bool ku, {Widget? afterHero}) {
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
            onRetry: () => setState(_loadLessons),
          );
        }
        final lessons = snap.data ?? [];
        if (lessons.isEmpty) {
          return AppEmptyState(
            icon: AppIcons.graduationCap,
            title: context.t(K.noLesson),
            message: context.t(K.noLessonInCategory),
            actionLabel: context.t(K.retryShort),
            onAction: () => setState(_loadLessons),
          );
        }
        final firstOpenIndex = _recommendedLessonIndex(lessons);
        // 2026-10-29 vay 2B (B6, Astra 7/10 "liste gibi"): etkin ünitenin
        // dersleri artık bir KEŞİF ROTASI — ünite başı sahnesi (manzara +
        // rehber maskot) ve kıvrımlı yol üstünde 64'lük düğümler; güncel ders
        // 80'lik düğüm + 3 px halka, altında tek turuncu "Başla"lı kart.
        // Önceki üniteler (bitenler) ve sonraki dersler eski liste dilinde
        // kalır; kilitli sonraki dersler tek "Tüm dersler (+N)" satırında.
        //
        // Geçmiş: 2026-09-29 (K5, K7) elmas düğümlü yol ikonsuz satırlara
        // döndü; 2026-10-25 beşerli üniteler; 2026-10-20 kilitli satırlar
        // ikiyle sınırlandı. Rota, ünitenin en çok 5 dersini gösterdiği için
        // aynı sınırı (5–7 düğüm) kendisi taşır.
        final blocks = <Widget>[];
        var run = <Widget>[];
        void closeRun() {
          if (run.isEmpty) return;
          blocks.add(SahneListGroup(children: run));
          run = <Widget>[];
        }

        final unitCount = (lessons.length / _kLessonsPerUnit).ceil();
        final pathUnit =
            (firstOpenIndex < 0 ? lessons.length - 1 : firstOpenIndex) ~/
            _kLessonsPerUnit;
        final pathFrom = pathUnit * _kLessonsPerUnit;
        final pathTo = math.min(pathFrom + _kLessonsPerUnit, lessons.length);
        int doneIn(int from, int to) => [
          for (var j = from; j < to; j++) lessons[j],
        ].where((l) => _completedIds.contains(l.id)).length;

        var unitHeaderShown = -1;
        var lockedHidden = 0;
        void listLesson(int i) {
          final isLocked = learningLessonLocked(
            index: i,
            completed: _completedIds.contains(lessons[i].id),
            recommendedIndex: firstOpenIndex,
          );
          if (isLocked && !_showAllLocked) {
            lockedHidden++;
            return;
          }
          final unit = i ~/ _kLessonsPerUnit;
          if (unitCount > 1 && unit != unitHeaderShown) {
            unitHeaderShown = unit;
            closeRun();
            final from = unit * _kLessonsPerUnit;
            final to = math.min(from + _kLessonsPerUnit, lessons.length);
            blocks.add(
              _UnitHeader(
                key: ValueKey('learning-unit-${unit + 1}'),
                number: unit + 1,
                done: doneIn(from, to),
                total: to - from,
              ),
            );
          }
          run.add(
            _listStop(
              ctx,
              ku,
              lessons: lessons,
              index: i,
              firstOpenIndex: firstOpenIndex,
            ),
          );
        }

        // Önceki üniteler: liste.
        for (var i = 0; i < pathFrom; i++) {
          listLesson(i);
        }
        closeRun();
        // Etkin ünite: sahne + rota.
        blocks.add(
          LearnUnitScene(
            key: ValueKey('learning-unit-${pathUnit + 1}'),
            eyebrow: context.t(K.learningUnit, {'n': '${pathUnit + 1}'}),
            title: _categoryLabel(_selectedCategory, ku),
            done: doneIn(pathFrom, pathTo),
            total: pathTo - pathFrom,
            countLabel: context.t(K.lessonCountProgress, {
              'done': '${doneIn(pathFrom, pathTo)}',
              'total': '${pathTo - pathFrom}',
            }),
          ),
        );
        blocks.add(
          LearnPath(
            key: const ValueKey('learning-route'),
            stops: [
              for (var i = pathFrom; i < pathTo; i++)
                _routeStop(
                  ctx,
                  ku,
                  lessons: lessons,
                  index: i,
                  firstOpenIndex: firstOpenIndex,
                  // T13 (2026-10-28 tur 3): "Seviyeni bul" kahramanın ALTINDA.
                  after: afterHero,
                ),
            ],
          ),
        );
        // Güncel ders bu ünitede değilse (hepsi bitti) davet rotanın ardında.
        final heroInPath =
            firstOpenIndex >= pathFrom && firstOpenIndex < pathTo;
        if (afterHero != null && !heroInPath) blocks.add(afterHero);
        // Sonraki dersler: kilitliler gizli, "Tüm dersler (+N)".
        unitHeaderShown = pathUnit;
        for (var i = pathTo; i < lessons.length; i++) {
          listLesson(i);
        }
        if (lockedHidden > 0) {
          run.add(
            SahneListRow.plain(
              key: const ValueKey('learning-locked-more'),
              dense: true,
              title: context.t(K.allLessonsMore, {'n': '$lockedHidden'}),
              onTap: () => setState(() => _showAllLocked = true),
              // W3 (2026-10-28 tur 5): kilit değil ok — satır kilitli dersleri
              // AÇAN bir eylemdir; kilit "dokunulamaz" okunuyordu.
              chevron: true,
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

  /// Rota durağı. Anahtarlar (`learning-path-node-…`, `learning-route-stop-…`,
  /// güncelde `learning-next-step`) ekranın test sözleşmesidir.
  LearnPathStop _routeStop(
    BuildContext context,
    bool ku, {
    required List<Lesson> lessons,
    required int index,
    required int firstOpenIndex,
    Widget? after,
  }) {
    final t = SahneTokens.of(context);
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
    void open() => _openLesson(lesson);
    Widget keyed(Widget child) => KeyedSubtree(
      key: ValueKey('learning-path-node-${lesson.id}'),
      child: KeyedSubtree(
        key: ValueKey('learning-route-stop-${lesson.id}'),
        child: locked
            ? KeyedSubtree(
                key: ValueKey('lesson-locked-${lesson.id}'),
                child: child,
              )
            : child,
      ),
    );
    if (current) {
      return LearnPathStop(
        state: LearnNodeState.current,
        step: index + 1,
        icon: iconForLesson(lesson),
        semanticLabel: semanticLabel,
        onTap: open,
        after: after,
        // 2026-10-29 son kurul tur 2 (E, Sol + Terra + Astra): düğümün
        // yanındaki "Sıradaki ders" ve "1. ders" rozetleri kalktı. Ünite
        // kartı, düğüm ve dolu ders kartı aynı başlangıcı dört kez
        // söylüyordu; güncel ders artık düğüm + kartla BİR kez söylenir.
        attachment: _CurrentLessonCard(
          lesson: lesson,
          title: _lessonTitle(lesson, ku),
          meta: _placementContextLabel(context, ku) ?? lesson.description(ku),
          onTap: open,
        ),
        // Satır + kart tek düğme: ekran okuyucu "Sıradaki ders. Alfabe.
        // Sonraki" duyar; kartın her yeri dokunulur.
        wrap: (child) => keyed(
          Semantics(
            key: const ValueKey('learning-next-step'),
            button: true,
            enabled: true,
            label: semanticLabel,
            onTap: open,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: child,
            ),
          ),
        ),
      );
    }
    return LearnPathStop(
      state: completed
          ? LearnNodeState.done
          : locked
          ? LearnNodeState.locked
          : LearnNodeState.open,
      step: index + 1,
      icon: iconForLesson(lesson),
      title: _lessonTitle(lesson, ku),
      status: completed
          ? Text(
              context.t(K.dersTamamlandi),
              style: SahneType.captionStrong.copyWith(color: t.okTx),
            )
          // 2026-10-29 son kurul tur 2 (E, Terra ×2 + Sol + Astra): kilitli
          // dersler nasıl açılacağını söylemiyordu. İpucu yalnız İLK kilitli
          // düğümde (güncelin hemen ardı); her kilitliye yazmak rotayı
          // aynı cümleyle doldururdu.
          : locked && index == firstOpenIndex + 1
          ? Text(
              context.t(K.lessonUnlockHint),
              key: const ValueKey('learning-unlock-hint'),
              style: SahneType.caption.copyWith(color: t.tx2),
            )
          : null,
      semanticLabel: semanticLabel,
      onTap: locked ? null : open,
      wrap: keyed,
    );
  }

  /// Rota dışındaki ders (önceki üniteler, açılan sonraki dersler): liste
  /// satırı.
  Widget _listStop(
    BuildContext context,
    bool ku, {
    required List<Lesson> lessons,
    required int index,
    required int firstOpenIndex,
  }) {
    final lesson = lessons[index];
    final completed = _completedIds.contains(lesson.id);
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
      current: false,
      locked: locked,
    );
    return KeyedSubtree(
      key: ValueKey('learning-path-node-${lesson.id}'),
      child: KeyedSubtree(
        key: ValueKey('learning-route-stop-${lesson.id}'),
        child: _LessonRow(
          lesson: lesson,
          step: index + 1,
          title: _lessonTitle(lesson, ku),
          completed: completed,
          semanticLabel: semanticLabel,
          onTap: locked ? null : () => _openLesson(lesson),
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
    if (!mounted) return;
    _reviewRefresh.value++;
    await _refreshCompleted();
    if (mounted) await _loadWordList();
  }

  Future<void> _openCategoryPractice() async {
    if (_lessonsLoading || _currentLessons.isEmpty || !mounted) return;
    final selectedCategory = _selectedCategory;
    final lessons = List<Lesson>.of(_currentLessons);
    if (lessons.any((lesson) => lesson.category != selectedCategory)) return;
    final lesson = lessons.first;
    final quizCategory = quizCategoryForLesson(lesson.category);
    try {
      final levelQuestions = await widget.repository.loadLevelQuestions(
        category: quizCategory,
        difficultyMin: 1,
        difficultyMax: 5,
        limit: 10,
      );
      if (!mounted || _selectedCategory != selectedCategory) return;
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
      if (!mounted || _selectedCategory != selectedCategory) return;
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
            name: _categoryLabel(selectedCategory, context.isKu),
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
      if (!mounted) return;
      _reviewRefresh.value++;
      await _refreshCompleted();
      if (mounted) await _loadWordList();
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
    if (_lessonsLoading || _currentLessons.isEmpty) return null;
    final index = _recommendedLessonIndex(_currentLessons);
    final lesson =
        _currentLessons[index < 0 ? _currentLessons.length - 1 : index];
    return lesson.category == _selectedCategory ? lesson : null;
  }

  Future<void> _openLexicon() async {
    await Navigator.of(
      context,
    ).push(AppRoute(page: const LearnerLexiconScreen()));
    // Sözlükte kelime kaydedilmiş olabilir.
    if (!mounted) return;
    _reviewRefresh.value++;
    await _loadWordList();
  }

  /// Tekrar her zaman açılır; vadesi gelen yoksa ekran bunu söyler.
  Future<void> _openTekrar() async {
    await Navigator.of(context).push(
      AppRoute.to(
        TekrarScreen(repository: widget.repository, isKu: context.isKu),
      ),
    );
    if (!mounted) return;
    _reviewRefresh.value++;
    await _loadWordList();
  }

  Future<void> _openMyWords() async {
    await Navigator.of(
      context,
    ).push(AppRoute(page: MyWordsScreen(repository: widget.repository)));
    if (!mounted) return;
    _reviewRefresh.value++;
    await _loadWordList();
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
    if (!mounted) return;
    _reviewRefresh.value++;
    await _refreshCompleted();
    if (mounted) await _loadWordList();
  }

  String _categoryLabel(String cat, bool ku) {
    const labels = {
      'everyday': ('Jiyana rojane', 'Gündelik hayat'),
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
            ink: true,
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

/// Rotanın güncel düğümünün altındaki kart (konuşma balonu gibi): ders adı,
/// bağlam satırı (yerleştirme seviyesi ya da dersin açıklaması) ve tam
/// genişlik TEK birincil düğme.
///
/// Semantik ve kartın her yerine dokunma, düğümle birlikte dış sarmalayıcıda
/// (`learning-next-step`): ekran okuyucu tek bir düğme duyar.
class _CurrentLessonCard extends StatelessWidget {
  const _CurrentLessonCard({
    required this.lesson,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final Lesson lesson;
  final String title;
  final String? meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metaText = meta?.trim();
    final t = SahneTokens.of(context);
    // Tasarım kurulu 2026-10-22: sıradaki ders DOLU Zimrût yüzeyle öne
    // çıkar; Agir yalnız "Başla"da. 2026-10-29 vay 2B: sağ alttaki silik kep
    // filigranı kalktı (Astra: "marka kimliğine katkı sağlamıyor"); rozetler
    // düğümün yanına taşındı.
    return DecoratedBox(
      key: const ValueKey('learning-active-frame'),
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: SahneShape.withSide(SahneShape.l, t.learnFill, width: 2),
      ),
      child: SahneSurfaceCard(
        color: t.learnFill,
        edgeColor: t.learnFill,
        // Son kurul tur 3: üst dolgu 16 → 12, Başla öncesi 16 → 12 (ilk
        // ekranda rotanın devamı görünsün; düğüm + kart tek birim).
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.x4,
          SahneSpace.x3,
          SahneSpace.x4,
          SahneSpace.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: SahneType.headline.copyWith(color: SahneVivid.onFill),
              ),
            ),
            if (metaText != null && metaText.isNotEmpty) ...[
              const SizedBox(height: SahneSpace.x1),
              Text(
                metaText,
                key: const ValueKey('learning-active-meta'),
                style: SahneType.caption.copyWith(color: SahneVivid.onFill),
              ),
            ],
            const SizedBox(height: SahneSpace.x3),
            SahneButton.primary(
              label: context.t(K.start),
              onPressed: onTap,
              expand: true,
            ),
          ],
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
    AppHaptics.selection();
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
    // Türkçe karşılık yalnız Türkçe arayüzde ve her açıklama cümlesinin
    // HEMEN altında (kapışma U20); Kurmancî arayüzde verilmez.
    return LessonContentBlocks(
      text: slide.contentKu,
      translation: context.isKu ? null : slide.contentTr,
    );
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
        accent: t.learnFill,
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
                                // Türkçe açıklama yalnız Türkçe arayüzde ve artık
                                // kartın sonunda değil, açıklama cümlesinin hemen
                                // altında (kapışma U20; bkz. LessonContentBlocks).
                                // Dokunarak çevrilen kart arkası kullanıcının
                                // isteğidir ve dilden bağımsız kalır.
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
                        if (isLast) ...[
                          const SizedBox(height: SahneSpace.cardGap),
                          const LessonFinishHint(),
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
                  // Çözme genişliği sınırlı: kaynak ne kadar büyük olursa
                  // olsun tam çözünürlükte belleğe açılmaz (Codex
                  // denetimi 2026-10-29); uzak görselle aynı sınır.
                  cacheWidth: 720,
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

/// Ünite başlığı: "Ünite 2" + ince ilerleme çubuğu ve "3/5".
class _UnitHeader extends StatelessWidget {
  const _UnitHeader({
    required this.number,
    required this.done,
    required this.total,
    super.key,
  });

  final int number;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final complete = done >= total;
    final countLabel = context.t(K.lessonCountProgress, {
      'done': '$done',
      'total': '$total',
    });
    // Büyük yazıda (≥ %150) "Beşa 1" + "0/5 ders" + çubuk tek satıra sığmaz
    // (320 pt, ×2: 30 pt taştı, 2026-10-28 tur 3): ad ve sayaç üstte, çubuk
    // altta.
    if (MediaQuery.textScalerOf(context).scale(14) >= 21) {
      return Padding(
        padding: const EdgeInsets.only(top: SahneSpace.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (complete) ...[
                  Icon(AppIcons.circleCheck, size: 18, color: t.okTx),
                  const SizedBox(width: SahneSpace.x2),
                ],
                Expanded(
                  child: Text(
                    context.t(K.learningUnit, {'n': '$number'}),
                    style: SahneType.eyebrow.copyWith(color: t.learnTx),
                  ),
                ),
                Text(
                  countLabel,
                  style: SahneType.captionStrong.copyWith(color: t.tx),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x1),
            SahneProgressBar(
              value: total == 0 ? 0 : done / total,
              height: 4,
              semanticLabel: context.t(K.learningUnit, {'n': '$number'}),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x2),
      child: Row(
        children: [
          if (complete) ...[
            Icon(AppIcons.circleCheck, size: 18, color: t.okTx),
            const SizedBox(width: SahneSpace.x2),
          ],
          Text(
            context.t(K.learningUnit, {'n': '$number'}),
            style: SahneType.eyebrow.copyWith(color: t.learnTx),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: SahneProgressBar(
              value: total == 0 ? 0 : done / total,
              height: 4,
              trailing: countLabel,
              semanticLabel: context.t(K.learningUnit, {'n': '$number'}),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTileData {
  const _PracticeTileData({
    required this.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
}

/// Pratik araçları: iki sütunlu kompakt kartlar (rozet + ad). Büyük yazıda
/// tek sütuna düşer.
class _PracticeGrid extends StatelessWidget {
  const _PracticeGrid({required this.tiles, super.key});

  final List<_PracticeTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final columns = scale > 1.3 ? 1 : 2;
    Widget tile(_PracticeTileData d) => SahneSurfaceCard(
      key: d.key,
      onTap: d.onTap,
      semanticLabel: [d.title, ?d.subtitle].join(', '),
      padding: const EdgeInsets.all(SahneSpace.x3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ExcludeSemantics(
          child: Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: d.onTap == null ? t.disabledFill : t.learnTint,
                  shape: SahneShape.m,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    d.icon,
                    size: 22,
                    color: d.onTap == null ? t.tx3 : t.learnTx,
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.title,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                    if (d.subtitle != null)
                      Text(
                        d.subtitle!,
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    const gap = SahneSpace.x3;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) const SizedBox(width: gap),
                Expanded(
                  child: j < tiles.length
                      ? tile(tiles[j])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Son slaytın akış notu (kapışma U14, 2026-10-29).
///
/// Son slaytta "Tamamla" ile "Kısa test" yan yana duruyordu; hangisinin dersi
/// bitirdiği ve testin tamamlamaya etkisi yazmıyordu (kare 96). Davranış:
/// Tamamla dersi yerel + sunucu kuyruğuna yazar ve sonrakinin kilidini açar;
/// kısa test ödülsüz alıştırmadır, tamamlamayı değiştirmez. Not kaydırılan
/// içerikte durur: alt perdeye konunca %200 yazıda perde içeriği eziyordu.
class LessonFinishHint extends StatelessWidget {
  const LessonFinishHint({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      key: const ValueKey('lesson-finish-hint'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.circleCheck, size: 20, color: t.tx2),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(
            context.t(K.lessonFinishHint),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ),
      ],
    );
  }
}
