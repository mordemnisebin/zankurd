# ZanKurd iOS 2.0.1 (22) — App Review Packet

Bu paket, mevcut kaynak koddan üretilen 2.0.1 (22) release adayı içindir.
2.0.0 (21) paketinden (`app_review_packet_2.0.0_build21.md`) türetildi;
"2.0.0 (21)'den beri değişenler" bölümü yeni olanı toplar, aşağıdaki
"1.9.2 (20)'den beri değişenler" bölümü tarihsel olarak korunur. Metin App Store Connect'e yapıştırılmadan önce sahibi
tarafından okunmalıdır: buradaki cümleler kaynak koddan doğrulanabilir
olanlardır, Apple hesabına ait kanıtlar (yükleme durumu, cihaz videosu,
App Privacy cevapları) değildir. App Store Connect'e yapıştırılmadan önce
yüklenen binary, App Privacy kaydı ve fiziksel cihaz videosu aynı build ile
tekrar doğrulanmalıdır. Yerel derlemenin başarılı olması Apple'ın binary
doğrulamasının veya inceleme kabulünün yerine geçmez.

## App Review Notes (copy/paste)

ZanKurd is a bilingual Kurmancî/Turkish learning and quiz app for people who
want to learn Kurmancî and test their knowledge through short lessons,
category practice, explanations, and optional multiplayer activities. It has
eleven categories and more than 2,400 questions: most are about Kurdish
language, history and culture; the Dünya (World), Teknoloji (Technology) and
Bilim ve Düşünce (Science and Thought) categories are general knowledge. The
app is not a regulated medical, financial, or gambling service. Core solo
learning content is available offline.

Version 2.0.0 is a redesign (new visual system, new logo and icon) plus
content expansion. Data flows are listed below.

Sign-in options on the first screen are: Sign in with Apple, Sign in with
Google, e-mail/password, and Guest. On iOS, Apple and Google sign-in run
in-app through the native provider SDKs and hand the resulting identity token
to Supabase; they do not open an external browser. Sign in with Apple is
offered wherever a third-party sign-in is offered, per Guideline 4.8.

No password is required for the main review flow. On the first screen, tap
“Misafir olarak devam et” / “Continue as guest”. Guest mode creates an
anonymous session and preserves the core app flow. Accept the Privacy Policy
and Terms of Use when prompted, then enter a display name if requested.

Suggested review path:

1. Launch the app and continue as Guest.
2. On the Home tab (the first tab, labeled “Öğren” / “Learn” in the tab
   bar), open the daily lesson (ten questions;
   five on the very first session), answer a question, and inspect the result
   and explanation flow.
3. From the topic grid on the Home tab choose a category (there are eleven),
   open its levels, and start a quiz.
4. Open the Play tab. “Hızlı düello” (quick duel) matches a random live
   opponent; if none is found within 20 seconds the app offers “Sırayla
   düello” (turn-based duel: you play now, the opponent plays later) or a
   bot. “Sırayla düello” can also be started directly from the Play tab and
   its results appear under “Düellolarım”. Under “Arkadaşlarınla” you can
   create a room (“Oda kur”) with an invite link or join by code (“Kodla
   katıl”). These features require an internet connection and the production
   Supabase service.
5. Open the Leaderboard tab (labeled “Sıralama”; periods Gün / Hafta / Ay /
   Arkadaşlar). It also pins a “my rank” row at the bottom.
6. In an online room, open chat. The room and profile surfaces expose Report
   and Block controls for user-generated content.
7. From the learning shortcut on the Home tab, open the learning screen for
   the lesson path, daily stories, word cards and the dictionary
   (Sözlük / Ferheng).
8. Open Profile and Settings. Account deletion is available at
   Settings → Account → Delete Account. The public fallback instructions are
   https://zankurd.com/delete-account.html.
9. Open the optional subscription screen. The shortest entry point is the
   "ZanKurd Pro" row at the bottom of the Home tab (it is hidden for users
   who already subscribe). It can also be reached from the Profile tab
   (rightmost tab in the bottom tab bar) → the "Ayarlar" / "Settings" row in
   the menu list (gear icon) → the "Premium" section → the card in that
   section. Those are the only two entry points. That screen carries every
   item Guideline 3.1.2
   requires: the subscription name "ZanKurd Pro", the length (monthly /
   yearly), the localized price and the monthly equivalent of the yearly
   plan, the auto-renewal terms, and functional Privacy Policy and Terms of
   Use links. The basic learning flow is usable without a subscription;
   Restore Purchases is available when store products are configured.

The app uses Supabase Auth, Postgres, Storage, and Realtime for optional
account synchronization, multiplayer rooms, turn-based duels,
leaderboard/friends, moderation, and user content. RevenueCat handles
optional subscription state and purchase restoration. Firebase Crashlytics
handles crash diagnostics. Firebase Analytics is disabled by default and is
enabled only after the user’s analytics choice. Firebase Cloud Messaging
provides a device push token that is stored on the user’s profile so the
server can send friend-request and duel notifications; the iOS notification
permission prompt is shown only when the user turns on the daily reminder in
Settings. OAuth is optional and is not required for the Guest review flow.

Privacy Policy: https://zankurd.com/privacy.html
Terms of Use: https://zankurd.com/terms.html
Support and abuse reports: https://zankurd.com/support.html
Account deletion: https://zankurd.com/delete-account.html

The product and content behavior is consistent across regions. The interface
and learning content are available in Kurmancî and Turkish. The app does not
use advertising or unrestricted web browsing. Open/licensed question imagery
has attribution in the in-app image credits screen.

Content note: questions that presented a single political view as the one
correct answer were removed from the playable set before this build
(individually, not by hiding categories). The Kurdish history questions state
events, people and dates; the general-knowledge categories are neutral facts.


## 2.0.0 (21)'den beri değişenler

- Başlangıç yolu (test kullanıcılarının geri bildirimi): dört yeni ders —
  Alfabe (Hawar harfleri), Silav û rêzdarî 2, Xwe nasandin (kendini
  tanıtma), Malbat (aile). Ders sonu kısa testlerinde boşluk doldurma ve
  kelimeleri seçerek cümle kurma alıştırmaları (boşluk doldurma 20 → 89,
  cümle kurma 8 → 59).
- Sözlük (Ferheng) 86 → 789 kelime; derslerde ve sorularda geçen
  kelimeleri kapsar. Arama aksan duyarsız. Öğrenme ve tek kişilik
  alıştırmalarda Kurmancî bir kelimeye dokununca anlamı açılır; çoklu
  oyuncu yarışlarında kapalıdır ve cevabı göstermez.
- App Review Notes metni değişmedi; yeni bir izin, veri türü, satın alma
  ya da harici hizmet eklenmedi. İletişim adresi her yerde
  iletisim@zankurd.com.

## 1.9.2 (20)'den beri değişenler

Bu bölüm 1.9.2 (20) paketinden AYRILAN her şeyi listeler; gerisi aynıdır.
1.9.2 (20) paketindeki "Build 17'nin reddi" bölümü (3.1.2(c): EULA bağlantısı
App Description'da, abonelik adı ve birim fiyat satın alma ekranında) bu
build'de de geçerlidir ve değişmedi; ayrıntı için o pakete bak.

- **Yeni görünüm (Şahnê tasarım sistemi).** Her ekran aynı bileşen
  ailesinden çiziliyor; yeni logo ve uygulama simgesi; her konunun kendi
  silüeti var. İşlev akışları değişmedi, yalnız görünüm ve gezinme düzeni.
- **On bir kategori, 2.486 oynanabilir soru.** Sinema, Siyaset, Teknoloji,
  Bilim ve Düşünce (iç kimlik Paradigma) ve Dünya eklendi ya da yeniden
  açıldı. Dünya, Kürtlerle doğrudan bağı olmayan genel bilgiyi Kürt
  kategorilerinden ayrı tutar.
- **Sırayla düello.** Rakibin aynı anda çevrimiçi olmasını gerektirmeyen 1v1
  (Yarış sekmesi → "Sırayla düello", sonuçlar "Düellolarım"da). Sunucu
  göçleri 2026-09-30'da canlıya uygulandı. İnceleme sırasında rakip
  gerekmeden oynanır; sonuç rakibin oynamasıyla tamamlanır.
- **Liderlik tablosu:** altına sabitlenen "benim sıram" satırı artık seçili
  dönem (Gün / Hafta / Ay) puanından hesaplanıyor.
- **Push belirteci (FCM).** Sistem izni yalnız kullanıcı "Günlük hatırlatıcı"yı
  açtığında istenir; belirteç profile yazılır. `Info.plist`e
  `UIBackgroundModes → remote-notification` eklendi ve Release derlemesi
  production `aps-environment` kullanır. Bu, 1.9.2 (20) paketinden sonra
  (2026-08-29) girdi; App Privacy kaydıyla eşleştirilmesi aşağıdaki "Owner
  inputs" listesindedir.
- **Turnuva ve haftalık lig bayrakla kapalı** (`kTournamentEnabled`,
  `kWeeklyLeagueEnabled`). 1.9.2 paketi turnuvadan söz ediyordu; bu build'de
  Yarış sekmesinde turnuva yok, bu yüzden aşağıdaki tabloda ve inceleme
  yolunda geçmez.
- **Kurmancî metinler:** arayüz metinlerinin ve soru bankasının tamamı çok
  modelli bir denetimden geçti; görünür sonuç yalnız metin düzeltmeleridir.

## Core feature walkthrough

| Feature | Entry point | Review condition |
| --- | --- | --- |
| Guest access | First screen → Misafir olarak devam et | No password; network may be needed for sync |
| Offline learning | Daily lesson, topic grid, Levels | Packaged solo question bank |
| Quiz results | Answer a quiz question | Explanation appears when content has one |
| Quick duel | Play tab → Hızlı düello | Internet and Supabase Realtime required; offers turn-based duel or bot if no opponent in 20 s |
| Turn-based duel | Play tab → Sırayla düello; results in Düellolarım | Internet and production backend required; opponent not needed to play |
| Multiplayer room | Play tab → Oda kur / Kodla katıl | Internet and Supabase Realtime required |
| Leaderboard/friends | Leaderboard tab (Sıralama) | Internet and an anonymous/authenticated session |
| Learning screen | Home tab → learning shortcut: lesson path, stories, word cards, Sözlük | Packaged content |
| Chat/moderation | Inside an online room | Report and Block are available |
| Subscription | Home tab "ZanKurd Pro" row; Profile → Settings → Premium | Optional; basic learning is not paywalled |
| Sign in with Apple | First screen → "Apple ile giriş yap" | Native provider sheet; no external browser on iOS |
| Sign in with Google | First screen → "Google ile giriş yap" | Native provider sheet on iOS |
| E-mail sign-in | First screen → e-mail and password form | Optional; create an account from the sign-up screen |
| Account deletion | Settings → Account → Delete Account | Works for anonymous and email accounts |

## Account, deletion, and moderation

Guest mode uses an anonymous Supabase Auth session, so a reviewer can inspect
the core online path without a private password. Email account creation,
Sign in with Apple, and Sign in with Google are optional. A guest can later
link an Apple or Google identity to the same anonymous session, so local
progress is preserved instead of being replaced. Account deletion is available
in-app and is also documented at the public deletion URL above.

Room messages and visible profile/player content are user-generated content.
The app exposes Report and Block controls, while the public support page gives
the abuse-report route: iletisim@zankurd.com.

## External services and data flows

- Supabase Auth: anonymous sessions plus optional e-mail, Sign in with Apple,
  and Sign in with Google sessions. On iOS the Apple/Google identity tokens
  are obtained by the native provider SDKs and verified by Supabase.
- Supabase Postgres/Storage/Realtime: profiles, learning/game records,
  multiplayer rooms, turn-based duels, leaderboard/friends, moderation, and
  user content.
- RevenueCat: optional subscription offerings, entitlement state, and restore
  purchases.
- Firebase Crashlytics: crash and stability diagnostics.
- Firebase Analytics: product analytics only after the user enables analytics.
- Firebase Cloud Messaging: device push token for friend-request and duel
  notifications; stored on the user's profile.
- Apple system services: App Store purchase and review flows; no custom
  encryption beyond standard HTTPS/platform services.

## Tested devices and release evidence

- Candidate build: 2.0.1 (22). App Store Connect upload and Binary State are
  intentionally left blank until this exact candidate is uploaded.
- Build device family: iPhone and iPad; minimum iOS: 15.0.
- Local production-config validation and local iOS release build results are
  recorded in the release run for this exact build; they are not asserted in
  this packet.
- Physical smoke evidence must be recorded on a public iOS release and must
  use this exact build. A device on an iOS beta is useful for smoke testing
  but is not final App Review evidence.

## Privacy and App Store metadata gate

The checked-in privacy manifest declares the data categories currently used by
the app and declares no location collection. Before uploading build 22, the
App Store Connect App Privacy answers must be compared with
`docs/app_privacy_reconciliation_1.9.2_build15.md` and with the push token
flow above (the device push token stored on the profile is an identifier; the
1.9.2 reconciliation predates it and does not mention it). In particular, do
not leave a coarse-location answer enabled unless the exact binary and product
behavior collect it; do not add a privacy declaration merely to silence a
metadata mismatch.

The App Store description must carry the Terms of Use (EULA) and Privacy
Policy links (see `docs/store_listing.md`, App Store section): their absence
caused the 3.1.2(c) rejection of build 17.

## Regional behavior and third-party content

The app provides the same core product behavior across regions. Language
selection changes the displayed Kurmancî/Turkish copy; it does not change
feature access. The app contains curated educational questions and credited
open/licensed imagery. It does not claim ownership of third-party imagery.

## Owner inputs before resubmission

- Enter the current owner phone number and the confirmed support email in App
  Store Connect App Review Information; do not store private contact details
  in source control.
- Upload the exact build 22 and reconcile App Privacy answers (including the
  push token) before sending it to review.
- Retake the store screenshots with the new design (the current set predates
  it; see `docs/store_listing.md`).
- Capture a physical-device video beginning at launch and showing the guest
  flow, solo quiz, a turn-based duel, account deletion, subscription screen,
  user-generated chat, and Report/Block controls.
- If Apple requires a non-anonymous account for any online feature, provide a
  disposable review account in App Store Connect only; do not put its password
  in source control or this packet. Placeholder for the owner:
  `<review-account-email>` / `<review-account-password>` (fill in App Store
  Connect only).
