/// Referans kodu kullanım sonucu.
enum ReferralStatus {
  success,
  alreadyRedeemed,
  ownCode,
  notFound,
  networkError,
}

class ReferralResult {
  const ReferralResult({
    required this.status,
    this.coinsAwarded = 0,
    this.referrerName,
    this.message,
  });

  final ReferralStatus status;
  final int coinsAwarded;
  final String? referrerName;
  final String? message;

  bool get isSuccess => status == ReferralStatus.success;

  factory ReferralResult.fromMap(Map<String, dynamic> data) {
    final success = data['success'] as bool? ?? false;
    if (success) {
      return ReferralResult(
        status: ReferralStatus.success,
        coinsAwarded: (data['coins_awarded'] as num?)?.toInt() ?? 100,
        referrerName: data['referrer_name'] as String?,
      );
    }
    final error = data['error'] as String? ?? '';
    final status = switch (error) {
      'already_redeemed' => ReferralStatus.alreadyRedeemed,
      'own_code' => ReferralStatus.ownCode,
      'code_not_found' => ReferralStatus.notFound,
      _ => ReferralStatus.networkError,
    };
    return ReferralResult(
      status: status,
      message: data['message'] as String?,
    );
  }
}
