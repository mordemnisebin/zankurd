import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/network_error.dart';

void main() {
  test('network and offline failures are classified as offline', () {
    expect(isLikelyOfflineError(StateError('network unavailable')), isTrue);
    expect(isLikelyOfflineError(StateError('offline')), isTrue);
    expect(
      isLikelyOfflineError(Exception('SocketException: failed host lookup')),
      isTrue,
    );
  });

  test('domain failures are not relabeled as offline', () {
    expect(isLikelyOfflineError(StateError('purchase rejected')), isFalse);
    expect(
      isLikelyOfflineError(const FormatException('invalid catalog')),
      isFalse,
    );
  });
}
