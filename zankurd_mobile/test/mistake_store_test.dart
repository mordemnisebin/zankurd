import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MistakeStore.resetInstance();
  });

  test('wrong answers are stored once', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');
    await store.markMistake('q1');
    await store.markMistake('q2');
    expect(store.count, 2);
    expect(store.contains('q1'), isTrue);
  });

  test('correct answer resolves the mistake', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');
    await store.markResolved('q1');
    expect(store.count, 0);
  });

  test('mistakes persist across instances', () async {
    final store = await MistakeStore.load();
    await store.markMistake('q1');

    MistakeStore.resetInstance();
    final restored = await MistakeStore.load();
    expect(restored.contains('q1'), isTrue);
  });
}
