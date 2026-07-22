# ZanKurd Full Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Denetimde doğrulanan P0-P3 sorunlarını, mevcut kullanıcı değişikliklerini koruyarak küçük ve test edilebilir paketlerle gidermek.

**Architecture:** Mevcut Provider + repository + imperative navigation yapısı korunacak. Düzeltmeler ortak kök noktalarda yapılacak; yeni framework, veri tabanı katmanı veya geniş refactor eklenmeyecek. Supabase güvenlik değişiklikleri istemci kodu ve tek bir idempotent migration olarak birlikte hazırlanacak, canlıya uygulanmayacak.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, Provider, Supabase/PostgreSQL, Firebase, package:test.

## Global Constraints

- Canlı Supabase, deploy, publish, commit, push ve PR işlemi yok.
- Mevcut kirli çalışma ağacı ve kullanıcı değişiklikleri korunacak.
- Yeni bağımlılık eklenmeyecek; mevcut paket API'leri kullanılacak.
- Her davranış değişikliği önce başarısız testle kanıtlanacak.
- Her paket sonunda `dart analyze`, ilgili test ve gereken build kapısı çalıştırılacak.
- Kurmancî değişiklikler yalnız kesin tutarsızlıklarda yapılacak; tartışmalı metinler uzman doğrulama listesine alınacak.

---

### Task 1: Derlenebilir tabanı geri getir

**Files:**
- Modify: `lib/src/theme/app_theme.dart`
- Modify: `lib/src/screens/spin_wheel_screen.dart`
- Modify: `lib/src/widgets/tournament_bracket_widget.dart`
- Modify: `lib/src/services/notification_service.dart`
- Modify: `analysis_options.yaml`
- Test: mevcut tema, çark, turnuva ve bildirim testleri

**Interfaces:** Mevcut public API'ler değişmeyecek; yalnız sözdizimi, yinelenen yardımcı, analyzer kapsamı ve kurulu bildirim paketi çağrıları düzeltilecek.

- [ ] Mevcut analyzer/test/build hatalarını RED kanıtı olarak kaydet.
- [ ] Eksik olmayan dosyaya yapılan tema importunu ve yinelenen `_isDark` tanımını kaldır.
- [ ] `Semantics` sarmalayıcılarındaki eksik kapanışları ve const olmayan renk çağrısını düzelt.
- [ ] `flutter_local_notifications 22.1.0` için yerel paket API'sine göre çağrıları güncelle.
- [ ] Bağımsız `widgetbook/**` paketini kök analyzer kapsamından yeniden çıkar; linter kurallarını geri yükle.
- [ ] `dart analyze` ve hedefli testleri çalıştır.

### Task 2: iOS ve platform release engellerini kapat

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Test: `test/release_config_test.dart`

**Interfaces:** Galeri avatar seçimi aynı kalacak; iOS açıklaması kullanıcıya neden fotoğraf erişimi gerektiğini söyleyecek. Windows yol override'ları gerçek üst sınırlarla sabitlenecek.

- [ ] `Info.plist` fotoğraf izni eksikliğini doğrulayan test yaz ve RED çalıştır.
- [ ] `NSPhotoLibraryUsageDescription` ekle.
- [ ] Yanıltıcı caret override'larını gerçek `<` üst sınırlarıyla düzelt ve `pub get --offline --enforce-lockfile` çalıştır.
- [ ] Android/iOS/Web yapılandırma testini ve analyzer'ı çalıştır.

### Task 3: Çok oyunculu puan ve oda bütünlüğünü sunucuya taşı

**Files:**
- Create: `supabase/2026-07-22_online_integrity_hardening.sql`
- Modify: `lib/src/data/supabase_zankurd_repository.dart`
- Modify: `lib/src/screens/quiz_screen.dart`
- Test: `test/supabase_repository_test.dart`
- Test: `test/quiz_multiplayer_sync_test.dart`
- Test: `test/supabase_sql_contract_test.dart`

**Interfaces:** `submit_answer` yalnız odanın geçerli sorusunu bir kez kabul edecek; host soru indeksini doğrudan UPDATE yerine RPC ile ilerletecek; istemci senkronizasyonu oyuncu kimliğini esas alacak.

- [ ] Keyfi soru kimliği, geniş host UPDATE ve aynı adlı oyuncu senkronizasyonunu gösteren testleri RED çalıştır.
- [ ] Migration'da geçerli oda sorusu doğrulaması, atomik ilerletme RPC'si ve dar oda UPDATE politikası oluştur.
- [ ] Repository'ye mevcut RPC kalıbıyla `advanceRoomQuestion` ekle.
- [ ] Quiz ekranındaki doğrudan tablo UPDATE'ini kaldır ve kimlik tabanlı answered state kullan.
- [ ] Repository, SQL sözleşmesi ve multiplayer testlerini çalıştır.

### Task 4: Doğru cevap sızıntısını kapat

**Files:**
- Extend: `supabase/2026-07-22_online_integrity_hardening.sql`
- Modify: `lib/src/data/supabase_zankurd_repository.dart`
- Modify: `lib/src/models/quiz_question.dart` yalnız gerekirse
- Modify: `lib/src/screens/quiz_screen.dart` yalnız gerekirse
- Test: `test/supabase_repository_test.dart`
- Test: `test/supabase_sql_contract_test.dart`

**Interfaces:** Solo mod offline bankayı kullanacak; online oda soru yükü `correct_option` içermeyecek; doğru seçenek yalnız cevap RPC sonucundan gelecek.

- [ ] Online soru yükünde `correct_option` bulunmamasını bekleyen RED test yaz.
- [ ] Migration'a katılımcı kontrollü, doğru cevabı gizleyen soru RPC/view sözleşmesi ekle.
- [ ] Repository'nin oda sorusu sorgusunu gizli-cevap sözleşmesine geçir.
- [ ] Reveal durumunda RPC sonucunu kullanan en küçük istemci değişikliğini yap.
- [ ] Solo ve multiplayer quiz testlerini çalıştır.

### Task 5: Erişilebilirlik ve başlangıç yükünü düzelt

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/src/screens/app_shell.dart`
- Modify: `lib/src/screens/leaderboard_screen.dart`
- Modify: `lib/src/screens/profile_screen.dart`
- Test: `test/accessibility_guideline_test.dart`
- Test: `test/app_shell_test.dart`

**Interfaces:** Sistem metin ölçeği en az 2.0'a kadar korunacak. Gizli sekmeler ilk seçilene kadar uzak veri yüklemeyecek ve periyodik yenileme başlatmayacak.

- [ ] 2.0 metin ölçeği ve gizli sekme ağ çağrıları için RED testleri yaz.
- [ ] Global `maxScaleFactor: 1.35` sınırını kaldır veya 2.0'a yükselt.
- [ ] IndexedStack sekmelerini mevcut widget yapısını bozmadan ilk erişimde oluştur.
- [ ] Liderlik zamanlayıcısını yalnız görünürlükte başlat/durdur.
- [ ] Erişilebilirlik ve AppShell testlerini çalıştır.

### Task 6: Soru bankasını güvenli ve ölçülebilir biçimde temizle

**Files:**
- Modify: `assets/data/offline_questions.json`
- Modify: `lib/src/data/offline_question_bank.dart`
- Modify: `tool/question_quality/source_manifest.json`
- Modify: `tool/verify_and_fix_question_bank.py`
- Test: `test/question_bank_test.dart`
- Test: `test/offline_questions_json_equivalence_test.dart`
- Test: `test/question_quality/manifest_and_normalization_test.dart`

**Interfaces:** Runtime Dart bankası ve JSON aynası birebir kalacak. Varsayılan doğrulama komutu salt okunur olacak; değişiklik yalnız açık `--fix` ile yapılacak.

- [ ] Exact duplicate, cevap pozisyonu ve script dry-run davranışı için RED testleri ekle.
- [ ] 800 exact duplicate kaydı deterministik biçimde kaldır; kimlik ve kategori sözleşmesini koru.
- [ ] Seçenek sıralamasını doğru cevap pozisyonunu dengeleyecek deterministik dönüşümle uygula.
- [ ] Manifest sayısını gerçek runtime sayısına eşitle ve JSON'u mevcut exporter ile üret.
- [ ] Scripti varsayılan check-only, açık `--fix` mutasyonlu hâle getir.
- [ ] Kalite auditini, soru testlerini ve JSON eşdeğerlik testini çalıştır.

### Task 7: Kesin dil ve ürün tutarlılıklarını düzelt

**Files:**
- Modify: `lib/src/screens/friends_screen.dart`
- Modify: `lib/src/screens/app_shell.dart`
- Modify: `lib/src/screens/onboarding_screen.dart`
- Modify: `lib/src/screens/tournament_screen.dart`
- Test: `test/language_copy_test.dart`

**Interfaces:** Kullanıcıya görünen kesin Türkçe kaçakları mevcut uygulamadaki Kurmancî karşılıklarla değiştirilecek; tartışmalı terminoloji otomatik değiştirilmeyecek.

- [ ] `Çevrimiçi` ve Kurmancî dalındaki `Turnuva` kaçaklarını yakalayan RED test yaz.
- [ ] `Çevrimiçi` için mevcut `Serhêl`, turnuva için mevcut `Kûpa/Kûpaya ZanKurd` terminolojisini kullan.
- [ ] `Ode`, `Pêşbirk` ve `Pêşbazî` kullanımını ekran bağlamına göre tutarlılaştır.
- [ ] Dil testlerini ve ilgili widget testlerini çalıştır.

### Task 8: Gereksiz yük ve stale araçları temizle

**Files:**
- Modify: `pubspec.yaml`
- Delete or repair: `widgetbook/` yalnız kullanım kanıtına göre
- Modify: `IMPLEMENTATION_PROGRESS.md`
- Test: analyzer ve web asset manifest kontrolü

**Interfaces:** Runtime tarafından okunmayan JSON asset bundle'dan çıkarılacak fakat geliştirme/test kaynağı olarak repoda kalacak. Kullanılmayan Widgetbook üretim analizini bozmayacak.

- [ ] Runtime'da JSON okunmadığını ve Widgetbook importlarının geçersiz olduğunu yeniden doğrula.
- [ ] `offline_questions.json` asset kaydını kaldır; eşdeğerlik testini dosya tabanlı oku.
- [ ] Kullanılmıyorsa stale Widgetbook'u sil; kullanım varsa yalnız bağımsız paket olarak onar.
- [ ] Yanlış “0 analyzer warning / 14 test” durum belgesini güncel doğrulama komutlarına bağla.
- [ ] `dart analyze`, tam test ve web build çalıştır.

### Task 9: Raporları gerçek son duruma göre yenile

**Files:**
- Modify: `GEMINI_FULL_LOCAL_AUDIT.md`
- Modify: `GEMINI_FINDINGS_INDEX.md`
- Modify: `GEMINI_RELEASE_READINESS.md`

**Interfaces:** Secret değerleri hiçbir raporda bulunmayacak; her kapanan bulgu test/build kanıtına, açık kalan bulgu dosya/satır kanıtına bağlanacak.

- [ ] Eski raporlardaki secret değerlerini ve yanlış iddiaları kaldır.
- [ ] P0-P3 indeksini gerçekleşen düzeltme durumuyla güncelle.
- [ ] Android/iOS/Web release kapılarını ayrı yaz.
- [ ] Son olarak `dart analyze`, tam `flutter test`, web release ve debug APK doğrulamalarını taze çalıştır.

## Self-review

- Kapsam: derleme, test, platform, Supabase, güvenlik, performans, erişilebilirlik, içerik, dil ve raporlar kapsandı.
- YAGNI: go_router, yeni state framework'ü, SQLite/Hive, yeni paket ve büyük ekran refactor'u eklenmedi.
- Canlı sınırı: SQL yalnız yerel migration olarak hazırlanacak; uygulama/deploy yapılmayacak.
- Kullanıcı değişiklikleri: hiçbir dosya geri alınmayacak; her edit mevcut diff üzerine uygulanacak.
