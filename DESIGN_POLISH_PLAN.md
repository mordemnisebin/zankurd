# ZanKurd — Tasarım Cilası Planı (DESIGN_POLISH_PLAN)

> Son güncelleme: 2026-06-22
> **Bu belge yalnızca PLANDIR. Hiçbir tasarım uygulanmadı.**
> Kural: yeni özellik yok, iş mantığı/akış değişmez, yalnızca görsel/UX cilası. Her madde için risk seviyesi belirtilmiştir.

Risk ölçeği: **Düşük** = sadece stil/sabit değer; **Orta** = widget ağacı/durum yerleşimi değişebilir; **Yüksek** = akış/etkileşim mantığına dokunur (bu planda yüksek riskli öneri kasıtlı olarak yok).

---

## 1. Ana Sayfa (home)

- **Sorun:** Kart yoğunluğu yüksek (hero, kategori grid, günlük görev, çark, turnuva kartları); görsel hiyerarşi zayıf olabilir, kullanıcı gözü nereye gideceğini şaşırabilir.
- **Öneri:**
  - Bölüm başlıkları için tutarlı tipografi (aynı punto/ağırlık/üst boşluk) ve bölümler arası tutarlı dikey ritim (örn. 16/24 px).
  - Hero kartını görsel olarak ön plana çıkar (hafif gradyan/gölge), ikincil kartları daha sakin tut.
  - Kart köşe yarıçapı, gölge ve iç boşlukları tek bir tasarım token'ına bağla.
- **Etkilenebilir dosyalar:** `screens/home_screen.dart`, `screens/home/hero_card.dart`, `screens/home/category_grid.dart`, `screens/home/daily_missions_card.dart`, `screens/home/spin_wheel_card.dart`, `screens/home/tournament_card.dart`, `theme/app_theme.dart`.
- **Risk:** Düşük–Orta.

## 2. Kategoriler Ekranı (categories_tab)

- **Sorun:** Kategori kartlarında görsel + isim + mastery rozeti yerleşiminin tutarlılığı; yeni görseller (cat_*.png) eklenince hizalama/oran kayması olabilir.
- **Öneri:**
  - Tüm kategori kartlarında sabit en-boy oranı ve görsel kırpma (`BoxFit.cover`) ile tutarlı görünüm.
  - Mastery unvanı rozetini kartın sabit bir köşesinde standart boyutta konumlandır.
  - Uzun kategori adları için tek satır + ellipsis kuralı.
- **Etkilenebilir dosyalar:** `screens/categories_tab.dart`, `screens/home/category_grid.dart`, `widgets/badge_widget.dart`.
- **Risk:** Düşük.

## 3. Quiz Ekranı (quiz)

- **Sorun:** Doğru/yanlış geri bildirimi, joker butonları ve ilerleme göstergesi görsel olarak güçlendirilebilir; landscape düzende sıkışma olabilir.
- **Öneri:**
  - Doğru/yanlış seçimde renk + ikon + kısa animasyonun (mevcut ses ile senkron) yumuşatılması; A/B/C/D rozet renk kontrastının erişilebilirlik için doğrulanması.
  - Joker butonlarında coin maliyetini ve "yetersiz coin" durumunu daha net görselleştir (devre dışı stili).
  - Üstte ince, akıcı bir ilerleme çubuğu / soru sayacı tutarlılığı.
- **Etkilenebilir dosyalar:** `screens/quiz_screen.dart`, `screens/quiz/` altındaki bileşenler, `widgets/styled_button.dart`, `theme/app_theme.dart`.
- **Risk:** Orta (animasyon/etkileşim mantığına dokunmadan yalnızca görsel katman).

## 4. Sonuç Ekranı (quiz_result_screen)

- **Sorun:** Sonuç özeti (doğru sayısı, XP, coin, mastery terfisi) bilgi yoğun; tek bir "özet kartı" hissi eksik olabilir.
- **Öneri:**
  - Net bir skor başlığı + altında ikonlu istatistik satırları (XP, coin, doğru/yanlış) içeren tek kart.
  - Mastery terfi banner'ını kutlama vurgusuyla (mevcut confetti ile) öne çıkar.
  - Birincil eylem (Tekrar/Devam) ile ikincil eylemin (Paylaş) görsel ayrımı.
- **Etkilenebilir dosyalar:** `screens/quiz_result_screen.dart`, `widgets/styled_button.dart`.
- **Risk:** Düşük–Orta.

## 5. Profil Ekranı (profile_screen)

- **Sorun:** İstatistikler, rozet koleksiyonu ve mastery ilerlemesi bölümlerinin düzeni yoğun; bölüm ayrımı zayıf olabilir.
- **Öneri:**
  - İstatistikleri 2'li/3'lü grid kartlara böl (oynanan, doğru oranı, streak, coin).
  - Rozet koleksiyonu için yatay kaydırma + "tümünü gör" tutarlılığı.
  - Mastery bölümünde kategori başına ilerleme çubuğu görsel standardı.
- **Etkilenebilir dosyalar:** `screens/profile_screen.dart`, `widgets/badge_collection_section.dart`, `widgets/badge_widget.dart`.
- **Risk:** Düşük–Orta.

## 6. Ayarlar Ekranı (settings_screen)

- **Sorun:** Ayar öğeleri (isim, ses, tema, dil, bildirim, hesap silme, sürüm) gruplanmadan listelenmiş olabilir; bildirim ayarının "simülasyon" olduğu kullanıcıya belirsiz.
- **Öneri:**
  - Ayarları başlıklı gruplara böl: Hesap / Görünüm / Ses & Bildirim / Hakkında.
  - Sürüm satırını "Hakkında" altında net göster (artık `1.5.0+6`).
  - Hesap silme gibi yıkıcı eylemi görsel olarak ayır (kırmızı/uyarı stili).
- **Etkilenebilir dosyalar:** `screens/settings_screen.dart`, `widgets/app_panel.dart`.
- **Risk:** Düşük.

## 7. Boş / Hata / Yükleme Durumları

- **Sorun:** Liste/sorgu ekranlarında boş, hata ve yükleme durumları muhtemelen tutarsız (kimi yerde spinner, kimi yerde shimmer, kimi yerde boş).
- **Öneri:**
  - Tek bir yükleme deseni (shimmer skeleton) standardı — `shimmer` paketi zaten mevcut.
  - Yeniden kullanılabilir "boş durum" bileşeni: ikon + kısa Kurmancî mesaj + (varsa) eylem butonu.
  - Hata durumu için "tekrar dene" butonlu standart bileşen.
- **Etkilenebilir dosyalar:** `widgets/` altında yeni paylaşılan durum bileşenleri (yalnızca görsel sarmalayıcı), `screens/leaderboard_screen.dart`, `screens/favorite_questions_screen.dart`, `screens/review_screen.dart`.
- **Risk:** Düşük–Orta (yeni "özellik" değil, mevcut durumların görsel standardizasyonu).

---

## Uygulama Sırası Önerisi (riske göre)

1. Düşük riskli, hızlı kazanımlar: Ayarlar gruplama (6), Kategori kart tutarlılığı (2), Boş/hata/yükleme standardı (7).
2. Orta riskli, görünür etki: Sonuç ekranı özet kartı (4), Profil düzeni (5), Ana sayfa hiyerarşisi (1).
3. En dikkatli: Quiz ekranı görsel katmanı (3) — etkileşim mantığına dokunmadan.

> Her adımdan sonra `dart analyze` + `flutter test` çalıştırılmalı; ekran davranışı (akış/skor/coin) değişmemeli.
