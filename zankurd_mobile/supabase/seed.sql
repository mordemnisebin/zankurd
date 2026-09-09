-- Local-only deterministic seed for `supabase db reset` and backend integration tests.
-- This file contains data only. Schema changes belong in migrations.

insert into public.categories (id, name, slug, is_active)
values (
  '11111111-1111-4111-8111-111111111111'::uuid,
  'Ziman',
  'ziman',
  true
)
on conflict (name) do update
set slug = excluded.slug,
    is_active = excluded.is_active;

insert into public.questions (
  id,
  category_id,
  language_code,
  prompt,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option,
  explanation,
  difficulty,
  is_approved,
  question_type,
  source_url,
  review_status,
  dialect,
  source_title,
  source_reference,
  quality_version
)
values
  (
    '20000000-0000-4000-8000-000000000001'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “av” bi Tirkî çi ye?',
    'Su', 'Ateş', 'Ev', 'Dağ', 'A',
    '“Av” bi Tirkî “su” ye.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:av', 1
  ),
  (
    '20000000-0000-4000-8000-000000000002'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “roj” bi Tirkî çi ye?',
    'Gece', 'Gün/güneş', 'Su', 'Yol', 'B',
    '“Roj” bi Tirkî “gün/güneş” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:roj', 1
  ),
  (
    '20000000-0000-4000-8000-000000000003'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “pirtûk” bi Tirkî çi ye?',
    'Kalem', 'Okul', 'Kitap', 'Kapı', 'C',
    '“Pirtûk” bi Tirkî “kitap” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:pirtuk', 1
  ),
  (
    '20000000-0000-4000-8000-000000000004'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “heval” bi Tirkî çi ye?',
    'Aile', 'Öğretmen', 'Çocuk', 'Arkadaş', 'D',
    '“Heval” bi Tirkî “arkadaş” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:heval', 1
  ),
  (
    '20000000-0000-4000-8000-000000000005'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “çiya” bi Tirkî çi ye?',
    'Dağ', 'Nehir', 'Ova', 'Göl', 'A',
    '“Çiya” bi Tirkî “dağ” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:ciya', 1
  ),
  (
    '20000000-0000-4000-8000-000000000006'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “nan” bi Tirkî çi ye?',
    'Süt', 'Ekmek', 'Peynir', 'Elma', 'B',
    '“Nan” bi Tirkî “ekmek” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:nan', 1
  ),
  (
    '20000000-0000-4000-8000-000000000007'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “bajar” bi Tirkî çi ye?',
    'Köy', 'Mahalle', 'Şehir', 'Sokak', 'C',
    '“Bajar” bi Tirkî “şehir” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:bajar', 1
  ),
  (
    '20000000-0000-4000-8000-000000000008'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “gund” bi Tirkî çi ye?',
    'Şehir', 'Cadde', 'Meydan', 'Köy', 'D',
    '“Gund” bi Tirkî “köy” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:gund', 1
  ),
  (
    '20000000-0000-4000-8000-000000000009'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “spas” bi Tirkî çi ye?',
    'Teşekkür', 'Merhaba', 'Lütfen', 'Hoşça kal', 'A',
    '“Spas” ji bo teşekkürkirinê tê bikaranîn.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:spas', 1
  ),
  (
    '20000000-0000-4000-8000-000000000010'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “şev” bi Tirkî çi ye?',
    'Sabah', 'Gece', 'Öğle', 'Gün', 'B',
    '“Şev” bi Tirkî “gece” ye.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:sev', 1
  ),
  (
    '20000000-0000-4000-8000-000000000011'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “rê” bi Tirkî çi ye?',
    'Kapı', 'Ev', 'Yol', 'Dağ', 'C',
    '“Rê” bi Tirkî “yol” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:re', 1
  ),
  (
    '20000000-0000-4000-8000-000000000012'::uuid,
    (select id from public.categories where name = 'Ziman'),
    'ku-kmr',
    'Di Kurmancî de peyva “zarok” bi Tirkî çi ye?',
    'Arkadaş', 'Öğretmen', 'Aile', 'Çocuk', 'D',
    '“Zarok” bi Tirkî “çocuk” e.',
    1, true, 'multiple_choice', 'zankurd_local_seed', 'approved', 'ku-kmr',
    'ZanKurd local integration seed', 'local-seed:zarok', 1
  )
on conflict (id) do update
set category_id = excluded.category_id,
    language_code = excluded.language_code,
    prompt = excluded.prompt,
    option_a = excluded.option_a,
    option_b = excluded.option_b,
    option_c = excluded.option_c,
    option_d = excluded.option_d,
    correct_option = excluded.correct_option,
    explanation = excluded.explanation,
    difficulty = excluded.difficulty,
    is_approved = excluded.is_approved,
    question_type = excluded.question_type,
    source_url = excluded.source_url,
    review_status = excluded.review_status,
    dialect = excluded.dialect,
    source_title = excluded.source_title,
    source_reference = excluded.source_reference,
    quality_version = excluded.quality_version,
    updated_at = now();
