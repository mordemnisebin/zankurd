# ZanKurd — Kalan UX İşleri (devralma prompt'u)

> Bu dosyanın tamamını yeni ajana ilk mesaj olarak ver.

---

Merhaba. ZanKurd Flutter uygulamasında yarım kalmış bir UX düzeltme işini
devralıyorsun. Aşağıdaki maddeleri **eksiksiz** tamamlamanı istiyorum.

## 1. Bağlam

- Repo: `/Users/kocer/Projects/zankurd`, ana ürün `zankurd_mobile/`
- Çalışılacak dal: `ux/live-review-fixes` (zaten var, `main`'e merge edilmedi)
- Kaynak rapor: `ZANKURD_LIVE_UX_REVIEW.md` — canlı gezinti ile üretilmiş
  34 maddelik bulgu listesi. §7 uygulama durumunu anlatır.
- Önce `AGENTS.md` ve `CLAUDE.md` dosyalarını oku; çalışma kuralları oradadır.

**Şu ana kadar yapılanlar** (tekrar etme): quiz ekranının sabit aksiyon barı,
soru bankası dil karışıklığına cırcır koruması, profil "Oyun" karosu, altı
noktada kontrast düzeltmesi, kategori renklerinin ada bağlanması, form
doğrulama tutarlılığı, rozet başlığı/mağaza/liderlik düzen düzeltmeleri,
kategori-seviye adlarının çevrilmesi, misafir çıkış uyarısı, "Hesabımı Sil"in
en alta taşınması, giriş animasyonunun kısaltılması.

## 2. Çalışma kuralları (uyulması zorunlu)

- **Türkçe** cevap ver, kod yorumlarını da Türkçe yaz.
- Büyük refactor yapma. Küçük, güvenli, test edilebilir adımlarla ilerle.
- Her madde **kendi commit'inde** olsun; commit mesajında *neyin* değil
  *neden* değiştiğini yaz (bulgu → kök neden → düzeltme).
- Her düzeltmeye, gerekçesini anlatan kısa bir kod yorumu ekle
  (mevcut kodda `2026-07-22 canlı UX denetimi` referanslı örnekler var,
  aynı deseni sürdür).
- **Davranış değiştiren her düzeltme için test yaz.** Test anlamlı mı diye
  doğrula: düzeltmeyi geçici geri al, testin kırıldığını gör, geri koy.
- Her adımdan sonra:
  ```
  cd zankurd_mobile
  dart analyze lib/ test/
  flutter test --exclude-tags preview
  ```
  Şu an taban: **671 test geçiyor, analyze temiz.** Bu sayı düşmemeli.
- Ekran değişikliği yaptıysan gerçek build ile de bak:
  ```
  flutter build web --release
  cd build/web && python3 -m http.server 8790
  ```
  375x812 mobil viewport'ta kontrol et.

## 3. YAPMA — geçersiz maddeler

Rapordaki şu üç madde **hatalı tespitti**, uygulama:

1. **"Düelloda soru başına 10 saniye"** — Düello 20 sn
   (`matchmaking_screen.dart:463`, bilinçli karar). Zamanlayıcı geri sayımın
   ortasında yakalanmış.
2. **"Ana sayfa açık tema CTA rengi marka turuncusuna dönsün"** —
   `AppTheme.primaryCtaColor` açık temada bilerek `#C05000`; beyaz metinle
   ~5.8:1 veriyor. Marka turuncusu (#F5931E) ~2.2:1 ile AA'da kalıyor.
   Uygularsan erişilebilirliği bozarsın.
3. **"Ayarlar dişlisini tema için güneş/ay ikonuna çevir"** —
   `home_screen.dart:542` zaten `AppIcons.sun` / `AppIcons.moon` kullanıyor.

## 4. Kalan işler

### 4.1 Önce bunlar — teknik, karar gerektirmiyor (7 madde)

**M10 — Kategori kartlarındaki boş renkli bant**
`lib/src/screens/categories_tab.dart`
Kök neden: kartlar `GridView` + `childAspectRatio` ile **sabit yükseklikte**
hücrelerde, ama kart içeriği `Column(mainAxisSize: min)`. İçerik bitince
gradyan hücrenin geri kalanını dolduruyor → her kartın alt ~%30'u boş renkli
bant. `LinearProgressIndicator` Column'ın son çocuğu.
Kabul: kartın alt kenarı ile ilerleme çubuğu arasında amaçsız boşluk kalmasın.
Ya içerik hücreyi doldursun (çubuktan önce `Spacer`) ya da aspectRatio
içerikten hesaplansın. 320/375/768 px'de taşma olmamalı.

**M15 — Alt kategori ikonları içerikle ilgisiz + kart watermark'ı taşıyor**
`lib/src/screens/subcategory_screen.dart:263` `_iconForId`
Kök neden: ikonlar anlama göre değil, id'lerin gruptaki sırasına göre
atanıyor — `dengbeji` (dengbêjlik) → `book`, `amur` (müzik aletleri) → `pen`,
`jineoloji` → `pen`. Ayrıca kartların sağındaki dekoratif blok kart sınırının
dışına taşıyor ve içerik gibi görünüyor.
Kabul: her alt kategori anlamına uygun ikon alsın. İkon eşlemesini
`lib/src/config/subcategory_config.dart` içine alan olarak taşımak tercih
edilir (`CategoryVisuals` deseni gibi tek kaynak). Watermark kart sınırında
kırpılsın.

**M16 — Seviye ekranında geri butonu kayboluyor**
`lib/src/screens/level_screen.dart`
Kök neden: app bar sticky değil; sayfa kaydırılınca beyaz geri oku açık gri
zemin üzerinde kalıyor ve görünmez oluyor.
Kabul: geri butonu her kaydırma konumunda okunur olsun (sticky app bar veya
kaydırınca zemin kazanan bar).
Ayrıca: seviye kartlarındaki 6 yıldızdan bir kısmı hiç oynanmamış hesapta
dolu görünüyor — yıldız "ilerleme" sanılıyor ama zorluğu gösteriyor.
Ya etiketle ("zorluk") ya da farklı bir gösterime geçir.

**M26 — Header'larda safe-area yok**
`lib/src/screens/home_screen.dart` (üst metrik çipleri),
`lib/src/screens/onboarding_screen.dart`, `lib/src/screens/sign_in_screen.dart`
(KU/TR toggle)
Kök neden: içerik status bar'a yapışık başlıyor.
Kabul: çentikli cihazlarda üst güvenli alan bırakılsın. Alt navigasyonda da
home indicator kontrolü yap.

**M30 — Turnuva bracket'i yatay kırpılıyor**
`lib/src/widgets/tournament_bracket_widget.dart`
Kök neden: "Çeyrek Final" sütunundaki kartlar ekranın sağından kesiliyor,
kaydırma göstergesi yok.
Kabul: yatay kaydırılabilir olsun ve kaydırılabildiği görsel olarak belli
olsun (kenar gradyanı/fade). Kırpılmış kart kalmasın.

**M31 — Çark durunca rakamlar eğik kalıyor**
`lib/src/screens/spin_wheel_screen.dart`
Kök neden: dilim metinleri çarkla birlikte döndüğü için duruş pozisyonunda
ters/eğik okunuyor.
Kabul: çark durduğunda rakamlar okunabilir yönde olsun.
Ek: sarı dilimlerdeki beyaz rakamlar ~1.9:1; koyu metne çevir
(`AppTheme.bg`), altın bantta zaten bu yapıldı — aynı deseni izle.

**M32 — Profil sekmesi yüklenirken boş siyah ekran**
`lib/src/screens/profile_screen.dart`
Kök neden: yükleme göstergesi ~4px'lik bir kare; kullanıcı boş ekran görüyor.
`lib/src/widgets/skeleton_loader.dart` zaten var, kullanılmıyor.
Kabul: yüklenirken iskelet (skeleton) gösterilsin.

### 4.2 Yarım kalanları tamamla (4 madde)

**M9 — Kayıt ekranında inline doğrulama**
`lib/src/screens/sign_up_screen.dart`
Yapıldı: geri butonu eklendi, hata SnackBar'ı renklendirildi.
Kalan: hata hâlâ SnackBar. Profil adı ekranı (`profile_name_gate_screen.dart`)
inline gösteriyor — iki farklı doğrulama dili sürüyor.
Kabul: alanlar `TextFormField` + `validator` +
`AutovalidateMode.onUserInteraction` ile inline doğrulasın; hatalı alan
kırmızıya dönsün. Parola kuralı (min 6 karakter) hata beklemeden yazsın.
Referans: `profile_name_gate_screen.dart` ve
`test/profile_name_gate_validation_test.dart`.

**M13 — İki rozet bölümünü birleştir**
`lib/src/screens/profile_screen.dart`, `lib/src/widgets/badge_collection_section.dart`
Yapıldı: başlık taşması düzeltildi.
Kalan: profilde iki ayrı rozet bölümü var — "Rozetler 1/8" ve
"Rozet Koleksiyonu 0/5". Farklı sayaçlar, aynı kavram, kullanıcı için kafa
karıştırıcı.
Kabul: tek bölüm, tek sayaç.

**M18 — Misafir hesabını kalıcı hale getirme akışı**
`lib/src/screens/profile_screen.dart`, `lib/src/providers/auth_provider.dart`
Yapıldı: çıkışta veri kaybı uyarısı (`isGuest` dalı).
Kalan: misafirin hesabını kaydetmesinin **hiçbir yolu yok**. Supabase anonim
kullanıcıyı e-posta/Google ile yükseltmeyi destekler.
Kabul: profilde "Hesabını kaydet" girişi olsun; başarılıysa ilerleme korunsun.
Bu backend'e dokunuyor — önce mevcut `auth_provider` akışını incele.

**M28 — CTA'larda çift okuma**
`lib/src/widgets/styled_button.dart` (ve benzeri buton bileşenleri)
Yapıldı: KU/TR toggle'a semantik etiket.
Kalan: ana butonlar erişilebilirlik ağacında iki kez okunuyor:
`"Têkeve Têkeve"`, `"Giriş Yap Giriş Yap"`, `"Oyuna Başla Oyuna Başla"`.
Muhtemel neden: hem `Semantics(label:)` hem de içteki `Text` sayılıyor.
Kabul: her buton adı bir kez okunsun. `read_page` çıktısıyla doğrula.

### 4.3 Görsel yön kararı gerektiriyor — ÖNCE KULLANICIYA SOR (4 madde)

Bunları doğrudan uygulama; önce seçenekleri sun ve onay al.

**M24 — Mağaza ekonomisi ve paleti**
`lib/src/screens/shop_screen.dart`
Sorun: quiz başına ~45 coin kazanılıyor, en ucuz ürün 100c, çoğu 300–1000c →
yeni kullanıcı için mağaza "bakılır, alınmaz". Ayrıca renkler (pastel mavi,
pembe, mor) marka paletinin tamamen dışında.
Karar gerekiyor: fiyatlar mı düşecek, kazanç mı artacak, giriş ürünü mü
eklenecek? Palet marka renklerine mi çekilecek?

**M25 — Avatar renkleri**
`lib/src/widgets/player_avatar.dart`
Sorun: isimden türetilen renkler palet dışına çıkıyor (pembe/kırmızı
`#D64560`, mor, teal). Liderlikte üç oyuncu da aynı pembe.
Karar gerekiyor: hangi sınırlı renk kümesi? `CategoryVisuals` deseni gibi
tanımlı bir palet üzerinden dağıt.

**M33 — Roj maskotunun kullanımı**
`lib/src/widgets/roj_mascot.dart`
Sorun: markanın en ayırt edici görseli yalnız "Günün Sözü" kartında ve
liderlikte var; onboarding'de ve boş durumlarda yok.
Karar gerekiyor: nerelerde görünsün?

**M23 — Ekranların boş alt alanları**
Etkilenen: turnuva girişi, eşleşme, giriş, profil adı kapısı, 2 şıklı quiz,
liderlik.
Sorun: neredeyse her ekranın alt %20–40'ı boş; düzenler sabit ölçülerle
kurulmuş, içerik miktarına göre esnemiyor.
Karar gerekiyor: boşluk içerikle mi doldurulacak (turnuva geçmişi,
istatistikler) yoksa düzen dikeyde mi dengelenecek?

### 4.4 Tasarım + ürün kararı (2 madde)

**M34 — Tablet genişliğinde tek sütun**
`lib/src/widgets/responsive_wrapper.dart` (`maxContentWidth` ile ortalıyor)
768px'de içerik dar bir sütunda ortalanıyor, yanlar boş. İki sütunlu düzen
fırsatı kaçıyor. Kapsamlı iş; ayrı planlanmalı.

**M20 — Yanlış cevaptan sonra açıklama**
`lib/src/screens/quiz/`, `review` ekranı
`QuizQuestion.explanation` alanı zaten var ve dolu; ama yarışma modunda tur
içinde gösterilmiyor (`_isLearningExperience` koşulu), inceleme ekranında da
yok. Öğrenme uygulamasında "neden" eksik.
Karar gerekiyor: tur içinde mi (tempoyu bozar) yoksa yalnız "Cevaplar"
ekranında mı gösterilsin? Ben ikincisini öneririm.

## 5. İçerik işi (kod değil, editöryel)

Bunlar kod tarafında **koruma altına alındı**, ama içerik düzeltmesi yapılmadı.
Senin işin değilse kullanıcıya hatırlat:

- **320 soruda gövde/şık dili ayrışıyor** (%13,6). Ziman/Rêziman çeviri
  alıştırmaları muaf. Döküm:
  `python3 tools/audit_question_language_mix.py --csv ihlaller.csv`
  Taban `test/question_language_policy_test.dart` içinde **320**; düzeltme
  yapıldıkça bu sayı **düşürülmeli**.
- **1070 etkin tekrar soru** (483 kümede aynı ipucu + aynı doğru cevap, farklı
  şablon önekiyle).
- **2347 sorunun 800'ü** yalnız iki kalıptan geliyor
  ("Di gotûbêja dersê de,", "Di nirxandina xwendekaran de,").

## 6. Bitirince

- `ZANKURD_LIVE_UX_REVIEW.md` §7'yi gerçek duruma göre güncelle.
- Yanlış çıkan bir tespit bulursan **düzelt ve söyle** — raporu savunma,
  doğruluğu savun. (Yukarıdaki üç geçersiz madde böyle bulundu.)
- Özet ver: hangi madde yapıldı, hangisi neden yapılmadı.
