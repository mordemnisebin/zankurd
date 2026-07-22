# ZanKurd UX Faz 1A — Nihai Uygulama Raporu

**Tarih:** 22 Temmuz 2026
**Durum:** Tamamlandı; kaynak değişiklikleri dört ayrı commit ile kaydedildi. Bağımsız inceleme bulguları kapatıldı.

## 1. Yönetici özeti

Faz 1A, doğrulanmış görsel UX bulgularından dört düşük riskli iyileştirmeyi uyguladı: açık tema birincil CTA kontrastı, quiz şıklarının cevap öncesi nötrleştirilmesi, navigasyon coach-mark turunun kısaltılması ve Quiz/Oda route'larının responsive genişlik-kaydırma düzeni. Ardından bağımsız salt-okunur inceleme sonucu zorunlu bulunan üç madde dördüncü bir commit ile kapatıldı: quiz tutorial'ın ikinci hedefinin kaydırılabilir alanda görünür kılınması, no-op responsive testlerin gerçek geometri testlerine çevrilmesi ve navigasyon turu Türkçe başlığının gerçek sekme etiketiyle hizalanması. Kod ve test değişiklikleri sınırlı tutuldu; backend, veri, auth ve oyun kuralları değiştirilmedi.

## 2. Faz 1A'nın amacı

Amaç, `ZANKURD_FINAL_VISUAL_UX_SPEC.md` içinde doğrulanan yüksek öncelikli sürtünmeleri çözmekti: açık temada düşük kontrastlı ana CTA, quiz renk anlamı çelişkisi, gereksiz coach-mark adımı ve pushed route'larda genişlik/taşma riski.

## 3. Başlangıç durumu

Başlangıç commit'i `9f963c097a53f870185d508860a78707c127ef52` (`9f963c0 chore: remove obsolete artifacts and handoffs`) idi. Başlangıç baseline'ında 642 test geçti, 0 test başarısız oldu ve 1 test atlandı.

## 4. Kullanılan branch ve worktree

- Branch: `codex/zankurd-ux-phase1a-2026-07-22`
- Worktree: `C:\Users\AMARGİ\.codex\worktrees\3050\pirs kurmanci`
- Flutter uygulaması: `C:\Users\AMARGİ\.codex\worktrees\3050\pirs kurmanci\zankurd_mobile`

## 5. Başlangıç commit'i

`9f963c097a53f870185d508860a78707c127ef52` Faz 1A karşılaştırma tabanıdır.

## 6. Uygulanan commit'ler

Faz 1A dört uygulama commit'i içerir:

1. `3d53ed4 fix(ui): improve light theme primary CTA contrast`
2. `9c88939 fix(ux): simplify quiz choices and navigation tour`
3. `7b5c118 fix(ui): improve quiz and room responsiveness`
4. `786bd75 fix(ux): harden quiz tutorial and responsive tests`

Dördüncü commit, bağımsız incelemede zorunlu bulunan Y1/Y2/O1 maddelerini kapatan düzeltme paketidir. `3bbbd4f` yalnızca bu raporun ilk sürümünü ekleyen doküman commit'idir ve son uygulama commit'i değildir.

## 7. Değiştirilen dosyaların tam listesi

Kaynak:

- `zankurd_mobile/lib/src/theme/app_theme.dart`
- `zankurd_mobile/lib/src/screens/home_screen.dart`
- `zankurd_mobile/lib/src/screens/quiz/quiz_widgets.dart`
- `zankurd_mobile/lib/src/screens/app_shell.dart` — *son commit'te yeniden güncellendi*
- `zankurd_mobile/lib/src/screens/quiz/quiz_screen_ui.dart`
- `zankurd_mobile/lib/src/screens/room_screen.dart`
- `zankurd_mobile/lib/src/widgets/coach_mark.dart` — *yalnız son commit*
- `zankurd_mobile/lib/src/widgets/quiz_tutorial_overlay.dart` — *yalnız son commit*

Test:

- `zankurd_mobile/test/kulturel_modern_home_test.dart`
- `zankurd_mobile/test/quiz_accent_test.dart`
- `zankurd_mobile/test/app_shell_nav_tour_test.dart` — *son commit'te yeniden güncellendi*
- `zankurd_mobile/test/quiz_flow_test.dart` — *son commit'te yeniden güncellendi*
- `zankurd_mobile/test/room_lobby_test.dart`

## 8. Her dosyada yapılan değişiklik

Tema ve Home dosyaları semantik CTA rengi ile DailyLessonHero bağını ekledi. Quiz widget dosyası boş şıkları nötr yüzeye aldı ve feedback renklerini korudu. App shell dosyası navigasyon turunu iki adıma indirdi; son commit'te ayrıca Türkçe tur başlığını düzeltti ve `_homeNavKey` hedefini gerçekten render edilen ikona taşıdı. Quiz UI ve Oda ekranı sırasıyla 800 px ve 680 px sınırları ile scroll/merkezleme düzenini ekledi. `coach_mark.dart` ve `quiz_tutorial_overlay.dart` yalnız son commit'te, tutorial hedefinin ölçümden önce görünür kılınması için değişti. Beş test dosyası bu davranışları kapsayacak biçimde güncellendi veya eklendi; bunlardan `quiz_flow_test.dart` ve `app_shell_nav_tour_test.dart` son commit'te gerçek davranış/geometri testlerine dönüştürüldü.

## 9. Açık tema CTA düzeltmesi

`AppTheme.primaryCtaColor(BuildContext)` semantik erişimi eklendi. Açık temada CTA rengi `#C05000`, koyu temada mevcut başarılı marka turuncusu/CTA davranışıdır. Global `FilledButtonTheme` değiştirilmedi.

## 10. Quiz cevap öncesi nötr renk sistemi

Boş cevap şıkları artık seçenek harfine göre kırmızı/mavi gibi güçlü zeminler kullanmıyor; tema yüzeyi, sınır ve birincil metin rengini kullanıyor. Böylece cevap verilmeden önce kırmızı=yanlış/yeşil=doğru anlamı tetiklenmiyor.

## 11. Quiz doğru/yanlış feedback koruması

Doğru cevap yeşil gradyan, yanlış cevap kırmızı gradyan ile gösterilmeye devam ediyor. Cevap kontrolü ve mevcut reveal mantığı korunmuştur.

## 12. Navigasyon coach-mark sadeleştirmesi

Navigasyon turu üç adımdan iki adıma indirildi ve Profil coach-mark adımı kaldırıldı. Nihai başlıklar:

- 1. adım: `Sereke` / `Ana Sayfa`
- 2. adım: `Pêşbazî` / `Yarış`

Türkçe başlık artık gerçek sekme etiketiyle **aynıdır**: hem `NavigationRail` hem `NavigationBar` bu sekmeyi `ku ? 'Pêşbazî' : 'Yarış'` olarak etiketler. Ara sürümdeki `Oyna` başlığı, sekmede böyle bir etiket bulunmadığı için son commit'te `Yarış` olarak düzeltildi. Kurmancî başlık `Pêşbazî` korunmuştur.

Ayrıca `_homeNavKey`, açılışta gerçekten render edilen **selected icon** hedefiyle eşleştirildi. Önceki bağlamada anahtar, home sekmesi seçiliyken render edilmeyen `icon` dalına bağlıydı; bu durumda `currentContext` null döndüğü için turun ilk adımı sessizce atlanabiliyordu.

## 13. Coach-mark persistence doğrulaması

Mevcut `zankurd.navTour.seen` anahtarı değiştirilmedi; migration gerekmez. Test artık turun tamamını gerçek widget akışıyla doğrular:

`Ana Sayfa 1/2` → `İleri` → `Yarış 2/2` (ve `Profil` adımının bulunmadığı) → `Anladım` → `zankurd.navTour.seen == true` → ağaç boşaltılıp yeniden kurulduğunda `CoachMarkOverlay` yeniden görünmez.

Kaynak dosya metnini `File(...).readAsStringSync()` ile grep eden kırılgan test kaldırıldı; yerini bu davranışsal test aldı.

## 14. Quiz responsive düzeni

Quiz portrait ve geniş/landscape yerleşimleri `SafeArea` altındaki doğal boyutlu içerik olarak düzenlendi. Dar veya kısa ekranlarda içerik küçültülmek yerine dikey kaydırılır; geniş görünümde içerik ortalanır.

## 15. Kaldırılan ana FittedBox kullanımları

`quiz_screen_ui.dart` içindeki portrait ana içerik ve landscape ana layout'u saran iki `FittedBox.scaleDown` kaldırıldı. Küçük, izole görsel öğeler için gerekli olmayan bir değişiklik yapılmadı.

## 16. Quiz scroll ve genişlik sistemi

Portrait `SingleChildScrollView` ile güvenli dikey scroll kullanır. Landscape iki sütun düzenini korur. Ana Quiz içerik genişliği en fazla 800 px'tir; soru metni doğal satır kırılımı ve cevap hedefleri gerçek boyutta kalır.

## 17. Oda responsive düzeni

Mevcut `SafeArea` ve `ListView` korunarak ana oda sütunu `Center > ConstrainedBox(maxWidth: 680)` içine alındı. Mobilde güvenli yatay padding içindeki kullanılabilir genişlik doldurulur; geniş ekranda içerik ortalanır.

## 18. Quiz tutorial ikinci hedef düzeltmesi (Y1)

FittedBox kaldırılıp portrait düzen kaydırılabilir hale gelince, quiz tutorial'ın ikinci adımının hedefi olan `Piştre` / `Sonraki` butonu kısa ekranlarda viewport fold'unun altında kalabiliyordu. `CoachMarkOverlay` hedefi yalnız `localToGlobal` ile ölçtüğü ve scroll offset'ini hesaba katmadığı için, ekran dışı bir dikdörtgen ölçülüyor, spotlight deliği ve balon viewport dışına düşüyordu; kullanıcı boş karartılmış bir ekran görüyordu.

Düzeltmenin doğrulanmış ayrıntıları:

- 360×640 testinde ikinci tutorial hedefinin başlangıçta viewport fold'unun **altında** olduğu gerçek testle doğrulandı. Test, scroll öncesi `beforeScroll.bottom > 640` iddiasını taşır ve geçer; Codex ölçümünde bu değer **643,4 px**'tir.
- Quiz, ikinci adıma geçmeden önce `Piştre` hedefini `Scrollable.ensureVisible` ile görünür alana kaydırır.
- Coach-mark ölçümü, scroll animasyonu **ve** sonraki frame tamamlandıktan sonra yapılır (`await Scrollable.ensureVisible(...)` → `await WidgetsBinding.instance.endOfFrame` → `setState` → post-frame ölçüm).
- Ortak `CoachMarkOverlay` içine, nullable ve yalnız gerektiğinde çalışan asenkron bir `onBeforeStep(int nextIndex)` kancası eklendi. `await` sonrası `if (!mounted) return;` guard'ı `setState` öncesinde uygulanır.
- Bu kanca yalnız Quiz tutorial tarafından kullanılır.
- Navigasyon turunun mevcut kullanımı etkilenmedi; nav turu bu parametreyi geçmez ve davranışı değişmez.
- `_homeNavKey`, açılışta gerçekten render edilen selected icon hedefiyle eşleştirildi (bkz. bölüm 12).

## 19. Korunan quiz state ve multiplayer sistemleri

`AnimatedSwitcher`, soru geçiş animasyonu, timer, jokerler, cevap/reveal akışı, solo/öğrenme/oda/1v1 kullanım biçimleri ve multiplayer state yönetimi değiştirilmedi.

## 20. Korunan oda realtime, host ve ready sistemleri

Realtime abonelikler, oyuncu senkronizasyonu, host başlatma yetkisi, ready state, oda kodu üretimi, sohbet katmanı ve zamanlama/messaging mantığı değiştirilmedi.

## 21. Eklenen veya güncellenen testler

- Açık/koyu CTA rengi: `kulturel_modern_home_test.dart`
- Nötr quiz şıkları ve doğru/yanlış feedback: `quiz_accent_test.dart`
- İki adımlı tur, 1/2 → 2/2 akışı ve kalıcılık: `app_shell_nav_tour_test.dart`
- Quiz dar/kısa/geniş responsive davranışları ve tutorial ikinci hedefi: `quiz_flow_test.dart`
- Oda geniş sütun ve mevcut lobby davranışları: `room_lobby_test.dart`

## 22. Responsive test sertleştirmesi (Y2)

İlk sürümdeki responsive kontroller `tester.scrollUntilVisible` kullanıyordu. Bu API döngü koşulunu `finder.evaluate().isEmpty` üzerinden kurar; `SingleChildScrollView` lazy olmadığı için hedef widget ilk frame'den itibaren ağaçta bulunur ve çağrı **hiç scroll etmeden** döner. Sonrasındaki `findsOneWidget` iddiası totolojiye dönüşür. Bu nedenle testler, layout tamamen bozulsa bile yeşil kalabiliyordu.

Son commit'te yapılanlar:

- Eski no-op `scrollUntilVisible` kontrolleri kaldırıldı.
- Kaydırılacak alan `quiz-portrait-scroll` anahtarına inen belirli bir finder ile seçiliyor; genel `find.byType(Scrollable).first` belirsizliği giderildi.
- Gerçek drag yapılıyor: `tester.drag(scrollable, const Offset(0, -500))` + `pumpAndSettle()`.
- CTA'nın scroll **öncesi** fold altında olduğu doğrulanıyor: `beforeScroll.bottom > 640`.
- Scroll **sonrası** CTA'nın üst ve alt koordinatlarının 360×640 viewport içinde olduğu doğrulanıyor: `afterScroll.top < beforeScroll.top`, `afterScroll.top >= 0`, `afterScroll.bottom <= 640`.
- Landscape testi de gerçek geometri iddiası kullanıyor: 844×390'da `nextRect.top >= 0` ve `nextRect.bottom <= 390`.
- Ayrıca yeni bir regresyon testi eklendi: tutorial ikinci adımında hem hedefin hem tooltip'in 360×640 viewport içinde kaldığı koordinatla doğrulanır.

## 23. Baseline test sonucu

642 geçti, 0 başarısız, 1 atlandı.

## 24. Paket 1 test sonucu

Odaklı testlerde 15 test geçti. Tam pakette 643 test geçti, 0 başarısız oldu ve 1 test atlandı.

## 25. Paket 2 test sonucu

Tam pakette 647 test geçti, 0 başarısız oldu ve 1 test atlandı.

## 26. Paket 3 test sonucu

Hedef testlerde 11 test geçti. Tam pakette 649 test geçti, 0 başarısız oldu ve 1 test atlandı.

## 27. Paket 4 (düzeltme paketi) test sonucu

Son düzeltme paketinin doğrulanmış sonuçları:

- 360×640 tutorial hedef testi geçti (`quiz tutorial keeps its second target and tooltip on screen`).
- Hedef testler: `flutter test --no-pub test/quiz_flow_test.dart test/app_shell_nav_tour_test.dart` → **8 geçti, 0 başarısız**. Bu iki dosya `quiz_flow_test.dart` içindeki 7 test ile `app_shell_nav_tour_test.dart` içindeki 1 testten oluşur; Faz 1A boyunca dokunulan tüm test dosyaları birlikte sayıldığında bu sayı daha yüksektir ve tam paket sonucu tarafından kapsanır.
- Tam paket: **649 geçti, 0 başarısız, 1 atlandı**.
- `dart analyze`: `No issues found!`
- Web release build başarılı.
- `git diff --check` temiz.

## 28. Nihai tam test sonucu

Son Faz 1A tam test koşusu: **649 geçti, 0 başarısız, 1 atlandı**.

## 29. Web release build sonucu

`C:\src\flutter\bin\flutter.bat build web --release --no-pub` başarıyla tamamlandı (`√ Built build\web`, çıkış kodu 0). Son koşuda web derlemesi yaklaşık 89,9 saniye sürdü.

## 30. Gerçek viewport doğrulaması

Yerel Windows Flutter web sunucusu ve tarayıcı CDP viewport emülasyonu kullanıldı. Aşağıdaki gerçek `window.innerWidth` ve `window.innerHeight` değerleri doğrulandı; ekran görüntüleri gözle incelendi ve yatay genişlik viewport ile eşitti.

- Quiz: 360×640, 390×844, 768×1024, 1440×900
- Oda: 390×844, 1440×900

`window.innerWidth = 360`, `window.innerHeight = 640` hedef viewport'unda quiz tutorial'ın ikinci adımı gözle doğrulandı: tooltip ve spotlight görünürdür, boş karartılmış coach-mark ekranı oluşmaz. Quiz'de içerik kesilmeden erişilebilir kaldı; Oda'da kod, oyuncu listesi, hazır alanı ve sohbet düğmesi görünür kaldı.

## 31. Analyzer sonucu

Analyzer kapısı **temizdir**.

- `flutter analyze --no-pub`, bu ortamda bilinen Dart language-server/LSP JSON problemi nedeniyle güvenilir sonuç üretmedi: analiz sunucusu çıkış kodu 255 ile düştü (`LspByteStreamServerChannel`, `FormatException: Unexpected end of input`). Bu bir Flutter wrapper/ortam sorunudur.
- Doğrudan `C:\src\flutter\bin\dart.bat analyze` başarıyla tamamlandı.
- Sonuç: `No issues found!` — **0 hata, 0 uyarı, 0 info** (çıkış kodu 0).
- Analyzer kaynak kalite kapısı doğrudan Dart analyzer ile temizlenmiştir.
- Flutter wrapper ortam sorunu proje kaynak hatası olarak yazılmamalıdır; kaynak kodda analyzer bulgusu yoktur.

## 32. Bağımsız inceleme

Faz 1A, uygulamadan bağımsız bir kıdemli Flutter reviewer (Claude Opus) tarafından salt-okunur olarak iki turda incelendi.

- İlk inceleme kararı: **C. Önemli düzeltmeler gerekiyor**
- Zorunlu bulunan maddeler:
  - **Y1** — 360×640'ta quiz tutorial ikinci hedefi fold altında; boş karartılmış ekran riski.
  - **Y2** — Responsive testler no-op `scrollUntilVisible` nedeniyle yanlış pozitif üretiyordu.
  - **O1** — Coach-mark Türkçe başlığı `Oyna`, gerçek sekme etiketi `Yarış` ile uyuşmuyordu.
- Y1, Y2 ve O1 `786bd75` commit'i ile düzeltildi.
- Son salt-okunur inceleme kararı: **A. MERGE İÇİN HAZIR**

## 33. Değiştirilmeyen kritik sistemler

Supabase, backend, auth, soru bankası, multiplayer altyapısı, ekonomi, provider'lar, pub bağımlılıkları ve lockfile değişmedi. `pubspec.yaml` ile `pubspec.lock` başlangıç commit'ine göre değişmemiştir.

## 34. Kapsam dışında bırakılan işler

Bu fazda uygulanmadı:

- Kartların AppPanel sistemine toplu göçü
- Card radius teknik borcu
- Alt navigasyonu dört sekmeye indirme
- Kategoriler ve Öğren merkezini birleştirme
- Liderlik sekmesini taşıma
- Ana sayfa kartlarını kaldırma
- Seviye kilitleri
- Çark otomatik açılışı
- Bildirim merkezi
- Lig sistemi değişiklikleri
- Mağaza veya arkadaş sistemi değişiklikleri
- LearningScreen ve PlayHubScreen responsive değişiklikleri

## 35. Bilinen düşük öncelikli backlog notları

Bağımsız incelemede tespit edilen, merge engeli **olmayan** iki iyileştirme:

- Çok hızlı çift dokunmada asenkron `_next()` çağrılarının çakışmasını önlemek için ileride bir `_advancing` guard'ı değerlendirilebilir. Mevcut etkisi yalnız adım sayacı metnidir; tur akışı ve persistence bozulmaz.
- Quiz tutorial içindeki `nextIndex == 1` kontrolü ileride hedef key tabanlı hâle getirilebilir; böylece adım sayısı değişirse kanca sessizce yanlış adıma bağlanmaz.

Bu iki maddenin mevcut iki adımlı akışta merge engeli olmadığı bağımsız incelemede doğrulanmıştır.

## 36. Bilinen riskler ve yapılmayan kontroller

Statik analiz kapısı doğrudan Dart analyzer ile temizlendiği için açık kalite kapısı kalmamıştır.

Yapılmayan kontrol: **fiziksel Android/iOS cihaz smoke kontrolü bu fazda yapılmamıştır.** Responsive ve tutorial doğrulamaları gerçek web viewport'larında (360×640 dahil) ve widget testleriyle yapılmıştır. Farklı cihaz yazı ölçekleri ve klavye açık durumu tam cihaz matrisi olarak tekrar edilmemiştir. Bu, merge engeli değildir; release öncesi öneri olarak açık bırakılmıştır.

## 37. Manuel kontrol önerileri

Release öncesinde fiziksel Android/iOS cihazda açık/koyu tema CTA kontrastı, kısa ekranlarda Quiz scroll'u ve tutorial ikinci adımı, landscape Quiz, Oda kodu kopyalama, host/guest ready akışı ve sohbet overlay'i kontrol edilmelidir. Bu kontroller merge engeli değil, release öncesi öneridir.

## 38. Geri dönüş için commit bilgileri

Değişiklikler ayrık commit'lerdedir. Geri dönüş ihtiyacında sırayla `786bd75`, `7b5c118`, `9c88939` veya `3d53ed4` geri alınabilir; böylece tutorial/test sertleştirmesi, responsive, quiz/coach-mark ve CTA paketleri bağımsız ele alınabilir. `786bd75` geri alınırsa Y1/Y2/O1 düzeltmelerinin de geri alınacağı unutulmamalıdır.

## 39. Birleştirme öncesi kabul kriterleri

- Branch ve worktree temiz olmalı. ✅
- Nihai test sonucu 649 geçti / 0 başarısız / 1 atlandı olarak korunmalı. ✅
- Web release build başarılı olmalı. ✅
- `git diff --check` temiz olmalı. ✅
- Analyzer temiz sonuç vermeli (`dart analyze` → `No issues found!`). ✅
- Bağımsız inceleme kararı `A. MERGE İÇİN HAZIR` olmalı. ✅
- Fiziksel cihaz smoke kontrolü release öncesi öneri olarak açık kalır (merge engeli değildir).

## 40. Nihai sonuç

Faz 1A tamamlandı. Dört uygulama commit'i açık tema CTA kontrastını, quiz cevap renk anlamını, navigasyon turu sürtünmesini, Quiz/Oda responsive düzenini ve quiz tutorial'ın kısa ekranlardaki ikinci adımını iyileştirir. Bağımsız incelemede zorunlu bulunan Y1, Y2 ve O1 maddeleri kapatılmıştır.

Test, doğrudan analyzer, web release build ve hedef viewport doğrulamaları başarılıdır. Açık teknik engel kalmamıştır; çalışma yerel `main` branch'ine fast-forward merge için hazırdır.
