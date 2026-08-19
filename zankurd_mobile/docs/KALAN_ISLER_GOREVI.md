# ZanKurd — kalan işler görevi

Bu depoda çalışacaksın. **Önce bu dosyayı, sonra `docs/TASARIM_DEVAM_NOTU.md`
ve kökteki `AGENTS.md`'i oku.** Sayılar 2026-08-19 itibarıyla ölçüldü ve
doğrudur; varsayım yürütme, gerekirse yeniden ölç.

Bankada **2920 soru** var. Uygulama App Store'da yayında (1.9.2+20).

---

## 0. Bağlayıcı kurallar

* **Türkçe** çalış ve Türkçe yaz.
* Kurmancî metinlerde **yalnız Hawar alfabesi**: `ı ğ ö ü İ` YOKTUR.
* Çeviri tek kaynaktan: `lib/src/l10n/strings.dart`. `context.s` ya da
  `.arb` kullanma. Testte beklenen metni **elle yazma**, `strings.dart`tan
  oku — son teslimde tam bu yüzden bir bekçi düştü.
* Dış bağlantılar `external_link.dart` üzerinden.
* Singleton store'larda `resetInstance()` korunur.
* **Yeni rapor dosyası üretme.** Bulgu üç yerde yaşar: testte, commit
  gövdesinde, kod yorumunda. Her düzeltmenin yanına onu koruyan bir test
  yaz ve testin belgesine kusurun ne olduğunu, **niçin sessiz kaldığını**
  yaz.
* Küçük, güvenli, test edilebilir adımlar. Her madde ayrı commit.

## 0.1 Yapma — bunlar bu depoda YAŞANDI

1. **Sahte iş.** Bir ajan 191 kayıtta yalnız `difficulty` alanını
   değiştirdi ve değeri kategori sayacının 3'e bölümünden üretti. Metinlere
   hiç dokunmamıştı. Geri alındı.
2. **Derlenmeyen kod.** Var olmayan sabit uydurma: `AppTheme.errorColor`
   ve `AppIcons.plus` YOKTUR; doğrusu `AppTheme.wrong`, `AppIcons.circlePlus`.
   Kullanmadan önce dosyada olduğunu doğrula.
3. **Test koşmamak.** Son teslim `dart analyze`dan geçti ama `flutter test`
   hiç çalıştırılmamıştı: 7 px satır taşması ve kendi yazdığı bekçinin
   düşmesi teslimden sonra bulundu.
4. **Kendi kendini onaylamak.** Bir çapraz kontrol dosyası, doğru cevabı
   kaydın kendisinden kopyalayan bir satırla bozuldu ve 55 hüküm çöpe gitti.
   Doğrulama, doğrulanan şeyden BAĞIMSIZ bir kaynaktan gelmeli.

---

## 1. Çapraz kontrolü olmayan 1810 soru — öncelik en yüksek

Bankanın %62'si hiçbir otomatik anahtar denetiminden geçmedi.

**Araç hazır:** `tool/content_authoring/cross_check.py`. Soruyu modele
**anahtarı göstermeden** sorar ve kendi yazdığı anahtarla karşılaştırır.
Anahtar bilerek gizlenir: gösterilseydi model neredeyse her zaman
onaylardı.

```bash
python3 tool/content_authoring/cross_check.py <banka.json> docs/content_batches/capraz_kontrol.json
```

Betik DeepSeek anahtarını `~/.local/share/opencode/auth.json` içinden
okur. **Kota bittiyse dur ve haber ver — uydurma hüküm yazma.** Betiğin
içinde bunun bekçisi var: istek tamamen başarısızsa hiçbir şey yazmaz,
çünkü bir keresinde başarısız parti de "?" alıp 77 soru kalıcı olarak
hükümsüz kalmıştı.

**Bitti sayılır:** `capraz_kontrol.json` kapsamı ölçülür ve
`docs/content_batches/celiskiler.json` içindeki çelişkili kayıtlar elden
geçirilir. Çelişki tek başına "yanlış" demek değildir — insan denetimi
gereken küçük kümeyi belirler.

**Bilinen kör nokta:** bu yöntem yalnız ŞIKKI denetler, SORUYU denetlemez.
Uydurma bir ödül ya da uydurma bir kayıt, dört şıktan biri doğru olduğu
sürece temiz geçer. Madde 2 bu boşluğu kapatır.

---

## 2. Makine taramasının 22 bulgusu — öncelik yüksek

```bash
python3 tool/content_authoring/sik_kalite_taramasi.py
```

Şu an **16 biçim sızması** + **6 uzunluk sızması** var. İkisi de cevabın
soruyu okumadan bilinmesine yol açar: doğru şık tek başına sayı taşıyor,
ya da çeldiricilerden belirgin uzun.

Düzeltirken **diğer bekçileri kırma.** Şunlar birlikte çalışır ve son
düzeltme turunda üçü birden düştü:

* `question_distractor_quality_test` — doğru cevap çeldiricileri 1,5 kat
  aşamaz; çeldiriciler doğru cevapla **aynı türden** olmalı (tarih/tarih
  dışı). Dikkat: Dart regex'inde `1830î` yıl sayılır ama `1946an` sayılmaz
  (`î` sözcük karakteri değil). Aynı eki kullan.
* `turkish_translation_integrity_test` — Türkçe **soru metni** uzunluğu
  Kurmancî'nin 0.55–1.9 katı olmalı. Şıkları değil, kökü ölçüyor.
* `question_bank_test` — doğru cevabın ekrandaki konum yayılımı ≤1. Kayıt
  ekledikten ya da anahtar değiştirdikten sonra:
  ```bash
  python3 tool/rebalance_answer_positions.py
  ```
  Yeniden sıralama çapraz kontrolü bozmaz — hükümler harf değil **metin**
  saklıyor, tam bu sebeple.

---

## 3. Park edilmiş 77 soru — öncelik yüksek

`docs/content_batches/bekleyen_2026_08_19_cografya_cand_edebiyat.json`
içinde **Cografya 41, Çand 29, Edebiyat 7** soru duruyor. Elden geçmişler
ama çapraz kontrolden geçmedikleri için bankaya alınmadılar.

Bu üç kategori tam da zorluk açığı olan üç kategori (madde 4). Sıra:
önce çapraz kontrol, sonra bankaya ekleme, sonra konum dengeleme.

---

## 4. Zorluk dengesi — öncelik orta

Hedef: her kategoride zorluk 4-5 oranı **%30**. Açık üç kategoride:

| Kategori | Soru | Zor | Oran | Gereken |
|---|---:|---:|---:|---:|
| Cografya | 318 | 71 | %22 | +24 |
| Çand | 257 | 62 | %24 | +15 |
| Edebiyat | 239 | 70 | %29 | +2 |

**Etiket değiştirerek kapatma.** Bir sorunun zorluğu, sorunun kendisi zor
olduğu için 4'tür. Yalnız `difficulty` alanını yükseltmek yukarıdaki 1
numaralı sahte iştir ve geri alınır. Madde 3'teki 77 soru bankaya
girerse açık büyük ölçüde kapanır; kalanı **yeni zor soru yazarak**
kapat.

---

## 5. Profil ekranında `RankMedal` — öncelik düşük

`docs/TASARIM_DEVAM_NOTU.md` bölüm 4.4 profil kartlarında `RankMedal` ve
`RewardToken` istiyordu; yalnız `RewardToken` uygulandı.
`lib/src/widgets/arena_kit.dart` içindeki `RankMedal` sıralama/rozet
gösteriminde kullanılsın.

---

## 6. Her adımdan sonra — atlanamaz

```bash
dart analyze                                    # temiz olmalı
flutter test                                    # 2367 test geçiyor
flutter test tool/screenshots/screen_tour_test.dart
```

Ekran turu bütün ana ekranları `docs/screenshots/tour/` altına basar:
açık/karanlık tema, Türkçe/Kurmancî, boş durumlar dâhil. **Emoji ve
`CustomPainter` metni test koşucusunda kutu çıkar**; o ikisi simülatörden
doğrulanır, tur çıktısından değil.

Görsel değişiklik simülatörden gözle doğrulanmadan bitmiş sayılmaz. Bu
projede üç kusuru yalnız simülatör yakaladı — krem kalan sayfa zemini,
enine gerilmiş baklavalar, ayrık duran şerit. Üçü de "doğru ama yanlış
görünüyor" türündendi; hiçbir test yakalayamazdı.

---

## 7. Bitti ölçütü

Bir madde şu dördü sağlanınca bitmiştir:

1. `dart analyze` temiz, `flutter test` tam geçiyor.
2. Düzeltmenin yanında onu koruyan bir test var ve testin belgesinde
   kusurun ne olduğu, niçin sessiz kaldığı yazılı.
3. Commit gövdesi *neyin* değil *niçin* değiştiğini anlatıyor.
4. Görsel değişiklikse ekran turunda taşma yok ve simülatörden görüldü.

Bir maddeyi bitiremezsen **yarım olduğunu açıkça yaz.** Yarım iş kabul
edilir; tam sanılan yarım iş kabul edilmez.
