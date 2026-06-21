# ZanKurd Kalite ve Yayın Hazırlık Checklist

Bu checklist mobil uygulamayı (ana ürün) yayınlamadan önce kalite ve güvenliği sabitlemek için kullanılır.

## 1) Komut Doğrulama

- [ ] `dart analyze` temiz.
- [ ] `flutter test` temiz.
- [ ] Android build öncesi (Windows) `TMP/TEMP` ASCII path ayarlı.
- [ ] Son release artefact doğrulaması `docs/release_readiness.md` ile eşleşiyor.

## 2) Kritik Akışlar (manuel/duman test)

- [ ] Quiz çözme akışı (başlat, cevapla, sonuç ekranı).
- [ ] Coin kazanımı ve bakiye güncelleme.
- [ ] Joker kullanımı (coin düşümü + yetersiz bakiye davranışı).
- [ ] Profil adı güncelleme.
- [ ] Offline/online geçişte temel ekranların çökmeden açılması.
- [ ] Profile tab refresh davranışı (AppShell tab dönüşünde güncel veri).

## 3) Soru Bankası Kalite Kontrolü

- [ ] `test/question_bank_test.dart` geçiyor.
- [ ] Boş/trim hatalı prompt-cevap-açıklama yok.
- [ ] Kategori/zorluk dağılımı alt limitleri korunuyor.
- [ ] Gerekirse `supabase/dedupe_and_fix_questions.sql` güncellendi.
- [ ] İçerik standardı: `docs/question_bank_quality_standard.md`.

## 4) Güvenlik Kontrolleri

- [ ] İstemciye yalnızca `publishable/anon` Supabase anahtarı verildi.
- [ ] `service_role` / `sb_secret_*` anahtarları istemcide yok.
- [ ] Hesap silme akışı erişilebilir.
- [ ] Privacy Policy URL Play Console ve uygulama metniyle tutarlı.

## 5) Play Console Öncesi

- [ ] `docs/play_console_submission_checklist.md` tamamlandı.
- [ ] Internal testing kurulumu ile en az bir gerçek cihaz doğrulandı.
- [ ] Pre-launch report kritik hata içermiyor.
