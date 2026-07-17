# Onaylı Mockup'lara Yeniden Hizalama — Uygulama Planı

Tarih: 2026-07-17
Kaynak: `zankurd_mobile/ÖRNEK TASARIM/` (11 onaylı mockup)
Süpersede eder: `2026-07-16-zankurd-total-ui-rebuild-design.md` (yanlış yön — açık gazete)

## 1. Kök Sorun

- Onaylanan 11 mockup'ın **hepsi koyu, sıcak, modern** (koyu yeşil yuvarlak
  kartlar, altın coin illüstrasyonları, fotoğraf avatarlar, renkli ikon
  çipleri, yuvarlak sans-serif font).
- Araya giren `2026-07-16` spec'i (satır 12, 71) bu koyu referansları
  **"açık Rojnameya Editorial gazete" sistemine çevirmeye** karar verdi.
  Bu karar mockup'larda **yoktu**; tamamen uydurma.
- Codex o spec'i sadık şekilde uyguladı → açık kâğıt, serif manşet, kart yok,
  illüstrasyon yok. Testler geçiyor ama **yanlış hedef**. "Ruhsuz/dağınık"
  hissi bundan.

## 2. Karar

Editoryal işi geri al. Sunum katmanını (yalnız `build()` yerleşimleri, tema,
paylaşılan widget'lar) **doğrudan 11 mockup'a göre** yeniden kur.
Repository / provider / model / servis / iş kuralları / joker / mastery /
coin RPC akışları **aynen korunur** (mockup sadece görünümü tanımlıyor).

Ana ilke: **Tüm uygulama tek koyu sistem.** "Açık ana + koyu quiz" ayrımı yok.

## 3. Tasarım Sistemi (mockup'lardan çıkarılan)

### Renk
- Zemin: `#0B0F0D` (neredeyse siyah, hafif yeşil)
- Yükseltilmiş kart: `#141C18` → `#18231D` (koyu yeşil, ~1px `#26332B` sınır)
- Seçili/vurgulu kart: yeşil tint `#183024` + `#347454` sınır
- Ana yeşil aksan: `#3DA968` (parlak zümrüt; metin/ikon/buton)
- Altın (coin/XP): `#E7B53C`
- Kırmızı (yanlış/yıkıcı/ana CTA bazen): `#E5533D`
- Birincil metin: `#F4F1E9` / ikincil: `#93A29A`
- Kategori ikon çipleri: her kategoriye sabit renk (Ziman=yeşil, Dîrok=kahve,
  Çand=mor, Civak=hardal, Cografya=teal, Zanist=lacivert) — mockup 4'teki
  eşleme birebir.

### Tipografi
- Mevcut `Rubik` kalır. **Serif YOK.** Mockup'lar yuvarlak/kalın sans kullanıyor.
- Manşet 26–30px w800; başlık 20–22px w700; gövde 14–16px; sayaç tabular.

### Şekil / yerleşim
- Kartlar **geri geliyor**: 16–20px yarıçap, koyu yüzey, ince sınır.
- Kategori/menü/liste satırı: sol renkli ikon çipi (12px radius) + başlık +
  alt açıklama + sağda değer/ok.
- Alt gezinme 5 sekme: Sereke/Mal, Kategorî, Oyun, Lîstik(Liderlik), Profîl —
  seçili sekme parlak yeşil dolu ikon.
- İlerleme çubukları: altın→yeşil gradyan (mockup 3, 10).

### İllüstrasyon
- Mockup'lardaki coin yığını, hazine sandığı, dağ, hediye kutusu, madalya,
  yıldız patlaması **gerekli**. Bunlar ekranın ruhu.
- Strateji: raster asset üretmek yerine önce mevcut asset'leri kontrol et
  (`assets/`), yoksa hedefli birkaç PNG/SVG üret (paket/coin/sandık/hediye/
  madalya/yıldız). Metin taşımaz; UI metni Flutter çizer. (Onay noktası — bkz §7)

## 4. Ekran → Referans Eşlemesi (30 yüzey)

| # | Ekran(lar) | Referans | Koyu | Not |
|---|---|---|---|---|
| 1 | Splash, Onboarding | 1 (17_26_26) | ✓ | Logo odak, koyu kapak |
| 2 | SignIn, SignUp, ProfileNameGate | 2 | ✓ | Tek sakin form, kart yığını yok |
| 3 | **HomeScreen** | 3 | ✓ | Masthead+selam, 3 metrik çip, zincir bar, "Dersê rojane" coin hero, Lîstika lez (Duel/Hevalan), Erka rojane, mini liderlik |
| 4 | CategoriesTab, Subcategory, Learning, Level, LevelPlacement, Story, FavoriteQuestions | 4 | ✓ | Arama + filtre chip + renkli ikon çipli liste satırları, %ilerleme, "N pirs" |
| 5 | **QuizScreen** + quiz widget'ları | 5 | ✓ | Üstte Ziman/sayaç/dairesel timer, ince turuncu bar, görsel soru, ikon çipli tek sütun şık, altta yeşil CTA. **A/B/C/D harf yerine ikon çip.** Jokerler korunur ama hiyerarşi bozulmadan |
| 6 | Doğru cevap durumu | 6 | ✓ | Yeşil tik patlaması + geri bildirim |
| 7 | Yanlış cevap + ReviewScreen | 7 | ✓ | Kırmızı X, doğru cevap yeşil, Tevgera/Zincir çift metrik kartı, Şîrove (açıklama+görsel), kırmızı CTA |
| 8 | **QuizResultScreen** | 8 | ✓ | 3 yıldız + %skor halkası, Encam, Rast/Nerast/Erj üç metrik, hazine bonus kartı, kırmızı "Dîsa" + outline "Mala vegere" |
| 9 | **LeaderboardScreen** | 9 | ✓ | Kupa başlık, dönem sekmeleri, madalya+fotoğraf sıralama, kendini yeşil vurgulu sabit alt satır |
| 10 | **ProfileScreen**, AvatarEditor, Settings | 10 | ✓ | Gold ringli fotoğraf avatar, Asta+XP gradyan bar, 3 stat kartı, ikon çipli menü satırları (Nîşan/Statistik/Heval/Ayarlar/Derketin) |
| 11 | FriendsScreen, ShopScreen | 11 (17_27_52) | ✓ | Arkadaş: sekme + davet kartı + online liste + takım CTA. Mağaza: sekmeler (Önerilen/Altın/Avatar/Tema/Diğer), "EN POPÜLER" paket hero, coin paket gridi, avatar/tema galerisi |
| + | Matchmaking, Room, Contest, Tournament, SpinWheel, PlayHub, Community | 9/10 dili | ✓ | Referansta yok → aynı koyu sistemle en yakın anlamlı düzen |

## 5. Paylaşılan Widget'lar (yeni koyu çekirdek)

Codex'in açık editoryal widget'ları (`zk_editorial_scaffold`,
`screen_identity_header` vb.) bu yön için uygun değil → koyu sisteme göre
yeniden yaz veya değiştir. Gerekli minimum set:

- `ZkScaffold` — koyu zemin + safe area + alt nav
- `ZkCard` — koyu yükseltilmiş yüzey (varsayılan sarmalayıcı)
- `ZkIconTile` — renkli yuvarlak-kare ikon çipi
- `ZkListRow` — ikon çipi + başlık + alt + trailing (kategori/menü/mağaza/arkadaş)
- `ZkMetricChip` — ikon + değer + etiket (home 3'lü, result 3'lü)
- `ZkProgressBar` — altın→yeşil gradyan
- `ZkPrimaryButton` — yeşil/kırmızı dolu ana eylem
- `ZkTabPills` — dönem/filtre sekme hapları
- `ZkAvatar` — gold ring destekli
- Mevcut `AppLogo` korunur (orijinal `assets/zankurd.webp`)

Tek kullanımlık soyutlama yok.

## 6. Korunacaklar (dokunulmaz)
- Tüm repository/provider/model/servis/controller
- Joker (spend_coins RPC), mastery, streak, XP, achievement, coin akışları
- Auth (misafir/Google/e-posta), dil seçimi, oda/matchmaking mantığı
- Soru bankası, iş kuralları, mevcut davranış testleri (yeniden skinlenecek)

## 7. Onay Gereken Noktalar (kod öncesi)
1. **İllüstrasyon:** Mockup'lardaki coin/sandık/hediye/madalya/yıldız/dağ
   asset'leri (a) üretilsin mi yoksa (b) sade ikon/gradyanla mı temsil edilsin?
   Ruh için (a) öneriliyor ama süre/asset üretimi ekler.
2. **Fotoğraf avatarlar:** Referanslar gerçek yüz fotoğrafı kullanıyor.
   Üretimde jenerik illüstre avatar seti mi, yoksa harf/renk avatar mı?
3. **Faz sırası:** Aşağıdaki sıralamayı onaylıyor musun?

## 8. Fazlama (her faz sonunda ekran görüntüsü + onay)
- **Faz 0:** Koyu tema + paylaşılan widget çekirdeği + alt nav (görünür temel)
- **Faz 1:** Home (mockup 3) — en görünür ekran, ruhu burada göster
- **Faz 2:** Quiz ailesi (5/6/7/8) — çekirdek deneyim
- **Faz 3:** Kategori/öğrenme ailesi (4)
- **Faz 4:** Liderlik + Profil + Ayarlar (9/10)
- **Faz 5:** Arkadaş + Mağaza (11)
- **Faz 6:** Giriş ailesi (1/2) + kalan oyun ekranları
- **Faz 7:** Doğrulama: dart analyze, flutter test, release web, 30 ekran görüntüsü, referansla yan yana kontrol

## 9. Doğrulama Kapıları
- `dart analyze` hatasız
- `flutter test` tam geçer (skinlenmiş testler dahil)
- Her ekran 390×844 gerçek içerikle görüntülenir ve **ilgili referansla yan
  yana** koyu/sıcak/kart/ikon-çip/illüstrasyon açısından eşleşir
- Açık gazete/serif/masthead artığı kalırsa teslim durur
