-- SECURITY DEFINER ve veri erişen public fonksiyonlarda role-mutable
-- search_path kullanma. Fonksiyon gövdeleri mevcut haliyle korunur.

begin;

alter function public.accept_friend_request(uuid) set search_path = public;
alter function public.add_friend(uuid, text) set search_path = public;
alter function public.chat_message_is_clean(text) set search_path = public;
alter function public.freeze_player_tag() set search_path = public;
alter function public.generate_player_tag() set search_path = public;
alter function public.get_contest_leaderboard(uuid, integer) set search_path = public;
alter function public.get_today_contest() set search_path = public;
alter function public.league_tier_for_rank(integer) set search_path = public;
alter function public.league_week_start(timestamp with time zone) set search_path = public;
alter function public.list_friends() set search_path = public;
alter function public.list_pending_friend_requests() set search_path = public;
alter function public.load_lesson(uuid) set search_path = public;
alter function public.load_lesson_slides(uuid) set search_path = public;
alter function public.load_lessons_by_category(text) set search_path = public;
alter function public.log_analytics_event(text, jsonb) set search_path = public;
alter function public.mark_lesson_completed(uuid) set search_path = public;
alter function public.profiles_client_write_guard() set search_path = public;
alter function public.reject_friend_request(uuid) set search_path = public;
alter function public.room_players_client_write_guard() set search_path = public;
alter function public.save_tournament_progress(text, integer, integer, text[]) set search_path = public;
alter function public.sync_mission_completion(text, integer, integer) set search_path = public;

commit;
