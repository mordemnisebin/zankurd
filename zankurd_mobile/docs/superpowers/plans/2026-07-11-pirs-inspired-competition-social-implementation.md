# Pirs-Inspired Competition and Social (Paket 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rekabet ve sosyal ekranları Pirs-inspired renk kimliklerine taşımak; bekleme/bağlantı durumlarını ayırmak ve 360 px'de oda kodu, oyuncu, podium ve aksiyon taşmalarını önlemek; mevcut realtime, polling, matchmaking ve navigation mantığını aynen korumak.

**Architecture:** Ekranların mevcut stateful yapısı, repository çağrıları, timer'ları ve handler'ları korunur; değişiklik yalnız mevcut widget ağaçlarının dekorasyon, tipografi ve responsive yerleşim katmanında yapılır. Kimlik renkleri doğrudan mevcut `AppTheme` token'larından alınır: 1vs1 `playPink`, oda/takım `playCyan`, liderlik/ödül `gold`, ana CTA `brandOrange`. Kilim yalnız hero yüzeyinde kalır; diğer yüzeyler ince border ve yumuşak gölge kullanır.

**Tech Stack:** Flutter, Dart, Material 3, Provider, flutter_test, Playwright CLI; yeni dependency yok.

## Global Constraints

- `_startMatchmaking`, `_pollMatchStatus`, `_cancelMatchmaking`, `_startSubscriptions`, `_startPolling`, `_pollPlayersOnce`, `_startGameHost` ve tüm repository/provider çağrıları değişmeyecek.
- Navigator/route hedefleri, `onTap`/`onPressed` callback gövdeleri, timer süreleri, stream abonelikleri ve Phase 2E-3C polling hotfix'i değişmeyecek.
- 1vs1 `AppTheme.playPink`; oda/takım `AppTheme.playCyan`; liderlik/ödül `AppTheme.gold`; ana CTA `AppTheme.brandOrange` kullanacak.
- Kalın glow/3D gölge yok; ince border ve düşük opaklıklı, blur'lü gölge kullanılacak.
- Kilim deseni yalnız hero yüzeylerinde kullanılacak.
- Light/dark aynı bilgi hiyerarşisini koruyacak; 360 px ve 1.3 text scale'de RenderFlex overflow olmayacak.
- Çalışma `codex/pirs-inspired-package-04` branch'inde, `.worktrees/pirs-inspired-package-04` worktree'sinde yapılacak.

---

### Task 1: Matchmaking ve 1vs1/Team Kimliği

**Files:**
- Modify: `lib/src/screens/matchmaking_screen.dart`
- Modify: `test/matchmaking_screen_test.dart`

**Interfaces:**
- Preserves: `_startMatchmaking`, `_pollMatchStatus`, `_cancelMatchmaking`, `_openCategoryPicker`, bütün `Navigator` çağrıları ve callback gövdeleri.
- Produces: `ValueKey('matchmaking-duel-card')`, `ValueKey('matchmaking-team-card')`, `ValueKey('matchmaking-waiting-state')` görsel test ankrajları.

- [ ] **Step 1: Başarısız görsel sözleşme testlerini yaz**

`test/matchmaking_screen_test.dart` içine 360 px testleri ekle: duel kart dekorasyon border'ı `AppTheme.playPink`, takım kartı `AppTheme.playCyan`; bekleme durumunda `matchmaking-waiting-state` bulunur ve `tester.takeException()` null kalır.

```dart
expect((tester.widget<Container>(find.byKey(const ValueKey('matchmaking-duel-card'))).decoration as BoxDecoration).border, isNotNull);
expect(find.byKey(const ValueKey('matchmaking-waiting-state')), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Testin key ve yeni renk sözleşmesi olmadığı için başarısız olduğunu doğrula**

Run: `flutter test test/matchmaking_screen_test.dart`

Expected: yeni key'ler bulunamadığı için FAIL.

- [ ] **Step 3: Yalnız görsel katmanı güncelle**

Seçim kartlarına ilgili key ve ince mod rengi border'ı ekle; 1vs1 vurgu/ikonunu `playPink`, takım/oda vurgu/ikonunu `playCyan` yap. Bekleme paneline key ekle; arama, bağlantı ve eşleşme bulundu metinlerini ayrı ikon/chip hiyerarşisiyle göster. CTA dolgusunu `brandOrange` yap; callback gövdelerini değiştirme. Uzun başlık ve alt metinlerde `maxLines: 2`, `overflow: TextOverflow.ellipsis`, kart satırlarında `Expanded` kullan.

- [ ] **Step 4: Odaklı testi geçir**

Run: `flutter test test/matchmaking_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/matchmaking_screen.dart test/matchmaking_screen_test.dart
git commit -m "ui: clarify matchmaking mode identities"
```

### Task 2: Oda Lobisi ve Oyuncu Durumları

**Files:**
- Modify: `lib/src/screens/room_screen.dart` (yalnız `build`, `_Pill`, `_PlayerTile` görsel widget'ları)
- Modify: `test/widget_test.dart` (mevcut room lobby testlerinin yanına)

**Interfaces:**
- Preserves exactly: satır 40-128 polling/subscription alanı, `_startGameHost`, `_navigateToQuiz`, `updateReady` ve tüm callback gövdeleri.
- Produces: `ValueKey('room-code')`, `ValueKey('room-player-tile')`, `ValueKey('room-connection-state')`.

- [ ] **Step 1: 360 px ve 1.3 text scale regresyon testini yaz**

Mevcut room test fixture'ını kullan; viewport'u `Size(360, 800)`, text scaler'ı `TextScaler.linear(1.3)` yap. Oda kodu ve oyuncu tile key'lerini doğrula, `tester.takeException()` için null bekle.

- [ ] **Step 2: Testi çalıştır ve eksik key/taşma nedeniyle FAIL olduğunu doğrula**

Run: `flutter test test/widget_test.dart --plain-name "room lobby fits 360px with scaled text"`

Expected: FAIL.

- [ ] **Step 3: Oda görselini playCyan kimliğine taşı**

Hero gradyanını `playCyan` tabanlı yap ve mevcut kilimi yalnız burada koru. Kod alanında `FittedBox(fit: BoxFit.scaleDown)` ve `SelectableText`/mevcut copy callback sözleşmesini koruyan key kullan. Liste güncelleniyor durumu `room-connection-state` key'li ayrı cyan status row olsun. Oyuncu tile'ına key, ince cyan border, isimde `maxLines: 1/ellipsis`, durum chip'inde tek satır ve skor kolonunda sabit minimum genişlik uygula. Hazır switch cyan, ana başlat CTA brandOrange olur; `onChanged` ve `onPressed` gövdeleri aynen kalır.

- [ ] **Step 4: Room regresyonlarını geçir**

Run: `flutter test test/widget_test.dart --plain-name "room lobby fits 360px with scaled text"`

Run: `flutter test test/widget_test.dart --plain-name "room lobby recovers via polling when realtime player list stays stale"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/room_screen.dart test/widget_test.dart
git commit -m "ui: refine responsive room lobby states"
```

### Task 3: Contest ve Tournament Ödül Hiyerarşisi

**Files:**
- Modify: `lib/src/screens/contest_screen.dart`
- Modify: `lib/src/screens/tournament_screen.dart`
- Modify: `test/contest_test.dart`
- Modify: `test/tournament_screen_test.dart`

**Interfaces:**
- Preserves: refresh timer, contest load/start/submit çağrıları, tournament state geçişleri ve navigation.
- Produces: `ValueKey('contest-hero')`, `ValueKey('tournament-hero')`, `ValueKey('tournament-primary-cta')`.

- [ ] **Step 1: Hero/CTA renk sözleşme testlerini yaz**

Contest ve tournament widget testlerinde hero dekorasyonunun `gold` kimliği taşıdığını, tournament CTA'nın `brandOrange` olduğunu ve 360 px'de exception oluşmadığını doğrula.

- [ ] **Step 2: Testlerin key/CTA rengi nedeniyle FAIL olduğunu doğrula**

Run: `flutter test test/contest_test.dart test/tournament_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Ödül ve aksiyon hiyerarşisini uygula**

Gold'u ödül, kupa, rank ve badge alanlarında tut; başlat/katıl ana CTA'larını `brandOrange` yap. Hero dışındaki glowShadow kullanımlarını ince gold border + `BoxShadow(blurRadius: 12, offset: Offset(0, 4))` ile değiştir. Uzun tema/round başlıklarında `maxLines: 2` ve ellipsis, ödül satırlarında `Wrap` kullan. Handler ve async gövdelerini değiştirme.

- [ ] **Step 4: Odaklı testleri geçir**

Run: `flutter test test/contest_test.dart test/tournament_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/contest_screen.dart lib/src/screens/tournament_screen.dart test/contest_test.dart test/tournament_screen_test.dart
git commit -m "ui: strengthen contest and tournament rewards"
```

### Task 4: Liderlik Podium ve Rank Satırları

**Files:**
- Modify: `lib/src/screens/leaderboard_screen.dart`
- Modify: `test/leaderboard_refresh_test.dart`
- Modify: `test/widget_test.dart` (mevcut leaderboard görsel testleri)

**Interfaces:**
- Preserves: `_load`, `_refreshTimer`, `refreshSignal`, period seçimi, repository çağrısı ve quick-race navigation.
- Produces: `ValueKey('leaderboard-podium')`, `ValueKey('leaderboard-rank-row')`, `ValueKey('leaderboard-refresh-button')`.

- [ ] **Step 1: Dark/light ve 360 px görsel sözleşme testini yaz**

Podium ve rank row key'lerini, gold border'ı, refresh key'ini ve 360 px/1.3 text scale'de exception olmadığını doğrula. Mevcut refresh-call sayacı testi aynen kalır.

- [ ] **Step 2: Yeni sözleşmenin FAIL olduğunu doğrula**

Run: `flutter test test/leaderboard_refresh_test.dart test/widget_test.dart --plain-name "leaderboard podium fits 360px with scaled text"`

Expected: key yokluğu nedeniyle FAIL.

- [ ] **Step 3: Liderlik görsel katmanını düzelt**

Hero/podium gold kimliğini koru; hero dışındaki glow'u ince border ve yumuşak gölgeye çevir. Podium adlarını `maxLines: 1/ellipsis`, skorları `FittedBox(scaleDown)` yap. Rank row'da isim `Expanded`, badge ve skor dar genişlikte wrap/scale-down kullanır. Period segmenti seçili gold, refresh butonu key'li kompakt ikon butonu olur; callback değişmez.

- [ ] **Step 4: Görsel ve refresh regresyonlarını geçir**

Run: `flutter test test/leaderboard_refresh_test.dart`

Run: `flutter test test/widget_test.dart --plain-name "leaderboard podium fits 360px with scaled text"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/leaderboard_screen.dart test/leaderboard_refresh_test.dart test/widget_test.dart
git commit -m "ui: polish responsive leaderboard hierarchy"
```

### Task 5: Friends Sosyal Kartları

**Files:**
- Modify: `lib/src/screens/friends_screen.dart`
- Modify: `test/friends_screen_test.dart`

**Interfaces:**
- Preserves: `_search`, `_sendRequest`, accept/reject/play callbacks, repository çağrıları ve navigation.
- Produces: `ValueKey('friends-search-panel')`, `ValueKey('friend-row')`, `ValueKey('friend-primary-action')`.

- [ ] **Step 1: Dar ekran ve kimlik testi yaz**

360 px/1.3 text scale'de arama paneli, friend row ve aksiyon key'lerini doğrula; uzun kullanıcı adı fixture'ında exception olmadığını bekle.

- [ ] **Step 2: Testin key/overflow sözleşmesi nedeniyle FAIL olduğunu doğrula**

Run: `flutter test test/friends_screen_test.dart`

Expected: FAIL.

- [ ] **Step 3: Sosyal yüzeyleri güncelle**

Arama panelini ince cyan border'lı yap; düello aksiyonunu pink, ana gönder/kabul aksiyonunu brandOrange kullan. Friend row isimlerini `Expanded + maxLines: 1 + ellipsis`, durumları tek satırlık chip, aksiyonları `Wrap`/kompakt ikon butonlarıyla düzenle. Bütün callback referanslarını aynen bırak.

- [ ] **Step 4: Friends testlerini geçir**

Run: `flutter test test/friends_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/friends_screen.dart test/friends_screen_test.dart
git commit -m "ui: refine responsive friends surfaces"
```

### Task 6: Paket Doğrulama, Görsel Kanıt ve Logic Audit

**Files:**
- Create: `docs/screenshots/pirs-inspired/package-04/light-390x844-matchmaking.png`
- Create: `docs/screenshots/pirs-inspired/package-04/dark-390x844-room.png`
- Create: `docs/screenshots/pirs-inspired/package-04/light-390x844-contest.png`
- Create: `docs/screenshots/pirs-inspired/package-04/light-390x844-tournament.png`
- Create: `docs/screenshots/pirs-inspired/package-04/light-390x844-leaderboard.png`
- Create: `docs/screenshots/pirs-inspired/package-04/light-390x844-friends.png`

**Interfaces:**
- Consumes: Tasks 1-5 görsel değişiklikleri.
- Produces: Paket 4 kullanıcı onayı için test/build/screenshot ve logic diff kanıtı.

- [ ] **Step 1: Format ve statik analiz**

Run: `dart format <yalnız değişen Dart dosyaları>`

Run: `dart analyze lib test`

Expected: `No issues found!`

- [ ] **Step 2: Odaklı ve tam test seti**

Run: `flutter test test/matchmaking_screen_test.dart test/friends_screen_test.dart test/tournament_screen_test.dart test/leaderboard_refresh_test.dart test/widget_test.dart`

Run: `flutter test`

Expected: tüm testler PASS. Sonra testlerin ürettiği `docs/screenshots/phase2b`, `phase2c` ve generated plugin değişikliklerini restore et.

- [ ] **Step 3: Release web build**

```powershell
$env:TMP='C:\src\tmp'
$env:TEMP='C:\src\tmp'
flutter build web --release
```

Expected: `Built build\web`.

- [ ] **Step 4: Playwright görsel doğrulama**

Release build'i yerel HTTP sunucusunda aç. 390x844 viewport'ta light/dark modlarda matchmaking, room, contest, tournament, leaderboard ve friends ekranlarını smoke et; yukarıdaki PNG'leri üret. Oda/online akışlarda yalnız misafir hesap kullan; canlı Supabase'e coin/ödül yazan aksiyonları tetikleme.

- [ ] **Step 5: Logic diff audit**

Run:

```bash
git diff zankurd-test-quality-hardening...HEAD -- lib/src/screens
git diff --check
```

Expected: repository/provider/Navigator çağrı hedefleri, callback gövdeleri, timer süreleri, polling/stream kodu ve matchmaking state geçişlerinde davranış farkı yok; yalnız widget/dekorasyon/test ankrajları değişmiş.

- [ ] **Step 6: Kanıt commit'i**

```bash
git add docs/screenshots/pirs-inspired/package-04
git commit -m "docs: verify Pirs-inspired competition and social screens"
```

## Paket 4 Kabul Kapısı

- 360 px ve 1.3 text scale'de oda kodu, oyuncu durumları, podium, rank row ve sosyal aksiyonlarda overflow yok.
- Bekleme, bağlantı ve eşleşme bulundu durumları görsel olarak ayrı.
- 1vs1 pink, oda/takım cyan, liderlik/ödül gold ve ana CTA orange kimliği tutarlı.
- Kilim yalnız hero yüzeylerinde; kalın glow yok.
- `dart analyze lib test`, odaklı testler, tam `flutter test` ve release web build başarılı.
- Logic audit, Phase 2E-3C polling hotfix'inin ve tüm davranış sözleşmelerinin korunduğunu gösteriyor.
- Paket 4 branch'i merge edilmeden kullanıcı görsel onayına sunuluyor.
