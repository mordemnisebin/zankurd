# Supabase Setup

The app can now run in two modes:

- No Supabase config: mock local mode.
- With Supabase config: `Supabase.initialize()` runs and `SupabaseZanKurdRepository` is available.

Supabase's current Flutter docs initialize the client with `Supabase.initialize(url: ..., publishableKey: ...)`, and this project follows that shape.

## 1. Create Project

1. Go to `https://supabase.com/dashboard`.
2. Create a new project.
3. Save the database password somewhere private.
4. Wait until the project is provisioned.

## 2. Get App Keys

In Supabase:

1. Open the project.
2. Go to `Project Settings`.
3. Open `API`.
4. Copy:
   - Project URL
   - Publishable key, also called anon/public key in some screens

Never put the service role key in the mobile app.

## 3. Run SQL Schema

Open `SQL Editor` in Supabase and run the schema from the web prototype:

```text
C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd\supabase\schema.sql
```

That creates profiles, categories, questions, rooms, room players, answers, reports, favorites, and coin transactions.

## 4. Seed Starter Data

After running the schema, insert starter categories and approved questions. A minimal seed can be:

```sql
insert into public.categories (name, slug) values
  ('Ziman', 'ziman'),
  ('Çand', 'cand'),
  ('Dîrok', 'dirok'),
  ('Edebiyat', 'edebiyat'),
  ('Cografya', 'cografya'),
  ('Muzîk', 'muzik')
on conflict (slug) do nothing;
```

Questions should be inserted with `is_approved = true` before they appear in the app.

## 5. Run App With Supabase

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

The app also accepts web-style names copied from Supabase/Next.js examples:

```bash
flutter run --dart-define=NEXT_PUBLIC_SUPABASE_URL=... --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
flutter build apk --release --dart-define=NEXT_PUBLIC_SUPABASE_URL=... --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
```

## 6. What Is Already Coded

- `lib/src/config/app_config.dart`: reads Dart defines.
- `lib/main.dart`: initializes Supabase when config exists.
- `lib/src/data/supabase_zankurd_repository.dart`:
  - anonymous sign-in
  - profile upsert
  - approved question fetch
  - remote room create
  - remote room join
  - room broadcast subscription

## 7. Next Code Hook

The UI currently still uses the local synchronous room/quiz flow so development is not blocked. The next hook is changing:

- `HomeScreen._openRoom`
- `HomeScreen._showJoinSheet`
- `RoomScreen._startGame`
- `QuizScreen._answer`

to call the async Supabase methods when the repository is `SupabaseZanKurdRepository`.
