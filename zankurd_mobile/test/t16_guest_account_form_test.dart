import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/guest_save_prompt.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/auth_social_buttons.dart';

import 'support/widget_test_helpers.dart';

class _GuestAuth extends AuthProvider {
  _GuestAuth() : super.test();
  int upgrades = 0;
  @override
  bool get isGuest => true;
  @override
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
  }) async {
    upgrades++;
    return false;
  }
}

void main() {
  setUp(freshMockRepository);
  for (final ku in [false, true]) {
    testWidgets(
      'Ö4 ${ku ? 'KU' : 'TR'} yarış formu boşken pasif, geçerli olunca etkin',
      (tester) async {
        final auth = _GuestAuth();
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(() {
          tester.view.reset();
          debugDefaultTargetPlatformOverride = null;
        });
        await tester.pumpWidget(
          testShell(
            authProvider: auth,
            languageProvider: ku ? kurmanciLang() : turkishLang(),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const GuestSaveSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(GoogleAuthButton).hitTestable(), findsOneWidget);
        expect(find.byType(AppleAuthButton).hitTestable(), findsOneWidget);
        bool saveEnabled() {
          final label = Tr.forKu(K.save, ku);
          final sahne = find.widgetWithText(SahneButton, label);
          if (sahne.evaluate().isNotEmpty) {
            return tester.widget<SahneButton>(sahne).onPressed != null;
          }
          return tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, label),
                  )
                  .onPressed !=
              null;
        }

        expect(
          saveEnabled(),
          isFalse,
          reason: 'boş form kırmızı hata üretmeden pasif kalmalı',
        );
        expect(
          find.text(
            ku
                ? 'E-name û şîfreyeke herî kêm 6 karakterî binivîse'
                : 'E-posta ve en az 6 karakterlik parola gir',
          ),
          findsOneWidget,
        );
        expect(find.text(Tr.forKu(K.emailInvalid, ku)), findsNothing);
        final fields = find.byType(SahneField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.first, 'name@');
        await tester.enterText(fields.last, '123456');
        await tester.pump();
        expect(
          saveEnabled(),
          isFalse,
          reason: 'profil ile aynı geçerli e-posta kuralı',
        );
        await tester.enterText(fields.first, 'name@example.com');
        await tester.pump();
        expect(saveEnabled(), isTrue);
        await tester.enterText(fields.last, '123');
        await tester.pump();
        expect(saveEnabled(), isFalse);
        expect(auth.upgrades, 0);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final save = find.text(Tr.forKu(K.save, ku));
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(544));
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
