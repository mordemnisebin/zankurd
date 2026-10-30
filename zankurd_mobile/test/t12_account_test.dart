import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

class _GuestAuth extends AuthProvider {
  _GuestAuth({this.guest = true}) : super.test();
  final bool guest;
  int signOutCalls = 0;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isGuest => guest;
  @override
  bool get isLoading => false;
  @override
  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    signOutCalls++;
  }
}

Future<void> _profile(WidgetTester tester, _GuestAuth auth) async {
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: ProfileScreen(repository: MockZanKurdRepository())),
      authProvider: auth,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dialog(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Hesabını kaydet'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Hesabını kaydet'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('T12 R24/41/57 parola şartı ilk açılışta ve yazarken >=14pt', (
    tester,
  ) async {
    await _profile(tester, _GuestAuth());
    await _dialog(tester);
    final hint = find.text(Tr.forKu(K.guestAccountRequirements, false));
    expect(hint, findsOneWidget);
    expect(tester.widget<Text>(hint).style!.fontSize, greaterThanOrEqualTo(14));
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.pump();
    expect(hint, findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('guest-upgrade-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('T12 R42/56 parola görünürlüğü metni kaybetmeden değişir', (
    tester,
  ) async {
    await _profile(tester, _GuestAuth());
    await _dialog(tester);
    final password = find.byType(TextField).last;
    await tester.enterText(password, '123456');
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.bySemanticsLabel('Parolayı göster'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(tester.widget<TextField>(password).controller!.text, '123456');
    await tester.tap(find.bySemanticsLabel('Parolayı gizle'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isTrue);
  });

  testWidgets('T12 R23/40/57 mevcut hesap yolu çıkış uyarısı ve iptali korur', (
    tester,
  ) async {
    final auth = _GuestAuth();
    await _profile(tester, auth);
    await _dialog(tester);
    final existing = find.byKey(
      const ValueKey('guest-upgrade-existing-account'),
    );
    expect(existing, findsOneWidget);
    await tester.ensureVisible(existing);
    await tester.tap(existing);
    await tester.pumpAndSettle();
    expect(find.text(Tr.forKu(K.signOutGuestWarn, false)), findsOneWidget);
    expect(auth.signOutCalls, 0);
    await tester.tap(find.text(Tr.forKu(K.cancel, false)));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);
    await _dialog(tester);
    await tester.ensureVisible(existing);
    await tester.tap(existing);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, Tr.forKu(K.signOut, false)),
    );
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });

  testWidgets(
    'T12 R26/44/58 misafir kurtarma açıklaması ve doğrudan kayıt yolu',
    (tester) async {
      await _profile(tester, _GuestAuth());
      final warning = find.byKey(const ValueKey('profile-guest-recovery'));
      expect(warning, findsOneWidget);
      expect(
        tester.widget<Text>(warning).style!.fontSize,
        greaterThanOrEqualTo(14),
      );
      final protect = find.byKey(const ValueKey('profile-guest-protect'));
      await tester.ensureVisible(protect);
      await tester.tap(protect);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('T12 kalıcı hesapta misafir kayıp uyarısı gösterilmez', (
    tester,
  ) async {
    await _profile(tester, _GuestAuth(guest: false));
    expect(find.byKey(const ValueKey('profile-guest-recovery')), findsNothing);
  });

  testWidgets('T12 kayıt diyaloğu Apple Google ve vazgeç yollarını korur', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _profile(tester, _GuestAuth());
    await _dialog(tester);
    debugDefaultTargetPlatformOverride = null;
    expect(find.byKey(const ValueKey('guest-upgrade-apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
