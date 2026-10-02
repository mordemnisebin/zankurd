import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/durable_write.dart';

void main() {
  test('yetersiz bakiye yeniden denenmez', () {
    final result = coinSpendFromRpc({
      'success': false,
      'error': 'invalid price',
    });

    expect(result.success, isFalse);
    expect(result.retryable, isFalse);
  });

  test('onaylanan harcama yeniden denenmez', () {
    final result = coinSpendFromRpc({'success': true, 'idempotent': true});

    expect(result.success, isTrue);
    expect(result.retryable, isFalse);
  });

  test('okunmayan cevap başarı sayılmaz', () {
    final result = coinSpendFromRpc(null);

    expect(result.success, isFalse);
    expect(result.retryable, isFalse);
  });
}
