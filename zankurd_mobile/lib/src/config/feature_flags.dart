/// Derleme-zamanı ürün kapıları. Canlı RPC/şema hazır olmadan UI vaat etmesin.
library;

/// `redeem_referral_code` canlıya basılana kadar davet ödülü kartı kapalı.
///
/// SQL: `supabase/2026-09-02_referral_system.sql` (applied.md'de ⏳).
/// Bekçi: `test/referral_and_share_reward_test.dart`.
const kReferralRewardsEnabled = false;
