import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

void main() {
  test(
    'offerings yükleme hatasını raporlayıp başarısız sonuç döndürür',
    () async {
      final reportedErrors = <Object>[];
      final service = PremiumService.forTesting(
        isAnonymous: () async => true,
        logOut: () async => throw UnimplementedError(),
        fetchOfferings: () async => throw StateError('RevenueCat unavailable'),
        recordError: (error, _, {reason}) => reportedErrors.add(error),
      );

      final result = await service.fetchOfferings();

      expect(result, isA<OfferingsFetchFailure>());
      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single, isA<StateError>());
    },
  );
}
