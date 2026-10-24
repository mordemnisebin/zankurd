/// Nazik e-posta doğrulama (6 haneli kod): profil kartı ve kod sayfası.
///
/// ## Kusur
///
/// E-posta/parola hesapları "Confirm email KAPALI" ile açılıyor: yazılan
/// adres hiç sınanmıyor, yanlış yazılan adresli hesap şifre sıfırlama
/// e-postası da alamıyor. Doğrulama kanıtı olarak `email_confirmed_at`
/// kullanılamaz (kayıtta otomatik dolar).
///
/// ## Niçin sessiz kalırdı
///
/// Akış üç sunucu adımından oluşur (kod yolla, kodu doğrula, işareti yaz);
/// herhangi birinde sessizce takılmak "doğrulandı" kartının kalmasına ya da
/// yanlışlıkla kalkmasına yol açar. Sahte kapı ile her adım ve sıra ayrı
/// ayrı görülür.
///
/// ## Kural
///
/// * Kart yalnız DOĞRULANMAMIŞ e-posta hesabında çizilir; Google/Apple,
///   misafir ve durumu bilinmeyen (çevrimdışı) hesapta hiç çizilmez.
/// * Doğrulama oyunu ya da sıralamayı KAPILAMAZ (bu dosya yalnız kart ve
///   kapıyı sınar; oyun ekranları kart bilmez).
/// * Tekrar gönderme 60 sn bekler; bekleme sürerken kart yeniden açılsa da
///   YENİ e-posta gitmez.
/// * İşaret yalnız `verifyCode` başarılı OLDUKTAN sonra yazılır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/services/email_verification.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/email_verify_card.dart';

class _FakeGateway implements EmailVerificationGateway {
  _FakeGateway({this.needs = true, this.verified = false});

  bool needs;
  bool? verified;
  final String address = 'ada@example.com';
  final calls = <String>[];
  EmailVerificationFailure? sendFailure;
  EmailVerificationFailure? verifyFailure;
  bool markResult = true;

  @override
  String? get email => address;

  @override
  bool get needsVerification => needs;

  @override
  Future<bool?> isVerified() async => verified;

  @override
  Future<void> sendCode() async {
    calls.add('send');
    final failure = sendFailure;
    if (failure != null) throw EmailVerificationException(failure);
  }

  @override
  Future<void> verifyCode(String code) async {
    calls.add('verify:$code');
    final failure = verifyFailure;
    if (failure != null) throw EmailVerificationException(failure);
  }

  @override
  Future<bool> markVerified() async {
    calls.add('mark');
    return markResult;
  }
}

Widget _wrap(Widget child, {double scale = 1.0}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

const _card = ValueKey('email-verify-card');
const _send = ValueKey('email-verify-send');
const _code = ValueKey('email-verify-code');
const _confirm = ValueKey('email-verify-confirm');
const _resend = ValueKey('email-verify-resend');
const _error = ValueKey('email-verify-error');

Future<void> _open(WidgetTester tester, _FakeGateway gateway) async {
  await tester.pumpWidget(_wrap(EmailVerifyCard(gateway: gateway)));
  await tester.pump();
  await tester.tap(find.byKey(_send));
  await tester.pumpAndSettle();
}

void main() {
  group('kart görünürlüğü', () {
    testWidgets('doğrulanmamış e-posta hesabında görünür', (tester) async {
      await tester.pumpWidget(_wrap(EmailVerifyCard(gateway: _FakeGateway())));
      await tester.pump();
      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('E-postanı doğrula'), findsOneWidget);
    });

    testWidgets('doğrulanmışsa görünmez', (tester) async {
      await tester.pumpWidget(
        _wrap(EmailVerifyCard(gateway: _FakeGateway(verified: true))),
      );
      await tester.pump();
      expect(find.byKey(_card), findsNothing);
    });

    testWidgets('Google/Apple ya da misafir hesapta (needs=false) görünmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EmailVerifyCard(gateway: _FakeGateway(needs: false))),
      );
      await tester.pump();
      expect(find.byKey(_card), findsNothing);
    });

    testWidgets('durum bilinmiyorsa (çevrimdışı) susar', (tester) async {
      await tester.pumpWidget(
        _wrap(EmailVerifyCard(gateway: _FakeGateway(verified: null))),
      );
      await tester.pump();
      expect(find.byKey(_card), findsNothing);
    });
  });

  group('akış', () {
    testWidgets('kod gider, kod sayfası adresi gösterir', (tester) async {
      final gateway = _FakeGateway();
      await _open(tester, gateway);

      expect(gateway.calls, ['send']);
      expect(find.byKey(_code), findsOneWidget);
      expect(find.textContaining('ada@example.com'), findsOneWidget);
    });

    testWidgets('doğru kod: verify sonra mark, kart kalkar', (tester) async {
      final gateway = _FakeGateway();
      var verifiedCallback = false;
      await tester.pumpWidget(
        _wrap(
          EmailVerifyCard(
            gateway: gateway,
            onVerified: () => verifiedCallback = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(_code), '123456');
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(gateway.calls, ['send', 'verify:123456', 'mark']);
      expect(verifiedCallback, isTrue);
      expect(find.byKey(_card), findsNothing);
      expect(find.text('E-postan doğrulandı'), findsOneWidget);
    });

    testWidgets('yanlış kod: hata görünür, işaret YAZILMAZ', (tester) async {
      final gateway = _FakeGateway()
        ..verifyFailure = EmailVerificationFailure.badCode;
      await _open(tester, gateway);

      await tester.enterText(find.byKey(_code), '000000');
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pump();
      await tester.pump();

      expect(gateway.calls, isNot(contains('mark')));
      expect(find.byKey(_error), findsOneWidget);
      expect(find.text('Kod hatalı ya da süresi doldu.'), findsOneWidget);
      expect(find.byKey(_card), findsOneWidget);
    });

    testWidgets('işaret yazılamazsa kart kalır ve hata görünür', (
      tester,
    ) async {
      final gateway = _FakeGateway()..markResult = false;
      await _open(tester, gateway);

      await tester.enterText(find.byKey(_code), '123456');
      await tester.pump();
      await tester.tap(find.byKey(_confirm));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(_error), findsOneWidget);
      expect(find.byKey(_card), findsOneWidget);
    });

    testWidgets('6 haneden kısa kodda Doğrula pasif', (tester) async {
      final gateway = _FakeGateway();
      await _open(tester, gateway);

      await tester.enterText(find.byKey(_code), '12345');
      await tester.pump();
      await tester.tap(find.byKey(_confirm), warnIfMissed: false);
      await tester.pump();

      expect(gateway.calls, ['send']);
    });

    testWidgets('yalnız rakam kabul edilir ve 6 haneyle sınırlıdır', (
      tester,
    ) async {
      await _open(tester, _FakeGateway());
      await tester.enterText(find.byKey(_code), '12ab34567890');
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '123456');
    });

    testWidgets('gönderim hatasında kod sayfası açılmaz', (tester) async {
      final gateway = _FakeGateway()
        ..sendFailure = EmailVerificationFailure.network;
      await _open(tester, gateway);

      expect(find.byKey(_code), findsNothing);
      expect(
        find.text('Kod gönderilemedi. Sonra tekrar dene.'),
        findsOneWidget,
      );
    });
  });

  group('60 sn tekrar gönderme sınırı', () {
    testWidgets('sayfa açılınca sayaç çalışır, 60 sn sonra düğme açılır', (
      tester,
    ) async {
      final gateway = _FakeGateway();
      await _open(tester, gateway);

      final resend = find.byKey(_resend);
      expect(find.text('Tekrar gönder (60 sn)'), findsOneWidget);
      // Bekleme sürerken dokunuş yeni e-posta göndermez.
      await tester.tap(resend, warnIfMissed: false);
      await tester.pump();
      expect(gateway.calls.where((c) => c == 'send').length, 1);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Tekrar gönder (30 sn)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Tekrar gönder'), findsOneWidget);

      await tester.tap(resend);
      await tester.pump();
      await tester.pump();
      expect(gateway.calls.where((c) => c == 'send').length, 2);
      // Yeniden gönderince sayaç 60'tan başlar.
      expect(find.text('Tekrar gönder (60 sn)'), findsOneWidget);
    });

    testWidgets('bekleme sürerken kart yeniden açılsa YENİ e-posta gitmez', (
      tester,
    ) async {
      final gateway = _FakeGateway();
      await _open(tester, gateway);

      // Sayfayı kapat.
      await tester.tap(find.byKey(const ValueKey('sahne-sheet-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(_code), findsNothing);

      await tester.tap(find.byKey(_send));
      await tester.pumpAndSettle();

      expect(gateway.calls.where((c) => c == 'send').length, 1);
      expect(find.byKey(_code), findsOneWidget);
    });
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('$width px ve %200 yazıda kart ve sayfa taşmaz', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(EmailVerifyCard(gateway: _FakeGateway()), scale: 2.0),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(_send));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
