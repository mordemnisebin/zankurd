# Phase 2E-3B — Room Sync & Start Button Diagnostic Report

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge`  
**Latest commit:** `aaf6ffc` — `test: add room lobby sync start gate diagnostics`  
**Prior:** `0eab7ec` (room code input hotfix — do not revisit)  
**Mode:** Inspection + diagnosis only — no `lib/` logic hotfix in this task

---

## Exact Files Inspected

| File | Role |
|------|------|
| `lib/src/screens/room_screen.dart` | Lobby subscriptions, polling, start gate, quiz navigation |
| `lib/src/screens/home_screen.dart` | Create/join entry points (sync path only) |
| `lib/src/data/zankurd_repository.dart` | Room API contract |
| `lib/src/data/supabase_zankurd_repository.dart` | Online create/join, streams, `loadRoomPlayers`, `startGame` |
| `lib/src/data/mock_zankurd_repository.dart` | Mock room (4 players, static streams) |
| `lib/src/models/room.dart` | `GameRoom`, `RoomStatus`, `hostId` |
| `lib/src/models/player.dart` | Player row model |
| `supabase/online_multiplayer_ready.sql` | `join_room_by_code`, `start_room_game`, `finish_room_game`, `submit_answer` |
| `supabase/add_realtime_room_tables.sql` | Realtime publication for `rooms` / `room_players` |
| `supabase/room_players_rls_fix.sql` | `is_room_participant()` + cross-participant SELECT |
| `test/widget_test.dart` | Room lobby + sync diagnostic tests |
| `test/supabase_repository_test.dart` | RPC/SQL contract source checks |

---

## Git Status / Log Summary

### `git status --short`

```
(clean tracked tree — no modified lib/ or test/ files)

?? analyze_3b.txt, test_3b*.txt, test_run_output.txt  (session temp)
?? docs/DOCS_CHECKPOINT_COMMIT_REPORT.md
?? docs/ROOM_CODE_INPUT_VISIBILITY_HOTFIX_REPORT.md
?? run_tests.ps1, tools/run_analyze_and_test.ps1
```

### `git log --oneline -5`

```
aaf6ffc test: add room lobby sync start gate diagnostics
0eab7ec fix: improve room code input readability
18fffd1 docs: add phase 2e audit and cleanup reports
6755744 phase 2e-2: redesign sign up and profile name gate screens
3ff754a phase 2e-1: redesign sign in and onboarding screens
```

---

## Participant Sync Logic Summary

### Where `room_players` are initially loaded

| Path | When | How |
|------|------|-----|
| **Host create** | `createOnlineRoom()` | INSERT `rooms` + INSERT `room_players` (host) → `_loadRoomPlayersById(roomId)` → `GameRoom` with `players[1]`, `hostId`, `id` |
| **Guest join** | `joinOnlineRoom(code)` | RPC `join_room_by_code` INSERT guest → `_loadRoomPlayersById(roomId)` → full list before `RoomScreen` |
| **Lobby entry** | `RoomScreen.initState` | Uses `widget.initialRoom.players` (already loaded above) |

### Where host player list is refreshed

| Mechanism | Code | Trigger |
|-----------|------|---------|
| **Realtime stream** | `subscribeRoomPlayers` → `.stream(room_players)` → `_loadRoomPlayersById` | Any `room_players` row change for `room_id` |
| **Polling fallback** | `Timer.periodic(3s)` → `loadRoomPlayers` → `_loadRoomPlayersById` | Every 3s while lobby active |
| **Not used in lobby** | `setState` from user actions | Only ready toggle (does not add players locally) |

### How `subscribeRoomPlayers` works

```dart
// supabase_zankurd_repository.dart:650-657
client.from('room_players')
  .stream(primaryKey: ['room_id', 'player_id'])
  .eq('room_id', roomId)
  .asyncMap((_) => _loadRoomPlayersById(roomId));
```

- Requires `room.id` (online room). Offline/mock with `id == null` → `Stream.value(room.players)` (static).
- On each realtime event, full player list re-fetched via REST (not raw stream payload).
- Joins `profiles` for display names and avatar fields.

### How polling fallback works

```dart
// room_screen.dart:69-89
Timer.periodic(3s) → loadRoomPlayers(room) → setState(players)
  → after 20 ticks (~60s): pause polling
  → after 15s delay: restart polling (if still mounted)
```

- Started in `initState` alongside subscriptions.
- Errors in poll loop: `catch (_) {}` — silent, no UI feedback.

### When polling pauses

| Event | Effect |
|-------|--------|
| **Any `subscribeRoomPlayers` emission** | `_pausePolling()` immediately (`room_screen.dart:57`) |
| **60s of successful polls** | Pause + 15s delayed restart |
| **dispose / quiz opened** | `_pausePolling()` |

**Critical:** First realtime event permanently stops polling until the 60-poll cycle completes — but that cycle **never runs** if polling was paused early by a stream event. Polling only restarts from the 15s delayed callback inside the poll loop itself (unreachable after early pause).

### If realtime fires but `loadRoomPlayers` returns stale/incomplete data

1. Stream event fires (e.g. guest INSERT in DB).
2. `_pausePolling()` — REST fallback disabled.
3. `_loadRoomPlayersById` returns partial list (e.g. host only) due to RLS or transient error.
4. `setState(players: [host])` — UI shows 1 player.
5. Polling is off — no 3s recovery unless another stream event arrives with a successful full reload.
6. **Host stuck at 1 player** → start button stays disabled.

### If RLS blocks guest row visibility

- `_loadRoomPlayersById` SELECT on `room_players` filtered by RLS.
- Without `is_room_participant(room_id)` policy (`room_players_rls_fix.sql`), host may only read `player_id = auth.uid()` → **1 row returned**.
- Guest join path works for guest (sees self + host if policy allows host row via rooms join) but **host poll/stream reload returns incomplete list**.
- Realtime still fires (INSERT happened) but reload is empty of guest → same stuck state.

---

## Start Button Logic Summary

### Exact enable condition

```dart
// room_screen.dart:290
onPressed: ready && !starting && room.players.length >= 2 ? _startGameHost : null
```

Shown only when:

```dart
// room_screen.dart:112, 286
isHost = room.hostId == null || room.hostId == currentUserId
```

### Dependency matrix

| Factor | Required for start? | Notes |
|--------|---------------------|-------|
| `room.players.length >= 2` | **Yes** | Client-only gate; SQL `start_room_game` does **not** check player count |
| `ready == true` (host toggle) | **Yes** | Defaults `true` in `initState` |
| `!starting` | **Yes** | Loading state during RPC |
| `isHost` | **Yes** | Host sees button; guest sees waiting spinner |
| All players `is_ready` | **No** | Not checked client-side or in `start_room_game` |
| `hostId == currentUserId` for RPC | **Yes** (server) | `start_room_game` checks `host_id = auth.uid()` |

### Why host may not start after friend joins

| Rank | Cause | Symptom |
|------|-------|---------|
| 1 | Host UI still shows `players.length == 1` (sync failure) | Button disabled + red "min 2 players" message |
| 2 | Host `ready` toggle off | Button disabled, no min-players message |
| 3 | `isHost == false` (hostId/currentUserId mismatch) | Guest wait UI instead of start button |
| 4 | `startGame` RPC fails after tap | Snackbar "Oyun başlatılamadı" — button was enabled |
| 5 | `room.id == null` | `startGame` silent no-op — unlikely after online create |

**Most likely:** #1 — participant list on host never reaches 2 due to realtime/RLS/polling interaction.

---

## Supabase Deployment Checklist

> **Not verified in production** — no live Supabase access in this audit. Apply checklist manually.

### Tables in realtime publication

| Table | Required | SQL file |
|-------|----------|----------|
| `public.rooms` | Yes | `supabase/add_realtime_room_tables.sql` |
| `public.room_players` | Yes | `supabase/add_realtime_room_tables.sql` |

**Verify (run in Supabase SQL editor):**

```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('rooms', 'room_players');
```

Expect 2 rows. If 0, host stream never fires on guest join.

### RLS policies for host to read guest rows

| Requirement | SQL file |
|-------------|----------|
| `is_room_participant(p_room_id)` function | `supabase/room_players_rls_fix.sql` |
| `"Players read room membership"` on `room_players` — `player_id = auth.uid() OR is_room_participant(room_id)` | `supabase/room_players_rls_fix.sql` |
| `"Room participants can read rooms"` on `rooms` | `supabase/room_players_rls_fix.sql` |
| `"Players update their own room membership"` (ready toggle) | `supabase/online_room_policies.sql` |
| `"Hosts can update their own rooms"` | `supabase/online_room_policies.sql` |

### RPCs required

| RPC | Purpose | SQL file |
|-----|---------|----------|
| `join_room_by_code(text)` | Guest join + `room_players` INSERT | `supabase/online_multiplayer_ready.sql` |
| `start_room_game(uuid)` | Host starts; sets `status=active` | `supabase/online_multiplayer_ready.sql` |
| `finish_room_game(uuid)` | End game | `supabase/online_multiplayer_ready.sql` |
| `submit_answer(...)` | In-game answers | `supabase/online_multiplayer_ready.sql` |

### Constraints / indexes (from SQL + app behavior)

| Item | Purpose |
|------|---------|
| `room_players (room_id, player_id)` unique / ON CONFLICT | `join_room_by_code` upsert |
| `rooms.code` unique | `createOnlineRoom` retry on `23505` |
| `rooms.status = 'lobby'` filter in join RPC | Prevents join to active room |
| `questions.is_approved = true` | `start_room_game` question seeding |

### SQL files that must be deployed (ordered)

1. Base schema (rooms, room_players, profiles — pre-existing)
2. `supabase/online_multiplayer_ready.sql`
3. `supabase/room_players_rls_fix.sql`
4. `supabase/online_room_policies.sql`
5. `supabase/add_realtime_room_tables.sql`
6. Optional: `supabase/online_game_sync.sql` (in-game index sync — post-start)

---

## Suspected Root Causes (Ranked by Likelihood)

### Issue 1: Host does not clearly see friend joined

| Rank | Cause | Classification |
|------|-------|----------------|
| 1 | `room_players` not in `supabase_realtime` publication | **Supabase realtime publication** + **manual test required** |
| 2 | RLS missing `is_room_participant` — reload returns host-only | **Supabase RLS** + **manual test required** |
| 3 | Stream event pauses polling; incomplete reload sticks | **App polling/realtime issue** |
| 4 | Poll errors swallowed silently | **App polling/realtime issue** |
| 5 | No join toast/badge — user doesn't notice count change | **App UI state issue** |
| 6 | Mock CI uses 4 static players | **Test gap** (masks prod bugs) |

### Issue 2: Host cannot start after friend joins

| Rank | Cause | Classification |
|------|-------|----------------|
| 1 | `room.players.length < 2` on host (Issue 1 downstream) | **App UI state** + sync layers above |
| 2 | Host `ready` false | **App UI state** |
| 3 | `isHost` false (`hostId` ≠ `currentUserId`) | **App UI state** |
| 4 | `start_room_game` RPC auth/question failure | **RPC/startGame issue** + **manual test required** |
| 5 | Guest not actually in DB (join failed silently) | **manual test required** |

---

## Tests Found

| Test | File | Coverage |
|------|------|----------|
| `creates a room and opens the quiz flow` | `widget_test.dart` | Mock 4 players — masks 2-player gate |
| `room lobby remains usable in landscape` | `widget_test.dart` | Layout only |
| `room lobby keeps start disabled until two players are present` | `widget_test.dart` | Start gate with 1 player |
| `room lobby enables start after player stream adds a guest` | `widget_test.dart` | Start enables on 2nd stream emit |
| `home does not open demo room when online room creation/join fails` | `widget_test.dart` | Error paths |
| `empty room code is validated locally` | `widget_test.dart` | Join validation (unrelated to sync) |
| `Supabase local room shell does not include mock opponents` | `supabase_repository_test.dart` | 1-player shell |
| `online room join uses the room-code RPC contract` | `supabase_repository_test.dart` | Source check |
| `online multiplayer SQL patch defines required live RPCs` | `supabase_repository_test.dart` | SQL file check |
| `room player queries preserve avatar showcase fields` | `supabase_repository_test.dart` | SELECT columns |

### Tests missing

| Test | Priority |
|------|----------|
| Polling resumes after stream with incomplete data | P1 |
| `loadRoomPlayers` error surfaces in UI | P2 |
| `isHost` false hides start (guest view) | P2 |
| Two-client Supabase integration | P0 manual |
| Production realtime publication present | P0 manual SQL |

---

## Tests Added/Updated in This Phase

Already committed at `aaf6ffc` (no new changes in this report-only pass):

| Action | Test |
|--------|------|
| Added | `room lobby keeps start disabled until two players are present` |
| Added | `room lobby enables start after player stream adds a guest` |
| Updated | `_HostOnlyRoomRepository`, `_GrowingPlayersRoomRepository` test doubles |

**No additional test changes in this task** — existing coverage satisfies item 6.

---

## Verification

### `dart analyze`

**Exit 0** — 10 info (`avoid_print` in preview test files); `lib/` clean.

### `flutter test --exclude-tags preview`

**Exit 0** — **338 / 338 passed**

All three room lobby tests passed (+305, +306, +307 in last run).

---

## Whether Any Code Was Changed

**No.** This task produced the report only. Diagnostic tests and doubles were committed earlier at `aaf6ffc`. Room code input hotfix at `0eab7ec` is unchanged.

---

## Risk Assessment

| Risk | Level |
|------|-------|
| Production rooms broken if SQL never deployed | **High** |
| Polling pause + partial reload leaves host stuck | **High** (client design) |
| False confidence from 338 passing widget tests | **Medium** (no live Supabase tests) |
| `isHost` null-hostId fallback | **Low** |
| Implementing broad logic fix without SQL verification | **High** |

---

## Exact Next Recommended Step

1. **Run Supabase deployment checklist** (SQL queries above) on production — confirm realtime + RLS before any `room_screen.dart` logic change.
2. **Manual two-device test** (checklist below).
3. If SQL confirmed OK but host still stuck → implement **narrow P1 fix**: do not permanently pause polling on first stream event; keep polling until `players.length >= 2` (separate commit, not redesign).
4. Do **not** revisit room code input (`0eab7ec`).

---

## Manual Two-Device Test Checklist

| # | Step | Host device | Guest device | Pass criteria |
|---|------|-------------|--------------|---------------|
| 1 | Auth | Signed in (not anonymous mismatch) | Signed in | Both have profiles |
| 2 | Create | Tap "Oda Kur" | — | Lobby opens, code visible, **1 player** |
| 3 | Join | Share code | Enter code in join sheet | Guest lobby shows **2 players** |
| 4 | Sync wait | Wait 3s, then 10s | — | Host player count → **2**, guest name visible |
| 5 | Start gate | — | — | Host "Yarışı Başlat" **enabled**; min-players warning **gone** |
| 6 | Guest UI | — | — | Guest sees "Ev sahibi bekleniyor" (not start button) |
| 7 | Start | Tap start | — | Both navigate to quiz |
| 8 | SQL spot-check | — | — | `room_players` has 2 rows for room UUID |
| 9 | Failure capture | If step 4 fails | — | Log Supabase: publication tables, RLS policies, host REST row count |

### Failure interpretation

| Failed step | Likely layer |
|-------------|--------------|
| 3 guest sees 1 player | Join RPC / RLS on guest read |
| 4 host stays at 1 | Realtime publication, RLS, or polling pause bug |
| 5 button disabled after step 4 shows 2 | UI state bug (unlikely if count correct) |
| 7 snackbar on start | RPC auth or empty question pool |

---

*End of Phase 2E-3B diagnostic report. No production logic hotfix applied.*