import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/services/content_quality_policy.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  group('Soru yapısal kalite politikası', () {
    const policy = QuestionContentPolicy();

    test('görselli soru görsel yoksa oynanamaz', () {
      const question = QuizQuestion(
        id: 'visual-missing',
        category: 'Rêziman',
        prompt: 'Wateya peyvê çi ye?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'Ravekirin',
        type: QuestionType.visual,
      );

      expect(policy.validate(question), contains('visual_image_missing'));
      expect(policy.isPlayable(question), isFalse);
    });

    test('geçerli soru oynanabilir', () {
      const question = QuizQuestion(
        id: 'valid',
        category: 'Ziman',
        prompt: 'Pirtûk çi ye?',
        answers: ['Kitap', 'Masa', 'Su', 'Ev'],
        correctAnswer: 'Kitap',
        explanation: 'Pirtûk kitap demektir.',
      );

      expect(policy.validate(question), isEmpty);
      expect(policy.isPlayable(question), isTrue);
    });
  });

  group('QuestionMetadata geriye uyumluluk', () {
    test('eski JSON (metadata alanı yok) güvenli varsayılana düşer', () {
      final meta = QuestionMetadata.fromJson(null);
      expect(meta.isEmpty, isTrue);
      expect(meta.reviewStatus, isNull);
      expect(meta.reportCount, 0);
      expect(meta.qualityVersion, 0);
    });

    test('kısmi JSON: eksik alanlar varsayılan, var olanlar okunur', () {
      final meta = QuestionMetadata.fromJson({
        'reviewStatus': 'approved',
        'sourceTitle': 'Ferhenga Kurdî',
        'reportCount': 3,
      });
      expect(meta.reviewStatus, ReviewStatus.approved);
      expect(meta.sourceTitle, 'Ferhenga Kurdî');
      expect(meta.reportCount, 3);
      expect(meta.dialect, isNull);
    });

    test('geçersiz enum değeri güvenli biçimde null olur', () {
      final meta = QuestionMetadata.fromJson({'reviewStatus': 'wibbly'});
      expect(meta.reviewStatus, isNull);
    });

    test('bozuk tipler güvenli varsayılana düşer', () {
      final meta = QuestionMetadata.fromJson({
        'reportCount': 'çok',
        'qualityVersion': null,
        'dialect': '   ',
      });
      expect(meta.reportCount, 0);
      expect(meta.qualityVersion, 0);
      expect(meta.dialect, isNull);
    });

    test('round-trip: toJson → fromJson korunur', () {
      const original = QuestionMetadata(
        reviewStatus: ReviewStatus.needsReview,
        dialect: 'Behdînî',
        sourceTitle: 'Kaynak',
        sourceReference: 'sf. 12',
        reviewedBy: 'editor-1',
        reviewedAt: '2026-07-12',
        lastContentCheckAt: '2026-07-12',
        qualityVersion: 2,
        reportCount: 4,
      );
      final restored = QuestionMetadata.fromJson(original.toJson());
      expect(restored.reviewStatus, ReviewStatus.needsReview);
      expect(restored.dialect, 'Behdînî');
      expect(restored.sourceReference, 'sf. 12');
      expect(restored.qualityVersion, 2);
      expect(restored.reportCount, 4);
    });
  });

  group('ContentQualityPolicy filtre', () {
    const policy = ContentQualityPolicy();

    test('metadata yok (legacy) → uygun (görünmez olmaz)', () {
      expect(policy.isEligible(null), isTrue);
    });

    test('rejected → elenmiş', () {
      expect(
        policy.isEligible(
          const QuestionMetadata(reviewStatus: ReviewStatus.rejected),
        ),
        isFalse,
      );
    });

    test('draft/needsReview/approved → uygun', () {
      for (final s in [
        ReviewStatus.draft,
        ReviewStatus.needsReview,
        ReviewStatus.approved,
      ]) {
        expect(policy.isEligible(QuestionMetadata(reviewStatus: s)), isTrue);
      }
    });

    test('katı mod (requireApproved) yalnız approved kabul eder', () {
      const strict = ContentQualityPolicy(requireApproved: true);
      expect(policy.isEligible(null), isTrue); // varsayılan gevşek
      expect(strict.isEligible(null), isFalse); // katı: doğrulanmamış eler
      expect(
        strict.isEligible(
          const QuestionMetadata(reviewStatus: ReviewStatus.approved),
        ),
        isTrue,
      );
    });
  });

  group('Rapor eşiği', () {
    const policy = ContentQualityPolicy(reportThreshold: 5);

    test('eşik altında needsReview üretmez', () {
      var meta = const QuestionMetadata();
      for (var i = 0; i < 4; i++) {
        meta = policy.applyReport(meta);
      }
      expect(meta.reportCount, 4);
      expect(meta.reviewStatus, isNull);
      expect(policy.isOverReported(meta), isFalse);
    });

    test('eşiğe ulaşınca needsReview işaretler', () {
      var meta = const QuestionMetadata();
      for (var i = 0; i < 5; i++) {
        meta = policy.applyReport(meta);
      }
      expect(meta.reportCount, 5);
      expect(meta.reviewStatus, ReviewStatus.needsReview);
      expect(policy.isOverReported(meta), isTrue);
    });

    test('rejected soru rapora rağmen needsReview olmaz', () {
      var meta = const QuestionMetadata(reviewStatus: ReviewStatus.rejected);
      for (var i = 0; i < 6; i++) {
        meta = policy.applyReport(meta);
      }
      expect(meta.reviewStatus, ReviewStatus.rejected);
    });
  });
}
