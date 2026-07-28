import 'package:flutter/material.dart';

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
                      onPlay: () => _playFrom(index - 2, questions),
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
      ...questions.where((question) => question.id != questions[index].id),
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
                questionCount: questions.length,
              );
          Navigator.of(context).push(
            AppRoute.to(
              QuizScreen(
                repository: widget.repository,
                room: room,
                questions: questions,
              ),
            ),
          );
        },
        icon: const Icon(AppIcons.circlePlay, size: 22),
        // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
        label: ExcludeSemantics(
          child: Text(
            context.t(K.playSavedQuestions),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
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
  final VoidCallback onPlay;
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(AppIcons.bookmark, color: Colors.white),
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
              const Icon(AppIcons.play, color: AppTheme.primaryGradientStart),
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
