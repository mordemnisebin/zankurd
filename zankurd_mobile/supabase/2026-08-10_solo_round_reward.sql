-- Solo tur ödülü: günlük tavanlı, doğrulanmamış talep.
--
-- ## Niçin gerekiyor
--
-- ZanKurd çevrimdışı-önceliklidir: 2153 soru cihazda durur ve ürünün ana
-- vaadi tek başına oynamaktır. Ama ana döngü hiçbir şey kazandırmıyordu.
-- `claim_quiz_reward`, `p_room_id is null` olduğunda `verification_required`
-- dönüp sıfır veriyor; çevrimdışı oyuncunun tek jeton kaynağı günde bir kez
-- çevrilen çarktı (ortalama 40,6 jeton). Yani oyunu OYNAMAK değil, bir
-- düğmeye basmak ödüllendiriliyordu.
--
-- ## Niçin doğrulama yapılamıyor
--
-- Bu "henüz yazılmadı" değil, mimari bir sınır: çevrimdışı bankadaki sorular
-- istemcideki JSON dosyalarında durur, veritabanında yoktur. Sunucu "bu
-- oyuncu gerçekten 10 soruda 8 doğru yaptı mı" sorusunu cevaplayamaz, çünkü
-- soruların kendisi burada değildir. `claim_quiz_reward`'ın reddi doğru bir
-- karardır ve kapatılamaz.
--
-- ## Niçin yine de veriyoruz
--
-- Korunan şeyin parasal değeri yoktur. Jeton satan bir IAP yoktur; jeton
-- yalnız kazanılır ve dört kozmetik ürünle jokerlere harcanır. Hile yapan
-- kimseden bir şey çalmaz, yalnız kozmetiğini erken açar. Buna karşılık
-- doğrulama ısrarı DÜRÜST HER OYUNCUNUN ana döngüsünü ödülsüz bırakıyordu.
--
-- Bu yüzden talep doğrulanmaz ama zarar sınırlanır: günde en fazla 45 jeton.
-- Tavan, günde iki iyi turla zaten ulaşılan bir miktardır — hile yapan,
-- dürüst oynayanın çok az önüne geçebilir.
--
-- ## Tavan niçin 45
--
-- Çark günde ~40,6 verir; solo tavanıyla günlük gelir ~85 olur ve mağaza
-- şöyle konumlanır (fiyat çıpası `lib/src/screens/shop_screen.dart` ve
-- `test/shop_economy_anchor_test.dart` içinde):
--
--     Ekstra Çevirme  120 → 1,4 gün
--     Neon Çerçeve    350 → 4,1 gün
--     Altın Çerçeve   480 → 5,6 gün
--     VIP Rozeti      720 → 8,5 gün
--
-- Tur başına ödül `4 + doğru + en iyi seri`; on soruluk kusursuz bir tur 24
-- jeton verir, yani tavana iki turda varılır. Amaç oynamayı ödüllendirmektir,
-- oynamayı zorunlu kılmak değil.
--
-- ## Bilinen ve kabul edilen risk
--
-- İleride bir jeton paketi IAP'ı eklenirse bu doğrulanmamış musluk gelir
-- sızıntısına döner. Tavan zararı sınırlar; `reason = 'solo_round'` gerekçe
-- kodu da her kaydı denetlenebilir ve gerekirse toplu geri alınabilir kılar.
--
-- Lig ve liderlik puana/rating'e dayanır, jetona değil: rekabet bütünlüğü
-- etkilenmez.

begin;

create or replace function public.claim_solo_reward(
  p_correct_count integer,
  p_total_questions integer,
  p_best_streak integer
) returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := current_date;
  v_daily_cap constant integer := 45;
  v_max_questions constant integer := 50;
  v_earned_today integer;
  v_remaining integer;
  v_amount integer;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'amount', 0,
      'error', 'Authenticated user required'
    );
  end if;

  -- Girdiler istemciden gelir ve doğrulanamaz; yine de SAÇMA değerler
  -- reddedilir. Üst sınırı tavan koyar, bu kontroller yalnız defterdeki
  -- kayıtların anlamlı kalmasını sağlar.
  if p_total_questions is null
     or p_total_questions <= 0
     or p_total_questions > v_max_questions
     or p_correct_count is null
     or p_correct_count < 0
     or p_correct_count > p_total_questions
     or p_best_streak is null
     or p_best_streak < 0
     or p_best_streak > p_total_questions then
    return jsonb_build_object('amount', 0, 'error', 'Invalid round summary');
  end if;

  -- Kilit, eşzamanlı iki talebin tavanı birlikte aşmasını engeller:
  -- ikisi de "bugün 0 kazandım" okuyup ikisi de yazamaz.
  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'Profile missing');
  end if;

  select coalesce(sum(amount), 0)
    into v_earned_today
  from public.coin_transactions
  where player_id = v_user_id
    and reason = 'solo_round'
    and created_at >= v_today::timestamptz
    and created_at < (v_today + 1)::timestamptz;

  v_remaining := greatest(v_daily_cap - v_earned_today, 0);
  if v_remaining = 0 then
    return jsonb_build_object(
      'amount', 0,
      'daily_cap', v_daily_cap,
      'cap_reached', true
    );
  end if;

  v_amount := least(4 + p_correct_count + p_best_streak, v_remaining);

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_user_id, v_amount, 'solo_round');

  return jsonb_build_object(
    'amount', v_amount,
    'daily_cap', v_daily_cap,
    'cap_reached', v_amount >= v_remaining
  );
end;
$$;

alter function public.claim_solo_reward(integer, integer, integer)
  owner to postgres;

revoke all on function public.claim_solo_reward(integer, integer, integer)
  from public;
revoke all on function public.claim_solo_reward(integer, integer, integer)
  from anon;
grant execute on function public.claim_solo_reward(integer, integer, integer)
  to authenticated;
grant execute on function public.claim_solo_reward(integer, integer, integer)
  to service_role;

commit;
