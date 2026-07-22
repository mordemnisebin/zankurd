# ZanKurd — Uzman Ürün & UX Denetim Raporu

**Tarih:** 22 Temmuz 2026  
**Denetleyen:** Bağımsız Ürün/UX Uzmanı  
**Platform:** Flutter (iOS, Android, Web)  
**Versiyon:** Mevcut ana dal (main branch)  
**Yöntem:** Kaynak kodu statik analizi, mimari inceleme, kullanıcı akışı simülasyonu

---

## 1. Yönetici Özeti

ZanKurd, Kürtçe (Kurmancî) öğretimi ve bilgi yarışmasını birleştiren cesur bir üründür. Teknik altyapı (Supabase realtime, çoklu oyun modları, SM-2 tekrar algoritması, oda sistemi, turnuva bracket) olgunlaşmış ve endüstri standardını karşılamaktadır. Ancak ürün, **özellik şişkinliği (feature bloat)** ve **bilgi mimarisi dağınıklığı** nedeniyle kullanıcıyı ilk 30 saniyede kaybetme riski taşımaktadır.

**Temel bulgular:**
- Ana sayfa 8+ farklı kart tipiyle kullanıcıyı bunaltıyor; net bir birincil eylem (CTA) yok.
- 7 farklı oyun modu birbirinden yeterince ayrışmıyor; yeni kullanıcı hangi moda girip başlayacağını bilemiyor.
- Öğrenme (LearningScreen, 1390 satır) geniş içerik barındırıyor ancak ana navigasyonda gizli; keşfedilemiyor.
- 5 sekmeli alt navigasyon, simetrik önem dağılımı yaratıyor; gerçekte "Oyna" ve "Öğren" birincil, diğerleri ikincil.
- Lig sistemi model katmanında hazır ama UI'da yok; kullanıcıya motivasyon kancası sunulmuyor.

**Stratejik öneri:** Ürünü "Öğren → Oyna → Yüksel" üçlü döngüsüne daraltmak, ana sayfayı tek bir net CTA etrafında yeniden kurmak ve alt navigasyonu 4 sekmeye indirmek.

---

## 2. İncelemenin Kapsamı

| Boyut | Kapsam |
|-------|--------|
| Kaynak kodu | `lib/src/` altındaki 33 ekran, 33 widget, 21 model, 7 provider, 7 servis, 2 tema dosyası |
| Mimari belgeler | ARCHITECTURE.md, AGENTS.md, README.md |
| Önceki denetimler | GEMINI_FULL_LOCAL_AUDIT.md, GEMINI_RELEASE_READINESS.md |
| Görsel inceleme | Kod bazlı çıkarım (ekran görüntüsü bulunmamaktadır) |
| Çalıştırma | Uygulama bu ortamda derlenip çalıştırılamamıştır |

**Kapsam dışı:** Backend SQL şemaları, Supabase Edge Functions, CI/CD pipeline detayları.

---

## 3. İncelenen Dosyalar ve Ekranlar

### Ekranlar (33 dosya)
| # | Dosya | Satır | Açıklama |
|---|-------|-------|----------|
| 1 | app_shell.dart | 495 | Ana kabuk, navigasyon, onboarding akışı |
| 2 | home_screen.dart | 857 | Ana sayfa |
| 3 | categories_tab.dart | 631 | Kategori listesi |
| 4 | subcategory_screen.dart | ~400 | Alt kategori |
| 5 | level_screen.dart | ~530 | Seviye seçimi |
| 6 | play_hub_screen.dart | 552 | Yarışma merkezi |
| 7 | contest_screen.dart | ~470 | Günlük yarışma |
| 8 | matchmaking_screen.dart | ~1080 | 1v1 eşleşme |
| 9 | room_screen.dart | ~960 | Özel oda |
| 10 | tournament_screen.dart | ~900 | Turnuva |
| 11 | quiz_screen.dart | 1522 | Quiz motoru |
| 12 | quiz_result_screen.dart | ~1380 | Sonuç ekranı |
| 13 | review_screen.dart | ~340 | Soru inceleme |
| 14 | leaderboard_screen.dart | 974 | Liderlik tablosu |
| 15 | profile_screen.dart | 784 | Profil |
| 16 | settings_screen.dart | ~1220 | Ayarlar |
| 17 | learning_screen.dart | 1390 | Öğrenme merkezi |
| 18 | story_screen.dart | ~230 | Hikaye modu |
| 19 | shop_screen.dart | ~980 | Mağaza |
| 20 | spin_wheel_screen.dart | ~820 | Çark çevirme |
| 21 | friends_screen.dart | ~480 | Arkadaşlar |
| 22 | sign_in_screen.dart | ~1310 | Giriş |
| 23 | sign_up_screen.dart | ~640 | Kayıt |
| 24 | onboarding_screen.dart | ~610 | İlk açılış turu |
| 25 | avatar_editor_screen.dart | ~560 | Avatar düzenleme |
| 26 | profile_name_gate_screen.dart | ~390 | İsim belirleme |
| 27 | level_placement_screen.dart | ~280 | Seviye testi |
| 28 | favorite_questions_screen.dart | ~310 | Favori sorular |
| 29 | suggest_question_screen.dart | ~550 | Soru önerme |
| 30 | splash_screen.dart | ~100 | Splash |

### Widget'lar (33 dosya)
Öne çıkanlar: coach_mark.dart, tournament_bracket_widget.dart, weekly_performance_chart.dart, strength_map_section.dart, badge_collection_section.dart, zana_daily_card.dart, room_chat.dart, roj_mascot.dart

### Tema
- app_theme.dart (1022 satır): Renk paleti, tipografi, spacing, radius, shadow, gradient sistemi
- app_icons.dart (icon set)

---

## 4. Çalıştırılarak Doğrulanan Ekranlar

**Uygulama bu ortamda çalıştırılamamıştır.**

**Nedenler:**
1. Flutter SDK bu analiz ortamında kurulu değildir.
2. Supabase bağlantı bilgileri (.env) production ortamına aittir; test ortamı mevcut değildir.
3. Firebase yapılandırması (google-services.json, GoogleService-Info.plist) cihaz gerektirir.
4. Gerçek cihaz veya emülatör erişimi bulunmamaktadır.

**Sonuç:** Tüm değerlendirmeler kaynak kodu, widget ağacı yapısı ve mevcut denetim belgelerine dayanmaktadır.

---

## 5. Görsel Olarak İncelenemeyen Ekranlar

Aşağıdaki ekranlar hakkında kod yapısından çıkarım yapılmış ancak gerçek render çıktısı görülmemiştir:

- **Tüm ekranlar** — Hiçbir ekran görsel olarak doğrulanmamıştır
- **Özellikle kritik olanlar:**
  - Quiz ekranı (1522 satır): Zamanlayıcı animasyonu, joker UI, multiplayer sync gösterimi
  - Turnuva bracket: 15.7KB widget, çizim mantığı
  - Spin wheel: Canvas bazlı animasyon
  - Matchmaking: Bekleme ekranı, bot fallback geçişi
  - Leaderboard: Podium animasyonları, tab geçişleri
  - Learning: Flashcard flip, slayt geçişleri

---

## 6. ZanKurd Hakkındaki Dürüst İlk İzlenim

### 6.1 Amacı anlaşılıyor mu?
**Kısmen.** "Kurmancî bilgi yarışması" kimliği onboarding'de iletiliyor, ancak ilk ana sayfa açıldığında 8+ farklı kart tipi (HeroCard, DailyRaceCard, DailyMissionsCard, PlayTeaserCard, RecommendationCard, StatsRow, LeaderboardPreview, QuickPlayGrid) kullanıcıyı "Bu bir yarışma uygulaması mı, dil öğrenme uygulaması mı, sosyal platform mu?" sorusuyla baş başa bırakıyor.

### 6.2 İlk eylem belli mi?
**Hayır.** Ana sayfada birden fazla CTA eşit görsel ağırlıkta sunuluyor. HeroCard (günün teması), DailyRaceCard (günlük yarış) ve PlayTeaserCard (hızlı oyna) birbiriyle rekabet ediyor. Kullanıcı ilk ne yapacağını seçmek zorunda kalıyor — bu seçim yükü (choice overload) engagement'ı düşürür.

### 6.3 Ana CTA belli mi?
**Hayır.** Birincil eylem "bir quiz başlat" olmalı, ancak buna ulaşmanın en az 3 farklı yolu var (PlayTeaser → PlayHub, QuickPlayGrid, DailyRaceCard) ve hiçbiri diğerinden daha belirgin değil.

### 6.4 Özellikler birbirinden ayrışıyor mu?
**Zayıf.** Günlük yarışma (contest), hızlı oyun (bot race), 1v1 eşleşme, oda, turnuva — bu 5 mod arasındaki fark yeni kullanıcıya ilk bakışta açık değil. İsimlendirme Kurmancî olduğunda (Pêşbazî, Yariyê Zû) kavrama süresi daha da uzuyor.

### 6.5 Düzenli mi?
**Orta.** Tema sistemi (AppTheme, AppSpacing, AppRadius) tutarlı uygulanmış; kart dekorasyon çeşitliliği (CardType.primary/secondary/info/glass) iyi tanımlanmış. Ancak ekran bazında kart miktarı ve bilgi yoğunluğu düzen hissini bozuyor.

### 6.6 Premium hissettiriyor mu?
**Kısmen.** Glassmorphism, 3D shadow, gradient sistemi, Lottie animasyonları premium sinyaller veriyor. Ancak 1022 satırlık tema dosyasındaki renk çeşitliliği (brandGreen, playGreen, playPink, playCyan, playPurple, gold, cyan, culturalBrandBg) birleşik bir marka kimliği yerine "her yere farklı renk" hissi yaratabilir.

### 6.7 Çok fazla seçenek mi?
**Evet.** Bu ürünün en büyük UX sorunu budur. Ana sayfa tek başına 8+ bileşen, PlayHub 5 oyun modu, profil 7+ bölüm, ayarlar 12+ seçenek sunuyor. Hick Yasası'na göre (seçenek sayısı arttıkça karar süresi logaritmik artar) bu ürün kullanıcıyı felç ediyor.

---

## 7. En Büyük 10-20 Ürün ve UX Problemi

### Problem 1: Ana Sayfa Bilgi Aşırı Yüklemesi
- **Sorun:** 8+ farklı kart tipi tek bir scroll'da sıralanıyor; net hiyerarşi yok.
- **Ekranlar:** HomeScreen (857 satır), home/ klasörü (10 bileşen)
- **Etki:** Yeni kullanıcı ilk 5 saniyede ne yapacağını bilemez → bounce rate artar.
- **Neden:** Her yeni özellik ana sayfaya "bir kart daha" olarak eklenmiş; geriye dönük budama yapılmamış.
- **Çözüm:** Ana sayfayı 3 bölüme daralt: (1) Tek birincil CTA kartı ("Şimdi Oyna" — otomatik mod seçimi), (2) Günlük görev ilerleme çubuğu, (3) Devam et / öneri. Kalan öğeler ilgili sekmelere taşınsın.

### Problem 2: Oyun Modu Karmaşıklığı
- **Sorun:** 7 farklı oyun modu (solo, hızlı, 1v1, oda, turnuva, günlük yarışma, oda paylaşım) yeni kullanıcıyı bunaltıyor.
- **Ekranlar:** PlayHubScreen, ContestScreen, MatchmakingScreen, RoomScreen, TournamentScreen
- **Etki:** Analiz felci; kullanıcı hiçbir moda girmeden çıkar.
- **Neden:** Her mod teknik olarak farklı, ancak kullanıcı perspektifinden "soru cevapla" eyleminin varyasyonları.
- **Çözüm:** İlerleme bazlı açılım: Yeni kullanıcıya yalnızca "Hızlı Oyun" ve "Günlük Yarışma" göster. Seviye 5'ten sonra 1v1 kilidini aç. Seviye 10'dan sonra Turnuva ve Oda göster. PlayHub'ı progressive disclosure ile yeniden tasarla.

### Problem 3: Öğrenme İçeriği Gizli Konumda
- **Sorun:** LearningScreen (1390 satır, 8 kategori, flashcard, slayt, mini quiz, hikaye) ana navigasyonda değil; yalnızca ana sayfadaki bir kart üzerinden erişiliyor.
- **Ekranlar:** LearningScreen, StoryScreen
- **Etki:** Ürünün en değerli içeriği (SM-2 tekrar, 8 öğrenme kategorisi) kullanıcıların %80+'sı tarafından keşfedilmeyebilir.
- **Neden:** Öğrenme özelliği sonradan eklenmiş; mevcut navigasyona entegre edilmemiş.
- **Çözüm:** Alt navigasyona "Fêrbûn/Öğren" sekmesi olarak ekle; Kategoriler sekmesiyle birleştir veya onun yerine koy.

### Problem 4: Alt Navigasyon Dengesizliği
- **Sorun:** 5 sekme (Sereke, Kategorî, Pêşbazî, Rêz, Profîl) eşit ağırlıkta ancak kullanım sıklığı eşit değil. Liderlik tablosu günde 1-2 kez bakılır, Ana Sayfa ve Oyna her oturumda kullanılır.
- **Ekranlar:** AppShell (bottom navigation)
- **Etki:** Nadir kullanılan ekranlar (Liderlik) birincil navigasyon alanını işgal ediyor.
- **Neden:** "5 sekme standart" yaklaşımıyla konumlandırılmış; kullanım verisine dayalı optimizasyon yapılmamış.
- **Çözüm:** 4 sekme: Sereke (Ana), Fêrbûn (Öğren), Bilîze (Oyna), Profîl. Liderlik → Ana Sayfa içi bileşen veya Profil altı. Kategoriler → Öğren sekmesi içine entegre.

### Problem 5: Quiz Ekranı Parametre Karmaşıklığı
- **Sorun:** QuizScreen tek bir widget içinde 8+ parametre kombinasyonu (room, practice, botRace, dailyQuiz, is1v1, experience, contestId, categoryFilter) yönetiyor → 1522 satır.
- **Ekranlar:** quiz_screen.dart
- **Etki:** Bakım zorluğu, farklı modlarda tutarsız davranış, yeni özellik ekleme riski.
- **Neden:** Tek dosya yaklaşımı; modlar arası ortak mantık paylaşımı tercih edilmiş.
- **Çözüm:** QuizScreen'i "QuizEngine" (ortak) + "SoloQuizView", "MultiplayerQuizView", "ContestQuizView" olarak ayır. Bu UX değil mimari sorundur ancak UX tutarlılığını doğrudan etkiler.

### Problem 6: Onboarding Yetersizliği
- **Sorun:** 5 slaytlık PageView + SignIn akışı var ancak ilk quiz deneyimi (gerçek değer anı) onboarding'e dahil değil.
- **Ekranlar:** OnboardingScreen, SignInScreen, ProfileNameGateScreen
- **Etki:** Kullanıcı değer anına (ilk doğru cevap heyecanı) ulaşmadan kayıt duvarına çarpıyor.
- **Neden:** Onboarding "uygulama tanıtımı" formatında; "deneyim odaklı" değil.
- **Çözüm:** Onboarding'i "1 soru cevapla → doğru → kutlama → şimdi kayıt ol ve devam et" formatına dönüştür. Kayıt duvarını ilk değer anının arkasına taşı.

### Problem 7: Mağaza Değer Önerisi Belirsiz
- **Sorun:** Mağaza (38.5KB, ~980 satır) kapsamlı ürün listesi sunuyor ancak ürünlerin oyun içi etkisi (joker ne zaman işe yarar? avatar çerçevesi ne sağlar?) yeterince iletilmiyor.
- **Ekranlar:** ShopScreen
- **Etki:** Coin biriktirme motivasyonu düşük; "neden harcayayım?" sorusu yanıtsız.
- **Neden:** Mağaza kataloğu teknik olarak eklenmiş ancak bağlamsal satış (contextual upsell) yapılmamış.
- **Çözüm:** Joker bittiğinde "Şimdi al, devam et" çağrısı, quiz sonrası "bu soruyu kaçırdın — joker olsaydı kazanırdın" mesajı. Mağazayı bağımsız hedef değil, akış içi mikro-tetikleyici olarak konumlandır.

### Problem 8: Lig Sistemi UI Eksikliği
- **Sorun:** Model katmanında Lig (Zêr/Zîv/Bronz) tanımlı ancak UI'da gösterilmiyor.
- **Ekranlar:** LeaderboardScreen (lig bilgisi yok), ProfileScreen (lig rozeti yok)
- **Etki:** Uzun vadeli motivasyon kancası (haftalık lig yükselme/düşme) kullanılamıyor.
- **Neden:** Backend hazır, frontend geliştirmesi tamamlanmamış.
- **Çözüm:** Liderlik ekranına lig göstergesi + yükselme/düşme animasyonu ekle. Profil'de mevcut lig rozetini göster. Haftalık sonuçlarda "Bu hafta Zîv'e yükseldin!" bildirimi.

### Problem 9: Arkadaş Sistemi Keşfedilebilirlik Sorunu
- **Sorun:** Arkadaş ekleme, çevrimiçi durum, arkadaşla oynama özellikleri var ancak ana akıştan kopuk.
- **Ekranlar:** FriendsScreen (PlayHub veya Profil'den erişim)
- **Etki:** Sosyal özellikler kullanılmıyor → retention düşük.
- **Neden:** Arkadaşlar ayrı bir ekran; oyun akışına entegre değil.
- **Çözüm:** Quiz sonucu ekranına "Arkadaşını davet et" CTA'sı ekle. Eşleşme bekleme ekranında "arkadaş çevrimiçi" bilgisi göster. Ana sayfada "Arkadaşlarının bu haftaki skoru" mini widget'ı.

### Problem 10: Ayarlar Ekranı Aşırı Uzun
- **Sorun:** Settings (~1220 satır) içinde 12+ seçenek: ad değiştirme, seviye testi, çocuk modu, dil, tema, hareket, ses, bildirim, hesap silme, nasıl oynanır, gizlilik, hakkında.
- **Ekranlar:** SettingsScreen
- **Etki:** Önemli ayarlar (dil, tema) ile nadir kullanılanlar (hesap silme, gizlilik) aynı görsel ağırlıkta.
- **Neden:** Her ayar düz liste halinde eklenmiş; gruplama yok.
- **Çözüm:** 3 grup: "Tercihler" (dil, tema, ses, bildirim), "Hesap" (ad, çocuk modu, hesap silme), "Bilgi" (nasıl oynanır, gizlilik, hakkında). Gruplar arası boşluk ve başlık ile hiyerarşi oluştur.

### Problem 11: Günlük Görev Motivasyon Eksikliği
- **Sorun:** DailyMissionsCard 3 görev gösteriyor (answerCorrect, completeQuiz, useWildcard vb.) ancak tamamlandığında ne olacağı (toplam ödül, bonus) görsel olarak yeterince vurgulanmıyor.
- **Ekranlar:** HomeScreen → DailyMissionsCard
- **Etki:** Görev tamamlama oranı düşük kalabilir.
- **Neden:** Görevler bilgi kartı olarak sunulmuş; progress + ödül vurgusu zayıf.
- **Çözüm:** "3/3 görevi tamamla → 50 bonus coin" ana ödül çubuğu ekle. Her görev tamamlandığında çek işareti animasyonu + coin splash. Tamamlanmamış görevlere "X soru kaldı" geri sayımı.

### Problem 12: Responsive Breakpoint Sorunları
- **Sorun:** 768px'de NavigationRail'e geçiş var ancak 600-768px arası (büyük telefon/küçük tablet) belirsiz.
- **Ekranlar:** AppShell, tüm ekranlar
- **Etki:** Tablet dikey modunda (typicaly ~800px) rail açılıyor ancak içerik dar kalıyor.
- **Neden:** Tek breakpoint (768px) kullanılmış; ara boyutlar için adaptasyon yok.
- **Çözüm:** 3 breakpoint: <600 (telefon, bottom nav), 600-1024 (tablet, compact rail), >1024 (masaüstü, expanded rail + sidebar). ConstrainedBox(maxWidth: 800) zaten var — iyi.

### Problem 13: Streak Kırılma Korkusu Eksik
- **Sorun:** Streak (günlük seri) var ancak kaybetme riski/korkusu UI'da yeterince iletilmiyor.
- **Ekranlar:** HomeScreen (StatsRow), ProfileScreen
- **Etki:** Streak tek başına güçlü bir retention mekanizması — ancak "kaybedeceksin" uyarısı olmadan etkisi %50 düşer.
- **Neden:** Streak yalnızca sayı olarak gösteriliyor.
- **Çözüm:** 20:00'dan sonra streak kırılacaksa push bildirim "Serinizi kaybetmemek için 1 soru çözün!". Ana sayfada streak tehlike durumunda kırmızı vurgu + alev ikonu titreşimi.

### Problem 14: Quiz Sonuç Ekranı Bilgi Yoğunluğu
- **Sorun:** QuizResultScreen (54.1KB, ~1380 satır) çok fazla bilgi (XP, coin, doğruluk, süre, sıralama, rozetler, paylaşım, inceleme, tekrar oyna) sunuyor.
- **Ekranlar:** quiz_result_screen.dart
- **Etki:** Kullanıcı "kazandım" veya "kaybettim" duygusunu hissetmeden bilgi bombardımanına uğruyor.
- **Neden:** Her ödül mekanizması sonuç ekranına eklenmiş.
- **Çözüm:** 2 aşamalı sonuç: (1) İlk 2 saniye — yalnızca büyük emoji + skor animasyonu. (2) Aşağı scroll ile detaylar. Birincil CTA: "Tekrar Oyna" (kazandıysa) veya "Konuyu Öğren" (kaybettiyse).

### Problem 15: Bildirim Ekranı Yokluğu
- **Sorun:** Uygulama içi bildirim merkezi (inbox) bulunmuyor; yalnızca push bildirim var.
- **Ekranlar:** Yok (eksik)
- **Etki:** Arkadaş istekleri, turnuva davetiyeleri, lig değişimleri sessizce kaybolabiliyor.
- **Neden:** Bildirim servisi yalnızca Firebase push'a bağlı; in-app inbox geliştirilmemiş.
- **Çözüm:** AppShell'e zil ikonu (AppBar veya fab) ekle → NotificationInboxScreen. Okunmamış sayısı badge olarak göster. İçerik: arkadaş istekleri, turnuva davetiyeleri, görev hatırlatıcıları.

### Problem 16: Çark (SpinWheel) Bağlam Kopukluğu
- **Sorun:** Günlük çark çevirme (SpinWheelScreen, 820 satır) mevcut ancak hangi akıştan erişildiği belirsiz.
- **Ekranlar:** SpinWheelScreen
- **Etki:** Günlük login ödülü olarak tasarlanmış ancak keşfedilebilirliği düşük.
- **Neden:** Çark ayrı bir ekran; günlük döngüye entegre değil.
- **Çözüm:** Günlük ilk açılışta otomatik olarak çark animasyonunu göster (auto-trigger). Kullanıcı "Çevir" butonuna bassın, ödülü alsın, ana sayfaya düşsün. Çark'ı ayrı menüden kaldır.

### Problem 17: Misafir Girişi Tamamlanmamış
- **Sorun:** Misafir girişi akışı başlatılmış ancak tamamlanmamış (kod yorumlarında belirtilmiş).
- **Ekranlar:** SignInScreen
- **Etki:** Kayıt duvarı → yüksek terk oranı. Kullanıcı uygulamayı denemeden hesap oluşturmak istemiyor.
- **Neden:** Teknik implementasyon yarım kalmış.
- **Çözüm:** Misafir modunu tamamla: Sınırlı özelliklerle (solo quiz, öğrenme) kayıtsız kullanım → 3. oturumda "Kayıt ol, ilerlemeni kaybet" çağrısı. Supabase anonymous auth kullanılabilir.

---

## 8. Mevcut Özellik ve Ekran Haritası

```
ZanKurd Uygulama Haritası (Mevcut Durum)
├── Onboarding (5 slayt)
├── Giriş/Kayıt
│   ├── Google Sign-In
│   ├── E-posta/Şifre
│   └── Misafir (tamamlanmamış)
├── ProfileNameGate (zorunlu isim)
├── CoachMark Tour (3 adım)
├── [TAB 0] Ana Sayfa (Sereke)
│   ├── HeroCard (günün teması)
│   ├── StatsRow (coin + streak)
│   ├── DailyRaceCard (günlük yarış)
│   ├── DailyMissionsCard (3 görev)
│   ├── PlayTeaserCard (yarış sekmesine yönlendirme)
│   ├── RecommendationCard (önerilen soru)
│   ├── LeaderboardPreview (top 3)
│   ├── QuickPlayGrid (hızlı modlar)
│   └── ZanaDailyCard (günlük bilgi)
├── [TAB 1] Kategoriler (Kategorî)
│   ├── Kategori Listesi (16 kategori, görsellerle)
│   ├── SubcategoryScreen
│   ├── LevelScreen (1-5)
│   └── QuizScreen → QuizResultScreen → ReviewScreen
├── [TAB 2] Yarışma (Pêşbazî / Bilîze)
│   ├── Günlük Yarışma (ContestScreen)
│   ├── 1v1 Eşleşme (MatchmakingScreen)
│   ├── Oda Oluştur (RoomScreen)
│   ├── Turnuva (TournamentScreen)
│   └── Hızlı Oynama Grid
├── [TAB 3] Liderlik (Rêz)
│   ├── Günlük Tab
│   ├── Haftalık Tab (varsayılan)
│   ├── Aylık Tab
│   └── Arkadaşlar Tab
├── [TAB 4] Profil (Profîl)
│   ├── Avatar + Ad + Seviye/XP
│   ├── Coin Bakiyesi
│   ├── İstatistikler
│   ├── Haftalık Performans Grafiği
│   ├── Güç Haritası
│   ├── Rozetler
│   └── Navigasyon → Avatar Editor, Settings, Favorites, Shop, SuggestQuestion
├── Öğrenme (HomeScreen'den erişim)
│   ├── 8 Kategori
│   ├── Flashcard Modu
│   ├── Slayt Dersleri
│   ├── Mini Quiz
│   └── StoryScreen (dallanan hikaye)
├── Mağaza (Profil'den erişim)
│   ├── Joker Paketleri
│   ├── Kozmetikler
│   └── VIP İçerikler
├── Çark (SpinWheel)
├── Arkadaşlar (PlayHub/Profil'den erişim)
└── Ayarlar (Profil'den erişim)
    ├── Ad Değiştirme
    ├── Seviye Testi
    ├── Çocuk Modu
    ├── Dil (KU/TR)
    ├── Tema (Dark/Light)
    ├── Hareket Azaltma
    ├── Ses
    ├── Bildirim
    ├── Hesap Silme
    ├── Nasıl Oynanır
    ├── Gizlilik
    └── Hakkında
```

---

## 9. Mevcut Bilgi Mimarisinin Eleştirisi

### Güçlü Yönler:
1. **Kategori → Alt Kategori → Seviye → Quiz** akışı net ve öğrenilebilir.
2. **Tab bazlı navigasyon** kullanıcının konumunu koruyor (IndexedStack).
3. **İki dilli destek** tutarlı şekilde uygulanmış (context.s() helper).

### Zayıf Yönler:

| Problem | Açıklama | Etki |
|---------|----------|------|
| **Düz hiyerarşi** | 5 sekme eşit derinlikte; "Oyna" ve "Öğren" aynı seviyede "Liderlik" ile | Önemli ile önemsizin ayrışamaması |
| **Öğrenme erişilemezliği** | LearningScreen tab'da değil; HomeScreen callback'iyle açılıyor | %80+ kullanıcı bu özelliği görmeyecek |
| **Mağaza erişimi** | Profil → Shop; oyun içi bağlamdan kopuk | Satın alma motivasyonu düşük |
| **Arkadaşlar dağınıklığı** | PlayHub'dan "Oda" → Arkadaşlar, Leaderboard'da "Arkadaşlar" tabı, Profil'den erişim | Tutarsız mental model |
| **Çark konumu** | Nereden erişildiği kod incelemesinde belirsiz | Günlük ödül mekanizması kayıp |
| **Liderlik bağımsızlığı** | Tam bir sekme ancak pasif içerik; interaksiyon düşük | Değerli alan israfı |

### Temel Sorun:
Mevcut bilgi mimarisi **özellik odaklı** (her özelliğe bir yer) — olması gereken **görev odaklı** (kullanıcının yapmak istediği şeye göre). Kullanıcı "Kürtçe öğrenmek" veya "arkadaşımla yarışmak" istiyor; "Kategoriler sekmesine git, alt kategori seç, seviye seç, quiz başlat" demiyor.

---

## 10. Önerilen Yeni Uygulama Haritası

```
ZanKurd Yeni Uygulama Haritası (Önerilen)
├── Onboarding (Deneyim Odaklı)
│   ├── 1 Soru Dene (kayıtsız)
│   ├── Doğru → Kutlama
│   ├── Kayıt/Giriş
│   └── İsim + Avatar Seçimi
├── [TAB 0] Ana Sayfa (Sereke)
│   ├── Kişiselleştirilmiş Selamlama + Streak
│   ├── TEK BİRİNCİL CTA: "Şimdi Oyna" (akıllı mod seçimi)
│   ├── Günlük Görev İlerleme Çubuğu (3/3)
│   ├── Devam Et / Öneri Kartı (SM-2 bazlı)
│   ├── Lig Durumu Mini Kartı
│   └── Arkadaş Aktivitesi (compact)
├── [TAB 1] Öğren (Fêrbûn)
│   ├── Kategori Grid (16 kategori, mastery göstergesi)
│   │   ├── Alt Kategori → Seviye → Quiz
│   │   └── Flashcard / Slayt / Hikaye
│   ├── Günlük Tekrar (SM-2 otomatik)
│   └── Güç Haritası (profil'den taşındı)
├── [TAB 2] Oyna (Bilîze)
│   ├── HERO: Günlük Yarışma (varsa aktif tema)
│   ├── Hızlı Oyun (bot - varsayılan 1 dokunuş)
│   ├── 1v1 Eşleşme (seviye 5+ kilidi açılır)
│   ├── Turnuva (seviye 10+ kilidi açılır)
│   ├── Arkadaşla Oyna (oda kodu)
│   └── Çark (günlük 1x, auto-prompt)
├── [TAB 3] Profil (Profîl)
│   ├── Avatar + Ad + Lig Rozeti
│   ├── Seviye/XP İlerleme
│   ├── İstatistikler (doğruluk, toplam, galibiyet)
│   ├── Haftalık Performans
│   ├── Rozetler/Başarımlar
│   ├── Liderlik Tablosu (inline, top 10)
│   ├── Arkadaşlar
│   ├── Mağaza
│   ├── Favori Sorular
│   └── Ayarlar
└── Sistem Ekranları
    ├── Quiz (tüm modlar)
    ├── Sonuç (2 aşamalı)
    ├── Bildirim Merkezi (yeni)
    └── İnceleme (yanlış sorular)
```

---

## 11. Önerilen Kesin Alt Navigasyon

**Karar: 4 sekme.**

| # | Ad (KU/TR) | İkon | Ana Özellikler | Neden Bu Sırada | Değer |
|---|------------|------|----------------|-----------------|-------|
| 1 | Sereke / Ana | house | Kişisel dashboard, CTA, görevler, streak | İlk açılış noktası; "bugün ne yapayım?" sorusuna cevap | Günlük engagement başlatıcı |
| 2 | Fêrbûn / Öğren | book-open | Kategoriler, dersler, flashcard, tekrar, güç haritası | Ürünün eğitim kimliğinin birincil ifadesi | İçerik keşfi, derinlik |
| 3 | Bilîze / Oyna | gamepad | Tüm oyun modları, turnuva, çark | Rekabet ve eğlence merkezi | Sosyal + motivasyon |
| 4 | Profîl / Profil | user-circle | Kişisel alan, liderlik, arkadaşlar, mağaza, ayarlar | Kişisel ilerleme ve sosyal | Retention kancası |

**Neden 4, 5 değil:**
- Liderlik bağımsız sekme olmaktan çıkıyor → Profil altına kompakt biçimde gömülüyor.
- Kategoriler bağımsız sekme olmaktan çıkıyor → "Öğren" sekmesinin ana içeriği oluyor.
- 4 sekme başparmak erişimine daha uygun; her ikon daha büyük dokunma alanı alıyor.
- Duolingo (4), Kahoot (4), Brilliant (4) — başarılı referanslar 4 sekme kullanıyor.

---

## 12. Önerilen Kesin Ana Sayfa Sırası

Ana sayfa "bugün ne yapayım?" sorusuna 3 saniyede cevap vermelidir.

| Sıra | Bileşen | Kalmalı mı? | Kart Türü | Öncelik | Hedef Ekran | Gösterilecek Bilgi |
|------|---------|-------------|-----------|---------|-------------|-------------------|
| 1 | Selamlama + Streak | EVET (yeni format) | İnline (kart değil) | - | - | "Silav [İsim]! 🔥 7 roj" |
| 2 | Birincil CTA: "Şimdi Oyna" | YENİ | CardType.primary, gradient, büyük | P0 | Akıllı mod seçimi (son kategoriden devam veya günlük yarışma) | "Destpêke!" + otomatik mod açıklaması |
| 3 | Günlük Görev İlerleme | EVET (daraltılmış) | CardType.secondary, compact bar | P1 | DailyMissionsDetail | "2/3 tamamlandı — 50 coin bonus'a X kaldı" |
| 4 | Devam Et / Tekrar Kartı | YENİ (RecommendationCard dönüşümü) | CardType.secondary | P1 | QuizScreen (SM-2 bazlı) | "Dün yanlış yaptığın 3 soru seni bekliyor" |
| 5 | Lig Durumu | YENİ | CardType.info, compact | P2 | LeaderboardScreen | "Zîv Lig — 340. sıra — yükselmeye 12 puan" |
| 6 | Arkadaş Aktivitesi | YENİ | CardType.info, mini | P3 | FriendsScreen | "Rojda şimdi çevrimiçi • Baran 850 puan yaptı" |

**Kaldırılan bileşenler:**
- HeroCard (günün teması) → Kaldır. Tema bilgisi Günlük Yarışma kartı içine göm.
- DailyRaceCard → "Şimdi Oyna" CTA'sı ile birleşti.
- PlayTeaserCard → Kaldır. Zaten Oyna sekmesi var.
- QuickPlayGrid → Kaldır. Oyna sekmesine taşındı.
- LeaderboardPreview → Lig Durumu mini kartı ile değişti (daha az yer, daha net bilgi).
- ZanaDailyCard → Kaldır veya Öğren sekmesine taşı (günlük bilgi notu olarak).

**Sonuç:** Ana sayfa 8+ kartten 5-6 kompakt bileşene iner. Scroll derinliği max 1.5 ekran yüksekliği.

---

## 13. Önerilen Oyna Merkezi (Bilîze Sekmesi)

PlayHub sekmesi "tüm rekabet modlarının evi" olarak tasarlanmalıdır. Progressive disclosure ile yeni kullanıcıyı bunaltmadan, deneyimli kullanıcıya derinlik sunmalıdır.

| Sıra | Ad (KU/TR) | Açıklama | Görsel Ağırlık | Hedef | Dokunuş |
|------|------------|----------|---------------|-------|--------|
| 1 | Yariyê Rojane / Günlük Yarışma | Tema bazlı günlük contest, 10 soru, ödül sıralaması | **En yüksek** — Hero kart, gradient, countdown | ContestScreen | 1 |
| 2 | Lîstika Bilez / Hızlı Oyun | 3 bot'a karşı 5 soru, 15sn/soru | **Yüksek** — Büyük buton, tek dokunuş | QuizScreen(botRace) | 1 |
| 3 | 1v1 Pêşbazî / 1v1 Eşleşme | Gerçek oyuncuyla veya bot fallback. Seviye 5+ | **Orta** — Standart kart | MatchmakingScreen | 1 |
| 4 | Tûrnament / Turnuva | 16 oyuncu bracket, 4 tur. Seviye 10+ | **Orta** — Kart + kilit (kilitliyse) | TournamentScreen | 2 |
| 5 | Bi Hevalan / Arkadaşla Oyna | Oda kodu oluştur veya gir | **Düşük** — Kompakt satır | RoomScreen | 2 |
| 6 | Çerxa Bextê / Günlük Çark | Günde 1x spin, 10-100 coin | **Düşük** — Mini kart, kullanılmamışsa göster | SpinWheelScreen | 1 |

**Tasarım kararları:**
- İlk 2 seçenek (Günlük Yarışma + Hızlı Oyun) ekranın üst yarısını kaplamalı; tek dokunuşla başlamalı.
- Seviye kilitleri görsel olarak açık: gri overlay + kilit ikonu + "Seviye X'te açılır" metni.
- Kilidi açılmış modlar için confetti animasyonu (ilk kez).
- Günlük çark kullanılmışsa o kart kaybolur (yer kazanımı).

---

## 14. Önerilen Dersler/Öğren Merkezi (Fêrbûn Sekmesi)

Öğren sekmesi mevcut "Kategoriler" sekmesi + "LearningScreen" birleşiminden oluşmalıdır.

### Yapı:

```
Fêrbûn (Öğren) Sekmesi
├── [Üst] Günlük Tekrar Çağrısı (SM-2 bazlı)
│   └── "5 soru tekrar için hazır" → QuizScreen(review)
├── [Orta] Kategori Grid (3 sütun)
│   ├── Her kart: Kategori görseli + mastery progress ring
│   ├── Dokunma → SubcategoryScreen (mevcut akış korunur)
│   └── Kilitli kategoriler gri (seviye bazlı progressive unlock)
├── [Alt] Öğrenme Modları
│   ├── Flashcard (tüm kategoriler, SM-2 sıralı)
│   ├── Günlük Bilgi Kartı (ZanaDailyCard buraya taşındı)
│   └── Hikaye Modu (StoryScreen)
└── [Footer] Güç Haritası (radar chart)
```

### Tasarım kararları:
- **Günlük Tekrar kartı** her zaman en üstte; SM-2 algoritmasının önerdiği sorulara yönlendirir. Tekrar yoksa kaybolur.
- **Kategori grid** mevcut CategoriesTab ile aynı mantık; mastery ring (0-100% halka) eklenir.
- **Flashcard modu** ayrı navigasyon çıkışı; LearningScreen'deki mevcut mantık korunur.
- **Güç Haritası** profil ekranından buraya taşınır — öğrenme kararını yönlendirir.

### Mevcut LearningScreen'in kaderi:
- 8 öğrenme kategorisi → Fêrbûn sekmesinin alt modları olur.
- Slayt dersleri → Her kategorinin SubcategoryScreen'ine "Ders" butonu olarak eklenir.
- Mini quiz → Mevcut quiz altyapısına bağlı; değişiklik gerekmez.
- Hikaye modu → "Öğrenme Modları" bölümünde bağımsız giriş noktası.

---

## 15. Yarışmalar ve Oyunlaştırma Sistemi

### Mevcut Durum:
| Mekanizma | Durum | Etki |
|-----------|-------|------|
| XP/Seviye | Çalışıyor | Orta — seviye atlama anı kutlanmıyor |
| Coin | Çalışıyor | Düşük — harcama motivasyonu zayıf |
| Streak | Çalışıyor | Orta — kırılma korkusu eksik |
| Günlük Görevler | Çalışıyor | Düşük — bonus vurgusu zayıf |
| Rozetler | Çalışıyor | Düşük — koleksiyon hissi yetersiz |
| Lig | Model hazır, UI yok | Sıfır — en güçlü retention kancası kullanılamıyor |
| Turnuva | Çalışıyor | Orta — takvim/duyuru eksik |
| Çark | Çalışıyor | Düşük — bağlam kopuk |

### Önerilen Oyunlaştırma Döngüsü:

**Günlük Döngü:**
1. Uygulama açılışı → Çark otomatik teklif
2. Ana sayfa → Streak + görev ilerleme
3. Tek birincil CTA → Quiz başlat
4. Quiz sonrası → XP + coin animasyonu → görev tamamlanma toast
5. 3/3 görev → Bonus coin + kutlama

**Haftalık Döngü:**
1. Pazartesi → Lig sıfırlanma, yeni hafta motivasyonu
2. Pazar → Lig sonuçlanma: yükselme/düşme bildirimi
3. Haftalık performans özeti (push)

**Aylık Döngü:**
1. Turnuva takvimi (ayda 2-4)
2. Aylık rozet/başarım özetleri
3. Sezonluk tema değişimi

### Lig Sistemi UI Önerisi:
- 3 lig: Zêr (Altın, top 10), Zîv (Gümüş, 11-25), Bronz (26+)
- Hafta sonu: top 3 yükselir, alt 3 düşer
- Yükselme → confetti + özel rozet
- Düşme → "Bu hafta geri dön!" motivasyon mesajı

### Streak Güçlendirme:
- 7 gün → Bronz alev rozeti
- 30 gün → Gümüş alev rozeti
- 100 gün → Altın alev rozeti
- Streak freeze: Mağazadan 1 gün koruma (200 coin)
- Push bildirim 20:00: "Streak'in tehlikede!"

