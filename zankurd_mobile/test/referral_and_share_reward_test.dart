import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/referral_result.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/utils/result_sharer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Günlük Paylaşım Ödülü Mantığı', () {
    test('aynı gün içinde yalnız bir kez ödül hak edilir', () async {
      final now = DateTime(2026, 9, 2, 10, 0);

      // İlk kontrol: henüz alınmadı
      expect(await ResultSharer.canClaimDailyShareReward(now), isTrue);

      // İlk talep: başarılı
      expect(await ResultSharer.claimDailyShareReward(now), isTrue);

      // Aynı gün tekrar talep: reddedilir
      expect(await ResultSharer.canClaimDailyShareReward(now), isFalse);
      expect(await ResultSharer.claimDailyShareReward(now), isFalse);

      // Ertesi gün: yeniden hak edilir
      final nextDay = DateTime(2026, 9, 3, 9, 0);
      expect(await ResultSharer.canClaimDailyShareReward(nextDay), isTrue);
      expect(await ResultSharer.claimDailyShareReward(nextDay), isTrue);
      expect(await ResultSharer.canClaimDailyShareReward(nextDay), isFalse);
    });
  });

  group('Referans (Arkadaş Davet) Depo Sözleşmesi', () {
    test(
      'geçerli kod ödül verir, mükerrer veya kendi kodu reddedilir',
      () async {
        final repository = MockZanKurdRepository();
        final initialCoins = await repository.loadCoinBalance();

        // Boş kod
        final emptyResult = await repository.redeemReferralCode('');
        expect(emptyResult.status, ReferralStatus.notFound);

        // Kendi kodu
        final ownResult = await repository.redeemReferralCode('ZK-TEST');
        expect(ownResult.status, ReferralStatus.ownCode);
        expect(await repository.loadCoinBalance(), equals(initialCoins));

        // Geçerli bir arkadaş kodu
        final successResult = await repository.redeemReferralCode('ZK-HEVAL');
        expect(successResult.status, ReferralStatus.success);
        expect(successResult.coinsAwarded, equals(100));
        expect(await repository.loadCoinBalance(), equals(initialCoins + 100));

        // İkinci kez kod girmeye çalışma
        final duplicateResult = await repository.redeemReferralCode(
          'ZK-DILSOZ',
        );
        expect(duplicateResult.status, ReferralStatus.alreadyRedeemed);
        expect(await repository.loadCoinBalance(), equals(initialCoins + 100));
      },
    );
  });

  group('FriendsScreen Davet ve Kod Girme Arayüzü', () {
    Widget createWidget(MockZanKurdRepository repo) {
      return MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => LanguageProvider())],
        child: MaterialApp(home: FriendsScreen(repository: repo)),
      );
    }

    testWidgets('RPC varken 100 coin davet kartı çizilir', (tester) async {
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(createWidget(repository));
      await tester.pumpAndSettle();

      // `redeem_referral_code` 2026-09-05'te canlıda; bayrak açık.
      expect(
        find.byKey(const ValueKey('friends-invite-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('friends-enter-code-button')),
        findsOneWidget,
      );
      expect(find.textContaining('100'), findsWidgets);
    });

    /// Davet kodu diyaloğunun denetleyicisi diyalogun kendi State'ine aittir.
    ///
    /// ## Kusur
    ///
    /// `_showReferralDialog` denetleyiciyi yaratıyor ve HİÇ atmıyordu
    /// (sızıntı); atılacak olsa da çağıran yerde, kapanış animasyonu
    /// bitmeden atmak "used after being disposed" çöküşüne yol açacaktı.
    /// Sessizdi: sızıntı hiçbir testte görünmez, kapanışta istisna
    /// sorgulanmıyordu.
    testWidgets('davet kodu diyaloğu kod uygulanıp kapanırken çökmez', (
      tester,
    ) async {
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(createWidget(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('friends-enter-code-button')));
      await tester.pumpAndSettle();
      // Odaklanmış alan: çökme yalnız odağı/imleci olan alanda görülür.
      await tester.tap(find.byKey(const ValueKey('referral-code-input')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('referral-code-input')),
        'ZK-HEVAL',
      );
      await tester.tap(find.byKey(const ValueKey('referral-code-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('referral-code-input')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
