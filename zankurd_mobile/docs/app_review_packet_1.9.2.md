# ZanKurd iOS 1.9.2 (14) — App Review Packet

This packet answers Apple’s Guideline 2.1 request for the rejected App Store
submission. It describes the submitted build 14. Do not copy this packet into
App Store Connect until the physical recording and any private owner fields
have been checked against the exact binary.

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

- App Store Connect build: 1.9.2 (14), Binary State: Validated.
- Build device family: iPhone and iPad; minimum iOS: 15.0.
- App Store Connect media verified: six iPhone screenshots and six iPad
  screenshots are present.
- Local production-config validation: passed without printing secrets.
- Local iOS release build with production config: passed.
- Physical smoke installation: iPhone 13 Pro (iPhone14,2), iOS 27.0 Beta,
  Developer Mode enabled. This beta device is evidence of a local smoke test,
  not a substitute for a final recording on the current public iOS release.

## Regional behavior and third-party content

The app provides the same core product behavior across regions. Language
selection changes the displayed Kurmancî/Turkish copy; it does not change
feature access. The app contains curated educational questions and credited
open/licensed imagery. It does not claim ownership of third-party imagery.

## Owner inputs before resubmission

- Add the current owner phone number to App Review Information.
- Confirm that `nisebinbawer47@gmail.com` is still the correct review/support
  email.
- Capture a physical-device video beginning at launch and showing the guest
  flow, solo quiz, account deletion, subscription screen, user-generated chat,
  and Report/Block controls.
- If Apple requires a non-anonymous account for any online feature, provide a
  disposable review account in App Store Connect only; do not put its password
  in source control or this packet.
- Replace the beta-device evidence above with the exact public iOS device/OS
  combination used for the final recording.
