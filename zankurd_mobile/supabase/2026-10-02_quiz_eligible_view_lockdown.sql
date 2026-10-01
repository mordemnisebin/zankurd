-- 2026-10-02: quiz_eligible_questions görünümünden istemci yazma yetkisi
-- kaldırıldı ve görünüm security_invoker yapıldı (ACİL).
--
-- NİÇİN: görünüm sahibi postgres (BYPASSRLS), basit bir `select from
-- questions` olduğu için otomatik güncellenebilir (pg_relation_is_updatable
-- = 28) ve anon/authenticated rollerine INSERT/UPDATE/DELETE verilmişti.
-- Görünüm üzerinden yazmada alt tablo yetkisi görünüm sahibi adına
-- denetlendiğinden RLS atlanıyordu: anon anahtarıyla soru bankasına
-- is_approved=true bir satır eklenebilirdi. Güvenlik sertleştirme ajanı
-- buldu; ana ajan yetkiyi salt okunur sorguyla doğruladı (anon INSERT = true).
-- İstemci (yeni ve mağazadaki eski sürüm) bu görünümü hiç kullanmıyor.
-- Geniş yetki temizliği 2026-10-02_grants_hardening.sql'de; bu dosya yalnız
-- en acil açığı kapatır ve tek başına güvenle uygulanabilir.
-- Geri alma: gerekmez (istemci yolu yok); gerekirse grant ile geri verilir.
-- Uygulama: supabase db query --linked -f supabase/2026-10-02_quiz_eligible_view_lockdown.sql
begin;

revoke insert, update, delete, truncate, references, trigger
  on public.quiz_eligible_questions from anon, authenticated, public;
alter view public.quiz_eligible_questions set (security_invoker = true);

do $$
begin
  if has_table_privilege('anon', 'public.quiz_eligible_questions', 'INSERT')
     or has_table_privilege('authenticated', 'public.quiz_eligible_questions', 'INSERT')
     or has_table_privilege('anon', 'public.quiz_eligible_questions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.quiz_eligible_questions', 'UPDATE')
     or has_table_privilege('anon', 'public.quiz_eligible_questions', 'DELETE')
     or has_table_privilege('authenticated', 'public.quiz_eligible_questions', 'DELETE') then
    raise exception 'quiz_eligible_questions hala istemciye yazilabilir';
  end if;
  if not exists (
    select 1 from pg_class
    where oid = 'public.quiz_eligible_questions'::regclass
      and reloptions @> array['security_invoker=true']
  ) then
    raise exception 'security_invoker ayarlanmadi';
  end if;
end
$$;

commit;
