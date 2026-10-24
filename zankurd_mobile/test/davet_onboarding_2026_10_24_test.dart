/// 2026-10-24 sahip kararları: sahte soru kartı yok, yaş kutusu yok, büyük dil
/// seçici, Türkçe varsayılan, kabul satırı, davet kartında kendi kod.
///
/// ## Kusur
///
/// Karşılamanın ilk sayfası bankadan alınmış gerçek bir soru ve dört şık
/// çiziyordu; kullanıcılar şıklara dokunmaya çalışıyordu. Ayrıca zorunlu bir
/// "13 yaşındayım" kutusu "Sonraki"yi kilitliyor ve ilk ekranda kırmızı hata
/// gösteriyordu. Dil, Kurmancî varsayılandı ve seçici küçük bir KU|TR hapıydı.
/// Davet kartında ise kullanıcı KENDİ kodunu bulamıyordu: kod yalnız
/// "Paylaş · ZK-…" düğmesinin etiketinde yaşıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Eski bekçiler kutunun ve maketin VARLIĞINI sabitliyordu; hiçbiri "yeni
/// gelen kullanıcı ilk ekranda ne yapmaya çalışır" sorusunu sormuyordu.
/// Davet kartı için kodun ekranda GÖRÜNÜR olduğunu ölçen bir test yoktu.
///
/// ## Kural
///
/// Karşılamada soru/şık/onay kutusu yoktur, "Sonraki" hemen etkindir; dil
/// seçici Kurmancî önce gelir; yeni kurulum Türkçe başlar, kayıtlı seçim
/// korunur; giriş ekranında şartlar ve gizlilik bağlantıdır; davet kartı
/// kullanıcının kodunu gösterir, kopyalar, mağaza bağlantılarıyla paylaşır.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/utils/profile_tab_request.dart';

import 'support/widget_test_helpers.dart';

class _TagRepository extends MockZanKurdRepository {
  @override
  Future<String?> getPlayerTag() async => 'ZK-4F7K';
}

class _GuestAuth extends AuthProvider {
  _GuestAuth() : super.test();

  @override
  bool get isGuest => true;

  @override
  bool get isAuthenticated => true;
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  LanguageProvider? language,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: language ?? turkishLang(),
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: OnboardingScreen(onComplete: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('karşılama', () {
    testWidgets('soru/şık/yaş kutusu yok, "Sonraki" hemen etkin', (
      tester,
    ) async {
      await _pumpOnboarding(tester);

      // Sahte soru ve şıklar.
      expect(find.textContaining('Türkçede ne demektir'), findsNothing);
      for (final answer in ['taş', 'yol', 'kapı', 'ağaç']) {
        expect(find.text(answer), findsNothing);
      }
      // Yaş kutusu.
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-age-gate')), findsNothing);
      expect(find.textContaining('13 yaş'), findsNothing);

      // "Sonraki" ilk dokunuşta ilerler.
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(find.text('Başla'), findsOneWidget);
      expect(find.textContaining('13 yaş'), findsNothing);
      expect(
        find.byKey(const ValueKey('onboarding-age-gate-hint')),
        findsNothing,
      );
    });

    testWidgets('dil seçici: Kurmancî ÖNCE, tam adlar, geçiş çalışır', (
      tester,
    ) async {
      await _pumpOnboarding(tester);

      final ku = find.byKey(const ValueKey('onboarding-language-ku'));
      final tr = find.byKey(const ValueKey('onboarding-language-tr'));
      expect(tester.getTopLeft(ku).dx, lessThan(tester.getTopLeft(tr).dx));
      expect(find.text('Kurmancî'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);
      expect(find.text('Uygulama dili · Zimanê sepanê'), findsOneWidget);
      expect(tester.getSize(ku).height, greaterThanOrEqualTo(56));

      expect(find.text('Sonraki'), findsOneWidget);
      await tester.tap(ku);
      await tester.pumpAndSettle();
      expect(find.text('Bidomîne'), findsOneWidget);
      await tester.tap(tr);
      await tester.pumpAndSettle();
      expect(find.text('Sonraki'), findsOneWidget);
    });

    for (final size in [const Size(320, 640), const Size(390, 844)]) {
      testWidgets('taşma yok: ${size.width.toInt()} genişlik, yazı ölçeği 2', (
        tester,
      ) async {
        await _pumpOnboarding(tester, size: size, textScale: 2);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('varsayılan dil', () {
    test('yeni kurulum Türkçe, kayıtlı Kurmancî korunur', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await LanguageProvider.load()).lang, 'tr');
      expect(LanguageProvider().lang, 'tr');

      SharedPreferences.setMockInitialValues({'zankurd.language': 'ku'});
      expect((await LanguageProvider.load()).lang, 'ku');
    });
  });

  group('kabul satırı', () {
    testWidgets('giriş ekranında şartlar ve gizlilik bağlantıdır, düğme değil', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: const SignInScreen(),
          authProvider: GateAuthProvider(),
        ),
      );
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('consent-line'));
      expect(line, findsOneWidget);
      final text = tester.widget<Text>(line).textSpan!.toPlainText();
      expect(
        text,
        "Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul edersin.",
      );
      final spans = <TextSpan>[];
      tester.widget<Text>(line).textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) spans.add(span);
        return true;
      });
      expect(spans.map((s) => s.text), [
        'Kullanım Şartları',
        'Gizlilik Politikası',
      ]);
      // Düğme değil: yalnız düz metin içinde iki bağlantı.
      expect(
        find.descendant(of: line, matching: find.byType(ElevatedButton)),
        findsNothing,
      );
    });

    test('adresler AppConfig yasal bağlantılarıdır', () {
      final source = File(
        'lib/src/widgets/consent_line.dart',
      ).readAsStringSync();
      expect(source, contains('AppConfig.termsOfServiceUrl'));
      expect(source, contains('AppConfig.privacyPolicyUrl'));
    });

    test('Kurmancî şablonda da iki bağlantı işareti var', () {
      final ku = Tr.of(K.signInConsent, AppLanguage.ku);
      expect(RegExp(r'\[[^\]]+\]').allMatches(ku), hasLength(2));
    });
  });

  group('davet kartı', () {
    Future<void> pumpFriends(
      WidgetTester tester, {
      AuthProvider? auth,
      Size size = const Size(390, 844),
      double textScale = 1,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          authProvider: auth,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: FriendsScreen(repository: _TagRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kullanıcının kendi kodu görünür ve kopyalanır', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpFriends(tester);

      expect(find.text('Arkadaşını davet et'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('friends-invite-code-text')),
            )
            .data,
        'ZK-4F7K',
      );
      expect(find.byKey(const ValueKey('friends-share-code-button')), findsOne);

      await tester.tap(find.byKey(const ValueKey('friends-copy-code-button')));
      await tester.pump();
      expect(copied, 'ZK-4F7K');
      expect(find.text('Kodun kopyalandı'), findsOneWidget);
    });

    testWidgets('misafirde kod yok, "hesabını kaydet" yönlendirmesi var', (
      tester,
    ) async {
      await pumpFriends(tester, auth: _GuestAuth());

      expect(
        find.byKey(const ValueKey('friends-invite-code-text')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('friends-share-code-button')),
        findsNothing,
      );
      expect(find.text('Davet kodu için hesabını kaydet'), findsOneWidget);
      final before = ProfileTabRequest.pending.value;
      await tester.ensureVisible(
        find.byKey(const ValueKey('friends-invite-save-account')),
      );
      await tester.tap(
        find.byKey(const ValueKey('friends-invite-save-account')),
      );
      await tester.pump();
      expect(ProfileTabRequest.pending.value, before + 1);
    });

    testWidgets('320 genişlik / yazı ölçeği 2: taşma yok', (tester) async {
      await pumpFriends(tester, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      await pumpFriends(
        tester,
        auth: _GuestAuth(),
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    test(
      'mağaza bağlantıları gerçek: App Store kimliği web/join.js ile aynı',
      () {
        final join = File('web/join.js').readAsStringSync();
        expect(join, contains(AppConfig.appStoreUrl));
        expect(
          AppConfig.playStoreUrl,
          'https://play.google.com/store/apps/details?id=com.zankurd.app',
        );
        final share = Tr.of(K.inviteStoreLinks, AppLanguage.tr, {
          'ios': AppConfig.appStoreUrl,
          'play': AppConfig.playStoreUrl,
        });
        expect(share, contains(AppConfig.appStoreUrl));
        expect(share, contains(AppConfig.playStoreUrl));
      },
    );

    test('ödül metni sunucudaki 100 ile aynı', () {
      final sql = File(
        'supabase/2026-10-02_referral_redemption_ledger.sql',
      ).readAsStringSync();
      expect(sql, contains('v_reward_amount constant integer := 100'));
      expect(Tr.of(K.inviteSubtitle, AppLanguage.tr), contains('100 jeton'));
    });
  });

  group('yaş şartı belgelerde', () {
    test('terms.html iki dilde 13 yaş maddesini taşır', () {
      final terms = File('web/terms.html').readAsStringSync();
      expect(terms, contains('13 yaş ve üzerindeki kullanıcılar içindir'));
      expect(terms, contains('ji bo bikarhênerên 13 salî û mezintir e'));
    });
    test('privacy.html iki dilde 13 yaş cümlesini taşır', () {
      final privacy = File('web/privacy.html').readAsStringSync();
      expect(privacy, contains('13 yaş ve üzerindeki kullanıcılar içindir'));
      expect(privacy, contains('13 salî û mezintir e'));
    });
  });
}
