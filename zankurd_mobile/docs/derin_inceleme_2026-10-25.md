# Derin inceleme — 2026-10-25 (akşam)

Orkestra: şef Claude Opus 5.5 (OpenCode). Beş paralel tarayıcı (veri/eşitleme,
quiz/öğrenme, çok oyunculu, içerik/dil, altyapı) kodu salt okudu; ürün
eleştirisi Gemini 4 Argon. Her aday düzeltme Codex + Gemini 4 Argon'a
bağımsız oya sunuldu; yalnız uzlaşılanlar uygulandı. Uygulanan farkın kod
incelemesi Codex ("engelleyici bulgu yok"; Gemini kotası doldu). Kurmancî
değişiklik Gemini 3.8 Flash + Grok 4.7 onaylı. Commit/push yapılmadı; canlı
veritabanına, mağazaya dokunulmadı.

## Uygulananlar

| Kod | Sorun | Düzeltme | Dosya |
|---|---|---|---|
| D1 | Oda/düello maçından sonra `profiles.xp` (yalnız rekabetçi XP) yerel toplamı (solo + görev + terfi) eziyordu; seviye çubuğu geri düşüyor, misafirde kalıcı kayıp | `applyServerTotal` yerel XP'yi asla düşürmez | `data/xp_store.dart` |
| Q1 | Alıştırmada zorluk düğmesine çift dokunuş SM-2'yi iki kez ilerletip soru atlatıyordu | Kilit + düğmenin ait olduğu soru indeksi | `screens/quiz_screen.dart`, `quiz/quiz_screen_ui.dart` |
| Q2 | Sonuç ekranından art arda "yanlışları tekrar et" soruyu aynı gün kuyruktan çıkarıyordu | İlk doğru oturum serbest; kuyruktan çıkaran ikinci oturum vadeyi bekler; yanlış sıfırlaması aynen | `data/mistake_store.dart` |
| Q3 | Alıştırma turu +50 taban XP, ustalık terfisi (+200) ve görev ilerlemesi veriyordu (sonsuz kasma); sıfır doğrulu tur da +50 | Alıştırma: doğru başına 5 XP, terfi/görev yok. Solo: taban yalnız ≥1 doğruda | `screens/quiz_result_screen.dart` |
| Q4 | Süresiz solo turda düşünerek verilen doğru cevap 0 puan | Süresiz solo: doğru = taban 100 (hız yarışı yok); çok oyunculu değişmedi | `screens/quiz_screen.dart` |
| D2 | Ustalaşılan yanlış, sunucudaki eski anlık görüntüyle eşitlenince kuyruğa geri geliyordu | Birleştirme: büyük `missCount` kazanır, eşitse `graduated` kazanır; ustalaşmış kimlik listeden çıkar | `data/progress_snapshot.dart` |
| D4 | Joker ücret anahtarı yalnız soru+tür; aynı soru başka turda çıkınca joker bedava | Anahtara tur kimliği | `quiz/quiz_screen_ui.dart` |
| D5 | Ağ hatası da deneme hakkı yakıyor, kısa kesintide ödüller "eşitlenemedi"ye düşüyordu | Ağ hatasında sayaç artmaz, kalanlar kuyrukta kalır | `data/sync_manager.dart` |
| D9 | Eksik RPC (42883) kaydı listeden siliniyor, PGRST202 tanınmıyordu | İkisi de "senkronize edilemedi" listesine | `data/sync_manager.dart` |
| M1 | Arkadaş isteği ve arkadaş satırında bildir/engelle yoktu (App Store 1.2) | "⋯" ile mevcut moderasyon sayfası | `screens/friends_screen.dart` |
| M2 | Eşleşmede yeniden kuyruğa giriş isteği izlenmiyor, iptal onu beklemiyordu (hayalet kuyruk/oda) | İstek `_joinRequest` ile izlenir | `screens/matchmaking_screen.dart` |
| M3 | Tepki yayını serbest metni ve sahte adı süzgeçsiz çiziyordu | Yalnız beş hazır tepki, alıcının dilinde; ad oyuncu listesinden | `utils/room_reactions.dart`, `room_screen.dart`, `quiz_screen.dart` |
| M4 | Sıralama RPC hatası "Henüz puan yok" gösteriyordu | Hata yukarı taşınır, ekran hata durumunu gösterir | `data/supabase_zankurd_repository.dart`, `leaderboard_screen.dart` |
| C5 | Kaynaklar arası 3 birebir kopya soru | `kolay_dirok_08`, `sf_nat_0005`, `wo-ku-001` emekli; benzersizlik bekçisi | `config/retired_question_ids.dart` |
| C1 | Doğru/Yanlış dengesi tek yönlü denetleniyordu | İki yönlü mandal testi (oynanabilir havuz: genel Şaş %50,3) | `test/true_false_balance_ratchet_test.dart` |
| C8 | Açıklama motorunda `Bersivên rast` (çoğul) ve `Şiroveya` (î'siz) | `Bersiva rast`, `Şîroveya rast` (iki model onaylı) | `l10n/explanation_ku.dart` |
| — | `ci_yerel.sh` şık taraması commit edilmemiş bulgu dosyasını `git checkout` ile siliyordu | Yedekle-geri koy | `tool/ci_yerel.sh` |

Yeni testler: `practice_rating_double_tap`, `quiz_result_practice_xp`,
`untimed_solo_score`, `wildcard_idempotency_key`, `room_reactions`,
`friends_moderation`, `matchmaking_rejoin_cancel`, `leaderboard_load_error`,
`playable_prompt_uniqueness`, `true_false_balance_ratchet`; genişletilen:
`xp_store`, `mistake_store`, `progress_snapshot`, `sync_manager`.

## Sahibin kararı / ayrı tasarım gerekenler

1. **Seri dondurma jetonu eşitlemede geri geliyor** (`progress_snapshot.dart`
   `freeze: max`). Codex RET, Gemini DEĞİŞTİR: aynı gün kazanılan jetonu
   silmeden güvenli birleştirme için sürümlü bakiye ya da işlem kaydı gerekir.
2. **Analitik varsayılan açık, ilk açılışta onay yok** — sahip "olduğu gibi
   kalsın" dedi; yalnız yanlış kod yorumu düzeltildi. AB/GDPR riski kayıtlı.
3. **RevenueCat Pro kapalıyken de çalışıyor** — kapatmak mevcut Pro
   abonelerinin otomatik seri korumasını bozabilir; atlandı.
4. **Göç gerektirenler** (uygulanmadı): sohbet sunucu hız sınırı;
   `save_my_progress` sürüm denetimi; seri onarımında İstanbul günü ile yerel
   gün uyuşmazlığı (diaspora 22:00–24:00); turnuva skorunun sunucuda
   hesaplanması (turnuva açılmadan önce); oda yayın kanalının private
   yapılması; emekli 3 sorunun sunucu karşılığı.
5. **Öğrenme derinliği** (içerik işi, Kurmancî iki model onayı ister):
   dilbilgisi dersleri 2 slaytta kalıyor; gelecek zaman, emir kipi, isim
   bükümü/çoğul, edatlar için ders yok; ay adları dersi 6 ayda kalıyor ve
   takvim başka gelenek kullanıyor; 41 kart arkasında "Çeviri" yerine özet.
6. Küçükler: eşleşme/oda/arkadaş yoklaması arka planda sürüyor (yaşam
   döngüsü); sohbet akışı kapanınca yeniden bağlanmıyor; 20 kullanılmayan
   l10n anahtarı; `supabase/migrations` canlı şemayı temsil etmiyor.
