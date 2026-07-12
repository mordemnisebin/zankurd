import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılan kapalı', () async {
    final p = await ReducedMotionProvider.load();
    expect(p.reduceMotion, isFalse);
  });

  test('kullanıcı ayarı kalıcı olur', () async {
    final p = await ReducedMotionProvider.load();
    await p.setUserReduce(true);
    expect(p.reduceMotion, isTrue);

    final reloaded = await ReducedMotionProvider.load();
    expect(reloaded.userReduce, isTrue);
    expect(reloaded.reduceMotion, isTrue);
  });

  test('sistem tercihi tek başına hareketi azaltır', () async {
    final p = await ReducedMotionProvider.load();
    expect(p.reduceMotion, isFalse);
    p.setSystemReduce(true);
    expect(p.reduceMotion, isTrue);
    expect(p.userReduce, isFalse); // kullanıcı ayarı değişmedi
  });

  test('motionDuration hareket azaltınca süreyi kısaltır', () async {
    final p = await ReducedMotionProvider.load();
    const base = Duration(milliseconds: 600);
    expect(p.motionDuration(base), base); // kapalıyken değişmez

    await p.setUserReduce(true);
    expect(p.motionDuration(base), const Duration(milliseconds: 80));
    // Zaten kısa olan süre daha da uzamaz.
    expect(
      p.motionDuration(const Duration(milliseconds: 40)),
      const Duration(milliseconds: 40),
    );
  });

  test('notifyListeners tetiklenir', () async {
    final p = await ReducedMotionProvider.load();
    var count = 0;
    p.addListener(() => count++);
    await p.setUserReduce(true);
    p.setSystemReduce(true);
    expect(count, 2);
  });
}
