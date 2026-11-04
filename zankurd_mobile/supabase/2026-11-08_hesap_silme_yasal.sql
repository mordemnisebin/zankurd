-- Hesap silme tur 10 (GPT-6 Pro alan 9 denetimi; engelleyici 1 + önemli 2, kodda doğrulandı).
-- UYGULANMADI (applied.md ⏳). Geri alma: geri_al/2026-11-08_hesap_silme_yasal_geri.sql
--
-- Taban (canlı ✅): delete_my_account'un canlı gövdesi, applied.md ✅ satırlarının sırasıyla
-- bulunan SON tanımdır: 2026-10-16_kalabalik_oda.sql gövdesi + 2026-11-04_olcek_sertlestirme.sql
-- kilit yaması (başka göç delete_my_account'a dokunmaz). TAM gövdenin md5'i bilinen tabana
-- eşitse yamalanır; başka her durumda göç durur. Eski gövde ve md5'i olcek_tur3_yedek'e
-- ('tur10:public.delete_my_account()') alınır. Taban md5'i yerelde PGlite'ta zincirden
-- yeniden kurularak bulundu (tool/test_hesap_silme_yasal_local.mjs aynı değeri doğrular);
-- canlıda göç ÖNCE kuru çalıştırılır: md5 uyuşmazsa göç raise eder ve hiçbir şey değişmez.
--
-- Eski istemci (build 43) sözleşmesi: delete_my_account imzası/dönüşü değişmez; eski istemci
-- RPC'yi aynen çağırmaya devam eder.
--
-- 1. [engelleyici] Profil fotoğrafı: RPC içindeki doğrudan SQL `DELETE FROM storage.objects`
--    Supabase'te fiziksel dosyayı silmez (korumalı projede hata verip bütün hesap silmeyi
--    geri alır). Gerçek silme Storage API'siyledir: YENİ istemci RPC'den önce kendi avatar
--    nesnelerini `storage.remove` ile siler (sahip silme politikası:
--    2026-07-05_avatar_showcase.sql "Users delete own avatar photos"). Bu göç doğrudan SQL
--    silmeyi YEDEK olarak tutar ama bir alt işlem bloğuna alır: hata verirse hesap silme
--    artık GERİ ALINMAZ (kullanıcının silme hakkı bir storage hatasına bağlı olmamalı).
--    Eski istemcide kalan fiziksel dosyalar için sunucu süpürmesi: docs/HESAP_SILME_VE_VERI.md.
-- 2. [önemli] Ardışık silmelerde başka oyuncuların room_result_snapshots JSON'unda silinen
--    kişinin kimliği/adı kalıyordu (A silinir -> C için kayıt B'nin kimliğiyle yazılır; B
--    silinince `ON CONFLICT DO NOTHING` kaydı olduğu gibi bırakıyordu). Yeni yardımcı
--    anonymize_deleted_user_in_snapshots(uuid), silinen kullanıcının bulunduğu bütün odaların
--    (room_players) bütün mevcut anlık görüntülerinde players[], winner_id, room.host_id ve
--    öteki her UUID geçtiği yeri sabit anonim kimlik/adla değiştirir; sayısal sonuçlar korunur.
--    Yardımcı istemciye KAPALI (yalnız SECURITY DEFINER delete_my_account çağırır).
--    Daha önce silinmiş kullanıcıların artık bilinmeyen kimlikleri geriye dönük bulunamaz;
--    bu göç yalnız bundan sonraki silmeleri ve hâlâ var olan kullanıcıların silinişini kapsar.
begin;

set local lock_timeout = '10s';

do $tur10_onkosul$
begin
  if to_regprocedure('public.delete_my_account()') is null
     or to_regclass('public.room_result_snapshots') is null
     or to_regclass('public.room_players') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur10: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Henüz uygulanmamış olmalı (yeniden çalıştırma yok): yardımcı ve yedek satırı olmamalı.
  if to_regprocedure('public.anonymize_deleted_user_in_snapshots(uuid)') is not null
     or exists (select 1 from public.olcek_tur3_yedek
                where ad = 'tur10:public.delete_my_account()') then
    raise exception 'tur10: göç zaten uygulanmış görünüyor (yardımcı ya da yedek satırı var); elle incele';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) or has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'tur10: olcek_tur3_yedek istemci rollerine açık; yedek güvenilmez';
  end if;
end;
$tur10_onkosul$;

create temp table tur10_durum (
  sahip oid not null, acl text, ayar text[], secdef boolean not null
) on commit drop;
do $tur10_durum$
declare
  v_def text := pg_get_functiondef(to_regprocedure('public.delete_my_account()'));
begin
  if md5(v_def) <> 'd475d062bb56d993875b88a8169d1e6f' then
    raise exception 'tur10: delete_my_account gövdesi bilinen canlı taban değil (md5 %); canlı gövde değişmiş olabilir, elle incele', md5(v_def);
  end if;
  insert into tur10_durum
  select p.proowner, p.proacl::text, p.proconfig, p.prosecdef
  from pg_proc p where p.oid = to_regprocedure('public.delete_my_account()');
end;
$tur10_durum$;

-- Yedek: eski gövde + md5 (geri alma bunu geri yükler).
insert into public.olcek_tur3_yedek (ad, tanim, alindi)
select 'tur10:public.delete_my_account()',
       pg_get_functiondef(to_regprocedure('public.delete_my_account()'))
         || E'\n-- md5:' || md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))),
       now();

-- ---------------------------------------------------------------------------
-- Yardımcı: silinen kullanıcıyı bütün mevcut anlık görüntülerde anonimleştir
-- ---------------------------------------------------------------------------
create function public.anonymize_deleted_user_in_snapshots(p_user_id uuid)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  c_anon_id constant text := '00000000-0000-0000-0000-000000000000';
  c_anon_name constant text := 'Hesabê jêbirî';
  v_uid text := p_user_id::text;
  v_row record;
  v_payload jsonb;
  v_adet integer := 0;
begin
  if p_user_id is null then
    return 0;
  end if;

  -- Yalnız silinen kullanıcının oynadığı odaların (room_players; PK öneki room_id)
  -- başkalarına ait anlık görüntüleri; silinenin kendi kaydı cascade ile gider.
  for v_row in
    select s.room_id, s.player_id, s.payload
    from public.room_result_snapshots s
    where s.player_id <> p_user_id
      and s.room_id in (
        select rp.room_id from public.room_players rp where rp.player_id = p_user_id
      )
      and position(v_uid in s.payload::text) > 0
    order by s.room_id, s.player_id
    for update of s
  loop
    v_payload := v_row.payload;

    if jsonb_typeof(v_payload -> 'players') = 'array' then
      v_payload := jsonb_set(
        v_payload,
        '{players}',
        coalesce((
          select jsonb_agg(
            case
              when e.item ->> 'player_id' = v_uid then
                e.item || jsonb_build_object(
                  'player_id', c_anon_id,
                  'display_name', c_anon_name
                )
              else e.item
            end
            order by e.ord
          )
          from jsonb_array_elements(v_payload -> 'players')
            with ordinality as e(item, ord)
        ), '[]'::jsonb)
      );
    end if;

    if v_payload ->> 'winner_id' = v_uid then
      v_payload := jsonb_set(v_payload, '{winner_id}', to_jsonb(c_anon_id));
    end if;

    if jsonb_typeof(v_payload -> 'room') = 'object'
       and v_payload -> 'room' ->> 'host_id' = v_uid then
      v_payload := jsonb_set(v_payload, '{room,host_id}', 'null'::jsonb);
    end if;

    -- Başka bir alanda kalmış kimlik de açıkta bırakılmaz.
    if position(v_uid in v_payload::text) > 0 then
      v_payload := replace(v_payload::text, v_uid, c_anon_id)::jsonb;
    end if;

    update public.room_result_snapshots s
    set payload = v_payload
    where s.room_id = v_row.room_id
      and s.player_id = v_row.player_id;
    v_adet := v_adet + 1;
  end loop;

  return v_adet;
end;
$function$;

revoke all on function public.anonymize_deleted_user_in_snapshots(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- delete_my_account yaması (tek bağlayıcı parça; tam bir kez bulunmalı)
-- ---------------------------------------------------------------------------
do $tur10_yama$
declare
  v_oid regprocedure := to_regprocedure('public.delete_my_account()');
  v_def text := pg_get_functiondef(v_oid);
  v_eski constant text :=
$e$  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = v_user_id::text;
$e$;
  v_yeni constant text :=
$y$  -- (2026-11-08) Başkalarının mevcut sonuç anlık görüntülerinde bu kullanıcının kimliği/adı
  -- anonimleştirilir (room_players silinmeden ÖNCE: oda listesi oradan gelir).
  perform public.anonymize_deleted_user_in_snapshots(v_user_id);

  delete from public.player_answers
  where player_id = v_user_id;

  delete from public.room_players
  where player_id = v_user_id;

  -- (2026-11-08) YEDEK yol: doğrudan SQL silme Supabase'te fiziksel dosyayı silmez ve
  -- korumalı projede hata verir. Gerçek silme istemcinin Storage API çağrısıdır (RPC'den
  -- önce). Hata artık hesap silmeyi geri ALMAZ.
  begin
    delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = v_user_id::text;
  exception when others then
    null;
  end;
$y$;
  v_adet integer;
begin
  v_adet := (length(v_def) - length(replace(v_def, v_eski, ''))) / length(v_eski);
  if v_adet <> 1 then
    raise exception 'tur10: delete_my_account için bağlayıcı metin % kez bulundu (1 beklenir); canlı gövde değişmiş, yeniden incele', v_adet;
  end if;
  execute replace(v_def, v_eski, v_yeni);
  update public.olcek_tur3_yedek
  set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'tur10:public.delete_my_account()';
end;
$tur10_yama$;

-- ---------------------------------------------------------------------------
-- Son kontroller: nihai md5, sahip/ACL/search_path/SECURITY DEFINER değişmedi,
-- anon/PUBLIC çalıştıramaz, yardımcı istemciye kapalı.
-- ---------------------------------------------------------------------------
do $tur10_son$
declare
  d record;
begin
  select * into d from tur10_durum;
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.delete_my_account()')
      and p.proowner = d.sahip
      and p.prosecdef = d.secdef
      and p.proconfig is not distinct from d.ayar
      and p.proacl::text is not distinct from d.acl
  ) then
    raise exception 'tur10: delete_my_account sahip / search_path / ACL doğrulanamadı';
  end if;
  if md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))) <> '2e5e96d2061716e7a0f876ee03b2d7be' then
    raise exception 'tur10: delete_my_account yama sonrası beklenen nihai md5 değil';
  end if;
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute')
     or has_function_privilege('public', 'public.delete_my_account()', 'execute') then
    raise exception 'tur10: delete_my_account anon/PUBLIC EXECUTE açık';
  end if;
  if not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then
    raise exception 'tur10: delete_my_account authenticated EXECUTE kaybolmuş (eski istemci kırılırdı)';
  end if;
  if has_function_privilege('anon', 'public.anonymize_deleted_user_in_snapshots(uuid)', 'execute')
     or has_function_privilege('public', 'public.anonymize_deleted_user_in_snapshots(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.anonymize_deleted_user_in_snapshots(uuid)', 'execute') then
    raise exception 'tur10: anonimleştirme yardımcısı istemciye açık';
  end if;
  if not exists (select 1 from pg_proc p
                 where p.oid = to_regprocedure('public.anonymize_deleted_user_in_snapshots(uuid)')
                   and p.prosecdef and p.proconfig is not null) then
    raise exception 'tur10: yardımcı SECURITY DEFINER + sabit search_path değil';
  end if;
end;
$tur10_son$;

commit;
