import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';
import 'support/widget_test_helpers.dart';

class _SignOutTrackingAuthProvider extends AuthProvider {
  _SignOutTrackingAuthProvider() : super.test();

  bool _authenticated = true;
  int signOutCalls = 0;
  bool? discardPendingRewards;
  String? discardedRewardsOwnerId;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => false;

  @override
  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    signOutCalls += 1;
    this.discardPendingRewards = discardPendingRewards;
    discardedRewardsOwnerId = pendingRewardsOwnerId;
    _authenticated = false;
    notifyListeners();
  }
}

class _CleanupFailingAuthProvider extends _SignOutTrackingAuthProvider {
  @override
  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    await super.signOut(
      discardPendingRewards: discardPendingRewards,
      pendingRewardsOwnerId: pendingRewardsOwnerId,
    );
    throw const AccountLocalCleanupException();
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

class _DeferredDeleteRepository extends _DeleteTrackingRepository {
  final Completer<void> deleteStarted = Completer<void>();
  final Completer<void> allowDelete = Completer<void>();

  @override
  Future<void> deleteMyAccount() async {
    deleteCalls += 1;
    deleteStarted.complete();
    await allowDelete.future;
  }
}

/// Hesap silme kartı 2026-07-22 UX denetiminden sonra ayarların en altına
/// taşındı (en yıkıcı eylem en üstte duruyordu). Testler artık ona
/// kaydırarak ulaşır.
Future<Finder> _scrollToDeleteAction(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('delete-account-action'));
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return finder.first;
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

    final deleteAction = await _scrollToDeleteAction(tester);
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

    await _scrollToDeleteAction(tester);
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

    final deleteAction = await _scrollToDeleteAction(tester);
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
    expect(authProvider.discardPendingRewards, isTrue);
    expect(authProvider.discardedRewardsOwnerId, 'user');
  });

  testWidgets('deleted account reports local cleanup failure accurately', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    final authProvider = _CleanupFailingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
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
    expect(find.textContaining('Hesap silindi ancak'), findsOneWidget);
    expect(find.textContaining('Hesap silinemedi'), findsNothing);
  });

  testWidgets('failed account deletion keeps the user in settings', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository(shouldFail: true);
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

    final deleteAction = await _scrollToDeleteAction(tester);
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
    expect(authProvider.signOutCalls, 0);
    expect(authProvider.discardPendingRewards, isNull);
    // Silme başarısızsa ekrandan çıkılmamalı. Bu, "Ayarlar" metnini arayarak
    // doğrulanıyordu; başlık AppBar'dan kimlik kartına taşınınca (çift
    // başlık düzeltmesi) metin, listeyle birlikte kaydırılıp ağaçtan
    // düşebiliyor. Asıl iddia gezinme: ekran hâlâ yerinde mi?
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Hesap silinemedi. Lütfen tekrar dene.'), findsOneWidget);
  });

  testWidgets('account cleanup continues if settings unmounts after deletion', (
    tester,
  ) async {
    final repository = _DeferredDeleteRepository();
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(repository: repository),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
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
    await repository.deleteStarted.future;

    await tester.tap(find.byType(ZkBackButton));
    await tester.pumpAndSettle();
    repository.allowDelete.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(authProvider.signOutCalls, 1);
    expect(authProvider.discardPendingRewards, isTrue);
    expect(authProvider.discardedRewardsOwnerId, 'user');
  });

  testWidgets('Kurmancî arayüzde oyuncu adı yer tutucusu çevrilir', (
    tester,
  ) async {
    // Depo, gerçek bir seçim olmayan `ZanKurd Oyuncusu` yer tutucusunu
    // döndürür. Diğer ekranlar bunu `PlayerIdentity` üzerinden dile
    // çevirir; ayarlar ekranı ham değeri kutuya yazıyor ve Kurmancî
    // arayüzde oyuncu kendi adını Türkçe görüyordu (2026-07-26).
    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: MockZanKurdRepository()),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ZanKurd Oyuncusu'), findsNothing);
    expect(find.text('Lîstikvan'), findsOneWidget);
  });

  testWidgets('Türkçe arayüzde yer tutucu Türkçe karşılığını alır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Oyuncu'), findsOneWidget);
  });
}
