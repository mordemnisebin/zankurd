# ZanKurd Antigravity Design Handoff

## Karar

Secilen yon: **C - Kulturel modern**.

ZanKurd siradan bir quiz uygulamasi gibi degil; Kurmanci dil, kultur ve bilgi hissini modern, sicak ve premium bir uygulama diliyle tasimali. Tasarim oyunlasmis kalmali ama ana karakteri sadece neon/arcade olmamali. Kultur, ogrenme ve yarismayi dengeli tasiyan bir gorsel sistem hedeflenmeli.

## Tasarim Ilkeleri

- Ana his: sicak, ozgun, guven veren, modern.
- Renkler: koyu bordo/kahveye bogulmadan; krem, sicak beyaz, derin yesil, mercan, altin ve kontrollu pembe vurgu.
- Motif: sade geometrik izler, gunes/roj, kitap, dag, govend, kilim benzeri ince patternler. Bunlar dekoratif ama metni ezmeyecek opaklikta olmali.
- UI dili: kartlar daha az rastgele gradient, daha cok iyi tanimlanmis yuzey sistemi. Hero ve quiz aksiyonlari daha canli olabilir.
- Tipografi: buyuk basliklarda guclu, govde metinlerinde cok okunakli. Kucuk ekranlarda metin tasmasi kabul edilmez.
- Komponentler: ikon rozetleri, seviye/coin/streak chipleri, ilerleme halkalari, sade bottom nav.
- Denge: Quiz ekranlari enerjik; ders, profil, ayarlar daha sakin.

## Yenilenecek Ekran Gruplari

1. AppShell ve genel tema
   - Ortak renk tokenlari ve yuzey stilleri netlestir.
   - `AppPanel`, `GlassPanel`, `StyledButton`, `StyledInput` gibi ortak komponentleri tek gorsel dile yaklastir.
   - Bottom navigation daha zarif, daha az plastik gorunmeli.

2. Onboarding ve auth
   - Ilk izlenim burada. Kulturel modern hero, logo, kisa mesaj ve dil secimi daha premium olmali.
   - Auth ekranlari koyu ve agir gorunmek yerine sicak, ferah ve guvenilir olmali.

3. Home
   - HomeHeader, hero card, quick play grid ve daily missions yeniden ele alinmali.
   - Ana sayfa "bugun ne yapacagim?" sorusuna net cevap vermeli.
   - 1V1, gunun yarismasi, dersler ve turnuva dengeli gorunmeli.

4. Quiz ve sonuc
   - Mevcut son polish korunabilir ama C yonune daha iyi uydurulmali.
   - Soru paneli, cevap kartlari, jokerler, skor ve sonuc ekrani tek bir yarismaci ama kulturel karakterli dile cekilmeli.

5. Learning / Categories
   - Bu ekranlar uygulamanin egitim kimligini tasimasi gereken yerler.
   - Kategoriler sadece renkli kutular degil; her kategoriye ikon, kisa aciklama, ilerleme ve ustalik hissi verilmeli.

6. Profile / Leaderboard / Social
   - Profil bir "oyuncu kimligi" gibi hissettirmeli: avatar, unvan, seviye, rozetler, ilerleme.
   - Leaderboard daha prestijli ama okunakli olmali.
   - Friends ve tournament sosyal/rekabet hissini guclendirmeli.

## Uygulama Sirasi

Buyuk refactor yapma. Kucuk, test edilebilir adimlarla ilerle:

1. Ortak theme/component audit yap.
2. Yeni gorsel tokenlari ve 2-3 ortak yardimci komponent oner.
3. Once Home + AppShell yenile.
4. Sonra Quiz + Result yenile.
5. Sonra Learning + Categories yenile.
6. Sonra Profile + Leaderboard + Friends/Tournament yenile.
7. Her adimdan sonra:
   - `dart analyze`
   - ilgili widget testleri
   - UI degisikligi varsa Flutter web/Playwright veya manuel ekran kontrolu

## Dikkat Edilecek Proje Kurallari

- Kod Flutter/Dart.
- Ana app: `zankurd_mobile`.
- Repository pattern ve Supabase davranislarina dokunma.
- Coin sistemi sunucu otoriter; client tarafinda keyfi coin ekleme yolu acma.
- Buyuk refactor yapma.
- Kurmanci metinlerde karakter ve anlam dogruluguna dikkat et.
- Windows ortaminda `flutter analyze` yerine `dart analyze` kullan.
- UI degisikliginde ekran tasmasi, buton tasmasi ve okunabilirlik mutlaka kontrol edilmeli.

## Antigravity Icin Prompt

Asagidaki prompt'u Antigravity IDE'ye ver:

```text
Bu projede ZanKurd Mobile Flutter uygulamasinin tum ekran tasarimini daha profesyonel, cekici ve modern hale getirmek istiyorum.

Secilen tasarim yonu: "Kulturel modern".

Hedef:
- ZanKurd siradan bir quiz uygulamasi gibi degil; Kurmanci dil, kultur ve bilgi hissini modern, sicak ve premium bir uygulama diliyle tasimali.
- Tasarim oyunlasmis kalmali ama sadece neon/arcade olmamali.
- Kultur, ogrenme ve yarismayi dengeli tasiyan bir gorsel sistem kurulmasi gerekiyor.

Oncelik:
1. Once mevcut mimariyi ve tasarim komponentlerini incele:
   - lib/src/theme/app_theme.dart
   - lib/src/widgets/app_panel.dart
   - lib/src/widgets/glass_panel.dart
   - lib/src/widgets/styled_button.dart
   - lib/src/widgets/styled_input.dart
   - lib/src/screens/app_shell.dart
   - lib/src/screens/home_screen.dart
   - lib/src/screens/home/*
   - lib/src/screens/quiz_screen.dart
   - lib/src/screens/quiz/*
   - lib/src/screens/learning_screen.dart
   - lib/src/screens/categories_tab.dart
   - lib/src/screens/profile_screen.dart
   - lib/src/screens/leaderboard_screen.dart

2. Dosya degistirmeden once kisa bir tasarim analizi ve uygulama plani cikar.

3. Buyuk refactor yapma. Kucuk, guvenli ve test edilebilir adimlarla ilerle.

Tasarim ilkeleri:
- Ana his: sicak, ozgun, guven veren, modern.
- Renkler: krem/sicak beyaz yuzeyler, derin yesil, mercan, altin, kontrollu pembe vurgu.
- Motif: roj/gunes, kitap, dag, govend, kilim benzeri cok dusuk opaklikli geometrik izler.
- Kartlar daha dengeli ve premium olmali; gradientler rastgele degil, anlamli kullanilmali.
- Quiz ekranlari daha enerjik; ders/profil/ayarlar daha sakin olmali.
- Metin okunabilirligi ve mobil tasma sorunlari kritik.

Uygulama sirasini su sekilde oner:
1. Ortak tema ve komponent dili
2. Home + AppShell
3. Quiz + Quiz Result
4. Learning + Categories
5. Profile + Leaderboard
6. Friends + Tournament + Shop

Her uygulama adimindan sonra:
- dart analyze calistir
- ilgili widget testlerini calistir
- UI degisikligi varsa Flutter web veya uygun ekran kontrolu yap

Notlar:
- Supabase/repository davranisina dokunma.
- Coin sistemi server-authoritative; client coin ekleme yolu acma.
- Kurmanci stringlerde karakter ve anlam dogruluguna dikkat et.
- Windows ortaminda flutter analyze yerine dart analyze kullan.
```

