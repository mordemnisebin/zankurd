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
    // Bilinmeyen bir değer, güvenli varsayılanın yerine *asla* sessizce
    // kabul edilmesin; bu durumda soru akışı kısıtlanır (fail-closed).
    return ReviewStatus.rejected;
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
    this.learningLessonId,
    this.productiveRecallEligible = false,
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

  /// Öğrenme modundaki belirli bir dersle açık editöryal eşleşme.
  ///
  /// `null` olduğunda soru için ders ilişkisi *çıkarılmaz*. Bu alan yalnız
  /// içerik gerçekten o derse bağlandığında doldurulur; Mini Quiz böylece
  /// geniş kategori havuzundan rastgele bir soruyu "ders sorusu" diye
  /// sunmaz.
  final String? learningLessonId;

  /// Öğrenme modunda seçenekleri kaldırıp yazmalı hatırlamaya çevirmeye
  /// editörün açıkça izin verdiği soru. Varsayılan `false`: MC içeriği
  /// prompt anlamı denetlenmeden otomatik olarak dönüştürülmez.
  final bool productiveRecallEligible;
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
      learningLessonId == null &&
      !productiveRecallEligible &&
      qualityVersion == 0 &&
      reportCount == 0;

  /// Oyuncuya künye göstermek için en az bir dolu alan gerekir.
  ///
  /// İkisi de boşken "kaynak" satırı çizilmez: boş künye, kaynaklı
  /// görünmekten beterdir (A17).
  bool get hasCitableSource {
    final title = sourceTitle?.trim() ?? '';
    final ref = sourceReference?.trim() ?? '';
    return title.isNotEmpty || ref.isNotEmpty;
  }

  /// Oyuncuya gösterilecek künye (cevap sonrası "Kaynak: …" satırı).
  ///
  /// Neden süzgeç var: paketli soruların `sourceTitle` alanı çoğu zaman
  /// EDİTÖRYAL iz sürme etiketidir ("ZanKurd başlangıç dersi: …", "Source-first
  /// verified expansion …", `internal:` başvurular) ve oyuncuya anlamsızdır.
  /// Sunucudaki `questions.source_url` da bazı satırlarda bir bağlantı değil
  /// toplu-yükleme etiketidir ("curated_movement_wave_1"). Bu yüzden bağlantı
  /// yalnız `http(s)://` ile başlıyorsa bağlantı sayılır; başlık iç etiketse
  /// bağlantının sunucu adı (ör. `en.wikipedia.org`) gösterilir; ikisi de
  /// yoksa `null` döner ve ekranda HİÇ yer ayrılmaz.
  ({String label, Uri? url})? get displaySource {
    final url = _firstHttpUri(sourceReference);
    final title = sourceTitle?.trim() ?? '';
    if (title.isNotEmpty && !_isInternalSourceLabel(title)) {
      return (label: title, url: url);
    }
    if (url != null) return (label: url.host, url: url);
    final ref = (sourceReference ?? '').split(';').first.trim();
    // Boşluksuz tek sözcük bir kitap/makale künyesi değil toplu-yükleme
    // etiketidir (ör. `zankurd_pure_kurdish_v1`).
    if (ref.contains(' ') && !_isInternalSourceLabel(ref)) {
      return (label: ref, url: null);
    }
    return null;
  }

  static final RegExp _httpPattern = RegExp(
    r'https?://[^\s;,)]+',
    caseSensitive: false,
  );

  static Uri? _firstHttpUri(String? text) {
    if (text == null) return null;
    final match = _httpPattern.firstMatch(text);
    if (match == null) return null;
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  static const List<String> _internalLabelPrefixes = [
    'internal:',
    'zankurd',
    'source-first',
    'kolay soru',
    'görselden',
    'topluluk katk',
    'editoryal',
  ];

  static bool _isInternalSourceLabel(String text) {
    final lower = text.toLowerCase();
    return _internalLabelPrefixes.any(lower.startsWith);
  }

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
      learningLessonId: _asString(json['learningLessonId']),
      productiveRecallEligible: json['productiveRecallEligible'] == true,
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
    if (learningLessonId != null) 'learningLessonId': learningLessonId,
    if (productiveRecallEligible)
      'productiveRecallEligible': productiveRecallEligible,
    if (qualityVersion != 0) 'qualityVersion': qualityVersion,
    if (reportCount != 0) 'reportCount': reportCount,
  };

  QuestionMetadata copyWith({
    ReviewStatus? reviewStatus,
    String? learningLessonId,
    bool? productiveRecallEligible,
    int? reportCount,
  }) {
    return QuestionMetadata(
      reviewStatus: reviewStatus ?? this.reviewStatus,
      dialect: dialect,
      sourceTitle: sourceTitle,
      sourceReference: sourceReference,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      lastContentCheckAt: lastContentCheckAt,
      learningLessonId: learningLessonId ?? this.learningLessonId,
      productiveRecallEligible:
          productiveRecallEligible ?? this.productiveRecallEligible,
      qualityVersion: qualityVersion,
      reportCount: reportCount ?? this.reportCount,
    );
  }
}
