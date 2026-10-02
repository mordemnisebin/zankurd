import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform originalStore;

  setUp(() {
    originalStore = SharedPreferencesStorePlatform.instance;
    LocalProgressScope.debugReset();
    LearningGoalStore.resetInstance();
    AnalyticsConsentProvider.isEnabled = false;
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalStore;
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    LearningGoalStore.resetInstance();
    AnalyticsConsentProvider.isEnabled = false;
  });

  for (final throwsError in [false, true]) {
    test(
      'analytics write failure ($throwsError) UI state değiştirmez',
      () async {
        final disk = _FailingWriteStore(
          {'flutter.zankurd.analyticsConsent': false},
          'flutter.zankurd.analyticsConsent',
          throwsError,
        );
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = disk;
        final provider = await AnalyticsConsentProvider.load();

        expect(await provider.setEnabled(true), isFalse);
        expect(provider.enabled, isFalse);
        expect(AnalyticsConsentProvider.isEnabled, isFalse);
        expect(disk.values['flutter.zankurd.analyticsConsent'], isFalse);
      },
    );

    test(
      'learning goal write failure ($throwsError) eski hedefi korur',
      () async {
        final disk = _FailingWriteStore(
          {'flutter.zankurd.learning_goal.v1': 'learn_kurmanci'},
          'flutter.zankurd.learning_goal.v1',
          throwsError,
        );
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = disk;
        final store = await LearningGoalStore.load();

        expect(store.goal, LearningGoal.learnKurmanci);
        expect(await store.save(LearningGoal.discoverCulture), isFalse);
        expect(store.goal, LearningGoal.learnKurmanci);
        LearningGoalStore.resetInstance();
        expect(
          (await LearningGoalStore.load()).goal,
          LearningGoal.learnKurmanci,
        );
      },
    );
  }
}

class _FailingWriteStore extends SharedPreferencesStorePlatform {
  _FailingWriteStore(this.values, this.failingKey, this.throwsError);

  final Map<String, Object> values;
  final String failingKey;
  final bool throwsError;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == failingKey) {
      if (throwsError) {
        throw PlatformException(code: 'injected_write_failure');
      }
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}
