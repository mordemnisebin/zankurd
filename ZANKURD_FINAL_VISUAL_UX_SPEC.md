# ZanKurd — Nihai Görsel UX Spesifikasyonu (Kanıta Dayalı)

**Tarih:** 22 Temmuz 2026
**Yöntem:** Uygulama Chrome web'de canlı çalıştırıldı (`http://127.0.0.1:8080`), ekranlar gerçek render üzerinden gezildi. Bu belge, `ZANKURD_EXPERT_PRODUCT_UX_AUDIT.md` (kod bazlı) raporunun kararlarını **gerçek görsel kanıt** ve **kod doğrulaması** ile yeniden değerlendirir.

---

## 0. Kanıt Sınıflandırması ve Dürüstlük Notu

Bu spec'te her bulgu, kanıt seviyesiyle etiketlenmiştir. Uydurma veya yanlış boyutlandırılmış görüntü **kullanılmamıştır**.

| Etiket | Anlamı |
|--------|--------|
| **GERÇEK GÖRSELLE DOĞRULANDI** | Mobil (~642px genişlik) canlı render'da, açık ve/veya koyu temada gözlemlendi. |
| **KODDAN DOĞRULANDI** | Kaynak kodunda ilgili mantık/ölçü teyit edildi; görsel breakpoint çekilemedi. |
| **GÖRSEL OLARAK DOĞRULANAMADI** | Ne mobil render'da ne de araçla güvenilir biçimde görülemedi. |

### Kritik araç kısıtı (şeffaflık)
- Otomasyon tarayıcısının viewport'u **~642px'e kilitliydi**; script ile yeniden boyutlandırma çalışmadı.
- Bu nedenle **tablet (≈768px) ve masaüstü (≥1024px) breakpoint'leri gerçek görselle yakalanamadı.**
- Bir alt-ajan "768x1024" ve "current" etiketli dosyalar üretti; ancak bunlar **bayt bayt kopya / yanlış adlandırılmış** (ör. `settings_current_light.png` aslında Profil ekranı, `learn_768x1024_*` = `learn_current_*` aynı mobil kare) olduğu için **bu spec'te kullanılmadı.** Bkz. Bölüm 49.
- Tablet/masaüstü değerlendirmeleri bu yüzden yalnızca **KODDAN DOĞRULANDI** veya **GÖRSEL OLARAK DOĞRULANAMADI** etiketiyle verilir.

---

## 1. Yönetici Özeti (Görsel Doğrulama Sonrası)

Canlı gezinti, kod bazlı raporun ana tezini (**özellik şişkinliği + kart dili tutarsızlığı**) büyük ölçüde **doğrulamış**, ancak birkaç önemli iddiasını **çürütmüştür**:

- ✅ **Doğrulanan:** Ana sayfa yoğunluğu, oyun modu bolluğu, öğrenmenin sekmede olmayışı, 5 sekmeli navigasyon.
- ❌ **Çürütülen:** "Lig UI yok" (Bronz lig banner'ı hem Liderlik hem Profil'de MEVCUT), "Turnuva takvim/duyuru eksik" (geri sayım + "Her Şemî 20:00" MEVCUT), "Misafir girişi tamamlanmamış" (misafir akışı sorunsuz çalışıyor).
- 🔴 **Rapor kaçırmış (yeni görsel bulgular):** (1) Sekmeler arası **kart dili tutarsızlığı** (üç farklı stil), (2) Quiz'de **A=Kırmızı / B=Mavi renk kodu çelişkisi**, (3) **Birden çok coach-mark turu** sürtünmesi, (4) **Açık temada birincil CTA düşük kontrast**, (5) **Quiz/Oda pushed-route'larında yatay taşma** (800px kısıtını aşıyor).

---

## 2. Çalıştırma Ortamı ve Kapsam

| Boyut | Durum |
|-------|-------|
| Ortam | Flutter 3.44.7, Dart 3.12.2, Chrome web |
| Çalıştırma | `flutter run` web-server, canlı gezinti yapıldı |
| Kaynak kod | Değiştirilmedi (`git status`: yalnızca doküman untracked) |
| Görsel breakpoint | Mobil ~642px gerçek; tablet/masaüstü araç kısıtı nedeniyle çekilemedi |
| Tema | Açık + koyu (koyu tema gerçek render'da doğrulandı) |

---

## 3. Doğrulanan Navigasyon Yapısı (Mevcut Durum)

**GERÇEK GÖRSELLE DOĞRULANDI** — Alt navigasyon **5 sekme**:

| # | Sekme (KU) | TR karşılığı | İkon |
|---|-----------|--------------|------|
| 0 | Sereke | Ana Sayfa | ev |
| 1 | Kategorî | Kategoriler | ızgara |
| 2 | Pêşbazî | Yarışma/Oyna | oyun kolu |
| 3 | Rêz | Liderlik | kupa |
| 4 | Profîl | Profil | kişi |

Akış: Onboarding (5 slayt) → SignIn (misafir seçeneği var) → ProfileNameGate (zorunlu isim) → CoachMark turu → Ana sayfa.

---

## 4. Ana Sayfa (Sereke) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI** (açık + koyu)
Kanıt: `zankurd_mobile/docs/ux-audit/screenshots-final/home_current_light.png`, `home_current_dark.png`

Görülen bileşenler (yukarıdan aşağı):
1. **HeroCard** — yeşil gradient header: "Rojbaş, Rojîn!" selamı, alev/coin sayaçları (🔥0 / 🪙0), sağ üstte **KU (dil)**, **tema** ve **ayar/avatar** butonları.
2. **"Dersê rojane"** (DailyRaceCard) — "10 Pirs • Dawî bike û xelat bistîne!" + **"Destpêk bike"** CTA.
3. **"Erkên Rojane"** (DailyMissions) — 0/3 temam, görevler (ör. "1 joker bikar bîne +20", "Seriya xwe biparêze +30").
4. **PlayTeaser** ("Zû bilîze").
5. **ZanaDaily** ("Gotina Rojê").
6. **Leaderboard preview** ("Lîsteya bilind").

Değerlendirme: Rapordaki "8+ kart" iddiası **abartılı**; gerçek sayı ~6 bölüm. Ancak "tek net birincil CTA yok / bilgi yoğunluğu yüksek" tezi **geçerli** (ONAYLANDI).

---

## 5. Ana Sayfa — Açık/Koyu Tema Kontrast Bulgusu

**GERÇEK GÖRSELLE DOĞRULANDI** — YENİ BULGU (rapor kaçırmış)

- **Koyu tema:** "Destpêk bike" birincil CTA **canlı turuncu** → net, davetkâr.
- **Açık tema:** Aynı buton **kahverengimsi/düşük kontrast** → pasif görünüyor, birincil eylem hissi zayıflıyor.
- **Öneri:** Açık temada birincil CTA için doygun turuncu (koyu temayla aynı marka turuncusu) kullan; WCAG AA kontrast (≥4.5:1) sağla.

---

## 6. Kategoriler (Kategorî) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/ref_categories_mobile_light.png`

- 16 kategori, **tam genişlik renkli gradient kartlar**, tek sütun.
- Her kart: ikon + ad + "N pirs • 5 ast" + sağ ok.
- Uzun dikey scroll gerekiyor (16 büyük kart).
- **Kart dili:** Home HeroCard ile benzer gradient dili → Bölüm 8'deki tutarsızlığın parçası.
- **Öneri (raporla uyumlu):** Mobilde 2 sütun / tablet-masaüstünde 3 sütun grid; mastery halkası. Grid'e geçiş scroll'u ~%50 azaltır.

---

## 7. Oyna Merkezi (Pêşbazî) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/play_current_light.png`, `play_current_dark.png`

Modlar: Şerê 1vs1, Pêşbirka Rojê (günlük), Kûpa (turnuva), Oda oluştur, Kod ile katıl, Dukan (mağaza).

- **Kart dili:** Beyaz kartlar + pastel ikon karoları → Home ve Kategoriler'den **belirgin biçimde farklı**.
- **Seviye kilidi YOK:** Raporun önerdiği "progressive unlock (Sv5 → 1v1, Sv10 → turnuva)" **mevcut değil**; tüm modlar açık.
- Değerlendirme: Rapordaki "mod karmaşıklığı" tezi **ONAYLANDI**; kilit önerisi henüz uygulanmamış.

---

## 8. 🔴 Kritik Bulgu: Sekmeler Arası Kart Dili Tutarsızlığı

**GERÇEK GÖRSELLE DOĞRULANDI** — YENİ BULGU (rapor kaçırmış)

Üç ana sekmede **üç farklı kart görsel dili**:

| Sekme | Kart stili |
|-------|-----------|
| Ana Sayfa | Gradient header + beyaz içerik kartları |
| Kategoriler | Tam-dolgu renkli gradient kartlar |
| Oyna | Beyaz kartlar + pastel ikon karoları |

Buna Oda ekranındaki **teal gradient** ve Profil'deki **turuncu gradient** eklenince marka dili dağılıyor. **Bu, kod bazlı raporun "premium hissi kısmen / her yere farklı renk" sezgisinin somut görsel kanıtıdır.**

**Öneri:** Tek bir kart bileşen sistemi (yükseklik, radius, gölge, gradient kuralları) tanımla; renk yalnızca **kategori/mod kimliği** için aksan olarak kullanılsın, kart iskeleti sabit kalsın.

---

## 9. Profil (Profîl) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/profile_current_light.png`, `profile_current_dark.png`

- Turuncu gradient header: avatar ("R"), "Rojîn", **"Lig Bronz" rozeti (MEVCUT ama soluk/pasif)**.
- "Ast 1 — 0/1000 XP" ilerleme çubuğu.
- "Statîstîkên Min": 2×2 beyaz stat kartları (Rêze, Tevayî Xal, Baştirîn Zincîr, Lîstik).
- Koyu temada header turuncu kalıyor (marka), stat kartları koyuya uyum sağlıyor.

**Not:** Lig rozeti burada **var** — raporun "Profil'de lig rozeti yok" iddiası **yanlış** (Bölüm 20).

---

## 10. Liderlik (Rêz) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/leaderboard_mobile_390x844.png` (mobil; kesin px genişliği araç tarafından garanti edilemez, ekran içeriği gerçektir)

- **"Lîga Bronz" banner'ı MEVCUT** (üstte lig göstergesi).
- Podyum (top 3) + dönem sekmeleri: **Roj / Heft / Meh / Heval**.
- Kullanıcının kendi satırı listede.
- İçerik dolu ve etkileşimli — rapordaki "pasif/değersiz alan" nitelemesi **kısmen fazla sert**.

---

## 11. Turnuva (Kûpa) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/tournament_mobile_390x844.png`

- Altın kupa görseli, "Kûpaya ZanKurd".
- **"Her Şemî 20:00" + geri sayım MEVCUT** (takvim/duyuru var).
- "16 lîstikvan (bot) • 4 tur" + katılım CTA.

**Not:** Raporun "turnuva takvim/duyuru eksik" iddiası **yanlış** (Bölüm 20).

---

## 12. Oda / Arkadaşla Oyna — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/room_mobile_390x844.png`

- Oda oluşturma diyaloğu: soru başına süre (15–60 sn) seçimi.
- Oda ekranı: **teal gradient**, oda kodu (ör. ZK-CD3D), oyuncu listesi, "Amade Me" (hazır) butonu.
- 🔴 **Yatay taşma:** İçerik sağ kenardan kırpılıyor. Oda ekranı, shell'in `maxWidth: 800` kısıtının **dışında** (pushed route) → geniş ekranda genişlik yönetimi yok. Bkz. Bölüm 22.

---

## 13. Mağaza (Dukan) — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/shop_mobile_390x844.png`

- "0 coin" bakiyesi, çark banner'ı (mağazadan çarka erişim).
- Öne çıkan "Rozeta VIP".
- 3 sütunlu ürün grid'i (çerçeveler, jokerler, isim renkleri) fiyatlarıyla.
- Organizasyon iyi. Raporun "bağlamsal satış eksik" tezi katalog düzeyinde geçerli olabilir ama **GÖRSEL OLARAK DOĞRULANAMADI** (akış içi upsell tetikleyicileri test edilmedi).

---

## 14. Ayarlar (Mîheng) — Değerlendirme

**KODDAN DOĞRULANDI** (`settings_screen.dart` ~1220 satır)
- Profil altından "Mîheng/Ayarlar" olarak açılıyor (scroll gerekli).
- Uzunluk ve gruplama eksikliği kodla tutarlı.
- **GÖRSEL OLARAK DOĞRULANAMADI:** Ayarların tam listesi canlı scroll ile yakalanamadı (Flutter canvas'ta sentetik scroll ulaşmadı). Alt-ajanın "settings" görüntüsü aslında Profil ekranıydı, kullanılmadı.

---

## 15. Quiz Ekranı — Görsel Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
Kanıt: `screenshots-final/ref_quiz_mobile_light.png`, `ref_quiz_clean_mobile_light.png`, `ref_quiz_answered_mobile_light.png`

Görülen: Siyaset kategorisi Rast/Xelet sorusu, 30 sn timer, 4 joker (Nîv bi Nîv, Ji Temaşevanan, Du Bersiv, Pirsê Biguhere).

- **Cevaplama sonrası (feedback) hali doğru:** doğru şık **yeşil + tik**, yanlış soluk, üstte kırmızı "Dem qediya! Bersiva rast: ..." banner'ı, "Piştre" turuncu aktif.

---

## 16. 🔴 Kritik Bulgu: Quiz Cevap Rengi Konvansiyon Çelişkisi

**GERÇEK GÖRSELLE DOĞRULANDI** — YENİ BULGU (rapor kaçırmış)

- Cevaplamadan **önce**: A şıkkı ("Rast") **KIRMIZI**, B şıkkı ("Şaş") **MAVİ** zeminde.
- Sorun: Kırmızı evrensel olarak "yanlış/hata" sinyali; kullanıcı henüz cevaplamadan A'yı yanlış sanabilir. Feedback aşamasında yeşil=doğru/kırmızı=yanlış kullanıldığı için **renk anlamı tutarsız**.
- **Öneri:** Cevaplama öncesi şıklar **nötr** (marka yüzey rengi) olsun; kırmızı/yeşil **yalnızca** cevap sonrası doğru/yanlış geri bildiriminde kullanılsın.

---

## 17. 🔴 Bulgu: Birden Çok Coach-Mark Turu Sürtünmesi

**GERÇEK GÖRSELLE DOĞRULANDI** — YENİ BULGU

- İsim belirlemeden sonra ana sayfada 3 adımlı coach-mark turu ("Bilîze 1/3 …").
- Quiz'e girildiğinde **ayrı bir** coach-mark turu daha (timer açıklaması).
- İlk deneyimde arka arkaya iki tur = değer anına ulaşmayı geciktiriyor.
- **Öneri:** Turları tek, kısa ve atlanabilir bir akışta birleştir; timer ipucunu ilk quiz'de tek satır tooltip'e indir.

---

## 18. Sonuç Ekranı (QuizResult) — Değerlendirme

**GÖRSEL OLARAK DOĞRULANAMADI** (temiz sonuç ekranı canlı akışta stabil yakalanamadı)
**KODDAN DOĞRULANDI:** `quiz_result_screen.dart` ~1380 satır; XP, coin, doğruluk, süre, sıralama, rozet, paylaşım, inceleme, tekrar-oyna öğelerini barındırıyor → rapordaki "bilgi yoğunluğu" tezi kodla tutarlı.
- **Öneri (raporla uyumlu):** 2 aşamalı sonuç — (1) büyük skor/emoji anı, (2) scroll ile detay; tek net birincil CTA.

---

## 19. Onboarding + Misafir Girişi — Değerlendirme

**GERÇEK GÖRSELLE DOĞRULANDI**
- Onboarding 5 slayt (ör. "Hîn bibe, pêş bike"), "Derbas bike" (atla) butonu çalışıyor.
- SignIn'de **"Wek mêvan bidomîne" (misafir devam et) sorunsuz çalıştı** → ana akışa geçildi.
- **Rapor iddiası çürütüldü:** "Misafir girişi tamamlanmamış" (Problem 17) → **REDDEDİLDİ** (misafir modu işlevsel).
- Geçerli kalan öneri: değer anını (ilk soru) kayıt duvarının önüne almak hâlâ iyi bir fikir.

---

## 20. Rapor Kararlarının Kanıta Dayalı Değerlendirmesi (Problem 1–17)

| # | Rapor Problemi | Verdikt | Kanıt seviyesi | Not |
|---|----------------|---------|----------------|-----|
| 1 | Ana sayfa bilgi aşırı yükü | ONAYLANDI (sayı düzelt) | GERÇEK GÖRSEL | ~6 bölüm, "8+" abartılı ama tez geçerli |
| 2 | Oyun modu karmaşıklığı | ONAYLANDI | GERÇEK GÖRSEL | 6 mod tek hub'da |
| 3 | Öğrenme sekmede değil | ONAYLANDI | GERÇEK GÖRSEL + KOD | 5 sekmede "Öğren" yok |
| 4 | 5 sekme dengesizliği | ONAYLANDI | GERÇEK GÖRSEL | 5 sekme teyit |
| 5 | Quiz parametre karmaşıklığı | ONAYLANDI | KODDAN | quiz_screen 1522 satır, çok mod |
| 6 | Onboarding yetersiz | DEĞİŞTİRİLMELİ | GERÇEK GÖRSEL | 5 slayt var; değer-anı önerisi geçerli |
| 7 | Mağaza değer önerisi | DEĞİŞTİRİLMELİ | GÖRSEL DOĞRULANAMADI | Katalog iyi; upsell test edilmedi |
| 8 | **Lig UI yok** | **REDDEDİLDİ** | GERÇEK GÖRSEL | Bronz lig banner'ı Liderlik+Profil'de MEVCUT |
| 9 | Arkadaş keşfedilebilirliği | DEĞİŞTİRİLMELİ | KODDAN | Rêz'de "Heval" sekmesi + odadan erişim var |
| 10 | Ayarlar çok uzun | ONAYLANDI | KODDAN | ~1220 satır, gruplama yok |
| 11 | Günlük görev motivasyonu | DEĞİŞTİRİLMELİ | GERÇEK GÖRSEL | Görev başına ödül gösteriliyor; toplam bonus vurgusu zayıf |
| 12 | Responsive breakpoint | DEĞİŞTİRİLMELİ | KODDAN | Gerçek breakpoint 720px (768 değil); tablet/masaüstü görsel DOĞRULANAMADI |
| 13 | Streak kırılma korkusu | ONAYLANDI | GERÇEK GÖRSEL | Streak yalnızca sayı (🔥0), tehlike UI yok |
| 14 | Sonuç ekranı yoğunluğu | ONAYLANDI | KODDAN | ~1380 satır; görsel DOĞRULANAMADI |
| 15 | Bildirim merkezi yok | ONAYLANDI | GERÇEK GÖRSEL + KOD | Home header'da zil yok (KU/tema/ayar/avatar var) |
| 16 | Çark bağlam kopukluğu | DEĞİŞTİRİLMELİ | GERÇEK GÖRSEL | Çarka mağaza banner'ı + play hub'dan erişiliyor |
| 17 | **Misafir girişi tamamlanmamış** | **REDDEDİLDİ** | GERÇEK GÖRSEL | Misafir akışı çalışıyor |

---

## 21. Rapor Stratejik Kararlarının Değerlendirmesi (Bölüm 11–15)

| Karar | Verdikt | Kanıt | Not |
|-------|---------|-------|-----|
| 4 sekmeye indir (Böl.11) | ONAYLANDI (yön) | GERÇEK GÖRSEL | 5→4 mantıklı; ama Liderlik dolu içerik, gömerken değer kaybetme |
| Ana sayfa tek CTA sırası (Böl.12) | ONAYLANDI | GERÇEK GÖRSEL | Mevcut çoklu CTA sorunu doğrulandı |
| Oyna hub + kilit (Böl.13) | KISMEN | GERÇEK GÖRSEL | Kilit yok; progressive unlock uygulanmalı |
| Öğren sekmesi (Böl.14) | ONAYLANDI | GERÇEK GÖRSEL | Kategoriler+Learning birleşimi mantıklı |
| Lig UI ekle (Böl.15) | DEĞİŞTİRİLMELİ | GERÇEK GÖRSEL | Lig UI zaten VAR; "ekle" değil "belirginleştir/aktive et" olmalı |

---

## 22. 🔴 Responsive / Breakpoint — Kod Doğrulaması

**KODDAN DOĞRULANDI** (tablet/masaüstü görsel çekilemedi):

- `app_shell.dart:199-200` → sekme içeriği `ConstrainedBox(maxWidth: 800)` ile ortalı sütun. Yani tablet/masaüstünde içerik **800px'de sabitlenip ortalanır**, gerçek geniş yerleşim yok.
- `home_screen.dart:162-167` → `constraints.maxWidth > 720` için **geniş yerleşim** dalı var.
- `quiz_screen.dart:735-737` → `constraints.maxWidth >= 700` için **yatay (landscape) yerleşim**.
- `onboarding_screen.dart:98-101` → `maxWidth >= 720` geniş yerleşim.
- **Gerçek breakpoint 720px'dir** (raporun dediği 768 değil).
- 🔴 **Pushed route'lar (Quiz, Oda) `maxWidth: 800` kısıtının dışında** → geniş/dar uçlarda **yatay taşma** gözlendi (Bölüm 12, 16). Bu, shell dışı route'lara aynı genişlik kısıtının uygulanmadığını gösterir.

**GÖRSEL OLARAK DOĞRULANAMADI:** 720px üstü (tablet/masaüstü) yerleşimlerin gerçek görünümü. Öneri: gelecekte gerçek pencere boyutlandırma ile ≥720px ve ≥1024px kareleri çekilmeli.

---

## 23–48. Ekran Bazlı Kısa UX Spesifikasyonu

Aşağıdaki maddeler kanıt seviyesiyle etiketli, uygulanabilir tasarım kararlarıdır.

### 23. Ana sayfa hiyerarşisi
Tek birincil CTA ("Destpêk bike/Şimdi Oyna") görsel olarak en baskın öğe olsun; diğer kartlar ikincil ağırlığa insin. **GERÇEK GÖRSEL** temelli.

### 24. Açık tema CTA
Birincil CTA açık temada doygun turuncu + AA kontrast. **GERÇEK GÖRSEL.**

### 25. Kart sistemi birleştirme
Tek kart iskeleti; renk sadece aksan. **GERÇEK GÖRSEL** (Bölüm 8).

### 26. Kategoriler grid
Mobil 2 sütun, ≥720px 3 sütun; mastery halkası. Mobil **GERÇEK GÖRSEL**, geniş **KODDAN**.

### 27. Oyna hub kilitleri
Sv5→1v1, Sv10→Turnuva için gri overlay + kilit + "Ast X'ê vebe". Şu an kilit **yok** (GERÇEK GÖRSEL).

### 28. Oyna hub kart dili
Home/Kategoriler ile aynı kart sistemine hizala. **GERÇEK GÖRSEL.**

### 29. Quiz şık renkleri
Cevap öncesi nötr; kırmızı/yeşil yalnız feedback'te. **GERÇEK GÖRSEL** (Bölüm 16).

### 30. Quiz yatay taşma
Quiz route'una `maxWidth` kısıtı/`SafeArea` + responsive padding uygula. **GERÇEK GÖRSEL + KOD.**

### 31. Coach-mark birleştirme
Tek atlanabilir tur; quiz timer ipucu tek tooltip. **GERÇEK GÖRSEL** (Bölüm 17).

### 32. Sonuç ekranı 2 aşama
Skor anı → detay scroll; tek CTA. **KODDAN.**

### 33. Profil lig rozeti belirginleştirme
Rozet var ama soluk; kontrast + "yükselmeye X puan" bilgisi ekle. **GERÇEK GÖRSEL.**

### 34. Liderlik değeri
Dolu ve etkileşimli; sekme yerine korunabilir. Rapor "değersiz" demiş — **kısmen reddedildi**. **GERÇEK GÖRSEL.**

### 35. Turnuva takvimi
Geri sayım + "Her Şemî 20:00" zaten var; öne çıkar. **GERÇEK GÖRSEL.**

### 36. Oda ekranı genişlik
Teal gradient içeriğini `maxWidth` sütununa al; yatay taşmayı gider. **GERÇEK GÖRSEL.**

### 37. Mağaza bağlamsal satış
Joker biterken akış-içi "şimdi al" tetikleyicisi. **GÖRSEL DOĞRULANAMADI** (öneri).

### 38. Çark entegrasyonu
Günlük ilk açılışta auto-prompt; ayrı menüden sadeleştir. **GERÇEK GÖRSEL** (erişim var).

### 39. Ayarlar gruplama
Tercihler / Hesap / Bilgi olarak 3 grup. **KODDAN.**

### 40. Streak tehlike UI
20:00 sonrası kırmızı vurgu + push. **GERÇEK GÖRSEL** (şu an sadece sayı).

### 41. Bildirim merkezi
Home header'a zil + inbox. **GERÇEK GÖRSEL** (yok).

### 42. Öğren sekmesi
Kategoriler + Learning + SM-2 tekrar tek sekmede. **GERÇEK GÖRSEL + KOD.**

### 43. Onboarding değer anı
İlk soruyu kayıt duvarından önce sun. **GERÇEK GÖRSEL.**

### 44. Marka renk disiplini
Turuncu (Profil), yeşil (Home), teal (Oda), pastel (Play) → sınırlı palet + tutarlı aksan kuralı. **GERÇEK GÖRSEL.**

### 45. Koyu tema tutarlılığı
Koyu tema genelde iyi; açık temada CTA kontrastı tek zayıf nokta. **GERÇEK GÖRSEL.**

### 46. Günlük görev toplam ödül
Görev başına ödül var; "3/3 → +50 bonus" ana çubuğu ekle. **GERÇEK GÖRSEL.**

### 47. Tablet yerleşimi
`maxWidth:800` merkezli sütun; ≥720 geniş dallar var ama görsel doğrulanmadı. **KODDAN / GÖRSEL DOĞRULANAMADI.**

### 48. Masaüstü yerleşimi
Ayrı masaüstü (≥1024) yerleşimi kodda özel olarak görülmedi; 800px sütun ortalanır. **KODDAN / GÖRSEL DOĞRULANAMADI.**

---

## 49. Kanıt Envanteri ve Güvenilirlik

### Güvenilir (bu spec'te kullanıldı) — gerçek mobil ~642px / tema
- `home_current_light.png`, `home_current_dark.png`
- `ref_home_mobile_light.png`, `ref_home_mobile_dark.png`
- `ref_categories_mobile_light.png`
- `play_current_light.png`, `play_current_dark.png`
- `profile_current_light.png`, `profile_current_dark.png`
- `leaderboard_mobile_390x844.png`, `tournament_mobile_390x844.png`, `room_mobile_390x844.png`, `shop_mobile_390x844.png`
- `ref_quiz_mobile_light.png`, `ref_quiz_clean_mobile_light.png`, `ref_quiz_answered_mobile_light.png`

### Güvenilmez (kullanılmadı) — kopya / yanlış adlandırma / yanlış boyut
- `*_768x1024_*.png` (gerçek 768 boyut değil; mobil karelerin kopyası)
- `learn_current_*.png` (= `learn_768x1024_*`, aslında Kategoriler)
- `settings_current_light.png`, `settings_768x1024_light.png` (**aslında Profil ekranı**)
- `_tmp_*.png` (geçici çalışma kareleri)
- `play_768x1024_light.png` (= mobil kopya)

> Not: Güvenilmez dosyalar **silinmedi** (kullanıcı talebi doğrultusunda uygulama/dosya değişikliği yapılmadı); yalnızca bu spec'te dışlandı.

---

## 50. Sonuç ve Öncelik Sırası

**Yüksek öncelik (görsel kanıtlı, düşük risk):**
1. Quiz şık renk konvansiyonu (A=kırmızı) düzelt — kafa karışıklığı riski yüksek.
2. Açık tema birincil CTA kontrastı.
3. Quiz/Oda yatay taşması (`maxWidth` sütununa alma).
4. Kart dili birleştirme (tutarlılık).
5. Coach-mark turlarını tekleştir.

**Orta öncelik:**
6. Ana sayfa hiyerarşisi (tek CTA), günlük görev toplam-ödül çubuğu.
7. Oyna hub progressive unlock.
8. Ayarlar gruplama, streak tehlike UI, bildirim merkezi.

**Düzeltilmesi gereken rapor hataları (gelecekteki dokümanlar için):**
- Lig UI mevcut → "ekle" değil "belirginleştir".
- Turnuva takvimi mevcut.
- Misafir girişi çalışıyor.
- Gerçek breakpoint 720px (768 değil).

**Görsel olarak tamamlanamayan (dürüst boşluk):**
- Tablet (≥720px) ve masaüstü (≥1024px) gerçek render görüntüleri. Araç viewport kısıtı nedeniyle çekilemedi; yalnızca koddan doğrulandı. Kesin görsel doğrulama için gerçek pencere boyutlandırma yapabilen bir ortamda ≥720 ve ≥1024 kareleri alınmalıdır.

---

*Bu spec yalnızca güvenilir gerçek görsel kanıt + kaynak kod doğrulamasıyla hazırlanmıştır. Uydurma/kopya/yanlış boyutlandırılmış görüntü kullanılmamış; uygulama kaynak kodu değiştirilmemiştir.*
