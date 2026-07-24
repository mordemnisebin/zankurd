import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quiz_question.dart';
import 'curated_question_bank.dart';
import 'question_bank_loader_stub.dart'
    if (dart.library.io) 'question_bank_loader_io.dart';

/// Soru bankasını asenkron olarak yükler.
///
/// Eski `offline_question_bank.dart` ve `editorial_question_bank.dart`
/// dosyaları doğrudan Dart const listesiydi (toplam ~1.5 MB kod segmenti).
/// Bu loader onların yerine asset JSON dosyalarını runtime'da okur;
/// bu sayede APK/IPA kodu küçülür, soru güncelleme kolaylaşır.
///
/// Kullanım:
/// ```dart
/// await QuestionBankLoader.instance.load();
/// final questions = QuestionBankLoader.instance.allQuestions;
/// ```
class QuestionBankLoader {
  QuestionBankLoader._();

  static final QuestionBankLoader instance = QuestionBankLoader._();

  List<QuizQuestion> _questions = const [];
  bool _loaded = false;

  /// Tüm sorular (curated + editorial + offline).
  List<QuizQuestion> get allQuestions {
    _ensureLoadedInTest();
    return _questions;
  }

  bool get isLoaded {
    _ensureLoadedInTest();
    return _loaded;
  }

  void _ensureLoadedInTest() {
    if (_loaded) return;
    final testQuestions = loadSyncIfInTest();
    if (testQuestions != null && testQuestions.isNotEmpty) {
      _questions = List.unmodifiable(testQuestions);
      _loaded = true;
    }
  }

  /// JSON asset'leri okur ve parse eder. Uygulama başlangıcında bir kez
  /// çağrılmalıdır (ör. `main()` içinde ya da `AppShell.initState()`).
  Future<void> load() async {
    if (_loaded) return;

    final offline = await _loadJson('assets/data/offline_questions.json');
    final editorial = await _loadJson('assets/data/editorial_questions.json');

    _questions = [
      ...curatedQuestionBank,
      ...editorial,
      ...offline,
    ];
    _loaded = true;
  }

  /// Test ortamı için soruları manuel olarak yükleme imkanı tanır.
  void setQuestionsForTest(List<QuizQuestion> questions) {
    _questions = List.unmodifiable(questions);
    _loaded = true;
  }

  /// Tek bir JSON asset dosyasını yükler ve `List<QuizQuestion>` döndürür.
  static Future<List<QuizQuestion>> _loadJson(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      // Asset bulunamazsa veya parse hatası olursa boş liste döndür
      // (uygulama curated + diğer banka ile devam eder).
      return const [];
    }
  }

  /// Belirli bir `id`'ye sahip soruyu bulur (MistakeStore için).
  QuizQuestion? findById(String id) {
    _ensureLoadedInTest();
    for (final q in _questions) {
      if (q.id == id) return q;
    }
    return null;
  }
}
