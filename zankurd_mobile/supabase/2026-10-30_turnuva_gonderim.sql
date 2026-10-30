-- T2: 0 puanlı gönderim ile hiç gönderilmemiş tarafı ayır.
-- Canlı bağlantı kurulmadan yazıldı; uygulanmadı. Yeni sütun gerekmez:
-- submitted_one/submitted_two hem eski hem sunucu puanlı yolda yazılır.
-- Eski göçteki fonksiyon gövdesi kopyalanmaz. Uygulama anındaki tanım
-- pg_get_functiondef ile alınır; yalnız maç JSON'una iki alan eklenir.
-- Beklenen ekleme noktası değişmişse işlem DURUR, yeni gövde ezilmez.
-- İlgili join/submit akışları istemcide aynı bracket RPC'siyle yenilenir.
-- Uygulamadan önce BEGIN...ROLLBACK denemesi ve önce/sonra tanım diff'i alın.
-- Geri alma: yalnız bu iki JSON çiftini güncel pg_get_functiondef çıktısından
-- çıkarıp CREATE OR REPLACE çalıştırın. submitted_* sütunlarını, RLS'yi ve
-- yetki kısıtlarını koruyun; eski bir göç gövdesine geri dönmeyin.
begin;

do $patch$
declare
  v_definition text;
  v_anchor constant text := '''deadline'', m.deadline';
  v_fields constant text := '''p1_submitted_at'', m.submitted_one,
                   ''p2_submitted_at'', m.submitted_two,
                   ''deadline'', m.deadline';
begin
  if to_regprocedure('public.get_tournament_bracket()') is null then
    raise exception 'T2: bracket RPC bulunamadı';
  end if;
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.tournament_matches'::regclass
      and attname = 'submitted_one' and not attisdropped
      and atttypid = 'timestamptz'::regtype
  ) or not exists (
    select 1 from pg_attribute
    where attrelid = 'public.tournament_matches'::regclass
      and attname = 'submitted_two' and not attisdropped
      and atttypid = 'timestamptz'::regtype
  ) then
    raise exception 'T2: beklenen gönderim sütunları bulunamadı';
  end if;

  select pg_get_functiondef('public.get_tournament_bracket()'::regprocedure)
    into v_definition;
  if position('''p1_submitted_at''' in v_definition) > 0
     or position('''p2_submitted_at''' in v_definition) > 0 then
    -- Tekrar uygulama yalnız tam olarak bu ekleme mevcutsa no-op olur.
    if position(v_fields in v_definition) = 0 then
      raise exception 'T2: gönderim alanları farklı tanımlanmış; elle inceleyin';
    end if;
  else
    if (length(v_definition) - length(replace(v_definition, v_anchor, '')))
        / length(v_anchor) <> 1 then
      raise exception 'T2: tekil JSON ekleme noktası yok; canlı tanımı inceleyin';
    end if;
    execute replace(v_definition, v_anchor, v_fields);
  end if;
end;
$patch$;

alter function public.get_tournament_bracket() set search_path = public, pg_temp;
revoke all on function public.get_tournament_bracket() from public, anon;
grant execute on function public.get_tournament_bracket() to authenticated;
alter table public.tournament_matches enable row level security;
revoke all on table public.tournament_matches from anon;

-- Son doğrulama: alanlar, sabit search_path, SECURITY DEFINER, RLS ve yetki.
do $verify$
declare
  v_definition text := pg_get_functiondef('public.get_tournament_bracket()'::regprocedure);
  v_config text[];
  v_definer boolean;
begin
  if position('''p1_submitted_at'', m.submitted_one' in v_definition) = 0
     or position('''p2_submitted_at'', m.submitted_two' in v_definition) = 0 then
    raise exception 'T2: gönderim alanları doğrulanamadı';
  end if;
  select proconfig, prosecdef into v_config, v_definer
    from pg_proc where oid = 'public.get_tournament_bracket()'::regprocedure;
  if not v_definer or not coalesce(v_config @> array['search_path=public, pg_temp'], false) then
    raise exception 'T2: fonksiyon güvenlik ayarları doğrulanamadı';
  end if;
  if has_function_privilege('anon', 'public.get_tournament_bracket()', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.get_tournament_bracket()', 'EXECUTE') then
    raise exception 'T2: RPC yetkileri doğrulanamadı';
  end if;
  if not (select relrowsecurity from pg_class
          where oid = 'public.tournament_matches'::regclass)
     or has_table_privilege('anon', 'public.tournament_matches', 'SELECT') then
    raise exception 'T2: maç tablosu koruması doğrulanamadı';
  end if;
end;
$verify$;
commit;
