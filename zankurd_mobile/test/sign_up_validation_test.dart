// 2026-07-22 canlı UX denetimi: inline doğrulama testleri
//
// sign_up_screen.dart doğrulama hatalarını SnackBar olarak değil, alanın
// altında kırmızı metin (inline error) olarak göstermelidir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';

import 'support/widget_test_helpers.dart';

/// `StyledInputField` label metnine göre `TextField`'ı bulur.
Finder textFieldByLabel(String label) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    ).first,
    matching: find.byType(TextField),
  ).first;
}

/// Ekranda herhangi bir SnackBar olup olmadığını kontrol eder.
bool hasSnackBar(WidgetTester tester) {
  return find.byType(SnackBar).evaluate().isNotEmpty;
}

/// Buton ekran dışındaysa önce görünür yapar, sonra basar.
Future<void> tapButton(WidgetTester tester, String text) async {
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

    await tester.pumpWidget(
      testShell(child: const SignUpScreen()),
    );
    await tester.pumpAndSettle();
  }

  group('Adım 0 — e-posta/parola doğrulama', () {
    testWidgets('boş alanlar → inline "gerekli" hata mesajları gösterilir',
        (tester) async {
      await pumpSignUpScreen(tester);

      // "İleri" butonuna bas — tüm alanlar boş
      await tapButton(tester, 'İleri');

      // Inline hata mesajları alanın altında görünmeli
      expect(find.text('E-posta gerekli'), findsOneWidget);
      expect(find.text('Parola gerekli'), findsOneWidget);
      expect(find.text('Parola onayı gerekli'), findsOneWidget);

      // SnackBar gösterilmemeli
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('geçersiz e-posta → inline hata mesajı gösterilir',
        (tester) async {
      await pumpSignUpScreen(tester);

      // Geçerli parola gir (doğrulama sadece e-postada kalsın)
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı Onayla'), '123456');

      // Geçersiz e-posta
      await tester.enterText(textFieldByLabel('E-posta adresi'), 'gecersiz');
      await tapButton(tester, 'İleri');

      expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('kısa parola → inline "en az 6 karakter" hatası gösterilir',
        (tester) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), 'abc');
      await tester.enterText(textFieldByLabel('Parolayı Onayla'), 'abc');

      await tapButton(tester, 'İleri');

      expect(find.text('Parola en az 6 karakter olmalı'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets('parola uyuşmazlığı → inline "eşleşmiyor" hatası gösterilir',
        (tester) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı Onayla'), '654321');

      await tapButton(tester, 'İleri');

      expect(find.text('Parolalar eşleşmiyor'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets(
        'parola alanında hint text olarak "En az 6 karakter" görünür',
        (tester) async {
      await pumpSignUpScreen(tester);

      expect(find.text('En az 6 karakter'), findsOneWidget);
    });
  });

  group('Adım 1 — kullanıcı adı doğrulama', () {
    Future<void> goToStep1(WidgetTester tester) async {
      await pumpSignUpScreen(tester);

      await tester.enterText(textFieldByLabel('E-posta adresi'), 'a@b.com');
      await tester.enterText(textFieldByLabel('Parola'), '123456');
      await tester.enterText(textFieldByLabel('Parolayı Onayla'), '123456');

      await tapButton(tester, 'İleri');
    }

    testWidgets('boş kullanıcı adı → inline "gerekli" hatası gösterilir',
        (tester) async {
      await goToStep1(tester);

      // Adım 1'de kullanıcı adı boş — "İleri"ye bas
      await tapButton(tester, 'İleri');

      expect(find.text('Kullanıcı adı gerekli'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });

    testWidgets(
        'kısa kullanıcı adı → inline "en az 2 karakter" hatası gösterilir',
        (tester) async {
      await goToStep1(tester);

      await tester.enterText(textFieldByLabel('Kullanıcı adı'), 'a');

      await tapButton(tester, 'İleri');

      expect(find.text('Kullanıcı adı en az 2 karakter olmalı'), findsOneWidget);
      expect(hasSnackBar(tester), isFalse);
    });
  });
}
