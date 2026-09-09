-- 2026-08-03 — Seri dondurma harcamasını idempotent yapar.
--
-- SORUN
--
-- `spend_coins(50, 'streak_freeze')` sunucuda idempotent DEĞİL. Mağaza
-- alımları `shop_purchases` üzerinden "zaten alınmış" kontrolüyle
-- korunuyor, ama `streak_freeze` (ve jokerler) için hiçbir dedup anahtarı
-- yok: her çağrı `coin_transactions` tablosuna yeni bir `-50` satırı
-- yazar.
--
-- İstemci bu yüzden bir kısıt altında çalışmak zorunda kalıyor: sonuç
-- makbuzu `freezeApplying` aşamasında kesilirse harcama BİR DAHA
-- denenmez, çünkü denenirse çift çekim riski var. Bunun bedeli, sunucuya
-- ulaşmış ama cevabı alınamamış bir harcamanın kullanıcı açısından
-- belirsiz kalmasıdır: coin gitmiş olabilir, dondurma uygulanmamıştır.
--
-- ÇÖZÜM
--
-- Harcamaya çağıran tarafından üretilen, değişmez bir idempotency
-- anahtarı verilir (sonuç makbuzunun kimliği: `<user>:<room>`). Anahtar
-- `reason` alanına `streak_freeze:<key>` biçiminde gömülür ve kısmi tekil
-- indeksle yapısal olarak güvenceye alınır. Aynı anahtarla ikinci çağrı
-- yeni satır YAZMAZ; ilk sonucu döndürür.
--
-- Böylece istemci, belirsiz kalan bir harcamayı güvenle tekrar
-- deneyebilir: ikinci çağrı ya ilk çekimi bildirir ya da hiç çekim
-- olmadığını.
--
-- UYGULANMADI
--
-- Bu dosya production'a, staging'e veya local'e UYGULANMAMIŞTIR ve
-- `applied.md` içinde kaydı yoktur. İstemci hâlâ eski
-- `spend_coins(50, 'streak_freeze')` yolunu kullanır ve belirsiz
-- harcamayı tekrar DENEMEZ — yani bu göç uygulanana kadar çift çekim
-- riski artmaz. Göç uygulandıktan sonra istemci
-- `spend_streak_freeze(p_idempotency_key)` çağrısına geçirilmeli ve
-- `freezeApplying` aşaması güvenle yeniden denenebilir hâle gelmelidir.

begin;

-- Anahtarlı dondurma harcamaları için yapısal tekillik.
--
-- Kısmi indeks: yalnız anahtarlı `streak_freeze:` satırlarını kapsar,
-- böylece eski anahtarsız `streak_freeze` kayıtları (aynı kullanıcıda
-- birden çok olabilir) etkilenmez ve göç mevcut veriyle çakışmaz.
create unique index if not exists coin_transactions_streak_freeze_key_uidx
  on public.coin_transactions (player_id, reason)
  where reason like 'streak_freeze:%';

create or replace function public.spend_streak_freeze(
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cost constant integer := 50;
  v_key text;
  v_reason text;
  v_existing integer;
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  -- Anahtar çağıranın kimliğini TAŞIMAZ; kullanıcı kapsamı `player_id`
  -- ile zaten sağlanır. Böylece bir kullanıcının anahtarı başka bir
  -- kullanıcının satırıyla çakışamaz.
  v_key := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  if v_key is null or length(v_key) > 200 then
    return jsonb_build_object('success', false, 'error', 'invalid key');
  end if;
  v_reason := 'streak_freeze:' || v_key;

  -- Aynı kullanıcının eşzamanlı iki denemesi sıraya girer.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  -- Bu anahtarla zaten çekilmiş mi? Çekilmişse İKİNCİ KEZ ÇEKME.
  select coin_tx.amount into v_existing
  from public.coin_transactions coin_tx
  where coin_tx.player_id = v_uid
    and coin_tx.reason = v_reason
  limit 1;

  if found then
    select coalesce(sum(amount), 0)::integer into v_balance
    from public.coin_transactions
    where player_id = v_uid;
    return jsonb_build_object(
      'success', true,
      'already_charged', true,
      'amount', abs(v_existing),
      'balance', v_balance
    );
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions
  where player_id = v_uid;

  if v_balance < v_cost then
    return jsonb_build_object(
      'success', false,
      'error', 'insufficient balance',
      'balance', v_balance
    );
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_cost, v_reason);

  return jsonb_build_object(
    'success', true,
    'already_charged', false,
    'amount', v_cost,
    'balance', v_balance - v_cost
  );
end;
$$;

revoke all on function public.spend_streak_freeze(text)
  from public, anon;
grant execute on function public.spend_streak_freeze(text) to authenticated;

commit;
