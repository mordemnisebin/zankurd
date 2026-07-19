# KIMI3 — ZanKurd Canlı Görsel & Ürün Denetimi (Final Rapor)

## 1. Yönetici özeti

ZanKurd (https://zankurd.com/, Flutter web, v1.9.1+13, main @ ed9a996) 2026-07-19 tarihinde gerçek tarayıcıda (Playwright + headful Chromium, canvas koordinat tıklama) uçtan uca denetlendi: onboarding, auth, ana sayfa, 5 alt sekme, 2 tam solo quiz + ek quiz koşuları, 50 soruluk canlı soru örneklemesi, 1v1 matchmaking, günlük yarışma, turnuva (bracket + maç), çark, mağaza, liderlik (4 filtre), profil, ayarlar, iki-context senkron oda testi (host + guest), performans ve erişilebilirlik ölçümleri. Toplam 369 kanıt dosyası (screenshot + log) üretildi.

Genel tablo: ürün çalışıyor, 0 JS hatası / 0 kırık asset, görsel dil tutarlı ve Kurmancî karakter bütünlüğü sağlam. Ancak üç kritik güven sorunu var: (1) Pêşbirka Rojê kartı boş "Çalakî" ekranı açıyor (ölü özellik), (2) Teknolojî kategorisi canlıda Türkçe meta/test soruları içeriyor, (3) bir quiz koşusunda "Piştre" butonu 5 farklı yöntemle ilerletilemedi. Ayrıca ilk yük ~13 MB ve erişilebilirlik semantiği varsayılan kapalı.

## 2. Tarih

2026-07-19 (tek gün, çok fazlı denetim).

## 3. Canlı adres

https://zankurd.com/ (Flutter web, canvas render, Supabase backend)

## 4. Branch / commit

- Branch: `main`, HEAD: `ed9a996d7a6176941d51de95cda2bb681898e5e6` ("chore: sürüm 1.9.1+13")
- Denetim anında 9 değiştirilmiş Dart dosyası commit'lenmemişti (matchmaking, profile, quiz_widgets, quiz_result, review, settings, shop, notification_service, explanation_ku).
- Flutter 3.44.1 stable / Dart 3.12.1. Ayarlar ekranındaki sürüm (1.9.1+13) pubspec ile birebir aynı ✓.
- Kanıt: `docs/KIMI3_LIVE_AUDIT_BASELINE.md`

## 5. Tarayıcı / viewport'lar

- Playwright + headful Chromium, kalıcı kullanıcı profili (misafir "Denetmen"), ikinci temiz context ("DenetmenB") oda testi için.
- Ana viewport: 390×844 mobil. Spot: 320×568, 768×1024, 1440×900, 844×390 landscape.
- Flutter web canvas olduğu için etkileşim koordinat tabanlı gerçek tıklama/klavye ile yapıldı.

## 6. İncelenen ekranlar

Onboarding (4 sayfa), giriş (e-posta/Google/misafir), misafir isim, ana sayfa (dark/light), Kategorî (8 kategori + alt kategoriler + seviye listesi), quiz ekranı (tutorial, soru, reveal, joker, timeout, sonuç), Pêşbazî hub, Şerê 1vs1 (giriş + bekleme + bot diyaloğu + iptal), Pêşbirka Rojê ekranı, Turnuva (kart + bracket + maç), Çerxa Rojê, Dukan (ürünler + satın alma diyaloğu), Kod ile katıl diyaloğu, Oda (oluşturma + lobi + iki-context oyun + sonuç), Rêz (Roj/Heft/Meh/Heval), Profîl (istatistik, rozetler, Analiza Berfireh), Ayarlar (tüm bölümler, dil/tema geçişi, accordion'lar).

## 7. Açılamayan ekranlar

Yok — tüm hedef ekranlar açıldı. Bilinçli kapsam dışı: Google girişi (gerçek hesap gerekir), çark çevirme (günlük hakkı tüketmemek için), gerçek satın alma, canlı 1v1 eşleşme (60 sn içinde rakip bulunamadı).

## 8. İncelenen akışlar

1. Onboarding → misafir giriş → ana sayfa coach-mark turu.
2. Giriş validasyonu (boş submit, geçersiz e-posta, boş isim).
3. Tema (dark↔light, kalıcı) ve dil (KU↔TR, anında) geçişleri.
4. Tam solo quiz koşuları: tutorial overlay (5 adım), klavye girişi (harf/rakam/Tab/Enter/Escape), çift tıklama, timeout, joker (kullanım + kilitli durum), reveal, 10 soru sonunda sonuç ekranı. (Faz 2 detay notu kayıp; bu akış 39–158 arası screenshot'lardan yeniden sentezlendi — aşağıda §18'e bakınız.)
5. 50 canlı soru örneklemesi (9 kategori).
6. 1v1: rastgele eşleşme → 60 sn bekleme → bot diyaloğu → "Na" ile iptal.
7. Turnuva: katılım → bracket → bot maçı (15 soru).
8. Oda: A host oluşturdu (ZK-PF5V) → B kod ile katıldı (boş/geçersiz/küçük harf testleri) → lobi senkronu (hazır toggle) → eşzamanlı oyun → skor tutarlılığı.
9. Liderlik filtreleri + yenileme davranışı.
10. Mağaza satın alma reddi (yetersiz coin) akışı.
11. Performans (ağ/byte ölçümü) ve erişilebilirlik (semantik ağaç, Tab sırası, zoom %200, dokunma hedefleri).

## 9. Konsol / ağ bulguları

Kanıt: `_console_network_log.jsonl` (340 satır).

- Faz 1 (ana akışlar): **0 JS hatası, 0 pageerror, 0 requestfailed, 0 HTTP≥400, 0 CORS, 0 kırık asset.** Sadece Firebase init debug logları.
- Turnuva maçı sırasında tekrarlı HTTP 400: `quiz_eligible_questions?is_approved=eq.true&category_id=eq.Ziman` (3× üst üste) ve `favorite_questions?question_id=eq.offline_5832 / offline_curated_20097` — offline soru id'leriyle favori sorgusu 400 dönüyor; UI sessiz fallback ile devam ediyor (kullanıcıya yansımıyor). P2.
- Oda testinde: `rpc/join_room_by_code` 400 (geçersiz kod "XXXXXX" — beklenen validasyon) ve oyun sırasında `rpc/submit_answer` 400 fırtınası (A ve B context'lerinde art arda ~10 istek) — skor yine de doğru senkronize oldu; muhtemelen retry/idempotency gürültüsü. P2 (incelenmeli).
- Performans koşusunda 48 isteğin tümü <400. ✓

## 10. En güçlü 10 yön

1. **Sıfır kırık**: ana akışlarda 0 JS hatası / 0 başarısız istek / 0 kırık asset (faz 1 logu).
2. **Oda multiplayer'ı gerçekten çalışıyor**: iki context'te aynı soru senkronu, hazır toggle senkronu, skor/sıralama tutarlılığı kanıtlı (218-A/B, 220-A/B).
3. **Onboarding + coach-mark**: 4 sayfalı onboarding (8/10) + ilk açılış coach-mark turu, "Derbas bike" her sayfada.
4. **Validasyon kalitesi**: giriş/isim/kod formlarında inline + snackbar çift geri bildirim, hata mesajları Kurmancî ve net.
5. **Tema ve dil altyapısı**: dark/light anında ve kalıcı; KU/TR geçişi tüm UI'da anında; dark tema kontrastı iyi (341, 342).
6. **Kurmancî karakter bütünlüğü**: ç/ê/î/ş/û genel olarak sağlam; 50 soruda büyük karakter bozulması yok.
7. **Dürüstlük etiketleri**: "Bot kûpa" rozeti, bot-onay diyaloğu, çark ödül notu — kullanıcıyı yanıltmama çabası.
8. **Empty-state tasarımı**: Rêz/Heval "Heval tune" kartı, az kullanıcılı dönemde podyum render'ı çökmüyor.
9. **Responsive olgunluk**: 320/768/1440 viewport'larda taşma yok, 1000px içerik sınırı, zoom %200'de yatay scroll yok.
10. **CTA hiyerarşisi**: ana sayfada "Destpêk bike" net, alt nav 5 sekme tutarlı, geri dönüşler çalışıyor.

## 11. En ciddi 10 sorun

| # | Öncelik | Sorun | Kanıt |
|---|---|---|---|
| 1 | P0 | Quiz'de "Piştre" butonu bir koşuda ilerlemedi: tek tık, çift tık, Enter, uzun bekleme, Alt+Y — hiçbiri sonraki soruya geçirmedi (faz 2 detay notu kayıp; kanıt dosya dizisi) | 139–144-r4-pistre-* |
| 2 | P1 | Pêşbirka Rojê kartı ("10 pirs") boş "Çalakî" ekranı açıyor: "Hîn çalakî tune", CTA yok, ölü özellik | 130–133 |
| 3 | P1 | Teknolojî kategorisi canlıda Türkçe meta/test soruları ("Kaynak sütunu CSV'de ne işe yarar?") | q21–q24 |
| 4 | P1 | Tarayıcı Geri sonrası tamamen beyaz boş sayfa; reload gerekli (SPA route stack) | 27-back-home |
| 5 | P1 | Rêz filtre değişiminde loading takılıyor: Heval filtresi 8 sn gri boş ekran; Heft'e dönüşte de gri kalıyor | 308–311 |
| 6 | P1 | İlk yük ~13 MB (canvaskit.wasm 7,2 MB + main.dart.js 4,9 MB), ilk anlamlı frame 6–9 sn | faz4 §22 |
| 7 | P1 | Erişilebilirlik semantiği varsayılan kapalı; "Enable accessibility" butonu klavye/fareyle ulaşılamaz (1×1 px, viewport dışı) | 402, 410 |
| 8 | P1 | Kategori kartları ekran okuyucuda `button` değil `group` rolünde — tıklanabilir oldukları duyurulmuyor | faz4 §23 |
| 9 | P2 | 1v1 "Zindî" etiketi beklenti şişiriyor: 60 sn'de canlı rakip yok, bot teklifine düşüyor | 111–121 |
| 10 | P2 | Soru içeriği şablon/tahmin edilebilir: doğru cevap ~%90 en uzun şık; T/F kalıpları ("were nirxandin"→Rast, "dûr e"→Şaş) kalıptan çözülebilir | q09–q50 |

## 12. Ekran puan tablosu (/10)

| Ekran | Puan |
|---|---|
| Onboarding | 8 |
| Giriş | 9 |
| Misafir isim | 9 |
| Ana sayfa (dark) | 9 |
| Ana sayfa (light) | 8 |
| Kategorî | 8 |
| Quiz (soru/reveal) | 8 |
| Quiz sonuç | 8 |
| Pêşbazî hub | 9 |
| Şerê 1vs1 | 7 |
| Pêşbirka Rojê | 3 |
| Turnuva | 7 |
| Çerxa Rojê | 6 |
| Oda (lobi+oyun) | 8 |
| Rêz (liderlik) | 6 |
| Profîl | 8 |
| Dukan | 7 |
| Ayarlar | 9 |
| Responsive 320 | 8 |
| Responsive 768 | 9 |
| Responsive 1440 | 9 |
| Landscape 844×390 | 7 |

## 13. Ana sayfa

- Mevcut durum: karşılama + avatar, KU toggle, tema toggle (çalışıyor), rozetler (Zincir/Xeruz/Misyon), "Dersê rojane" ana CTA, "Zû bîlize", "Getina Rojê", top-3 liderlik, coach-mark turu ilk açılışta.
- Kullanıcı etkisi: "Öğren / Yarış / İlerle" vaatleri ilk ekranda karşılanıyor; yeni kullanıcı yönlendirmesi güçlü.
- Bulgular: light temada "Dersê rojane" hero kartı koyu kalıyor (P3, 23); landscape'te CTA alt nav ile çakışıyor (P3, 36); ilk açılış ~6–9 sn (P1, §31).
- Kanıt: 18–35. UI-only. Öneri: hero kart tema renklerine bağlansın; landscape'te CTA için safe-area/bottom padding.
- Kabul kriteri: light temada hero kart light yüzeyde okunur; 844×390'da CTA tamamen görünür ve tıklanabilir.

## 14. Bilgi mimarisi

- Alt nav 5 sekme (Sereke/Kategorî/Pêşbazî/Rêz/Profîl) net ve tutarlı; tab semantiği ekran okuyucuda tablist olarak doğru.
- Sorun: Pêşbirka Rojê kartı başlığı ile açtığı ekran ("Çalakî") isim uyuşmuyor (P3); "Günlük yarışma" beklentisi boş aktivite ekranına düşüyor (P1, §22).
- Tarayıcı Geri bozuk (P1, 27-back-home) — web'de route stack güveni kırılıyor.
- Öneri: kart↔ekran isim eşleşmesi; web `history` entegrasyonu için route stratejisi gözden geçirilsin (logic-sensitive: route isimleri — sadece plan + geri/ileri navigation regression testi).

## 15. Onboarding / auth

- Onboarding 4 sayfa, skip her sayfada, nokta göstergeleri doğru (01–08). Puan 8.
- Sorun: reload sonrası onboarding sayfa 2'den açıldı — persist edilen indeks tutarsız (P2, 10/11).
- FAZ3B'de B context'inde "Derbas bike" 2 tıkta tepki vermedi; "Piştre" ile ilerlendi (tek context, doğrulanamadı — P2 şüphe).
- Giriş: boş submit → "E-peyam pêwîst e"; geçersiz e-posta → kırmızı border + inline mesaj (13/14). "123" şifre sonrası mesaj "Şifre pêwîst e" — min-length yerine "pêwîst" görünüyor; mesaj ayrıştırması iyileştirilebilir (P3).
- Misafir isim: boş isim inline hata, 2 karakter minimum (15/16). Seviye/placement akışı misafirde çıkmadı (not edildi).
- Kabul kriteri: reload sonrası onboarding her zaman sayfa 1'den (veya tamamlanmışsa hiç) açılır; skip tek tıkta çalışır; şifre hatası "en az X karakter" olarak ayrı mesaj verir.

## 16. Öğrenme alanı

- Mevcut durum: **yok**. Onboarding "Hîn bibe" vaat ediyor ama üründe oku/izle → soru çöz döngüsü bulunmuyor.
- Profilde FÊRBÛN menüsü (Pirsên Tomarkirî, Şaşiyên Min 0/14, Pirs Pêşniyar Bike) var; yanlış tekrarı ekranı mevcut ama bağımsız öğrenme modu değil.
- Kullanıcı etkisi: Kurmancî eğitim misyonu quiz-only kalıyor; Pirs'in en güçlü farkı (LearningZone) karşılıksız.
- Öncelik: P1 (ürün stratejisi). UI-only yeni modül. Öneri: kategori bazlı kısa ders kartları + ders sonrası mini quiz.
- Kabul kriteri: en az 1 kategoride öğrenme içeriği → ilgili quiz akışına bağlanmış; tamamlama durumu profilde görünür.

## 17. Kategoriler

- 8 kategori, soru sayıları görünür (Ziman 1083, Paradîgma 521, Siyaset 499, Muzîk 491, …, Teknolojî 23). Alt kategori → 5 ast (seviye) yapısı Pirs ile uyumlu (47–50, 430–436).
- Sorun: seviye ilerlemesi hep "0" görünüyor (faz4 tablosu, madde 1) — ilerleme kaydı UI'da çalışmıyor (P2, logic-sensitive: ilerleme yazımı — plan + test).
- Sorun: Teknolojî (23 pirs) meta/test içeriği barındırıyor (P1, q21–q24).
- Erişilebilirlik: kategori kartları `group` rolünde, button olmalı (P1).
- Kabul kriteri: Teknolojî yayına hazır içerikle dolana dek gizli; kategori kartları SR'da "button, Ziman, 1083 pirs" diye okunur; bir quiz tamamlanınca seviye ilerlemesi artar.

## 18. Quiz deneyimi

**Not:** Faz 2 quiz akışı detay notu kayıp (ajan kesildi). Bu bölüm 37–158 arası screenshot dosya adlarından ve konsol logundan dürüstçe yeniden sentezlendi; "not edilemedi" denen yerler doğrulanamadı.

- Tutorial overlay 5 adım ("Demjimêr 1/5", "Bersiv Hilbjêre 2/5" …) ilk girişte gösteriliyor (51–55). Olumlu; ancak oda oyununda sayaç tutorial arkasında işlemeye devam ediyor (P2, 218-B).
- Soru ekranı: 4 şık veya Rast/Xelet, süre sayacı, üstte Pûan/Rêz/Coin canlı sayaçlar (56, 60, 62…).
- Klavye: harf (a), rakam (1), Tab, Enter, Escape testleri yapılmış (57, 58, 86–88); sonuçlar not edilemedi (detay notu kayıp) — screenshot'larda reveal'a geçildiği görülüyor, Escape davranışı doğrulanamadı.
- Çift tıklama reveal'ı tetikliyor/engelliyor mu: 89-q1-doubleclick-reveal ve 141-r4-pistre-dblclick var; net sonuç not edilemedi.
- Timeout: süre dolunca soru otomatik "Şaş" sayılıyor (63, 94, 114-r3-q3-timeout) — tasarım gereği, çalışıyor.
- Joker: kullanım (67-q5-joker1) ve kilitli durum (96-q4-joker-locked) görüntülendi; jokerler coin ile açılıyor (20c–40c, turnuva gözlemi).
- **P0 — "Piştre" ilerlememe**: r4 koşusunda reveal sonrası "Piştre" tek tık (140), çift tık (141), Enter (142), uzun bekleme (143), Alt+Y (144) ile ilerletilemedi; koşu terk edilip r5 başlatıldı (145). Başka koşularda (r3, turnuva) Piştre çalıştı — koşula/duruma bağlı. Logic-sensitive (quiz state machine): önce reprodüksiyon + state loglama, sonra minimal düzeltme.
- Reveal: doğru yeşil / yanlış kırmızı geri bildirim tutarlı (59, 61, 65, 68, 151).
- Açıklama (şîrove): 50 soruluk gözlemde reveal sonrası açıklama UI'ı hiç görünmedi (P0 Piştre hatası nedeniyle ileri akış doğrulanamadı); "!" ikonu açıklama değil "Pirsê ragihîne" diyalogu açıyor (90, 121-r3-q4-info). Şîrove görünürlüğü doğrulanamadı — not edilemedi.
- Sonuç ekranı: 84-final, 111-result-1, 135-r3-result mevcut; puan/istatistik render oluyor.
- Günlük quiz deterministik: Dersê rojane Q1 iki ayrı koşuda aynı soru ("pîr") — P1 tekrar (146 ve faz2 notu, 173 referansı).
- Kabul kriteri (P0): 20 ardışık quiz koşusunda (solo + oda + turnuva) Piştre %100 ilerler; takılmada state logu üretilir.

## 19. İçerik ve Kurmancî kalitesi

Kanıt: `KIMI3_LIVE_QUESTION_SAMPLE_AUDIT.md` (50 canlı soru).

- Olumlu: karakter bütünlüğü sağlam (0 büyük hata); çekirdek kelime havuzu (pisîk, kanî, nan, berf…) doğru ve öğretici; aynı soruda yinelenen şık yok; görselli sorular (q34, q36, q47) düzgün render.
- P1: Teknolojî kategorisi Türkçe meta/test soruları (q21, q22, q24).
- P2: dil karışımı ~%40 (Kurmancî kök + Türkçe şık); tamamen Türkçe soru ~%14 (q33 "Şerefname…", q49).
- P2: şablon soru kökü 8/50 ("Di asta X de, ji bo dersa Y kîjan vebijark…"); T/F kalıbı 12/50 tahmin edilebilir; doğru cevap sistematik en uzun şık (~9/10); çeldirici tekrarı 3 grup (q35/q48/q50-A aynı metin).
- P2: kategori↔içerik uyumsuzluğu ~%24 (Rêziman'da kelime çevirisi, Paradîgma'da kimya, Çand'da müzik aleti).
- Tek tek şüpheliler: q10 (çift doğru riski: sar/hênik), q39 (anlamsız önerme), q37 ("mîrgeh"?), q34 ("vegottinê"?), q27 ("çêtir" doğal değil), q36/q47 (Türkçe gömülü meta-kategori soruları), q12 (5 satır kök + heterojen şıklar).
- Öncelik: içerik düzeltmeleri UI-only değil **veri** işidir; soru bankası düzenleme akışı (mevcut adjudication raporları) ile yürütülmeli.
- Kabul kriteri: 50 soruluk örneklem tekrarında meta içerik 0, Türkçe-only soru 0 (tasarım gereği vocab hariç, dokümante), en-uzun-şık oranı <%40, kategori uyumsuzluğu <%5.

## 20. Sonuç ekranı

- Mevcut durum: puan/seri özetleri render oluyor (84-final, 111/112, 135/136). Oda sonucunda "TU BI SER KETÎ / TE WINDA KIR" ekranları iki tarafta tutarlı (220-A/B).
- Bulgu: A'ya gerçek insan rakibe karşı "Bot Têk Bir" rozeti verildi — rozet mantığı yanlış (P2, logic-sensitive: rozet/achievement koşulu — plan + test).
- Bulgu: oda ara ekranında soru ilerleme segmenti A ve B'de farklı göründü (doğrulanamadı, zamanlama olabilir).
- Öneri: sonuç ekranına "yanlışları tekrar et" CTA'sı (Şaşiyên Min'e bağlantı) — öğrenme döngüsünü kapatır.
- Kabul kriteri: insan rakibe karşı bot rozeti verilmez; sonuç ekranından yanlış tekrarına tek dokunuş.

## 21. Multiplayer ve oda

- Kanıtlı çalışanlar: oda direkt oluşuyor (kategori/süre/zorluk seçim ekranı YOK — ara adım atlanıyor, P2 UX); kod büyük/sarı + kopyala ikonu (paylaş butonu yok, P3); boş kod inline hata; geçersiz kodda diyalog kapanıp input siliniyor (P3); küçük harf kod kabul ediliyor ✓; lobi senkronu anlık; hazır toggle senkronu ✓; guest başlatamıyor ✓; soru ve skor senkronu kanıtlı.
- Bulgular: host, guest "Li bendê" iken başlat butonu aktif (test edilmedi — P2 şüphe); B tarafında "Mêvandar" zorluk çipi görünmüyor (P3); lobi "30 sn" ↔ oyun içi 15 sn tutarsızlığı (P2, iki context'te doğrulandı); tutorial sayacı yiyor (P2); `submit_answer` 400 fırtınası (P2, §9).
- Logic-sensitive: `subscribeRoomPlayers`, `join_room_by_code`, `submit_answer` RPC'leri — sadece plan + regression testi; yüzeysel öneri: tutarsız süre sabitleri tek kaynaktan okunsun.
- Kabul kriteri: lobi süresi = oyun içi süre; hazır olmayan oyuncu varken host başlatamaz (veya bilinçli uyarı); iki context'te tutorial sayaç duraklatır.

## 22. Günlük yarışma ve turnuva

- **Pêşbirka Rojê (P1)**: kart "10 pirs" vaat ediyor; açtığı ekran "Çalakî" başlıklı ve BOŞ ("Hîn çalakî tune — Sibê çalakiya nû tê"), CTA yok, 3 tık hiçbir şey değiştirmedi (130–133). Ölü/yarım özellik; isim tutarsızlığı da var.
- **Turnuva (7/10)**: kart dürüst ("Bot turnuva · rojane kûpa", "Her Şemî 20:00", geri sayım); bracket açılıyor (16 bot, 4 tur); bot isimleri gerçekçi (Azad, Rojîn…) ama bracket satırlarında bot ibaresi yok (P3, küçük yanıltma); maç standart quiz ekranı — rakip skoru/versus göstergesi/tur ilerlemesi görünmüyor (P2); ödül somut yazmıyor ("şampiyon kûpayê digire", coin/puan yok, P3); maç sonu gözlemlenemedi (bütçe).
- Çerxa Rojê: günlük hak/geri sayım göstergesi yok, "Bizivirîne!" hep aktif görünüyor (P3); kart "100 coin" ama 100 sadece bir dilim (P3).
- Kabul kriteri: Pêşbirka Rojê ya 10 soruluk gerçek günlük yarışma açar ya da kart kaldırılır/"yakında" işaretlenir; turnuva maçında rakip skoru ve tur göstergesi görünür; çarkta kalan hak/geri sayım gösterilir.

## 23. Liderlik

- 4 filtre (Roj/Heft/Meh/Heval); "Hemû dem" filtresi yok (P3). Podyum + liste render'ı sağlam; az kullanıcılı dönemde çökme yok (306). Uzun isimler taşmadan sığıyor.
- **P1**: filtre değişiminde loading takılıyor — Heval 8 sn gri boş ekran, Heft'e dönüşte de gri (308–311). Refresh sonrası içerik geliyor ve Heval empty-state düzgün (312). Yani sorun empty-state değil, yükleme durumu.
- "Her 30 çirkeyî nûve dibe" iddiası var; otomatik yenileme gözlemlenmedi (not edilemedi).
- Kendi sıram göstergesi yok — ilk 10 dışındaki kullanıcı sırasını bulamıyor (P2).
- Empty-state dili karışık: Kurmancî başlık + Türkçe açıklama (P3, 312).
- Logic-sensitive: liderlik sorguları/yenileme — plan + loading-timeout testi. Kabul kriteri: filtre geçişi <2 sn içinde içerik veya empty-state gösterir; asla süresiz gri ekran kalmaz.

## 24. Profil

- Üst kart net (avatar, isim, misafir uyarısı, Ast 1 · 190/1000 XP). Statistîk 2×2: Rêze "—" (boş, P3), Tevayî Xal 190, Baştirîn Zincir 0, Listik 0. **Coin ve doğruluk yüzdesi yok** (P2).
- Rozetler: 2/8 kazanılmış; "Bot Tek Bir" rozet adı Türkçe karışmış (P3). Analiza Berfireh akordeonu çalışıyor (318/319). FÊRBÛN ve HESAB menüleri düzenli; çıkış kırmızı.
- Kabul kriteri: istatistik kartlarına coin + doğruluk; Rêze 0 yerine anlamlı gösterim; rozet adları tek dil.

## 25. Mağaza

- Bakiye bandı net (55 coin). Sadece 3 ürün (Rozeta VIP 1000c, Carçoveya Zêrîn 750c, ekstra çark 200c) — katalog çok küçük (P2 ürün stratejisi). Ürün adı ellipsis kesiliyor, tam adı görme yolu yok (P3, 323). "BABETÊ HERÎ BABET" rozeti anlamsız tekrar (P3).
- Satın alma reddi doğru çalışıyor: yetersiz coinde kırmızı snackbar "Bakîyeya te kêm e!", bakiye değişmedi (325–329). Bikire yetersizde disabled değil (P3, kabul edilebilir). Canlı önizleme yok.
- Logic-sensitive: coin RPC/economy — dokunma; sadece test. Kabul kriteri: ürün adı tam okunur; sahip olunan ürün işaretli; yetersiz bakiye reddi regression testte sabit.

## 26. Ayarlar

- En güçlü ekran (9/10): bölümler tam (HESAP/HÎNBÛN/EWLEKARÎ/DÎMEN/DENG/DERBARÊ), sürüm pubspec ile aynı, dil ve tema geçişi anında + kalıcı, accordion'lar düzgün (330–345).
- Eksikler: ayrı titreşim toggle'ı yok, ses/müzik tek birleşik toggle (P3); destek/şartlar linki ilk bakışta yok (P3).
- Kabul kriteri: değişiklik yok şart değil; eklenirse ayrı ses/müzik toggle'ları.

## 27. Loading / empty / error / offline

- Empty-state'ler iyi tasarlanmış (Heval tune; az kullanıcılı podyum). Loading takılması Rêz'de P1 (§23). Offline: `offline_*` soru id'leriyle fallback mevcut ama favori sorguları 400 üretiyor (P2); gerçek offline davranış test edilmedi — not edilemedi.
- Kabul kriteri: tüm liste ekranlarında loading ≤2 sn + skeleton/empty; offline'da favori sorgusu atlanır.

## 28. Light / dark tema

- Toggle çalışıyor, kalıcı, ayarlar/profil/ana sayfada tutarlı (21–23, 335–343, 341/342 dark kontrast iyi).
- Bulgular: light'ta "Dersê rojane" hero koyu kalıyor (P3); sistem `prefers-color-scheme`'e otomatik yanıt yok gibi (P3, doğrulama sınırlı — canvas render nedeniyle kesin ölçüm yapılamadı).
- Kontrast oranları sayısal ölçülemedi (canvas) — sınırlama olarak kayıtlı.

## 29. Responsive

- 320×568: taşma yok, zarif ellipsis (8/10). 768: 2 sütun grid (9/10). 1440: ~1000px sınır (9/10). Landscape 844×390: CTA alt nav'a yapışık/kesik (7/10, P3). Zoom %200: yatay scroll yok ✓.
- Kabul kriteri: landscape'te CTA tam görünür.

## 30. Erişilebilirlik

- **P1**: semantik ağaç varsayılan kapalı; "Enable accessibility" butonu 1×1 px, viewport dışı — fare/klavyeyle ulaşılamaz (sadece JS ile tıklanabildi). Ekran okuyucu kullanıcısı için sayfa tamamen boş.
- **P1**: kategori kartları `group` rolünde (button olmalı).
- **P1**: "Hemûyê bibîne ›" 102×17 px ve misyon satırı 32 px yükseklik — 44px dokunma kuralı altında.
- P2: focus halkası 1 px çok ince; bazı ikon butonlarda aria-label eksik.
- P3: ilk 2 Tab durağı ölü (FLUTTER-VIEW).
- Olumlu: semantik açıldığında 40 node, anlamlı roller (tablist, progressbar, button); Tab sırası mantıklı; üst bar 44×44 ✓.
- Sınırlamalar: NVDA/VoiceOver testi yapılamadı; kontrast sayısal ölçülemedi.
- Kabul kriteri: `auto` semantics etkin; kategori kartları button; tüm etkileşim hedefleri ≥44 px; focus 2–3 px.

## 31. Performans

- DOMContentLoaded ~393 ms; networkidle ~5,0 sn; etkileşime hazır ~3,1 sn; cache'li reload 175 ms; 48 istek, 0 başarısız ✓.
- **P1**: kritik yük ~13 MB (canvaskit.wasm 7,23 MB br + main.dart.js 4,93 MB br); soğuk headful'da ilk anlamlı frame 6–9 sn.
- P2: 4 Rubik ağırlığı ~700 KB (Black seyrek); route geçişleri 2–2,5 sn (42 fetch — önbellek yok gibi).
- Öneri: HTML renderer/canvaskit lite değerlendirmesi, `--tree-shake-icons` doğrulaması, font subsetting, route verisi önbelleği.
- Kabul kriteri: ilk yük ≤6 MB; route geçişi <1 sn (tekrar ziyarette); ilk anlamlı frame <3 sn (3G throttling'de ölçüm).

## 32. Pirs karşılaştırması

Özet (faz4 Aşama 20, 13 ilke): Mevcut ve güçlendirilmeli: seviye sistemi (ilerleme görünür çalışmalı), turnuva takvimi (geçmiş turnuvalar + kazananlar görünürlüğü). **Doğrudan alınmalı**: öğrenme alanı (LearningZone), yer işareti/yanlış tekrarı bağımsız modu. **Uyarlanmalı**: Soru Değiştir/Çift Cevap jokerleri (coin dengesiyle), web push ile günlük soru/turnuva hatırlatması, bot ile garanti oyun. **Alınmamalı**: matematik modu (odak dışı), reklam (premium his). Görsel dil kopyalanmayacak.

## 33. P0

1. **Quiz "Piştre" ilerlememesi** (139–144): koşula bağlı; 5 etkileşim yöntemi başarısız. Logic-sensitive (quiz state machine). Çözüm: reprodüksiyon senaryosu + state transition loglama; düzeltme sonrası 20 koşuluk regression (solo/oda/turnuva). Kabul: %100 ilerleme.

## 34. P1

1. Pêşbirka Rojê → boş "Çalakî" ekranı (130–133). UI-only. Kabul: gerçek 10 soruluk akış veya kart "yakında".
2. Teknolojî meta/test soruları canlıda (q21–q24). Veri. Kabul: kategori gizli ya da içerik değişmiş.
3. Tarayıcı Geri → beyaz sayfa (27). Logic-sensitive (routing). Kabul: geri/ileri navigation regression testi.
4. Rêz filtre loading takılması (308–311). Kabul: <2 sn içerik/empty; timeout fallback.
5. İlk yük ~13 MB (§31).
6. Semantics kapalı + ulaşılamaz "Enable accessibility" (402).
7. Kategori kartları button rolünde değil (faz4 §23).
8. Günlük quiz deterministik tekrar — Q1 hep aynı (146). Logic-sensitive (soru seçimi). Kabul: art arda 3 gün farklı Q1.
9. Dokunma hedefleri: "Hemûyê bibîne ›" 17 px, misyon satırı 32 px.
10. Öğrenme alanı yok (ürün stratejisi, §16).

## 35. P2

1. Soru içeriği: en-uzun-şık, T/F kalıpları, şablon kök, çeldirici tekrarı, kategori uyumsuzluğu, dil karışımı (§19).
2. 1v1 "Zindî" etiketi şişirme (111–121).
3. Turnuva maçı versus hissi yok; bracket'te bot ibaresi yok (150–158).
4. Supabase 400'ler: quiz_eligible_questions retry, favorite_questions offline id, submit_answer fırtınası (§9).
5. Oda: süre tutarsızlığı (30↔15 sn), tutorial sayacı yiyor, host hazırsız guest ile başlatabilir (şüphe), seçim ekranı yok.
6. "Bot Têk Bir" rozeti insana karşı verildi (220-A).
7. Onboarding reload indeksi tutarsız; skip 2 tıkta tepkisiz (şüphe).
8. Liderlikte kendi sıram göstergesi yok.
9. Profilde coin/doğruluk yok; Rêze "—".
10. Route geçişleri 2–2,5 sn; 4 Rubik ağırlığı.
11. Focus 1 px; ikon buton aria-label eksikleri.
12. Seviye ilerlemesi UI'da hep 0.

## 36. P3

1. Light hero kart koyu (23). 2. Landscape CTA kesik (36). 3. Şifre hata mesajı ayrıştırması (14). 4. Çark hak/geri sayım yok; kart "100 coin" şişirme (159–161). 5. Pêşbirka↔Çalakî isim uyuşmazlığı. 6. Heval empty-state dil karışık (312). 7. "Bot Tek Bir" rozet adı (314). 8. Mağaza ürün adı ellipsis; "BABETÊ HERÎ BABET" rozeti (323). 9. Geçersiz kodda diyalog kapanıp input siliniyor (213-B). 10. Guest lobi zorluk çipi eksik (214-B). 11. Oda kodunda paylaş butonu yok. 12. Turnuva ödülü somut değil. 13. Ayrı titreşim/ses-müzik toggle yok. 14. "Hemû dem" filtresi yok. 15. Ölü Tab durakları; sistem tema tercihine otomatik yanıt yok.

## 37. UI-only alanlar

Tema/hero kart rengi, landscape CTA padding, isim eşleşmeleri (Pêşbirka↔Çalakî), empty-state dili, rozet adları, ürün adı ellipsis, focus halkası kalınlığı, dokunma hedefi boyutları, aria rolleri/etiketleri, öğrenme alanı modülü (yeni ekranlar), liderlik "kendi sıram" bandı, çark geri sayım göstergesi, turnuva versus göstergesi (görsel katman).

## 38. Logic-sensitive alanlar

Quiz state machine (Piştre/reveal/timeout), `subscribeRoomPlayers`, matchmaking RPC, `join_room_by_code`, `submit_answer` RPC, coin/XP RPC ve economy, auth akışları, route isimleri/web history, soru seçimi/günlük quiz sıralaması, liderlik sorguları, favori/offline fallback, migration'lar. Bu alanlarda: sadece plan + regression testi; kod değişikliği minimal ve test korumalı.

## 39. Dokunulmaması gereken alanlar

- Oda senkron çekirdeği (iki-context testle kanıtlı çalışıyor) — refactor yok.
- Auth/misafir akışının çalışan kısımları.
- Supabase şema/migration'lar (denetim kapsamı dışı, risk yüksek).
- Coin economy RPC'leri (satın alma reddi doğru çalışıyor).
- Sürüm/build konfigürasyonu (1.9.1+13 tutarlı).

## 40. Screenshot indeksi

Kök: `output/kimi3_live_visual_audit/2026-07-19/` — toplam 369 dosya (368 PNG + 1 JSONL).

| Aralık | İçerik |
|---|---|
| 01–38 | Faz 1: onboarding (01–11), giriş/validasyon (12–14), misafir isim (15–19), ana sayfa dark/light + coach-mark (20–26), geri-butonu beyaz sayfa (27), reload (28), tab'lar (29–32), responsive spot (33–36), quiz smoke (37–38) |
| 39–50 | Faz 2 başlangıç: tab'lar, kategori scroll, Ziman detay, Rêziman ast'lar |
| 51–99 | Faz 2 quiz akışı: tutorial (51–55), koşu 1 soru/reveal/timeout/joker (56–84, sonuç 84-final), koşu 2 klavye/çift-tık/joker-kilitli (85–99) |
| q01–q50 | 50 canlı soru örneklemesi (9 kategori) |
| 100–158 | Ek quiz koşuları (r3–r7): reveal'lar, timeout (114), info diyalogu (121), Piştre takılması (139–144), günlük start (145), oda öncesi koşular, sonuç ekranları (111–112, 135–136) |
| 102–165 | Faz 3A: Pêşbazî hub (102–105), 1v1 bekleme/bot diyaloğu/iptal (110–123), Pêşbirka Rojê boş ekran (130–133), turnuva bracket+maç (140–158), çark (159–161), dukan (162), kod diyaloğu (163–164) |
| 200–220 | Faz 3B: iki-context oda testi (A host/B guest): oluşturma (209), katılım validasyonları (212–214), lobi senkronu (215–217), oyun senkronu (218–219), sonuç tutarlılığı (220) |
| 21–36, 301–351 | Faz 3C: liderlik filtreleri + loading takılması (302–312), profil (313–320), mağaza (321–329), ayarlar + dil/tema/accordion (330–351) |
| 400–436 | Faz 4: performans sonrası durum (400–401), erişilebilirlik öncesi/sonrası (402–412), dark (415), semantics (420–421), kategori (430–436) |
| _console_network_log.jsonl | 340 satır konsol/ağ logu (Firebase debug + §9'daki 400'ler) |

## 41. Önerilen geliştirme sırası

1. P0: Piştre state machine — repro + loglama + düzeltme + 20 koşuluk regression.
2. P1 güven paketi: Pêşbirka Rojê (gerçek akış ya da kart gizle), Teknolojî kategorisini gizle, tarayıcı Geri düzeltmesi, Rêz loading timeout.
3. P1 erişilebilirlik/performans: auto semantics, kategori kartı rolleri, dokunma hedefleri; canvaskit lite/HTML renderer + font subsetting.
4. P1 içerik: günlük quiz tekrarını kır; meta soruları temizle.
5. P2 içerik kalitesi turu: en-uzun-şık, T/F kalıpları, çeldirici tekrarı, kategori uyumu (soru bankası akışıyla).
6. P2 deneyim: oda süre tutarlılığı, tutorial sayaç duraklatma, turnuva versus katmanı, kendi sıram bandı, profil metrikleri.
7. Ürün genişlemesi: öğrenme alanı + yanlış tekrarı modülü (Pirs ilkeleri 2 ve 3).
8. P3 cilalama paketi (§36 listesi).

Detaylı faz planı: `KIMI3_GELISTIRME_PLANI.md`.
