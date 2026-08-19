import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/discovery.dart';
import '../../tool/question_quality/src/checks.dart';
import '../../tool/question_quality/src/manifest.dart';
import '../../tool/question_quality/src/models.dart';
import '../../tool/question_quality/src/normalization.dart';
import '../../tool/question_quality/src/source_readers.dart';

void main() {
  test('gerçek depodaki bütün soru kaynakları manifestte sınıflandırılır', () {
    final manifest = SourceManifest.fromJsonString(
      File('tool/question_quality/source_manifest.json').readAsStringSync(),
    );
    final unknown = discoverPotentialQuestionSources(
      Directory.current,
    ).where((candidate) => manifest.resolve(candidate.path).isUnknown);

    expect(unknown.map((candidate) => candidate.path), isEmpty);
  });

  group('release gate source model (gerçek manifest)', () {
    final manifest = SourceManifest.fromJsonString(
      File('tool/question_quality/source_manifest.json').readAsStringSync(),
    );

    test('gate sources have live expectedRecordCount and no parse errors', () {
      final failures = <String>[];
      for (final source in manifest.sources) {
        if (!source.gateIncluded ||
            source.expectedRecordCount == null ||
            source.path == null) {
          continue;
        }
        final file = File(source.path!);
        expect(file.existsSync(), isTrue, reason: '${source.id} dosyası yok');
        final result = readSource(
          source,
          file,
          repositoryRelativePath: source.path!,
        );
        if (result.stats.parseErrors != 0 ||
            result.stats.read != source.expectedRecordCount) {
          failures.add(
            '${source.id} expected '
            '${source.expectedRecordCount}, read ${result.stats.read}'
            '${result.stats.parseErrors != 0 ? ', parseErrors ${result.stats.parseErrors}' : ''}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('candidate pool sources never enter the release gate', () {
      final pool = manifest.sources
          .where((source) => source.role == SourceRole.candidatePool)
          .toList();
      expect(pool, isNotEmpty);
      for (final source in pool) {
        expect(
          source.gateIncluded,
          isFalse,
          reason:
              'candidate_pool ${source.id} release gate\'e dahil edilmemeli '
              '(olgusal denetim tamamlanmadan)',
        );
      }
    });

    test(
      'deepseek expansion candidate keeps review-only model and mapping',
      () {
        final source = manifest.sources.firstWhere(
          (item) => item.id == 'deepseek_expansion_2026_08_18',
        );
        expect(source.role, SourceRole.candidatePool);
        expect(source.parser, 'csv');
        expect(source.canonicalGroup, 'candidate_questions');
        expect(source.reportIncluded, isTrue);
        expect(source.gateIncluded, isFalse);
        expect(source.productionLike, isFalse);
        expect(source.columns, {
          'id': 'id',
          'locale': 'language_code',
          'category': 'category_key',
          'prompt': 'prompt',
          'optionA': 'option_a',
          'optionB': 'option_b',
          'optionC': 'option_c',
          'optionD': 'option_d',
          'correct': 'correct_option',
          'explanation': 'explanation',
          'difficulty': 'difficulty',
          'sourceUrl': 'source_url',
          'status': 'publication_status',
        });
      },
    );
  });

  group('candidate csv parser mapping', () {
    final manifest = SourceManifest.fromJsonString(
      File('tool/question_quality/source_manifest.json').readAsStringSync(),
    );
    final source = manifest.sources.firstWhere(
      (item) => item.id == 'deepseek_expansion_2026_08_18',
    );
    const csvPath = 'docs/content_batches/aday_2026_08_18.csv';

    test('reads the real candidate CSV through the manifest mapping', () {
      final result = readSource(
        source,
        File(csvPath),
        repositoryRelativePath: csvPath,
      );

      expect(result.stats.parseErrors, 0);
      expect(result.records, isNotEmpty);

      final first = result.records.first;
      expect(first.sourceRecordId, isNotEmpty);
      expect(first.prompt, isNotEmpty);
      expect(first.category, isNotEmpty);
      expect(first.options, hasLength(4));
      expect(first.correctOptionText, isNotEmpty);
      expect(first.difficulty, isNotNull);
      expect(first.status, 'approved');
    });
  });

  group('source manifest', () {
    final manifest = SourceManifest.fromJsonString('''
{
  "version": 1,
  "sources": [
    {
      "id": "broad",
      "description": "broad",
      "glob": "supabase/*.csv",
      "role": "historical_snapshot",
      "parser": "csv",
      "canonicalGroup": "bank",
      "reportIncluded": true,
      "gateIncluded": false,
      "productionLike": false,
      "precedence": 10,
      "expectedRecordCount": null,
      "notes": ""
    },
    {
      "id": "active",
      "description": "active",
      "path": "supabase/questions_import_ready.csv",
      "role": "import_candidate",
      "parser": "csv",
      "canonicalGroup": "bank",
      "reportIncluded": true,
      "gateIncluded": true,
      "productionLike": true,
      "precedence": 100,
      "expectedRecordCount": 2,
      "notes": ""
    }
  ]
}
''');

    test('highest precedence wins and overlap is reported', () {
      final result = manifest.resolve('supabase/questions_import_ready.csv');
      expect(result.source?.id, 'active');
      expect(result.overlaps.map((entry) => entry.id), contains('broad'));
    });

    test('unknown source stays unclassified', () {
      final result = manifest.resolve('data/new_question_source.csv');
      expect(result.source, isNull);
      expect(result.isUnknown, isTrue);
    });

    test('equal precedence conflict is fatal', () {
      final conflicting = SourceManifest(
        version: 1,
        sources: [
          SourceDefinition.synthetic(id: 'a', glob: '*.csv', precedence: 5),
          SourceDefinition.synthetic(id: 'b', glob: '*.csv', precedence: 5),
        ],
      );
      expect(
        () => conflicting.resolve('bank.csv'),
        throwsA(isA<ManifestConflictException>()),
      );
    });
  });

  group('normalization', () {
    test('composes Kurmanci combining marks without ASCII folding', () {
      expect(
        normalizeText('  E\u0302 I\u0302 U\u0302 S\u0327 C\u0327  '),
        'ê î û ş ç',
      );
      expect(normalizeText('ê î û ş ç'), 'ê î û ş ç');
    });

    test('normalizes quotes whitespace and terminal punctuation', () {
      expect(normalizeText(' “Heval”   e?! '), '"heval" e');
    });

    test('option normalization preserves punctuation-only answers', () {
      expect(normalizeOption(' ? '), '?');
      expect(normalizeOption('??'), '??');
      expect(normalizeOption('?:'), '?:');
      expect(normalizeOption(' Heval?! '), 'heval');
    });

    test('stable hash is deterministic and SHA-256 sized', () {
      final first = sha256Hex('zankurd');
      expect(first, sha256Hex('zankurd'));
      expect(first, hasLength(64));
      expect(first, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('high-volume issue fingerprint is deterministic and 128-bit', () {
      final first = stableFingerprint('check|canonical|prompt');
      expect(first, stableFingerprint('check|canonical|prompt'));
      expect(first, hasLength(32));
      expect(first, isNot(stableFingerprint('check|canonical|other')));
    });
  });

  group('dynamic fact detection', () {
    QuestionRecord record(String prompt, {String? type}) => QuestionRecord(
      sourceId: 'test',
      sourceRole: SourceRole.runtimePrimary,
      sourcePath: 'test.json',
      sourceFormat: 'json',
      sourceRow: 1,
      sourceRecordId: 'q1',
      canonicalGroup: 'test',
      locale: 'ku-kmr',
      category: 'Dîrok',
      difficulty: 1,
      prompt: prompt,
      options: const ['A', 'B'],
      correctOptionIndex: 0,
      correctOptionText: 'A',
      explanation: 'Ravekirina bersivê.',
      questionType: type,
      sourceTitle: 'Çavkanî',
    );

    test('does not match îro inside dîrok or pîrozkirin', () {
      final issues = runChecks([
        record('Di dîroka Kurdan de Newroz çawa tê pîrozkirin?'),
      ]);

      expect(issues.where((issue) => issue.checkId == 'dynamic_fact'), isEmpty);
    });

    test('still detects standalone time-sensitive terms', () {
      final issues = runChecks([record('Niha başkan kî ye?')]);

      expect(
        issues.where((issue) => issue.checkId == 'dynamic_fact'),
        hasLength(1),
      );
    });

    test('does not treat a quoted vocabulary target as a current fact', () {
      final issues = runChecks([record('Kîjan peyv wateya "bugün" dide?')]);

      expect(issues.where((issue) => issue.checkId == 'dynamic_fact'), isEmpty);
    });
  });
}
