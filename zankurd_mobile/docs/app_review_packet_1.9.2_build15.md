# ZanKurd iOS 1.9.2 (15) — App Review Packet

Bu paket, mevcut kaynak koddan üretilen 1.9.2 (15) release adayı içindir.
App Store Connect'e yapıştırılmadan önce yüklenen binary, App Privacy kaydı ve
fiziksel cihaz videosu aynı build ile tekrar doğrulanmalıdır. Yerel derlemenin
başarılı olması Apple'ın binary doğrulamasının veya inceleme kabulünün yerine
geçmez.

## App Review Notes (copy/paste)

ZanKurd is a bilingual Kurmancî/Turkish learning and quiz app for people who
want to learn Kurmancî through short lessons, category practice, explanations,
and optional multiplayer activities. The app is not a regulated medical,
financial, or gambling service. Core solo learning content is available
offline.

No password is required for the main review flow. On the first screen, tap
“Misafir olarak devam et” / “Continue as guest”. Guest mode creates an
anonymous session and preserves the core app flow. Accept the Privacy Policy
and Terms of Use when prompted, then enter a display name if requested.

Suggested review path:

1. Launch the app and continue as Guest.
2. Open the five-question daily lesson, answer a question, and inspect the
   result and explanation flow.
3. Open Categories, choose a category, open its levels, and start a quiz.
4. Open Play / Multiplayer to inspect room creation, room joining, the
   tournament flow, and the leaderboard. These features require an internet
   connection and the production Supabase service.
5. In an online room, open chat. The room and profile surfaces expose Report
   and Block controls for user-generated content.
6. Open Profile and Settings. Account deletion is available at
   Settings → Account → Delete Account. The public fallback instructions are
   https://zankurd.com/delete-account.html.
7. Open the optional subscription/premium screen. The basic learning flow is
   usable without a subscription; Restore Purchases is available when store
   products are configured.

The app uses Supabase Auth, Postgres, Storage, and Realtime for optional
account synchronization, multiplayer rooms, leaderboard/friends, moderation,
and user content. RevenueCat handles optional subscription state and purchase
restoration. Firebase Crashlytics handles crash diagnostics. Firebase
Analytics is disabled by default and is enabled only after the user’s
analytics choice. OAuth is optional and is not required for the Guest review
flow.

Privacy Policy: https://zankurd.com/privacy.html
Terms of Use: https://zankurd.com/terms.html
Support and abuse reports: https://zankurd.com/support.html
Account deletion: https://zankurd.com/delete-account.html

The product and content behavior is consistent across regions. The interface
and learning content are available in Kurmancî and Turkish. The app does not
use advertising or unrestricted web browsing. Open/licensed question imagery
has attribution in the in-app image credits screen.

## Core feature walkthrough

| Feature | Entry point | Review condition |
| --- | --- | --- |
| Guest access | First screen → Misafir olarak devam et | No password; network may be needed for sync |
| Offline learning | Daily lesson, Categories, Levels | Packaged solo question bank |
| Quiz results | Answer a quiz question | Explanation appears when content has one |
| Multiplayer room | Play → online room | Internet and Supabase Realtime required |
| Tournament | Play → tournament | Internet and production backend required |
| Leaderboard/friends | Leaderboard tab | Internet and an anonymous/authenticated session |
| Chat/moderation | Inside an online room | Report and Block are available |
| Subscription | Premium/shop surface | Optional; basic learning is not paywalled |
| Account deletion | Settings → Account → Delete Account | Works for anonymous and email accounts |

## Account, deletion, and moderation

Guest mode uses an anonymous Supabase Auth session, so a reviewer can inspect
the core online path without a private password. Email account creation and
Google/OAuth options are optional. Account deletion is available in-app and
is also documented at the public deletion URL above.

Room messages and visible profile/player content are user-generated content.
The app exposes Report and Block controls, while the public support page gives
the abuse-report route: nisebinbawer47@gmail.com.

## External services and data flows

- Supabase Auth: anonymous and optional email/OAuth sessions.
- Supabase Postgres/Storage/Realtime: profiles, learning/game records,
  multiplayer rooms, leaderboard/friends, moderation, and user content.
- RevenueCat: optional subscription offerings, entitlement state, and restore
  purchases.
- Firebase Crashlytics: crash and stability diagnostics.
- Firebase Analytics: product analytics only after the user enables analytics.
- Apple system services: App Store purchase and review flows; no custom
  encryption beyond standard HTTPS/platform services.

## Tested devices and release evidence

- Candidate build: 1.9.2 (15). App Store Connect upload and Binary State are
  intentionally left blank until this exact candidate is uploaded.
- Build device family: iPhone and iPad; minimum iOS: 15.0.
- Local production-config validation: passed without printing secrets.
- Local iOS release build with production config: passed without code signing.
- Physical smoke evidence must be recorded on a public iOS release and must
  use this exact build. The connected iPhone 13 Pro currently runs iOS 27.0 Beta,
  so it is useful for smoke testing but is not final App Review evidence.

## Privacy and App Store metadata gate

The checked-in privacy manifest declares the data categories currently used by
the app and declares no location collection. Before uploading build 15, the
App Store Connect App Privacy answers must be compared with
`docs/app_privacy_reconciliation_1.9.2_build15.md`. In particular, do not
leave a coarse-location answer enabled unless the exact binary and product
behavior collect it; do not add a privacy declaration merely to silence a
metadata mismatch.

## Regional behavior and third-party content

The app provides the same core product behavior across regions. Language
selection changes the displayed Kurmancî/Turkish copy; it does not change
feature access. The app contains curated educational questions and credited
open/licensed imagery. It does not claim ownership of third-party imagery.

## Owner inputs before resubmission

- Enter the current owner phone number and the confirmed support email in App
  Store Connect App Review Information; do not store private contact details
  in source control.
- Upload the exact build 15 and reconcile App Privacy answers before sending
  it to review.
- Capture a physical-device video beginning at launch and showing the guest
  flow, solo quiz, account deletion, subscription screen, user-generated chat,
  and Report/Block controls.
- If Apple requires a non-anonymous account for any online feature, provide a
  disposable review account in App Store Connect only; do not put its password
  in source control or this packet.
