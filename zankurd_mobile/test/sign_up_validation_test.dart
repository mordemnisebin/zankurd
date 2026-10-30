// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-07-22 canlı UX denetimi: inline doğrulama testleri
//
// sign_up_screen.dart doğrulama hatalarını SnackBar olarak değil, alanın
// altında kırmızı metin (inline error) olarak göstermelidir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/widgets/auth_social_buttons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// `SahneField` label metnine göre `TextField`'ı bulur.
Finder textFieldByLabel(String label) {
  return find
      .descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      )
      .first;
}

/// Ekranda herhangi bir SnackBar olup olmadığını kontrol eder.
bool hasSnackBar(WidgetTester tester) {
  return find.byType(SnackBar).evaluate().isNotEmpty;
}

/// Buton ekran dışındaysa önce görünür yapar, sonra basar.
Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.pump();
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => freshMockRepository());

  Future<void> pumpSignUpScreen(WidgetTester tester) async {
    // Mobil boyut — SignUpScreen scrollable olduğu için 390x844 yeterli
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(testShell(child: const SignUpScreen()));
    await tester.pumpAndSettle();
  }

  group('Adım 0 — e-posta/parola doğrulama', () {
    testWidgets('T10 boş alanlarda İleri pasif, sosyal kayıt yolları açık', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);

      expect(
        find.text(
          '1. E-posta ve parola → 2. Kullanıcı adı → 3. Kontrol et ve hesabı oluştur',
        ),
        findsOneWidget,
      );
      expect(find.text('E-postanı ve parolanı gir'), findsNothing);
      final next = find.byKey(const ValueKey('signup-next'));
      expect(tester.widget<SahneButton>(next).onPressed, isNull);
      final google = find.byKey(const ValueKey('auth-google'));
      expect(tester.widget<GoogleAuthButton>(google).onPressed, isNotNull);
      await tapButton(tester, 'İleri');
      expect(find.text('E-posta gerekli'), findsNothing);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('S25 geçerli epostada İleri açılır, boş epostada kapanır', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);
      final next = find.byKey(const ValueKey('signup-next'));
      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.pump();
      expect(tester.widget<SahneButton>(next).onPressed, isNotNull);
      await tester.enterText(textFieldByLabel('Parolayı onayla'), '123456');
      await tester.pump();
      expect(tester.widget<SahneButton>(next).onPressed, isNotNull);
      await tester.enterText(textFieldByLabel('E-posta adresi'), '   ');
      await tester.pump();
      expect(tester.widget<SahneButton>(next).onPressed, isNull);
      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.pump();
      expect(tester.widget<SahneButton>(next).onPressed, isNotNull);
      await tapButton(tester, 'İleri');
      expect(find.text('Kullanıcı adını seç'), findsOneWidget);
      expect(tester.widget<SahneButton>(next).onPressed, isNull);
    });

    testWidgets('geçersiz e-posta → inline hata mesajı gösterilir', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);

      // Geçerli parola gir (doğrulama sadece e-postada kalsın)
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı onayla'), '123456');

      // Geçersiz e-posta
      await tester.enterText(textFieldByLabel('E-posta adresi'), 'gecersiz');
      await tapButton(tester, 'İleri');

      expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('kısa parola → inline "en az 6 karakter" hatası gösterilir', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), 'abc');
      await tester.enterText(textFieldByLabel('Parolayı onayla'), 'abc');

      await tapButton(tester, 'İleri');

      expect(find.text('Parola en az 6 karakter olmalı'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('parola uyuşmazlığı → inline "eşleşmiyor" hatası gösterilir', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı onayla'), '654321');

      await tapButton(tester, 'İleri');

      expect(find.text('Parolalar eşleşmiyor'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('parola alanında hint text olarak "En az 6 karakter" görünür', (
      tester,
    ) async {
      await pumpSignUpScreen(tester);

      expect(find.text('En az 6 karakter'), findsOneWidget);
    });
  });

  group('Adım 1 — kullanıcı adı doğrulama', () {
    Future<void> goToStep1(WidgetTester tester) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı onayla'), '123456');

      await tapButton(tester, 'İleri');
    }

    testWidgets('boş kullanıcı adı → İleri pasif', (tester) async {
      await goToStep1(tester);

      expect(
        tester
            .widget<SahneButton>(find.byKey(const ValueKey('signup-next')))
            .onPressed,
        isNull,
      );
      await tapButton(tester, 'İleri');
      expect(find.text('Ad en az 2 karakter olmalı'), findsNothing);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets(
      'kısa kullanıcı adı → inline "en az 2 karakter" hatası gösterilir',
      (tester) async {
        await goToStep1(tester);

        await tester.enterText(textFieldByLabel('Kullanıcı adı'), 'a');

        await tapButton(tester, 'İleri');

        expect(find.text('Ad en az 2 karakter olmalı'), findsOneWidget);
        expect(hasSnackBar(tester), isFalse);
      },
    );
  });

  group('Adım 1 — kullanıcı adı DisplayNamePolicy kontrolünden geçer', () {
    // 2026-08-14 denetimi: kayıt formu üçüncü bir yazma yoluydu — isim
    // kapısı (`profile_name_gate_screen.dart`) ve ayarlar
    // (`settings_screen.dart` `_savePlayerName`) zaten `DisplayNamePolicy`
    // çağırıyordu, kayıt hiç çağırmıyordu. Engellenen bir sözcük ya da
    // marka/yetkili taklidi içeren bir ad, kapıdan hiç geçmeden doğrudan
    // sunucuya (`updateProfileName` üzerinden) yazılabiliyordu.
    Future<void> goToStep1(WidgetTester tester) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı onayla'), '123456');

      await tapButton(tester, 'İleri');
    }

    testWidgets('engellenen sözcük içeren ad reddedilir', (tester) async {
      await goToStep1(tester);

      await tester.enterText(textFieldByLabel('Kullanıcı adı'), 'siktir');
      await tapButton(tester, 'İleri');

      // `DisplayNameVerdict.blockedWord` → `K.nameBlockedWord`.
      expect(find.text('Bu ad uygunsuz bir sözcük içeriyor'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('yetkili/destek taklidi eden ad reddedilir', (tester) async {
      await goToStep1(tester);

      await tester.enterText(
        textFieldByLabel('Kullanıcı adı'),
        'ZanKurd Destek',
      );
      await tapButton(tester, 'İleri');

      // `DisplayNameVerdict.reservedName` → `K.nameReserved`.
      expect(find.text('Bu ad korumalı, kullanılamaz'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('masum bir Kurmancî ad kabul edilir, sonraki adıma geçilir', (
      tester,
    ) async {
      await goToStep1(tester);

      await tester.enterText(textFieldByLabel('Kullanıcı adı'), 'Zelal');
      await tapButton(tester, 'İleri');

      // Adım 2 (gözden geçir) alana ait etiketi gösterir; reddedilseydi
      // sihirbaz Adım 1'de kalırdı.
      expect(find.text('Kullanıcı adı:'), findsOneWidget);
    });
  });
}
