# Canlıya uygulanma manifesti (supabase/)

> 2026-07-21 denetiminde oluşturuldu. Kaynak: CURRENT_STATUS.md, CLAUDE.md ve
> hafıza kayıtları. **"?" işaretliler doğrulanmadı** — canlı şemayla
> karşılaştırılıp güncellenmeli. Yeni migration uyguladığında bu dosyaya satır
> ekle; bu dosya tek uygulanma kaydıdır.

| Dosya | Canlıda? | Tarih / Not |
|---|---|---|
| 2026-07-03_reward_hardening.sql | ✅ | 2026-07-03 (claim_* RPC'ler, xp, guard trigger'lar) |
| 2026-07-03_matchmaking_fix.sql | ✅ | 2026-07-03 (join_matchmaking + realtime queue) |
| 2026-07-13_curated_question_wave_1.sql | ✅ | 2026-07-15, Management API ile (category_id düzeltmesiyle) |
| 2026-07-16_editorial_content_fix.sql | ✅ | 2026-07-18'de doğrulandı |
| 2026-07-16_editorial_kurmanci_translation.sql | ✅ | 2026-07-18'de doğrulandı |
| 2026-07-16_editorial_kurmanci_translation_followup.sql | ✅ | 2026-07-18'de doğrulandı |
| strip_difficulty_prefixes.sql | ✅ | 2026-06-16 (prefix temizliği, memory kaydı) |
| spend_coins.sql | ✅? | Joker sistemi canlıda çalışıyor; dosya bazında doğrulanmadı |
| submit_answer_function.sql | ✅? | Oda skorlaması canlıda; clamp sürümü (clamp_submit_answer_response_ms.sql) dahil mi doğrulanmadı |
| public_read_policies.sql | ✅? | Anon okuma canlıda çalışıyor |
| delete_my_account_rpc.sql | ✅ | 2026-07-29 canlı fonksiyon ve yalnızca `authenticated` çalıştırma yetkisi doğrulandı; katkı/moderasyon yabancı anahtarları `2026-07-29_client_reward_authority_fix.sql` ile güvenle serbest bırakılıyor. |
| leaderboard_view.sql / leaderboard_period_rpc.sql | ✅? | Liderlik canlıda çalışıyor |
| daily_spin_rpc.sql | ✅? | Çark canlıda çalışıyor |
| 2026-07-10_weekly_league.sql | ? | pg_cron adımı Studio'da ayrı — doğrulanmadı |
| 2026-07-14_room_timer_speed_scoring.sql | ? | doğrulanmadı |
| 2026-07-14_tournament_integrity_hardening.sql | ? | doğrulanmadı |
| Diğer tüm .sql dosyaları | ? | tek tek doğrulanmadı |
| 2026-07-21_room_cleanup.sql | ✅ | 2026-07-21, kullanıcı tarafından Supabase SQL Editor'den elle uygulandı |
| 2026-07-21_room_cleanup_cron.sql | ✅ | 2026-07-21, kullanıcı tarafından uygulandı — `cleanup-stale-rooms` işi saatlik (`17 * * * *`) çalışıyor |
| 2026-07-21_strip_asta_prompt_prefix.sql | ✅ | 2026-07-21, kullanıcı tarafından Supabase SQL Editor'den elle uygulandı — canlı questions.prompt artık offline bankayla eşleşmeli |
| 2026-07-22_multiplayer_integrity_hardening.sql | ✅ | 2026-07-22, Management API ile uygulandı; izinler, RPC'ler, politikalar ve TIMEOUT kısıtı canlı sorguyla doğrulandı |
| 2026-07-26_real_player_tournament.sql | ✅ | 2026-07-26, kullanıcı tarafından Supabase SQL Editor'den elle uygulandı (iki turda: önce şema+RPC'ler, sonra `claim_tournament_reward` sertleştirmesi). **2026-07-27'de canlı sorguyla doğrulandı:** 3 tablo var, üçünde de RLS açık ve politika yalnız `r` (yazma yolu yok), 8 fonksiyonun 8'i var, `claim_tournament_reward` şampiyonluğu `champion_id` üzerinden doğrulayan sürüm. Dosya yeniden uygulanabilir; sütunlar koşullu eklenir. Sağlık raporu: `2026-07-26_tournament_verify.sql` |
| 2026-07-26_tournament_verify.sql | — | Salt okunur doğrulama betiği; şema değiştirmez |
| 2026-07-28_player_tag.sql | ✅ | 2026-07-28, kullanıcı tarafından Supabase SQL Editor'den uygulandı. Oyuncu kodu (`profiles.player_tag`): benzersiz dizin, atama/dondurma tetikleyicileri ve `search_profiles`in kodla arayan yeni sürümü. 2026-07-29 canlı doğrulamasında eksik veya biçimsiz oyuncu kodu sayısı `0`. |
| 2026-07-29_release_readiness_hardening.sql | ✅ | 2026-07-29, kullanıcı tarafından Supabase SQL Editor'den uygulandı. Oda mesajı üyeliği, aktif soru zorlaması, doğrudan yarışma yazımlarının kapatılması, liderlik sınırı ve sunucu fiyatlı coin harcaması. |
| 2026-07-29_shop_purchase_integrity_fix.sql | ✅ | 2026-07-29, Codex tarafından SQL Editor'de tek işlem olarak uygulandı. Canlı ön kontrolde `profiles/shop_items/coin_transactions/spin_wheel_history` kimlik tipleri uyumlu bulundu. Son doğrulamada 9/9 izin ve RPC kontrolü `true`; gelecek tarihli çark, geçersiz satın alma ve sahte VIP satırı `0`; karantina satırı `0`. |
| 2026-07-29_shop_purchase_integrity_preflight.sql | — | Salt okunur ön kontrol betiği; şema değiştirmez |
| 2026-07-29_shop_purchase_integrity_verify.sql | — | Salt okunur doğrulama betiği; şema değiştirmez |
| 2026-07-29_client_reward_authority_verify.sql | — | Salt okunur doğrulama betiği; şema değiştirmez |
| 2026-07-29_client_reward_authority_fix.sql | ✅ | 2026-07-29, Codex tarafından SQL Editor'de tek işlem olarak uygulandı. Canlı doğrulamada yarışma submit kapısı ve yazımsız XP tanımı etkin; istemci tablo yazım yetkisi ve mutasyon politikası `0`; `anon` RPC yetkileri kapalı, `authenticated` yetkileri açık; claim davranışı `false / 0 / NULL`; hesap silme iki `NO ACTION` katkı/moderasyon bağını önce `NULL` yapıyor. Yayın istemcisi sahte senkronizasyon yapmıyor; XP ve öğrenme ilerlemesi açıkça cihaz-yerel tutuluyor. |
| 2026-07-31_tournament_score_authority.sql | ✅ | 2026-08-01, kullanıcı tarafından Supabase SQL Editor'den uygulandı. Turnuva skor tavanı (`least(v_score, questions_per_match * 150)`) ve süresi dolan maçtan sonra `advance_tournament` çağrısı. Uygulanmadan önce `submit_tournament_match` istemcinin bildirdiği skoru sınırsız kabul ediyordu — `p_score = 2147483647` her maçı kazanıp `claim_tournament_reward` üzerinden sınırsız coin bastırabiliyordu. `tournaments` tablosuna `questions_per_match` kolonu ekler (varsayılan 4). |
| 2026-07-31_exposure_hardening.sql | ✅ | 2026-08-01, kullanıcı tarafından Supabase SQL Editor'den uygulandı. Üç okuma yüzeyi: (1) `questions_editorial_backup_20260716` ve `..._phase2` tablolarını siler — bu yedekler `correct_option` taşıyor ve 2026-07-22'deki `revoke select on public.questions`ın dışında kalmıştı; (2) `search_profiles`te LIKE metakarakterlerini kaçırır — `%%` gönderen istemci tüm kullanıcı kütüğünü sayfalayabiliyordu; (3) `profiles.fcm_token` üzerinde kolon bazlı `revoke select`. Yedek tablolar silindi (geri alınamaz); 2026-07-16 editoryal düzeltmesinin geri dönüş kopyalarıydı ve düzeltme 2026-07-18'de canlı doğrulanmıştı. |
| 2026-07-31_chat_moderation.sql | ✅ | 2026-08-01, kullanıcı tarafından Supabase SQL Editor'den uygulandı. Oda sohbeti moderasyonu (Apple 1.2 / Play UGC). Getirdikleri: `blocked_users` ve `message_reports` tabloları (ikisinde de RLS), `chat_message_is_clean` süzgeci + `room_messages` üzerinde BEFORE INSERT tetikleyicisi, `report_room_message` / `block_player` / `unblock_player` RPC'leri, ve `room_messages` okuma politikasının `USING (true)`den oda üyeliğine çekilmesi. Tetikleyici ayrıca `sender_id`, `sender_name` ve `created_at`i sunucuda yeniden yazar — üçü de istemciden geliyordu, yani sohbette kimlik taklidi mümkündü. Uygulanmadan önce bildir/engelle çağrıları `false` dönüyor ve `room_messages` okuma politikası herkese açıktı. |

