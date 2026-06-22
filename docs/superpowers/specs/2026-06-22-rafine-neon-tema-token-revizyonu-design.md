# Rafine Neon — Tema/Token Revizyonu (Design Spec)

- **Tarih:** 2026-06-22
- **Kapsam:** `zankurd_mobile` tasarım token'ları ve ortak bileşen davranışları
- **Yön:** "Saf B — Rafine Neon" (refero.design ilhamı; mevcut kozmik neon kimliğini cilalama)
- **İlham kaynağı:** [styles.refero.design](https://styles.refero.design/) — AI-okunabilir DESIGN.md tasarım sistemleri (Linear "midnight command deck" disiplini referans alındı; Duolingo'nun oyunsu öğeleri bilinçli olarak kapsam dışı bırakıldı)

## Amaç

Mevcut tema zaten olgun (neon mor/pembe/turuncu gradient, koyu kozmik zemin `#0F0C20`, Rubik, glassmorphism, kategori gradientleri). Sorun **tutarsızlık ve görsel gürültü**: çok sayıda rakip parlak renk aynı anda dikkat çekiyor, `w900` her yerde, kart/buton stilleri ekrandan ekrana değişiyor. Bu revizyon sıfırdan tasarım değil; **mevcut kimliği net bir hiyerarşiye oturtup her ekranda tutarlı uygulamaktır.**

## Tasarım İlkeleri

1. Mevcut marka kimliğini koru — koyu kozmik zemin + neon aksanlar kalır.
2. Renk = anlam. Her renk tek bir role hizmet eder; dekoratif çoğulluk kaldırılır.
3. Tutarlılık > yenilik. Var olan helper'lar (`cardDecoration`, `cardShadow`, `shadow3D`) her ekranda tek tip uygulanır.
4. YAGNI — layout değişmez, yeni ekran/konfeti/3D buton eklenmez.

## 1. Renk Sistemi

Net rol hiyerarşisi kurulur:

| Rol | Renk / Token | Kullanım | Kural |
|-----|--------------|----------|-------|
| Primary | `accentGradient` (`#FF4B91`→`#FF7B54`) | Ana CTA, marka vurgusu | Ekranda en fazla 1 baskın primary öğe |
| Secondary | `secondaryAccent` `#6F61C0` (mor) | İkincil aksiyon, başlık gradientleri | — |
| Ödül | `gold` `#FFD23F` | **Yalnızca** coin / ödül / streak | Başka bağlamda kullanılmaz |
| Bilgi/ipucu | `cyan` `#00F0FF` | Nadir bilgi vurgusu (ör. joker ipucu) | "Emekli" — yaygın kullanımı kaldırılır |
| Doğru | `correct` `#00E676` | Yalnızca doğru cevap geri bildirimi | Semantik, sabit |
| Yanlış | `wrong` `#FF1744` | Yalnızca yanlış cevap geri bildirimi | Semantik, sabit |

**Yüzey kademeleri** net ayrışacak şekilde kullanılır (mevcut değerler korunur, tutarlı uygulanır):
`bgDeep #080711` < `bg #0F0C20` < `surface #16132D` < `surfaceHi #221E42`. Kartlar zeminden gölge + ince border ile ayrışır; iç içe yüzeyler bir kademe yukarı çıkar.

**Açık tema** aynı disiplinle güncellenir: aynı rol hiyerarşisi, açık paletin (`lightBg`/`lightSurface`/...) mevcut değerleriyle. Yeniden icat yok.

## 2. Tipografi

Rubik korunur. Ağırlık ölçeği sadeleştirilir (şu an her yerde `w900`):

| Stil | Ağırlık | Kullanım |
|------|---------|----------|
| Display / headlineSmall | `w800` | Ekran başlıkları, hero |
| Title (titleLarge/Medium) | `w700` | Kart başlıkları, bölüm başlıkları |
| Body (bodyLarge/Medium/Small) | `w400`–`w500` | Gövde metni |
| Label | `w600` | Buton/etiket metni |

`letterSpacing` ve `height` mevcut değerleri korunur. Kürtçe/Türkçe karakterlerde okunurluk doğrulanır.

## 3. Butonlar & Kartlar

- **Kartlar:** Tüm kartlar `AppTheme.cardDecoration` / `cardShadow` üzerinden çizilir. Ekrandan ekrana farklı elle yazılmış dekorasyonlar bu helper'a indirgenir. Standart radius `cardRadius` (20), iç öğeler `cardRadiusSmall` (12).
- **Ana CTA:** Temiz dolgun gradient buton (`accentGradient`), `FilledButton` teması üzerinden tutarlı padding/radius. Düz renkli alt-gölge ("3D" Duolingo efekti) **eklenmez**.
- **Tıklanabilir kartlar:** Hafif basılma geri bildirimi — `scale 0.97` + ripple. Bu bir polish; abartılı animasyon değil. (Mevcut tappable kartlarda tutarlı bir `InkWell`/`AnimatedScale` sarmalayıcı.)
- **İkincil butonlar:** Düz outline (`outlinedButtonTheme`) korunur.

## 4. Kategori Karoları

- Mevcut `categoryGradients` listesi ve `categoryGradient(index)` korunur.
- Kontrast standartlaşır (her gradient üzerinde beyaz metin/ikon okunur).
- Her kategoriye **sabit ikon** eşlenir → tarama hızlanır:

| Kategori | İkon (öneri) |
|----------|--------------|
| Ziman | dil / `language` |
| Çand | tiyatro maskesi |
| Dîrok | saat/tarih |
| Edebiyat | kitap |
| Cografya | küre/harita |
| Muzîk | nota |
| Siyaset | kürsü/bayrak |
| Paradigma | beyin/fikir |

İkon eşlemesi tek bir yerde (ör. kategori config) tutulur; home grid ve categories tab aynı kaynaktan okur.

## 5. Kapsam Dışı (YAGNI)

- Ekran düzenleri (layout) değişmez.
- Yeni ekran eklenmez.
- Konfeti / kutlama mikro-animasyonları, 3D alt-gölgeli butonlar **eklenmez** (saf B kararı).
- Renk paleti hex değerleri büyük ölçüde korunur; revizyon **kullanım disiplini** üzerine, yeni palet icadı değil.

## Etkilenen Dosyalar (ön görü)

- `lib/src/theme/app_theme.dart` — token rolleri, tipografi ölçeği, helper netleştirme
- Kategori ikon kaynağı (yeni veya mevcut config; ör. `lib/src/config/subcategory_config.dart` yakınında)
- Kart/buton kullanan ekranlar — elle yazılmış dekorasyonların helper'a indirgenmesi (home kartları, quiz, profil, kategoriler vb.)

Kesin dosya listesi ve sıralama uygulama planında netleşecek.

## Başarı Kriterleri

- `dart analyze` temiz (CLAUDE.md: `flutter analyze` LSP nedeniyle kullanılmaz).
- `flutter test` geçer (mevcut test sayısı korunur/artar).
- Açık ve koyu temada her renk rolü okunur ve tutarlı.
- Aynı bileşen (kart/buton/kategori karosu) tüm ekranlarda görsel olarak aynı.
