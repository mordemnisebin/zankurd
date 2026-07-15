import 'dart:io';

import '../src/discovery.dart';
import '../src/manifest.dart';
import '../src/models.dart';
import '../src/source_readers.dart';

class SourceCorpus {
  const SourceCorpus({
    required this.records,
    required this.sourcesByPath,
    required this.rawCorrectByLocation,
    required this.errors,
  });

  final List<QuestionRecord> records;
  final Map<String, SourceDefinition> sourcesByPath;
  final Map<String, String?> rawCorrectByLocation;
  final List<String> errors;

  String? rawCorrect(String path, int row) =>
      rawCorrectByLocation['$path:$row'];
}

SourceCorpus loadSourceCorpus(Directory root, SourceManifest manifest) {
  final selected = <String, SourceDefinition>{};
  for (final discovered in discoverPotentialQuestionSources(root)) {
    final resolution = manifest.resolve(discovered.path);
    if (!resolution.isUnknown && resolution.source!.reportIncluded) {
      selected[discovered.path] = resolution.source!;
    }
  }
  for (final source in manifest.sources.where(
    (source) => source.path != null && source.reportIncluded,
  )) {
    final path = source.path!.replaceAll('\\', '/');
    if (File(_absolute(root, path)).existsSync()) selected[path] = source;
  }

  final records = <QuestionRecord>[];
  final rawCorrect = <String, String?>{};
  final errors = <String>[];
  final paths = selected.keys.toList()..sort();
  for (final path in paths) {
    final source = selected[path]!;
    final file = File(_absolute(root, path));
    final result = readSource(source, file, repositoryRelativePath: path);
    records.addAll(result.records);
    errors.addAll(result.errors);
    if (source.parser == 'csv') {
      final rows = parseAdjudicationCsv(file.readAsStringSync());
      final correctColumn = source.columns['correct'];
      if (correctColumn != null) {
        for (final record in result.records) {
          rawCorrect['$path:${record.sourceRow}'] = rawCsvValue(
            rows,
            sourceRow: record.sourceRow,
            column: correctColumn,
          );
        }
      }
    } else if (source.parser == 'dart_quiz_question') {
      for (final record in result.records) {
        rawCorrect['$path:${record.sourceRow}'] = record.correctOptionText;
      }
    }
  }
  return SourceCorpus(
    records: records,
    sourcesByPath: selected,
    rawCorrectByLocation: rawCorrect,
    errors: errors,
  );
}

List<List<String>> parseAdjudicationCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(char);
      }
    } else if (char == '"' && field.isEmpty) {
      quoted = true;
    } else if (char == ',') {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (quoted) throw const FormatException('Unclosed quoted CSV field.');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

String? rawCsvValue(
  List<List<String>> rows, {
  required int sourceRow,
  required String column,
}) {
  if (rows.isEmpty || sourceRow < 2 || sourceRow > rows.length) return null;
  final index = rows.first.indexOf(column);
  if (index < 0 || index >= rows[sourceRow - 1].length) return null;
  return rows[sourceRow - 1][index];
}

String _absolute(Directory root, String relative) =>
    '${root.absolute.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';
