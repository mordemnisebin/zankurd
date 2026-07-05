# Avatar + Unvan Vitrini — Tasarım (Faz B)

**Tarih:** 2026-07-05
**Faz:** B / 4 (onaylı yol haritası; Faz A canlıda)
**İlham:** TRT Bil Bakalım'ın rozet/çerçeve/avatar kişiselleştirmesi.
**Durum:** Kullanıcı yol haritasını ve fotoğraf yükleme dahil avatar
modelini onayladı; otomatik pilot yetkisi var.

## Amaç

Oyuncunun görsel kimliği bugün tek harflik bir daireden ibaret; kazanılan
mastery unvanları (Xwendekar/Pispor/Mamoste) profil sayfası dışında hiçbir
yerde görünmüyor. Bu faz oyuncuya seçilebilir bir yüz (hazır set veya
fotoğraf), kazanılmış bir çerçeve ve rakiplerin de göreceği bir unvan verir
— rekabet ekranlarına "kimlik" katar.

## Kapsam

### 1. Veri modeli (canlı DB migration — onay gerektirir)
`public.profiles` tablosuna 4 kozmetik kolon:
- `avatar_icon text` — hazır setten ikon kimliği (ör. `tembur`); null = harf
- `avatar_url text` — yüklenen fotoğrafın public URL'i; doluysa ikondan öncelikli
- `avatar_frame text` — kazanılan çerçeve kimliği (`bronze|silver|gold|mamoste`); null = çerçevesiz
- `showcase_title text` — vitrin unvanı, ör. `Mamoste · Dîrok`; null = gizli

Bunlar ekonomik değil kozmetik alanlardır; mevcut "kendi profil satırını
güncelleyebilir" RLS'i yeterlidir (display_name ile aynı yol). Skor/coin
guard'larına dokunulmaz.

**Storage:** `avatars` bucket'ı — public okuma; yazma yalnız
`auth.uid()` ile eşleşen klasör yoluna (`<uid>/avatar.jpg`). 2MB üst
sınır istemcide doğrulanır. Not: kullanıcı fotoğrafı diğer oyunculara
görünen UGC'dir; Play politikası gereği ileride bir "bildir" mekanizması
gerekebilir — bilinen risk olarak kabul edildi (kullanıcı onayladı),
spec'e gelecek işi not düşüldü.

### 2. Hazır avatar seti (asset eklenmez)
16 kültürel temalı Material ikonu × 8 renk (mevcut `AppTheme` paleti):
tembûr (music_note), dengbêj (mic), dağ (landscape), güneş (wb_sunny),
kitap (menu_book), Newroz ateşi (local_fire_department), yıldız, kalem
(edit), dünya (public), kalkan (shield), taç (workspace_premium), çiçek
(local_florist), ağaç (park), göz (visibility), şimşek (bolt), kupa
(emoji_events). İkon kimlikleri `avatar_presets.dart`'ta sabit listede.

### 3. Çerçeveler (kazanım mantığı yerel, gösterim sunucudan)
- `bronze`: herhangi bir rozet açıldığında
- `silver`: 5+ rozet
- `gold`: herhangi bir kategoride Pispor
- `mamoste`: herhangi bir kategoride Mamoste
Saf fonksiyon: `unlockedFrames(int badgeCount, MasteryStore)` →
`Set<AvatarFrame>`. Kendi cihazında hesaplanır; seçilen çerçeve
profiles.avatar_frame'e yazılır (rakip cihazlar oradan okur). İstemci
kilidi: kazanılmamış çerçeve seçilemez (UI'da kilit ikonu).

### 4. `PlayerAvatar` widget'ı (tek kaynak)
Öncelik: `avatar_url` fotoğrafı > `avatar_icon`+renk > baş harf+renk.
Çerçeve, dairenin etrafında renkli halka + köşe rozeti. Boyut parametrik
(liderlik satırı 40, podyum 64, profil 68, 1v1 96). Fotoğraf yükleme
başarısız/URL kırıksa zarifçe ikon/harf fallback'ine düşer
(`errorBuilder`).

### 5. Avatar düzenleyici ekranı
Profil → avatar'a dokun → `AvatarEditorScreen`:
- Üstte canlı önizleme (PlayerAvatar, seçili çerçeveyle)
- "Fotoğraf yükle" butonu (image_picker; galeri; 2MB sınır; yüklenince
  fotoğraf modu aktif, "fotoğrafı kaldır" ile ikon moduna dönüş)
- İkon ızgarası (16), renk sırası (8), çerçeve sırası (kilitliler gri +
  kilit ikonu ve kazanım koşulu metni)
- Unvan seçici: kazanılmış mastery unvanları listesi (MasteryStore'dan;
  `Pispor · Ziman` biçiminde) + "gizle" seçeneği
- Kaydet → repository.updateAvatarIdentity(...)

### 6. Vitrin yüzeyleri
- **Liderlik tablosu**: satırlarda ve podyumda PlayerAvatar + isim
  altında küçük unvan etiketi (varsa)
- **1v1 eşleştirme ekranı**: iki tarafta PlayerAvatar (rakibinki
  profilden), isim altında unvan
- **Düello skor başlığı (quiz)**: mini avatarlar
- **Sonuç ekranı**: kendi avatarın skor kartında
- **Profil başlığı**: harf yerine PlayerAvatar + unvan rozeti
Sunucu tarafı: leaderboard sorgusu/görünümü yeni kolonları da döndürür
(migration'da view güncellenir); oda/eşleşme oyuncu satırları profiles
join'inden alır.

### 7. Repository API
`ZanKurdRepository`'ye:
- `Future<AvatarIdentity> loadAvatarIdentity()` (kendi)
- `Future<void> updateAvatarIdentity(AvatarIdentity identity)`
- `Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType)`
Mock: SharedPreferences'ta saklar (test/offline). Supabase: profiles +
storage; hata durumunda sessiz offline fallback (mevcut desen).
`LeaderboardEntry` ve `Player` modellerine opsiyonel avatar alanları
eklenir (geriye dönük uyumlu, null-güvenli).

## Yeni bağımlılık
`image_picker` (resmi Flutter paketi) — yalnız fotoğraf seçimi için.
Kırpma paketi EKLENMEZ; kare görünüm `BoxFit.cover` ile sağlanır.

## Test planı
- Birim: `unlockedFrames` eşikleri; `AvatarIdentity` (de)serileştirme.
- Widget: PlayerAvatar öncelik sırası (url>icon>harf); editörde kilitli
  çerçeve seçilememesi; unvan seçicinin yalnız kazanılmışları listelemesi.
- Regresyon: mevcut 258 test + `dart analyze` temiz.

## Kapsam dışı
- Fotoğraf moderasyonu/bildirme akışı (bilinen risk, ileriye not)
- Çerçeve/ikon satın alma (coin mağazasına bağlanmaz — kozmetikler
  yalnız kazanımla açılır)
- Sonuç ekranının genel yeniden tasarımı
