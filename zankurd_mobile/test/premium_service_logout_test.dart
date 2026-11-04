import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

void main() {
  // Gerçek davranış: A hesabı bağlı ve aktif premium iken çıkış yapılınca
  // premium ve kimlik bağlantısı TEMİZLENMELİ; B hesabına taşınmamalı.
  // (Eski üç senaryo servisi zaten boş başlatıyordu: temizleme kodu
  // silinse de yeşil kalırdı.)
  Future<PremiumService> premiumLinkedToA({
    required Future<bool> Function() isAnonymous,
    required Future<CustomerInfo> Function() logOut,
    Future<CustomerInfo> Function()? fetch,
    Future<LogInResult> Function(String)? logIn,
    void Function(Object, StackTrace, {String? reason})? recordError,
  }) async {
    final service = PremiumService.forTesting(
      isAnonymous: isAnonymous,
      logOut: logOut,
      fetchCustomerInfo: fetch ?? () async => _premiumCustomerInfo(),
      logIn:
          logIn ??
          (id) async =>
              LogInResult(customerInfo: _premiumCustomerInfo(), created: false),
      recordError: recordError ?? (Object _, StackTrace _, {String? reason}) {},
    );
    await service.logInUser('user-a');
    expect(service.linkedUserId, 'user-a', reason: 'önkoşul: A bağlı');
    expect(service.isPremium, isTrue, reason: 'önkoşul: A premium');
    return service;
  }

  test('çıkış A hesabının premium ve kimliğini temizler (kimlikli)', () async {
    var nativeLogoutCalls = 0;
    final service = await premiumLinkedToA(
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

  test('anonim çıkış yolu da A premium ve kimliğini temizler', () async {
    var nativeLogoutCalls = 0;
    final service = await premiumLinkedToA(
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

  test(
    'hatalı çıkış yolu da premium ve kimliği temizler; B devralmaz',
    () async {
      var loginCalls = 0;
      final service = await premiumLinkedToA(
        isAnonymous: () async => false,
        logOut: () async => throw PlatformException(code: '1'),
        recordError: (_, _, {reason}) {},
        logIn: (id) async {
          loginCalls++;
          // B hesabı entitlement'sız: A'nınki taşınmamalı.
          return id == 'user-a'
              ? LogInResult(
                  customerInfo: _premiumCustomerInfo(),
                  created: false,
                )
              : LogInResult(
                  customerInfo: _anonymousCustomerInfo(),
                  created: false,
                );
        },
      );

      await service.logOutUser();
      expect(service.linkedUserId, isNull);
      expect(service.isPremium, isFalse);

      await service.logInUser('user-b');
      expect(loginCalls, 2);
      expect(service.linkedUserId, 'user-b');
      expect(service.isPremium, isFalse, reason: 'B, A aboneliğini devraldı');
    },
  );

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

  test(
    'anonymous logout race error is treated as an unreported no-op',
    () async {
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
    },
  );
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

CustomerInfo _premiumCustomerInfo() {
  const ent = EntitlementInfo(
    'premium',
    true,
    true,
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z',
    'prod_premium',
    false,
  );
  return const CustomerInfo(
    EntitlementInfos({'premium': ent}, {'premium': ent}),
    {},
    [],
    [],
    [],
    '2026-08-02T00:00:00Z',
    'user-a',
    {},
    '2026-08-02T00:00:00Z',
  );
}
