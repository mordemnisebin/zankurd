import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/baseline.dart';
import '../../tool/question_quality/src/csv_writer.dart';

void main() {
  test('CSV cells that could execute formulas are escaped', () {
    expect(csvCell('=SUM(A1:A2)'), "'=SUM(A1:A2)");
    expect(csvCell('+cmd'), "'+cmd");
    expect(csvCell('-1+2'), "'-1+2");
    expect(csvCell('@user'), "'@user");
    expect(csvCell('safe'), 'safe');
  });

  test('CSV quoting is deterministic', () {
    expect(csvRow(['a', 'b,c', 'say "hi"']), 'a,"b,c","say ""hi"""');
  });

  test('same debt passes and a new blocker fails', () {
    final baseline = AuditBaseline.synthetic(
      issueFingerprints: const {'old'},
      blockerCount: 1,
      criticalCount: 2,
    );
    expect(
      compareBaseline(
        baseline,
        AuditSnapshot.synthetic(
          issueFingerprints: const {'old'},
          blockerCount: 1,
          criticalCount: 2,
        ),
      ).passes,
      isTrue,
    );
    final regression = compareBaseline(
      baseline,
      AuditSnapshot.synthetic(
        issueFingerprints: const {'old', 'new'},
        blockerCount: 2,
        criticalCount: 2,
      ),
    );
    expect(regression.passes, isFalse);
    expect(regression.reasons, contains('New issue fingerprint: new'));
  });

  test('improvement passes without requiring baseline rewrite', () {
    final result = compareBaseline(
      AuditBaseline.synthetic(
        issueFingerprints: const {'old', 'fixed'},
        blockerCount: 1,
        criticalCount: 2,
      ),
      AuditSnapshot.synthetic(
        issueFingerprints: const {'old'},
        blockerCount: 0,
        criticalCount: 1,
      ),
    );
    expect(result.passes, isTrue);
  });

  test('unknown source always fails the gate', () {
    final result = compareBaseline(
      AuditBaseline.synthetic(issueFingerprints: const {}),
      AuditSnapshot.synthetic(
        issueFingerprints: const {},
        unknownSourceCount: 1,
      ),
    );
    expect(result.passes, isFalse);
    expect(result.reasons, contains('Unclassified question source detected.'));
  });
}
