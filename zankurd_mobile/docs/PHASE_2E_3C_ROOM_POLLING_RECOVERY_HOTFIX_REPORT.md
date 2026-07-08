# Phase 2E-3C — Room Polling/Realtime Recovery Hotfix Report

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge`  
**Commit:** `0f296e3` — `fix: keep room lobby polling resilient after realtime events`  
**Context:** Supabase production verification PASS; client-side stuck-lobby recovery

---

## Exact Files Inspected

| File | Role |
|------|------|
| `lib/src/screens/room_screen.dart` | Polling + `subscribeRoomPlayers` handling |
| `test/widget_test.dart` | Room lobby diagnostic tests |
| `docs/PHASE_2E_3A_ROOM_FLOW_MAPPING_AUDIT.md` | Flow reference |
| `docs/PHASE_2E_3B_ROOM_SYNC_START_DIAGNOSTIC_REPORT.md` | Root cause analysis |
| `docs/SUPABASE_ROOM_DEPLOYMENT_VERIFICATION_GUIDE.md` | Production SQL PASS context |

---

## Exact Files Changed

| File | Change |
|------|--------|
| `lib/src/screens/room_screen.dart` | Polling/realtime recovery logic |
| `test/widget_test.dart` | `_StaleStreamPollRecoveryRepository` + recovery test |

**No other files modified.**

---

## Root Cause

`RoomScreen` called `_pausePolling()` on **every** `subscribeRoomPlayers` event. After the first realtime fire (including host-ready updates or stale partial reloads), REST polling stopped permanently. If that reload returned only 1 player, the host stayed at `room.players.length < 2` and the start button remained disabled — even with correct Supabase realtime/RLS.

---

## Exact Fix

| Before | After |
|--------|-------|
| Realtime event → always `_pausePolling()` | `_applyPlayerList()` → `_syncPollingForLobby(count)` |
| Polling never resumes after early realtime | Polling **continues** while `playerCount < 2` |
| Poll errors swallowed silently | `ErrorReporter.record` on poll failure |
| 60s throttle applied regardless of player count | Throttle only when `players.length >= 2` |

### New helpers in `room_screen.dart`

- `_applyPlayerList(players)` — `setState` + sync polling
- `_syncPollingForLobby(playerCount)` — pause only when `>= 2` or `quizOpened`; resume polling if `< 2` and timer null
- `_pollPlayersOnce()` — extracted poll tick with recovery logic

### Start button

**Unchanged:** `ready && !starting && room.players.length >= 2`  
**Unchanged:** host-only / guest-waiting UI

---

## Why This Is Safe

| Check | Reason |
|-------|--------|
| Narrow scope | Only lobby sync/polling in `RoomScreen` |
| Conservative API use | Polling stops once 2 players confirmed (same as “lobby ready”) |
| Supabase verified | SQL/RLS/realtime PASS — fix addresses client pause bug |
| No contract changes | Repository interface untouched |
| Regression tests | 339/339 pass including 3 lobby gate + 1 recovery test |

---

## What Was Not Changed

| Area | Status |
|------|--------|
| Supabase SQL / RPC | **Not touched** |
| Repository implementations | **Not touched** |
| Navigation / routes | **Not touched** |
| Room code input (`0eab7ec`) | **Not touched** |
| Matchmaking / quiz start flow | **Not touched** |
| Room UI redesign | **Not touched** |
| Start button enable formula | **Not touched** (only player list recovery improves count) |

---

## Confirmations

| Item | Confirmed |
|------|-----------|
| SQL not touched | Yes |
| Repository not touched | Yes |
| Navigation not touched | Yes |
| Room code input not touched | Yes |

---

## Tests Added / Updated

| Test | Purpose |
|------|---------|
| `room lobby keeps start disabled until two players are present` | Existing — still passes |
| `room lobby enables start after player stream adds a guest` | Existing — still passes |
| `room lobby recovers via polling when realtime player list stays stale` | **New** — stale stream + poll → 2 players → start enabled |

Test double: `_StaleStreamPollRecoveryRepository`

---

## Verification

### `dart analyze`

**Exit 0** — 10 info (`avoid_print` in preview tests); `lib/` clean.

### `flutter test --exclude-tags preview`

**Exit 0** — **339 / 339 passed**

---

## Risk Assessment

| Risk | Level |
|------|-------|
| Extra poll calls while waiting for guest | Low — 3s interval, stops at 2 players |
| Realtime + poll race double setState | Low — idempotent player list updates |
| Regression in landscape lobby test | Very low — 339/339 green |
| Host still stuck if REST also returns 1 row | Medium — would indicate RLS/data issue, not client pause |

**Overall:** **Low risk** — targeted recovery for confirmed client bug.

---

## Manual Two-Device Test Checklist

| # | Step | Pass criteria |
|---|------|---------------|
| 1 | Host creates room | 1 player shown |
| 2 | Guest joins by code | Guest sees 2 players |
| 3 | Host within 3–10s | Host count → 2, guest name visible |
| 4 | Start button | Enabled on host |
| 5 | Host taps start | Both reach quiz |
| 6 | Guest UI | Waiting message until start (unchanged) |
| 7 | Ready toggle | Still works (unchanged) |

---

## Next Recommended Step

1. **Manual two-device test** on production build with this commit.
2. If host still stuck at 1 after 10s, capture host `loadRoomPlayers` response (unlikely post-SQL PASS).
3. Optional follow-up: subtle “player joined” UI feedback (separate UI-only task).
4. Defer full room lobby redesign until sync confirmed on device.

---

*End of Phase 2E-3C polling recovery hotfix report.*