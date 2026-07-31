-- Oyuncu kodu tetikleyicisi kendi çağırdığı fonksiyona erişemiyordu.
--
-- ## Belirti
--
-- Yeni (anonim dahil) bir kullanıcı ilk kez oda kurmaya çalıştığında:
--
--   PostgrestException(message: permission denied for function
--   generate_player_tag, code: 42501)
--
-- 2026-08-01'de iOS simülatöründe canlı backend'e bağlanarak bulundu.
-- Kod okumasıyla görünmüyordu çünkü kusur iki ayrı dosyadaki iki doğru
-- kararın kesişiminde duruyor.
--
-- ## Sebep
--
-- `2026-07-28_player_tag.sql` iki şey yapıyor ve ikisi de tek başına
-- doğru:
--
--   1. `generate_player_tag()` istemciden geri alınıyor
--      (`revoke all ... from public, anon, authenticated`). Doğru: kullanıcı
--      bu fonksiyonu doğrudan çağırıp kod havuzunu tüketememeli.
--   2. `profiles` üzerine BEFORE INSERT tetikleyicisi konuyor
--      (`assign_player_tag`) ve o, `generate_player_tag()`i çağırıyor.
--
-- Ama `assign_player_tag` `security definer` DEĞİL. PostgreSQL'de
-- varsayılan `security invoker`dır: tetikleyici, satırı ekleyen kullanıcının
-- yetkileriyle çalışır. Yani `authenticated` bir kullanıcı profil satırı
-- eklediğinde tetikleyici onun adına `generate_player_tag()`i çağırıyor ve
-- 1. maddedeki revoke tam da bunu engelliyor.
--
-- ## Etkisi — sanıldığından geniş
--
-- `ensureProfile()` istisnayı yakalayıp sessizce geçiyor, bu yüzden
-- uygulama açılıyor ve ana ekran normal görünüyor. Ama profil satırı HİÇ
-- OLUŞMUYOR. Sonuç, yeni her kullanıcı için:
--
--   * oyuncu kodu yok (arkadaş ekleme çalışmaz),
--   * liderlik tablosunda satırı yok,
--   * `createOnlineRoom` her seferinde aynı hatayla düşüyor — oda kurma
--     tamamen kırık.
--
-- Mevcut kullanıcılar etkilenmiyordu: profilleri göç öncesinde ya da
-- `2026-07-28`in geri doldurma adımında oluşmuştu.
--
-- ## Düzeltme
--
-- Tetikleyici fonksiyonu `security definer` yapmak yeterli: artık
-- fonksiyonun sahibi (postgres) adına çalışır ve `generate_player_tag`e
-- erişebilir. `generate_player_tag` istemciye KAPALI kalmaya devam
-- ediyor — 1. maddedeki koruma korunuyor, yalnız tetikleyici muaf.
--
-- `set search_path = public` zorunlu: `security definer` bir fonksiyon
-- çağıranın arama yolunu miras alırsa, aynı adı taşıyan sahte bir nesne
-- gerçek olanın önüne geçebilir.

begin;

create or replace function public.assign_player_tag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.player_tag is null or length(trim(new.player_tag)) = 0 then
    new.player_tag := public.generate_player_tag();
  end if;
  return new;
end;
$$;

-- Tetikleyici tanımı değişmedi ama fonksiyon yeniden yaratıldığı için
-- bağlamayı tazelemek güvenli ve idempotenttir.
drop trigger if exists profiles_assign_player_tag on public.profiles;
create trigger profiles_assign_player_tag
  before insert on public.profiles
  for each row
  execute function public.assign_player_tag();

-- Geri doldurma: kusur yüzünden profili hiç oluşmamış kullanıcı olamaz
-- (insert baştan düşüyordu), ama kodu boş kalmış satır varsa tamamlanır.
update public.profiles
   set player_tag = public.generate_player_tag()
 where player_tag is null or length(trim(player_tag)) = 0;

commit;
