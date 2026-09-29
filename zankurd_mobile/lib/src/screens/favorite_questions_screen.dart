import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../services/favorite_mutation_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'learning_screen.dart' show BarIconAction;
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class FavoriteQuestionsScreen extends StatefulWidget {
  const FavoriteQuestionsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<FavoriteQuestionsScreen> createState() =>
      _FavoriteQuestionsScreenState();
}

class _FavoriteQuestionsScreenState extends State<FavoriteQuestionsScreen> {
  late Future<List<QuizQuestion>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = widget.repository.loadFavoriteQuestions();
  }

  void _reload() {
    setState(() {
      _favoritesFuture = widget.repository.loadFavoriteQuestions();
    });
  }

  /// Favoriden çıkarır.
  ///
  /// Çağrı bir `try` içinde: `toggleFavoriteQuestion` sunucu tarafında
  /// FIRLATIR (silme sorgusunun etrafında hiçbir yakalama yok). Burada
  /// yakalama olmadığı için hata çağıran zincire düşüyor, ekranda hiçbir iz
  /// bırakmıyordu — üstelik "çıkarıldı" mesajı `await`ten SONRA geldiği için
  /// başarısızlıkta hiç görünmüyordu bile: kullanıcı dokunuyor, hiçbir şey
  /// olmuyor, soru listede kalıyor ve niçin olduğunu söyleyen tek bir kelime
  /// yok (2026-08-17).
  ///
  /// Aynı işi yapan `quiz_screen._toggleFavorite` bunu zaten doğru yapıyordu;
  /// iki ekran artık aynı dayanıklılık servisini kullanır.
  Future<void> _removeFavorite(QuizQuestion question) async {
    try {
      await FavoriteMutationService.setFavorite(
        repository: widget.repository,
        question: question,
        favorite: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.questionRemoveFailed))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t(K.questionRemoved))));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: B iskeleti. "Kaydedilenler" ve sayı çubukta; eski
    // altın kimlik bandı kalktı. Yenile, çubuğun sağında 44'lük plaka
    // (dokunma alanı 48). Tek birincil eylem "Kaydedilen Soruları Oyna".
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(context.t(K.savedShort)),
        subtitle: FutureBuilder<List<QuizQuestion>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Text(
              count > 0
                  ? context.t(K.questionsReplay, {'count': '$count'})
                  : context.t(K.yourFavorites),
            );
          },
        ),
        actions: [
          BarIconAction(
            icon: AppIcons.arrowsRotate,
            label: context.t(K.refreshAction),
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<QuizQuestion>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: t.learnTx));
            }

            if (snapshot.hasError) {
              return AppErrorState(
                title: context.t(K.favoritesLoadFailed),
                message: context.t(K.checkConnection),
                retryLabel: context.t(K.retry),
                onRetry: _reload,
              );
            }

            final questions = snapshot.data ?? const <QuizQuestion>[];
            if (questions.isEmpty) return const _EmptyFavorites();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x2,
                SahneSpace.page,
                SahneSpace.x6,
              ),
              itemCount: questions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildPlayAllButton(context, questions);
                }
                final question = questions[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                  child: _FavoriteQuestionTile(
                    question: question,
                    // Çevrimiçi oda maçında kaydedilen favoriler doğru
                    // cevabı taşımaz (hile önlemi); yerel yeniden puanlama
                    // imkansız — oynatma kapatılır, yalnız görüntülenebilir
                    // (2026-08-14 denetimi).
                    onPlay: question.hasHiddenAnswer
                        ? null
                        : () => _playFrom(index - 1, questions),
                    onRemove: () => _removeFavorite(question),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _playFrom(int index, List<QuizQuestion> questions) {
    final selected = [
      questions[index],
      // Cevabı sunucuda saklı (hasHiddenAnswer) sorular yerel olarak
      // puanlanamaz; destede ikinci sorudan sonra çıksalar bile turu
      // bozardı (2026-08-14 denetimi).
      ...questions.where(
        (question) =>
            question.id != questions[index].id && !question.hasHiddenAnswer,
      ),
    ];
    final room = widget.repository
        .createRoom(category: questions[index].category)
        .copyWith(
          name: context.t(K.savedQuestions),
          questionCount: selected.length,
        );

    Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: room,
          questions: selected,
        ),
      ),
    );
  }

  Widget _buildPlayAllButton(
    BuildContext context,
    List<QuizQuestion> questions,
  ) {
    // Cevabı sunucuda saklı sorular yerel olarak puanlanamaz; "Tümünü
    // Oyna" yalnız yeniden oynatılabilir sorularla kurulur. Hiçbiri
    // oynatılabilir değilse düğme hiç çizilmez (2026-08-14 denetimi).
    final playable = questions
        .where((question) => !question.hasHiddenAnswer)
        .toList();
    if (playable.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x4),
      child: SahneButton.primary(
        icon: AppIcons.circlePlay,
        arrow: false,
        label: context.t(K.playSavedQuestions),
        expand: true,
        onPressed: () {
          final room = widget.repository
              .createRoom(category: 'Tomarkirî')
              .copyWith(
                name: context.t(K.savedQuestions),
                questionCount: playable.length,
              );
          Navigator.of(context).push(
            AppRoute.to(
              QuizScreen(
                repository: widget.repository,
                room: room,
                questions: playable,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kayıtlı soru: yüzey kartı — solda sorunun KATEGORİ ikonu (öğrenme
/// tonlu karo), ortada kategori · soru tipi, (varsa) "cevap gizli" ipucu ve
/// soru; sağda "Kaldır" (48) ve oynat / yalnız görüntüle ikonu.
///
/// Solda yer imi değil kategori durur: önce burada da bir yer imi kutusu
/// vardı; sağda yer imi düğmesi, üstte kimlik bandında yine yer imi — aynı
/// simge tek ekranda dört kez (2026-07-30 ekran turu, 71).
class _FavoriteQuestionTile extends StatelessWidget {
  const _FavoriteQuestionTile({
    required this.question,
    required this.onPlay,
    required this.onRemove,
  });

  final QuizQuestion question;
  // null: cevabı sunucuda saklı (question.hasHiddenAnswer) — yeniden
  // oynatılamaz, yalnız görüntülenir.
  final VoidCallback? onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final large = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return SahneSurfaceCard(
      onTap: onPlay,
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x3,
        SahneSpace.x3,
        SahneSpace.x1,
        SahneSpace.x3,
      ),
      child: Row(
        children: [
          // Büyük yazı ölçeğinde (≥ 1.5) kategori karosu çizilmez: meta
          // satırı dar sütunda harf harf bölünüyordu ("Paradîgm / a").
          if (!large) ...[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: t.learnTint,
                shape: SahneShape.m,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  CategoryVisuals.icon(question.category),
                  size: 24,
                  color: t.learnTx,
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: SahneSpace.x1,
                  runSpacing: 0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      CategoryNames.localized(question.category, context.isKu),
                      style: SahneType.captionStrong.copyWith(color: t.learnTx),
                    ),
                    Text(
                      '·',
                      style: SahneType.captionStrong.copyWith(color: t.tx3),
                    ),
                    Text(
                      question.typeLabelLocalized(context.isKu),
                      style: SahneType.captionStrong.copyWith(color: t.tx3),
                    ),
                  ],
                ),
                if (question.hasHiddenAnswer)
                  Text(
                    context.t(K.favoriteAnswerHiddenHint),
                    key: const ValueKey('favorite-answer-hidden-hint'),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                const SizedBox(height: SahneSpace.x1),
                Text(
                  question.promptText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: context.t(K.removeAction),
            icon: Icon(AppIcons.bookmark, color: t.tx2, size: 22),
          ),
          ExcludeSemantics(
            child: Icon(
              onPlay != null ? AppIcons.play : AppIcons.eye,
              color: onPlay != null ? t.learnTx : t.tx3,
              size: 20,
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
        ],
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.bookmark,
      title: context.t(K.noSavedQuestions),
      message: context.t(K.noSavedQuestionsHint),
    );
  }
}
