-- 2026-10-26: ilerleme kaydında iyimser eşzamanlılık (save_my_progress_v2).
--
-- NİÇİN: save_my_progress koşulsuz üstüne yazıyor. Cihaz A sunucudan okuyup
-- birleştirirken cihaz B kayıt yaparsa, A'nın kaydı B'ninkini siler. Birleşim
-- tekdüze (en yüksek / birleşim) olduğu için B bir sonraki eşitlemede veriyi
-- geri getirir; ama B bir daha açılmazsa kayıp kalıcı olur.
--
-- NASIL: yeni fonksiyon, istemcinin okuduğu `updated_at`'i bekler. Sunucudaki
-- kayıt o andan beri değiştiyse YAZMAZ, {ok:false, conflict:true} döner;
-- istemci yeniden okuyup birleştirir ve tekrar dener. Aynı oyuncunun
-- eşzamanlı iki kaydı advisory kilitle sıraya girer. Karşılaştırma milisaniye
-- düzeyindedir (istemci zamanı JSON'dan milisaniye hassasiyetle taşır).
--
-- GERİYE UYUM: save_my_progress (tek argüman) DEĞİŞMEZ; eski derlemeler onu
-- çağırmaya devam eder. Yeni istemci v2'yi dener, yoksa eskisine düşer.
-- Yetki: eski fonksiyonla aynı (yalnız authenticated; anon ve public yok).
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-26_ilerleme_surum_denetimi.sql

begin;

create or replace function public.save_my_progress_v2(
  p_snapshot jsonb,
  p_expected_updated_at timestamptz
)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_cur timestamptz;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object' then
    raise exception 'Invalid snapshot';
  end if;

  if octet_length(p_snapshot::text) > 262144 then
    raise exception 'Snapshot too large';
  end if;

  perform 1 from public.profiles where id = v_uid;
  if not found then
    raise exception 'Profile missing';
  end if;

  -- Aynı oyuncunun iki kaydı sırayla: okuma-karşılaştırma-yazma bölünmez.
  perform pg_advisory_xact_lock(
    hashtextextended('progress:' || v_uid::text, 0));

  select updated_at into v_cur
  from public.player_progress
  where player_id = v_uid;

  if found then
    if p_expected_updated_at is null
       or date_trunc('milliseconds', v_cur)
          <> date_trunc('milliseconds', p_expected_updated_at) then
      return jsonb_build_object(
        'ok', false,
        'conflict', true,
        'updated_at', v_cur
      );
    end if;
  end if;

  insert into public.player_progress (player_id, snapshot, updated_at)
  values (v_uid, p_snapshot, v_now)
  on conflict (player_id) do update
    set snapshot = excluded.snapshot,
        updated_at = excluded.updated_at;

  return jsonb_build_object('ok', true, 'updated_at', v_now);
end;
$function$;

revoke all on function public.save_my_progress_v2(jsonb, timestamptz)
  from public, anon;
grant execute on function public.save_my_progress_v2(jsonb, timestamptz)
  to authenticated;

commit;
