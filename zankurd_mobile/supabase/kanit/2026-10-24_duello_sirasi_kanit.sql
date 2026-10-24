-- Kanıt betiği: 2026-10-24_duello_sirasi.sql (+ _cron.sql), bulgular a..o:
-- a 24 saat · b/c/d hükmen, davetli ve rakipsiz düz expired · e hatırlatma tek ·
-- f hükmen bildirimi · g dönüşte yarım soru yanlış, sonrakiler temiz ·
-- h liste alanları · i cron · j süre dolunca cevap reddi · k/l/m soru sunumu
-- (başlangıç değişmez, 30 sn gecikme yanlış, sıra dışı indeks) · n hükmen XP
-- sunucuda, claim çift vermez · o ardışık expire'da hatırlatma tek ·
-- p engelli çiftte normal sonuç push'u yok · q ödenmemiş hükmen XP'si yeniden
-- denenir · r sıra dışı cevap indeksi reddi.
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `durum`: SONRA-OK (gozlenen = beklenen_sonra), ONCE-DURUMU (gozlenen =
-- beklenen_once; göç henüz yok), BEKLENMEDIK (ikisi de değil). Bir adım hata
-- verirse satırda 'HATA: ...' görünür (diğer adımlar sürer; hatalı adım kendi
-- savepoint'inde geri alınır). Yeni sütun yoksa ilgili gözlem 'kolon yok'
-- yazar, hata vermez (dinamik SQL).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_sirasi_kanit.sql
--
-- Hiçbir auth.users satırı eklenmez: gerçek profillerden açık/eşleşmiş
-- düellosu olmayan altısı seçilir; kimlik set_config('request.jwt.claims')
-- ile taklit edilir. Düello, sonuç ve cevap satırlarını bu işlem kurar,
-- rollback hepsini siler.
-- UYARI: expire_async_duels() işlem içinde BÜTÜN canlı süresi geçmiş
-- düellolara da dokunur (ve onlar için push_outbox satırı yazar); hepsi
-- rollback ile geri alınır. Betik birkaç saniyede biter. Push sayımı yalnız
-- bu işlemde (created_at >= now()) ve yalnız seçilen altı profil için yapılır.
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid) on commit drop;
create temp table _f (k text, id uuid) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id
from (
  select pr.id
  from public.profiles pr
  where not exists (
    select 1 from public.async_duels d
    where d.status in ('open', 'matched')
      and pr.id in (d.creator_id, d.opponent_id, d.invited_id)
  )
  order by pr.id
  limit 6
) p;

do $$
begin
  if (select count(*) from _p) < 6 then
    raise exception 'kanit: açık düellosu olmayan en az 6 profil gerekli';
  end if;
end $$;

-- Yeni sütun yoksa 'kolon yok' (HATA değil).
create function pg_temp.kaybeden(p_duel uuid) returns text
language plpgsql as $f$
declare v text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'async_duels'
      and column_name = 'forfeit_loser_id'
  ) then
    return 'kolon yok';
  end if;
  execute 'select coalesce(forfeit_loser_id::text, ''null'') from public.async_duels where id = $1'
    into v using p_duel;
  return v;
end $f$;

-- Kullanıcı numarası -> 'a'/'b'... etiketi için kısa yol.
create function pg_temp.uid(p_n int) returns uuid
language sql as $f$ select id from _p where n = p_n $f$;

-- Sorulu düello satırı kurar; kimlik döner.
create function pg_temp.duello(
  p_creator uuid, p_opp uuid, p_invited uuid, p_status text,
  p_created interval, p_expires interval, p_code text default null
) returns uuid
language plpgsql as $f$
declare v_q uuid[]; v_id uuid;
begin
  select array_agg(id) into v_q from (
    select id from public.questions where is_approved = true limit 7
  ) q;
  insert into public.async_duels (
    question_ids, creator_id, opponent_id, invited_id, status,
    matched_at, created_at, expires_at, challenge_code
  ) values (
    v_q, p_creator, p_opp, p_invited, p_status,
    case when p_opp is not null then now() - p_created else null end,
    now() - p_created, now() + p_expires, p_code
  ) returning id into v_id;
  return v_id;
end $f$;

create function pg_temp.bitir(p_duel uuid, p_player uuid) returns void
language sql as $f$
  insert into public.async_duel_results (duel_id, player_id, correct_count, total_ms)
  values (p_duel, p_player, 5, 60000)
$f$;

-- ---------------------------------------------------------------- (a)
-- Yeni düello (create_async_duel_challenge, kullanıcı 5): pencere 24 saat.
do $$
declare
  u uuid := pg_temp.uid(5);
  v jsonb; v_h numeric;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  v := public.create_async_duel_challenge(null, null);
  select round(extract(epoch from (expires_at - created_at)) / 3600, 2)
  into v_h from public.async_duels where id = (v->>'duel_id')::uuid;
  insert into _kanit values (1, '(a) yeni düello expires_at - created_at (saat)',
    '48.00', '24.00', v_h::text);
exception when others then
  insert into _kanit values (1, '(a)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- kurulum
-- Kullanıcılar: 1 = yaratıcı, 2 = girmiş rakip (bitirmedi), 3 = kabul
-- etmemiş davetli, 4 = hatırlatılacak rakip, 5/6 = (a)/(g).
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  x uuid;
begin
  -- (b)/(f): eşleşmiş, yaratıcı bitirdi, rakip bitirmedi, süre geçti.
  x := pg_temp.duello(a, b, null, 'matched', interval '25 hours', interval '-1 minute');
  perform pg_temp.bitir(x, a);
  insert into _f values ('forfeit', x);
  -- (c): kabul edilmemiş arkadaş daveti, süre geçti.
  x := pg_temp.duello(a, null, c, 'open', interval '25 hours', interval '-1 minute', 'DKANTXPA2');
  perform pg_temp.bitir(x, a);
  insert into _f values ('davet', x);
  -- (d): rakipsiz rastgele düello, süre geçti.
  x := pg_temp.duello(a, null, null, 'open', interval '25 hours', interval '-1 minute');
  perform pg_temp.bitir(x, a);
  insert into _f values ('rakipsiz', x);
  -- (e): 3 saat kaldı, rakip (4) bitirmedi.
  x := pg_temp.duello(a, d, null, 'matched', interval '21 hours', interval '3 hours');
  perform pg_temp.bitir(x, a);
  insert into _f values ('hatirlat', x);
exception when others then
  insert into _kanit values (0, 'kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- expire #1
do $$
declare
  a uuid := pg_temp.uid(1); b uuid := pg_temp.uid(2);
  c uuid := pg_temp.uid(3); d uuid := pg_temp.uid(4);
  v_forfeit uuid := (select id from _f where k = 'forfeit');
  v_davet uuid := (select id from _f where k = 'davet');
  v_rakipsiz uuid := (select id from _f where k = 'rakipsiz');
  v_hat uuid := (select id from _f where k = 'hatirlat');
  v_row jsonb; v_n int; s text;
  v_xp0 int; v_xp1 int; v_xp2 int;
begin
  select coalesce(xp, 0) into v_xp0 from public.profiles where id = a;
  perform public.expire_async_duels();
  select coalesce(xp, 0) into v_xp1 from public.profiles where id = a;

  -- (b) kaybeden = bitirmeyen rakip; kazanan için outcome win.
  s := pg_temp.kaybeden(v_forfeit);
  insert into _kanit values (2, '(b1) forfeit_loser_id = bitirmeyen rakip',
    'kolon yok', 'bitirmeyen',
    case when s = b::text then 'bitirmeyen' else s end);

  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  select r into v_row from public.list_my_async_duels() r
  where r->>'duel_id' = v_forfeit::text;
  insert into _kanit values (3, '(b2) kazanan (bitiren) için list outcome',
    'null', 'win', coalesce(v_row->>'outcome', 'null'));

  -- (c) kabul edilmemiş davet: hükmen yok, düz expired.
  insert into _kanit values (4, '(c) kabul edilmemiş davet: durum / kaybeden',
    'expired/kolon yok', 'expired/null',
    (select status from public.async_duels where id = v_davet)
      || '/' || pg_temp.kaybeden(v_davet));

  -- (d) rakipsiz rastgele düello: düz expired.
  insert into _kanit values (5, '(d) rakipsiz rastgele düello: durum / kaybeden',
    'expired/kolon yok', 'expired/null',
    (select status from public.async_duels where id = v_rakipsiz)
      || '/' || pg_temp.kaybeden(v_rakipsiz));

  -- (e1) ≤4 sa kala bitirmemiş rakibe (4) async_duel_turn.
  select count(*) into v_n from public.push_outbox
  where to_user_id = d and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (6, '(e1) hatırlatma satırı (kullanıcı 4, ilk expire)',
    '0', '1', v_n::text);
  -- Bitirmiş yaratıcıya hatırlatma gitmez (kontrol).
  select count(*) into v_n from public.push_outbox
  where to_user_id = a and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (7, '(e0) bitirmiş yaratıcıya hatırlatma yok (kontrol)',
    '0', '0', v_n::text);

  -- (f) hükmen sonuç iki tarafa async_duel_result.
  select count(*) into v_n from public.push_outbox
  where to_user_id = a and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (8, '(f1) kazanana async_duel_result', '0', '1', v_n::text);
  select count(*) into v_n from public.push_outbox
  where to_user_id = b and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (9, '(f2) kaybedene async_duel_result', '0', '1', v_n::text);
  -- Davetliye (3) hükmen bildirimi gitmez (kontrol).
  select count(*) into v_n from public.push_outbox
  where to_user_id = c and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (10, '(f0) kabul etmemiş davetliye sonuç bildirimi yok (kontrol)',
    '0', '0', v_n::text);

  -- (n) hükmen kazananın XP'si SUNUCUDA yazıldı (cron), ikinci claim çift
  -- vermez. Gözlem: "expire'ın verdiği/claim'in verdiği". Eski: expire
  -- vermez, claim 5×20 = 100 verir (hükmen +30 yok).
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  perform public.claim_async_duel_xp(v_forfeit);
  select coalesce(xp, 0) into v_xp2 from public.profiles where id = a;
  insert into _kanit values (15, '(n) hükmen kazanan XP: expire / sonradan claim',
    '0/100', '130/0', (v_xp1 - v_xp0)::text || '/' || (v_xp2 - v_xp1)::text);

  -- (h) liste alanları.
  insert into _kanit values (11, '(h) list_my_async_duels expires_at / forfeit anahtarları',
    'expires_at=yok,forfeit=yok', 'expires_at=var,forfeit=var',
    'expires_at=' || case when v_row ? 'expires_at' then 'var' else 'yok' end
      || ',forfeit=' || case when v_row ? 'forfeit' then 'var' else 'yok' end);
exception when others then
  insert into _kanit values (2, '(b..h)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- expire #2
do $$
declare
  d uuid := pg_temp.uid(4); v_n int;
begin
  perform public.expire_async_duels();
  select count(*) into v_n from public.push_outbox
  where to_user_id = d and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (12, '(e2) ikinci expire sonrası hatırlatma YİNELENMEZ (toplam)',
    '0', '1', v_n::text);
exception when others then
  insert into _kanit values (12, '(e2)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (j)
-- Süre dolduktan sonra gelen cevap reddedilir. j1: süresi geçmiş (henüz
-- süpürülmemiş) düello. j2: durum 'expired' ama bitiş saati ileride (veri
-- anomalisi / hükmen sonrası): ESKİ gövde bunu kabul ederdi.
do $$
declare
  a uuid := pg_temp.uid(1); u uuid := pg_temp.uid(6);
  x uuid; r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);

  x := pg_temp.duello(a, u, null, 'matched', interval '3 hours', interval '-2 seconds');
  perform pg_temp.bitir(x, a);
  begin
    perform public.answer_async_duel(x, 0, 'A', 0);
    r := 'kabul edildi';
  exception when others then r := sqlerrm;
  end;
  insert into _kanit values (16, '(j1) süresi geçmiş düelloya cevap', 'Duel expired',
    'Duel expired', r);

  x := pg_temp.duello(a, u, null, 'expired', interval '3 hours', interval '5 hours');
  perform pg_temp.bitir(x, a);
  begin
    perform public.answer_async_duel(x, 0, 'A', 0);
    r := 'kabul edildi';
  exception when others then r := sqlerrm;
  end;
  insert into _kanit values (17, '(j2) durumu expired olan düelloya cevap', 'kabul edildi',
    'Duel expired', r);
exception when others then
  insert into _kanit values (16, '(j)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (k,l,m)
-- Soru sunumu. Göç yoksa üç satır da 'RPC yok' (ONCE-DURUMU).
do $$
declare
  a uuid := pg_temp.uid(1); u uuid := pg_temp.uid(6);
  x uuid; v_has boolean; r text; s1 text; s2 text; v_opt text;
  v_res jsonb; v_ms int;
begin
  v_has := to_regprocedure('public.present_async_duel_question(uuid,integer)') is not null;
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);

  -- (k) present iki kez: başlangıç DEĞİŞMEZ.
  x := pg_temp.duello(a, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, a);
  if v_has then
    execute 'select (public.present_async_duel_question($1, 0))->>''started_at''' into s1 using x;
    perform pg_sleep(0.2);
    execute 'select (public.present_async_duel_question($1, 0))->>''started_at''' into s2 using x;
    r := case when s1 = s2 then 'ayni' else 'degisti' end;
  else r := 'RPC yok'; end if;
  insert into _kanit values (18, '(k) present iki kez çağrılınca başlangıç', 'RPC yok', 'ayni', r);

  -- (m) sıra dışı indeks reddedilir (cevap yokken 3. soru sunulamaz).
  if v_has then
    begin
      execute 'select public.present_async_duel_question($1, 3)' using x;
      r := 'kabul edildi';
    exception when others then r := sqlerrm;
    end;
  else r := 'RPC yok'; end if;
  insert into _kanit values (19, '(m) sıra dışı indeks', 'RPC yok', 'Invalid index', r);

  -- (l) present sonrası 30 sn gecikmeli (doğru) cevap YANLIŞ sayılır.
  x := pg_temp.duello(a, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, a);
  if v_has then
    select q.correct_option into v_opt from public.questions q
    where q.id = (select question_ids[1] from public.async_duels where id = x);
    execute 'select public.present_async_duel_question($1, 0)' using x;
    execute 'update public.async_duel_question_starts set started_at = clock_timestamp() - interval ''30 seconds'' where duel_id = $1 and player_id = $2'
      using x, u;
    v_res := public.answer_async_duel(x, 0, v_opt, 0);
    select response_ms into v_ms from public.async_duel_answers
    where duel_id = x and player_id = u and question_index = 0;
    r := 'correct=' || (v_res->>'correct') || ',ms=' || v_ms;
  else r := 'RPC yok'; end if;
  insert into _kanit values (20, '(l) present sonrası 30 sn gecikmeli doğru cevap',
    'RPC yok', 'correct=false,ms=20000', r);

  -- (l0) kontrol: present sonrası hemen verilen doğru cevap doğru kalır.
  x := pg_temp.duello(a, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, a);
  if v_has then
    select q.correct_option into v_opt from public.questions q
    where q.id = (select question_ids[1] from public.async_duels where id = x);
    execute 'select public.present_async_duel_question($1, 0)' using x;
    v_res := public.answer_async_duel(x, 0, v_opt, 0);
    r := 'correct=' || (v_res->>'correct');
  else r := 'RPC yok'; end if;
  insert into _kanit values (21, '(l0) kontrol: hemen verilen doğru cevap',
    'RPC yok', 'correct=true', r);

  -- (g) devam adaleti: 3 saat önce sunulmuş soru, dönüşte süresi geçmiş
  -- sayılır (resume saati sıfırlamaz); sonraki soru sunulunca temiz başlar.
  x := pg_temp.duello(a, u, null, 'matched', interval '4 hours', interval '20 hours');
  perform pg_temp.bitir(x, a);
  if v_has then
    execute 'select public.present_async_duel_question($1, 0)' using x;
    execute 'update public.async_duel_question_starts set started_at = clock_timestamp() - interval ''3 hours'' where duel_id = $1 and player_id = $2'
      using x, u;
    perform public.resume_my_async_duel(x);
    select q.correct_option into v_opt from public.questions q
    where q.id = (select question_ids[1] from public.async_duels where id = x);
    v_res := public.answer_async_duel(x, 0, v_opt, 0);
    r := 'soru0 correct=' || (v_res->>'correct');
    execute 'select public.present_async_duel_question($1, 1)' using x;
    select q.correct_option into v_opt from public.questions q
    where q.id = (select question_ids[2] from public.async_duels where id = x);
    v_res := public.answer_async_duel(x, 1, v_opt, 0);
    select response_ms into v_ms from public.async_duel_answers
    where duel_id = x and player_id = u and question_index = 1;
    r := r || ',soru1 correct=' || (v_res->>'correct') || ',kucuk=' || (v_ms < 20000);
  else r := 'RPC yok'; end if;
  insert into _kanit values (22, '(g) 3 sa sonra dönüş: yarım soru yanlış, sonraki temiz',
    'RPC yok', 'soru0 correct=false,soru1 correct=true,kucuk=true', r);
exception when others then
  insert into _kanit values (18, '(k,l,m,g)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (o)
-- Ardışık/aynı sorguda iki expire: hatırlatma tek. (Gerçek eşzamanlılık iki
-- oturum ister; `for update skip locked` + `marked` birleşimi o durumu
-- sözleşmeye bağlar, bekçi: test/duello_sirasi_sql_test.dart.)
do $$
declare
  a uuid := pg_temp.uid(1); e uuid := pg_temp.uid(5);
  x uuid; v_n int;
begin
  x := pg_temp.duello(a, e, null, 'matched', interval '22 hours', interval '2 hours');
  perform pg_temp.bitir(x, a);
  perform public.expire_async_duels(), public.expire_async_duels();
  select count(*) into v_n from public.push_outbox
  where to_user_id = e and kind = 'async_duel_turn' and created_at >= now();
  insert into _kanit values (23, '(o) aynı sorguda iki expire: hatırlatma sayısı', '0', '1', v_n::text);
exception when others then
  insert into _kanit values (23, '(o)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (p)
-- Normal tamamlanma sonuç push'u: engelli çiftte YOK (p), engelsiz kontrolde
-- VAR (p0). Yaratıcı bitirmiş, rakip 7 soruyu sırayla cevaplar.
do $$
declare
  c1 uuid := pg_temp.uid(5); c2 uuid := pg_temp.uid(3); u uuid := pg_temp.uid(6);
  x uuid; i int; v_n int;
begin
  insert into public.blocked_users (blocker_id, blocked_id) values (c1, u);
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);

  x := pg_temp.duello(c1, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, c1);
  for i in 0..6 loop perform public.answer_async_duel(x, i, 'A', 0); end loop;
  select count(*) into v_n from public.push_outbox
  where to_user_id = c1 and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (25, '(p) engelli çiftte normal tamamlanma push''u', '1', '0', v_n::text);

  x := pg_temp.duello(c2, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, c2);
  for i in 0..6 loop perform public.answer_async_duel(x, i, 'A', 0); end loop;
  select count(*) into v_n from public.push_outbox
  where to_user_id = c2 and kind = 'async_duel_result' and created_at >= now();
  insert into _kanit values (26, '(p0) kontrol: engelsiz çiftte push var', '1', '1', v_n::text);
exception when others then
  insert into _kanit values (25, '(p)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (q)
-- XP ödemesi başarısız kalmış eski hükmen düello (xp_awarded=false): bir
-- sonraki expire koşusu öder, ikincisi çift ödemez.
do $$
declare
  w uuid := pg_temp.uid(4); l uuid := pg_temp.uid(2);
  x uuid; v0 int; v1 int; v2 int;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'async_duels'
      and column_name = 'forfeit_loser_id'
  ) then
    insert into _kanit values (27, '(q1) ödenmemiş hükmen: expire ödedi (XP farkı)', 'kolon yok', '130', 'kolon yok');
    insert into _kanit values (28, '(q2) ikinci expire çift ödemedi (XP farkı)', 'kolon yok', '0', 'kolon yok');
    return;
  end if;
  x := pg_temp.duello(w, l, null, 'expired', interval '30 hours', interval '-1 minute');
  perform pg_temp.bitir(x, w);
  execute 'update public.async_duels set forfeit_loser_id = $2 where id = $1' using x, l;
  select coalesce(xp, 0) into v0 from public.profiles where id = w;
  perform public.expire_async_duels();
  select coalesce(xp, 0) into v1 from public.profiles where id = w;
  perform public.expire_async_duels();
  select coalesce(xp, 0) into v2 from public.profiles where id = w;
  insert into _kanit values (27, '(q1) ödenmemiş hükmen: expire ödedi (XP farkı)', 'kolon yok', '130', (v1 - v0)::text);
  insert into _kanit values (28, '(q2) ikinci expire çift ödemedi (XP farkı)', 'kolon yok', '0', (v2 - v1)::text);
exception when others then
  insert into _kanit values (27, '(q)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (r)
-- Sıra dışı cevap indeksi: hiç cevap yokken 4. soruya cevap reddedilir.
do $$
declare
  a uuid := pg_temp.uid(1); u uuid := pg_temp.uid(6);
  x uuid; r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  x := pg_temp.duello(a, u, null, 'matched', interval '1 hour', interval '23 hours');
  perform pg_temp.bitir(x, a);
  begin
    perform public.answer_async_duel(x, 3, 'A', 0);
    r := 'kabul edildi';
  exception when others then r := sqlerrm;
  end;
  insert into _kanit values (29, '(r) sıra dışı cevap indeksi', 'kabul edildi', 'Invalid index', r);
exception when others then
  insert into _kanit values (29, '(r)', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- (i)
insert into _kanit
select 30, '(i) expire-async-duels cron takvimi', '37 * * * *', '*/10 * * * *',
       coalesce((select schedule from cron.job where jobname = 'expire-async-duels'),
                'iş yok');

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
