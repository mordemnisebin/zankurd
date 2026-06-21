import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/review_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewService.resetInstance();
    // Mağaza her zaman mevcut + çağrı sayacı.
    ReviewService.availabilityCheck = () async => true;
    ReviewService.requestReviewFn = () async {};
  });

  test('eşik altında istemez', () async {
    final service = await ReviewService.load();
    // 4 quiz (eşik 5), hep yüksek skor
    for (var i = 0; i < 4; i++) {
      final requested = await service.recordQuizCompletion(accuracyPercent: 90);
      expect(requested, false);
    }
    expect(service.completedQuizzes, 4);
  });

  test('eşik üstü + yüksek skor ile bir kez ister', () async {
    final service = await ReviewService.load();
    bool? fifth;
    for (var i = 0; i < 5; i++) {
      fifth = await service.recordQuizCompletion(accuracyPercent: 80);
    }
    expect(fifth, true);
    expect(service.alreadyRequested, true);
  });

  test('eşik üstü ama düşük skor ile istemez', () async {
    final service = await ReviewService.load();
    bool? last;
    for (var i = 0; i < 6; i++) {
      last = await service.recordQuizCompletion(accuracyPercent: 50);
    }
    expect(last, false);
    expect(service.alreadyRequested, false);
  });

  test('bir kez istendikten sonra tekrar istemez', () async {
    final service = await ReviewService.load();
    for (var i = 0; i < 5; i++) {
      await service.recordQuizCompletion(accuracyPercent: 90);
    }
    final again = await service.recordQuizCompletion(accuracyPercent: 95);
    expect(again, false);
  });

  test('mağaza uygun değilse istemez ve requested kalmaz', () async {
    ReviewService.availabilityCheck = () async => false;
    final service = await ReviewService.load();
    bool? last;
    for (var i = 0; i < 5; i++) {
      last = await service.recordQuizCompletion(accuracyPercent: 90);
    }
    expect(last, false);
    expect(service.alreadyRequested, false);
  });

  test('tamamlanan quiz sayısı kalıcıdır', () async {
    final service = await ReviewService.load();
    await service.recordQuizCompletion(accuracyPercent: 30);
    await service.recordQuizCompletion(accuracyPercent: 30);
    ReviewService.resetInstance();
    final reloaded = await ReviewService.load();
    expect(reloaded.completedQuizzes, 2);
  });
}
