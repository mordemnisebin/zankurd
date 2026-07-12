/// Soru içeriği için editör/kalite meta verisi (geriye uyumlu, opsiyonel).
///
/// Eski soru JSON'ları bu alanları içermez; hepsi güvenli varsayılanlara
/// düşer. `reviewStatus` bilinmiyorsa `null` kalır — bu bilinçli bir seçim:
/// mevcut offline içeriğe **sahte "onaylandı" değeri basmamak** için. Kalite
/// politikası (bkz. [ContentQualityPolicy]) `null`'ı "uygun ama doğrulanmamış"
/// olarak ele alır, böylece hiçbir mevcut soru görünmez olmaz.
library;

enum ReviewStatus {
  draft,
  needsReview,
  approved,
  rejected;

  String get storageKey => name;

  /// Bilinmeyen/eksik değer güvenli biçimde `null` döner (varsayılana düşer).
  static ReviewStatus? fromKey(Object? key) {
    if (key is! String) return null;
    for (final s in ReviewStatus.values) {
      if (s.name == key) return s;
    }
    return null;
  }
}

class QuestionMetadata {
  const QuestionMetadata({
    this.reviewStatus,
    this.dialect,
    this.sourceTitle,
    this.sourceReference,
    this.reviewedBy,
    this.reviewedAt,
    this.lastContentCheckAt,
    this.qualityVersion = 0,
    this.reportCount = 0,
  });

  /// Onay durumu. `null` = bilinmiyor (doğrulanmamış), rejected = elenmiş.
  final ReviewStatus? reviewStatus;

  /// Lehçe/bölge; `null` ise standart Kurmancî varsayılır.
  final String? dialect;
  final String? sourceTitle;
  final String? sourceReference;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? lastContentCheckAt;
  final int qualityVersion;
  final int reportCount;

  bool get isEmpty =>
      reviewStatus == null &&
      dialect == null &&
      sourceTitle == null &&
      sourceReference == null &&
      reviewedBy == null &&
      reviewedAt == null &&
      lastContentCheckAt == null &&
      qualityVersion == 0 &&
      reportCount == 0;

  static int _asInt(Object? v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static String? _asString(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  /// Geriye uyumlu ayrıştırma: eksik/geçersiz alanlar güvenli varsayılana düşer.
  factory QuestionMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QuestionMetadata();
    return QuestionMetadata(
      reviewStatus: ReviewStatus.fromKey(json['reviewStatus']),
      dialect: _asString(json['dialect']),
      sourceTitle: _asString(json['sourceTitle']),
      sourceReference: _asString(json['sourceReference']),
      reviewedBy: _asString(json['reviewedBy']),
      reviewedAt: _asString(json['reviewedAt']),
      lastContentCheckAt: _asString(json['lastContentCheckAt']),
      qualityVersion: _asInt(json['qualityVersion'], 0),
      reportCount: _asInt(json['reportCount'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
    if (reviewStatus != null) 'reviewStatus': reviewStatus!.storageKey,
    if (dialect != null) 'dialect': dialect,
    if (sourceTitle != null) 'sourceTitle': sourceTitle,
    if (sourceReference != null) 'sourceReference': sourceReference,
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (reviewedAt != null) 'reviewedAt': reviewedAt,
    if (lastContentCheckAt != null) 'lastContentCheckAt': lastContentCheckAt,
    if (qualityVersion != 0) 'qualityVersion': qualityVersion,
    if (reportCount != 0) 'reportCount': reportCount,
  };

  QuestionMetadata copyWith({ReviewStatus? reviewStatus, int? reportCount}) {
    return QuestionMetadata(
      reviewStatus: reviewStatus ?? this.reviewStatus,
      dialect: dialect,
      sourceTitle: sourceTitle,
      sourceReference: sourceReference,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      lastContentCheckAt: lastContentCheckAt,
      qualityVersion: qualityVersion,
      reportCount: reportCount ?? this.reportCount,
    );
  }
}
