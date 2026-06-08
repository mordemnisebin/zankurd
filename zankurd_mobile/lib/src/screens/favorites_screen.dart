import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'quiz_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<QuizQuestion>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = widget.repository.loadFavoriteQuestions();
  }

  void _refresh() {
    setState(() {
      _favoritesFuture = widget.repository.loadFavoriteQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilen Sorular'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<QuizQuestion>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: AppPanel(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Kayıtlı sorular yükleniyor...')),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _FavoritesMessage(
                icon: Icons.error_outline,
                title: 'Sorular yüklenemedi',
                message: 'Bağlantıyı kontrol edip tekrar dene.',
                onRetry: _refresh,
              );
            }

            final questions = snapshot.data ?? const [];
            if (questions.isEmpty) {
              return _FavoritesMessage(
                icon: Icons.bookmark_border,
                title: 'Henüz kayıtlı soru yok',
                message: 'Sınav sırasında soruların üstündeki kitapçık simgesine dokunarak soru kaydedebilirsin.',
                onRetry: _refresh,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                const _FavoritesHero(),
                const SizedBox(height: 16),
                for (final question in questions) ...[
                  _FavoriteQuestionCard(
                    question: question,
                    repository: widget.repository,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.green, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
              ),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar dene'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoritesHero extends StatelessWidget {
  const _FavoritesHero();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: const Color(0xFF4059AD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bookmark, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'Kaydedilen Sorular',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28),
          ),
          const SizedBox(height: 8),
          const Text(
            'Beğendiğin soruları tekrar çöz, bilgini pekiştir.',
            style: TextStyle(color: Color(0xFFD5DDF0), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _FavoriteQuestionCard extends StatelessWidget {
  const _FavoriteQuestionCard({
    required this.question,
    required this.repository,
  });

  final QuizQuestion question;
  final ZanKurdRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyTag(label: question.category),
              const SizedBox(width: 8),
              _TinyTag(label: question.typeLabel),
              const Spacer(),
              _TinyTag(label: '${question.difficulty}/5'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.prompt,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.2),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final room = repository.createRoom(category: question.category)
                    .copyWith(questionCount: 1, name: 'Özel Çalışma');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      repository: repository,
                      room: room,
                      questions: [question],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Soruyu Çöz'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
