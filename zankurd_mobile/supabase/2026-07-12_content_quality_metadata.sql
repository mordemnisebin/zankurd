-- ============================================================================
-- İçerik Kalite & Editör Meta Verisi — questions tablosu genişletmesi
-- Tarih: 2026-07-12
--
-- DURUM: CANLIYA UYGULANDI (2026-07-14). Uygulama tarafı (QuestionMetadata +
-- ContentQualityPolicy) bu kolonlar olmadan da geriye uyumlu çalışır:
-- kolonlar yoksa istemci metadata'yı null kabul eder ve içerik görünür kalır.
--
-- İlke: mevcut sorulara SAHTE "approved" değeri BASILMAZ. reviewStatus
-- varsayılanı NULL bırakılır (doğrulanmamış = uygun ama onaylanmamış). Yalnız
-- açıkça 'rejected' işaretli sorular son kullanıcı quizinden elenir.
-- ============================================================================

-- 1) Kolonlar (hepsi nullable / güvenli varsayılan; geriye uyumlu)
alter table public.questions
  add column if not exists review_status text
    check (review_status in ('draft','needsReview','approved','rejected')),
  add column if not exists dialect text,
  add column if not exists source_title text,
  add column if not exists source_reference text,
  add column if not exists reviewed_by text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists last_content_check_at timestamptz,
  add column if not exists quality_version integer not null default 0,
  add column if not exists report_count integer not null default 0;

-- 2) Son kullanıcı quizinde uygun soruları döndüren yardımcı view.
--    Katı mod (yalnız approved) BİLİNÇLİ olarak kapalı: sadece rejected elenir,
--    böylece onaylanmamış mevcut havuz görünmez olmaz.
create or replace view public.quiz_eligible_questions as
  select *
  from public.questions
  where is_approved = true
    and review_status is distinct from 'rejected';

-- 3) Kullanıcı bildirimi: report_count artır; eşiği (5) aşınca ve rejected
--    değilse needsReview'e çek. Mevcut report akışıyla uyumlu, güvenli.
create or replace function public.report_question(p_question_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_status text;
begin
  update public.questions
    set report_count = coalesce(report_count, 0) + 1
    where id = p_question_id
    returning report_count, review_status into v_count, v_status;

  if v_count >= 5 and (v_status is distinct from 'rejected') then
    update public.questions
      set review_status = 'needsReview'
      where id = p_question_id;
  end if;
end;
$$;

-- NOT: Gerçek editör kişileri, admin paneli veya canlı onay süreci bu
-- migration'ın kapsamı DIŞINDADIR. Yalnız veri modeli ve güvenli filtre/rapor
-- altyapısı hazırlanmıştır.
