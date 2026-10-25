# Gece çalışması — 2026-10-25

Orkestra: şef Claude Opus 5.5; ürün/tasarım kurulu Codex + Gemini 4 Argon;
Kurmancî denetim Gemini 3.8 Flash + Grok 4.7, uyuşmazlıkta hakem Gemini 4
Argon; kod ikinci gözü Codex ve Gemini 4 Argon. Commit/push yapılmadı;
canlı veritabanına, mağazaya dokunulmadı.

## Yapılanlar

| Alan | Değişiklik | Dosya |
|---|---|---|
| Satın alınan görünüm | Altın/neon çerçeve çift kontur (gradyan dış halka + koyu ayırıcı + iç tel), VIP rozeti avatarın sağ altında; sıralama, podyum, 1v1, oda, eşleşme, sonuç, profil, mağaza önizlemesi | `widgets/player_avatar.dart`, `game/avatar_frames.dart`, 9 ekran |
| Kelime tekrarı | Kutuya göre tür: 1 anlam, 2 geri çağırma, 3 dinleme (Hawar varyantlı şıklar), 4+ harf dizme; bitişte kelime özeti; kayıt sürerken "Sonraki" kapalı | `data/word_drill.dart`, `screens/word_drill_screen.dart` |
| Alfabe | Harfe dokununca kayıtlı örnek kelime seslenir; harf kelime içinde vurgulanır; e/ê, i/î, u/û, c/ç, s/ş çiftinin örneği yan yana | `widgets/lesson_vocab_tiles.dart` |
| Hikâye | Geçilen adımlar sohbet akışı (anlatı solda, oyuncu sağda), Kurmancî metin sözlüğe dokunulur | `screens/story_screen.dart` |
| Ders yolu | Beşerli üniteler, ünite başlığı + ilerleme | `screens/learning_screen.dart` |
| Profil | Son 7 gün etkinlik şeridi | `screens/profile/profile_week_strip.dart` |
| Günün turu | Oynamadan önce önizleme: bitiren sayısı (0/1/çok ayrı cümle), dünün birincisi, geri sayım; bugünkü skor yok | `widgets/daily_event_board.dart`, `screens/contest_screen.dart` |
| Sözlüklü metin | Fazla boşluk ve şişkin satır aralığı giderildi | `widgets/lexicon_lookup.dart` |
| Quiz sayacı | Rehber ertelemesinde çift başlatma ve bayat süre dolumu koruması (bugün tetiklenmeyen yol, savunma) | `screens/quiz_screen.dart` |

## Kurmancî (iki model onaylı)

`Pembeya gulê`, `Şitil`, alfabe örnek listesi, `Îro {count} kesan ev ger
qedand.`, `Îro kesekî ev ger qedand.`, `Îro hîn tu kesî neqedandiye. Bibe
yekem!`, `Ev wate bi Kurmancî kîjan peyv e?`, `Guhdarî bike û nivîsîna rast
hilbijêre.`, `Tîpan rêz bike û peyva Kurmancî binivîse.`, `Tîpa dawî jê
bibe`, `Beşa {n}`, `7 rojên dawî`.

## Pro paketi (öğleden sonra, kurul kararı)

- Eklendi: **Serbest kelime pratiği** (Kelimelerim): tüm kelimeler ya da
  yalnız zorlandıkların (1. kutu), oturum 15 kelime, kutu/vade değişmez.
  Yalnız aboneye görünür; paywall'da fayda olarak yazılı.
- Reddedildi: Pro'ya fazladan joker (tek kişilik XP sıralamaya yazıldığı
  için parayla sıralama avantajı), Pro çerçevesi (sunucu çerçeve listesi
  kısıtı; canlı göç ister), Kelimelerim'de kilitli satış satırı (paywall'a
  üçüncü giriş App Review yol tarifini bozar).
- Metin bekçisi "sınırsız/bêsînor" sözünü yasaklıyor; fayda "Serbest kelime
  pratiği" adıyla yazıldı.

## Sahibin kararı gereken öneriler

1. **Pro'yu güçlendirmek** için sıradaki adaylar sunucu ister: Pro'ya özel
   çerçeve (çerçeve listesi göçü), çevrimdışı ders paketi.
2. **Mağaza kataloğu**: 4 ürün. Yeni kozmetikler ekonomi kararı.
3. **Soru öner → "Önerilerim"** (durum: alındı/inceleniyor/yayında): sunucu
   tablosu/RPC gerektirir.
4. **Ders sonunda yanlışları yeniden sorma** ve ünite sonu kontrol testi:
   quiz akışına dokunur.
5. **Cümle düzeyinde ses**: kendi TTS hattı (VoxCPM2 + LoRA, MMS denetimi)
   ders cümlelerine genişletilirse dinleme soruları derslere de girer.
6. `awardXpDurable` hiç çağrılmıyor (ölü kod): silinsin mi bağlansın mı.
