-- 2026-11-12_yonetim_paneli.sql geri alma.
-- UYARI: yönetici tabloları (denetim günlüğü, ödül defteri, moderasyon
-- durumu) SİLİNİR. Önce gerekiyorsa dışa aktar:
--   admin_audit_log, admin_reward_grants, admin_contributor_rewards,
--   user_moderation. Verilmiş jeton/rozetler geri alınmaz (profiles.coins ve
--   coin_transactions'a dokunulmaz).
begin;

drop trigger if exists trg_admin_push_suggestion on public.suggested_questions;
drop trigger if exists trg_admin_push_question_report on public.question_reports;
drop trigger if exists trg_admin_push_profile_report on public.profile_reports;

drop function if exists public.admin_enqueue_push();
drop function if exists public.admin_set_notify_pref(text, boolean);
drop function if exists public.admin_get_notify_prefs();
drop function if exists public.admin_moderate_user(uuid, text, integer, text);
drop function if exists public.admin_list_user_reports(integer);
drop function if exists public.admin_set_auto_reward(boolean);
drop function if exists public.admin_get_auto_reward();
drop function if exists public.admin_grant_reward(text, text, uuid, integer, text);
drop function if exists public.admin_list_reward_candidates(text, text);
drop function if exists public.admin_reward_contributor(uuid, integer, text);
drop function if exists public._admin_credit_coins(uuid, integer, text);
drop function if exists public.admin_list_contributors(integer);
drop function if exists public.admin_dismiss_question_reports(uuid);
drop function if exists public.admin_retire_question(uuid, text);
drop function if exists public.admin_fix_question(uuid, text, text[], integer, text);
drop function if exists public.admin_list_reported_questions(integer);
drop function if exists public.admin_review_suggestion(uuid, text, text, jsonb);
drop function if exists public.admin_list_suggestions(text, integer);
drop function if exists public.admin_list_audit(integer);
drop function if exists public.admin_get_stats();
drop function if exists public.admin_is_admin();
drop function if exists public.admin_log(text, text, text, jsonb);
drop function if exists public.admin_assert();

drop table if exists public.admin_notify_prefs;
drop table if exists public.admin_settings;
drop table if exists public.user_moderation;
drop table if exists public.admin_contributor_rewards;
drop table if exists public.admin_reward_grants;
drop table if exists public.admin_audit_log;
drop table if exists public.admins;

alter table public.profile_reports drop column if exists handled_at;

commit;
