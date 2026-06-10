-- ZanKurd: CSV ile soru bankasi yenileme hazirligi
-- Bu dosyayi Supabase SQL Editor'da bir kez calistir.
-- Sonra questions_import_ready.csv dosyasini Table Editor > questions > Import data
-- ile yukle.

alter table public.questions
  add column if not exists question_type text not null default 'multiple_choice';

alter table public.questions
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_question_type_check'
  ) then
    alter table public.questions
      add constraint questions_question_type_check
      check (question_type in ('multiple_choice', 'true_false', 'visual'));
  end if;
end;
$$;

insert into public.categories (name, slug, is_active)
values
  ('Ziman', 'ziman', true),
  ('Çand', 'cand', true),
  ('Dîrok', 'dirok', true),
  ('Edebiyat', 'edebiyat', true),
  ('Cografya', 'cografya', true),
  ('Muzîk', 'muzik', true)
on conflict (name) do update
set slug = excluded.slug,
    is_active = excluded.is_active;

delete from public.questions
where source_url in ('zankurd_seed_rich_v1', 'zankurd_seed_rich_v2')
   or image_url like '%placehold.co%';
