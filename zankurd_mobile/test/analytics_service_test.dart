import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    test('singleton örneği çalışır', () {
      final a = AnalyticsService.instance;
      final b = AnalyticsService.instance;
      expect(identical(a, b), true);
    });

    test('logEvent hatasız çalışır', () async {
      await AnalyticsService.instance.logEvent('test_event', {'key': 'value'});
    });

    test('logQuizStart hatasız çalışır', () async {
      await AnalyticsService.instance.logQuizStart(
        category: 'Ziman',
        mode: 'quick_race',
      );
    });

    test('logQuizComplete hatasız çalışır', () async {
      await AnalyticsService.instance.logQuizComplete(
        category: 'Çand',
        correctCount: 8,
        totalQuestions: 10,
        xpEarned: 150,
      );
    });

    test('logBadgeEarned hatasız çalışır', () async {
      await AnalyticsService.instance.logBadgeEarned('streak_30');
    });

    test('logLanguageChange hatasız çalışır', () async {
      await AnalyticsService.instance.logLanguageChange('ku');
    });

    test('logThemeChange hatasız çalışır', () async {
      await AnalyticsService.instance.logThemeChange('dark');
    });
  });
}
