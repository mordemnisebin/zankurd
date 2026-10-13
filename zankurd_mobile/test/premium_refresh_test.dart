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
/// `refreshEntitlement` doğrulamayı çağrı anında yapar ve sonucu üç ayrı
/// hâlde döner: kesin cevap, kesin "abone değil" ve bilinmiyen. 2026-09-25
/// öncesi hata ile yokluşu tek `false`'a indirgiyordu; sonuç ekranı bunu
/// "abone değil" okuyup çevrimdışı aboneyi ücretli yola sürüklüyordu.
void main() {
  test(
    'taze premium doğrulanınca kesin true döner ve bayrak kurulur',
    () async {
      final service = _service(fetch: () async => _info(premiumActive: true));

      final result = await service.refreshEntitlement();

      expect(
        result,
        isA<EntitlementRefreshKnown>().having(
          (e) => e.isPremium,
          'isPremium',
          isTrue,
        ),
      );
      expect(service.isPremium, isTrue);
    },
  );

  test('taze yanıtta entitlement yoksa kesin false döner', () async {
    final service = _service(fetch: () async => _info(premiumActive: false));

    final result = await service.refreshEntitlement();

    expect(
      result,
      isA<EntitlementRefreshKnown>().having(
        (e) => e.isPremium,
        'isPremium',
        isFalse,
      ),
    );
    expect(service.isPremium, isFalse);
  });

  test('doğrulama hatasında "abone değil" denmez, bilinmiyor döner', () async {
    final reported = <Object>[];
    final service = _service(
      fetch: () async => throw Exception('network down'),
      recordError: (Object e, StackTrace _, {String? reason}) =>
          reported.add(e),
    );

    final result = await service.refreshEntitlement();

    expect(result, isA<EntitlementRefreshUnknown>());
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

    final result = await service.refreshEntitlement();

    expect(result, isA<EntitlementRefreshUnknown>());
    expect(calls, 0);
  });
}
