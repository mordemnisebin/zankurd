-- 2026-10-02: gereksiz EXECUTE ve tablo yazma yetkileri kapatılır
-- (güvenlik denetimi L1 + L2 + denetimde bulunan görünüm açığı).
--
-- ÖNCE EN CİDDİSİ — `public.quiz_eligible_questions` GÖRÜNÜMÜ:
--   Görünüm `security_invoker` DEĞİL (sahibi postgres, BYPASSRLS) ve basit
--   `select ... from questions where ...` olduğu için otomatik güncellenebilir
--   (pg_relation_is_updatable = 28: INSERT+UPDATE+DELETE). Üstüne
--   `anon` ve `authenticated`a INSERT/UPDATE/DELETE verilmişti. Postgres,
--   görünüm üzerinden yazmada altta yatan tablonun yetkisini GÖRÜNÜM
--   SAHİBİ olarak denetler — yani RLS atlanır. Sonuç: anon anahtarıyla
--   `POST /rest/v1/quiz_eligible_questions` (SELECT hakkı gerekmez)
--   soru bankasına, `is_approved = true` ve istenen `correct_option` ile
--   soru enjekte edilebilirdi. (Filtreli UPDATE/DELETE, kolon SELECT hakkı
--   olmadığı ve safeupdate açık olduğu için tutmuyor.) İstemci bu görünümü
--   hiç kullanmıyor (lib/ ve 468ea4a4 tarandı; yalnız SQL ve bir test).
--   Düzeltme: bütün istemci yetkileri kalkar + `security_invoker = true`.
--
-- L1 — EXECUTE:
--   * enforce_display_name_policy(), enqueue_friend_request_push():
--     tetikleyici işlevleri; anon/PUBLIC çalıştıramaz olmalı.
--   * get_today_contest(): SECURITY DEFINER ve `contests`e satır YAZIYOR
--     (günün yarışmasını oluşturur); anon çağırabiliyordu. İstemci oturum
--     açıldıktan sonra çağırır (auth kapısı; hem güncel hem 468ea4a4).
--   * rls_auto_enable(): olay tetikleyicisi işlevi; hiçbir istemci rolü
--     çalıştırmamalı.
--   Tetikleyici ve olay tetikleyici işlevlerinin çalışması çağıranın EXECUTE
--   hakkına bağlı değildir (yetki yalnız CREATE TRIGGER anında denetlenir),
--   bu yüzden profil güncellemeleri etkilenmez.
--
-- L2 — TABLO YAZMA YETKİLERİ (RLS'e ek ikinci kemer):
--   Supabase varsayılanı her public tabloya anon ve authenticated için
--   ALL verir; yazmayı yalnız RLS politikası engelliyor. Aşağıdakiler
--   kaldırılır:
--     * TRUNCATE, REFERENCES, TRIGGER: anon ve authenticated için TÜM
--       tablolarda (TRUNCATE RLS'ten geçmez; hiçbir istemci kullanmaz).
--     * INSERT/UPDATE/DELETE: anon için TÜM tablolarda (anonim OTURUM da
--       `authenticated` rolüdür; anon = oturumsuz istek, hiçbir yazma yolu
--       yok).
--     * INSERT/UPDATE/DELETE: authenticated için, istemcinin doğrudan yazdığı
--       şu tablolar DIŞINDA hepsinde (yazma politikası olmayanlar):
--         profiles(insert,update)  favorite_questions(insert,update,delete)
--         blocked_users(insert,update,delete)  question_reports(insert)
--         room_messages(insert)  suggested_questions(insert)
--         user_lesson_progress(insert,update)
--       İstemci taraması (lib/ + 468ea4a4): doğrudan yazılan tablolar tam
--       olarak bunlar; geri kalan her yazma bir SECURITY DEFINER RPC'dir
--       (sahibi olarak çalışır, bu yetkilere bağlı değil).
--   Gelecekte yeni bir tabloya istemci yazması gerekirse bu listeye
--   eklenmeli (yoksa 42501 alır). Supabase'in varsayılan ALTER DEFAULT
--   PRIVILEGES'ı yeni tablolara yine ALL verir; bu migration o davranışı
--   DEĞİŞTİRMEZ — yeni tabloda `revoke` yazmayı unutma.
--
-- GERİ ALMA: `grant insert, update, delete, truncate, references, trigger on
-- table public.<t> to anon, authenticated;` (önerilmez); işlevler için
-- `grant execute on function ... to anon;`; görünüm için `alter view ...
-- reset (security_invoker)`.

begin;

-- L1 ------------------------------------------------------------------
revoke all on function public.enforce_display_name_policy() from public, anon;
revoke all on function public.enqueue_friend_request_push() from public, anon;
revoke all on function public.get_today_contest() from public, anon;
grant execute on function public.get_today_contest() to authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

-- Görünüm açığı ---------------------------------------------------------
alter view public.quiz_eligible_questions set (security_invoker = true);

-- L2 ------------------------------------------------------------------
do $$
declare
  r record;
  v_keep text[];
  v_priv text;
begin
  for r in
    select c.relname
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind in ('r', 'p', 'v', 'm', 'f')
  loop
    execute format(
      'revoke truncate, references, trigger on table public.%I from anon, authenticated',
      r.relname);
    execute format(
      'revoke insert, update, delete on table public.%I from anon',
      r.relname);
    execute format(
      'revoke insert, update, delete on table public.%I from authenticated',
      r.relname);

    v_keep := case r.relname
      when 'profiles' then array['insert', 'update']
      when 'favorite_questions' then array['insert', 'update', 'delete']
      when 'blocked_users' then array['insert', 'update', 'delete']
      when 'question_reports' then array['insert']
      when 'room_messages' then array['insert']
      when 'suggested_questions' then array['insert']
      when 'user_lesson_progress' then array['insert', 'update']
      else array[]::text[]
    end;

    foreach v_priv in array v_keep loop
      execute format(
        'grant %s on table public.%I to authenticated', v_priv, r.relname);
    end loop;
  end loop;
end $$;

-- Doğrulama --------------------------------------------------------------
do $$
declare
  r record;
  v_bad text;
begin
  -- anon hiçbir public nesnesine yazamaz / truncate edemez.
  select string_agg(c.relname || ':' || p, ', ')
  into v_bad
  from pg_class c
  cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','f')
    and has_table_privilege('anon', c.oid, p);
  if v_bad is not null then
    raise exception 'anon hâlâ yazabiliyor: %', v_bad;
  end if;

  -- authenticated: TRUNCATE/REFERENCES/TRIGGER yok; yazma yalnız izin listesinde.
  select string_agg(c.relname || ':' || p, ', ')
  into v_bad
  from pg_class c
  cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
  where c.relnamespace = 'public'::regnamespace
    and c.relkind in ('r','p','v','m','f')
    and has_table_privilege('authenticated', c.oid, p)
    and not (
      (c.relname, p) in (
        ('profiles','INSERT'), ('profiles','UPDATE'),
        ('favorite_questions','INSERT'), ('favorite_questions','UPDATE'),
        ('favorite_questions','DELETE'),
        ('blocked_users','INSERT'), ('blocked_users','UPDATE'),
        ('blocked_users','DELETE'),
        ('question_reports','INSERT'), ('room_messages','INSERT'),
        ('suggested_questions','INSERT'),
        ('user_lesson_progress','INSERT'), ('user_lesson_progress','UPDATE')
      )
    );
  if v_bad is not null then
    raise exception 'authenticated beklenmeyen yetki taşıyor: %', v_bad;
  end if;

  -- İstemcinin kullandığı yazma yolları KORUNDU.
  if not (has_table_privilege('authenticated', 'public.profiles', 'INSERT')
      and has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
      and has_table_privilege('authenticated', 'public.favorite_questions', 'DELETE')
      and has_table_privilege('authenticated', 'public.favorite_questions', 'INSERT')
      and has_table_privilege('authenticated', 'public.question_reports', 'INSERT')
      and has_table_privilege('authenticated', 'public.room_messages', 'INSERT')
      and has_table_privilege('authenticated', 'public.suggested_questions', 'INSERT')
      and has_table_privilege('authenticated', 'public.user_lesson_progress', 'UPDATE')) then
    raise exception 'istemci yazma yolu yanlışlıkla kapandı';
  end if;

  -- Görünüm.
  if not exists (
    select 1 from pg_class c
    where c.oid = 'public.quiz_eligible_questions'::regclass
      and c.reloptions @> array['security_invoker=true']
  ) then
    raise exception 'quiz_eligible_questions security_invoker değil';
  end if;

  -- L1.
  for r in
    select * from (values
      ('public.enforce_display_name_policy()'),
      ('public.enqueue_friend_request_push()'),
      ('public.get_today_contest()')
    ) as t(fn)
  loop
    if has_function_privilege('anon', r.fn::regprocedure, 'execute') then
      raise exception '% anon''a açık', r.fn;
    end if;
  end loop;
  if not has_function_privilege('authenticated', 'public.get_today_contest()', 'execute') then
    raise exception 'get_today_contest authenticated''a kapalı';
  end if;
  if has_function_privilege('authenticated', 'public.rls_auto_enable()', 'execute')
     or has_function_privilege('anon', 'public.rls_auto_enable()', 'execute') then
    raise exception 'rls_auto_enable istemciye açık';
  end if;
  -- Tetikleyiciler yerinde (revoke onları kaldırmaz).
  if (select count(*) from pg_trigger
      where tgrelid = 'public.profiles'::regclass
        and tgname in ('trg_enforce_display_name_policy',
                       'profiles_client_write_guard_trg')) <> 2 then
    raise exception 'profiles tetikleyicileri eksik';
  end if;
end $$;

commit;
