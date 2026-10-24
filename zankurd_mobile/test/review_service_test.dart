import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/review_service.dart';

/// Puanlama isteği: 2026-10-21 simülatör düğme turunda ilk 5/5 kısa testin
/// hemen ardından iOS penceresi öğrenme akışını kesti. Kusur sessizdi çünkü
/// koşul yalnız tur sayısıydı (gün sayısı yok) ve istek tur kaydı sırasında,
/// sonuç ekranı açıkken yapılıyordu. Bu dosya ikisini de bekler.
void main() {
  var asked = 0;
  final day1 = DateTime(2026, 10, 20, 12);
  final day2 = DateTime(2026, 10, 21, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewService.resetInstance();
    asked = 0;
    ReviewService.availabilityCheck = () async => true;
    ReviewService.requestReviewFn = () async => asked++;
  });

  test('kayıt anında asla istemez (pencere turun içinde açılmaz)', () async {
    final service = await ReviewService.load();
    for (var i = 0; i < 6; i++) {
      await service.recordQuizCompletion(
        accuracyPercent: 100,
        now: i.isEven ? day1 : day2,
      );
    }
    expect(asked, 0);
    expect(service.alreadyRequested, false);
  });

  test('ilk oturum: aynı gün 5 tur dolsa da istemez', () async {
    final service = await ReviewService.load();
    for (var i = 0; i < 5; i++) {
      await service.recordQuizCompletion(accuracyPercent: 100, now: day1);
    }
    expect(await service.requestIfDue(), false);
    expect(asked, 0);
  });

  test('3 tur + 2 farklı gün + yüksek skor: dönüşte bir kez ister', () async {
    final service = await ReviewService.load();
    await service.recordQuizCompletion(accuracyPercent: 90, now: day1);
    await service.recordQuizCompletion(accuracyPercent: 90, now: day1);
    await service.recordQuizCompletion(accuracyPercent: 90, now: day2);
    expect(await service.requestIfDue(), true);
    expect(asked, 1);
    expect(service.alreadyRequested, true);
    await service.recordQuizCompletion(accuracyPercent: 95, now: day2);
    expect(await service.requestIfDue(), false);
    expect(asked, 1);
  });

  test('2 tur yetmez', () async {
    final service = await ReviewService.load();
    await service.recordQuizCompletion(accuracyPercent: 90, now: day1);
    await service.recordQuizCompletion(accuracyPercent: 90, now: day2);
    expect(await service.requestIfDue(), false);
  });

  test('düşük skor ile istemez', () async {
    final service = await ReviewService.load();
    for (var i = 0; i < 4; i++) {
      await service.recordQuizCompletion(
        accuracyPercent: 50,
        now: i.isEven ? day1 : day2,
      );
    }
    expect(await service.requestIfDue(), false);
    expect(service.alreadyRequested, false);
  });

  test('mağaza uygun değilse istemez ve requested kalmaz', () async {
    ReviewService.availabilityCheck = () async => false;
    final service = await ReviewService.load();
    for (var i = 0; i < 4; i++) {
      await service.recordQuizCompletion(
        accuracyPercent: 90,
        now: i.isEven ? day1 : day2,
      );
    }
    expect(await service.requestIfDue(), false);
    expect(service.alreadyRequested, false);
  });

  test('tur sayısı ve günler kalıcıdır', () async {
    final service = await ReviewService.load();
    await service.recordQuizCompletion(accuracyPercent: 30, now: day1);
    await service.recordQuizCompletion(accuracyPercent: 30, now: day2);
    ReviewService.resetInstance();
    final reloaded = await ReviewService.load();
    expect(reloaded.completedQuizzes, 2);
    expect(reloaded.distinctDays, 2);
  });
}
