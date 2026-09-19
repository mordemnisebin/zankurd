import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

CustomerInfo _info({required bool premiumActive}) {
  final ent = EntitlementInfo(
    'premium',
    premiumActive,
    true,
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z',
    'prod_premium',
    false,
  );
  return CustomerInfo(
    EntitlementInfos({
      'premium': ent,
    }, premiumActive ? {'premium': ent} : const {}),
    const {},
    const [],
    const [],
    const [],
    '2026-08-02T00:00:00Z',
    'user-x',
    const {},
    '2026-08-02T00:00:00Z',
  );
}

PremiumService _service({
  required Future<CustomerInfo> Function() fetch,
  bool configured = true,
  void Function(Object, StackTrace, {String? reason})? recordError,
}) => PremiumService.forTesting(
  isAnonymous: () async => false,
  logOut: () => throw UnimplementedError(),
  fetchCustomerInfo: fetch,
  recordError: recordError ?? (Object _, StackTrace _, {String? reason}) {},
  configured: configured,
);

/// Ücretsiz avantaj kapıları bellektekine değil taze entitlement'a bakar.
///
/// ## Kusur
///
/// Seri dondurma `isPremium` bayrağına göre ücretsiz veriliyordu; bayrak
/// bayat `true` kalırsa (expiry listener kaçarsa) bedava avantaj sızardı.
/// `refreshEntitlement` doğrulamayı çağrı anında yapar; başarısızlıkta
/// son bilinen durum korunur ve `false` dönülür (güvenli taraf).
void main() {
  test('taze premium doğrulanınca true döner ve bayrak kurulur', () async {
    final service = _service(fetch: () async => _info(premiumActive: true));

    expect(await service.refreshEntitlement(), isTrue);
    expect(service.isPremium, isTrue);
  });

  test('taze yanıtta entitlement yoksa false döner', () async {
    final service = _service(fetch: () async => _info(premiumActive: false));

    expect(await service.refreshEntitlement(), isFalse);
    expect(service.isPremium, isFalse);
  });

  test('doğrulama hatasında son durum korunur ve false dönülür', () async {
    final reported = <Object>[];
    final service = _service(
      fetch: () async => throw Exception('network down'),
      recordError: (Object e, StackTrace _, {String? reason}) =>
          reported.add(e),
    );

    expect(await service.refreshEntitlement(), isFalse);
    expect(service.isPremium, isFalse);
    expect(reported, hasLength(1));
  });

  test('yapılandırılmamış serviste ağa çıkılmaz', () async {
    var calls = 0;
    final service = _service(
      fetch: () async {
        calls++;
        return _info(premiumActive: true);
      },
      configured: false,
    );

    expect(await service.refreshEntitlement(), isFalse);
    expect(calls, 0);
  });
}
