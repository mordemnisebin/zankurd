# ZanKurd Product Plan

ZanKurd is a Kurmanci-first live quiz app. The first build focuses on the game loop: create a room, invite players with a code, answer timed questions, calculate scores on the backend, and show live rankings.

## MVP Scope

- Email, Google, or anonymous guest sign-in.
- Player profile with display name, avatar color, coins, and stats.
- Question bank by category, difficulty, language, and source.
- Single-player practice mode.
- Private room with invite code.
- Live room state: lobby, active question, reveal, leaderboard, finished.
- Backend-side answer validation and score calculation.
- Basic leaderboards for daily, weekly, and all-time rankings.
- Admin workflow for adding, reviewing, and disabling questions.

## Online Room Flow

1. Host creates a room and receives a short code.
2. Players join the room channel through Supabase Realtime Presence.
3. Host selects category, question count, answer time, and joker rules.
4. When the host starts the room, the backend locks a question set.
5. Clients receive question text and answer options, but not the correct answer.
6. Players submit answers to the backend before the timer ends.
7. Backend computes correctness, speed bonus, streak bonus, and joker effects.
8. Room broadcasts reveal state and updated leaderboard.
9. The final state writes match results and player stats.

## Score Rules

- Correct answer: 100 points.
- Speed bonus: up to 50 points, based on remaining milliseconds.
- Streak bonus: 10 points per consecutive correct answer, capped at 50.
- Wrong answer: 0 points for the question.
- No answer: 0 points.

## Game Modes

- Private room: friends join with a code.
- Random match: matchmaking by category and rating band.
- Daily challenge: same questions for everyone that day.
- Tournament: scheduled room with a fixed start time and public ranking.
- Learn and solve: short lesson content followed by questions.

## Monetization

- Coins for cosmetic profile items and limited joker refills.
- One-time coin packs through Google Play Billing.
- Optional premium subscription later: ad-free, detailed stats, extra practice sets.

## Compliance Checklist

- Privacy policy URL.
- In-app account deletion path.
- Data deletion request page.
- Google Play Data Safety form aligned with actual SDK usage.
- Purchase validation on the backend.
- Clear reporting flow for wrong or sensitive questions.
