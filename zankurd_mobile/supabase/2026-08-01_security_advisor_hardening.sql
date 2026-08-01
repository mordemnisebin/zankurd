-- Supabase advisor bulguları: görünüm, storage listeleme ve anon RPC yüzeyi.

begin;

-- Alt tabloların kendi RLS kurallarını da görünüm sorgularında uygula.
alter view public.quiz_public_questions set (security_invoker = true);
alter view public.leaderboard_entries set (security_invoker = true);

-- Avatarlar public bucket üzerinden URL ile okunabilir; object listesi herkese
-- açık olmamalı.
drop policy if exists "Avatar photos are publicly readable" on storage.objects;

-- Uygulama önce anonim oturum açıyor; bu RPC'ler yalnız authenticated oturum
-- sonrasında çağrılmalı. Trigger/cron fonksiyonları da istemci anon rolünden
-- doğrudan çalıştırılabilir olmamalı.
revoke execute on function public.accept_friend_request(uuid) from public, anon;
revoke execute on function public.add_friend(uuid, text) from public, anon;
revoke execute on function public.assign_player_tag() from public, anon;
revoke execute on function public.cleanup_stale_rooms() from public, anon;
revoke execute on function public.enforce_chat_moderation() from public, anon;
revoke execute on function public.enforce_current_room_question() from public, anon;
revoke execute on function public.finalize_weekly_league(date) from public, anon;
revoke execute on function public.get_leaderboard(integer, integer) from public, anon;
revoke execute on function public.get_my_league_state() from public, anon;
revoke execute on function public.get_tournament_bracket() from public, anon;
revoke execute on function public.is_room_participant(uuid) from public, anon;
revoke execute on function public.join_matchmaking(text) from public, anon;
revoke execute on function public.join_room_by_code(text) from public, anon;
revoke execute on function public.join_tournament() from public, anon;
revoke execute on function public.log_analytics_event(text, jsonb) from public, anon;
revoke execute on function public.mark_lesson_completed(uuid) from public, anon;
revoke execute on function public.protect_paid_profile_cosmetics() from public, anon;
revoke execute on function public.reject_friend_request(uuid) from public, anon;
revoke execute on function public.report_question(text) from public, anon;
revoke execute on function public.rls_auto_enable() from public, anon;
revoke execute on function public.save_tournament_progress(text, integer, integer, text[]) from public, anon;
revoke execute on function public.sync_mission_completion(text, integer, integer) from public, anon;

commit;
