-- start_room_game: sertleştirilmiş sürümü tarihli göçe al (idempotent).
--
-- ## Niçin
--
-- Bu fonksiyon YALNIZ tarihsiz iki dosyada tanımlıydı: `online_game_sync.sql`
-- ve `online_multiplayer_ready.sql`. İkisi tek bir satırda ayrılıyordu —
-- `online_multiplayer_ready` sürümü `set search_path = public` taşıyor,
-- öteki taşımıyor.
--
-- `search_path` sabitlenmemiş bir `security definer` fonksiyonu, çağıranın
-- arama yolunu miras alır: aynı adı taşıyan sahte bir tablo ya da fonksiyon
-- gerçek olanın önüne geçebilir. Depodaki bütün sertleştirilmiş göçler bu
-- yüzden `set search_path` yazıyor.
--
-- Sorun, iki dosyanın da TARİHSİZ olmasıydı. Klasörü alfabetik sırayla
-- çalıştıran biri için `online_game_sync.sql` (korumasız) `2026-*` ile
-- başlayan her göçten SONRA gelir ve korumalı sürümün üzerine yazar.
-- Ama ikisi de arşive alınamıyordu, çünkü `start_room_game` için tek
-- kaynak onlardı (2026-07-31 denetimi).
--
-- Bu göç o düğümü çözer: korumalı sürüm artık tarihli bir dosyada
-- yaşıyor, dolayısıyla iki tarihsiz dosya da `supabase/archive/`e
-- taşınabildi.
--
-- ## Uygulanması
--
-- Canlıda hangi sürümün durduğundan bağımsız olarak güvenle çalıştırılır:
-- `create or replace` ve gövde, `online_multiplayer_ready.sql` içindeki
-- korumalı sürümün birebir aynısı. Zaten korumalı sürüm yüklüyse bu göç
-- hiçbir şeyi değiştirmez.

begin;

create or replace function public.start_room_game(
  p_room_id uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  v_room public.rooms%rowtype;
  v_question_count integer;
begin
  v_player_id := auth.uid();
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id;

  if not found then
    raise exception 'Room not found';
  end if;

  if v_room.host_id <> v_player_id then
    raise exception 'Only the host can start this room';
  end if;

  if not exists (
    select 1
    from public.room_questions
    where room_id = p_room_id
  ) then
    insert into public.room_questions (
      room_id,
      question_id,
      question_index,
      started_at
    )
    select
      p_room_id,
      picked.id,
      row_number() over (order by picked.random_order)::integer - 1,
      case
        when row_number() over (order by picked.random_order) = 1 then now()
        else null
      end
    from (
      select q.id, random() as random_order
      from public.questions q
      where q.is_approved = true
        and (v_room.category_id is null or q.category_id = v_room.category_id)
      order by random_order
      limit v_room.question_count
    ) picked;
  end if;

  select count(*)::integer into v_question_count
  from public.room_questions
  where room_id = p_room_id;

  if v_question_count = 0 then
    raise exception 'No approved questions available for this room';
  end if;

  update public.rooms
  set
    status = 'active',
    current_question_index = 0,
    started_at = coalesce(started_at, now())
  where id = p_room_id;

  return json_build_object(
    'status', 'active',
    'question_count', v_question_count
  );
end;
$$;

revoke all on function public.start_room_game(uuid) from public, anon;
grant execute on function public.start_room_game(uuid) to authenticated;

commit;
