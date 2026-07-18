import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'support/widget_test_helpers.dart';

class _SignOutTrackingAuthProvider extends AuthProvider {
  _SignOutTrackingAuthProvider() : super.test();

  bool _authenticated = true;
  int signOutCalls = 0;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => false;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _authenticated = false;
    notifyListeners();
  }
}

class _DeleteTrackingRepository extends MockZanKurdRepository {
  _DeleteTrackingRepository({this.shouldFail = false});

  final bool shouldFail;
  int deleteCalls = 0;

  @override
  Future<void> deleteMyAccount() async {
    deleteCalls += 1;
    if (shouldFail) {
      throw StateError('delete failed');
    }
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('settings does not delete account before final confirmation', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Hesabı kalıcı olarak sil?'), findsOneWidget);
    expect(repository.deleteCalls, 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
  });

  testWidgets('settings separates dangerous account actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: _DeleteTrackingRepository())),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hesap İşlemleri'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap İşlemleri'), findsOneWidget);
    expect(find.text('Bu alandaki işlemler geri alınamaz.'), findsOneWidget);
    expect(find.text('Hesabımı Sil'), findsOneWidget);
  });

  testWidgets('settings shows the package version in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: themeMode),
          child: SettingsScreen(
            repository: repository,
            packageInfoLoader: () async => PackageInfo(
              appName: 'ZanKurd',
              packageName: 'com.zankurd.app',
              version: '9.8.7',
              buildNumber: '654',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sürüm 9.8.7+654'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final versionText = find.text('Sürüm 9.8.7+654');
      expect(versionText, findsOneWidget);
      expect(
        Theme.of(tester.element(versionText)).brightness,
        themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('settings uses a neutral version when package info fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(
          repository: repository,
          packageInfoLoader: () async => throw StateError('unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Sürüm —'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sürüm —'), findsOneWidget);
    expect(find.textContaining('1.8.0+10'), findsNothing);
  });

  testWidgets('successful account deletion signs out to the auth gate', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı Olarak Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(authProvider.signOutCalls, 1);
  });

  testWidgets('failed account deletion keeps the user in settings', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository(shouldFail: true);
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı Olarak Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(
      find.text('Hesap silinemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });
}
