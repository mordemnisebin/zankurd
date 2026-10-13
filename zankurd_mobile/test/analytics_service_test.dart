import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/analytics_service.dart';

/// Analytics sarmalayıcıları gerçek olay adını gönderir.
///
/// ## Kusur
///
/// `logEvent`, `logQuizStart` ve kardeşleri "hatasız çalışır" diye
/// adlandırılmış testlerle korunuyordu. Testler `expect` içermiyordu;
/// yöntem fırlatmazsa yeşil kalıyordu. Firebase testte yok (`_analytics`
/// null), yani olay adı hiç doğrulanmıyordu. `quiz_start` `quizStart`
/// olsa da CI aynı yeşili basardı.
///
/// ## Niçin sessiz kaldı
///
/// Bekçi yalnız istisna yokluğunu ölçüyordu. Üretim yolu `debugPrint`
/// + isteğe bağlı Firebase; test koşusunda ikincisi bağlı değil, birincisi
/// de assertion değil. Ad değişse, parametre düşse, sarmalayıcı boş gövde
/// olsa kimse duymazdı.
class _FakeAnalyticsRecorder {
  final names = <String>[];

  void record(String name, Map<String, Object>? parameters) {
    names.add(name);
  }
}

void main() {
  group('AnalyticsService', () {
    late _FakeAnalyticsRecorder recorder;

    setUp(() {
      recorder = _FakeAnalyticsRecorder();
      AnalyticsService.instance.debugEventSink = recorder.record;
    });

    tearDown(() {
      AnalyticsService.instance.debugEventSink = null;
    });

    test('singleton örneği çalışır', () {
      final a = AnalyticsService.instance;
      final b = AnalyticsService.instance;
      expect(identical(a, b), true);
    });

    test('logEvent hatasız çalışır', () async {
      await AnalyticsService.instance.logEvent('test_event', {'key': 'value'});
      expect(recorder.names, ['test_event']);
    });

    test('logQuizStart hatasız çalışır', () async {
      await AnalyticsService.instance.logQuizStart(
        category: 'Ziman',
        mode: 'quick_race',
      );
      expect(recorder.names, ['quiz_start']);
    });

    test('logQuizComplete hatasız çalışır', () async {
      await AnalyticsService.instance.logQuizComplete(
        category: 'Çand',
        correctCount: 8,
        totalQuestions: 10,
        xpEarned: 150,
      );
      expect(recorder.names, ['quiz_complete']);
    });

    test('logBadgeEarned hatasız çalışır', () async {
      await AnalyticsService.instance.logBadgeEarned('streak_30');
      expect(recorder.names, ['badge_earned']);
    });

    test('logLanguageChange hatasız çalışır', () async {
      await AnalyticsService.instance.logLanguageChange('ku');
      expect(recorder.names, ['language_change']);
    });

    test('logThemeChange hatasız çalışır', () async {
      await AnalyticsService.instance.logThemeChange('dark');
      expect(recorder.names, ['theme_change']);
    });

    test('logMatchmakingWait hassas veri olmadan hatasız çalışır', () async {
      await AnalyticsService.instance.logMatchmakingWait(
        outcome: 'human',
        waitSeconds: 12,
      );
      expect(recorder.names, ['matchmaking_wait']);
    });

    test('premium hunisi olayları hatasız çalışır', () async {
      await AnalyticsService.instance.logPurchaseOutcome(
        packageId: 'monthly',
        outcome: 'success',
      );
      await AnalyticsService.instance.logRestoreOutcome('nothingFound');
      expect(recorder.names, ['purchase_outcome', 'restore_outcome']);
    });
  });
}
