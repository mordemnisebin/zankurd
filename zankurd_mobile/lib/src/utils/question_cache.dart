import '../models/quiz_question.dart';

/// Soru metni / banka içeriği değişince artır.
/// Eski oturumlardaki bellek önbelleği `vN::` anahtarıyla otomatik düşer.
const int kQuestionContentVersion = 2;

class _CacheEntry {
  _CacheEntry({required this.questions, required this.expiresAt});
  final List<QuizQuestion> questions;
  final DateTime expiresAt;
}

class QuestionCache {
  QuestionCache({
    this.ttl = const Duration(minutes: 5),
    this.contentVersion = kQuestionContentVersion,
  });

  final Duration ttl;

  /// Anahtar önekine gömülür; sürüm artınca eski girdiler erişilemez.
  final int contentVersion;

  final _store = <String, _CacheEntry>{};

  String _versioned(String key) => 'v$contentVersion::$key';

  List<QuizQuestion>? get(String key) {
    final entry = _store[_versioned(key)];
    if (entry == null || DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(_versioned(key));
      return null;
    }
    return entry.questions;
  }

  void set(String key, List<QuizQuestion> questions) {
    // Değiştirilemez kopya sakla: çağıranın kaynak listeyi sonradan
    // değiştirmesi ya da get() çıktısını mutasyona uğratması önbelleği bozmasın.
    _store[_versioned(key)] = _CacheEntry(
      questions: List<QuizQuestion>.unmodifiable(questions),
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) => _store.remove(_versioned(key));

  void clear() => _store.clear();

  /// Eski sürüm artıkları ve süresi dolmuş girdileri temizler.
  void dropStale({int? keepVersion}) {
    final keep = keepVersion ?? contentVersion;
    final now = DateTime.now();
    _store.removeWhere((key, entry) {
      if (now.isAfter(entry.expiresAt)) return true;
      return !key.startsWith('v$keep::');
    });
  }
}
