-- GUARD: eski `spend_streak_freeze(text)` mağaza alımlarında da sunucu üst sınırını uygular.
-- Geri alma: geri_al/2026-11-17_seri_dondurma_eski_rpc_koruma_geri.sql
--
-- **SIRA: 2.1.2 mağazaya yayıldıktan ve eski istemcilerin çoğu güncellendikten SONRA
-- uygulanır** (2026-11-16_seri_dondurma_ust_sinir.sql ön koşuldur ve canlıda).
--
-- NİÇİN (Copilot, W3 turu 2): `spend_streak_freeze_capped` yalnız yeni istemcinin
-- çağırdığı yoldur. Build 45 ve öncesi mağaza alımını SINIRSIZ eski
-- `spend_streak_freeze(text)` ile yapar; iki eski cihaz yine iki ücret / tek hak
-- üretebilir. Sunucu genelinde garanti için eski işlev, anahtarı `shop_freeze_`
-- ile başlayan (mağaza) çağrıları sınırlı işleve devreder. Bozulma anı teklifi
-- (başka anahtar öneki) elde jeton TUTMAZ; sınırsız eski davranışta kalır.
--
-- NASIL: tam gövde md5 düzeni (guvenlik_tur7 ile aynı): canlı gövdenin
-- pg_get_functiondef md5'i bilinen TABANa eşitse yamalanır; zaten yamalıysa
-- (yeni parça tam bir kez + yedek zinciri sağlam) atlanır; başka her durumda göç
-- DURUR. Eski gövde olcek_tur3_yedek'e ('guard_seri:<imza>') md5 zinciriyle alınır.
-- TABAN, 2026-08-03_streak_freeze_idempotency.sql'in PGlite'ta üretilen gövdesinin
-- md5'idir; canlı kuru çalıştırmada farklı çıkarsa göç bu mesajla durur ve gerçek md5'i
-- söyler: koordinatör canlı md5'i okuyup aşağıdaki `v_taban`ı güncelleyerek yeniden dener.
begin;

set local lock_timeout = '10s';

do $guard_onkosul$
begin
  if to_regprocedure('public.spend_streak_freeze(text)') is null
     or to_regprocedure('public.spend_streak_freeze_capped(text)') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'guard_seri: beklenen canlı nesneler eksik (üst sınır göçü uygulanmış olmalı)';
  end if;
end
$guard_onkosul$;

do $guard_yama$
declare
  v_taban constant text := 'c2160f4e1f8800a055533ebac98ba650';
  v_imza constant text := 'public.spend_streak_freeze(text)';
  v_eski_parca constant text := E'  v_reason := ''streak_freeze:'' || v_key;\n';
  v_yeni_parca constant text :=
    E'  v_reason := ''streak_freeze:'' || v_key;\n' ||
    E'  -- GUARD (2026-11-17): mağaza alımı sunucu üst sınırlı işleve devredilir.\n' ||
    E'  if v_key like ''shop\\_freeze\\_%'' then\n' ||
    E'    return public.spend_streak_freeze_capped(p_idempotency_key);\n' ||
    E'  end if;\n';
  v_def text := pg_get_functiondef(to_regprocedure(v_imza));
  v_yedek text;
  v_owner oid;
  v_acl text;
  v_yeni text;
begin
  if md5(v_def) <> v_taban then
    if position('spend_streak_freeze_capped' in v_def) > 0 then
      select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'guard_seri:' || v_imza;
      if v_yedek is null or position('-- md5:' || v_taban in v_yedek) = 0 then
        raise exception 'guard_seri: gövde yamalı ama yedek zinciri sağlam değil; elle incele';
      end if;
      return; -- zaten uygulanmış
    end if;
    raise exception 'guard_seri: % gövdesi bilinen taban değil (canlı md5 %); canlı gövde değişmiş olabilir, v_taban''ı güncelle ya da elle incele', v_imza, md5(v_def);
  end if;
  if (length(v_def) - length(replace(v_def, v_eski_parca, ''))) / length(v_eski_parca) <> 1 then
    raise exception 'guard_seri: yama noktası tam bir kez bulunamadı';
  end if;

  select p.proowner, p.proacl::text into v_owner, v_acl
  from pg_proc p where p.oid = to_regprocedure(v_imza);

  insert into public.olcek_tur3_yedek (ad, tanim)
  values ('guard_seri:' || v_imza, v_def || E'\n-- md5:' || v_taban || E'\n')
  on conflict (ad) do nothing;

  v_yeni := replace(v_def, v_eski_parca, v_yeni_parca);
  execute v_yeni;

  if exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure(v_imza)
      and (p.proowner <> v_owner or p.proacl::text is distinct from v_acl
           or not p.prosecdef or not (p.proconfig @> array['search_path=public']))
  ) then
    raise exception 'guard_seri: yama sahip/ACL/definer/search_path değiştirdi';
  end if;
  if has_function_privilege('anon', v_imza, 'execute')
     or has_function_privilege('public', v_imza, 'execute')
     or not has_function_privilege('authenticated', v_imza, 'execute') then
    raise exception 'guard_seri: yetkiler beklenen değil';
  end if;
end
$guard_yama$;

commit;
