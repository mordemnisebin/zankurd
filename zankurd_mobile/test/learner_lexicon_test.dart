import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

void main() {
  test('öğrenen sözlüğü benzersiz ve kaynaklı kayıtlar içerir', () {
    final ids = <String>{};

    for (final entry in LearnerLexicon.entries) {
      expect(entry.id.trim(), isNotEmpty);
      expect(
        ids.add(entry.id),
        isTrue,
        reason: 'Yinelenen sözlük kimliği: ${entry.id}',
      );
      expect(entry.termKu.trim(), isNotEmpty, reason: entry.id);
      expect(entry.meaningTr.trim(), isNotEmpty, reason: entry.id);
      expect(
        LearnerLexicon.sources.containsKey(entry.sourceId),
        isTrue,
        reason: '${entry.id} bilinmeyen kaynağa bağlı: ${entry.sourceId}',
      );
    }
  });

  test('sözlük kaynakları benzersiz, dolu ve kendi anahtarıyla tutarlıdır', () {
    for (final sourceEntry in LearnerLexicon.sources.entries) {
      final source = sourceEntry.value;
      expect(source.id, sourceEntry.key);
      expect(source.titleKu.trim(), isNotEmpty, reason: source.id);
      expect(source.titleTr.trim(), isNotEmpty, reason: source.id);
      expect(source.categoryKu.trim(), isNotEmpty, reason: source.id);
      expect(source.categoryTr.trim(), isNotEmpty, reason: source.id);
    }
  });

  test(
    'ilk sözlük çekirdeğindeki her çeviri ders kaynağında birebir vardır',
    () {
      final lessonSource = File(
        'lib/src/data/mock_zankurd_repository.dart',
      ).readAsStringSync();

      for (final entry in LearnerLexicon.entries) {
        final authoredPair = '${entry.termKu}: ${entry.meaningTr}';
        expect(
          lessonSource,
          contains(authoredPair),
          reason:
              '${entry.id} sözlük kaydı ders metninden birebir gelmiyor: '
              '$authoredPair',
        );
      }
    },
  );

  test('güvenli kaynak genişlemesi 17 dersin tamamını kapsar', () {
    expect(LearnerLexicon.entriesForSource('everyday_2'), hasLength(4));
    expect(LearnerLexicon.entriesForSource('culture_2'), hasLength(2));
    expect(LearnerLexicon.entriesForSource('geography_1'), hasLength(2));
    expect(LearnerLexicon.entriesForSource('time_1'), hasLength(6));

    final covered = LearnerLexicon.sources.keys.toSet();
    expect(covered, hasLength(17));
    expect(covered.contains('time_1'), isTrue);
  });
}
