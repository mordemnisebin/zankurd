import '../src/models.dart';

enum Adjudication {
  confirmedDataDefect('confirmed_data_defect'),
  parserFalsePositive('parser_false_positive'),
  sourceSchemaMismatch('source_schema_mismatch'),
  crossSourceCopyArtifact('cross_source_copy_artifact'),
  historicalNonRuntime('historical_non_runtime'),
  ambiguousNeedsEditor('ambiguous_needs_editor'),
  factualVerificationRequired('factual_verification_required'),
  unableToLocateSource('unable_to_locate_source');

  const Adjudication(this.value);
  final String value;
}

enum RuntimeReachability {
  runtimeActive('runtime_active'),
  importActiveNotRuntime('import_active_not_runtime'),
  publishCandidateNotRuntime('publish_candidate_not_runtime'),
  historicalOnly('historical_only'),
  quarantineOnly('quarantine_only'),
  unknown('unknown');

  const RuntimeReachability(this.value);
  final String value;
}

enum NumericBase { zeroBased, oneBased }

enum LocateStatus { located, notFound, ambiguous }

class CorrectInterpretation {
  const CorrectInterpretation({
    required this.raw,
    required this.index,
    required this.text,
    required this.rule,
  });

  final String raw;
  final int? index;
  final String? text;
  final String rule;
}

class IssueReference {
  const IssueReference({
    required this.fingerprint,
    required this.sourcePath,
    required this.sourceRow,
    required this.recordId,
  });

  final String fingerprint;
  final String sourcePath;
  final int sourceRow;
  final String? recordId;
}

class LocateResult {
  const LocateResult(this.status, this.record);
  final LocateStatus status;
  final QuestionRecord? record;
}

class SampleCandidate {
  const SampleCandidate(
    this.role,
    this.sourceId,
    this.sourceRow,
    this.fingerprint,
  );

  final String role;
  final String sourceId;
  final int sourceRow;
  final String fingerprint;
}

class AdjudicationRecord {
  const AdjudicationRecord({
    required this.issueFingerprint,
    required this.checkId,
    required this.severity,
    required this.sourceId,
    required this.sourceRole,
    required this.gateIncluded,
    required this.productionLike,
    required this.sourcePath,
    required this.sourceRow,
    required this.sourceRecordId,
    required this.runtimeId,
    required this.canonicalId,
    required this.prompt,
    required this.options,
    required this.rawCorrectValue,
    required this.parsedCorrectIndex,
    required this.parsedCorrectText,
    required this.explanation,
    required this.category,
    required this.difficulty,
    required this.parserName,
    required this.parserRule,
    required this.originalSourceLocated,
    required this.runtimeReachable,
    required this.duplicateSourceCount,
    required this.crossSourceDifference,
    required this.adjudication,
    required this.confidence,
    required this.evidence,
    required this.factualVerificationNeeded,
    required this.kurmanciEditorNeeded,
    required this.recommendedAction,
    this.safeForAutomaticFix = false,
  });

  final String issueFingerprint;
  final String checkId;
  final String severity;
  final String sourceId;
  final String sourceRole;
  final bool gateIncluded;
  final bool productionLike;
  final String sourcePath;
  final int sourceRow;
  final String? sourceRecordId;
  final String? runtimeId;
  final String? canonicalId;
  final String prompt;
  final List<String> options;
  final String? rawCorrectValue;
  final int? parsedCorrectIndex;
  final String? parsedCorrectText;
  final String? explanation;
  final String? category;
  final int? difficulty;
  final String parserName;
  final String parserRule;
  final bool originalSourceLocated;
  final RuntimeReachability runtimeReachable;
  final int duplicateSourceCount;
  final String crossSourceDifference;
  final Adjudication adjudication;
  final String confidence;
  final String evidence;
  final bool factualVerificationNeeded;
  final bool kurmanciEditorNeeded;
  final String recommendedAction;
  final bool safeForAutomaticFix;
}
