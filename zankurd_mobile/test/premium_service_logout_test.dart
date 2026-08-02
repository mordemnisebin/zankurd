import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

void main() {
  test('anonymous logout skips the native RevenueCat logout', () async {
    var nativeLogoutCalls = 0;
    final service = PremiumService.forTesting(
      isAnonymous: () async => true,
      logOut: () async {
        nativeLogoutCalls++;
        return _anonymousCustomerInfo();
      },
    );

    await service.logOutUser();

    expect(nativeLogoutCalls, 0);
    expect(service.linkedUserId, isNull);
    expect(service.isPremium, isFalse);
  });

  test('identified logout calls native RevenueCat logout once', () async {
    var nativeLogoutCalls = 0;
    final service = PremiumService.forTesting(
      isAnonymous: () async => false,
      logOut: () async {
        nativeLogoutCalls++;
        return _anonymousCustomerInfo();
      },
    );

    await service.logOutUser();

    expect(nativeLogoutCalls, 1);
    expect(service.linkedUserId, isNull);
    expect(service.isPremium, isFalse);
  });

  test('anonymous logout race error is treated as an unreported no-op', () async {
    var nativeLogoutCalls = 0;
    final reportedErrors = <Object>[];
    final service = PremiumService.forTesting(
      isAnonymous: () async => false,
      logOut: () async {
        nativeLogoutCalls++;
        throw PlatformException(code: '22');
      },
      recordError: (error, _, {reason}) => reportedErrors.add(error),
    );

    await service.logOutUser();

    expect(nativeLogoutCalls, 1);
    expect(reportedErrors, isEmpty);
    expect(service.linkedUserId, isNull);
    expect(service.isPremium, isFalse);
  });
}

CustomerInfo _anonymousCustomerInfo() => const CustomerInfo(
  EntitlementInfos({}, {}),
  {},
  [],
  [],
  [],
  '2026-08-02T00:00:00Z',
  'anonymous-user',
  {},
  '2026-08-02T00:00:00Z',
);
