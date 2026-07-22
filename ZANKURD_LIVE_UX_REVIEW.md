# ZanKurd — Canlı Uygulama UX & Tasarım Denetimi

> **Durum (2026-07-22):** Bu raporun bulguları `ux/live-review-fixes` dalında
> uygulandı — 11 commit, 671 test geçiyor, `dart analyze` temiz.
> Uygulananların özeti ve düzeltilen tespitler için bkz. **§7 Uygulama durumu**.

**Tarih:** 2026-07-22
**Yöntem:** `flutter build web --release` ile üretilen gerçek build, tarayıcıda
mobil viewport'ta (320 / 375 / 768 px) canlı gezildi. Production Supabase'e
misafir girişi yapıldı, tam bir quiz (10 soru) oynandı, düello/oda/turnuva/çark/
mağaza akışları çalıştırıldı. Her bulgu ekran görüntüsü, konsol çıktısı veya
erişilebilirlik ağacı okuması ile doğrulandı.
**Kapsam:** Kurmancî + Türkçe × açık + karanlık tema × 3 genişlik.
**Not:** Bu bir denetim raporudur; kod değiştirilmedi.

---

## 1. Yönetici özeti

ZanKurd, "yarım kalmış bir prototip" değil — **çalışan, dolu, düşünülmüş bir
ürün**. Onboarding'den turnuva bracket'ına kadar her akış gerçekten
tamamlanmış, boş durumlar yazılmış, çıkış onayları konmuş, iki dil ve iki tema
gerçekten uygulanmış. Bu, bu olgunluktaki çoğu projeden ileride.

Sorun şu: **iyi parçalar birbiriyle konuşmuyor.** Uygulama tek bir tasarım
sisteminden değil, birbirinden habersiz 5-6 ayrı tasarım kararından oluşuyor
gibi görünüyor. Ve öğrenme döngüsünün merkezindeki iki şey — quiz ekranının
ekrana sığması ve soru içeriğinin dil tutarlılığı — şu an kırık.

**En güçlü 5 nokta**
1. **Çark ekranı** — marka renklerini doğru kullanan, tek başına ayakta duran
   bir ekran. Uygulamanın geri kalanı bu seviyeye çekilmeli.
2. **Oda akışı** — oda kodu, kopyalama, hazır toggle, "en az 2 oyuncu gerekli"
   engelleyicisi: eksiksiz ve net.
3. **Cevaplar (inceleme) ekranı** — doğru cevap yeşil, senin yanlışın kırmızı
   ✗ ile ayrı ayrı işaretleniyor. Öğrenme için doğru kurulmuş.
4. **Kültürel içerik** — "Gotina rast şîrîn e" günün sözü kartı, erbane
   fotoğraflı soru, Kurmancî bot isimleri (Azad, Rojîn, Berfîn, Şêrko).
   Ürünün ruhu burada.
5. **Karanlık tema** — koyu yeşil yüzeyler + krem metin kombinasyonu marka ile
   uyumlu ve açık temadan **daha iyi** duruyor.

**En zayıf 5 nokta**
1. **Quiz ekranı zaman baskısı altında ekrana sığmıyor** — cevap verdikten
   sonra "Sonraki" butonu görünmüyor, scroll gerekiyor (P0).
2. **Soru bankasında dil karışıklığı** — Kurmancî soru + Türkçe şıklar aynı
   soruda görüldü (P0).
3. **Renk sistemi yok** — sayfa sayfa 15+ farklı doygun renk; aynı kategori
   üç ekranda üç farklı renkte.
4. **Kontrast hataları görünür yerlerde** — profil "Bronz Lig" rozeti, sonuç
   ekranı yıldızları ve istatistik etiketleri, çark kutlama bandı okunmuyor.
5. **Sayısal tutarsızlık** — sonuç 479 puan / %30 doğruluk, profil 210 puan /
   %27 doğruluk / "0 oyun".

---

## 2. Ekran ekran bulgular

### 2.1 Onboarding (`lib/src/screens/onboarding_screen.dart`)
- **Dikey denge bozuk.** 3 sayfanın hepsinde kartın üstünde ~135px, altında
  ~125px kullanılmayan alan var; içerik ne ortada ne üstte.
- **Üst satır hizasız.** Wordmark (y≈54) ile "Derbas bike" (y≈38) farklı
  baseline'da; safe-area boşluğu yok, status bar altında kalır.
- **Kart renkleri anlatı kurmuyor.** Turuncu → bakır kahve → hardal: üç kart
  arasında ilerleme/heyecan artışı hissi yok, tonlar birbirine yakın ve mat.
- Sayfa 3'te beyaz ikon dairesi hardal zemin üzerinde neredeyse kayboluyor.
- **Roj maskotu burada kullanılmamış** — markanın en ayırt edici görsel varlığı
  onboarding'de yok, sadece ana sayfadaki bir kartta beliriyor.

### 2.2 Giriş (`sign_in_screen.dart`)
- **Açılış animasyonu 2000 ms.** İlk yakalanan karede logo ve hoş geldin
  banner'ı henüz yok; kullanıcı ~2 saniye yarı boş bir ekran görüyor.
  (`AnimationController(duration: Duration(milliseconds: 2000))`)
- **İki birincil eylem çakışıyor.** "Google ile giriş yap" beyaz zemin üzerinde
  beyaz buton (sadece gölgeyle ayrışıyor), "Giriş Yap" turuncu. İkisi de
  birincil görünüyor, hiyerarşi yok.
- **İki farklı gölge dili yan yana.** Google butonunda yumuşak blur gölge,
  "Giriş Yap"ta 4px sert offset gölge (neo-brutalist). Aynı kartın içinde.
- **Input alanları "devre dışı" görünüyor.** Dış beyaz kutu + iç gri kapsül
  şeklinde iki katmanlı; kapsülün içi boş ve placeholder yok.
- **KU/TR toggle butonlarının erişilebilirlik etiketi yok** (ağaçta
  `button [ref_2]`, `button [ref_3]` olarak isimsiz görünüyor).
- Ana CTA'lar semantik ağaçta çift okunuyor: `"Têkeve Têkeve"`,
  `"Giriş Yap Giriş Yap"` — ekran okuyucu her buton adını iki kez söyler.

### 2.3 Kayıt (`sign_up_screen.dart`)
- **Geri dönüş yolu yok.** 3 adımlı sihirbazın hiçbir adımında app bar veya
  geri butonu yok; tek çıkış alttaki "Giriş Yap" linki.
- **Hata gösterimi ekranın geri kalanıyla çelişiyor.** Boş formla "İleri"ye
  basınca hata **beyaz, ikonsuz, renksiz bir snackbar** olarak altta çıkıyor
  ("E-posta gerekli"); alan kırmızıya dönmüyor. Oysa profil adı ekranında
  aynı durum kırmızı border + kırmızı yardım metni ile gösteriliyor.
  **İki farklı doğrulama dili.**
- Parola kuralı (min 6 karakter) hiçbir yerde yazmıyor; hata alınca öğreniliyor.
- Adım göstergesi sadece 1/2/3 rakamları — adımların ne olduğu belli değil.

### 2.4 Profil adı kapısı (`profile_name_gate_screen.dart`)
- **Hata durumu temizlenmiyor.** "Ad en az 2 karakter olmalı" hatası
  gösterildikten sonra 6 karakterlik geçerli bir isim yazıldığında kırmızı
  border ve hata metni **ekranda kalıyor**. (Doğrulandı: "Rojhat" yazıldıktan
  sonra hata hâlâ görünür.) Girdi değiştiğinde hata sıfırlanmalı.
- Turuncu hero alanının alt ~125px'i tamamen boş.
- Misafir kullanıcı için isim zorunlu ama "sonra sorulsun" seçeneği yok.

### 2.5 Ana sayfa (`home_screen.dart`, `screens/home/`)
- **Açık temada birincil buton rengi yanlış.** "Başla" butonu açık temada
  tuğla/kiremit kırmızısına (≈#B5541A) kayıyor; karanlık temada aynı buton
  doğru marka turuncusu (#F5931E) olarak render oluyor. Onboarding'in parlak
  turuncu CTA'sıyla açık temada uyuşmuyor.
- **"Hemen oyna" kartı tıklanabilir görünmüyor.** Açık temada kart zemini ile
  sayfa zemini neredeyse aynı (#F2F3F4 vs #EFEFEF); karanlık temada fark daha
  da az (#121612 vs #0B0F0D) ve kart sınırı yok.
- **Günlük görev satırlarında hizalama kırığı.** "0 / 1" ilerleme metni satırın
  sol altında, ikonla hizalı değil (x≈110 vs ikon x≈137) ve yanında ilerleme
  çubuğu yok — sadece çıplak metin.
- **Liderlik özetinde kendi sıran yok.** Top-3 gösteriliyor, "sen X.
  sıradasın" satırı yok.
- **Üst metrik çipleri tutarsız.** Ana sayfada 2 çip (seri, coin), quiz
  ekranında 3 çip (kupa, seri, coin). Aynı kullanıcı, farklı sayıda metrik.
- Header'daki büyük yıldız watermark çok soluk ve amaçsız duruyor.

### 2.6 Kategoriler (`categories_tab.dart`)
- **Her kartın alt ~%30'u boş.** İçerik satırı bittikten sonra ince bir
  ilerleme çizgisi, ardından 55px yüksekliğinde boş renkli bant geliyor.
  8 kartın hepsinde tekrarlıyor — sistematik bir düzen hatası gibi duruyor
  (muhtemelen çubuğun altındaki etiket eksik ya da padding fazla).
- **Renk paleti rastgele.** 8 kategori = turuncu-kahve, bordo, mavi, hardal,
  yeşil, kiremit, mor, teal. Marka paletiyle (turuncu / koyu yeşil / altın)
  ilişkisi yok; mavi ve mor kültürel palete hiç oturmuyor.
- **Kontrast riski.** Müzik (hardal ≈#C9A93B) ve Dil (turuncu-kahve) kartları
  üzerindeki beyaz alt metin ("491 soru • 5 seviye") tahmini 2:1–2.5:1
  aralığında — WCAG AA (4.5:1) altında.
- **Siyaset kategorisinin ikonu onay kutusu** — konuyla ilgisi yok.
- Dikey liste; her kart ~210px. 8 kategori 2 ekran boyu yer kaplıyor.

### 2.7 Alt kategori (`subcategory_screen.dart`)
- **Kategori rengi liste ile detay arasında tutmuyor.** Müzik: listede hardal
  sarı, detay ekranında bordo/pembe. Tarih: listede bordo, düelloda lacivert.
  Üç ayrı yerden üç ayrı renk geliyor.
- **Alt kategori ikonları içerikle ilgisiz.** Dengbêjlik → liste ikonu,
  Modern Müzik → kitap, Müzik Aletleri → kalem. Hiçbiri müzikle ilgili değil;
  jenerik bir ikon dizisinden sırayla atanıyor gibi.
- **Kartların sağındaki dekoratif blok kırpılmıyor.** Dengbêjlik kartında sağ
  taraftaki pembe watermark, kart sınırının dışına taşıyor ve içerik gibi
  görünüyor (iki beyaz çubuk).
- Hero'nun sol üstünde açıklanamayan küçük gri nokta (y≈133).
- Hero'nun üst ~%60'ı boş (başlık en altta).

### 2.8 Seviye haritası (`level_screen.dart`)
- **Geri butonu scroll'da okunmaz hale geliyor.** App bar sticky değil; ok
  içerikle birlikte kayıyor ve açık gri zemin üstünde beyaz kalıyor.
- **Yıldızlar yanıltıcı.** Hiç oynanmamış bir hesapta seviyeler 2/6, 2/6, 3/6,
  4/6 yıldızlı görünüyor — yani yıldız ilerlemeyi değil zorluğu gösteriyor.
  Yıldız evrensel olarak "kazanılmış ilerleme" sinyalidir; etiketsiz kullanımı
  yanlış okunuyor. Ayrıca yıldızların hepsi içi boş çerçeve — dolu/boş ayrımı
  görsel olarak zayıf.
- **Seviye dairelerinin renkleri anlam taşımıyor** (yeşil, lacivert, hardal,
  turuncu, altın). Duolingo-tarzı patikada renk = durum olmalı.
- **TR arayüzde seviye adları çevrilmemiş**: Destpêk, Bingeh, Navîn, Pêşketî,
  Mamoste.
- Kilit durumu gösterilmiyor — tüm seviyeler açık mı, belli değil.

### 2.9 Quiz (`quiz_screen.dart`, `screens/quiz/`) — **en kritik ekran**

**P0 — Cevap sonrası "Sonraki" butonu görünmüyor.**
375×812'de (iPhone SE'den büyük bir ekran) cevap verdikten sonra "Süre doldu /
doğru cevap" bandı eklenince ana ilerleme butonu viewport'un altında kalıyor;
kullanıcı scroll etmeden devam edemiyor. Uzun şıklı sorularda buton **cevap
vermeden önce de** görünmüyor. Doğrulandı: aynı quiz içinde 3 farklı soruda
"Sonraki"ye ulaşmak için scroll gerekti, bir soruda D şıkkı bile ekran dışında
kaldı — üstelik 30 saniyelik sayaç çalışırken.

**P0 — Soru içinde dil karışıyor.**
`"Di çarçoveya Muzîkê de 'Kardeş Türküler' tê çi wateyê?"` sorusunun 4 şıkkı da
**Türkçe**. Aynı quiz içinde kimi sorular tamamen Kurmancî, kimi soru Kurmancî
gövde + Türkçe şıklar. Arayüz dili ne olursa olsun bu bir içerik hatası.

**Düzen ekrana uyum sağlamıyor.** 4 uzun şıklı soruda ekran taşıyor; 2 şıklı
Doğru/Yanlış sorusunda ekranın alt %20'si boş kalıyor. Tek bir sabit düzen iki
ucu da idare edemiyor.

**Şık harflerinin renkleri yanıltıcı.** A kırmızı, B mavi, C yeşil, D hardal.
Quiz bağlamında **kırmızı = yanlış, yeşil = doğru** demektir; cevaplamadan önce
bir şıkkı yeşil, birini kırmızı göstermek yanlış sinyal veriyor.

Diğer:
- App bar sadece "Müzik" diyor; alt kategori ve seviye bilgisi yok.
- "Bildir" ikonu siyah bir uyarı üçgeni — "bu soruda hata var" izlenimi veriyor.
- Joker çipleri ~40px yüksekliğinde, 44pt dokunma hedefinin altında.
- Yanlış cevaptan sonra **açıklama yok** — öğrenme uygulamasında "neden" eksik.
- Sticky app bar'ın altına giren soru metni kesiliyor, fade/blur maskesi yok.
- Şık metinlerinde büyük/küçük harf tutarsız: "Şakiro", "bilûr", "Meryem Xan",
  "lîrîka klaman".
- Görselli soruda resim `contain` ile ortalanıyor; pembe kart üzerinde iki yanda
  beyaz letterbox oluşuyor.

### 2.10 Sonuç (`quiz_result_screen.dart`)
- **Yıldızlar okunmuyor.** Turuncu hero kart üzerinde turuncu yıldızlar;
  dolu/boş ayrımı neredeyse görünmez. Skorun en özet göstergesi bu.
- **Alt istatistik satırı kontrast hatası.** "3 Doğru / 7 Yanlış / 1 Seri" —
  sayılar açık, etiket kelimeleri koyu turuncu üzerinde daha koyu turuncu;
  tahmini 1.8:1. WCAG AA'nın çok altında.
- **Alt bağlantı satırında sarkan ayırıcı.** "Ana Sayfa • Sadece yanlışlar •
  Liderlik tablosu •" — son madde işaretinden sonra hiçbir şey yok, "Değerlendir"
  alt satıra kaymış.
- **"İncele" butonunun ikonu onay kutusu** — inceleme için yanlış metafor.
- "Yeni Rozet" bölümü iki satır iki ikon; hangisinin başlık hangisinin rozet
  olduğu belirsiz. %30 doğrulukla biten bir oyunda kutlama tonu ("YARIŞ
  TAMAMLANDI") ile teşvik mesajı arasında ayrım yok.

### 2.11 Cevaplar / inceleme (`review`)
- **İyi:** doğru cevap yeşil ✓, kullanıcının yanlış seçimi kırmızı ✗ ile ayrı
  ayrı işaretleniyor. Doğru kurulmuş.
- **Şık sırası quiz'dekinden farklı** ve A/B/C/D harfleri kaldırılmış —
  kullanıcı ne seçtiğini eşleştirmekte zorlanıyor.
- **Açıklama yok.** Neden doğru olduğu anlatılmıyor.
- Üstteki "Özet: 3 doğru • 7 yanlış • 0 boş" kartı ile hemen altındaki 3
  istatistik kartı aynı bilgiyi iki kez veriyor.
- **İçerik tekrarı:** 10 soruluk sette Soru 1 ve Soru 4 aynı bilgiyi soruyor
  ("dengbêjê mezin ê ku wekî 'Şahê Dengbêjan'..."). Birçok soru
  "Di gotûbêja dersê de..." kalıbıyla başlıyor — şablon üretimi hissi veriyor.

### 2.12 Yarış merkezi (`play_hub_screen.dart`)
- **"Günün Yarışması" kartı diğerlerinden farklı görünüyor** — gri zeminli ve
  gölgesiz; pasif/devre dışı okunuyor ama tıklanabilir.
- **Kart aralıkları düzensiz:** 24 / 24 / 40 / 24 px.
- "Mağaza ve jokerler" chevron'u sarı, diğerleri gri — kural yok.
- İkon renkleri: pembe, turuncu, açık yeşil, açık yeşil, sarı. Pembe palet dışı.
- "Bot + Canlı", "Bot kupa" alt metinleri rakibin bot olduğunu peşinen
  duyuruyor — rekabet hissini baştan düşürüyor.

### 2.13 Eşleşme ve düello (`matchmaking_screen.dart`)
- **Düelloda soru başına süre 10 saniye.** Karşıma çıkan soru 5 satırlık bir
  gövde + her biri 3 satırlık 4 şıktan oluşuyordu ve ekrana sığmıyordu.
  10 saniyede okunması fiziksel olarak mümkün değil; bot 110-0 kazandı.
  Oysa oda modunda süre 15–60 sn arası seçilebiliyor. **Denge ve tutarlılık
  hatası.**
- Kategori çipleri renksiz (hepsi beyaz) — kategori renk kodlaması burada
  uygulanmamış.
- "Rastgele eşleşme" kartı koyu teal (#3B7A6E) — uygulamada başka hiçbir yerde
  olmayan bir renk.
- Üstteki bilgi kartı sadece dekoratif (başlık + açıklama tekrarı, eylem yok).
- Canlı rakip bulunamıyor → bot öneriliyor. Bu ürün gerçeği, tasarım hatası
  değil; ancak diyalogda "Hayır" kırmızı renkte ve tehlikeli eylem gibi
  görünüyor.

### 2.14 Oda (`room_screen.dart`, `room_chat.dart`) — **en iyi ekranlardan**
- Oda kodu (ZK-FTZT), kopyala butonu, oyuncu listesi, hazır toggle ve
  "Yarışı başlatmak için en az 2 oyuncu olmalıdır" engelleyicisi eksiksiz.
- **Kategori adı çevrilmiyor.** TR arayüzde oda kategorisi "Ziman" olarak
  görünüyor; Kategoriler sekmesinde aynı kategori "Dil". **Aynı kategori iki
  farklı isimle.**
- Oda adı otomatik Kurmancî ("Hevalên Zanînê") — TR arayüzde dil karışıyor.
- "Oyuncu listesi güncelleniyor…" spinner'ı kalıcı görünüyor.
- Teal yüzey rengi ve teal toggle, uygulamanın turuncu primary'siyle ilgisiz.

### 2.15 Turnuva (`tournament_screen.dart`, `tournament_bracket_widget.dart`)
- Bracket iyi çalışılmış; Kurmancî bot isimleri güzel bir dokunuş.
- **Bracket yatay taşıyor** — "Çeyrek Final" sütunundaki kartlar ekranın
  sağından kırpılıyor.
- **Avatar renkleri tamamen rastgele**: teal, mavi-mor, mor, açık mavi, kırmızı,
  koyu mor, turuncu. 7 farklı doygun renk, palet dışı.
- Giriş ekranında "Bot turnuva • günlük kupa" çipi sarı üstüne sarı (≈2:1).
- Giriş ekranının alt %40'ı tamamen boş.
- "Her Cumartesi 20:00" + "Turnuvaya kalan: 3 gün" + hemen aktif "Turnuvaya
  Katıl" butonu birbiriyle çelişiyor.

### 2.16 Çark (`spin_wheel_screen.dart`) — **en iyi ekran**
- Marka renklerinde (turuncu/altın/yeşil) çark, ZK logolu merkez, parıltı
  detayları, net CTA, geri sayımlı kilitli durum. Uygulamanın referans noktası
  bu olmalı.
- **Kutlama mesajı okunmuyor:** "Tebrikler! +30 coin kazandın!" açık sarı zemin
  üzerine beyaz metin (≈1.3:1).
- Çark durduğunda dilim rakamları döner pozisyonda kalıyor (eğik/ters); okuması
  zor.
- Sarı dilimler üzerindeki beyaz rakamlar da düşük kontrastlı (≈1.9:1).
- Hero'da turuncu→yeşil gradient ortada çamurlu bir kahverengi üretiyor.

### 2.17 Mağaza (`shop_screen.dart`)
- **Ekonomi dengesi kurulmamış.** Bir quiz ≈ 45 coin kazandırıyor; en ucuz ürün
  100c, çoğu 300–1000c. Yeni kullanıcı için mağaza tamamen "bakılır, alınmaz".
  Erişilebilir bir giriş ürünü yok.
- **Ürün açıklamaları kesiliyor:** "…paletl…", "…seyir…", "…kullanabilece…".
  Kart yüksekliği sabit, metin sığmıyor.
- **Fiyat butonları devre dışı görünüyor** (gri zemin, gri metin) — alınabilir
  ve alınamaz ürünler aynı görünüyor.
- **Renkler tamamen palet dışı:** pastel mavi, pembe, mor, sarı. Uygulamanın
  geri kalanından kopuk bir estetik.
- Satın alma diyaloğunda **üç eylem üç farklı hizada** merdiven gibi diziliyor
  ("Coin kazan" ortada, "İptal" sağ üstte, "Satın Al" sağ altta) — actions satırı
  taşmış ve kırılmış.
- Son ürün grid'de tek başına, yanı boş.
- Yeni bir uygulamada "EN POPÜLER" rozeti inandırıcı değil.

### 2.18 Liderlik (`leaderboard_screen.dart`)
- **Kendi sıran yok.** 479 puanla quiz bitirdikten sonra bile listede yer
  almıyorum, sabitlenmiş "senin sıran" satırı da yok. Liderlik tablosunun temel
  motivasyon mekanizması eksik.
- **Podyum podyum değil.** #1 ortada biraz büyük, #2 ve #3 aynı boyutta yan
  yana; yükseklik farkı yok.
- Üç oyuncunun avatarı da aynı kırmızı/pembe — ayırt edici değil ve palet dışı.
- Seçili sekme ("Hafta") **sarı**, alt navigasyonda seçili sekme **turuncu**.
  Aynı uygulamada iki farklı "seçili" rengi.
- "Bronz Lig — Bu hafta yarış, lige gir!" kartı bej/kahve, düşük kontrast; ligde
  olup olmadığım mesajdan anlaşılmıyor.
- "Her 30 saniyede güncellenir" yazısı ile manuel yenile butonu birlikte
  gereksiz.

### 2.19 Profil (`profile_screen.dart`, `screens/profile/`)
- **"Bronz Lig" rozeti görünmüyor.** Turuncu hero üzerinde turuncu çip +
  turuncu metin (≈1.4:1). Dört kombinasyonda da (KU/TR × açık/karanlık)
  doğrulandı.
- **Sayısal tutarsızlık.** Sonuç ekranı: 479 puan, %30 doğruluk. Profil:
  "Toplam Puan 210", "%27 doğruluk", **"Oyun: 0"**. Bir oyun oynandığı halde
  oyun sayacı sıfır; puan alanı aslında XP'yi gösteriyor.
- **Terminoloji karışık:** puan / XP / coin üç ayrı birim, isimlendirme
  ekrandan ekrana değişiyor.
- **İki ayrı rozet bölümü:** "Rozetler 1/8" ve "Rozet Koleksiyonu 0/5". Farklı
  sayaçlar, aynı kavram.
- **"Rozet Koleksiyo…" başlığı kesiliyor** (TR'de). Başlık + "0/5" çipi +
  "Tümünü Gör" satıra sığmıyor; "Tümünü Gör" ekran kenarına yapışıyor.
- "Yanlışlarım — Tekrar Edilecek: 0 / Toplam: 8": 8 yanlış var ama tekrar
  edilecek soru yok. SM-2 aralığı doğru olabilir ama kullanıcıya böyle
  anlatılması kafa karıştırıyor.
- İstatistik kartlarının kenarlık renkleri (sarı/turuncu/sarı/yeşil/sarı/yeşil)
  hiçbir anlam taşımıyor.
- **Misafir hesabı için "hesabını kalıcı hale getir" yolu yok.** "Çıkış Yap"
  tüm ilerlemeyi kaybettirir ama uyarı yok.
- Profil sekmesine geçişte **boş siyah ekran + ~4px turuncu kare** yükleme
  göstergesi görünüyor; skeleton veya en azından görünür bir loader olmalı.

### 2.20 Ayarlar (`settings_screen.dart`)
- İçerik zengin ve iyi gruplanmış (HESAP / ÖĞRENME / GÜVENLİK / GÖRÜNÜM /
  SES & BİLDİRİM / UYGULAMA HAKKINDA). Dil, tema, hareketi azalt, ses, günlük
  hatırlatıcı, nasıl oynanır, gizlilik, sürüm — hepsi var.
- **"Hesabımı Sil" ekranın en üstünde, ikinci kartta.** En yıkıcı eylem en
  görünür konumda; en alta taşınmalı.
- Bölüm başlığı çubuklarının renkleri (sarı/yeşil/yeşil/sarı/sarı) anlam
  taşımıyor.
- "Hareketi azalt" ikonu film klaketi, "Güvenli çocuk modu"nun açıklaması yok.
- **İyi:** karanlık modda tema ikonu güneşten aya dönüyor.

### 2.21 Ana kabuk ve navigasyon (`app_shell.dart`)
- 5 sekmeli alt navigasyon net; aktif sekme pill + renk + etiket ile
  işaretleniyor.
- **Aktif pill rengi temaya göre kimlik değiştiriyor:** açık temada açık
  turuncu, karanlık temada hardal/zeytin. Karanlıkta marka turuncusu
  kayboluyor.
- Sekme geçişi sırasında iki sekme aynı anda aktif görünebiliyor.
- **Ayarlar dişlisi aslında temayı değiştiriyor.** Ana sayfa header'ındaki ⚙️
  ikonunun erişilebilirlik etiketi "Tema". Dişli evrensel olarak "Ayarlar"
  demektir; tema için güneş/ay kullanılmalı.
- Header'da safe-area boşluğu yok; çipler status bar'a çok yakın.
- Coach-mark turu (2 adım) iyi tasarlanmış.

---

## 3. Sistem düzeyi bulgular

### 3.1 Renk: bir palet değil, bir renk yığını
Tek bir gezintide sayılan **belirgin, doygun renk sayısı: 15+** — marka
turuncusu, koyu yeşil, altın, bordo, lacivert, hardal, orman yeşili, kiremit,
mor, teal, pembe/kırmızı (avatarlar), pastel mavi/pembe/mor (mağaza), koyu teal
(eşleşme). Bunların çoğu `app_theme.dart`'taki tanımlı token'lardan gelmiyor.

Somut sonuçları:
- Aynı kategori üç ekranda üç farklı renk (Müzik: hardal → bordo; Tarih: bordo
  → lacivert).
- "Seçili" durumu bazı ekranlarda turuncu, bazılarında sarı.
- Avatar renkleri isimden türetiliyor ve palet dışına çıkıyor.
- Mağaza tamamen farklı bir görsel dilde.

`AppTheme` içinde `brandGreen`, `culturalBrandBg`, `playGreen/Pink/Cyan/Purple`,
`secondaryAccent` gibi token'lar zaten tanımlı — sorun token eksikliği değil,
**token'ların kullanılmaması**.

### 3.2 Kontrast: tekrar eden bir kalıp
Aynı hata beş yerde: **renkli zemin üzerine aynı renk ailesinden metin.**
- Profil "Bronz Lig" rozeti (turuncu/turuncu)
- Sonuç ekranı istatistik etiketleri (turuncu/turuncu)
- Sonuç ekranı yıldızları (turuncu/turuncu)
- Çark kutlama bandı (sarı/beyaz)
- Turnuva "Bot turnuva" çipi (sarı/sarı)
- Kategori kartlarında beyaz alt metin (hardal/beyaz)

`AppColors.toneOnSurface()` yardımcısı tam bu iş için yazılmış ama bu yerlerde
kullanılmamış.

### 3.3 Bileşen ailesi çakışması
`styled_button`, `bouncing_button`, `pressable_card`, `colorful_action_card`,
`app_panel`, `glass panel`, `CardType` enum'u (primary/secondary/info/glass) —
altı ayrı "tıklanabilir yüzey" ailesi var. Sonuç: aynı işlevdeki iki buton
farklı gölge, farklı radius, farklı basılma davranışı gösterebiliyor (giriş
ekranındaki yumuşak gölge vs sert offset gölge aynı kart içinde).

### 3.4 Boşluk: hep aynı yönde hata
Neredeyse her ekranda **alt %20–40 boş**: turnuva girişi, eşleşme, giriş
ekranı, profil adı kapısı, 2 şıklı quiz, mağaza sonu, liderlik. Buna karşılık
quiz'in 4 şıklı hali taşıyor. Yani düzenler sabit ölçülerle kurulmuş, içerik
miktarına göre esnemiyor.

### 3.5 İki dil paritesi
Arayüz çevirisi iyi: TR ve KU metinleri düzgün, taşma yok, Kurmancî
diakritikleri (î, ê, û, ş, ç) her yerde doğru render ediliyor. Sorun **veride**:
- Kategori adları çevrilmiyor (Dil ↔ Ziman aynı oturumda).
- Seviye adları çevrilmiyor (Destpêk, Bingeh, Navîn, Pêşketî, Mamoste).
- Oda adları otomatik Kurmancî üretiliyor.
- **Soru bankasında dil karışıyor** — en ciddisi.

### 3.6 Bilgi mimarisi
- 5 sekme + Yarış içinde 6 alt mod + Profil içinde 6 giriş = derin ama
  gezilebilir bir yapı. Genel olarak sağlam.
- Ama üç metrik (puan/XP/coin) ve iki rozet sistemi kullanıcı zihninde
  sadeleşmiyor.
- Öğrenme döngüsü (yanlışlar → tekrar) var ama "Tekrar edilecek: 0 / Toplam: 8"
  gibi mesajlarla kullanıcıya kapalı kalıyor.

### 3.7 Erişilebilirlik
- Semantik ağaç genel olarak dolu; butonların çoğunun etiketi var. İyi.
- Dil toggle butonları etiketsiz.
- Ana CTA'ların adları çift okunuyor ("Têkeve Têkeve").
- Seviye butonlarının etiketinde yıldız/ilerleme bilgisi yok.
- Joker çipleri 44pt dokunma hedefinin altında.

---

## 4. Öncelikli iş listesi

### P0 — Ürünün temel işini bozan
| # | Bulgu | Dosya | Efor |
|---|---|---|---|
| 1 | Quiz'de "Sonraki"/şıklar ekrana sığmıyor; sayaç işlerken scroll gerekiyor | `screens/quiz/`, `quiz_screen.dart` | Orta (1–2 gün) |
| 2 | Soru bankasında dil karışıklığı (KU soru + TR şıklar) | soru bankası + `tool/` denetimi | Orta — içerik işi |
| 3 | Düelloda 10 sn süre, uzun sorularla oynanamaz | `matchmaking_screen.dart` / düello ayarı | Küçük (yarım gün) |
| 4 | Profilde "Oyun: 0", puan/doğruluk sonuç ekranıyla uyuşmuyor | `data/`, `profile_screen.dart` | Küçük–orta |

### P1 — Belirgin UX/kalite kaybı
| # | Bulgu | Dosya | Efor |
|---|---|---|---|
| 5 | Kontrast hataları (Bronz Lig, sonuç istatistikleri/yıldızlar, çark bandı, turnuva çipi, kategori metinleri) — `AppColors.toneOnSurface` uygula | `profile/`, `quiz_result_screen.dart`, `spin_wheel_screen.dart`, `tournament_screen.dart`, `categories_tab.dart` | Küçük, çok noktalı |
| 6 | Kategori renklerini tek kaynaktan besle (liste = detay = düello = çip) | kategori modeli + `app_theme.dart` | Orta |
| 7 | Şık harflerinin kırmızı/yeşil renklerini nötrle | `screens/quiz/` | Küçük |
| 8 | Profil adı ekranında hata durumu girdi değişince temizlensin | `profile_name_gate_screen.dart` | Küçük |
| 9 | Kayıt ekranına geri butonu + inline doğrulama (snackbar yerine) | `sign_up_screen.dart` | Küçük |
| 10 | Kategori kartlarındaki boş alt bant | `categories_tab.dart` | Küçük |
| 11 | Mağazada kesilen açıklamalar + satın alma diyaloğunun buton düzeni | `shop_screen.dart` | Küçük |
| 12 | Liderlikte "senin sıran" satırı ekle | `leaderboard_screen.dart` | Küçük–orta |
| 13 | "Rozet Koleksiyonu" başlık taşması, iki rozet bölümünü birleştir | `profile/`, `badge_collection_section.dart` | Küçük |
| 14 | Ana sayfada açık tema CTA rengi marka turuncusuna dönsün | `app_theme.dart` / `home/` | Küçük |
| 15 | Alt kategori ikonlarını içerikle eşleştir; kart watermark'ını kırp | `subcategory_screen.dart` | Küçük |
| 16 | Seviye ekranında sticky app bar; yıldız anlamını netleştir/etiketle | `level_screen.dart` | Küçük–orta |
| 17 | Kategori ve seviye adlarını çevir (Dil↔Ziman, Destpêk vb.) | `l10n/`, kategori modeli | Orta |
| 18 | Misafir hesabı için "hesabını kaydet" akışı + çıkışta veri kaybı uyarısı | `profile_screen.dart`, `auth_provider.dart` | Orta |
| 19 | "Hesabımı Sil" ayarların en altına | `settings_screen.dart` | Çok küçük |
| 20 | Yanlış cevaptan sonra kısa açıklama alanı | soru modeli + `quiz/`, `review` | Orta — içerik gerektirir |

### P2 — Cila
| # | Bulgu | Efor |
|---|---|---|
| 21 | Giriş ekranı açılış animasyonunu 2000 ms'den ~600 ms'ye indir | Çok küçük |
| 22 | Google butonu ile e-posta butonu arasında hiyerarşi kur; tek gölge dili seç | Küçük |
| 23 | Boş alt alanları doldur (turnuva geçmişi, eşleşme istatistikleri) veya düzenleri dikeyde dengele | Orta |
| 24 | Mağaza paletini marka paletine çek; 25–50c aralığında giriş ürünü ekle | Orta |
| 25 | Avatar renklerini marka paletinden seçilen sınırlı bir kümeye bağla | Küçük |
| 26 | Header'lara safe-area padding | Küçük |
| 27 | Ayarlar dişlisini tema için güneş/ay ikonuna çevir | Çok küçük |
| 28 | Dil toggle'ına semantik etiket; CTA'larda çift okuma sorununu gider | Küçük |
| 29 | "Hemen oyna" kartına kenarlık/zemin farkı ver | Çok küçük |
| 30 | Turnuva bracket'ında yatay scroll göstergesi | Küçük |
| 31 | Çark durduğunda dilim rakamları dik kalsın | Küçük |
| 32 | Profil sekmesi yüklenirken skeleton göster | Küçük |
| 33 | Roj maskotunu onboarding ve boş durumlarda kullan | Orta |
| 34 | Tablet genişliğinde iki sütunlu düzen (şu an tek sütun ortalanıyor) | Orta |

---

## 5. Canlı doğrulanamayan ekranlar

Bu gezintide açılamayan veya veri olmadığı için içeriği görünmeyen ekranlar —
bulgular bunları kapsamıyor:

- `learning_screen.dart` (Öğrenme sekmesi/akışı)
- `review_screen.dart` (SM-2 tekrar oturumu — tekrar edilecek soru 0 olduğu için)
- `favorite_questions_screen.dart` (kaydedilmiş soru yoktu)
- `story_screen.dart`
- `friends_screen.dart`
- `avatar_editor_screen.dart`
- `suggest_question_screen.dart`
- `level_placement_screen.dart` (seviye tespit sınavı)
- `contest_screen.dart` (Günün Yarışması)
- `splash_screen.dart` (web'de görülmedi)
- Turnuva maç akışı (bracket'tan sonrası)
- Paylaş kartı (`share_result_card.dart`)

---

## 6. Genel değerlendirme

Bu uygulamanın sorunu eksiklik değil, **kararlılık**. İçerik var, akışlar var,
iki dil var, iki tema var, boş durumlar bile yazılmış. Eksik olan tek bir görsel
otorite: hangi turuncu, hangi yeşil, hangi buton, hangi gölge, hangi seçili
rengi.

En yüksek getirili üç iş, sırayla:

1. **Quiz ekranını yeniden düzenle** (P0 #1). Bu ürünün kalbi ve şu an
   kullanıcıyı zorluyor. Soru metnini uzunluğa göre ölçekleyen, şık listesini
   kaydırılabilir yapan ve "Sonraki"yi ekranın altına sabitleyen bir düzen.
2. **Tek bir renk otoritesi kur.** Kategori renklerini tek kaynağa bağla,
   `toneOnSurface`'i kontrast hatalarına uygula, "seçili" rengini turunculaştır,
   mağaza ve avatar renklerini palete çek. Tek başına uygulamayı bir kademe
   yukarı taşır.
3. **Soru bankasını dil ve tekrar açısından denet.** KU/TR karışan sorular,
   tekrarlanan sorular ve "Di gotûbêja dersê de..." kalıbının aşırı kullanımı,
   ürünün en çok bakılan içeriğinde kalite hissini düşürüyor.

Bu üçü yapıldığında ZanKurd, "iyi düşünülmüş ama dağınık" konumundan
"cilalı" konumuna geçer.

---

## 7. Uygulama durumu (2026-07-22)

Bulgular `ux/live-review-fixes` dalında uygulandı. Her düzeltme kendi
commit'inde, gerekçesi kodda yorum olarak, davranışı testle kilitli.
**671 test geçiyor, `dart analyze` temiz.**

### Denetim sırasında düzelttiğim kendi hatalarım

Uygulama aşamasında raporun iki tespitinin **yanlış** olduğu ortaya çıktı:

- **"Düelloda soru başına 10 saniye"** — yanlış. Düello 20 saniye
  (`matchmaking_screen.dart:463`, 2026-07-21 tarihli bilinçli bir karar).
  Zamanlayıcı halkasını geri sayımın ortasında yakalamışım. Yerine gerçek bir
  tutarsızlık bulundu ve düzeltildi: `play_hub` 15 sn seçeneği sunuyordu ama bu
  değer `GameRoom.allowedSecondsPerQuestion` içinde yok.
- **"Soru 1 ile Soru 4 birebir aynı"** — kısmen yanlış. Bankada birebir
  tekrarlanan gövde yok; ama aynı ipucu + aynı doğru cevap farklı şablon
  önekleriyle 483 kümede **1070 kez** tekrarlanıyor. Yani sorun gerçek,
  ölçeği raporda yazdığımdan büyük.

### Ölçülen kapsam (yeni bilgi)

`tools/audit_question_language_mix.py` ile:
- 2347 sorunun **320'sinde (%13,6)** gövde/şık dili ayrışıyor
  (Muzîk 74, Dîrok 73, Edebiyat 68, Cografya 50, Çand 46, Siyaset 6, Paradigma 3)
- Ziman/Rêziman çeviri alıştırmaları haklı olarak muaf
- 2347 sorunun **800'ü** yalnız iki şablon önekinden geliyor

### Uygulananlar

| Rapor maddesi | Ne yapıldı |
|---|---|
| P0-1 Quiz taşması | Portrait düzeni üç bölgeye ayrıldı; joker + "Piştre" ekrana sabitlendi. SnackBar'lar barı örtmesin diye yukarı alındı. |
| P0-2 Dil karışıklığı | `QuestionLanguagePolicy` + cırcır testi (taban 320, yalnız azalabilir) + denetim aracı. Çeviri işi editöryel. |
| P0-3 Süre | UI'daki 15 sn seçeneği modelin izinli kümesine bağlandı. |
| P0-4 "Oyun: 0" | Karo `roomsPlayed` yerine cevaplanan soru sayısını gösteriyor; sıralama eşiği de düzeltildi. |
| P1-A Kontrast (6 nokta) | `AppColors.heroScrim()` ve `readableAccent()` eklendi; altın bantta koyu mürekkep; kategori metinlerine gölge. Eşikler `contrast_policy_test` ile ölçülüyor. |
| P1-B Kategori renkleri | Renk sıradan değil **kategori adından** geliyor (`CategoryVisuals`). Siyaset ikonu terazi oldu. |
| P1-C Doğrulama | `autovalidateMode`, hata renkli SnackBar, kayıtta ilk adımda geri butonu, şık harflerinden kırmızı/yeşil kaldırıldı. |
| P1-D Düzen | Rozet başlığı taşması, mağaza kesik açıklamaları + diyalog buton merdiveni, liderlikte "senin sıran" satırı. |
| P1-E Dil/hesap | Oda kategori adı çevrildi, `LevelNames` eklendi, misafir çıkışına veri kaybı uyarısı, "Hesabımı Sil" en alta. |
| P2 Cila | Giriş animasyonu 2000→900 ms, dil toggle'ına semantik etiket, "Hemen oyna" kartına afordans. |

### Eklenen koruma testleri

`contrast_policy_test`, `category_color_identity_test`,
`answer_option_color_semantics_test`, `question_language_policy_test`,
`leaderboard_my_rank_test`, `profile_stats_test`,
`profile_name_gate_validation_test` ve `play_hub_room_duration_test`
genişletmesi.

Not: kontrast testi ilk denemedeki değerlerimin (scrim %26 → 4,07:1;
lightness 0,34 → 4,34:1) AA altında kaldığını yakaladı; değerler ölçüme
göre düzeltildi.

### Yapılmayanlar

- **320 sorunun çevirisi** — editöryel iş; kod tarafı sayının artmasını
  engelliyor, azaltma içerik ekibinde.
- **1070 etkin tekrar sorunun ayıklanması** — aynı şekilde içerik kararı.
- **Sonuç ekranı puanı ile profildeki "Toplam Puan" farkı** — sunucu
  toplaması (`total_score`) ile ilgili; yerelde doğrulanamadı, tahminle
  değiştirilmedi.
- **P2'nin kalan maddeleri** (mağaza paleti, avatar renkleri, tablet iki
  sütun, turnuva bracket yatay kaydırma, boş alt alanlar) — görsel yön
  kararı gerektiriyor.
