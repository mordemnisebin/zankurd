import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_authoring/src/artifacts.dart';
import '../../tool/content_authoring/src/csv_source.dart';
import '../../tool/content_authoring/src/promotion.dart';

void main() {
  PromotionCandidate candidate({
    String id = 'q1',
    String prompt = 'Kîjan bajar paytexta Amedê ye?',
    List<String> options = const ['Amed', 'Wan', 'Diyarbekir', 'Mûş'],
    String correct = 'A',
    String explanation =
        'Amed navê kevn ê Diyarbekirê ye û di dîroka herêmê de girîng e.',
    String category = 'Cografya',
    int? difficulty = 2,
    String verified = 'Doğrulandı',
    String sourceUrl = 'https://example.org/source',
    String status = 'REVIEWED',
    String issueType = '',
    double? confidence = 0.95,
    String reviewNotes = '',
  }) => PromotionCandidate(
    row: 2,
    id: id,
    locale: 'ku-kmr',
    category: category,
    prompt: prompt,
    options: options,
    correctOption: correct,
    explanation: explanation,
    difficulty: difficulty,
    sourceVerified: verified,
    sourceUrl: sourceUrl,
    publicationStatus: status,
    issueType: issueType,
    confidence: confidence,
    reviewNotes: reviewNotes,
  );

  test('verified, sourced, non-template candidate is promoted', () {
    final result = promoteCandidates(
      candidates: [candidate()],
      active: const [],
      targetCount: 15000,
    );

    expect(result.accepted, hasLength(1));
    expect(result.rejectedByReason, isEmpty);
    expect(result.remainingToTarget, 14999);
  });

  test('candidate without difficulty or verified source is quarantined', () {
    final result = promoteCandidates(
      candidates: [
        candidate(difficulty: null, verified: 'Kısmen', sourceUrl: ''),
      ],
      active: const [],
      targetCount: 15000,
    );

    expect(result.accepted, isEmpty);
    expect(
      result.rejectedByReason.keys,
      containsAll(<String>{
        'missing_difficulty',
        'unverified_source',
        'missing_source_url',
      }),
    );
  });

  test('canonical duplicate against active bank is rejected', () {
    final result = promoteCandidates(
      candidates: [candidate()],
      active: [candidate(id: 'active-1')],
      targetCount: 15000,
    );

    expect(result.accepted, isEmpty);
    expect(result.rejectedByReason['canonical_duplicate'], 1);
  });

  test(
    'repeated explanation, duplicate options, and language mismatch are rejected',
    () {
      final result = promoteCandidates(
        candidates: [
          candidate(
            id: 'bad-1',
            options: const ['Amed', 'Amed', 'Wan', 'Mûş'],
            explanation: 'Amed',
            prompt: 'Aşağıdakilerden hangisidir?',
          ),
        ],
        active: const [],
        targetCount: 15000,
      );

      expect(result.accepted, isEmpty);
      expect(
        result.rejectedByReason.keys,
        containsAll(<String>{
          'duplicate_option',
          'explanation_repeats_answer',
          'answer_language_mismatch',
        }),
      );
    },
  );

  test(
    'template density is capped and reported by category and difficulty',
    () {
      final first = candidate(
        id: 'q1',
        prompt: 'Di destpêkê de têgeha "av" çi ye?',
      );
      final second = candidate(
        id: 'q2',
        prompt: 'Di destpêkê de têgeha "avê" çi ye?',
        category: 'Ziman',
      );
      final result = promoteCandidates(
        candidates: [first, second],
        active: const [],
        targetCount: 15000,
        maxTemplatePerShape: 1,
      );

      expect(result.accepted, hasLength(1));
      expect(result.rejectedByReason['template_density'], 1);
      expect(result.categoryDistribution, {'Cografya': 1});
      expect(result.difficultyDistribution, {'2': 1});
    },
  );

  test('writer does not create expanded bank when no candidate passes', () {
    final result = promoteCandidates(
      candidates: [candidate(difficulty: null)],
      active: const [],
      targetCount: 15000,
    );

    expect(result.shouldWriteExpandedBank, isFalse);
    expect(result.manifest['expanded_questions'], isFalse);
    expect(result.manifest['accepted_count'], 0);
  });

  test(
    'candidate CSV loader preserves quoted Kurmanci fields and missing difficulty',
    () {
      final file = File('${Directory.systemTemp.path}/promotion-candidate.csv')
        ..writeAsStringSync(
          'review_id,category_key,language_code,corrected_prompt,corrected_option_a,corrected_option_b,corrected_option_c,corrected_option_d,corrected_correct_option,corrected_explanation,confidence_0_to_1,source_verified,better_source_url,issue_type,publication_status\n'
          'wave_1,Ziman,ku-kmr,"Pirsê, bi navê",A,B,C,D,A,"Ravekirin, bi agahiyê",0.95,Doğrulandı,https://example.org,,REVIEWED\n',
        );

      final candidates = loadPromotionCandidates(file);

      expect(candidates, hasLength(1));
      expect(candidates.single.prompt, 'Pirsê, bi navê');
      expect(candidates.single.explanation, 'Ravekirin, bi agahiyê');
      expect(candidates.single.difficulty, isNull);
      expect(candidates.single.sourceUrl, 'https://example.org');
      file.deleteSync();
    },
  );

  test('low confidence and unresolved review notes remain quarantined', () {
    final result = promoteCandidates(
      candidates: [
        candidate(
          id: 'weak-evidence',
          confidence: 0.82,
          reviewNotes: 'Şablon tekrarı için yeniden incelenmeli.',
        ),
        candidate(id: 'missing-evidence', confidence: null),
      ],
      active: const [],
      targetCount: 15000,
    );

    expect(result.accepted, isEmpty);
    expect(
      result.rejectedByReason.keys,
      containsAll(<String>{
        'low_confidence',
        'editorial_issue',
        'missing_confidence',
      }),
    );
  });

  test('single-quoted prompt templates are capped', () {
    final result = promoteCandidates(
      candidates: [
        candidate(id: 'single-1', prompt: "Têgeha 'av' çi ye di Kurmancî de?"),
        candidate(id: 'single-2', prompt: "Têgeha 'roj' çi ye di Kurmancî de?"),
      ],
      active: const [],
      targetCount: 15000,
      maxTemplatePerShape: 1,
    );

    expect(result.accepted, hasLength(1));
    expect(result.rejectedByReason['template_density'], 1);
  });

  test('artifact writer emits manifest and no fake bank for empty result', () {
    final result = promoteCandidates(
      candidates: [candidate(id: 'not-approved', status: 'QUARANTINED')],
      active: const [],
      targetCount: 15000,
    );
    final directory = Directory.systemTemp.createTempSync('content-artifacts-');
    addTearDown(() => directory.deleteSync(recursive: true));

    writePromotionArtifacts(
      result,
      directory,
      sourcePath: 'supabase/quarantine.csv',
    );

    expect(
      File('${directory.path}/promotion_manifest.json').existsSync(),
      isTrue,
    );
    expect(File('${directory.path}/promotion_report.md').existsSync(), isTrue);
    expect(File('${directory.path}/rejected_rows.csv').existsSync(), isTrue);
    expect(
      File('${directory.path}/expanded_questions.json').existsSync(),
      isFalse,
    );
  });
}
