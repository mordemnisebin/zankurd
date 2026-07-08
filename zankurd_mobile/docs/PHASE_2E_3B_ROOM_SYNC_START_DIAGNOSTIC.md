# Phase 2E-3B — Room Sync & Start Button Diagnostic

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge`  
**Base commit:** `0eab7ec` (room code input hotfix)  
**Mode:** Inspection + test planning — no `lib/` logic changes, no redesign, no push

---

## Exact Files Inspected

| File | Role |
|------|------|
| `lib/src/screens/room_screen.dart` | Subscriptions, polling, start gate, navigation |
| `lib/src/screens/home_screen.dart` | Create/join entry (unchanged) |
| `lib/src/data/supabase_zankurd_repository.dart` | `createOnlineRoom`, `joinOnlineRoom`, streams, `loadRoomPlayers`, `startGame` |
| `lib/src/data/mock_zankurd_repository.dart` | Static streams; 4-player mock masks sync |
| `lib/src/data/zankurd_repository.dart` | API contract |
| `lib/src/models/room.dart` | `GameRoom`, `hostId` |
| `supabase/add_realtime_room_tables.sql` | Realtime publication patch |
| `supabase/room_players_rls_fix.sql` | Cross-participant SELECT |
| `supabase/online_multiplayer_ready.sql` | `join_room_by_code`, `start_room_game` |
| `supabase/online_room_policies.sql` | Ready toggle update policy |
| `test/widget_test.dart` | Existing + new diagnostic tests |

---

## Sync Flow (Host Perspective)

```
createOnlineRoom
  → rooms INSERT (host_id)
  → room_players INSERT (host, is_ready=true)
  → RoomScreen(initialRoom: players[1], hostId set)

RoomScreen.initState
  ├── subscribeRoomPlayers → .stream(room_players) → _loadRoomPlayersById
  ├── subscribeRoomStatus  → .stream(rooms.status)
  ├── Timer.periodic 3s    → loadRoomPlayers (fallback)
  └── updateReady(true)    → PATCH room_players (may trigger stream)

On stream event:
  ├── _pausePolling()      ← polling stops permanently
  └── setState(players)

Start button enabled when:
  isHost && ready && !starting && room.players.length >= 2

isHost = room.hostId == null || room.hostId == currentUserId
```

### Guest path (works today)

`joinOnlineRoom` → RPC inserts guest → `_loadRoomPlayersById` returns **full list** before navigation. Guest sees host immediately. Confirms join + initial load work; host update is the failure point.

---

## Issue 1: Host Does Not Clearly See Friend Joined

### Ranked root-cause candidates

| # | Cause | Layer | Likelihood | Evidence |
|---|-------|-------|------------|----------|
| 1 | `room_players` / `rooms` not in `supabase_realtime` publication | **Realtime / deployment** | **High** | `add_realtime_room_tables.sql` documents this as prior root cause |
| 2 | RLS allows only `player_id = auth.uid()` without `is_room_participant` | **Repository / deployment** | **High** | `room_players_rls_fix.sql` required for host to read guest rows |
| 3 | Stream reload returns incomplete list; polling already paused | **Client state** | **Medium** | Any stream event calls `_pausePolling()`; no resume except 60-poll cycle (never reached if paused early) |
| 4 | Poll errors swallowed (`catch (_) {}`) | **Client / repository** | **Medium** | Silent failure; UI stuck at initial count |
| 5 | No join UX feedback (count/tile only) | **UI perception** | **Medium** | Sync may work but host doesn't notice |
| 6 | Mock tests use 4 static players | **Test gap** | **High** | CI never exercised 1→2 player transition before 3B |

### Client-side finding (important)

**Polling is permanently paused on the first `subscribeRoomPlayers` event** (`room_screen.dart:57`). Design assumes realtime delivers all subsequent updates. If realtime is flaky or reload returns partial data, host can remain at 1 player with no polling safety net.

| Realtime state | Polling | Host sees guest? |
|----------------|---------|------------------|
| Not deployed | Runs every 3s | Yes, if RLS + REST OK (~3s delay) |
| Deployed + RLS OK | Paused after 1st event | Yes, on each stream reload |
| Deployed + RLS broken | Paused after 1st event | **No** — stuck at partial reload |
| Not deployed + RLS broken | Runs every 3s | **No** — poll also returns 1 row |

---

## Issue 2: Host Cannot Start After Friend Joins

### Direct coupling

Start button: `room.players.length >= 2` (`room_screen.dart:290`). **If Issue 1 leaves host at 1 player, start stays disabled.** This is the most likely user-visible symptom, not a separate start bug.

### Secondary candidates

| Cause | Layer | Notes |
|-------|-------|-------|
| `ready == false` | UI | Defaults `true`; cleared on dispose only |
| `isHost == false` | Client | When `hostId != null && currentUserId != hostId`; host sees guest wait UI instead of start |
| `start_room_game` RPC auth failure | Repository | `host_id = auth.uid()` — snackbar on failure, button was enabled |
| `startGame` no-op when `room.id == null` | Repository | Silent return — unlikely after online create |
| Question pool empty in RPC | Backend | Error after tap, not disabled button |

### `isHost` fallback risk

`room.hostId == null || room.hostId == currentUserId` — if `hostId` is null, **any** client may see host start UI; RPC still rejects non-host.

---

## What Was NOT Changed

| Area | Status |
|------|--------|
| `lib/` app logic | **No changes** |
| Room screen UI redesign | **Not started** |
| Repository / RPC / SQL | **Untouched** |
| Navigation / matchmaking | **Untouched** |

---

## Tests Added (Diagnostic)

| Test | Purpose |
|------|---------|
| `room lobby keeps start disabled until two players are present` | Documents `players.length < 2` gate + warning copy |
| `room lobby enables start after player stream adds a guest` | Documents UI unlock when `subscribeRoomPlayers` emits 2nd player |

### Test doubles

| Class | Behavior |
|-------|----------|
| `_HostOnlyRoomRepository` | 1 host player; static stream |
| `_GrowingPlayersRoomRepository` | Emits guest after 50ms on stream |

### Tests still missing (planned, not implemented)

| Test | Type | Priority |
|------|------|----------|
| Polling resumes after stream failure | Widget + fake repo | P1 |
| `isHost` false hides start button | Widget | P2 |
| `loadRoomPlayers` error surfaces retry hint | Widget | P2 |
| Two-client Supabase integration | Manual / tagged integration | P0 for prod validation |
| Realtime publication present in prod | SQL verification script | P0 |

---

## Verification

### `dart analyze`

**Exit 0** — 10 info (`avoid_print` in preview tests); `lib/` clean.

### `flutter test --exclude-tags preview`

**Exit 0** — **338 / 338 passed** (was 336; +2 diagnostic tests)

| Room lobby tests | Result |
|------------------|--------|
| `room lobby remains usable in landscape` | Pass |
| `room lobby keeps start disabled until two players are present` | Pass |
| `room lobby enables start after player stream adds a guest` | Pass |

---

## Production Deployment Checklist (Manual)

Run in Supabase SQL Editor **before** client fixes:

```sql
-- 1. Realtime publication
select tablename from pg_publication_tables
where pubname = 'supabase_realtime'
  and tablename in ('rooms', 'room_players');

-- 2. RLS helper exists
select proname from pg_proc where proname = 'is_room_participant';

-- 3. Policy allows participant read
-- (inspect "Players read room membership" on room_players)
```

Apply if missing:
- `supabase/add_realtime_room_tables.sql`
- `supabase/room_players_rls_fix.sql`

### Two-device manual repro

| Step | Host | Guest |
|------|------|-------|
| 1 | Create room | — |
| 2 | Note player count | Join by code |
| 3 | Wait 3s / 10s | Confirm 2 players visible |
| 4 | Check start enabled | Confirm waiting UI |
| 5 | Tap start | Both reach quiz |

Log `loadRoomPlayers` row count on host if still failing.

---

## Recommended Fix Order (Next Phase — Not This PR)

| Priority | Fix | Scope | Effort |
|----------|-----|-------|--------|
| P0 | Verify/deploy realtime + RLS SQL | Supabase ops | Low |
| P1 | Don't pause polling permanently on stream; use debounced pause or parallel poll until `players.length >= 2` | `room_screen.dart` | Small |
| P1 | Log/report poll + stream errors (replace `catch (_) {}`) | `room_screen.dart` | Small |
| P2 | Tighten `isHost` to require `hostId == currentUserId` | `room_screen.dart` | Small |
| P2 | Join feedback snackbar/badge on player count increase | `room_screen.dart` UI | Small |
| P3 | Integration test with tagged Supabase env | `test/` | Medium |

---

## Risk Assessment

| Risk | Level |
|------|-------|
| Deploying SQL patches incorrectly | Medium — use idempotent scripts |
| P1 polling fix causing extra API calls | Low — acceptable for lobby |
| Current production broken for all private rooms | High if SQL never deployed |

---

## Next Recommended Step

1. **Run production deployment checklist** on live Supabase.
2. **Two-device manual repro** with checklist above.
3. If still failing after SQL confirmed: implement **P1 polling resume** fix in a narrow `room_screen.dart` hotfix (separate commit from redesign).
4. Defer full room lobby visual redesign until sync confirmed.

---

*End of Phase 2E-3B diagnostic. No `lib/` changes in this phase.*