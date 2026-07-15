enum SourceRole {
  runtimePrimary('runtime_primary'),
  runtimeSecondary('runtime_secondary'),
  publishCandidate('publish_candidate'),
  importCandidate('import_candidate'),
  historicalSnapshot('historical_snapshot'),
  candidatePool('candidate_pool'),
  quarantine('quarantine'),
  testFixture('test_fixture'),
  mock('mock'),
  generatedReport('generated_report'),
  ignoredNonQuestion('ignored_non_question');

  const SourceRole(this.jsonName);
  final String jsonName;

  static SourceRole parse(String value) => values.firstWhere(
    (role) => role.jsonName == value,
    orElse: () => throw FormatException('Unknown source role: $value'),
  );
}

enum Severity {
  blocker,
  critical,
  warning,
  info;

  int get rank => index;
}

class SourceDefinition {
  const SourceDefinition({
    required this.id,
    required this.description,
    this.path,
    this.glob,
    required this.role,
    required this.parser,
    required this.canonicalGroup,
    required this.reportIncluded,
    required this.gateIncluded,
    required this.productionLike,
    required this.precedence,
    required this.expectedRecordCount,
    required this.notes,
    this.columns = const {},
  }) : assert(path != null || glob != null);

  factory SourceDefinition.synthetic({
    required String id,
    required String glob,
    required int precedence,
  }) => SourceDefinition(
    id: id,
    description: id,
    glob: glob,
    role: SourceRole.historicalSnapshot,
    parser: 'csv',
    canonicalGroup: 'synthetic',
    reportIncluded: true,
    gateIncluded: false,
    productionLike: false,
    precedence: precedence,
    expectedRecordCount: null,
    notes: '',
  );

  factory SourceDefinition.fromJson(Map<String, Object?> json) {
    int? expected;
    final rawExpected = json['expectedRecordCount'];
    if (rawExpected is num) expected = rawExpected.toInt();
    final rawColumns = json['columns'];
    return SourceDefinition(
      id: json['id']! as String,
      description: json['description']! as String,
      path: json['path'] as String?,
      glob: json['glob'] as String?,
      role: SourceRole.parse(json['role']! as String),
      parser: json['parser']! as String,
      canonicalGroup: json['canonicalGroup']! as String,
      reportIncluded: json['reportIncluded']! as bool,
      gateIncluded: json['gateIncluded']! as bool,
      productionLike: json['productionLike']! as bool,
      precedence: (json['precedence']! as num).toInt(),
      expectedRecordCount: expected,
      notes: json['notes']! as String,
      columns: rawColumns is Map
          ? rawColumns.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
    );
  }

  final String id;
  final String description;
  final String? path;
  final String? glob;
  final SourceRole role;
  final String parser;
  final String canonicalGroup;
  final bool reportIncluded;
  final bool gateIncluded;
  final bool productionLike;
  final int precedence;
  final int? expectedRecordCount;
  final String notes;
  final Map<String, String> columns;
}

class QuestionRecord {
  const QuestionRecord({
    required this.sourceId,
    required this.sourceRole,
    required this.sourcePath,
    required this.sourceFormat,
    required this.sourceRow,
    this.sourceRecordId,
    this.runtimeId,
    this.canonicalId,
    required this.canonicalGroup,
    this.locale,
    this.dialect,
    this.category,
    this.subcategory,
    this.difficulty,
    required this.prompt,
    required this.options,
    this.correctOptionIndex,
    this.correctOptionText,
    this.explanation,
    this.tags = const [],
    this.imagePath,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceDate,
    this.reviewedAt,
    this.reviewedBy,
    this.status,
    this.rawFingerprint,
    this.normalizedFingerprint,
  });

  final String sourceId;
  final SourceRole sourceRole;
  final String sourcePath;
  final String sourceFormat;
  final int sourceRow;
  final String? sourceRecordId;
  final String? runtimeId;
  final String? canonicalId;
  final String canonicalGroup;
  final String? locale;
  final String? dialect;
  final String? category;
  final String? subcategory;
  final int? difficulty;
  final String prompt;
  final List<String> options;
  final int? correctOptionIndex;
  final String? correctOptionText;
  final String? explanation;
  final List<String> tags;
  final String? imagePath;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceDate;
  final String? reviewedAt;
  final String? reviewedBy;
  final String? status;
  final String? rawFingerprint;
  final String? normalizedFingerprint;
}

class AuditIssue {
  const AuditIssue({
    required this.checkId,
    required this.severity,
    required this.record,
    required this.message,
    required this.fingerprint,
    this.confidence = 'high',
  });

  final String checkId;
  final Severity severity;
  final QuestionRecord record;
  final String message;
  final String fingerprint;
  final String confidence;
}

class CrossSourceDivergence {
  const CrossSourceDivergence({
    required this.canonicalKey,
    required this.left,
    required this.right,
    required this.fields,
    required this.severity,
  });

  final String canonicalKey;
  final QuestionRecord left;
  final QuestionRecord right;
  final List<String> fields;
  final Severity severity;
}

class ParserStats {
  const ParserStats({
    this.read = 0,
    this.skipped = 0,
    this.parseErrors = 0,
    this.headers = 0,
    this.comments = 0,
    this.blankLines = 0,
  });

  final int read;
  final int skipped;
  final int parseErrors;
  final int headers;
  final int comments;
  final int blankLines;
}

class SourceReadResult {
  const SourceReadResult({
    required this.source,
    required this.records,
    required this.stats,
    this.errors = const [],
  });

  final SourceDefinition source;
  final List<QuestionRecord> records;
  final ParserStats stats;
  final List<String> errors;
}
