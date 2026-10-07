import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LearningGoalStore.resetInstance();
  });

  test('yeni kullanıcıda seçim yoktur ve mevcut davranış korunur', () async {
    final store = await LearningGoalStore.load();

    expect(store.goal, isNull);
  });

  test('öğrenme amacı sonraki yüklemede kalıcıdır', () async {
    final store = await LearningGoalStore.load();
    await store.save(LearningGoal.discoverCulture);
    LearningGoalStore.resetInstance();

    final reloaded = await LearningGoalStore.load();
    expect(reloaded.goal, LearningGoal.discoverCulture);
  });

  test('bozuk kayıt seçim yapılmamış gibi ele alınır', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.learning_goal.v1': 'unknown',
    });

    final store = await LearningGoalStore.load();
    expect(store.goal, isNull);
  });
}
