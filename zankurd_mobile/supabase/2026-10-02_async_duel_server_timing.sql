-- 2026-10-02: sırayla düelloda cevap süresi sunucuda ölçülür (güvenlik
-- denetimi M4).
--
-- KUSUR: `answer_async_duel` süreyi istemciden (`p_response_ms`) alıyordu
-- (yalnız 0–120000 kırpmasıyla). Düellonun sonucu önce doğru sayısına, EŞİTSE
-- toplam süreye bakar ve +30 XP kazanan bonusu (`claim_async_duel_xp`) aynı
-- süreye bağlıdır. Değiştirilmiş bir istemci her soruya 1 ms yazıp bütün
-- eşitlikleri ve bonusları kazanırdı.
--
-- DÜZELTME: süre = bu cevabın sunucuya ulaşma anı − sorunun oyuncuya
-- sunulduğu an, [0, 20000] ms'e kırpılı. "Sunuldu" anı oyuncunun önceki
-- cevabının `answered_at` değeri; ilk soruda yaratıcı için `created_at`,
-- rakip için `matched_at` (start_async_duel soruları o anda döndürür).
-- Yeni sütun/tablo GEREKMEZ: `async_duel_answers.answered_at` zaten var.
-- `TIMEOUT` her zaman 20000 ms. İstemci değeri yok sayılır.
--
-- İMZA/ESKİ İSTEMCİ: `answer_async_duel(uuid, integer, text, integer)` AYNI,
-- dönüş anahtarları AYNI. (Bu RPC mağazadaki 468ea4a4 sürümünde yok; canlıda
-- 0 düello var — yine de uyumlu bırakıldı.) Yalnız `response_ms` değerleri
-- artık sunucu ölçümü.
--
-- DOĞRU ŞIKKIN YARATICIYA HEMEN DÖNMESİ: değerlendirildi, DEĞİŞTİRİLMEDİ.
-- Yaratıcı her cevaptan sonra `correct_option`ı görür; rakip sonra eşleşir,
-- yani yaratıcı şıkları rakip hesabına (ikinci hesabı) aktarabilir.
-- Bunu kapatmak için yaratıcıya `correct_option`ı düello bitene kadar
-- vermemek gerekir; bu, yarım oyuncunun ("açan") anlık geri bildirimini ve
-- yanlış cevaptan öğrenmeyi (ürünün ana değeri) siler. Kazanç dar (yalnız
-- iki hesabı olan biri, +30 XP ve düello başına en çok 7×20 XP; XP günlük
-- tavanı 20000 XP) ve soru bankasının büyük kısmı zaten uygulamada
-- paketli. Ürün sahibi isterse tek satırlık değişiklik: bu fonksiyonda
-- `'correct_option', v_correct_option` yerine
-- `'correct_option', case when v_uid = v_duel.creator_id and
-- v_duel.status <> 'completed' then null else v_correct_option end`
-- (istemci `AsyncDuelAnswer.correctOption` nullable yapılmalı).
--
-- ARTA KALAN RİSK: soru bankasını bilen otomatik bir istemci doğru cevapları
-- anında gönderebilir; süre ölçümü onu engellemez (yalnız yapay 0 ms'yi
-- engeller). Hız sınırı ve CAPTCHA Dashboard işi.
--
-- GERİ ALMA: `2026-09-28_async_duels.sql` içindeki `answer_async_duel`
-- gövdesini yeniden çalıştırın.

begin;

CREATE OR REPLACE FUNCTION public.answer_async_duel(p_duel_id uuid, p_question_index integer, p_choice text, p_response_ms integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_id uuid;
  v_total integer;
  v_question_id uuid;
  v_correct_option text;
  v_is_correct boolean;
  v_response_ms integer;
  v_prev_at timestamptz;
  v_baseline timestamptz;
  v_server_ms integer;
  -- İstemcideki soru süresi (async_duel_play_screen `_questionSeconds` = 20).
  v_max_ms constant integer := 20000;
  v_answered integer;
  v_finished boolean := false;
  v_my_correct integer;
  v_my_ms integer;
  v_opp_correct integer;
  v_opp_ms integer;
  v_opponent_done boolean := false;
  v_completed_now boolean := false;
  v_outcome text;
  v_result jsonb := null;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found';
  end if;

  if v_uid = v_duel.creator_id then
    v_other_id := v_duel.opponent_id;
  elsif v_uid = v_duel.opponent_id then
    v_other_id := v_duel.creator_id;
  else
    raise exception 'Not a duel player';
  end if;

  if v_duel.status <> 'completed' and now() > v_duel.expires_at then
    raise exception 'Duel expired';
  end if;

  v_total := coalesce(array_length(v_duel.question_ids, 1), 0);
  if p_question_index is null
     or p_question_index < 0
     or p_question_index >= v_total then
    raise exception 'Invalid index';
  end if;

  if p_choice is null or p_choice not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid choice';
  end if;

  v_question_id := v_duel.question_ids[p_question_index + 1];
  select q.correct_option into v_correct_option
  from public.questions q
  where q.id = v_question_id;

  -- correct_option beklenmedik biçimde NULL gelirse (bozuk veri) bile
  -- NOT NULL is_correct sütununa NULL yazmayı önler.
  v_is_correct := coalesce(v_correct_option = p_choice, false);
  -- SÜRE SUNUCUDA ÖLÇÜLÜR. `p_response_ms` artık kullanılmaz: eşitlik
  -- bozucu ve +30 XP kazanan bonusu bu süreye bağlı, istemci değeri ise
  -- değiştirilmiş bir istemciyle 1 ms yazılabiliyordu. Soru "sunuldu" anı:
  --   * oyuncunun bu düellodaki önceki cevabının zamanı, yoksa
  --   * ilk soruda: yaratıcıda düellonun açılışı (`created_at`), rakipte
  --     eşleşme anı (`matched_at`) — sorular start_async_duel yanıtıyla
  --     o anda iletilir.
  -- Ölçülen süre [0, 20000] ms'e kırpılır (soru süresi; uygulamayı arka
  -- plana atıp saatler sonra dönen oyuncu en çok TIMEOUT kadar kaybeder).
  -- Dürüst istemcinin kendi kronometresi hiçbir zaman sunucu aralığından
  -- uzun olamaz (ağ + cevap gösterim bekleme süresi sunucu tarafında
  -- sayılır, iki oyuncu için de aynı sabit pay), bu yüzden sıralama adil
  -- kalır. Eski istemcinin 4 parametreli çağrısı aynen çalışır.
  select max(a.answered_at) into v_prev_at
  from public.async_duel_answers a
  where a.duel_id = p_duel_id
    and a.player_id = v_uid;

  v_baseline := coalesce(
    v_prev_at,
    case
      when v_uid = v_duel.creator_id then v_duel.created_at
      else coalesce(v_duel.matched_at, v_duel.created_at)
    end
  );

  v_server_ms := greatest(
    0,
    least(
      floor(extract(epoch from (now() - v_baseline)) * 1000),
      v_max_ms
    )
  )::integer;

  v_response_ms := case when p_choice = 'TIMEOUT' then v_max_ms else v_server_ms end;

  begin
    insert into public.async_duel_answers (
      duel_id, player_id, question_index, choice, is_correct, response_ms
    ) values (
      p_duel_id, v_uid, p_question_index, p_choice, v_is_correct, v_response_ms
    );
  exception
    when unique_violation then
      raise exception 'Already answered';
  end;

  select count(*) into v_answered
  from public.async_duel_answers
  where duel_id = p_duel_id
    and player_id = v_uid;

  if v_answered >= v_total then
    v_finished := true;

    select
      count(*) filter (where is_correct)::integer,
      coalesce(sum(response_ms), 0)::integer
    into v_my_correct, v_my_ms
    from public.async_duel_answers
    where duel_id = p_duel_id
      and player_id = v_uid;

    insert into public.async_duel_results (
      duel_id, player_id, correct_count, total_ms
    ) values (
      p_duel_id, v_uid, v_my_correct, v_my_ms
    )
    on conflict (duel_id, player_id) do update
      set correct_count = excluded.correct_count,
          total_ms = excluded.total_ms
    returning correct_count, total_ms into v_my_correct, v_my_ms;

    if v_other_id is not null then
      select correct_count, total_ms into v_opp_correct, v_opp_ms
      from public.async_duel_results
      where duel_id = p_duel_id
        and player_id = v_other_id;

      v_opponent_done := found;
    end if;

    if v_opponent_done then
      update public.async_duels
      set status = 'completed',
          completed_at = now()
      where id = p_duel_id
        and status <> 'completed';

      v_completed_now := found;

      v_outcome := case
        when v_my_correct > v_opp_correct then 'win'
        when v_my_correct < v_opp_correct then 'loss'
        when v_my_ms < v_opp_ms then 'win'
        when v_my_ms > v_opp_ms then 'loss'
        else 'draw'
      end;

      v_result := jsonb_build_object(
        'status', 'completed',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'opponent_correct', v_opp_correct,
        'opponent_ms', v_opp_ms,
        'outcome', v_outcome
      );

      -- Sonucu az önce TAMAMLAYAN bu çağrı olduğunda, bekleyen diğer
      -- oyuncuya tek seferlik bildirim kuyruklanır (enqueue_friend_request_push
      -- ile aynı desen: bkz. 2026-08-26_fcm_token.sql).
      if v_completed_now then
        insert into public.push_outbox (to_user_id, kind, title, body)
        values (
          v_other_id,
          'async_duel_result',
          'ZanKurd',
          -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
          'Pêşbirka te qediya — encamê bibîne · Düellon bitti — sonucu gör'
        );
      end if;
    else
      v_result := jsonb_build_object(
        'status', 'waiting',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'opponent_correct', null,
        'opponent_ms', null,
        'outcome', null
      );
    end if;
  end if;

  return jsonb_build_object(
    'correct', v_is_correct,
    'correct_option', v_correct_option,
    'answered', v_answered,
    'total', v_total,
    'finished', v_finished,
    'result', v_result
  );
end;
$function$;

revoke all on function public.answer_async_duel(uuid, integer, text, integer)
  from public, anon;
grant execute on function public.answer_async_duel(uuid, integer, text, integer)
  to authenticated;

do $$
declare
  v_def text := pg_get_functiondef(
    'public.answer_async_duel(uuid,integer,text,integer)'::regprocedure
  );
begin
  if v_def not like '%v_server_ms%' then
    raise exception 'answer_async_duel sunucu süresini ölçmüyor';
  end if;
  if v_def like '%least(coalesce(p_response_ms%' then
    raise exception 'answer_async_duel hâlâ istemci süresine güveniyor';
  end if;
  if has_function_privilege(
       'anon', 'public.answer_async_duel(uuid,integer,text,integer)', 'execute') then
    raise exception 'answer_async_duel anon''a açık';
  end if;
  if not has_function_privilege(
       'authenticated', 'public.answer_async_duel(uuid,integer,text,integer)', 'execute') then
    raise exception 'answer_async_duel authenticated''a kapalı';
  end if;
end $$;

commit;
