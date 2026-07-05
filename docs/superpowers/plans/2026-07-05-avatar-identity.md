# Avatar + Unvan Vitrini Uygulama Planı (Faz B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Oyuncuya seçilebilir avatar (16 ikon × 8 renk / fotoğraf), kazanılan çerçeveler ve rakiplerin gördüğü mastery unvan vitrini kazandırmak.

**Architecture:** Tek görsel kaynak `PlayerAvatar` widget'ı (url > ikon > harf önceliği); kimlik verisi `AvatarIdentity` modeli ile repository üzerinden akar (Mock=SharedPreferences, Supabase=profiles+storage, sessiz offline fallback). Çerçeve kazanımı yerel saf fonksiyon; seçim sunucuya kozmetik kolon olarak yazılır. Canlı DB migration'ı ayrı SQL dosyası olarak hazırlanır ve KULLANICI ONAYINDAN SONRA uygulanır.

**Tech Stack:** Flutter, image_picker (yeni bağımlılık, yalnız foto seçimi), Supabase profiles+storage.

**Görev sırası:** 1 model+presets → 2 çerçeve mantığı → 3 PlayerAvatar → 4 repository → 5 editör ekranı → 6 vitrin yüzeyleri → 7 SQL+canlı+dağıtım.

---

### Task 1: `AvatarIdentity` modeli + preset sabitleri

**Files:**
- Create: `zankurd_mobile/lib/src/models/avatar_identity.dart`
- Create: `zankurd_mobile/lib/src/config/avatar_presets.dart`
- Test: `zankurd_mobile/test/avatar_identity_test.dart`

- [ ] Test: (a) `AvatarIdentity.fromJson/toJson` gidiş-dönüş; (b) bilinmeyen ikon kimliği `iconFor()`'da null döner; (c) preset listesi 16 ikon / 8 renk içerir ve kimlikler benzersizdir.
- [ ] Model: `class AvatarIdentity { final String? iconId; final String? colorHex; final String? photoUrl; final String? frameId; final String? showcaseTitle; }` + `copyWith`, `toJson`, `fromJson` (tüm alanlar nullable; boş kimlik = harf fallback).
- [ ] Presets: `const avatarIcons = <String, IconData>{ 'tembur': Icons.music_note_rounded, 'dengbej': Icons.mic_rounded, 'ciya': Icons.landscape_rounded, 'roj': Icons.wb_sunny_rounded, 'pirtuk': Icons.menu_book_rounded, 'newroz': Icons.local_fire_department_rounded, 'ster': Icons.star_rounded, 'pen': Icons.edit_rounded, 'cihan': Icons.public_rounded, 'mertal': Icons.shield_rounded, 'tac': Icons.workspace_premium_rounded, 'gul': Icons.local_florist_rounded, 'dar': Icons.park_rounded, 'cav': Icons.visibility_rounded, 'birusk': Icons.bolt_rounded, 'kupa': Icons.emoji_events_rounded }`; `const avatarColors = <String>['#E94560','#7C3AED','#2563EB','#10B981','#F59E0B','#EC4899','#0EA5E9','#F97316']`; yardımcılar `IconData? iconFor(String? id)`, `Color colorFrom(String? hex, {Color fallback})`.
- [ ] Test geç + `dart analyze` temiz + commit `feat(avatar): AvatarIdentity modeli ve preset seti`.

### Task 2: Çerçeve kazanım mantığı

**Files:**
- Create: `zankurd_mobile/lib/src/game/avatar_frames.dart`
- Test: `zankurd_mobile/test/avatar_frames_test.dart`

- [ ] Test: rozet 0 → boş küme; rozet 1 → {bronze}; rozet 5 → {bronze,silver}; herhangi kategoride correctCount ≥ 100 (Pispor) → +gold; ≥ 400 (Mamoste) → +mamoste; kombinasyonlar.
- [ ] Impl: `enum AvatarFrame { bronze, silver, gold, mamoste }` + `Set<AvatarFrame> unlockedFrames({required int unlockedBadgeCount, required Map<String,int> masteryCorrectByCategory})` — MasteryLevel eşiklerini `mastery_level.dart`'taki mevcut sabitlerden okur (100/400'ü kopyalama, sabitlere referans ver).
- [ ] Çerçeve görselleri: `frameColor(AvatarFrame)` (bronz #CD7F32, gümüş #C0C0C0, altın #FFC107, mamoste = AppTheme.violet degrade) — PlayerAvatar Task 3'te kullanır.
- [ ] Test geç + commit `feat(avatar): çerçeve kazanım mantığı`.

### Task 3: `PlayerAvatar` widget'ı

**Files:**
- Create: `zankurd_mobile/lib/src/widgets/player_avatar.dart`
- Test: `zankurd_mobile/test/player_avatar_test.dart`

- [ ] Test: (a) photoUrl doluysa Image ağaçta (test için `Image.network` yerine sahte `ImageProvider` enjeksiyonu: widget `ImageProvider Function(String url)? imageProviderFactory` parametresi alır, testte MemoryImage döndürülür); (b) photoUrl yok + iconId varsa Icon ağaçta; (c) ikisi de yoksa baş harf Text'i; (d) frameId doluysa halka dekorasyonlu dış Container.
- [ ] Impl: `PlayerAvatar({required double radius, String? photoUrl, String? iconId, String? colorHex, String? frameId, String? displayName, ImageProvider Function(String)? imageProviderFactory})`. Fotoğraf `ClipOval + Image(fit: cover, errorBuilder: ikon/harf fallback)`. Çerçeve: 3px halka + (radius ≥ 30 iken) sağ-alt köşede mini çerçeve ikonu.
- [ ] Test geç + commit `feat(avatar): PlayerAvatar widget'ı`.

### Task 4: Repository API

**Files:**
- Modify: `zankurd_mobile/lib/src/data/zankurd_repository.dart` (3 yeni metot imzası)
- Modify: `zankurd_mobile/lib/src/data/mock_zankurd_repository.dart` (SharedPreferences impl)
- Modify: `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart` (profiles+storage impl, offline fallback)
- Test: `zankurd_mobile/test/avatar_repository_test.dart`

- [ ] Test (Mock üzerinden): updateAvatarIdentity → loadAvatarIdentity gidiş-dönüş; boş başlangıç null alanlı kimlik döner; uploadAvatarPhoto Mock'ta `mock://avatar` URL döner ve identity.photoUrl'e yazılır.
- [ ] Arayüz: `Future<AvatarIdentity> loadAvatarIdentity(); Future<void> updateAvatarIdentity(AvatarIdentity identity); Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType);`
- [ ] Mock: `zankurd.avatarIdentity` anahtarında JSON saklar.
- [ ] Supabase: load → `profiles.select('avatar_icon, avatar_color, avatar_url, avatar_frame, showcase_title')`; update → aynı kolonlara upsert; upload → `storage.from('avatars').uploadBinary('<uid>/avatar.jpg', bytes, upsert: true)` + `getPublicUrl`. Tüm metotlar try/catch ile `_offline`'a düşer (mevcut kompozisyon deseni).
- [ ] Test geç + tam `flutter test` regresyon + commit `feat(avatar): repository kimlik API'si`.

### Task 5: Avatar düzenleyici ekranı

**Files:**
- Create: `zankurd_mobile/lib/src/screens/avatar_editor_screen.dart`
- Modify: `zankurd_mobile/pubspec.yaml` (image_picker)
- Test: `zankurd_mobile/test/avatar_editor_test.dart`

- [ ] `flutter pub add image_picker` (sürümü pub'un seçtiği stable).
- [ ] Test: ikon seçimi önizlemeyi günceller; kilitli çerçeveye dokununca seçilmez + kilit snackbar'ı; unvan listesi yalnız kazanılmış mastery unvanlarını içerir; Kaydet repository.updateAvatarIdentity'yi doğru kimlikle çağırır (sahte repo ile).
- [ ] Impl: bölümler — önizleme, foto yükle/kaldır (image_picker `pickImage(source: gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85)` → bytes ≤ 2MB kontrolü → repository.uploadAvatarPhoto), ikon ızgarası (GridView 4 sütun), renk sırası, çerçeve sırası (`unlockedFrames` ile kilit durumu + koşul metni KU/TR), unvan dropdown (MasteryStore'daki `levelFor(category) != null` kategorilerden `'$unvan · $kategori'`; ilk seçenek 'Gizle'). Kaydet başarılıysa pop(true).
- [ ] Test geç + commit `feat(avatar): avatar düzenleyici ekranı`.

### Task 6: Vitrin yüzeyleri

**Files:**
- Modify: `zankurd_mobile/lib/src/models/player.dart` + `leaderboard_entry.dart` (opsiyonel avatar alanları: `avatarIcon, avatarColor, avatarUrl, avatarFrame, showcaseTitle`)
- Modify: `zankurd_mobile/lib/src/screens/profile_screen.dart:198` (başlık avatarı → PlayerAvatar + dokununca AvatarEditorScreen; dönüşte reload)
- Modify: `zankurd_mobile/lib/src/screens/leaderboard_screen.dart:351-500` (podyum + satır CircleAvatar'ları → PlayerAvatar; isim altında unvan etiketi)
- Modify: `zankurd_mobile/lib/src/screens/matchmaking_screen.dart:393,469` (iki taraf → PlayerAvatar + unvan)
- Modify: `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart` (leaderboard/oda oyuncu sorgularına yeni kolonlar; RPC dönmüyorsa null-güvenli)
- Test: mevcut leaderboard/profil widget testlerine avatar varlık kontrolleri eklenir
- [ ] Sorgular: `get_leaderboard` RPC'si eski sürümde yeni kolonları döndürmeyebilir → `row['avatar_icon'] as String?` null-güvenli okuma; migration view'ı güncelleyene kadar harf fallback çalışır.
- [ ] Test geç + tam regresyon + commit `feat(avatar): vitrin yüzeyleri (liderlik, 1v1, profil)`.

### Task 7: Migration + canlı + dağıtım

**Files:**
- Create: `zankurd_mobile/supabase/2026-07-05_avatar_identity.sql`

- [ ] SQL: 4 `alter table profiles add column if not exists`; `insert into storage.buckets (id, name, public) values ('avatars','avatars',true) on conflict do nothing;` + storage RLS politikaları (`auth.uid()::text = (storage.foldername(name))[1]` yazma, public okuma); leaderboard view/RPC'ye yeni kolonlar.
- [ ] KULLANICIDAN ONAY CÜMLESİ İSTE (üretim DB yazması — otomatik pilot bu adımı kapsamıyor, oturum kuralı).
- [ ] Onay sonrası uygula + doğrula (kolonlar + bucket + politika listesi).
- [ ] Web görsel QA (editör akışı + liderlikte avatar) → release build → FTP dağıtım → canlı smoke.
- [ ] Commit `docs(supabase): avatar identity migration` + push yedek dala.
