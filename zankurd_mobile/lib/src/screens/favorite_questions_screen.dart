import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
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

  Future<void> _removeFavorite(QuizQuestion question) async {
    await widget.repository.toggleFavoriteQuestion(question, false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t(K.questionRemoved))));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: context.t(K.refreshAction),
            icon: const Icon(AppIcons.arrowsRotate),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: FutureBuilder<List<QuizQuestion>>(
            future: _favoritesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                );
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
              if (questions.isEmpty) {
                // AppEmptyState LayoutBuilder ile maxHeight ister — ListView'da
                // unbounded olur; Column + Expanded kullan.
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      ScreenIdentityHeader(
                        title: context.t(K.savedShort),
                        subtitle: context.t(K.yourFavorites),
                        accent: AppTheme.gold,
                        icon: AppIcons.bookmark,
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Expanded(child: _EmptyFavorites()),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                itemCount: questions.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ScreenIdentityHeader(
                        title: context.t(K.savedShort),
                        subtitle: context.t(K.questionsReplay, {
                          'count': '${questions.length}',
                        }),
                        accent: AppTheme.gold,
                        icon: AppIcons.bookmark,
                        compact: true,
                      ),
                    );
                  }
                  if (index == 1) {
                    return _buildPlayAllButton(context, questions);
                  }
                  final question = questions[index - 2];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FavoriteQuestionTile(
                      question: question,
                      // Çevrimiçi oda maçında kaydedilen favoriler doğru
                      // cevabı taşımaz (hile önlemi); yerel yeniden
                      // puanlama imkansız — oynatma kapatılır, yalnız
                      // görüntülenebilir (2026-08-14 denetimi).
                      onPlay: question.hasHiddenAnswer
                          ? null
                          : () => _playFrom(index - 2, questions),
                      onRemove: () => _removeFavorite(question),
                    ),
                  );
                },
              );
            },
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppTheme.glowShadow(AppTheme.gold, intensity: 0.18),
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          // Altın gradyan üstünde sabit beyaz 2.40:1 veriyordu; en büyük
          // düğmenin etiketi ekrandaki en okunmaz yazıydı (2026-07-27).
          // Renk zemine göre seçilir — gradyanın açık ucu en kötü durum.
          foregroundColor: AppColors.onSolid(
            AppTheme.goldGradient.colors.first,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
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
        icon: const Icon(AppIcons.circlePlay, size: 22),
        label: Text(
          context.t(K.playSavedQuestions),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

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
    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Solda sorunun **kategori** simgesi durur, yer imi değil.
              //
              // Önce burada da altın bir yer imi kutusu vardı; sağda yer imi
              // aç/kapa düğmesi, üstte kimlik bandında yine yer imi — aynı
              // simge tek ekranda dört kez (2026-07-30 ekran turu, 71).
              // Zaten kaydedilmiş soruların listesinde "kaydedilmiş" bilgisi
              // yeni bir şey söylemiyor; kategori söylüyor.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: CategoryVisuals.gradientColors(question.category),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CategoryVisuals.icon(question.category),
                  color: AppColors.onSolid(
                    CategoryVisuals.color(question.category),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TinyBadge(
                          label: CategoryNames.localized(
                            question.category,
                            context.isKu,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TinyBadge(
                          label: question.typeLabelLocalized(context.isKu),
                        ),
                      ],
                    ),
                    if (question.hasHiddenAnswer) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.t(K.favoriteAnswerHiddenHint),
                        key: const ValueKey('favorite-answer-hidden-hint'),
                        style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      question.promptText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRemove,
                tooltip: context.t(K.removeAction),
                icon: Icon(
                  AppIcons.bookmark,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
              if (onPlay != null)
                const Icon(
                  AppIcons.play,
                  color: AppTheme.primaryGradientStart,
                )
              else
                Icon(AppIcons.eye, color: AppTheme.textMutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textSubColor(context),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
