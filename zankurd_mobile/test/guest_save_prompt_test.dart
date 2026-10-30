/// Misafirin 3. oyunundan sonra tek, nazik "hesabını kaydet" sayfası.
///
/// ## Kusur
///
/// Misafir girişi küçük bir bağlantıydı ve misafire hesabını kaydetmesini
/// söyleyen tek yer Profil menüsüydü; oyuncu ilk heyecanını yaşadığı anda
/// (üç oyundan sonra) ilerlemesinin cihaza bağlı olduğunu bilmiyordu.
///
/// ## Niçin sessiz kaldı
///
/// Hiçbir test "misafir kaç oyun sonra, kaç kez ve ne sıklıkla hatırlatılır"
/// sorusunu sormuyordu; hatırlatıcı yoktu, dolayısıyla bozulacak bir şey de
/// yoktu. Sayfa eklenirken en kolay hata, onu her oyun sonunda ya da giriş
/// yapmış kullanıcıya göstermek ve oyunu kesmektir: bu dosya sayaç, bekleme
/// süresi, üst sınır ve "asla engelleme" kurallarını sabitler.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/guest_save_prompt.dart';
import 'package:zankurd_mobile/src/widgets/guest_account_email_form.dart';

import 'support/widget_test_helpers.dart';

class _GuestAuth extends AuthProvider {
  _GuestAuth() : super.test();
  @override
  bool get isAuthenticated => true;
  @override
  bool get isGuest => true;
  @override
  bool get isLoading => false;
  @override
  String? get guestSaveUserId => 'u1';
}

void main() {
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 24, 12);
  });

  Future<GuestSavePromptService> load([String uid = 'u1']) =>
      GuestSavePromptService.load(uid, now: () => now);

  test(
    'üçüncü oyunda bir kez tetiklenir, öncesinde ve sonrasında değil',
    () async {
      final s = await load();
      expect(await s.recordGame(), isFalse);
      expect(await s.recordGame(), isFalse);
      expect(await s.recordGame(), isTrue);
      expect(await s.recordGame(), isFalse, reason: 'bekleme süresi içinde');
    },
  );

  test('kapatınca 7 gün susar, sonra yeniden sorar; en çok 3 kez', () async {
    final s = await load();
    for (var i = 0; i < 3; i++) {
      await s.recordGame();
    }
    now = now.add(const Duration(days: 6, hours: 23));
    expect(await s.recordGame(), isFalse);
    now = now.add(const Duration(hours: 2));
    expect(await s.recordGame(), isTrue, reason: '2. gösterim');
    now = now.add(const Duration(days: 8));
    expect(await s.recordGame(), isTrue, reason: '3. gösterim');
    now = now.add(const Duration(days: 30));
    expect(await s.recordGame(), isFalse, reason: 'üst sınır 3');
  });

  test('sayaç kullanıcıya özeldir ve yeniden yüklemede korunur', () async {
    final a = await load('a');
    await a.recordGame();
    await a.recordGame();
    final b = await load('b');
    expect(await b.recordGame(), isFalse);
    final a2 = await load('a');
    expect(await a2.recordGame(), isTrue);
  });

  Widget host(AuthProvider? auth, void Function(BuildContext) grab) =>
      testShell(
        authProvider: auth,
        child: Builder(
          builder: (c) {
            grab(c);
            return const Scaffold(body: Text('sonuç'));
          },
        ),
      );

  testWidgets('misafir 3. oyunda sayfayı görür; "Şimdi değil" oyunu kesmez', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(_GuestAuth(), (c) => ctx = c));
    for (var i = 0; i < 2; i++) {
      await GuestSavePrompt.afterGame(ctx, now: () => now);
      await tester.pumpAndSettle();
      expect(find.text('Şimdi değil'), findsNothing);
    }
    final shown = GuestSavePrompt.afterGame(ctx, now: () => now);
    await tester.pumpAndSettle();
    expect(find.text('İlerlemeni kaybetme — hesabını kaydet'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing, reason: 'Android');
    expect(find.byType(GuestAccountEmailForm), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('guest-upgrade-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Şimdi değil'));
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    await shown;
    expect(find.text('sonuç'), findsOneWidget);
    expect(find.text('Şimdi değil'), findsNothing);
  });

  testWidgets(
    'T4 iOS sosyal seçenek eksikti; eski bekçi tek sağlayıcı istiyordu',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      late BuildContext ctx;
      await tester.pumpWidget(host(_GuestAuth(), (c) => ctx = c));
      for (var i = 0; i < 3; i++) {
        GuestSavePrompt.afterGame(ctx, now: () => now);
        await tester.pumpAndSettle();
      }
      expect(find.text('Apple ile devam et'), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('misafir olmayan ne sayılır ne sayfa görür', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(null, (c) => ctx = c));
    for (var i = 0; i < 5; i++) {
      await GuestSavePrompt.afterGame(ctx, now: () => now);
    }
    await tester.pumpAndSettle();
    expect(find.text('Şimdi değil'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.contains('guestSave')), isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320 genişlik, yazı ×$scale: taşma yok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      late BuildContext ctx;
      await tester.pumpWidget(host(_GuestAuth(), (c) => ctx = c));
      for (var i = 0; i < 3; i++) {
        GuestSavePrompt.afterGame(ctx, now: () => now);
        await tester.pumpAndSettle();
      }
      expect(find.text('Şimdi değil'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
