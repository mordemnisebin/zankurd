-- ZanKurd — profil INSERT yetkisi ve haftalık lig finalizasyonu
-- ==============================================================
--
-- İleri yönlü göç. Uygulanmış hiçbir göç dosyası düzenlenmedi.
--
-- Her iki kusur da adversarial olarak, temiz bir üretim şeması klonunda,
-- gerçek `authenticated` rolü ve gerçek `request.jwt.claims` altında
-- (PostgREST'in çalıştırdığı mekanizmanın aynısı) üretildi — 2026-08-06.
--
--
-- 1) PROFİL INSERT'İNDE SUNUCU YETKİSİ YOKTU
--
-- `profiles_client_write_guard_trg` `BEFORE UPDATE`tir. Yalnız UPDATE.
-- `INSERT` yolunda ekonomiyi koruyan hiçbir şey yoktu ve INSERT
-- politikası da yalnız satırın sahibini doğruluyor, SÜTUNLARI değil:
--
--     "Users insert their own profile"  WITH CHECK (id = auth.uid())
--
-- Profil satırı `auth.users` üzerinde bir tetikleyiciyle DEĞİL, istemci
-- tarafından oluşturuluyor (`ensureProfile` / `upsertProfile`). Yani her
-- yeni kullanıcının ilk yazımı, tamamen kendi denetimindeki bir INSERT.
--
-- Klonda üretildi:
--
--     set role authenticated;  -- request.jwt.claims = kendi uid'i
--     insert into profiles (id, display_name, avatar_icon, avatar_color,
--                           coins, xp, rating)
--     values (<kendi uid>, 'Berfin', 'tac', '#334455', 999999, 888888, 7777);
--     -> KABUL EDİLDİ
--     select coins, xp, rating -> 999999 | 888888 | 7777
--
-- Yani değiştirilmiş bir istemci ya da düz bir REST çağrısı, kayıt olur
-- olmaz kendine sınırsız coin, XP ve liderlik reytingi yazabiliyordu.
-- Coin gerçek bir mağaza parası (joker, ekstra çark, çerçeve, VIP rozet),
-- rating ise liderlik sıralamasının kendisi.
--
-- Aynı oturumda ÇÜRÜTÜLEN iki yol (bunlar zaten kapalıydı, dokunulmadı):
--
--     • başka bir uid için satır açmak
--       -> "new row violates row-level security policy" (RLS tutuyor)
--     • kendi satırını silip yeniden yaratmak
--       -> DELETE 0 satır (delete politikası yok)
--     • `on conflict do update` ile kaçmak
--       -> UPDATE yoluna düşer, mevcut guard coins/rating'i geri alır
--
-- Demek ki delik TAM OLARAK ilk INSERT. Düzeltme de oraya, aynı
-- biçimde konuluyor: sunucu, istemcinin ne gönderdiğine bakmadan
-- başlangıç değerlerini dayatır. UPDATE guard'ına dokunulmadı.
--
-- Kozmetik sütunlar (avatar_frame, showcase_title) zaten korunuyordu:
-- `protect_paid_profile_cosmetics` `BEFORE INSERT OR UPDATE` ve
-- `tg_op = 'INSERT'` dalında bütün alanları "değişti" sayıyor. Yani
-- sahte VIP rozetiyle veya satın alınmamış çerçeveyle açılan bir profil
-- zaten reddediliyordu; burada eksik olan yalnız ekonomiydi.
--
--
-- 2) HAFTALIK LİGİ HERKES KAPATABİLİYORDU
--
-- `finalize_weekly_league(date)` `SECURITY DEFINER` ve `authenticated`
-- rolünde EXECUTE yetkisi var; gövdesinde hiçbir rol kontrolü yok.
-- Klonda düz bir kullanıcı olarak çağrıldı ve BAŞARILI oldu.
--
-- Fonksiyon salt okunur değil: `league_weeks` satırını 'finalizing' →
-- 'closed' yapıyor, `league_memberships`i o hafta için SİLİP yeniden
-- yazıyor, terfi/küme düşme bayraklarını hesaplıyor. Yani herhangi bir
-- kullanıcı haftayı erken kapatıp sıralamayı dondurabilir ya da geçmiş
-- bir haftayı yeniden finalize edip terfileri yeniden yazabilirdi.
--
-- İstemci bu RPC'yi HİÇ ÇAĞIRMIYOR — `lib/` içinde tek geçtiği yer
-- `league_tier.dart` içindeki bir yorum satırı. Dolayısıyla
-- `authenticated` yetkisini geri almak uygulamada hiçbir yolu bozmaz;
-- planlanmış (cron/service-role) çağrı yolu olduğu gibi kalır.

begin;

-- ── 1) INSERT'te sunucu otoritesi ──────────────────────────────────────
create or replace function public.profiles_client_insert_authority()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci eklemeleri kisitlanir. Mevcut UPDATE
  -- guard'iyla ayni kosul, ayni gerekce.
  if current_user in ('authenticated', 'anon') then
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := 0;
    new.rating := 1000;
    -- XP yalnizca award_xp_delta() RPC'si uzerinden yazilir.
    new.xp := 0;
    new.xp_daily_total := 0;
    new.xp_daily_date := null;
  end if;
  return new;
end;
$function$;

drop trigger if exists profiles_client_insert_authority_trg on public.profiles;
create trigger profiles_client_insert_authority_trg
  before insert on public.profiles
  for each row execute function public.profiles_client_insert_authority();

-- ── 2) Haftalık lig finalizasyonu yalnız sunucu tarafında ──────────────
revoke execute on function public.finalize_weekly_league(date) from authenticated;
revoke execute on function public.finalize_weekly_league(date) from anon;
-- Planlanmis is / bakim yolu korunur.
grant execute on function public.finalize_weekly_league(date) to service_role;

commit;

-- Doğrulama (salt okunur):
--
--   select 'insert trigger' as check, count(*) = 1 as ok
--     from pg_trigger
--    where tgrelid = 'public.profiles'::regclass
--      and tgname = 'profiles_client_insert_authority_trg';
--
--   select 'league revoked' as check,
--          array_to_string(proacl, ' | ') not like '%authenticated=X%' as ok
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'finalize_weekly_league';
