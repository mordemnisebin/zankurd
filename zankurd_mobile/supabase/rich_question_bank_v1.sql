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
on conflict (name) do update set is_active = excluded.is_active;

delete from public.questions
where source_url = 'zankurd_seed_rich_v1';

insert into public.questions (
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
  image_url,
  source_url
)
values
  ((select id from public.categories where name = 'Ziman'), 'ku-kmr', 'Di Kurmancî de "spas" bi Tirkî çi ye?', 'Teşekkür', 'Selam', 'Kitap', 'Yol', 'A', '"Spas" teşekkür anlamında kullanılır.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Ziman'), 'ku-kmr', 'Peyva "av" di Kurmancî de su anlamına gelir.', 'Rast', 'Şaş', '-', '-', 'A', '"Av" su demektir.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Ziman'), 'ku-kmr', 'Görseldeki kavram Kurmancîde hangisine en yakındır?', 'Çiya', 'Av', 'Mal', 'Pirtûk', 'A', 'Dağ için Kurmancîde "çiya" kullanılır.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=%C3%87iya', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Ziman'), 'ku-kmr', '"Ez dixwînim" cümlesinde fiil hangisidir?', 'dixwînim', 'ez', 'û', 'nav', 'A', '"Dixwînim" okumak fiilinin çekimidir.', 2, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Ziman'), 'ku-kmr', 'Kurmancîde "roj" gece demektir.', 'Rast', 'Şaş', '-', '-', 'B', '"Roj" gün/güneş bağlamında kullanılır; gece "şev"dir.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),

  ((select id from public.categories where name = 'Çand'), 'ku-kmr', 'Newroz bi gelemperî kîjan rojê tê pîroz kirin?', '21 Adar', '1 Gulan', '15 Hezîran', '29 Cotmeh', 'A', 'Newroz genellikle 21 Mart/Adar günü kutlanır.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=Newroz', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Çand'), 'ku-kmr', 'Dengbêjlik sözlü kültürle ilişkilidir.', 'Rast', 'Şaş', '-', '-', 'A', 'Dengbêjlik sözlü anlatım ve ezgili hikaye geleneğidir.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Çand'), 'ku-kmr', 'Kürt kültüründe govend neyle ilgilidir?', 'Halk oyunu', 'Denizcilik', 'Matbaa', 'Astronomi', 'A', 'Govend toplu halk oyunu geleneğidir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Çand'), 'ku-kmr', 'Görseldeki bayram ateşi hangi kültürel günle ilişkilidir?', 'Newroz', 'Ramazan', 'Noel', 'Hıdırellez', 'A', 'Newroz ateşi bu kutlamanın en bilinen sembollerindendir.', 2, true, 'visual', 'https://placehold.co/900x520/png?text=Agir%C3%AA%20Newroz%C3%AA', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Çand'), 'ku-kmr', 'Kilim ve motifler kültürel hafızanın parçası sayılır.', 'Rast', 'Şaş', '-', '-', 'A', 'Motifler yerel kültür, renk ve sembollerle ilişkilidir.', 2, true, 'true_false', null, 'zankurd_seed_rich_v1'),

  ((select id from public.categories where name = 'Dîrok'), 'ku-kmr', 'Medler hangi tarih alanıyla ilişkilidir?', 'Antik Yakın Doğu', 'Viking tarihi', 'Japon feodalizmi', 'Roma hukuku', 'A', 'Medler Antik Yakın Doğu tarihinin önemli topluluklarındandır.', 2, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Dîrok'), 'ku-kmr', 'Mem û Zîn tarih kitabıdır.', 'Rast', 'Şaş', '-', '-', 'B', 'Mem û Zîn edebi/klasik bir eserdir, doğrudan tarih kitabı değildir.', 2, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Dîrok'), 'ku-kmr', 'Görseldeki eski harita fikri hangi soru türüne örnektir?', 'Tarih', 'Müzik', 'Dil bilgisi', 'Spor', 'A', 'Harita ve dönem bilgisi tarih sorularında sık kullanılır.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=Mapa%20D%C3%AErok%C3%AE', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Dîrok'), 'ku-kmr', 'Aşağıdakilerden hangisi tarih çalışmasında birincil kaynak olabilir?', 'Mektup', 'Tahmin', 'Masal yorumu', 'Modern reklam', 'A', 'Mektup, ait olduğu dönem için birincil kaynak olabilir.', 3, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Dîrok'), 'ku-kmr', 'Tarih sadece savaşlardan oluşur.', 'Rast', 'Şaş', '-', '-', 'B', 'Tarih kültür, ekonomi, dil, göç, gündelik yaşam gibi çok geniş alanları kapsar.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),

  ((select id from public.categories where name = 'Edebiyat'), 'ku-kmr', 'Mem û Zîn kimin eseri olarak bilinir?', 'Ehmedê Xanî', 'Cegerxwîn', 'Melayê Cizîrî', 'Feqiyê Teyran', 'A', 'Mem û Zîn, Ehmedê Xanî ile özdeşleşmiş klasik eserdir.', 2, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Edebiyat'), 'ku-kmr', 'Şiir sadece düz yazıdan oluşur.', 'Rast', 'Şaş', '-', '-', 'B', 'Şiir ritim, imge, ölçü veya serbest biçim gibi özellikler taşıyabilir.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Edebiyat'), 'ku-kmr', 'Görseldeki kitap simgesi hangi alanı çağrıştırır?', 'Edebiyat', 'Coğrafya', 'Kimya', 'Spor', 'A', 'Kitap simgesi edebiyat ve okuma alanıyla ilişkilidir.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=Pirt%C3%BBk', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Edebiyat'), 'ku-kmr', 'Kurmancîde "çîrok" hangi türle ilişkilidir?', 'Hikaye', 'Harita', 'Rakam', 'Ağırlık', 'A', '"Çîrok" hikaye/öykü anlamına gelir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Edebiyat'), 'ku-kmr', 'Dengbêj anlatıları edebiyat ve sözlü kültürle de ilişkilendirilebilir.', 'Rast', 'Şaş', '-', '-', 'A', 'Sözlü anlatım edebi kültürün önemli parçalarından biridir.', 2, true, 'true_false', null, 'zankurd_seed_rich_v1'),

  ((select id from public.categories where name = 'Cografya'), 'ku-kmr', 'Kurmancîde "çiya" ne demektir?', 'Dağ', 'Deniz', 'Ova', 'Köprü', 'A', '"Çiya" dağ anlamına gelir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Cografya'), 'ku-kmr', 'Dicle ve Fırat bölge coğrafyasında önemli nehirlerdir.', 'Rast', 'Şaş', '-', '-', 'A', 'Her iki nehir de Mezopotamya coğrafyası için önemlidir.', 2, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Cografya'), 'ku-kmr', 'Görseldeki akarsu sembolü Kurmancîde en çok hangisiyle ilgilidir?', 'Av', 'Agir', 'Kevir', 'Dar', 'A', '"Av" su anlamına gelir.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=Av', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Cografya'), 'ku-kmr', 'Aşağıdakilerden hangisi bir yeryüzü şeklidir?', 'Ova', 'Fiil', 'Cümle', 'Nota', 'A', 'Ova coğrafi bir yeryüzü şeklidir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Cografya'), 'ku-kmr', 'İklim ve bitki örtüsü coğrafyanın konuları arasındadır.', 'Rast', 'Şaş', '-', '-', 'A', 'Coğrafya doğal ve beşeri çevreyi birlikte inceler.', 2, true, 'true_false', null, 'zankurd_seed_rich_v1'),

  ((select id from public.categories where name = 'Muzîk'), 'ku-kmr', 'Dengbêj geleneği hangi alanla daha çok ilişkilidir?', 'Sözlü müzik/anlatı', 'Mimari çizim', 'Matematik ispatı', 'Harita okuma', 'A', 'Dengbêjlik ezgili sözlü anlatım geleneğidir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Muzîk'), 'ku-kmr', 'Def ve erbane vurmalı çalgılar arasında sayılır.', 'Rast', 'Şaş', '-', '-', 'A', 'Bu çalgılar ritim temelli vurmalı çalgılar olarak bilinir.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Muzîk'), 'ku-kmr', 'Görseldeki ritim simgesi hangi kategoriye en yakındır?', 'Muzîk', 'Dîrok', 'Cografya', 'Ziman', 'A', 'Ritim, müzik bilgisinin temel öğelerindendir.', 1, true, 'visual', 'https://placehold.co/900x520/png?text=R%C3%AEtm', 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Muzîk'), 'ku-kmr', 'Şarkıda söz, ritim ve melodi birlikte bulunabilir.', 'Rast', 'Şaş', '-', '-', 'A', 'Birçok şarkı bu üç unsurun birleşiminden oluşur.', 1, true, 'true_false', null, 'zankurd_seed_rich_v1'),
  ((select id from public.categories where name = 'Muzîk'), 'ku-kmr', 'Aşağıdakilerden hangisi müzikle ilgili bir kavramdır?', 'Melodî', 'Dağ sırası', 'Fiil çekimi', 'Kaynakça', 'A', 'Melodi müziğin temel kavramlarından biridir.', 1, true, 'multiple_choice', null, 'zankurd_seed_rich_v1');
