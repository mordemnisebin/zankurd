import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.dark(), home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryProgressStore.resetInstance();
  });

  testWidgets('hikâye açılır ve seçim sonraki düğüme dallanır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
    );
    await tester.pumpAndSettle();

    // Başlangıç düğümü metni
    expect(find.byKey(const ValueKey('story-text-ku')), findsOneWidget);
    // İlk seçime dokun (-> tea)
    await tester.tap(find.text('Bir çay, lütfen.'));
    await tester.pumpAndSettle();
    // "tea" düğümünün TR metni görünür
    expect(find.textContaining('Şeker ister misin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bir yolu tamamlayınca yeniden oynatma çıkar', (tester) async {
    await tester.pumpWidget(wrap(StoryScreen(story: cayxaneStory)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bir çay, lütfen.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evet, teşekkürler.'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-ending-restart')), findsOneWidget);
  });

  testWidgets('mini rehber açılabilir', (tester) async {
    await tester.pumpWidget(
      wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-open-guide')));
    await tester.pumpAndSettle();
    expect(find.text('Yeni kelimeler'), findsOneWidget);
    expect(find.text('Derse başla'), findsOneWidget);
  });

  testWidgets('yeniden başlatma başa döner', (tester) async {
    await tester.pumpWidget(wrap(StoryScreen(story: cayxaneStory)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bir çay, lütfen.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-restart')));
    await tester.pumpAndSettle();
    // Başlangıç seçimi tekrar görünür
    expect(find.text('Bir çay, lütfen.'), findsOneWidget);
  });

  testWidgets('tablet boyutunda overflow oluşmaz', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
