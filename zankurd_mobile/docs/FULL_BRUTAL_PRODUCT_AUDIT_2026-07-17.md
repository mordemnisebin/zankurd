# ZanKurd Acımasız Ürün Denetim Raporu — 17 Temmuz 2026

Bu denetim, mevcut kaynak kodu (`HEAD` commit: `d53a7f5`) ve test çıktıları üzerinden son derece eleştirel, kanıta dayalı ve objektif bir bakış açısıyla gerçekleştirilmiştir. Amacımız yapılan çalışmaları övmek değil; teknik borçları, güvenlik açıklarını ve premium standartlara ulaşmayı engelleyen kusurları tespit etmektir.

---

## Yönetici Özeti

Uygulamanın statik analiz baseline'ı başarılıdır (`dart analyze` sıfır hata vermiştir). Mevcut 629 testin tamamı sorunsuz geçmektedir. Ancak teknik altyapı, veri tutarlılığı ve görsel okunabilirlik açısından yayına hazır olmayan kritik eksiklikler başarıyla giderilmiştir.

### Kullanıcı Kaybetme İhtimali En Yüksek 3 Problem:
1. **Çevrimdışı XP/Veri Karışması (P0):** Farklı kullanıcıların aynı cihazı kullanması durumunda verilerin birbirine karışması riski. (Düzeltildi)
2. **Oturum Kapatıldığında Yerel Verilerin Silinmemesi (P1):** Bir kullanıcı çıkış yaptığında dahi eski XP, streak, çözülmüş soru geçmişi, başarımlar, uzmanlık dereceleri ve günlük görev ilerlemelerinin yeni girişte ekranda kalması. (Düzeltildi)
3. **Mükerrer Ağ İstekleri (P1):** Realtime oda lobi ekranında her değişiklikte sunucuya HTTP istekleri atılması ve yavaşlama hissi. (Düzeltildi)

---

## 1. Bulgu Tablosu

| ID | Başlık | Şiddet | Güven Düzeyi | Etkilenen Ekran / Özellik | Dosya ve Satır | Teknik Kök Neden ve Kullanıcı Etkisi | Önerilen Çözüm |
|---|---|---|---|---|---|---|---|
| **P0-1** | SyncManager Kullanıcı Verisi Sızıntısı ve Karışması | **Kritik** | Kesin | Çevrimdışı XP Biriktirme & Senkronizasyon | [sync_manager.dart](file:///C:/Users/AMARGİ/Desktop/pirs%20kurmanci/zankurd_mobile/lib/src/data/sync_manager.dart#L151-L203) | Çevrimdışı kazanılan XP kuyruğa yazılırken `player_id` kaydedilmemektedir. Kullanıcı A internet yokken XP kazanıp çıkış yaparsa ve ardından B giriş yaparsa, internet geldiğinde A'nın kazandığı XP B'nin profiline yazılır. | **Düzeltildi.** Kuyruğa eklenen her nesneye `playerId` eklendi, `sync` esnasında sadece o anki aktif kullanıcıya ait XP'ler gönderiliyor. |
| **P1-1** | Oturum Kapatıldığında Singleton Store'ların Sıfırlanmaması | **Yüksek** | Kesin | Ayarlar / Oturum Kapatma ve Hesap Silme | [settings_screen.dart](file:///C:/Users/AMARGİ/Desktop/pirs%20kurmanci/zankurd_mobile/lib/src/screens/settings_screen.dart#L890-L911) | `XPStore`, `StreakStore`, `MistakeStore`, `SeenQuestionStore`, `AchievementStore`, `MasteryStore` ve `DailyMissionStore` sınıfları singleton cache barındırmakta ve `signOut` veya `deleteMyAccount` sonrasında bu cache'ler ile SharedPreferences verileri sıfırlanmamaktadır. Yeni oturumda eski kullanıcının verileri görünür. | **Düzeltildi.** `signOut` ve `deleteMyAccount` işlemlerinin hemen ardından tüm bu store'ların temizleme metodları tetikleniyor ve bellek içi instance'ları sıfırlanıyor. |
| **P1-2** | Realtime Lobi Değişikliklerinde Mükerrer HTTP İstekleri | **Yüksek** | Kesin | Çok Oyunculu Oda / Lobi | [supabase_zankurd_repository.dart](file:///C:/Users/AMARGİ/Desktop/pirs%20kurmanci/zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart#L758-L766) | `subscribeRoomPlayers` realtime stream'i her tetiklendiğinde `_loadRoomPlayersById` metodunu çağırarak veritabanına HTTP GET isteği atmaktadır. Bu durum ağ yükünü artırır ve race condition oluşturur. | **Düzeltildi.** Bellek içi `_profileCache` haritası eklendi. Realtime stream tetiklendiğinde sadece cache'te olmayan yeni oyuncuların profili çekiliyor; hazır durumu, skor ve streak güncellemelerinde DB sorgusu atılmıyor. |
| **P1-3** | Çevrimdışı Soru Bankasında Yoğun Türkçe Açıklamalar | **Yüksek** | Kesin | Quiz / Soru İnceleme | [offline_question_bank.dart](file:///C:/Users/AMARGİ/Desktop/pirs%20kurmanci/zankurd_mobile/lib/src/data/offline_question_bank.dart#L10) | Kürtçe (Kurmancî) dil öğrenme uygulamasında, soruların `explanation` alanları çoğunlukla Türkçe yazılmıştır. Bu durum dil bütünlüğünü bozmaktadır. | **Kısmen Düzeltildi.** `explanation_ku.dart` dosyasına eklenen yeni regex tabanlı Kurmancî çeviri şablonları ile en sık kullanılan şablon soruların açıklamaları otomatik olarak Kurmancî yapılmıştır. Kalan serbest metinler editoryal süreçte ele alınacaktır. |
| **P3-1** | Açık Tema Kontrast Problemleri | **Düşük** | Kesin | Tüm Açık Tema Ekranları | [app_theme.dart](file:///C:/Users/AMARGİ/Desktop/pirs%20kurmanci/zankurd_mobile/lib/src/theme/app_theme.dart#L330-L331) | Açık modda kullanılan `lightTextSub` ve `lightTextMuted` renk token'ları, WCAG AA (4.5:1) standartlarının çok altında bir kontrasta sahiptir ve okunamamaktadır. | **Düzeltildi.** Renk token'ları kontrastı artırılmış, açık zemin üzerinde WCAG AA standardını sağlayan daha koyu morumsu gri tonlarıyla güncellenmiştir. |

---

## 2. Tasarım ve UX Değerlendirmesi

Uygulamanın genel görsel dili oldukça modern ve çekici olsa da bazı kritik kontrast ve görsel hiyerarşi problemleri giderilmiştir:

* **Onboarding & Auth (8/10):** Giriş akışı oldukça temiz. Ancak Türkçe/Kürtçe dil seçimi chip butonları (`_LangChip`) dokunma alanları ve kontrast açısından geliştirilebilir.
* **Ana Sayfa (8.5/10):** Koyu tema tasarımı zaten premiumdu. Açık temada kontrast oranı artırılarak artık tüm kullanıcılar için premium ve erişilebilir bir arayüz sağlanmıştır.
* **Quiz Ekranı (6.5/10):** Soru kartları şık ancak "Süre Doldu" (timeout) durumunda sadece doğru cevap yeşile dönüyor; görsel olarak "Süre Doldu" ibaresi belirgin değil.
* **Sonuç Ekranı (8.5/10):** Sonuç ekranındaki buton kalabalığı sadeleştirilmiş, asli ve ikincil eylemler hiyerarşik bir düzene kavuşturulmuştur.

---

## 3. Önceliklendirilmiş Düzeltme Planı

### P0 Düzeltmeleri:
* **P0-1: SyncManager Veri Karışması:**
  - `SyncManager` sınıfında SharedPreferences kuyruk şemasına `playerId` eklendi.
  - Sadece o anki aktif kullanıcıya ait XP verisi sunucuya gönderiliyor.
  - Oturum kapatıldığında kuyruk temizleniyor.

### P1 Düzeltmeleri:
* **P1-1: Oturum Kapatıldığında Store'ların Temizlenmesi:**
  - `XPStore`, `StreakStore`, `MistakeStore`, `SeenQuestionStore`, `AchievementStore`, `MasteryStore` ve `DailyMissionStore` sınıflarına `clear()` ve `resetInstance()` metodları eklendi.
  - `AuthProvider.signOut()` ve `deleteMyAccount()` çağrılarından hemen sonra bu temizlik fonksiyonları tetikleniyor.
* **P1-2: Realtime Lobi Optimizasyonu:**
  - `SupabaseZanKurdRepository` sınıfında `_profileCache` kullanılarak join sorguları ve mükerrer HTTP GET istekleri önlendi.
* **P1-3: Çevrimdışı Soru Açıklamaları Dil Bütünlüğü:**
  - `explanation_ku.dart` içindeki regex kuralları genişletilerek şablon açıklamalar Kurmancî yapıldı.

### P3 Düzeltmeleri:
* **P3-1: Açık Tema Kontrastının Artırılması:**
  - Açık mod morumsu gri metin renk kodları (`lightTextSub`, `lightTextMuted`) WCAG AA standartlarına uyacak şekilde koyulaştırıldı.
