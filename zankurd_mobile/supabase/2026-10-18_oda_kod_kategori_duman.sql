-- Duman testi: 2026-10-18_oda_kod_kategori.sql UYGULANDIKTAN SONRA çalıştırılır.
--   supabase db query --linked -f supabase/2026-10-18_oda_kod_kategori_duman.sql
-- Her şey `begin; ... rollback;` içindedir: canlıya kalıcı hiçbir şey yazmaz.
-- Gerçek, şu an canlı odada olmayan 5 profili salt okunur seçer (kimlik
-- gömülü değil); 5'ten az boşta profil varsa ilgili adımlar 'SKIP' yazar.
-- Sonuç: smoke tablosu (ok = true olmayan satır varsa göçü uygulama).
begin;

create temp table smoke (step integer, check_name text, ok boolean, detail text)
  on commit drop;

do $t$
declare
  u uuid[];
  r json;
  rid uuid;
  code text;
  spaced text;
  n integer;
  easy integer;
  first_d integer;
  all_ids uuid[];
  picked uuid[];
  avg_easy numeric;
  avg_mid numeric;
  avg_hard numeric;
  bad_first integer := 0;
  i integer;
  cats uuid[];
  outside integer;
begin
  select array_agg(p.id) into u
  from (
    select p.id from public.profiles p
    where not exists (
      select 1 from public.room_players rp
      join public.rooms rr on rr.id = rp.room_id
      where rp.player_id = p.id and rp.left_at is null
        and rr.status in ('lobby', 'active')
    )
    order by p.created_at
    limit 5
  ) p;

  if u is null or cardinality(u) < 5 then
    insert into smoke values (0, 'yeterli boşta profil', false,
      'SKIP: 5 boşta profil gerekli');
    return;
  end if;

  -- 1) Eski 5 parametreli imza: tek kategori, ESKİ 'ZK-'+10 hex kod, category_id dolu.
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[1], 'role', 'authenticated')::text, true);
  r := public.create_online_room('Ziman', 20, 10, 0, 2);
  rid := (r->>'room_id')::uuid;
  code := r->>'code';
  insert into smoke values (1, 'eski imza: kod ZK-+10 hex', code ~ '^ZK-[0-9A-F]{10}$', code);
  insert into smoke select 1, 'eski imza: category_id dolu, category_ids boş',
    (category_id is not null and category_ids is null), null
    from public.rooms where id = rid;
  insert into smoke values (1, 'eski imza: etiket Ziman', r->>'category_name' = 'Ziman', r->>'category_name');

  -- 2) Eski biçimde: aynı kodla BİTMİŞ bir oda varken katılım AÇIK odayı çözer
  --    (küresel benzersizlik kalktı; biten oda katılımı ele geçirmez).
  insert into public.rooms (code, host_id, status, question_count, max_players, is_custom, ended_reason)
  values (code, u[1], 'finished', 10, 2, true, 'completed');
  spaced := lower(code);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[2], 'role', 'authenticated')::text, true);
  r := public.join_room_by_code(spaced);
  insert into smoke values (2, 'küçük harfli eski kodla katılım açık odayı çözer',
    (r->>'room_id')::uuid = rid, r->>'room_id');

  -- 3) Başlat: kolay ilk soru + zorluk dağılımı.
  update public.room_players set is_ready = true where room_id = rid;
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[1], 'role', 'authenticated')::text, true);
  perform public.start_room_game(rid);
  select count(*) into n from public.room_questions where room_id = rid;
  insert into smoke values (3, 'oda 10 soru aldı', n = 10, n::text);
  select q.difficulty into first_d
  from public.room_questions rq join public.questions q on q.id = rq.question_id
  where rq.room_id = rid and rq.question_index = 0;
  insert into smoke values (3, 'ilk soru kolay (<=2)', first_d <= 2, first_d::text);

  -- 4) v2 Karışık (boş dizi): category_id ve category_ids NULL, etiket Tevlihev.
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[3], 'role', 'authenticated')::text, true);
  r := public.create_online_room_v2(array[]::text[], 20, 10, 0, 2);
  rid := (r->>'room_id')::uuid;
  insert into smoke select 4, 'karışık: iki sütun NULL, etiket Tevlihev',
    (category_id is null and category_ids is null and r->>'category_name' = 'Tevlihev'),
    r->>'category_name' from public.rooms where id = rid;
  insert into smoke values (4, 'karışık: kod 6 rakam', (r->>'code') ~ '^[1-9][0-9]{5}$', r->>'code');
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[4], 'role', 'authenticated')::text, true);
  -- 6 rakamlı kod boşluklu yazılsa da çözülür.
  perform public.join_room_by_code(substr(r->>'code', 1, 3) || ' ' || substr(r->>'code', 4));
  update public.room_players set is_ready = true where room_id = rid;
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[3], 'role', 'authenticated')::text, true);
  perform public.start_room_game(rid);
  select count(distinct q.category_id) into n
  from public.room_questions rq join public.questions q on q.id = rq.question_id
  where rq.room_id = rid;
  insert into smoke values (4, 'karışık: birden çok kategoriden soru', n >= 2, n::text);

  -- 5) v2 çoklu (3 kategori): sorular yalnız seçilenlerden.
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[5], 'role', 'authenticated')::text, true);
  r := public.create_online_room_v2(array['Ziman', 'Dîrok', 'Çand'], 20, 5, 0, 4);
  rid := (r->>'room_id')::uuid;
  select category_ids into cats from public.rooms where id = rid;
  insert into smoke values (5, 'çoklu: category_ids 3 eleman, category_id NULL',
    cardinality(cats) = 3 and (select category_id is null from public.rooms where id = rid),
    r->>'category_name');
  perform set_config('request.jwt.claims',
    json_build_object('sub', u[1], 'role', 'authenticated')::text, true);
  -- u[1] önceki odada aktif; çoklu odayı yalnız host ile başlatmak için
  -- ikinci üye gerekir: u[2] ve u[1] meşgul olduğundan bu adım yalnız
  -- oluşturma/etiketi doğrular, başlatmayı 3. adımdaki yolla paylaşır.
  select count(*) into outside
  from public.categories c where c.id = any(cats) and not c.is_active;
  insert into smoke values (5, 'çoklu: seçilen kategoriler aktif', outside = 0, outside::text);

  -- 6) Bilinmeyen kategori reddedilir.
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', u[5], 'role', 'authenticated')::text, true);
    perform public.create_online_room_v2(array['YokBoyleKategori'], 20, 10, 0, 2);
    insert into smoke values (6, 'bilinmeyen kategori reddedilir', false, 'hata beklenirdi');
  exception when others then
    insert into smoke values (6, 'bilinmeyen kategori reddedilir',
      sqlerrm = 'Category is not available', sqlerrm);
  end;

  -- 7) Zorluk dağılımı: 10'luk 40 çekilişte ortalama (hedef ~6 / 3 / 1).
  select array_agg(id) into all_ids from public.questions where is_approved;
  avg_easy := 0; avg_mid := 0; avg_hard := 0;
  for i in 1..40 loop
    picked := public.weighted_question_pick(all_ids, '{}'::uuid[], 10);
    select count(*) filter (where d <= 2), count(*) filter (where d = 3),
           count(*) filter (where d >= 4)
      into easy, n, outside
    from (select q.difficulty d from unnest(picked) u(id)
          join public.questions q on q.id = u.id) s;
    avg_easy := avg_easy + easy; avg_mid := avg_mid + n; avg_hard := avg_hard + outside;
    select q.difficulty into first_d from public.questions q where q.id = picked[1];
    if first_d > 2 then bad_first := bad_first + 1; end if;
  end loop;
  insert into smoke values (7, 'ortalama kolay/orta/zor (10 soru)',
    avg_easy / 40 between 5.5 and 6.5
      and avg_mid / 40 between 2.5 and 3.5
      and avg_hard / 40 between 0.5 and 1.5,
    round(avg_easy / 40, 2) || ' / ' || round(avg_mid / 40, 2) || ' / ' || round(avg_hard / 40, 2));
  insert into smoke values (7, 'her çekilişte ilk soru kolay', bad_first = 0, bad_first::text);
  insert into smoke values (7, 'aday azsa dizi daralır, hata vermez',
    cardinality(public.weighted_question_pick(all_ids[1:3], '{}'::uuid[], 10)) = 3, null);
end
$t$;

select * from smoke order by step, check_name;

rollback;
