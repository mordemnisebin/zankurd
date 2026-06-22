import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import 'quiz_screen.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.s('Pirs hate rakirin.', 'Soru kayıtlardan çıkarıldı.'),
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.s('Tomarkirî', 'Kaydedilenler')),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: Icon(Icons.refresh_rounded),
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
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }

              if (snapshot.hasError) {
                return AppErrorState(
                  title: context.s(
                    'Pirsên tomarkirî nehatin barkirin',
                    'Kaydedilen sorular yüklenemedi',
                  ),
                  message: context.s(
                    'Girêdanê kontrol bike û dîsa bicerib.',
                    'Bağlantıyı kontrol edip tekrar dene.',
                  ),
                  retryLabel: context.s('Dîsa Bicerib', 'Tekrar Dene'),
                  onRetry: _reload,
                );
              }

              final questions = snapshot.data ?? const <QuizQuestion>[];
              if (questions.isEmpty) {
                return const _EmptyFavorites();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                itemCount: questions.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildPlayAllButton(context, questions);
                  }
                  final question = questions[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FavoriteQuestionTile(
                      question: question,
                      onPlay: () => _playFrom(index - 1, questions),
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
          name: context.s('Pirsên Tomarkirî', 'Kaydedilen Sorular'),
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

  Widget _buildPlayAllButton(BuildContext context, List<QuizQuestion> questions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        onPressed: () {
          final room = widget.repository
              .createRoom(category: 'Tomarkirî')
              .copyWith(
                name: context.s('Pirsên Tomarkirî', 'Kaydedilen Sorular'),
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
        icon: const Icon(Icons.play_circle_fill, size: 22),
        label: Text(
          context.s('Pirsên Tomarkirî Bilîze', 'Kaydedilen Soruları Oyna'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
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
                child: Icon(Icons.bookmark, color: Colors.white),
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
                tooltip: context.s('Rake', 'Kaldır'),
                icon: Icon(
                  Icons.bookmark_remove_outlined,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: AppTheme.accent),
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
      icon: Icons.bookmark_border,
      title: context.s(
        'Hîn pirsên tomarkirî tune.',
        'Henüz kaydedilmiş soru yok.',
      ),
      message: context.s(
        'Di dema pêşbirkê de bişkoka nîşankirinê bitikîne û pirsan li vir zêde bike.',
        'Quiz sırasında yer imi simgesine basarak soruları buraya ekleyebilirsin.',
      ),
    );
  }
}
