# ZanKurd Tam Ürün Denetimi — 15 Temmuz 2026

## 1. Yönetici özeti

ZanKurd'un temel ürün akışları çalışıyor; mobil öncelikli yerleşim, koyu tema, kategori hiyerarşisi, quiz geri bildirimi ve sonuç akışı genel olarak profesyonel bir temel sunuyor. Ancak mevcut kaynak sürümü yayın adayı olarak kabul edilmemelidir. Dört yayın engeli öne çıkıyor:

1. `dart analyze` 26 hatayla başarısız oluyor; hataların tamamı Widgetbook girişinde eksik paket/API çözümlemesiyle ilgili.
2. Kurmancî arayüz içinde gerçek quiz soruları, seçenekleri ve açıklamaları yoğun biçimde Türkçe veya karışık dilde. Bu, ürünün ana vaadini doğrudan zedeliyor.
3. Android release yapılandırması, release keystore yoksa sessizce debug signing'e düşüyor.
4. Uygulama sürümü `1.8.1+11` olduğu hâlde ayarlar ekranındaki hata durumuna ait fallback `1.8.0+10` olarak kalmış.

Test ve web build baseline'ı başarılıdır: 549 test geçti; standart web ve WASM build tamamlandı. Canlı site ile yerel sürüm davranış, ilk ekran, metin yapısı, `version.json` ve service-worker açısından çok yakın; fakat derlenmiş WASM/MJS hash'leri birebir eşleşmediği için canlı sürümün tam olarak `f590566` olduğu kanıtlanamamıştır.

Önerilen ilk paket; yalnızca yayın güvenliği ve doğrulanabilirlik konularını içeren küçük bir P0 paketidir: analyzer kapsamı/Widgetbook bağımlılığı, Android release signing fail-fast, sürüm fallback'i ve soru bankası için yayın kapısı. Görsel iyileştirmeler bundan sonra ayrı küçük paketlere bölünmelidir.

## 2. Audit ortamı

| Alan | Değer |
|---|---|
| Tarih | 2026-07-15 |
| Audit worktree | `C:\src\zankurd_audit_2026-07-15` |
| Uygulama kökü | `C:\src\zankurd_audit_2026-07-15\zankurd_mobile` |
| Flutter | 3.44.1 stable |
| Dart | 3.12.1 |
| Yerel web sunucusu | `http://127.0.0.1:53001` (audit sonunda durduruldu) |
| Canlı hedef | [zankurd.com](https://zankurd.com) |
| İncelenen temel viewport'lar | 320×568, 390×844, 768×1024, 844×390, 1440×900 |

`flutter pub get` daha önce başarıyla tamamlandığından tekrar çalıştırılmadı. Windows satır sonu davranışının değiştirdiği yedi generated plugin dosyası, kullanıcı tarafından açıkça izin verilen hedefli `git restore --source=HEAD --worktree -- ...` işlemiyle geri alındı. Normal diff/stat/numstat anlamsal içerik göstermedi; `--ignore-space-at-eol --exit-code` başarılıydı.

## 3. Commit ve branch doğrulaması

| Kontrol | Sonuç |
|---|---|
| Branch | `codex/full-product-audit-2026-07-15` |
| HEAD | `f590566bc07cf46d5ea14d3db58ad20e96a0e1bb` |
| Ana checkout branch | `main` |
| Ana checkout HEAD | `f590566bc07cf46d5ea14d3db58ad20e96a0e1bb` |

Audit, doğrulanmış `main` commit'inden ayrılmış izole worktree üzerinde yürütüldü. Branch veya HEAD değiştirilmedi; commit, stash, reset, clean ya da checkout yapılmadı.

## 4. Worktree güvenliği

Ana çalışma dizininde build, test, analyze veya `pub get` çalıştırılmadı. Ana checkout'un son doğrulanan durumu yalnızca şudur:

```text
 M macos/Flutter/GeneratedPluginRegistrant.swift
```

Audit worktree'de uygulama kaynak değişikliği yoktur. Yalnızca bu rapor ve izin verilen audit ekran görüntüleri oluşturuldu. Generated dosyalardaki LF/CRLF artefaktları her baseline adımından sonra aynı dar kapsamlı kontrolle doğrulanıp hedefli olarak geri alındı.

## 5. Baseline sonuçları

| Komut | Sonuç | Süre / ayrıntı |
|---|---|---|
| `dart analyze` | Başarısız, exit 1 | 26 hata; tümü `widgetbook/lib/main.dart` içinde eksik `package:widgetbook/widgetbook.dart` ve çözümlenemeyen Widgetbook API'leri |
| `flutter test --exclude-tags preview` | Başarılı | 549 test, 134.1 sn, `All tests passed!` |
| `flutter build web` | Başarılı | 143.8 sn; WASM dry-run da başarılı |
| `flutter build web --wasm` | Başarılı | 256 sn |

Analyzer başarısızlığı düzeltilmedi; baseline bulgusu olarak bırakıldı. Testlerin geçmesi olumlu olmakla birlikte analyzer yayın kapısını karşılamıyor.

## 6. Canlı–yerel eşleşme değerlendirmesi

### Sonuç

**Yüksek olasılıkla aynı kaynak ailesi ve aynı ürün davranışı; birebir artifact eşleşmesi doğrulanamadı.**

| Kanıt | Canlı / yerel sonucu |
|---|---|
| İlk onboarding ve auth yapısı | Görsel ve metinsel olarak eşleşiyor |
| `version.json` | Aynı SHA-256: `E0F79FB3E169FCAA2D06A71D22D9937D338DB34868BAA0EFBE757659FA5D6B1D` |
| `flutter_service_worker.js` | Aynı SHA-256: `DBFBE64AE5BE5B462ABB97338EB9AF783ED4ED57A8C73A53C2A44488A26F6416` |
| `.mjs` | Boyut ve hash farklı (`43264` / `43327` bayt) |
| `.wasm` | Boyut ve hash farklı (`4491448` / `4492342` bayt) |

WASM farkı; build ortamı, derleyici girdisi veya canlıdaki farklı bir commit nedeniyle oluşabilir. Bu nedenle “canlı tam olarak `f590566`” iddiası desteklenmiyor. Canlı sayfada ilk yüklemede konsol hatası/uyarısı görülmedi; analytics başlangıç bilgisi vardı.

## 7. İncelenen akışlar

- İlk açılış, onboarding, auth ve misafir girişi
- İsim doğrulama, placement ekranı ve ana sayfaya geçiş
- Açık/koyu tema; azaltılmış hareket, çocuk güvenliği, ses ve bildirim ayarları
- Ana sayfa: 320, 390, 768 ve 1440 px genişlikler
- Oyun merkezi, 1v1 kategori seçimi ve çevrimdışı eşleşme hatası
- Günlük yarışma kartı, bot turnuva, mağaza yetersiz bakiye davranışı
- Profil, ayarlar, liderlik tablosu
- Kategori → alt kategori → seviye navigasyonu
- Quiz başlangıcı, tutorial/timer kapısı, doğru, yanlış, timeout ve 10 soruluk sonuç
- Sonuç ekranı, cevap inceleme girişleri, liderlik tablosuna gidip geri dönme
- Canlı sitede yenileme, bilinmeyen deep link SPA fallback ve çevrimdışı yeniden yükleme
- Yerel ve canlı mobil/landscape görünüm
- Pirs Play Store sayfası ve üç ürün ekranı referansı

## 8. İncelenmeyen veya sınırlı incelenen alanlar

- Gerçek çok oyunculu iki cihaz senkronizasyonu yapılmadı.
- Gerçek ödeme/IAP, bildirim teslimi, Google/Apple mağaza imzası ve release yüklemesi denenmedi.
- Gerçek kullanıcı hesabıyla uzun süreli istatistik, arkadaş kodu ve sosyal paylaşım tamamlanmadı.
- Kamera/fotoğraf seçici iOS cihazında denenmedi.
- Tüm 4.386/10.000 soru tek tek editoryal olarak okunmadı; veri dağılımı, mevcut audit raporları, CSV analizi ve runtime örneklemesi kullanıldı.
- Erişilebilirlik gerçek VoiceOver/TalkBack cihaz oturumuyla doğrulanmadı; tarayıcı accessibility snapshot'ları ve görsel kanıt kullanıldı.
- Ağ gecikmesi, paket kaybı ve gerçek düşük donanım profillemesi yapılmadı.

## 9. Ekran bazlı kalite puanı

Puanlar 10 üzerinden; ürün netliği, görsel hiyerarşi, erişilebilirlik ve durum geri bildirimi birlikte değerlendirilmiştir.

| Ekran / akış | Puan | Kısa değerlendirme |
|---|---:|---|
| Onboarding | 8.0 | Temiz, anlaşılır, canlı ve yerel eşleşiyor |
| Auth / misafir | 8.0 | Net giriş; isim validasyonu doğru |
| Placement | 7.5 | Sade ve karar noktası anlaşılır |
| Ana sayfa – koyu | 8.0 | Güçlü kart ayrımı ve modern görünüm |
| Ana sayfa – açık | 5.5 | Açık başlık zemini üzerinde kritik düşük kontrast |
| Oyun merkezi | 7.5 | Mod ayrımı iyi; yarışma fallback'i yanıltıcı |
| 1v1 | 7.0 | Kategori seçimi açık; çevrimdışı hata fazla genel |
| Turnuva | 8.0 | Bot oyuncular dürüstçe etiketlenmiş |
| Mağaza | 7.5 | Yetersiz bakiye güvenli; fiyat/CTA durumu geliştirilebilir |
| Kategori hiyerarşisi | 8.0 | 9 kategori, alt kategori ve seviye adımları anlaşılır |
| Quiz | 5.0 | Mekanik iyi; içerik dili ve solo/oda kimliği ciddi sorun |
| Quiz geri bildirimi | 7.0 | Doğru/yanlış renk + ikon + semantik; timeout etiketsiz |
| Sonuç – koyu | 6.5 | Bilgi zengin; CTA sayısı fazla |
| Sonuç – açık/turuncu | 4.5 | Ödül ve stat metinlerinde kritik kontrast sorunu |
| Liderlik | 7.0 | Veriler okunur; kontrol etiketi ve tüm-zamanlar sekmesi eksik |
| Profil | 6.5 | Görsel düzen iyi; semantik yapı tek büyük gruba çöküyor |
| Ayarlar | 7.5 | Kapsamlı; bazı ikon etiketleri ve sürüm fallback'i sorunlu |
| Responsive genel | 7.0 | Mobil güçlü; 320'de alt içerik kırpılıyor, geniş ekranda boşluk fazla |

## 10. Pirs'ten alınabilecek ürün ilkeleri

Karşılaştırma, [Pirs Play Store sayfası](https://play.google.com/store/apps/details?id=kurdi.leyzok.pirs&hl=tr&pli=1) ve mağazadaki ekran görüntülerine dayanır. Pirs'in mevcut görsel dili eski görünse de şu ürün ilkeleri değerlidir:

- Mod taksonomisini ilk bakışta açık kılmak: grup, 1v1 ve rastgele modlar ayrı ve güçlü kartlar.
- Ana ekranda kullanıcının bir sonraki eylemini hemen görünür yapmak.
- İstatistik, ödül ve ilerlemeyi tek bakışta okunabilir sunmak.
- Sonuç ekranında kupa/yüzde gibi tek bir ana başarı ögesini baskın kılmak.
- Öğrenme, yarışma ve sosyal alanları adlandırma düzeyinde birbirinden ayırmak.

ZanKurd; Pirs'in rengini, logosunu veya yerleşimini kopyalamamalıdır. ZanKurd'un daha modern kart dili korunmalı; yalnızca bilgi mimarisi ve karar netliği alınmalıdır.

## 11. P0 bulguları — yayın öncesi engeller

### P0-1 — Kurmancî ürün içinde Türkçe/karışık quiz içeriği

- **Akış:** Kategori → seviye → solo quiz.
- **Tekrar:** `Ziman > Rêziman` benzeri bir seviyeyi açıp soruları ilerlet.
- **Gerçek:** `Kurmancî'de "dev" ne demek?`, Türkçe seçenekler ve Türkçe açıklamalar; ayrıca `Görsel etiketi ... Doğru anlam hangisidir?` gibi metinler.
- **Beklenen:** Kurmancî arayüzde doğal, doğrulanmış Kurmancî soru, seçenek ve açıklama.
- **Kanıt:** `local-390x844-quiz-question-dark.png`, `local-390x844-quiz-correct.png`, `local-390x844-quiz-wrong.png`.
- **Konsol/ağ:** Runtime hatası değil; içerik/veri kalitesi.
- **Muhtemel alanlar:** Offline soru bankası, Supabase soru kayıtları, import CSV'leri ve yayınlama/audit araçları.
- **Sınıf:** Logic/data-sensitive; yalnız UI düzeltmesi değil.
- **Öneri:** Yeni soru yayınını dil, kaynak, cevap dağılımı ve editoryal onay kapısından geçirmek; mevcut canlı havuzu karantinaya alıp dalga dalga gözden geçirmek.
- **Risk:** Otomatik toplu düzeltme anlam ve doğru cevap ilişkisini bozabilir; rollback veri sürümü üzerinden yapılmalı.

### P0-2 — Analyzer baseline'ı başarısız

- **Akış:** CI/release doğrulaması.
- **Tekrar:** Uygulama kökünde `dart analyze`.
- **Gerçek:** 26 hata; `widgetbook/lib/main.dart` içinde paket ve API çözümleme hataları.
- **Beklenen:** Analyzer exit 0 veya Widgetbook'un ayrı paket olarak açıkça kapsam dışına alınması ve kendi bağımlılıklarıyla ayrıca doğrulanması.
- **Kanıt:** Komut çıktısı; görsel yok.
- **Muhtemel dosyalar:** `widgetbook/pubspec.yaml`, `widgetbook/lib/main.dart`, kök analyzer/CI yapılandırması.
- **Sınıf:** Build/tooling-sensitive.
- **Öneri:** Widgetbook bağımlılık sınırını ve CI komutunu tek küçük PR'da netleştirmek; hatayı bastırmadan her iki paketi ayrı analyze etmek.
- **Risk:** Yanlış exclude gerçek uygulama hatalarını saklayabilir.

### P0-3 — Android release build sessizce debug signing'e düşebiliyor

- **Akış:** Android release artifact üretimi.
- **Tekrar:** Release keystore properties olmayan ortamda yapılandırmayı değerlendir/build al.
- **Gerçek:** `android/app/build.gradle.kts` release signing için keystore yoksa `signingConfigs.getByName("debug")` seçiyor.
- **Beklenen:** Release build açık ve anlaşılır hatayla durmalı.
- **Kanıt:** `android/app/build.gradle.kts:54-57`.
- **Muhtemel dosya:** `android/app/build.gradle.kts`.
- **Sınıf:** Release logic-sensitive.
- **Öneri:** Release varyantında fail-fast; CI secret/keystore doğrulaması.
- **Risk:** Yerel geliştirici akışı değişebilir; debug build etkilenmemeli.

### P0-4 — Sürüm fallback'i güncel değil

- **Akış:** Ayarlar → Hakkında/sürüm; `PackageInfo` başarısız olduğu edge/test platformu.
- **Gerçek:** `pubspec.yaml` `1.8.1+11`; fallback `1.8.0+10`.
- **Beklenen:** Tek kaynak veya güncel değer.
- **Kanıt:** `pubspec.yaml:19`, `lib/src/screens/settings_screen.dart:26-27`.
- **Muhtemel dosya:** `lib/src/screens/settings_screen.dart`.
- **Sınıf:** Küçük UI/release metadata; logic-sensitive değil.
- **Öneri:** Sabit fallback'i kaldırmak ya da build-time tek kaynaktan üretmek.
- **Risk:** Düşük; testte `PackageInfo` bulunmadığı senaryolar korunmalı.

## 12. P1 bulguları — yüksek öncelik

| ID | Bulgu | Kanıt | Önerilen küçük çözüm |
|---|---|---|---|
| P1-1 | Açık tema ana başlık/ikon kontrastı çok düşük | `local-390x844-home.png` | Başlık yüzeyi için koyu foreground token ve kontrast testi |
| P1-2 | Açık/turuncu sonuçta coin, XP ve stat metinleri zor okunuyor | `local-390x844-result.png` | Sonuç hero foreground token'larını WCAG kontrastıyla düzelt |
| P1-3 | “Günlük yarışma” verisi yokken kart sessizce generic oda quiz'i başlatıyor | `local-390x844-contest.png`; runtime'da `Ode ZK-9FLR` | Açık boş durum veya devre dışı CTA; generic fallback'i yarışma gibi göstermeme |
| P1-4 | Solo quiz `Ode ZK-...` başlığı ve oda koduyla gösteriliyor | Quiz/result ekranları | Solo ve oda oturum kimliğini model/başlıkta ayır |
| P1-5 | Timeout yalnız doğru cevabı açıyor; “süre doldu” etiketi yok | `local-390x844-quiz-timeout.png` | Renkten bağımsız görünür + semantik timeout mesajı |
| P1-6 | Profil içeriği accessibility ağacında tek büyük grup; bazı ikon butonları etiketsiz | Profil, ayarlar, liderlik snapshot'ları | Bölüm başlığı/istatistik/CTA semantiğini böl; tooltip/semanticLabel ekle |
| P1-7 | Sonuç ekranında beş rakip CTA var | `local-390x844-result.png` | En fazla iki ana CTA; diğerlerini ikincil menü/listede grupla |
| P1-8 | Service worker kendini unregister ediyor; çevrimdışı reload tarayıcı hata sayfası | `live-390x844-offline-reload.png`, `build/web/flutter_service_worker.js:11` | Güncel cache stratejisi veya açık “online gerekli” kabuğu |
| P1-9 | iOS `PrivacyInfo.xcprivacy` yok; kullanım açıklamaları görünmüyor | iOS statik tarama | Kullanılan API/paketlere göre privacy manifest ve gerekli açıklamaları doğrula |
| P1-10 | 1v1 offline hata yalnız “Li hev anîn bi ser neket.” diyor | `local-390x844-1v1-offline.png`; `ERR_INTERNET_DISCONNECTED` | Ağ durumunu ayır, yeniden dene CTA'sı ve açık mesaj ekle |

P1-3 logic-sensitive ayrıntısı: `play_hub_screen.dart` içindeki günlük quiz akışı önce bugünün contest'ini yüklüyor; sonuç `null` ise generic 10 soru ve yerel oda oluşturuyor. Bu davranış veri yokluğu ile gerçek yarışma arasındaki ayrımı gizliyor. Değişiklikten önce ürün kararı gerektirir.

## 13. P2 bulguları — iyileştirme

- Tema token adları gerçek renkleri yansıtmıyor; örneğin `brandOrange` indigo bir değer taşıyor. Semantik isimlendirme borcu var.
- Çok sayıda sabit radius, renk ve boşluk değeri tasarım sistemini dağıtıyor.
- 1440×900 ana sayfada kontrollü max-width olumlu olsa da alt alanda gereğinden fazla boşluk kalıyor.
- 320×568 ilk viewport'ta alt eylemler kırpılıyor; kaydırma mümkün olsa da kritik CTA görünürlüğü test edilmeli.
- Liderlikte günlük/haftalık/aylık/arkadaşlar var, tüm-zamanlar görünümü yok.
- Sonuç landscape görünümünde ilk viewport ana skor kimliğini göstermiyor.
- Mağazada yetersiz bakiyeyle alınamayacak ürünlerin CTA durumu daha öngörülebilir olabilir.
- Soru açıklamalarında dil ve üslup standardı ekran bazında değişiyor.

## 14. Kırık, yanıltıcı veya eksik geri bildirimli kontroller

| Kontrol | Durum | Değerlendirme |
|---|---|---|
| Günlük yarışma kartı | Yanıltıcı | Contest yoksa generic quiz odası açıyor; yarışma bağlamı yok |
| 1v1 rastgele eşleşme (offline) | Çalışıyor ancak eksik | Güvenli şekilde geri dönüyor; hata fazla genel, retry yok |
| Mağaza satın alma (0 coin) | Güvenli | İşlem yapılmıyor, `Bakiyeya te kêm e!` mesajı geliyor |
| Quiz timeout | Eksik geri bildirim | Doğru cevap açılıyor; sürenin dolduğu açıkça söylenmiyor |
| Liderlik yenile butonu | Erişilebilirlik eksik | İkon kontrolü semantik etiketsiz |
| Ayarlar ikon kontrolü | Erişilebilirlik eksik | Snapshot'ta yalnız `button` olarak görünüyor |
| Sonuç aksiyonları | Aşırı kalabalık | Replay, inceleme, hatalar, liderlik, paylaşım aynı seviyeye yaklaşıyor |

## 15. Tasarım sistemi değerlendirmesi

Güçlü taraflar: koyu tema kartları, yuvarlatılmış yüzeyler, kategori renk ayrımı, tutarlı mobil yatay boşluk ve ana navigasyon dili. Zayıf taraflar: token semantiği, açık tema foreground seçimi ve sonuç ekranındaki özel renklerin sistemden kopması.

Önerilen sıra:

1. Önce yalnız kontrast token'larını düzelt ve görsel golden/ekran testi ekle.
2. Sonra renk adlarını yeni semantik alias'larla düzelt; tek seferde geniş rename yapma.
3. Radius/spacing tekrarlarını sadece dokunulan ekranlarda kademeli birleştir.
4. Ana CTA, ikincil CTA ve bilgi kartı hiyerarşisini yazılı bir mini sözleşmeye bağla.

## 16. Dil ve mikro metin kalitesi

Arayüzün önemli kısmı Kurmancî ve tutarlı; ancak çekirdek quiz içeriği bu kaliteyi boşa çıkarıyor. Türkçe soru kalıpları Kurmancî apostrof/ek yapısıyla karışıyor, seçenekler Türkçe kalıyor ve açıklamalar iki dil arasında geçiş yapıyor. Bu yalnız çeviri sorunu değil; kaynak, doğru cevap ve açıklama birlikte editoryal doğrulama gerektiriyor.

UI mikro metninde de “oda”, “solo”, “yarışma” ve “eşleşme” kavramları aynı kullanıcı yolculuğunda birbirine karışıyor. Ürün sözlüğü oluşturulmalı; teknik room ID yalnız gerçek oda bağlamında gösterilmeli.

## 17. Soru bankası ve editoryal kalite

Mevcut tracked rapor ve CSV'lerin salt okunur analizi şu tabloyu veriyor:

| Kaynak | Satır | Exact duplicate | Doğru seçenek dağılımı |
|---|---:|---:|---|
| Canlı audit raporu | 4.386 | 308 grup / 546 fazla satır | Raporda 15 answer leak |
| `questions_import_ready.csv` | 10.000 | 311 grup / 637 fazla satır | A 3726, B 3083, C 1635, D 1556 |
| `rich_question_bank_v2_questions.csv` | 10.000 | 311 grup / 637 fazla satır | Aynı dengesizlik |
| `2026-07-14_all_generated_questions_master.csv` | 285 | 0 | A 243, B 17, C 12, D 13 |

10.000 “unique prompt” iddiası gerçek editoryal çeşitlilik anlamına gelmiyor. Dalga-2 raporunun yalnız 49/10.000 kaydı yayın adayı kabul etmesi bu riski ayrıca doğruluyor. Önerilen kapı:

- Doğal Kurmancî dil kontrolü
- Doğru cevap–açıklama tutarlılığı
- Kaynak ve gözden geçiren kimliği
- Exact + semantik duplicate kontrolü
- Cevap konumu dağılımı
- Kategori/alt kategori yeterliliği
- Yayın/karantina durumu ve veri sürümü

Bu audit sırasında soru verisi veya Supabase değiştirilmedi.

## 18. Responsive değerlendirme

- **320×568:** İçerik kullanılabilir, ancak alt eylemler ilk viewport dışında/kırpılmış; küçük cihaz smoke testi zorunlu olmalı.
- **390×844:** Ana hedef için dengeli ve genel olarak güçlü.
- **768×1024:** Kart yapısı iyi ölçekleniyor.
- **844×390:** Sonuç kullanılabilir, fakat ana skor/kimlik ilk görünümde kayboluyor.
- **1440×900:** Max-width sayesinde aşırı yayılma yok; dikey boşluk optimizasyonu mümkün.

Responsive iyileştirme geniş refactor gerektirmiyor: kritik CTA görünürlüğü, landscape hero sırası ve büyük ekran dikey ritmi ekran bazında düzeltilebilir.

## 19. Erişilebilirlik değerlendirmesi

Olumlu: doğru/yanlış cevaplarda yalnız renk kullanılmıyor; ikon ve semantik etiket de var. Temel metinler mobilde okunabilir boyutta.

Riskler:

- Açık tema ana sayfa ve sonuç hero kontrastı ciddi ölçüde yetersiz.
- Profil içeriği screen-reader ağacında büyük tek grup olarak görünüyor.
- Ayarlar/liderlik gibi ikon kontrolleri etiketsiz.
- Timeout durumunun görünür ve semantik adı yok.
- Hareket azaltma ayarı mevcut; ancak bütün animasyonların buna uyduğu uçtan uca doğrulanmadı.
- Gerçek TalkBack/VoiceOver, dinamik font ölçeği ve klavye odağı test edilmedi.

## 20. Performans değerlendirmesi

Standart web build yaklaşık 49.7 MB; `main.dart.js` yaklaşık 4.96 MB. Toplamın önemli kısmı CanvasKit/WASM varlıklarından geliyor. 81 soru görseli toplam yaklaşık 3.79 MB, en büyüğü yaklaşık 129 KB ve WebP kullanımı olumlu.

Build başarılı, ilk ekran yerel/canlıda açıldı ve kritik runtime çökmesi görülmedi. Bununla birlikte bu audit Lighthouse/Core Web Vitals veya düşük cihaz profillemesi içermedi. İlk iyileştirme alanı görseller değil; renderer/build varyantı, lazy loading ve ilk rota bundle davranışının ölçülmesidir.

## 21. Web / PWA değerlendirmesi

Olumlu:

- Manifest adı, kısa adı, theme/background renkleri ve maskable icon'lar mevcut.
- `.htaccess` WASM/MJS MIME türlerini, SPA fallback'i ve index no-cache davranışını kapsıyor.
- Bilinmeyen deep link canlıda app shell'e döndü.
- Canlı yenileme çalıştı.

Risk:

`flutter_service_worker.js` activate sırasında kendisini unregister ediyor. Bu, eski cache problemlerini azaltabilir; fakat offline app shell'i bilinçli olarak ortadan kaldırıyor. Canlı sayfa online açıldıktan sonra ağ kesilip reload edildiğinde Chrome `ERR_INTERNET_DISCONNECTED` gösterdi. Ürün kararı açıkça belgelenmeli: ya “online-only” kabuk ve mesaj, ya da sürümlenmiş güvenli cache stratejisi.

## 22. Android / iOS yayın hazırlığı

### Android

- Namespace/application ID: `com.zankurd.app`.
- İzinler: `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`.
- En büyük risk release signing'in keystore yokluğunda debug signing'e düşmesi.
- Bildirim izin/scheduling davranışı gerçek cihaz ve güncel target SDK üzerinde ayrıca doğrulanmalı.

### iOS

- iPhone/iPad için portrait ve landscape orientation girdileri mevcut.
- `PrivacyInfo.xcprivacy` bulunmadı.
- `NS...UsageDescription` girdileri statik taramada görünmedi. Kamera/fotoğraf API'leri gerçekten kullanılıyorsa App Store öncesi zorunlu açıklamalar doğrulanmalı.
- Gerçek archive, code signing ve App Store validation bu audit kapsamına alınmadı.

## 23. Logic-sensitive alanlar

Onay olmadan değiştirilmemesi gereken alanlar:

- Günlük yarışmanın contest bulunamadığında generic quiz'e düşmesi
- Solo/oda kimliği, room code üretimi ve sonuç submit/reward akışı
- Quiz timer, tutorial kapısı ve timeout state transition'ları
- 1v1 matchmaking RPC/queue fallback davranışı
- Coin, XP, streak, badge ve yarışma ödülleri
- Soru yayın/karantina modeli ve Supabase şeması
- Web service-worker/cache stratejisi
- Android release signing

Bu alanlarda UI metnini tek başına değiştirmek, alttaki ürün sözleşmesini gizleyebilir. Her değişiklik odaklı test ve rollback sınırıyla yapılmalıdır.

## 24. Önerilen küçük uygulama fazları

### Faz 0 — Yayın kapıları

Analyzer kapsamı, Android signing fail-fast, sürüm fallback'i ve soru bankası yayın kapısı. Uygulama davranışını genişletmeden önce güvenilir baseline oluşturur.

### Faz 1 — Kontrast ve semantik erişilebilirlik

Açık ana sayfa + sonuç hero kontrastı; etiketsiz ikonlar; timeout mesajı. Golden/widget testleriyle küçük ve geri alınabilir.

### Faz 2 — Mod kimliği ve yarışma boş durumu

Solo/oda başlığı; günlük yarışma `null` durumu; 1v1 offline mesaj/retry. Önce ürün sözleşmesi, sonra ekran ve test.

### Faz 3 — Sonuç hiyerarşisi

En fazla iki ana CTA, ikincil aksiyon grubu, landscape hero sırası.

### Faz 4 — PWA ve platform release sertleştirme

Online-only/offline cache kararı, iOS privacy manifest, gerçek Android/iOS release doğrulaması.

### Faz 5 — Tasarım sistemi borcu

Yalnız dokunulan ekranlarda semantik renk alias'ları ve kademeli token konsolidasyonu; büyük refactor yok.

## 25. Dosya kapsamı, risk ve rollback

### Bu audit sırasında oluşturulanlar

- `docs/ZANKURD_FULL_PRODUCT_AUDIT_2026-07-15.md`
- `docs/screenshots/full_product_audit/2026-07-15/*.png`

### Değiştirilmemesi gerekenler

- Ana checkout'taki `macos/Flutter/GeneratedPluginRegistrant.swift`
- Soru CSV/SQL/veritabanı kayıtları
- Quiz, matchmaking, reward ve contest mantığı (ayrı onay olmadan)
- Signing, PWA cache ve platform yapılandırmaları (ayrı faz/onay olmadan)
- Generated plugin dosyaları (yalnız anlamsal olarak boş LF/CRLF artefaktı için hedefli restore istisnası)

### Risk / rollback ilkesi

Her faz tek amaçlı, küçük ve test edilebilir olmalı. Önce mevcut davranışı yakalayan test, sonra değişiklik, ardından `dart analyze`, ilgili testler ve gerekiyorsa gerçek ekran doğrulaması yapılmalı. Veri değişiklikleri sürümlü import/karantina tablosuyla; UI değişiklikleri dosya bazlı commit ile; release yapılandırmaları ise doğrulanmış artifact hash ve signing çıktısıyla geri alınabilir tutulmalıdır.

---

## Son karar

Ürün görsel ve akışsal olarak güçlü bir temele sahip; fakat **mevcut commit yayın adayı değildir**. İlk güvenli uygulama paketi Faz 0 olmalıdır. En büyük kullanıcı güveni riski soru içeriğinin dili/kalitesi, en büyük teknik release riski ise başarısız analyzer ve Android'in sessiz debug-signing fallback'idir. Audit hiçbir uygulama kaynağını değiştirmemiştir.
