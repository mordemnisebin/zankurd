import 'dart:io';

import 'promotion.dart';

List<PromotionCandidate> loadPromotionCandidates(File file) {
  final rows = _parseCsv(file.readAsStringSync());
  if (rows.isEmpty) return const [];
  final headers = rows.first.map((value) => value.trim()).toList();
  final indexes = <String, int>{
    for (var index = 0; index < headers.length; index++) headers[index]: index,
  };
  final candidates = <PromotionCandidate>[];
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.every((value) => value.trim().isEmpty)) continue;
    String value(List<String> names) {
      for (final name in names) {
        final index = indexes[name];
        if (index != null && index < row.length) return row[index].trim();
      }
      return '';
    }

    final difficultyValue = value(['difficulty', 'corrected_difficulty']);
    candidates.add(
      PromotionCandidate(
        row: rowIndex + 1,
        id: value(['review_id', 'id', 'candidate_id']),
        locale: value(['language_code', 'locale']),
        category: value(['category_key', 'category']),
        prompt: value(['corrected_prompt', 'prompt']),
        options: [
          value(['corrected_option_a', 'option_a']),
          value(['corrected_option_b', 'option_b']),
          value(['corrected_option_c', 'option_c']),
          value(['corrected_option_d', 'option_d']),
        ],
        correctOption: value(['corrected_correct_option', 'correct_option']),
        explanation: value(['corrected_explanation', 'explanation']),
        difficulty: int.tryParse(difficultyValue),
        sourceVerified: value(['source_verified', 'verified']),
        sourceUrl: value(['better_source_url', 'source_url']),
        publicationStatus: value(['publication_status', 'status']),
        issueType: value(['issue_type']),
        confidence: double.tryParse(value(['confidence_0_to_1', 'confidence'])),
        reviewNotes: value(['review_notes', 'notes']),
      ),
    );
  }
  return List.unmodifiable(candidates);
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < input.length; index++) {
    final char = input[index];
    if (quoted) {
      if (char == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
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
      if (char == '\r' &&
          index + 1 < input.length &&
          input[index + 1] == '\n') {
        index++;
      }
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
