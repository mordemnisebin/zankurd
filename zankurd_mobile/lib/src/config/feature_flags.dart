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

/// Haftalık lig (Bronz/Gümüş/Altın) sıralamada ve profilde görünür mü?
///
/// 2026-09-27: kapatıldı. Lig, sıralamayı basamaklara bölen bir katman;
/// oyuncu sayısı az olunca herkes aynı basamakta ("Bronz Lig") kalıyor ve
/// "Bu hafta yarış, lige gir!" çağrısı yeni gelene ne yapacağını
/// söylemiyordu. Sunucudaki haftalık lig hesabı (league_weeks, finalize
/// cron) çalışmaya devam ediyor; yalnız arayüz katmanı gizli. Kitle
/// büyüyünce bu bayrak açılır.
const kWeeklyLeagueEnabled = false;

/// Sırayla düello (async 1v1) Yarış sekmesinde görünür mü?
///
/// 2026-09-27: kapalı başlar. Ekranlar ve veri katmanı hazır, ama sunucu
/// göçü (`supabase/2026-09-28_async_duels.sql` + `_cron.sql`) canlıya
/// henüz UYGULANMADI. Göç olmadan kart açılırsa her dokunuş "Düello
/// başlatılamadı" ile düşer — oyuncu kırık bir özellik görür. Göç
/// uygulanıp `applied.md`ye işlenince bu bayrak `true` yapılır.
///
/// 2026-09-30: `true`. Dört göç (`2026-09-22_xp_and_coin_idempotency`,
/// `2026-09-28_async_duels`, `_async_duels_cron`,
/// `_hidden_categories_inactive`) 2026-09-30'da canlıya uygulandı ve
/// `2026-09-30_async_duels_verify.sql` temiz geçti (bkz. `supabase/applied.md`);
/// eski "ana dala birleştirme" uyarısı kalktı.
const kAsyncDuelEnabled = true;

/// Pro (destekçi aboneliği) ana ekranda ve ayarlarda görünür mü?
///
/// 2026-10-25 (sahip kararı): kapalı. Öğrenme herkese ücretsiz; Pro ancak
/// fiyat, katman, mağaza ürünleri ve sözleşme/vergi/banka tamamlanınca
/// açılır. Kapalıyken paywall'a giden hiçbir giriş görünmez.
const kProEnabled = false;
