import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/learner_lexicon.dart';
import '../data/word_list_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/app_route.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../utils/word_csv.dart';
import '../widgets/app_state.dart';
import '../widgets/lexicon_lookup.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/todays_review_card.dart';
import '../widgets/word_save_button.dart';
import '../widgets/zk_back_button.dart';
import 'word_drill_screen.dart';

/// "Kelimelerim": kullanıcının kaydettiği sözlük maddeleri, her kelimenin
/// Leitner kutusu ve tek "Tekrar · bugün N" girişi.
///
/// Tekrar başlatma burada ayrı bir mekanizma DEĞİLDİR: kart, öğrenme
/// ekranındakiyle aynı [TodaysReviewCard]dır (kelime + yanlış sorusu tek
/// oturum). Eskiden burada yalnız kelimeleri açan ikinci bir "Bugünkü
/// tekrar" kartı vardı; kullanıcı ikisini ayıramıyordu (2026-10-24).
///
/// Liste [WordListStore]u dinler: kelime yer işaretiyle çıkarılınca satır
/// anında kaybolur; tekrar oturumundan dönünce sayılar tazelenir.
class MyWordsScreen extends StatefulWidget {
  const MyWordsScreen({required this.repository, this.store, super.key});

  /// Tekrar oturumunun soru aşaması için.
  final ZanKurdRepository repository;

  /// Testlerde verilir; yoksa kullanıcının paylaşılan listesi.
  final WordListStore? store;

  @override
  State<MyWordsScreen> createState() => _MyWordsScreenState();
}

class _MyWordsScreenState extends State<MyWordsScreen> {
  WordListStore? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      store.addListener(_changed);
      if (!mounted) {
        store.removeListener(_changed);
        return;
      }
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'my_words_load');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final store = _store;
    final words = store?.words ?? const <SavedWord>[];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(context.t(K.wordsTitle)),
        actions: words.isEmpty
            ? null
            : [
                SahneIconButton(
                  key: const ValueKey('my-words-share'),
                  icon: AppIcons.shareNodes,
                  semanticLabel: context.t(K.share),
                  onPressed: () => _shareCsv(words),
                ),
              ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : words.isEmpty
            ? AppEmptyState(
                key: const ValueKey('my-words-empty'),
                icon: AppIcons.bookmark,
                title: context.t(K.wordsEmptyTitle),
                message: context.t(K.wordsEmptyBody),
              )
            : Builder(
                builder: (context) {
                  // Kelime listesi sınırsız büyür; kartlar tembel çizilir
                  // (yalnız görünenler). Üst bölüm sabit birkaç parçadır.
                  final header = [
                    _reviewCard(context, t, store!),
                    _practiceSection(context, t, words),
                    const SizedBox(height: SahneSpace.x4),
                    Text(
                      context.t(K.wordsCount, {'count': '${words.length}'}),
                      key: const ValueKey('my-words-count'),
                      style: SahneType.captionStrong.copyWith(color: t.tx2),
                    ),
                    const SizedBox(height: SahneSpace.x2),
                  ];
                  return ListView.builder(
                    key: const ValueKey('my-words-list'),
                    padding: const EdgeInsets.fromLTRB(
                      SahneSpace.page,
                      SahneSpace.x2,
                      SahneSpace.page,
                      SahneSpace.x6,
                    ),
                    itemCount: header.length + words.length,
                    itemBuilder: (context, index) {
                      if (index < header.length) return header[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                        child: _wordCard(
                          context,
                          t,
                          words[index - header.length],
                          store,
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  /// Listeyi CSV olarak paylaşır (Excel'de açılır). Sözlük kimliği
  /// bulunamayan kayıtlar atlanır; liste boşsa düğme gösterilmez.
  Future<void> _shareCsv(List<SavedWord> words) async {
    final rows = [
      for (final word in words)
        if (LearnerLexicon.byId(word.entryId) case final entry?)
          WordCsvRow(
            termKu: entry.termKu,
            meaningTr: entry.meaningTr,
            box: word.box,
            reviews: word.reviews,
          ),
    ];
    final bytes = buildWordCsvBytes(rows);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'zankurd_kelimeler.csv',
            ),
          ],
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'my_words_csv_share');
    }
  }

  Widget _reviewCard(BuildContext context, SahneTokens t, WordListStore store) {
    return SahneSurfaceCard(
      key: const ValueKey('my-words-review-card'),
      child: TodaysReviewCard(
        repository: widget.repository,
        isKu: context.isKu,
        wordStore: store,
        refreshSignal: store,
      ),
    );
  }

  /// Serbest pratik: vadesini beklemeden tüm kelimeler ya da yalnız
  /// zorlandıkların (1. kutu). Kutular değişmez (bkz.
  /// [WordDrillScreen.practice]).
  ///
  /// Herkese açık (2026-10-25 sahip ilkesi: öğrenme ayrım gözetmeden
  /// herkese). Önce Pro'ya kilitlenmişti; kurulda Codex "herkese aç",
  /// Gemini 4 Argon "günde 1" dedi. Şef kararı: günde 1 sınırının gelir
  /// getiren yarısı (ikinci oturumda paywall) App Review yol tarifi
  /// yüzünden yapılamıyor; geriye yalnız kısıt kalıyordu.
  Widget _practiceSection(
    BuildContext context,
    SahneTokens t,
    List<SavedWord> words,
  ) {
    final weak = [
      for (final w in words)
        if (w.box <= 1) w,
    ];
    Widget row({
      required Key key,
      required String title,
      required List<SavedWord> pool,
    }) {
      return SahneListRow.icon(
        key: key,
        icon: AppIcons.play,
        role: SahneRole.learn,
        title: title,
        subtitle: '${pool.length}',
        chevron: true,
        onTap: () => _startPractice(context, pool),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x4),
      child: Column(
        key: const ValueKey('my-words-practice'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.wordsPracticeTitle),
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            context.t(K.wordsPracticeHint),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x2),
          SahneListGroup(
            children: [
              row(
                key: const ValueKey('my-words-practice-all'),
                title: context.t(K.wordsPracticeAll),
                pool: words,
              ),
              if (weak.isNotEmpty)
                row(
                  key: const ValueKey('my-words-practice-weak'),
                  title: context.t(K.wordsPracticeWeak),
                  pool: weak,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Oturum en çok [_practiceCap] kelime; her açılışta karışık.
  static const _practiceCap = 15;

  Future<void> _startPractice(
    BuildContext context,
    List<SavedWord> pool,
  ) async {
    final picked = [...pool]..shuffle(math.Random());
    await Navigator.of(context).push(
      AppRoute.to(
        WordDrillScreen(
          store: _store,
          words: picked.take(_practiceCap).toList(),
          practice: true,
        ),
      ),
    );
  }

  Widget _wordCard(
    BuildContext context,
    SahneTokens t,
    SavedWord word,
    WordListStore store,
  ) {
    final entry = LearnerLexicon.byId(word.entryId)!;
    final due = word.isDue(DateTime.now());
    final box = context.t(K.wordsBox, {'box': '${word.box}'});
    // 2026-10-28 kurul K13: satır = sözcük + anlam + ses + kaydet. Mikrofon
    // (telaffuz denemesi) satırdan kalktı: kelime ayrıntısına (balon) ve
    // çalışmaya taşındı; her satırda üç ikon sırası listeyi kalabalık
    // yapıyordu. "Kutu n/5" yazısı 5 noktalık küçük ustalık göstergesi oldu
    // (ekran okuyucu yine "Kutu n/5" der); "Hazır" rozeti yeşil "Tekrar
    // zamanı" çipi oldu.
    return SahneSurfaceCard(
      key: ValueKey('my-word-${entry.id}'),
      semanticLabel:
          '${entry.termKu}. ${entry.meaningTr}. $box.'
          '${due ? ' ${context.t(K.wordsDueBadge)}.' : ''}',
      onTap: () => showLexiconEntrySheet(context, entry),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.termKu,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    entry.meaningTr,
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Wrap(
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MasteryDots(
                        key: ValueKey('my-word-mastery-${entry.id}'),
                        box: word.box,
                      ),
                      if (due) _DueChip(label: context.t(K.wordsDueBadge)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          LexiconSpeakButton(text: entry.termKu),
          WordSaveButton(entryId: entry.id, store: store),
        ],
      ),
    );
  }
}

/// Leitner kutusunu 5 küçük noktayla gösterir: dolu nokta sayısı = kutu.
/// Renge ek olarak doluluk (şekil) söyler; sayı ekran okuyucuda kartın
/// etiketinde ("Kutu n/5") yazılıdır.
class _MasteryDots extends StatelessWidget {
  const _MasteryDots({super.key, required this.box});

  final int box;

  static const int total = 5;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          DecoratedBox(
            key: ValueKey('mastery-dot-$i-${i < box ? 'on' : 'off'}'),
            decoration: ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(
                  color: i < box ? t.learnTx : t.tx3,
                  width: 1.5,
                ),
              ),
              color: i < box ? t.learnTx : Colors.transparent,
            ),
            child: const SizedBox.square(dimension: 9),
          ),
        ],
      ],
    );
  }
}

/// Küçük nötr "Tekrar zamanı" çipi (vadesi gelmiş kelime).
///
/// Y6 (2026-10-29 tur 6): çip yeşildi; yeşil "doğru cevap" demektir, burada
/// ise "vakti geldi". Nötr yüzey + saat simgesi: durum anlamlarıyla çakışmaz.
class _DueChip extends StatelessWidget {
  const _DueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('my-word-due-chip'),
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x2,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.clock, size: 12, color: t.tx2),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: SahneType.captionStrong.copyWith(color: t.tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
