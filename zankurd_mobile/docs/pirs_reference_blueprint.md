# ZanKurd Pirs Reference Blueprint

Last updated: 2026-06-08

This project uses the local `Pirs_apk_extracted` folder as a product reference, not as source code to copy.

Reference path:

- `C:\Users\AMARGİ\Desktop\pirs kurmanci\Pirs_apk_extracted`

Important source files:

- `README_TR.md`
- `CODEX_PROMPT_TR.md`
- `reports/APK_ANALYSIS_SUMMARY_TR.md`
- `reports/resources_overview.md`
- `databases/quiz_level_schema.sql`
- `databases/quiz_bookmark_schema.sql`
- `decoded_xml/res/layout/*`

## Rule

Do not copy proprietary code, package names, API keys, images, or exact assets from Pirs.

Use Pirs as a feature, flow, and UX reference. ZanKurd should be a modern Flutter/Supabase implementation with its own identity.

## Pirs Feature Map To Keep As Product Backbone

Core flow:

- Splash / app loading
- Guest or login flow
- Home dashboard
- Category list
- Subcategory list
- Level list
- Quiz play
- Complete/result screen
- Review screen
- Bookmark/favorite questions

Competition:

- Leaderboard tabs
- Contest
- Tournament
- Battle play
- One-to-one waiting room
- Multiplayer waiting room
- Room code / join room dialog
- Live player score rows

Learning:

- Learning zone
- Learning chapters
- Practice quiz
- Math/TeX capable questions later

Retention/economy:

- Coin store
- Rewards
- Spin wheel
- Daily activities
- Notifications

Support/settings:

- Profile
- User statistics
- Settings
- Instructions
- Privacy policy
- Question report dialog
- Submit question dialog

## Mapping To ZanKurd

Already started:

- Home dashboard
- Online rooms with code
- Waiting room
- Quiz play
- Result screen
- Leaderboard
- Favorite/report UI stubs
- Supabase backend
- Android/Web/Windows builds
- iOS/macOS/Linux project folders

Next high-priority Pirs-inspired implementation:

1. Category -> Level flow
   - Add level cards under each category.
   - Track progress.
   - Unlock next level after completing a level.

2. Review screen
   - After result, show each question, selected answer, correct answer, and explanation.

3. Favorite/bookmark system
   - Replace UI stub with Supabase favorite_questions writes.
   - Add a bookmark list screen.
   - Allow replaying bookmarked questions.

4. Battle polish
   - Shared room question order is phase 1.
   - Add room-level current_question_index.
   - Move all players question-by-question together.
   - Add final room ranking.

5. Profile and statistics
   - Display name editor.
   - Total score, best streak, games played.
   - Profile screen.

6. Coins/rewards
   - Award coins after quiz.
   - Add basic reward history.
   - Keep paid billing/ads for later feature flags.

7. Contests/tournaments
   - Start with scheduled daily contest table.
   - Then tournament leaderboard.

## Design Direction

Pirs was feature-rich and game-like. ZanKurd should keep that breadth but use a cleaner modern interface:

- Dense, scannable quiz dashboard.
- Clear room code and player state.
- Strong result/review loop.
- Small icons for key actions.
- No copied graphics or direct layouts.
- Modern cards/panels, restrained colors, fast navigation.

## Immediate Development Queue

Current next step:

- Add Category -> Level screen and progress model.

Then:

- Add Review screen.
- Wire favorites/bookmarks to Supabase.
- Add profile/statistics screen.
