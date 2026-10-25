class DurableCoinSpend {
  const DurableCoinSpend({required this.success, required this.retryable});

  final bool success;
  final bool retryable;
}

/// RPC gövdesi bir sonuçtur: yetersiz bakiye veya geçersiz fiyat yeniden
/// denenmez. Ağ hatası bu fonksiyona düşmez; o [RetryableWriteException] olur.
DurableCoinSpend coinSpendFromRpc(Object? response) {
  final success = response is Map && response['success'] == true;
  return DurableCoinSpend(success: success, retryable: false);
}

class RetryableWriteException implements Exception {
  const RetryableWriteException(this.cause);

  final Object cause;
}
