import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/models/mastery_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
  });

  group('MasteryLevelDetails.fromCorrectCount', () {
    test(
      '0 → none',
      () => expect(MasteryLevelDetails.fromCorrectCount(0), MasteryLevel.none),
    );
    test(
      '19 → none',
      () => expect(MasteryLevelDetails.fromCorrectCount(19), MasteryLevel.none),
    );
    test(
      '20 → xwendekar',
      () => expect(
        MasteryLevelDetails.fromCorrectCount(20),
        MasteryLevel.xwendekar,
      ),
    );
    test(
      '99 → xwendekar',
      () => expect(
        MasteryLevelDetails.fromCorrectCount(99),
        MasteryLevel.xwendekar,
      ),
    );
    test(
      '100 → pispor',
      () => expect(
        MasteryLevelDetails.fromCorrectCount(100),
        MasteryLevel.pispor,
      ),
    );
    test(
      '399 → pispor',
      () => expect(
        MasteryLevelDetails.fromCorrectCount(399),
        MasteryLevel.pispor,
      ),
    );
    test(
      '400 → mamoste',
      () => expect(
        MasteryLevelDetails.fromCorrectCount(400),
        MasteryLevel.mamoste,
      ),
    );
  });

  group('MasteryStore', () {
    test('yeni kategoride doğru sayısı 0 başlar', () async {
      final store = await MasteryStore.load();
      expect(store.correctCount('Ziman'), 0);
      expect(store.levelFor('Ziman'), MasteryLevel.none);
    });

    test('addCorrect kümülatif sayar', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 10);
      await store.addCorrect('Ziman', 5);
      expect(store.correctCount('Ziman'), 15);
    });

    test('addCorrect seviye atlamamışsa null döner', () async {
      final store = await MasteryStore.load();
      final result = await store.addCorrect('Ziman', 5);
      expect(result, isNull);
    });

    test('addCorrect xwendekar seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 15);
      final result = await store.addCorrect('Ziman', 10);
      expect(result, MasteryLevel.xwendekar);
    });

    test('addCorrect pispor seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 90);
      final result = await store.addCorrect('Ziman', 15);
      expect(result, MasteryLevel.pispor);
    });

    test('addCorrect mamoste seviyesine atlayınca döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 390);
      final result = await store.addCorrect('Ziman', 15);
      expect(result, MasteryLevel.mamoste);
    });

    test('addCorrect zaten mamoste ise null döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 400);
      final result = await store.addCorrect('Ziman', 10);
      expect(result, isNull);
    });

    test('farklı kategoriler bağımsız izlenir', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 25);
      await store.addCorrect('Çand', 5);
      expect(store.correctCount('Ziman'), 25);
      expect(store.correctCount('Çand'), 5);
      expect(store.levelFor('Ziman'), MasteryLevel.xwendekar);
      expect(store.levelFor('Çand'), MasteryLevel.none);
    });

    test('nextThreshold — 19 için 20 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 19);
      expect(store.nextThreshold('Ziman'), 20);
    });

    test('nextThreshold — 25 için 100 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 25);
      expect(store.nextThreshold('Ziman'), 100);
    });

    test('nextThreshold — 450 için 400 döner', () async {
      final store = await MasteryStore.load();
      await store.addCorrect('Ziman', 450);
      expect(store.nextThreshold('Ziman'), 400);
    });

    test('resetInstance testler arası izolasyon sağlar', () async {
      final store1 = await MasteryStore.load();
      await store1.addCorrect('Ziman', 25);

      MasteryStore.resetInstance();
      SharedPreferences.setMockInitialValues({});

      final store2 = await MasteryStore.load();
      expect(store2.correctCount('Ziman'), 0);
    });
  });
}
