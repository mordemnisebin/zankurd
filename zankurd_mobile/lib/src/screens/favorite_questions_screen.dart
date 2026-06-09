import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_question.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
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
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FutureBuilder<List<QuizQuestion>>(
            future: _favoritesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }

              final questions = snapshot.data ?? const <QuizQuestion>[];
              if (questions.isEmpty) {
                return const _EmptyFavorites();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _FavoriteQuestionTile(
                    question: questions[index],
                    onPlay: () => _playFrom(index, questions),
                    onRemove: () => _removeFavorite(questions[index]),
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
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          repository: widget.repository,
          room: room,
          questions: selected,
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
                child: const Icon(Icons.bookmark, color: Colors.white),
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
                        _TinyBadge(label: question.typeLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
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
                icon: const Icon(
                  Icons.bookmark_remove_outlined,
                  color: AppTheme.textMuted,
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: AppTheme.accent),
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
        color: AppTheme.surfaceHi,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSub,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.s(
                  'Hîn pirsên tomarkirî tune.',
                  'Henüz kaydedilmiş soru yok.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.s(
                  'Di dema pêşbirkê de bişkoka nîşankirinê bitikîne û pirsan li vir zêde bike.',
                  'Quiz sırasında yer imi simgesine basarak soruları buraya ekleyebilirsin.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
