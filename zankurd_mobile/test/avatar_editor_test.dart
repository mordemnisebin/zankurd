import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

class _RecordingRepo extends MockZanKurdRepository {
  AvatarIdentity? saved;

  @override
  Future<void> updateAvatarIdentity(AvatarIdentity identity) async {
    saved = identity;
    await super.updateAvatarIdentity(identity);
  }
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    AchievementStore.resetInstance();
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(finder),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
  }

  Widget shell(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );

  testWidgets('ikon seçimi önizlemeye yansır ve kaydedilir', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(shell(AvatarEditorScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('avatar-icon-newroz')));
    await tester.pumpAndSettle();

    final preview = tester.widget<PlayerAvatar>(
      find.byKey(const ValueKey('avatar-preview')),
    );
    expect(preview.iconId, 'newroz');

    await scrollTo(tester, find.byKey(const ValueKey('avatar-save')));
    await tester.tap(find.byKey(const ValueKey('avatar-save')));
    await tester.pumpAndSettle();

    expect(repo.saved?.iconId, 'newroz');
  });

  testWidgets('kilitli çerçeve seçilemez, kilit uyarısı gösterilir', (
    tester,
  ) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(shell(AvatarEditorScreen(repository: repo)));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('avatar-frame-gold')));
    await tester.tap(find.byKey(const ValueKey('avatar-frame-gold')));
    await tester.pump();

    expect(find.textContaining('Kilitli'), findsOneWidget);

    // Kilitli seçim kaydedilen kimliğe sızmamalı.
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('avatar-save')));
    await tester.tap(find.byKey(const ValueKey('avatar-save')));
    await tester.pumpAndSettle();
    expect(repo.saved?.frameId, isNull);
  });

  testWidgets('kazanılmış mastery unvanı listelenir ve seçilebilir', (
    tester,
  ) async {
    // Ziman'da Pispor eşiği (100) aşılmış olsun.
    SharedPreferences.setMockInitialValues({'zankurd.mastery.Ziman': 120});
    MasteryStore.resetInstance();

    final repo = _RecordingRepo();
    await tester.pumpWidget(shell(AvatarEditorScreen(repository: repo)));
    await tester.pumpAndSettle();

    final titleKey = const ValueKey('avatar-title-Pispor · Ziman');
    await scrollTo(tester, find.byKey(titleKey));
    await tester.tap(find.byKey(titleKey));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('avatar-save')));
    await tester.tap(find.byKey(const ValueKey('avatar-save')));
    await tester.pumpAndSettle();

    expect(repo.saved?.showcaseTitle, 'Pispor · Ziman');
  });

  testWidgets('unvan yokken bilgilendirme metni görünür', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(shell(AvatarEditorScreen(repository: repo)));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Henüz unvan yok'));
    expect(find.textContaining('Henüz unvan yok'), findsOneWidget);
  });
}
