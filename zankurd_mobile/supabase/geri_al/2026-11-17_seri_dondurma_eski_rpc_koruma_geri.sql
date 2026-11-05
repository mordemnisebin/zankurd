-- 2026-11-17_seri_dondurma_eski_rpc_koruma.sql geri alma: eski gövdeyi yedekten
-- birebir yükler (md5 zinciri doğrulanır; sağlam değilse durur).
begin;

do $guard_geri$
declare
  v_imza constant text := 'public.spend_streak_freeze(text)';
  v_yedek text;
  v_eski text;
  v_md5 text;
begin
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'guard_seri:' || v_imza;
  if v_yedek is null then
    raise exception 'guard_seri geri: yedek satırı yok';
  end if;
  v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n$', '');
  v_md5 := substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n$');
  if v_eski = v_yedek or md5(v_eski) <> v_md5 then
    raise exception 'guard_seri geri: yedek md5 zinciri bozuk; elle incele';
  end if;
  execute v_eski;
  delete from public.olcek_tur3_yedek where ad = 'guard_seri:' || v_imza;
end
$guard_geri$;

commit;
