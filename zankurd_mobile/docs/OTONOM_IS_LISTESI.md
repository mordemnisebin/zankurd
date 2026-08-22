# ZanKurd — otonom çalışma listesi

Bu dosya **durumdur, rapor değil.** Her bulut koşusu buradan iş alır,
yapar, sonucu buraya işler. Yeni rapor dosyası üretme.

Son taban ölçümü: **2026-08-23**, dal `fix/quiz-layout-and-release-hygiene`.

## Taban (o gün ölçüldü)

| Ölçüt | Değer |
|---|---|
| Dart dosyası / satır | 191 / 79.149 |
| Test dosyası / test | 366 / 2373 |
| `dart analyze` | temiz |
| Soru bankası | 2920 |
| Çeviri anahtarı | 909 (ku ve tr tam, Hawar temiz) |
| Varlıklar | 9,6 MB (5,1 MB görsel) |

Sağlıklı bulunan ve **yeniden denetlenmesine gerek olmayan** alanlar:
gömülü sır yok (anon key `String.fromEnvironment`), `prefer_const`
uyarısı sıfır, dispose edilmeyen controller yok, 235 `mounted` koruması,
çeviri iki dilde eksiksiz.

---

## İŞ SIRASI

Sıradaki açık maddeyi al. Bitirdiğinde satırı `[x]` yap, altına tek
cümlelik sonuç ve commit kısa kimliğini yaz.

### A1 — [ ] Supabase katmanında 60 sessiz hata yutma
`lib/src/data/supabase_zankurd_repository.dart` içinde 60 `catch` bloğu
`ErrorReporter`'a hiçbir şey bildirmiyor. Bu ağ katmanı: sessiz düşen bir
istek, kullanıcıya boş ekran olarak görünür ve hiçbir yerde iz bırakmaz.
Her birine `ErrorReporter.record(error, stack, reason: '<işlem_adı>')`
ekle. Davranışı DEĞİŞTİRME — yalnız raporlama ekle.
Bekçi: raporlamayan `catch` sayısını sabitleyen bir test yaz.

### A2 — [ ] Ölü kod: `ErrorDialog`
`lib/src/widgets/error_dialog.dart` (66 satır) hiçbir yerden
çağrılmıyor — `lib/`, `test/`, `tool/` üçünde de sıfır referans. Sil.
Silmeden önce referans yokluğunu yeniden doğrula.

### A3 — [ ] Tooltip'siz 4 `IconButton`
21 `IconButton`'ın 17'sinde `tooltip` var, 4'ünde yok. Ekran okuyucu
kullanıcısı o dördünün ne yaptığını bilemez. Bul, `strings.dart`tan
metin vererek ekle (metni ELLE yazma).

### A4 — [ ] Bağımlılık güncellemesi
Güncellenebilir: `firebase_core` 4.12.1→4.13.0, `firebase_analytics`
12.4.5→12.4.6, `firebase_crashlytics` 5.2.6→5.2.7, `supabase_flutter`
2.16.0→2.17.2, `purchases_flutter` 10.6.0→10.9.1,
`flutter_local_notifications` 22.2.0→22.3.0.
**Teker teker** yükselt, her birinden sonra tam test koş. Biri kırarsa
geri al ve maddeye niçin kırdığını yaz. `shimmer` 3→4 ana sürüm
atlaması: kırıcı değişiklik olabilir, ayrı ele al.

### A5 — [ ] İçerik: çapraz kontrolü olmayan 1810 soru
Ayrıntı `docs/KALAN_ISLER_GOREVI.md` bölüm 1. **DeepSeek API anahtarı
gerekiyor ve bulutta yok** — bu madde bulut koşusunda YAPILAMAZ.
Yerel oturum için bırakıldı.

### A6 — [ ] İçerik: makine taramasının 22 sızma bulgusu
`python3 tool/content_authoring/sik_kalite_taramasi.py` çalıştır
(saf Python, Flutter gerektirmez). 16 biçim + 6 uzunluk sızması.
Düzeltirken `docs/KALAN_ISLER_GOREVI.md` bölüm 2'deki bekçi tuzaklarını
oku — orada üç testin birbirini nasıl kırdığı yazılı.

### A7 — [ ] Park edilmiş 77 soru
`docs/content_batches/bekleyen_2026_08_19_cografya_cand_edebiyat.json`.
A5'e bağlı (çapraz kontrol gerekiyor). Bulutta yapılamaz.

### A8 — [ ] Dev dosyaların bölünmesi
`quiz_screen.dart` 3784 satır, `supabase_zankurd_repository.dart` 3023,
`quiz_result_screen.dart` 2655. Bunlar bakım riski ama çalışıyorlar.
**Yalnız Flutter test koşulabiliyorsa** dokun; koşulamıyorsa dokunma.
Küçük adım: tek bir bağımsız bölümü `part` dosyasına taşı, test koş,
commit et. Büyük refactor YAPMA.

---

## Bulut koşusunun uyacağı kurallar

1. **Flutter var mı, önce bak.** `flutter --version` çalışmıyorsa Dart
   kodunu DEĞİŞTİRME — doğrulayamadığın değişikliği göndermek bu
   depoda iki kez derleme kırdı. O durumda yalnız Python/JSON/belge
   işlerini yap (A6) ya da bir maddeyi analiz edip bulgularını bu
   dosyaya işle.
2. **Testsiz gönderme.** Flutter varsa: `dart analyze` temiz ve
   `flutter test` tam geçmeden commit etme.
3. **Her düzeltmenin bekçisi olsun.** Testin belgesine kusurun ne
   olduğunu ve niçin sessiz kaldığını yaz.
4. **Commit gövdesi niçini anlatsın**, neyi değil.
5. **Yeni rapor dosyası üretme.** Bulgu buraya, teste ve commit
   gövdesine yazılır.
6. **Bitiremediğini yarım bırak ve yarım olduğunu yaz.** Tam sanılan
   yarım iş kabul edilmez.
7. Kurmancî metinlerde yalnız Hawar alfabesi (`ı ğ ö ü İ` yok).
   Çeviri tek kaynaktan: `lib/src/l10n/strings.dart`.

## Koşu günlüğü

Her koşu buraya tek satır ekler: tarih, ne yapıldı, commit.
