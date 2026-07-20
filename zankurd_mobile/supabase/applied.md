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
| delete_my_account_rpc.sql | ✅? | Ayarlar'daki hesap silme buna dayanıyor |
| leaderboard_view.sql / leaderboard_period_rpc.sql | ✅? | Liderlik canlıda çalışıyor |
| daily_spin_rpc.sql | ✅? | Çark canlıda çalışıyor |
| 2026-07-10_weekly_league.sql | ? | pg_cron adımı Studio'da ayrı — doğrulanmadı |
| 2026-07-14_room_timer_speed_scoring.sql | ? | doğrulanmadı |
| 2026-07-14_tournament_integrity_hardening.sql | ? | doğrulanmadı |
| Diğer tüm .sql dosyaları | ? | tek tek doğrulanmadı |
| 2026-07-21_room_cleanup.sql | ❌ | Henüz uygulanmadı (bu denetimde yazıldı) |
| 2026-07-21_strip_asta_prompt_prefix.sql | ❌ | Henüz uygulanmadı (offline banka temizliğinin canlı eşi) |
