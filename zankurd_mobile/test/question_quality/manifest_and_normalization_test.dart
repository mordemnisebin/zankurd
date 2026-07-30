import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/discovery.dart';
import '../../tool/question_quality/src/checks.dart';
import '../../tool/question_quality/src/manifest.dart';
import '../../tool/question_quality/src/models.dart';
import '../../tool/question_quality/src/normalization.dart';

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
