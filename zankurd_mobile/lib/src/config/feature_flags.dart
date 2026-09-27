/// Derleme-zamanı ürün kapıları. Canlı RPC/şema hazır olmadan UI vaat etmesin.
library;

/// `redeem_referral_code` 2026-09-05'te canlıya basıldı (applied.md ✅).
/// Davet ödülü kartı açıktır.
const kReferralRewardsEnabled = true;

/// Eleme turnuvası (16 oyuncu, 4 tur) Yarış sekmesinde görünür mü?
///
/// 2026-09-27: kapatıldı. Turnuva kontenjan dolunca başlıyor; kullanıcı
/// sayısı az olan bir uygulamada kontenjan günlerce dolmuyor ve oyuncu
/// "boş bir salona" bakıyor. Benzer uygulamalarda da (Pirs, Quizduell)
/// küçük kitleyi tutan şey arkadaşla oda ve sırayla oynanan düellodur,
/// kalabalık bekleyen modlar değil. Kod ve sunucu tarafı yerinde duruyor;
/// kitle büyüyünce bu bayrak açılır.
const kTournamentEnabled = false;
