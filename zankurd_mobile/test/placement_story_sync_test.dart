import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';

/// Seviye sınavı ve hikâye "yeniden başla" eşitlemede geri alınmasın.
///
/// ## Kusur
///
/// * Sınav: birleştirme "en yüksek seviye" diyordu. Kullanıcı sınavı
///   yeniden çözüp daha DÜŞÜK seviyeye inince eşitleme uzaktaki yüksek
///   seviyeyi yerele geri yazıyordu.
/// * Hikâye: "yeniden başlat" yerel anahtarı siliyordu; birleştirme
///   `{...uzak, ...yerel}` olduğundan silinmiş kayıt uzaktakiyle doldu ve
///   ilerleme geri geldi. "Yeniden oyna" bitiş ✓ işaretini de siliyordu.
///
/// ## Niçin sessizdi
///
/// İki kural da kendi içinde tutarlıydı ve tek cihazda hiçbir şey bozuk
/// görünmezdi; hata yalnız yerel ile uzağın ayrıştığı ikinci eşitlemede,
/// kullanıcının kararı sessizce eski hâline dönerek ortaya çıkıyordu.
ProgressSnapshot _s({
  String? placement,
  bool skipped = false,
  int? placementAt,
  Map<String, String> story = const {},
  Map<String, int> storyAt = const {},
  Set<String> done = const {},
}) => ProgressSnapshot(
  placementLevel: placement,
  placementSkipped: skipped,
  placementUpdatedAt: placementAt,
  story: story,
  storyUpdatedAt: storyAt,
  storyDone: done,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('birleştirme: seviye sınavı', () {
    test('zamanlı: en son yazan kazanır (düşük seviyeye yeniden sınav)', () {
      final local = _s(placement: 'destpek', placementAt: 200);
      final remote = _s(placement: 'pesketi', placementAt: 100);
      final m = ProgressSnapshot.merge(local, remote);
      expect(m.placementLevel, 'destpek');
      expect(m.placementUpdatedAt, 200);
      // Simetrik.
      expect(ProgressSnapshot.merge(remote, local).placementLevel, 'destpek');
    });

    test('zamansız (eski v1 veri): en yüksek seviye kuralı sürer', () {
      expect(
        ProgressSnapshot.merge(
          _s(placement: 'destpek'),
          _s(placement: 'pesketi'),
        ).placementLevel,
        'pesketi',
      );
      expect(
        ProgressSnapshot.merge(
          _s(placement: 'destpek', placementAt: 500),
          _s(placement: 'pesketi'),
        ).placementLevel,
        'pesketi',
      );
    });

    test('daha yeni "geç" eski seviyeyi ezmez ama seviyesizi geçer', () {
      final m = ProgressSnapshot.merge(
        _s(skipped: true, placementAt: 300),
        _s(placementAt: 100),
      );
      expect(m.placementSkipped, isTrue);
      expect(m.placementLevel, isNull);
    });

    test('alan JSON gidiş-dönüşünde korunur, eski JSON okunur', () {
      final snap = _s(placement: 'navin', placementAt: 42);
      expect(ProgressSnapshot.tryParse(snap.toJson())!.placementUpdatedAt, 42);
      final old = ProgressSnapshot.tryParse({
        'v': 1,
        'placementLevel': 'navin',
        'story': {'a': 'n'},
      })!;
      expect(old.placementLevel, 'navin');
      expect(old.placementUpdatedAt, isNull);
      expect(old.story, {'a': 'n'});
      expect(old.storyDone, isEmpty);
    });
  });

  group('birleştirme: hikâye', () {
    test('zamanlı yeniden başlatma uzaktaki eski ilerlemeyi yener', () {
      final local = _s(story: {'s': 'start'}, storyAt: {'s': 200});
      final remote = _s(story: {'s': 'n7'}, storyAt: {'s': 100});
      final m = ProgressSnapshot.merge(local, remote);
      expect(m.story['s'], 'start');
      expect(m.storyUpdatedAt['s'], 200);
      expect(ProgressSnapshot.merge(remote, local).story['s'], 'start');
    });

    test('zamansız eski kayıtta yerel kazanır; yerelde yoksa uzak gelir', () {
      final m = ProgressSnapshot.merge(
        _s(story: {'s1': 'n3'}),
        _s(story: {'s1': 'n1', 's2': 'n9'}),
      );
      expect(m.story, {'s1': 'n3', 's2': 'n9'});
    });

    test('bitirildi kümesi birleşimdir', () {
      final m = ProgressSnapshot.merge(_s(done: {'a'}), _s(done: {'b'}));
      expect(m.storyDone, {'a', 'b'});
      expect(_s(done: {'a'}).isEmpty, isFalse);
    });
  });

  group('depo ve yerel yazım', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PlacementStore.resetInstance();
      StoryProgressStore.resetInstance();
    });

    test(
      'PlacementStore saveResult ve markSkipped zaman damgası yazar',
      () async {
        final store = await PlacementStore.load();
        await store.saveResult(PlacementLevel.navin);
        final prefs = await SharedPreferences.getInstance();
        expect(LocalProgressSnapshot.read(prefs).placementUpdatedAt, isNotNull);
        expect(LocalProgressSnapshot.read(prefs).placementLevel, 'navin');
      },
    );

    test('hikâye yeniden başlatma kaydı siler değil, başa yazar', () async {
      final store = await StoryProgressStore.load();
      await store.saveNode('s', 'n7');
      await store.markCompleted('s');
      await store.restart('s', 'start');

      final prefs = await SharedPreferences.getInstance();
      final snap = LocalProgressSnapshot.read(prefs);
      expect(snap.story['s'], 'start');
      expect(snap.storyUpdatedAt['s'], isNotNull);
      // Yeniden oyna "bitirildi" işaretini silmez.
      expect(snap.storyDone, {'s'});

      StoryProgressStore.resetInstance();
      final reloaded = await StoryProgressStore.load();
      expect(reloaded.currentNodeId('s'), 'start');
      expect(reloaded.isCompleted('s'), isTrue);
    });

    test(
      'yeniden başlatma, eski uzak kayıtla eşitlenince geri gelmez',
      () async {
        final store = await StoryProgressStore.load();
        await store.saveNode('s', 'n7');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await store.restart('s', 'start');
        final prefs = await SharedPreferences.getInstance();

        final remote = _s(story: {'s': 'n7'}, storyAt: {'s': 1});
        final merged = ProgressSnapshot.merge(
          LocalProgressSnapshot.read(prefs),
          remote,
        );
        await LocalProgressSnapshot.write(prefs, merged);

        StoryProgressStore.resetInstance();
        expect((await StoryProgressStore.load()).currentNodeId('s'), 'start');
      },
    );

    test('düşük seviyeye yeniden sınav eşitlemede geri alınmaz', () async {
      final store = await PlacementStore.load();
      await store.saveResult(PlacementLevel.destpek);
      final prefs = await SharedPreferences.getInstance();

      final remote = _s(placement: 'pesketi', placementAt: 1);
      final merged = ProgressSnapshot.merge(
        LocalProgressSnapshot.read(prefs),
        remote,
      );
      await LocalProgressSnapshot.write(prefs, merged);

      PlacementStore.resetInstance();
      expect((await PlacementStore.load()).level, PlacementLevel.destpek);
    });

    test('clear üst veriyi de siler', () async {
      final store = await StoryProgressStore.load();
      await store.saveNode('s', 'n');
      await store.markCompleted('s');
      await store.clear();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(StoryProgressStore.metaKey), isFalse);
    });
  });
}
