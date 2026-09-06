import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story dallanma', () {
    test('günlük yaşam kataloğu sabit ve benzersiz dört hikâye taşır', () {
      expect(everydayStories.map((story) => story.id), [
        'cayxane',
        'xwe-nasandin',
        'kirin',
        'rê-pirsîn',
      ]);
      expect(everydayStories.map((story) => story.id).toSet().length, 4);
    });

    test('her günlük hikâyede bağlama özgü dallanma ve bitiş vardır', () {
      for (final story in everydayStories.skip(1)) {
        expect(story.start.choices.length, greaterThanOrEqualTo(2));
        expect(
          story.nodes.where((node) => node.isEnding).length,
          greaterThanOrEqualTo(2),
          reason: story.id,
        );
        expect(
          story.start.choices.map((choice) => choice.feedbackTr).toSet().length,
          story.start.choices.length,
          reason: '${story.id} başlangıç geri bildirimleri yinelenmemeli',
        );
        for (final node in story.nodes.where((node) => !node.isEnding)) {
          for (final choice in node.choices) {
            expect(
              choice.feedbackKu,
              isNotEmpty,
              reason: '${story.id}/${node.id}',
            );
            expect(
              choice.feedbackTr,
              isNotEmpty,
              reason: '${story.id}/${node.id}',
            );
          }
        }
      }
    });

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

    test('hesap çıkışında tüm hikâye ilerlemesi temizlenir', () async {
      final store = await StoryProgressStore.load();
      await store.saveNode('cayxane', 'tea');
      await store.saveNode('bazaar', 'entry');

      await store.clear();

      expect(store.currentNodeId('cayxane'), isNull);
      expect(store.currentNodeId('bazaar'), isNull);
    });
  });

  group('MiniGuide içeriği', () {
    test('her günlük hikâyenin dolu ve eşleşen mini rehberi vardır', () {
      expect(everydayGuides.keys, {
        'cayxane',
        'xwe-nasandin',
        'kirin',
        'rê-pirsîn',
      });
      for (final story in everydayStories) {
        final guide = everydayGuides[story.id];
        expect(guide, isNotNull, reason: story.id);
        expect(guide!.newWords.length, greaterThanOrEqualTo(3));
        expect(guide.examples.length, 2);
      }
    });

    test('rehber tüm bölümleri taşır', () {
      const g = cayxaneGuide;
      expect(g.newWords, isNotEmpty);
      expect(g.examples.length, 2);
      expect(g.grammarKu, isNotEmpty);
      expect(g.cultureTr, isNotEmpty);
    });
  });
}
