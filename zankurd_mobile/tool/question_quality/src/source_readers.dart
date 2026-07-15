import 'dart:convert';
import 'dart:io';

import 'models.dart';

SourceReadResult readSource(
  SourceDefinition source,
  File file, {
  required String repositoryRelativePath,
}) {
  try {
    return switch (source.parser) {
      'csv' => _readCsv(source, file, repositoryRelativePath),
      'json' => _readJson(source, file, repositoryRelativePath),
      'dart_quiz_question' => _readDart(source, file, repositoryRelativePath),
      'sql_count' => _readSqlCount(source, file, repositoryRelativePath),
      'none' => SourceReadResult(
        source: source,
        records: const [],
        stats: const ParserStats(),
      ),
      _ => throw FormatException('Unsupported parser: ${source.parser}'),
    };
  } catch (error) {
    return SourceReadResult(
      source: source,
      records: const [],
      stats: const ParserStats(parseErrors: 1),
      errors: ['$repositoryRelativePath: $error'],
    );
  }
}

SourceReadResult _readCsv(SourceDefinition source, File file, String path) {
  final rows = _parseCsv(file.readAsStringSync());
  if (rows.isEmpty) {
    return SourceReadResult(
      source: source,
      records: const [],
      stats: const ParserStats(),
    );
  }
  final headers = rows.first.map((value) => value.trim()).toList();
  final index = <String, int>{
    for (var i = 0; i < headers.length; i++) headers[i]: i,
  };
  final records = <QuestionRecord>[];
  final errors = <String>[];
  var blank = 0;
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.every((value) => value.trim().isEmpty)) {
      blank++;
      continue;
    }
    try {
      records.add(
        _recordFromFields(source, path, rowIndex + 1, (field) {
          final column = source.columns[field];
          if (column == null) return null;
          final position = index[column];
          return position == null || position >= row.length
              ? null
              : row[position];
        }, optionsList: null),
      );
    } catch (error) {
      errors.add('$path:${rowIndex + 1}: $error');
    }
  }
  return SourceReadResult(
    source: source,
    records: records,
    stats: ParserStats(
      read: records.length,
      parseErrors: errors.length,
      headers: 1,
      blankLines: blank,
    ),
    errors: errors,
  );
}

SourceReadResult _readJson(SourceDefinition source, File file, String path) {
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    final items = decoded is List
        ? decoded
        : decoded is Map && decoded['questions'] is List
        ? decoded['questions'] as List
        : throw const FormatException(
            'Expected a JSON array or questions array.',
          );
    final records = <QuestionRecord>[];
    final errors = <String>[];
    for (var i = 0; i < items.length; i++) {
      try {
        final map = items[i] as Map;
        Object? raw(String field) {
          final column = source.columns[field];
          return column == null ? null : map[column];
        }

        final optionsValue = raw('options');
        records.add(
          _recordFromFields(
            source,
            path,
            i + 1,
            (field) => raw(field)?.toString(),
            optionsList: optionsValue is List
                ? optionsValue.map((value) => value.toString()).toList()
                : null,
          ),
        );
      } catch (error) {
        errors.add('$path:${i + 1}: $error');
      }
    }
    return SourceReadResult(
      source: source,
      records: records,
      stats: ParserStats(read: records.length, parseErrors: errors.length),
      errors: errors,
    );
  } catch (error) {
    return SourceReadResult(
      source: source,
      records: const [],
      stats: const ParserStats(parseErrors: 1),
      errors: ['$path: $error'],
    );
  }
}

SourceReadResult _readDart(SourceDefinition source, File file, String path) {
  final content = file.readAsStringSync();
  final blocks = _dartConstructorBlocks(content, 'QuizQuestion(');
  final records = <QuestionRecord>[];
  final errors = <String>[];
  for (final block in blocks) {
    try {
      final start = block.start;
      final body = block.text;
      final answersExpression = _dartNamedExpression(body, 'answers');
      final options = answersExpression == null
          ? <String>[]
          : _dartStrings(answersExpression);
      final correct = _dartString(_dartNamedExpression(body, 'correctAnswer'));
      final correctIndex = correct == null ? null : options.indexOf(correct);
      records.add(
        QuestionRecord(
          sourceId: source.id,
          sourceRole: source.role,
          sourcePath: path,
          sourceFormat: 'dart',
          sourceRow: '\n'.allMatches(content.substring(0, start)).length + 1,
          sourceRecordId: _dartString(_dartNamedExpression(body, 'id')),
          runtimeId: _dartString(_dartNamedExpression(body, 'id')),
          canonicalGroup: source.canonicalGroup,
          locale: source.columns['locale'] ?? 'ku-kmr',
          category: _dartString(_dartNamedExpression(body, 'category')),
          difficulty: int.tryParse(
            _dartNamedExpression(body, 'difficulty')?.trim() ?? '',
          ),
          prompt: _dartString(_dartNamedExpression(body, 'prompt')) ?? '',
          options: options,
          correctOptionIndex: correctIndex != null && correctIndex >= 0
              ? correctIndex
              : null,
          correctOptionText: correct,
          explanation: _dartString(_dartNamedExpression(body, 'explanation')),
          imagePath: _dartString(_dartNamedExpression(body, 'imageUrl')),
          status: body.contains('ReviewStatus.approved') ? 'approved' : null,
        ),
      );
    } catch (error) {
      errors.add('$path:${block.start}: $error');
    }
  }
  return SourceReadResult(
    source: source,
    records: records,
    stats: ParserStats(read: records.length, parseErrors: errors.length),
    errors: errors,
  );
}

SourceReadResult _readSqlCount(
  SourceDefinition source,
  File file,
  String path,
) {
  final content = file.readAsStringSync();
  final count = RegExp(r'^\s*\(', multiLine: true).allMatches(content).length;
  return SourceReadResult(
    source: source,
    records: const [],
    stats: ParserStats(read: count),
  );
}

QuestionRecord _recordFromFields(
  SourceDefinition source,
  String path,
  int row,
  String? Function(String field) value, {
  required List<String>? optionsList,
}) {
  final options =
      optionsList ??
      [
        value('optionA'),
        value('optionB'),
        value('optionC'),
        value('optionD'),
      ].whereType<String>().where((item) => item.isNotEmpty).toList();
  final correctRaw = value('correct')?.trim();
  int? index;
  String? correctText;
  if (correctRaw != null && correctRaw.isNotEmpty) {
    final letter = 'ABCD'.indexOf(correctRaw.toUpperCase());
    if (letter >= 0) {
      index = letter;
      if (letter < options.length) correctText = options[letter];
    } else {
      final numeric = int.tryParse(correctRaw);
      if (numeric != null) {
        index = numeric;
        if (index >= 0 && index < options.length) correctText = options[index];
      } else {
        correctText = correctRaw;
        final found = options.indexOf(correctRaw);
        if (found >= 0) index = found;
      }
    }
  }
  return QuestionRecord(
    sourceId: source.id,
    sourceRole: source.role,
    sourcePath: path,
    sourceFormat: source.parser,
    sourceRow: row,
    sourceRecordId: value('id'),
    runtimeId: value('runtimeId') ?? value('id'),
    canonicalGroup: source.canonicalGroup,
    locale: value('locale'),
    dialect: value('dialect'),
    category: value('category'),
    subcategory: value('subcategory'),
    difficulty: int.tryParse(value('difficulty') ?? ''),
    prompt: value('prompt') ?? '',
    options: options,
    correctOptionIndex: index,
    correctOptionText: correctText,
    explanation: value('explanation'),
    imagePath: value('imagePath'),
    sourceTitle: value('sourceTitle'),
    sourceUrl: value('sourceUrl'),
    sourceDate: value('sourceDate'),
    reviewedAt: value('reviewedAt'),
    reviewedBy: value('reviewedBy'),
    status: value('status'),
  );
}

List<List<String>> _parseCsv(String input) {
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

class _Block {
  const _Block(this.start, this.text);
  final int start;
  final String text;
}

List<_Block> _dartConstructorBlocks(String content, String marker) {
  final blocks = <_Block>[];
  var search = 0;
  while (true) {
    final start = content.indexOf(marker, search);
    if (start < 0) break;
    var depth = 1;
    var quote = '';
    var escaped = false;
    var end = start + marker.length;
    for (; end < content.length && depth > 0; end++) {
      final char = content[end];
      if (quote.isNotEmpty) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == '\\') {
          escaped = true;
          continue;
        }
        if (char == quote) quote = '';
      } else if (char == "'" || char == '"') {
        quote = char;
      } else if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
    }
    if (depth != 0) {
      throw FormatException('Unclosed QuizQuestion at offset $start.');
    }
    blocks.add(
      _Block(start, content.substring(start + marker.length, end - 1)),
    );
    search = end;
  }
  return blocks;
}

String? _dartNamedExpression(String body, String name) {
  final match = RegExp(
    '(?:^|\\n)\\s*${RegExp.escape(name)}\\s*:',
  ).firstMatch(body);
  if (match == null) return null;
  final start = match.end;
  var square = 0;
  var round = 0;
  var curly = 0;
  var quote = '';
  var escaped = false;
  for (var i = start; i < body.length; i++) {
    final char = body[i];
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == quote) quote = '';
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '[') {
      square++;
    } else if (char == ']') {
      square--;
    } else if (char == '(') {
      round++;
    } else if (char == ')') {
      round--;
    } else if (char == '{') {
      curly++;
    } else if (char == '}') {
      curly--;
    } else if (char == ',' && square == 0 && round == 0 && curly == 0) {
      return body.substring(start, i).trim();
    }
  }
  return body.substring(start).trim();
}

String? _dartString(String? expression) {
  if (expression == null) return null;
  final values = _dartStrings(expression);
  return values.isEmpty ? null : values.join();
}

List<String> _dartStrings(String expression) {
  final values = <String>[];
  final pattern = RegExp(
    r'''(?:r)?('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''',
    multiLine: true,
  );
  for (final match in pattern.allMatches(expression)) {
    final token = match.group(0)!;
    final raw = token.startsWith('r');
    final quoted = raw ? token.substring(1) : token;
    var value = quoted.substring(1, quoted.length - 1);
    if (!raw) {
      value = value
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '\r')
          .replaceAll(r'\t', '\t')
          .replaceAll(r"\'", "'")
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\');
    }
    values.add(value);
  }
  return values;
}
