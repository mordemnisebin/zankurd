# Phase 2E-3A — Room Flow Mapping Audit

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge` @ `6755744`  
**Mode:** Inspection only — no code changes, no commit, no push

> **Path note:** Requested `lib/src/actions/room_actions.dart` does not exist. Actual file: `lib/src/screens/home/room_actions.dart` (wired from `home_screen.dart`).

---

## Verification

### `git status --short`

```
 M docs/screenshots/phase2b/design_tokens_preview.png
 M docs/screenshots/phase2b/hero_no_pattern.png
 M docs/screenshots/phase2b/hero_pattern.png
 M docs/screenshots/phase2b/home_after.png
?? docs/PHASE_2E_*.md, docs/SPIN_WHEEL_FULL_AUDIT.md, .tmp/*, test_output*.txt
```

No `lib/` changes staged or modified.

### `dart analyze`

**Exit 0** — 10 info (`avoid_print` in preview test files only); `lib/` clean.

### `flutter test --exclude-tags preview`

**Exit 0** — **335 passed / 0 failed**

---

## Exact Files Inspected

| File | Role |
|------|------|
| `lib/src/screens/room_screen.dart` | Lobby: subscriptions, polling, player list, start gate, quiz navigation |
| `lib/src/screens/home/room_actions.dart` | Home create/join button UI (callbacks only) |
| `lib/src/screens/home_screen.dart` | `_createOnlineRoom`, `_showJoinSheet`, `_openRoom` |
| `lib/src/screens/matchmaking_screen.dart` | Separate 1v1 queue flow (not private-room-by-code) |
| `lib/src/models/room.dart` | `GameRoom`, `RoomStatus`, `generateRoomCode()` |
| `lib/src/models/player.dart` | Player row model |
| `lib/src/data/zankurd_repository.dart` | Room API contract |
| `lib/src/data/supabase_zankurd_repository.dart` | Online create/join, streams, `startGame` RPC |
| `lib/src/data/mock_zankurd_repository.dart` | Mock room (4 players, static streams) |
| `supabase/online_multiplayer_ready.sql` | `join_room_by_code`, `start_room_game` RPCs |
| `supabase/add_realtime_room_tables.sql` | Realtime publication for `rooms` / `room_players` |
| `supabase/room_players_rls_fix.sql` | Cross-participant SELECT policies |

---

## Current Room Flow Summary

```
Home (RoomActions)
  ├─ "Oda Kur" ──► home_screen._createOnlineRoom()
  │                    └─ repo.createOnlineRoom()
  │                         ├─ INSERT rooms (host_id, code)
  │                         ├─ INSERT room_players (host, is_ready=true)
  │                         └─ return GameRoom(id, hostId, players[1])
  │
  └─ "Kodla Katıl" ──► home_screen._showJoinSheet()
                           └─ repo.joinOnlineRoom(code)
                                ├─ RPC join_room_by_code
                                ├─ INSERT room_players (guest, is_ready=false)
                                └─ return GameRoom(id, hostId, players[N])

Both paths ──► home_screen._openRoom() ──► RoomScreen(initialRoom)

RoomScreen lobby
  ├─ subscribeRoomPlayers ──► stream room_players → loadRoomPlayers
  ├─ subscribeRoomStatus  ──► stream rooms.status
  ├─ polling fallback     ──► loadRoomPlayers every 3s (pauses on realtime)
  ├─ show/share code      ──► header copy button (Clipboard + snackbar)
  ├─ participant list     ──► sorted _PlayerTile rows + count badge
  ├─ ready toggle         ──► updateReady(room, bool)
  ├─ start (host only)    ──► enabled when ready && players.length >= 2
  │       └─ startGame RPC → _navigateToQuiz()
  └─ guest wait UI        ──► subscribeRoomStatus active → _navigateToQuiz()
```

### Step-by-step mapping

| Step | Where | What happens |
|------|-------|--------------|
| **Create room** | `home_screen.dart` → `SupabaseZanKurdRepository.createOnlineRoom` | Inserts `rooms` + host `room_players`; returns `GameRoom` with `id`, `hostId`, 1 player |
| **Show/share code** | `room_screen.dart` header `TextButton.icon` | Displays `room.code`; tap copies to clipboard + snackbar. No deep-link or share sheet |
| **Join by code** | `home_screen._showJoinSheet` → `joinOnlineRoom` | Bottom sheet input → RPC `join_room_by_code` → navigates to `RoomScreen` with full player list |
| **Participant list / count** | `room_screen.dart` players `AppPanel` | `sorted.length` in header; `_PlayerTile` per player (name, ready state, score) |
| **Host sees guest** | `RoomScreen` subscriptions + poll | `subscribeRoomPlayers` reloads list; 3s `loadRoomPlayers` fallback if realtime silent |
| **Guest sees host** | Immediate on join + same subscriptions | `joinOnlineRoom` calls `_loadRoomPlayersById` before navigation; then live stream/poll |
| **Start button enablement** | `room_screen.dart:290` | `isHost && ready && !starting && room.players.length >= 2` |
| **Game start navigation** | Host: `_startGameHost` → `startGame` RPC → `_navigateToQuiz` | Guest: `subscribeRoomStatus` → `active` → `_navigateToQuiz` → `QuizScreen` push |

### `matchmaking_screen.dart` (out of private-room path)

Uses `matchmaking_queue` + auto-paired `room_id`. Loads players via `loadRoomPlayers` then opens quiz. **Not** the home "Oda Kur / Kodla Katıl" flow, but shares `GameRoom`, `loadRoomPlayers`, and `QuizScreen` navigation.

---

## Known Issues — Suspected Root Causes

### 1. Host does not clearly see friend joined

| Candidate | Category | Evidence |
|-----------|----------|----------|
| `room_players` not in `supabase_realtime` publication | **Realtime** | `add_realtime_room_tables.sql` documents this as root cause; stream never fires on join |
| RLS blocks host reading guest row in `room_players` | **Repository** | `room_players_rls_fix.sql` adds `is_room_participant()` — may be undeployed |
| Polling errors swallowed (`catch (_) {}`) | **Repository** | Host may stay at 1 player with no error surfaced |
| Realtime event pauses polling; reload returns stale/incomplete list | **Repository** | `_pausePolling()` on any stream hit; depends on `_loadRoomPlayersById` succeeding |
| No join toast/badge — only silent count/tile update | **UI** | User may not notice sync even when data arrives |
| Mock tests use 4 static players | **Repository** | Masks sync bugs in CI |

**Primary suspicion:** Realtime + RLS deployment gap, compounded by weak UI feedback.

---

### 2. Host cannot start after friend joins

| Candidate | Category | Evidence |
|-----------|----------|----------|
| `room.players.length` still 1 on host (Issue 1 downstream) | **Repository / Realtime** | Start gated at `>= 2` (`room_screen.dart:290`) |
| Host `ready` toggle off | **UI** | Button requires `ready == true` (defaults true; cleared on dispose) |
| `hostId` ≠ `currentUserId` — RPC rejects start | **Repository** | `start_room_game` checks `host_id = auth.uid()`; `isHost` fallback true when `hostId == null` |
| `startGame` RPC fails (no approved questions, network) | **Repository** | Snackbar shown; `starting` reset — user sees disabled or error state |
| Guest never navigates | **Navigation** | Only if `subscribeRoomStatus` misses `active` — secondary to start itself |

**Primary suspicion:** Start stays disabled because host player list never reaches 2 (sync issue), not because start logic is missing.

---

### 3. Room code input text hard to see / invisible

| Candidate | Category | Evidence |
|-----------|----------|----------|
| Hint text `textMutedColor` on green `fillColor` — low contrast | **UI** | `home_screen._showJoinSheet` lines 756–783; hint before typing |
| No explicit `fillColor` on field — relies on theme merge in bottom sheet | **UI** | Sheet uses `surfaceOf(context)` without auth-style `Theme` wrapper |
| Typed text style is explicit `textPrimaryColor` — should be readable | **UI** | Issue likely empty-state/hint, not entered text |
| Join sheet not using `StyledInput` pattern from Phase 2E auth | **UI** | Inconsistent input treatment |

**Primary suspicion:** UI contrast on hint/empty field state. Not realtime, repository, or navigation.

---

## Tests

### Found

| Test | Coverage |
|------|----------|
| `creates a room and opens the quiz flow` | Create → lobby → start → quiz (mock, 4 players) |
| `join by code opens the room code sheet` | Sheet opens with labels |
| `empty room code is validated locally` | Form validator blocks empty join |
| `home does not open a demo room when online room creation/join fails` | Error snackbars |
| `room lobby remains usable in landscape` | Lobby scroll/layout |
| `kurdish home room join action uses compact label` | KU button text |
| `Supabase local room shell does not include mock opponents` | Production shell has 1 player |
| `online room join uses the room-code RPC contract` | Source-level RPC check |
| `online multiplayer SQL patch defines required live RPCs` | SQL file contract |

### Missing

- Host player list updates when second player joins (stream or poll)
- Start button disabled at 1 player / enabled at 2 (online path)
- `subscribeRoomPlayers` / `subscribeRoomStatus` behavior
- Join sheet text contrast (golden or readability assertion)
- `hostId` / `isHost` mismatch edge case
- Two-client integration test

---

## Next Recommended Step

1. **Verify Supabase deployment** of `add_realtime_room_tables.sql` and `room_players_rls_fix.sql` against production — highest leverage for Issues 1 and 2.
2. **Reproduce on two devices** with logging around `loadRoomPlayers` poll results and `subscribeRoomPlayers` emissions before any code fix.
3. **Add one widget test** with a fake repository that emits player-list growth after delay to lock the `players.length >= 2` start gate.
4. **Defer UI redesign**; for Issue 3 only, a targeted join-sheet contrast fix can be scoped separately once sync is confirmed.

---

*End of Phase 2E-3A flow mapping audit. No app code modified.*