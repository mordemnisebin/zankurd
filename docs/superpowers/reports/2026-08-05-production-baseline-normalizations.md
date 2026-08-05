# Production Baseline Normalizations — 2026-08-05

Source: verified logical schema backup at `/Users/kocer/Backups/zankurd/supabase-production-20260805-161408/schema.sql`.

The backup was previously compared with the read-only production public-schema snapshot. Application-object fingerprints matched for tables, parsed functions, types, indexes, constraints, policies, triggers, ACLs, `SECURITY DEFINER`, and public `search_path` clauses.

## Applied normalizations

1. Removed PostgreSQL dump-session wrappers `\\restrict ...` and `\\unrestrict ...`. They are `pg_dump` client directives, not database objects, and are not valid migration SQL.
2. Removed `CREATE SCHEMA public`, `ALTER SCHEMA public OWNER TO pg_database_owner`, and the standard public-schema comment. Supabase creates and owns the `public` schema before migrations; replaying these dump-header statements would be environment-specific and can fail on an already initialized Supabase database.
3. Removed the three `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin` blocks for sequences, functions, and tables. A clean local Supabase replay proved these platform-owner ACL statements are not executable by the migration role (`permission denied to change default privileges`). They govern future objects owned by Supabase’s internal platform role, not the application’s existing object grants; the `postgres` default-privilege blocks and all concrete application ACLs remain.

## Explicitly preserved

- All 37 application tables, 2 application enum types, 69 raw function declarations, 49 policies, 8 triggers, indexes, constraints, grants, `SECURITY DEFINER`, and `search_path` clauses.
- Application foreign-key references to `auth.users` and function references to `auth`/`storage`; the local replay environment supplies platform stubs, while the baseline does not copy platform internals.
- Existing realtime-managed application table definitions. Realtime publication membership remains a separately verified platform-managed boundary.

No application object was silently excluded. The generated baseline is `zankurd_mobile/supabase/baselines/20260801000000_production_baseline.sql`; it is kept outside the migration execution root so it cannot override dated migration definitions.
