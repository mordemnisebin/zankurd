# Play Console Submission Checklist

Use this checklist for the first Google Play upload of ZanKurd.

## 1. Build Upload

- [ ] Open Play Console.
- [ ] Create or select the app named `ZanKurd`.
- [ ] Confirm package name is `com.zankurd.app`.
- [ ] Go to `Test and release > Testing > Internal testing`.
- [ ] Upload `build/app/outputs/bundle/release/app-release.aab`.
- [ ] Confirm Play Console accepts the bundle without target API, signing, or version errors.
- [ ] Add release notes from `docs/release_notes_internal.md`.

## 2. App Access

- [ ] Select that no special access is required if anonymous login is available to reviewers.
- [ ] If Supabase anonymous auth is disabled for the submitted build, provide a reviewer test account.
- [ ] Add a note that the app can be tested through the guest/anonymous flow.

Suggested note:

```text
Reviewers can access the app with the guest/anonymous flow. No paid account, invitation code, or external credential is required for the main quiz experience.
```

## 3. Ads

- [ ] Mark the app as not containing ads.
- [ ] Revisit this answer if an ad SDK is added later.

## 4. Content Rating

- [ ] Complete the content rating questionnaire.
- [ ] Category: education/trivia quiz.
- [ ] Disclose user-generated content: multiplayer room chat messages and submitted question suggestions are present in this release.
- [ ] Disclose online interactions for multiplayer room chat and gameplay.

## 5. Target Audience

- [ ] Choose the intended age range for the real product.
- [ ] Do not mark the app as child-directed unless the app, SDK usage, privacy policy, and content are prepared for the Google Play Families policy.
- [ ] Confirm the store listing language does not market the app directly to children if Families compliance has not been prepared.

## 6. Data Safety

Base the Data Safety form on actual production configuration:

- [ ] Account identifiers: Supabase user ID and optional email if email login is enabled.
- [ ] User profile data: display name; visible in leaderboards, friend features, multiplayer rooms, and tournaments.
- [ ] Photos: avatar image, only when the player uploads one (`Photos and videos > Photos`).
- [ ] Messages: text sent in multiplayer room chat; visible to participants in that room.
- [ ] Other user-generated content: submitted question text, answer choices, and explanation; visible only to authorized content reviewers.
- [ ] Gameplay content: stored game and learning progress, scores, tournament participation, and multiplayer matchmaking records.
- [ ] App activity: quiz scores, leaderboard entries, coin balance, daily spin state, favorites, reported questions.
- [ ] App interactions: Firebase Analytics events (screen opened, round started/completed, language changed).
- [ ] Device or other identifiers: Firebase app-installation identifier used for analytics; not advertising and not tracking.
- [ ] Purchases: RevenueCat subscription state, if premium packages are enabled for the release.
- [ ] Diagnostics: Firebase Crashlytics crash data on supported platforms.
- [ ] Data is transmitted over HTTPS.
- [ ] Data deletion is available in-app and through `https://www.zankurd.com/delete-account.html`.
- [ ] No advertising data is collected unless an ad SDK is added later.
- [ ] No precise location, contacts, SMS, call log, audio, or camera data is collected by the current app.

> 2026-07-29 denetimi: fotoğraf, analitik, satın alma, oda mesajları, soru
> önerileri ve oyun/eşleştirme içeriği uygulamanın gerçek veri akışına göre
> listelendi. Play formu, iOS bildirimi ve yayınlanan politika **aynı** şeyi
> söylemelidir; birbirlerini yalanlarlarsa inceleme takılır.

## 7. Privacy Policy

- [ ] Publish `web/privacy.html` at a public HTTPS URL.
- [ ] Verify the URL returns HTTP 200 without login.
- [ ] Enter the URL in Play Console's Privacy Policy field.
- [ ] Confirm the app also contains or links to account deletion instructions.
- [ ] Enter `https://www.zankurd.com/delete-account.html` in the account deletion URL field.

## 8. Store Listing

- [ ] App name: `ZanKurd`
- [ ] Short description: `Kurmanci odaklı günlük quiz, kategori yarışları ve arkadaş odaları.`
- [ ] Full description should mention quiz, Kurmanci learning, categories, daily challenge, leaderboard, and anonymous play.
- [ ] Upload phone screenshots from a real or emulator Play build.
- [ ] Upload `docs/store-assets/play-feature-graphic.png` (1024×500) as the feature graphic.
- [ ] Use category `Education` or `Trivia`; prefer `Education` if the listing emphasizes language learning.

## 9. Internal Test Smoke Check

Install from the Play internal testing link and verify:

- [ ] First launch and onboarding.
- [ ] Anonymous sign-in.
- [ ] Profile name gate.
- [ ] Daily quiz.
- [ ] Category/level quiz.
- [ ] Daily spin.
- [ ] Leaderboard.
- [ ] Question favorite.
- [ ] Question report.
- [ ] Account deletion request.
- [ ] App relaunch preserves expected local state.

## 10. Promotion Decision

- [ ] Play Console pre-launch report has no blocking crash.
- [ ] Internal tester can complete one quiz.
- [ ] Data Safety and privacy policy answers match the shipped SDKs and backend behavior.
- [ ] Supabase production SQL and policies are applied.
- [ ] Upload key is backed up outside the project folder.
