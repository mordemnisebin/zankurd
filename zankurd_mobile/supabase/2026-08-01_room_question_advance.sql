-- Oda maçında 1. sorudan sonraki hiçbir cevap kaydedilmiyordu.
--
-- ## Belirti
--
-- İki gerçek cihaz arasında oda maçı oynanınca (Android ev sahibi,
-- iOS katılan) 1. soru düzgün işledi — puan sunucudan geldi. 2. sorudan
-- itibaren her cevapta:
--
--   PostgrestException(message: Question is not the current active room
--   question, code: P0001)
--
-- ve ekranda "Cevap gönderilemedi. Lütfen tekrar dene." Tekrar denemek de
-- işe yaramıyordu; on soruluk maçın dokuzu boşa gidiyordu.
--
-- 2026-08-01'de canlı iki cihazlı denemede bulundu.
--
-- ## Sebep — iki doğru kararın kesişimi
--
-- 1. `2026-07-22_multiplayer_integrity_hardening.sql:34`
--    `"Hosts can update their own rooms"` politikasını KALDIRDI. Doğruydu:
--    ev sahibi `rooms` satırının her sütununu (skor, durum, soru sayısı)
--    serbestçe yazabilmemeli.
-- 2. `2026-07-29_release_readiness_hardening.sql` `player_answers` üzerine
--    `enforce_current_room_question` tetikleyicisini koydu: cevabın soru
--    indeksi `rooms.current_question_index` ile eşleşmeli. Bu da doğruydu:
--    ileri bir sorunun cevabı önceden gönderilememeli.
--
-- Ama `quiz_screen.dart` sorudan soruya geçerken hâlâ DOĞRUDAN tablo
-- güncellemesi yapıyordu:
--
--     client.from('rooms').update({'current_question_index': next})
--
-- 1. madde bu güncellemeyi engelliyor. Engelliyor ama **hata vermiyor**:
-- PostgREST'te `select` istenmeyen bir `update`, RLS yüzünden sıfır satır
-- eşleşse de 204 No Content döner. İstemci ilerlettiğini sanıyor.
--
-- Sonuç: `current_question_index` sonsuza dek 0'da kalıyor, iki istemci de
-- yerel olarak ilerliyor, ve 2. sorudan sonraki her cevabı 2. maddedeki
-- tetikleyici reddediyor.
--
-- Kusur kod okumasıyla görünmüyordu çünkü üç dosyanın kesişiminde duruyor
-- ve hiçbiri tek başına yanlış değil. Tek cihazda da görünmüyordu: oda
-- maçı iki oyuncu olmadan başlamıyor.
--
-- ## Düzeltme
--
-- İlerletme, doğrudan tablo yazımından çıkıp `security definer` bir RPC'ye
-- taşınıyor. Böylece:
--
--   * ev sahibi `rooms` üzerinde geniş yazma hakkı KAZANMIYOR — 1. maddenin
--     koruması yerinde kalıyor, yalnız tek sütun tek yönde değişiyor,
--   * indeks bir artıyor ve soru sayısını aşamıyor (istemci hatası odayı
--     bitirilemez hâle getiremesin),
--   * ve en önemlisi: yetki yoksa RPC **hata döndürüyor**. Sessiz başarı
--     kusuru bir daha aynı biçimde saklanamaz.

begin;

create or replace function public.advance_room_question(p_room_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_next integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select count(*)::integer into v_count
  from public.room_questions
  where room_id = p_room_id;

  if v_count < 1 then
    raise exception 'Room has no questions';
  end if;

  -- Son soruyu aşmaz: `finish_room_game`, indeksin en az `count - 1`
  -- olmasını şart koşuyor; üstüne çıkmak bir şey kazandırmaz ama
  -- kayıtları tutarsız yapardı.
  update public.rooms r
     set current_question_index =
           least(coalesce(r.current_question_index, 0) + 1, v_count - 1)
   where r.id = p_room_id
     and r.host_id = v_uid
     and r.status = 'active'
  returning r.current_question_index into v_next;

  if v_next is null then
    raise exception 'Only the active room host can advance the question';
  end if;

  return v_next;
end;
$$;

revoke all on function public.advance_room_question(uuid) from public, anon;
grant execute on function public.advance_room_question(uuid) to authenticated;

commit;
