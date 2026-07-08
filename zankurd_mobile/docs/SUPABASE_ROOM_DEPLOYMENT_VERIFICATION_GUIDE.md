# Supabase Room Deployment Verification Guide

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge`  
**Context:** Phase 2E-3B room sync/start diagnostic  
**Purpose:** Paste-ready SQL for Supabase SQL Editor — verify production before room sync hotfix

> **Disclaimer:** This guide does **not** confirm your production database is correct. Run every query and compare results yourself. No app code or SQL files were modified to produce this guide.

**Related reports:**
- `docs/PHASE_2E_3A_ROOM_FLOW_MAPPING_AUDIT.md`
- `docs/PHASE_2E_3B_ROOM_SYNC_START_DIAGNOSTIC_REPORT.md`

**Recommended patch order (if fixes needed):**
1. `supabase/online_multiplayer_ready.sql`
2. `supabase/room_players_rls_fix.sql`
3. `supabase/online_room_policies.sql`
4. `supabase/add_realtime_room_tables.sql`

---

## Quick Reference — What Breaks If Missing

| Missing piece | Symptom |
|---------------|---------|
| Realtime publication (`rooms`, `room_players`) | Host may not get live join events; relies on 3s polling only |
| `is_room_participant` + read policies | Host `loadRoomPlayers` returns only self → start button stays disabled |
| `join_room_by_code` RPC | Guest cannot join by code |
| `start_room_game` RPC | Host tap fails / snackbar error |
| `room_players` unique `(room_id, player_id)` | Join upsert may fail or duplicate rows |

---

## 1. Realtime Publication Check

### Query 1A — List room tables in `supabase_realtime`

```sql
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename IN ('rooms', 'room_players')
ORDER BY tablename;
```

| Result | Verdict |
|--------|---------|
| **2 rows:** `rooms` and `room_players` | **PASS** |
| **1 row** (only one table) | **FAIL** — missing table not listed |
| **0 rows** | **FAIL** — realtime not configured for private rooms |

**If FAIL → apply:** `supabase/add_realtime_room_tables.sql`

---

### Query 1B — Confirm publication exists

```sql
SELECT pubname FROM pg_publication WHERE pubname = 'supabase_realtime';
```

| Result | Verdict |
|--------|---------|
| **1 row** | **PASS** (publication exists) |
| **0 rows** | **FAIL** — Supabase realtime not set up (unusual on hosted Supabase) |

---

## 2. RLS Helper Check

### Query 2A — `is_room_participant` function exists

```sql
SELECT
  n.nspname AS schema,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'is_room_participant';
```

| Result | Verdict |
|--------|---------|
| **1 row**, `arguments = p_room_id uuid`, `security_definer = true` | **PASS** |
| **0 rows** | **FAIL** — host cannot read other participants via RLS |

**If FAIL → apply:** `supabase/room_players_rls_fix.sql`

---

### Query 2B — Execute grant on helper (authenticated)

```sql
SELECT has_function_privilege(
  'authenticated',
  'public.is_room_participant(uuid)',
  'EXECUTE'
) AS authenticated_can_execute;
```

| Result | Verdict |
|--------|---------|
| `authenticated_can_execute = true` | **PASS** |
| `false` | **FAIL** — clients cannot evaluate participant policy |

**If FAIL → apply:** `supabase/room_players_rls_fix.sql` (includes `GRANT EXECUTE`)

---

## 3. RLS Policy Check

### Query 3A — All policies on `room_players` and `rooms`

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('room_players', 'rooms')
ORDER BY tablename, policyname;
```

Review output manually. Required policies:

| Table | Policy name (expected) | Command | Verdict |
|-------|------------------------|---------|---------|
| `room_players` | `Players read room membership` | `SELECT` | **PASS** if present and `using` contains `is_room_participant` |
| `room_players` | `Players update their own room membership` | `UPDATE` | **PASS** if present and restricts `player_id = auth.uid()` |
| `rooms` | `Room participants can read rooms` | `SELECT` | **PASS** if present and `using` contains `is_room_participant` or `host_id` |
| `rooms` | `Hosts can update their own rooms` | `UPDATE` | **PASS** if present and restricts `host_id = auth.uid()` |

| Result | Verdict |
|--------|---------|
| All four policies present with expected logic | **PASS** |
| `Players read room membership` missing or no `is_room_participant` | **FAIL** — host sees only self |
| `Room participants can read rooms` missing | **FAIL** — status stream may break |
| Update policies missing | **FAIL** — ready toggle or host room update fails |

**If read policies FAIL → apply:** `supabase/room_players_rls_fix.sql`  
**If update policies FAIL → apply:** `supabase/online_room_policies.sql`

---

### Query 3B — Targeted policy name check

```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND (
    (tablename = 'room_players' AND policyname IN (
      'Players read room membership',
      'Players update their own room membership'
    ))
    OR (tablename = 'rooms' AND policyname IN (
      'Room participants can read rooms',
      'Hosts can update their own rooms'
    ))
  )
ORDER BY tablename, policyname;
```

| Result | Verdict |
|--------|---------|
| **4 rows** with correct names | **PASS** |
| **< 4 rows** | **FAIL** — note which names are missing from Query 3B output |

---

### Query 3C — RLS enabled on tables

```sql
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('rooms', 'room_players');
```

| Result | Verdict |
|--------|---------|
| Both tables `rls_enabled = true` | **PASS** |
| Either `false` | **WARN/FAIL** — policies may not enforce |

---

## 4. RPC Check

### Query 4A — Required RPC functions exist

```sql
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'join_room_by_code',
    'start_room_game',
    'finish_room_game',
    'submit_answer'
  )
ORDER BY p.proname, arguments;
```

| Function | Expected signature (approx.) | Verdict |
|----------|------------------------------|---------|
| `join_room_by_code` | `p_code text` | **PASS** if row exists |
| `start_room_game` | `p_room_id uuid` | **PASS** if row exists |
| `finish_room_game` | `p_room_id uuid` | **PASS** if row exists |
| `submit_answer` | `p_room_id uuid, p_question_id uuid, p_selected_option text, ...` | **PASS** if row exists |

| Result | Verdict |
|--------|---------|
| **4 distinct function names** returned | **PASS** |
| **< 4 names** | **FAIL** — note missing RPCs |

**If FAIL → apply:** `supabase/online_multiplayer_ready.sql`

---

### Query 4B — Authenticated execute grants

```sql
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN (
    'join_room_by_code',
    'start_room_game',
    'finish_room_game',
    'submit_answer'
  )
  AND grantee = 'authenticated'
ORDER BY routine_name;
```

| Result | Verdict |
|--------|---------|
| **EXECUTE** grant for each of the 4 RPCs | **PASS** |
| Missing grant on any RPC | **FAIL** — app calls will permission-deny |

**If FAIL → apply:** `supabase/online_multiplayer_ready.sql`

---

## 5. Constraint / Index Check

### Query 5A — `room_players` unique constraint on `(room_id, player_id)`

```sql
SELECT
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name = 'room_players'
  AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
ORDER BY tc.constraint_name, kcu.ordinal_position;
```

Also check unique indexes:

```sql
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'room_players'
  AND indexdef ILIKE '%UNIQUE%';
```

| Result | Verdict |
|--------|---------|
| UNIQUE or PRIMARY KEY spanning **both** `room_id` and `player_id` | **PASS** — supports `ON CONFLICT (room_id, player_id)` in `join_room_by_code` |
| Only single-column unique / no composite unique | **FAIL** — join upsert may break |
| No unique index at all | **FAIL** |

> If base schema uses a named PK on `(room_id, player_id)`, Query 5A will show a PRIMARY KEY — that counts as **PASS**.

---

### Query 5B — `rooms.code` uniqueness

```sql
SELECT
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name = 'rooms'
  AND kcu.column_name = 'code'
  AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY');
```

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'rooms'
  AND indexdef ILIKE '%code%'
  AND indexdef ILIKE '%UNIQUE%';
```

| Result | Verdict |
|--------|---------|
| UNIQUE constraint or unique index on `code` | **PASS** — supports app retry on `23505` |
| No unique on `code` | **WARN** — room code collisions possible; create may still work |

---

## 6. Optional Sanity Queries (Post-Verification)

Run after policies/RPCs pass, during or after a manual two-device test.

### Query 6A — Recent lobby rooms

```sql
SELECT id, code, host_id, status, created_at
FROM public.rooms
WHERE status = 'lobby'
ORDER BY created_at DESC
LIMIT 10;
```

Useful to confirm rooms are being created.

---

### Query 6B — Player count for a specific room

Replace `<ROOM_UUID>` with a room `id` from Query 6A:

```sql
SELECT room_id, player_id, is_ready, joined_at
FROM public.room_players
WHERE room_id = '<ROOM_UUID>'
ORDER BY joined_at;
```

| Result | Verdict |
|--------|---------|
| **2 rows** after guest joins | **PASS** at DB level |
| **1 row** after guest claims to have joined | **FAIL** — join RPC or insert failed |

> This query runs as **service role / SQL editor** (bypasses RLS). It shows ground truth regardless of client RLS.

---

### Query 6C — Approved questions available for `start_room_game`

```sql
SELECT count(*) AS approved_question_count
FROM public.questions
WHERE is_approved = true;
```

| Result | Verdict |
|--------|---------|
| `approved_question_count > 0` | **PASS** — `start_room_game` can seed questions |
| `0` | **FAIL** — start RPC raises "No approved questions available" |

---

## 7. Failure → Remediation Map

| Failed check | Apply this file (Supabase SQL Editor) |
|--------------|---------------------------------------|
| Realtime publication (Section 1) | `supabase/add_realtime_room_tables.sql` |
| `is_room_participant` or participant SELECT policies (Section 2–3) | `supabase/room_players_rls_fix.sql` |
| Ready toggle / host room UPDATE policies (Section 3) | `supabase/online_room_policies.sql` |
| RPCs missing or not granted (Section 4) | `supabase/online_multiplayer_ready.sql` |
| Multiple sections failed | Apply in order: `online_multiplayer_ready.sql` → `room_players_rls_fix.sql` → `online_room_policies.sql` → `add_realtime_room_tables.sql` |

**After applying patches:** Re-run all queries in Sections 1–5.

---

## 8. Manual Two-Device Test Checklist

Run **only after** Sections 1–5 pass (or after applying fixes and re-verifying).

| # | Step | Host | Guest | Pass criteria |
|---|------|------|-------|---------------|
| 1 | Auth | Sign in (stable account) | Sign in (different account) | Both have profiles / display names |
| 2 | Create | Tap **Oda Kur** | — | Lobby opens; code visible; **1 player** in list |
| 3 | Share code | Copy code | — | — |
| 4 | Join | — | **Kodla Katıl** → enter code | Guest lobby shows **2 players** (host + guest) |
| 5 | Host sync | Wait 3s, then 10s | — | Host player count → **2**; guest name appears |
| 6 | Start gate | — | — | Host **Yarışı Başlat** enabled; min-players warning gone |
| 7 | Guest UI | — | — | Guest sees host-waiting message (not start button) |
| 8 | Start | Tap **Yarışı Başlat** | — | Both navigate to quiz |
| 9 | DB spot-check | Run Query 6B with room UUID | — | 2 rows in `room_players` |
| 10 | Failure log | If step 5 fails | — | Re-run Sections 1–3; capture host REST row count |

### Failure interpretation

| Failed step | Likely cause |
|-------------|--------------|
| 4 (guest sees 1 player) | `join_room_by_code` / guest RLS |
| 5 (host stays at 1) | Realtime publication, `is_room_participant`, or client polling pause |
| 6 (button disabled, count is 2) | Client UI state — investigate after DB confirms 2 rows |
| 8 (snackbar on start) | `start_room_game` auth, empty question pool (Query 6C), or network |

---

## 9. What This Guide Does Not Verify

- Client-side polling pause behavior (`room_screen.dart`)
- Network latency or mobile background restrictions
- Anonymous vs email auth `hostId` / `currentUserId` mismatch
- Matchmaking queue flow (separate from private room-by-code)

If SQL verification **passes** but step 5 **fails**, proceed to narrow **client sync hotfix** per `PHASE_2E_3B_ROOM_SYNC_START_DIAGNOSTIC_REPORT.md` — do not redesign the room UI yet.

---

*End of Supabase room deployment verification guide.*