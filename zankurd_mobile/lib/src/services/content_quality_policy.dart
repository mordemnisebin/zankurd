import '../models/question_metadata.dart';

/// Son kullanıcı quizinde hangi soruların uygun olduğuna karar veren, saf ve
/// açık içerik-kalite politikası.
///
/// Tasarım ilkesi: mevcut (doğrulanmamış) içeriği görünmez YAPMAMAK. Yalnız
/// açıkça `rejected` işaretli sorular elenir; `null`/`draft`/`approved`/
/// `needsReview` hepsi oynanabilir kabul edilir. Bu, "yalnız approved zorunlu
/// tut" katı modunun offline bankayı boşaltmasını önler. Katı mod ileride
/// [requireApproved] ile açılabilir (varsayılan kapalı).
class ContentQualityPolicy {
  const ContentQualityPolicy({
    this.requireApproved = false,
    this.reportThreshold = 5,
  });

  /// Açıksa yalnız `approved` sorular uygundur (offline içeriği gizleyebilir —
  /// bilinçli olarak varsayılan kapalı).
  final bool requireApproved;

  /// Bu kadar (veya daha fazla) rapor alan soru `needsReview` sayılır.
  final int reportThreshold;

  /// Soru son kullanıcı quizinde gösterilebilir mi?
  bool isEligible(QuestionMetadata? metadata) {
    final meta = metadata ?? const QuestionMetadata();
    if (meta.reviewStatus == ReviewStatus.rejected) return false;
    if (requireApproved) {
      return meta.reviewStatus == ReviewStatus.approved;
    }
    return true;
  }

  /// Rapor sayısı eşiğe ulaşmış mı? (çok bildirilen soru)
  bool isOverReported(QuestionMetadata? metadata) {
    final meta = metadata ?? const QuestionMetadata();
    return meta.reportCount >= reportThreshold;
  }

  /// Kullanıcı bildirimini uygular: rapor sayısını artırır ve eşik aşılırsa
  /// durumu `needsReview`'e çeker (zaten rejected/approved-üstü değilse).
  /// Mevcut report mekanizmasıyla uyumlu, yan etkisiz saf dönüşüm.
  QuestionMetadata applyReport(QuestionMetadata? metadata) {
    final meta = metadata ?? const QuestionMetadata();
    final nextCount = meta.reportCount + 1;
    final shouldFlag =
        nextCount >= reportThreshold &&
        meta.reviewStatus != ReviewStatus.rejected;
    return meta.copyWith(
      reportCount: nextCount,
      reviewStatus: shouldFlag ? ReviewStatus.needsReview : meta.reviewStatus,
    );
  }
}
