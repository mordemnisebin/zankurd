import '../config/category_visibility.dart';
import '../models/quiz_question.dart';
import 'content_quality_policy.dart';

/// Son kullanıcıya gösterilmeden önce sorunun yapısal oynanabilirliğini
/// doğrular. Editör dili ve kategori anlamı ayrı bir editör kontrolüdür.
class QuestionContentPolicy {
  const QuestionContentPolicy();

  static const _qualityPolicy = ContentQualityPolicy();

  bool isPlayable(QuizQuestion question) {
    // Gizli kategori (ör. içeriği hazır olmayan Sînema) hiçbir akışta
    // oynanabilir değildir; quiz seçimi, günlük soru ve offline banka
    // sızıntıları bu tek noktadan kapanır.
    if (!isCategoryVisible(question.category)) return false;
    if (!_qualityPolicy.isEligible(question.metadata)) return false;
    return validate(question).isEmpty;
  }

  /// Çevrimiçi odada doğru cevap, cevap gönderilene kadar sunucuda gizlidir.
  /// Normal [isPlayable] kuralını gevşetmeden yalnız bu taşıma biçimini
  /// doğrular; boş olmayan ama şıklarda bulunmayan cevap yine reddedilir.
  bool isPlayableWithHiddenAnswer(QuizQuestion question) {
    if (!isCategoryVisible(question.category)) return false;
    if (!_qualityPolicy.isEligible(question.metadata)) return false;
    return validate(question, allowHiddenAnswer: true).isEmpty;
  }

  List<String> validate(
    QuizQuestion question, {
    bool allowHiddenAnswer = false,
  }) {
    final issues = <String>[];
    if (question.prompt.trim().isEmpty) issues.add('empty_prompt');
    if (question.category.trim().isEmpty) issues.add('empty_category');
    if (question.type != QuestionType.fillInBlank &&
        question.answers.length < 2) {
      issues.add('too_few_answers');
    }
    if (question.type == QuestionType.fillInBlank &&
        (question.answers.length != 1 ||
            question.answers.single.trim().isEmpty ||
            question.correctAnswer.trim().isEmpty)) {
      issues.add('fill_in_blank_requires_one_canonical_answer');
    }
    final answerIsHidden =
        allowHiddenAnswer && question.correctAnswer.trim().isEmpty;

    // Çevrimiçi oda protokolü yalnız A-D/TIMEOUT anahtarı taşır. Serbest
    // metni veya acceptedAnswers listesini sunucuya güvenle iletemediği için
    // boşluk doldurma, protokol genişletilene kadar gizli-cevap akışına
    // alınmaz.
    if (question.type == QuestionType.fillInBlank && allowHiddenAnswer) {
      issues.add('hidden_answer_unsupported');
      return List.unmodifiable(issues);
    }

    // Cümle kurma sorusunda `answers` şık listesi değil, kelime havuzudur;
    // `correctAnswer` ise bu kelimelerin doğru sırayla birleştirilmiş hâli.
    // Genel "doğru cevap şıklar arasında olmalı" kuralı burada geçerli
    // değildir; uygulanırsa her cümle kurma sorusu oynanamaz sayılır.
    if (question.type == QuestionType.wordOrdering) {
      // Oda RPC'si yalnız A-D seçenek anahtarı kabul eder. Cümle kurmada
      // seçilen değer bir seçenek değil, birleştirilmiş cümledir; sunucu
      // protokolü genişletilmeden doğru cevap güvenle gizlenemez.
      if (answerIsHidden) {
        issues.add('hidden_answer_unsupported');
        return List.unmodifiable(issues);
      }
      final tokens = question.correctAnswer
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();
      final pool = List<String>.of(question.answers)..sort();
      final expected = List<String>.of(tokens)..sort();
      var poolMatches = pool.length == expected.length;
      for (var index = 0; poolMatches && index < pool.length; index++) {
        poolMatches = pool[index] == expected[index];
      }
      if (tokens.length < 2) {
        issues.add('word_ordering_requires_two_words');
      } else if (!poolMatches) {
        // Havuz ile doğru cümlenin kelimeleri birebir örtüşmezse soru
        // çözülemez: ya artık kelime kalır ya eksik kelime istenir.
        issues.add('word_ordering_pool_mismatch');
      }
      return List.unmodifiable(issues);
    }

    if (!answerIsHidden && !question.answers.contains(question.correctAnswer)) {
      issues.add('correct_answer_missing');
    }
    if (question.type == QuestionType.multipleChoice &&
        question.answers.length < 4) {
      issues.add('multiple_choice_requires_four_answers');
    }
    if (question.type == QuestionType.visual && !question.hasImage) {
      issues.add('visual_image_missing');
    }
    return List.unmodifiable(issues);
  }
}
