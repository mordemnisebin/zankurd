# ZanKurd

Kurmanci-first live quiz app prototype.

## What is included

- React + Vite + TypeScript frontend.
- Responsive dashboard-style MVP screen.
- Private room, player list, active question, joker, category, and tournament UI.
- Product plan in `docs/PRODUCT_PLAN.md`.
- Supabase starter schema in `supabase/schema.sql`.

## Local development

```bash
npm install
npm run dev
```

## Production build

```bash
npm run build
```

## Next implementation steps

- Add Supabase client and environment variables.
- Implement auth and profile creation.
- Replace mock questions with approved questions from Supabase.
- Implement room creation, join by code, and Realtime Presence.
- Move answer validation and scoring into backend functions.
- Add admin panel for question moderation.
