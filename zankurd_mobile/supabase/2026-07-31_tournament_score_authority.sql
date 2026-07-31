-- Turnuva skor yetkisi ve tur ilerlemesi (forward-only, idempotent).
--
-- ## Niçin
--
-- `submit_tournament_match(p_match_id, p_score)` istemcinin bildirdiği
-- skoru hiçbir sunucu kaydına karşı doğrulamadan, ÜST SINIR da koymadan
-- kabul ediyordu. Tek koruma `greatest(coalesce(p_score, 0), 0)` idi ve
-- o yalnız negatifi kırpar.
--
-- Yani maçtaki iki oyuncudan biri REST üzerinden `p_score = 2147483647`
-- göndererek her maçı kazanır, `advance_tournament` onu şampiyon yapar ve
-- `claim_tournament_reward` turnuva başına 200 coin yatırır. Coin
-- `spend_coins` ile mağazadan VIP rozeti dahil her şeyi alıyor. Anonim
-- giriş açık olduğu için saldırgan sınırsız hesap açıp bunu tekrarlayabilir.
--
-- Bu, projenin geri kalanındaki disiplinle çelişen tek açık kalan
-- istemci-yetkili ödül yoluydu: `submit_contest_entry` 2026-07-29'da tam
-- bu sebeple `contest_verification_required` ile kapatılmıştı.
--
-- ## Niçin kapatmak değil sınırlamak
--
-- Yarışma tarafında seçilen çözüm fonksiyonu tamamen kapatmaktı, çünkü
-- yarışma o gün canlıda kullanılmıyordu. Turnuva ise yayınlanmış ve
-- oynanan bir özellik; kapatmak çalışan bir şeyi kırar. Bunun yerine
-- skor, oyunun kendi puanlamasının izin verdiği en yüksek değere
-- sabitlenir.
--
-- Tavan oyundan türetiliyor: doğru cevap `100 + (streak * 10)` puan
-- verir ve seri bonusu 50'de sınırlıdır (quiz_screen.dart), yani soru
-- başına en çok 150. Maç başına soru sayısı artık şemada duruyor
-- (varsayılan 4), dolayısıyla tavan `questions_per_match * 150`.
--
-- Bu, sahtekârlığı tamamen bitirmez — oyuncu hâlâ hak etmediği bir skoru
-- bildirebilir — ama sınırsız coin basma yolunu kapatır ve turnuvayı
-- oynanabilir bırakır. Kalıcı çözüm, maçın da oda gibi `room_questions` +
-- `submit_answer` üzerinden oynanıp skorun `sum(player_answers.
-- points_awarded)` ile sunucuda hesaplanmasıdır; o gelene kadar bu tavan
-- ara önlemdir.

begin;

-- Maç başına soru sayısı şemaya taşınıyor: tavan sabit bir sayıya değil
-- turnuvanın kendi yapılandırmasına bağlansın.
alter table public.tournaments
  add column if not exists questions_per_match int not null default 4;

comment on column public.tournaments.questions_per_match is
  'Bir maçtaki soru sayısı. submit_tournament_match skor tavanını buradan '
  'türetir: questions_per_match * 150 (soru başına en yüksek puan).';

create or replace function public.submit_tournament_match(
  p_match_id uuid,
  p_score int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_match public.tournament_matches;
  v_winner uuid;
  v_score int := greatest(coalesce(p_score, 0), 0);
  v_max_score int;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select * into v_match from public.tournament_matches
   where id = p_match_id for update;
  if not found then
    raise exception 'Match not found';
  end if;
  if v_user not in (coalesce(v_match.player_one, '00000000-0000-0000-0000-000000000000'::uuid),
                    coalesce(v_match.player_two, '00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'Player is not in this match';
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('status', 'completed',
                              'winner_id', v_match.winner_id);
  end if;

  -- Skor tavanı: oyunun puanlamasının izin verdiği en yüksek değer.
  -- Soru başına 150 (100 taban + 50 seri bonusu tavanı).
  select coalesce(t.questions_per_match, 4) * 150
    into v_max_score
    from public.tournaments t
   where t.id = v_match.tournament_id;

  v_score := least(v_score, coalesce(v_max_score, 600));

  -- Skor tek sefer kabul edilir: ikinci gönderim sessizce yok sayılır,
  -- yoksa oyuncu turu tekrar oynayıp skorunu yükseltebilirdi.
  if v_user = v_match.player_one and v_match.submitted_one is null then
    update public.tournament_matches
       set score_one = v_score, submitted_one = now()
     where id = p_match_id;
  elsif v_user = v_match.player_two and v_match.submitted_two is null then
    update public.tournament_matches
       set score_two = v_score, submitted_two = now()
     where id = p_match_id;
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;

  if v_match.submitted_one is not null and v_match.submitted_two is not null
  then
    -- Eşitlikte daha erken bitiren geçer: aynı skoru önce tamamlamak
    -- ölçülebilir bir üstünlüktür ve yazı-tura atmaktan yeğdir.
    if coalesce(v_match.score_one, 0) > coalesce(v_match.score_two, 0) then
      v_winner := v_match.player_one;
    elsif coalesce(v_match.score_two, 0) > coalesce(v_match.score_one, 0) then
      v_winner := v_match.player_two;
    elsif v_match.submitted_one <= v_match.submitted_two then
      v_winner := v_match.player_one;
    else
      v_winner := v_match.player_two;
    end if;

    update public.tournament_matches
       set status = 'completed', winner_id = v_winner
     where id = p_match_id;

    perform public.advance_tournament(v_match.tournament_id);
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;
  return jsonb_build_object('status', v_match.status,
                            'winner_id', v_match.winner_id);
end;
$$;

-- Süresi dolmuş maçlarda oynamış olan geçer (hükmen); ikisi de
-- oynamadıysa maç kimseye yazılmaz ve üst tur boş kalır.
--
-- DÜZELTME: eski hâli maçları `completed` yapıyor ama bir sonraki turu
-- KURMUYORDU — `advance_tournament` çağrısı yoktu ve deponun tamamında
-- onun tek çağıranı `submit_tournament_match`ti. Yani iki oyuncu da süreyi
-- kaçırırsa turnuva sonsuza dek o turda kilitleniyordu: maçlar bitmiş
-- görünüyor, üst tur hiç kurulmuyor, kimse şampiyon olmuyor ve
-- `claim_tournament_reward` hiçbir zaman ödeme yapmıyordu (2026-07-31).
create or replace function public.resolve_expired_tournament_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tournament uuid;
begin
  update public.tournament_matches
     set status = 'completed',
         winner_id = case
           when submitted_one is not null and submitted_two is null
             then player_one
           when submitted_two is not null and submitted_one is null
             then player_two
           else null
         end
   where status <> 'completed'
     and deadline is not null
     and deadline < now();

  -- Süresi dolmuş maçı olan her turnuvayı bir tur ilerlet. Ayrı bir
  -- döngü: `advance_tournament` kendi içinde turun tamamlanıp
  -- tamamlanmadığına bakar, erken çağrı zararsızdır.
  for v_tournament in
    select distinct m.tournament_id
      from public.tournament_matches m
     where m.status = 'completed'
       and m.deadline is not null
       and m.deadline < now()
  loop
    perform public.advance_tournament(v_tournament);
  end loop;
end;
$$;

revoke all on function public.submit_tournament_match(uuid, int)
  from public, anon;
grant execute on function public.submit_tournament_match(uuid, int)
  to authenticated;

revoke all on function public.resolve_expired_tournament_matches()
  from public, anon, authenticated;

commit;
