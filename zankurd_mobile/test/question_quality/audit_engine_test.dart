import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/audit_engine.dart';
import '../../tool/question_quality/src/manifest.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('audit-engine-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('engine separates report records from gate records', () {
    File('${temp.path}/runtime.csv').writeAsStringSync(
      'id,prompt,a,b,correct,category,difficulty\nq1,Pirs?,A,B,A,Ziman,1\n',
    );
    File('${temp.path}/history.csv').writeAsStringSync(
      'id,prompt,a,b,correct,category,difficulty\nq2,Pirs 2?,A,B,B,Ziman,1\n',
    );
    final manifest = SourceManifest.fromJsonString(_manifestJson);
    final result = AuditEngine(root: temp, manifest: manifest).run();
    expect(result.reportRecords, hasLength(2));
    expect(result.gateRecords, hasLength(1));
    expect(result.reportPhysicalCount, 2);
    expect(result.gatePhysicalCount, 1);
  });

  test('unknown source is inventoried and makes gate snapshot unsafe', () {
    File('${temp.path}/runtime.csv').writeAsStringSync(
      'id,prompt,a,b,correct,category,difficulty\nq1,Pirs?,A,B,A,Ziman,1\n',
    );
    File(
      '${temp.path}/new_questions.csv',
    ).writeAsStringSync('id,prompt,correct_option\n');
    final result = AuditEngine(
      root: temp,
      manifest: SourceManifest.fromJsonString(_manifestJson),
    ).run();
    expect(
      result.unknownSources.map((item) => item.path),
      contains('new_questions.csv'),
    );
    expect(result.snapshot.unknownSourceCount, 1);
  });
}

const _manifestJson = '''
{
  "version": 1,
  "sources": [
    {
      "id":"runtime","description":"runtime","path":"runtime.csv",
      "role":"runtime_primary","parser":"csv","canonicalGroup":"q",
      "reportIncluded":true,"gateIncluded":true,"productionLike":true,
      "precedence":100,"expectedRecordCount":1,"notes":"",
      "columns":{"id":"id","prompt":"prompt","optionA":"a","optionB":"b","correct":"correct","category":"category","difficulty":"difficulty"}
    },
    {
      "id":"history","description":"history","path":"history.csv",
      "role":"historical_snapshot","parser":"csv","canonicalGroup":"q",
      "reportIncluded":true,"gateIncluded":false,"productionLike":false,
      "precedence":10,"expectedRecordCount":1,"notes":"",
      "columns":{"id":"id","prompt":"prompt","optionA":"a","optionB":"b","correct":"correct","category":"category","difficulty":"difficulty"}
    }
  ]
}
''';
