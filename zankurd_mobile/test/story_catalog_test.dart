import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/story_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryProgressStore.resetInstance();
  });

  testWidgets('katalog dört hikâyeyi ve başlanmamış durumunu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-catalog')), findsOneWidget);
    for (final story in everydayStories) {
      expect(find.byKey(ValueKey('story-card-${story.id}')), findsOneWidget);
    }
    expect(find.text('Başla'), findsNWidgets(4));
  });

  testWidgets('katalog kayıtlı hikâyeyi devam, bitişi tamamlandı gösterir', (
    tester,
  ) async {
    final store = await StoryProgressStore.load();
    await store.saveNode('cayxane', 'tea');
    await store.saveNode('xwe-nasandin', 'end_friend');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devam et'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('Başla'), findsNWidgets(2));
  });
}
