-- 2026-11-01: TURNUVADAN AYRILMA (başlamadan önce).
--
-- Kusur: `join_tournament` oyuncuyu açık kupaya yazar ama çıkış yolu yoktu.
-- Kontenjan (4) dolmayan kupada oyuncu en çok 24 saat boyunca, başka hiçbir
-- şey yapamadan, kayıtlı kalıyordu; vazgeçmek için tek yol hesabı silmekti.
--
-- `leave_tournament()`:
--   * yalnız `auth.uid()` sahibi; parametre yok, başkası adına ayrılınamaz,
--   * yalnız kupa HÂLÂ 'open' iken: başladıysa (running/finished) kayıt silinmez
--     (eşleşmeler kurulmuş, rakip beklemede) ve `reason: 'started'` döner,
--   * kupa satırı kilitlenir: `start_tournament` de aynı kilidi alır, bu yüzden
--     "tam başlarken ayrılma" yarışı tek yöne çözülür,
--   * katılım ÜCRETİ yoktur (`join_tournament` coin düşmez; bkz. 2026-07-26
--     göçü), dolayısıyla iade edilecek bir şey de yok. Ücret eklenirse iade
--     bu fonksiyona eklenmelidir,
--   * yeniden uygulanabilir (idempotent): kaydı olmayan oyuncuya hata yerine
--     `left: true, already: true` döner; ikinci çağrı zararsızdır,
--   * hata fırlatmaz (kimlik yoksa hariç): istemci sonucu okuyup ekranı yeniler.
begin;

create or replace function public.leave_tournament()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_tid uuid;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Authenticated user required';
  end if;

  -- Oyuncunun en yeni (açık ya da süren) kaydı; join ile aynı seçim.
  select t.id into v_tid
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_uid
     and t.status in ('open', 'running')
   order by t.opened_at desc
   limit 1;

  if v_tid is null then
    return jsonb_build_object('left', true, 'already', true);
  end if;

  -- Kupayı kilitle ve durumu kilit altında yeniden oku.
  select status into v_status
    from public.tournaments
   where id = v_tid
   for update;

  if v_status is distinct from 'open' then
    return jsonb_build_object('left', false, 'reason', 'started',
                              'tournament_id', v_tid);
  end if;

  delete from public.tournament_entries
   where tournament_id = v_tid
     and player_id = v_uid;

  return jsonb_build_object('left', true, 'tournament_id', v_tid);
end;
$function$;

revoke all on function public.leave_tournament() from public, anon;
grant execute on function public.leave_tournament() to authenticated;

commit;
