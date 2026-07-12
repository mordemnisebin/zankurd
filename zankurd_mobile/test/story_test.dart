import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story dallanma', () {
    test('başlangıç düğümü ve seçimler doğru', () {
      final story = cayxaneStory;
      expect(story.start.id, 'start');
      expect(story.start.choices.length, 2);
      expect(story.start.isEnding, isFalse);
    });

    test('seçim izleyince doğru sonraki düğüme gider', () {
      final story = cayxaneStory;
      final choice = story.start.choices.first; // -> tea
      final next = story.follow(story.start, choice);
      expect(next, isNotNull);
      expect(next!.id, 'tea');
    });

    test('geçersiz node id güvenle null döner', () {
      expect(cayxaneStory.node('yok-boyle-node'), isNull);
      expect(cayxaneStory.node(null), isNull);
    });

    test('yabancı seçim ile follow null döner (koruma)', () {
      final story = cayxaneStory;
      const alien = StoryChoice(labelKu: 'x', labelTr: 'x', nextNodeId: 'tea');
      expect(story.follow(story.start, alien), isNull);
    });

    test('bir yol tamamlanabilir (bitiş düğümüne ulaşılır)', () {
      final story = cayxaneStory;
      var node = story.start;
      var guard = 0;
      while (!node.isEnding && guard < 20) {
        node = story.follow(node, node.choices.first)!;
        guard++;
      }
      expect(node.isEnding, isTrue);
    });
  });

  group('StoryProgressStore devam/yeniden başlatma', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StoryProgressStore.resetInstance();
    });

    test('başlanmamış hikâye null döner', () async {
      final store = await StoryProgressStore.load();
      expect(store.currentNodeId('cayxane'), isNull);
    });

    test('düğüm kaydı devam ettirilebilir (kalıcı)', () async {
      final store = await StoryProgressStore.load();
      await store.saveNode('cayxane', 'tea');
      expect(store.currentNodeId('cayxane'), 'tea');

      StoryProgressStore.resetInstance();
      final reloaded = await StoryProgressStore.load();
      expect(reloaded.currentNodeId('cayxane'), 'tea');
    });

    test('yeniden başlatma ilerlemeyi siler', () async {
      final store = await StoryProgressStore.load();
      await store.saveNode('cayxane', 'end_warm');
      await store.restart('cayxane');
      expect(store.currentNodeId('cayxane'), isNull);
    });
  });

  group('MiniGuide içeriği', () {
    test('rehber tüm bölümleri taşır', () {
      const g = cayxaneGuide;
      expect(g.newWords, isNotEmpty);
      expect(g.examples.length, 2);
      expect(g.grammarKu, isNotEmpty);
      expect(g.cultureTr, isNotEmpty);
    });
  });
}
