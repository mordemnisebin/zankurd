import '../models/quiz_question.dart';

class _CacheEntry {
  _CacheEntry({required this.questions, required this.expiresAt});
  final List<QuizQuestion> questions;
  final DateTime expiresAt;
}

class QuestionCache {
  QuestionCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final _store = <String, _CacheEntry>{};

  List<QuizQuestion>? get(String key) {
    final entry = _store[key];
    if (entry == null || DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.questions;
  }

  void set(String key, List<QuizQuestion> questions) {
    _store[key] = _CacheEntry(
      questions: questions,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) => _store.remove(key);
  void clear() => _store.clear();
}
