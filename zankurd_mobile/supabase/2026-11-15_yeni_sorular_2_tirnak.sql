-- 2026-11-15: yeni sorular 2 alintilarini tek tirnaktan duz cift tirnaga cevirir
--
-- NICIN: 2026-11-10_yeni_sorular_2.sql canlida uygulandi; yerel bankadaki
-- (assets/data/yeni2_2026_11_10_questions.json) alinti tirnaklari ev bicimine
-- (duz cift tirnak, bkz. question_quotation_style_test / question_typography_test)
-- cevrildi. Sunucu ve yerel ayni soruda ayni metni gostersin diye ayni
-- degisiklik sunucuya uygulanir. Yalnizca alinti tirnak karakteri degisir.
--
-- KAPSAM: 21 soru, 26 (id, sutun) cifti; sunucuda olmayan
-- alanlar (promptTr, Turkce JSON explanation) dahil degildir.
--
-- ON KOSUL: bir satir yalniz sutun degeri BEKLENEN ESKI metne esitse guncellenir;
-- baska bir degerse dokunulmaz ve sayilir. Zaten yeni degerdeyse "zaten" sayilir.
-- IDEMPOTENT: ikinci calistirmada her sey "zaten" cikar, hicbir satir degismez.
-- Sonuc NOTICE olarak yazilir: uygulanan / zaten / uyusmayan / bulunamayan.

begin;

create temp table _tirnak (local_id text, id uuid, col text, eski text, yeni text) on commit drop;

insert into _tirnak (local_id, id, col, eski, yeni) values
  ('r14_sinema_012', 'f0d84e6a-0c0f-5829-83c5-e8d7f1f5a989'::uuid, 'explanation_tr', '''Dağların Chaplin''i'' (Chaplin of the Mountains, 2013) filmi Jano Rosebiani tarafından Kürtçe ve İngilizce olarak çekilmiştir.', '"Dağların Chaplin''i" (Chaplin of the Mountains, 2013) filmi Jano Rosebiani tarafından Kürtçe ve İngilizce olarak çekilmiştir.'),
  ('r14_sinema_199', '277e7f28-6c36-5002-93b4-b8ad1062caa0'::uuid, 'explanation_tr', 'Fritz Lang, ''Metropolis''te sınıflara bölünmüş fütüristik bir şehri ve sinema tarihini derinden etkileyen robot Maria karakterini beyaz perdeye taşımıştır.', 'Fritz Lang, "Metropolis"te sınıflara bölünmüş fütüristik bir şehri ve sinema tarihini derinden etkileyen robot Maria karakterini beyaz perdeye taşımıştır.'),
  ('r14_sinema_280', '2ce2bd39-09f8-5543-8729-dafb41bc5d24'::uuid, 'prompt', 'Lîstikvana navdar a amerîkî ya ku bi zêdetirî 20 caran bûye berendama Xelata Oscarê û bi fîlmên wekî ''Sophie''s Choice'' û "The Iron Lady" xelat wergirtiye kî ye?', 'Lîstikvana navdar a amerîkî ya ku bi zêdetirî 20 caran bûye berendama Xelata Oscarê û bi fîlmên wekî "Sophie''s Choice" û "The Iron Lady" xelat wergirtiye kî ye?'),
  ('r14_sinema_273', '3ead90e1-bc08-5a10-acf5-8731fbe10b41'::uuid, 'prompt', 'Lîstikvanê hosta yê ku di fîlmê "Kis Uykusu" de rola Aydin lîst û bi rêzefîlma ''Sahsiyet''ê Xelata Emmy ya Navneteweyî wergirt kî ye?', 'Lîstikvanê hosta yê ku di fîlmê "Kis Uykusu" de rola Aydin lîst û bi rêzefîlma "Sahsiyet"ê Xelata Emmy ya Navneteweyî wergirt kî ye?'),
  ('r14_sinema_250', '8292055a-ae26-525d-ba56-69d88ce2c88f'::uuid, 'prompt', 'Fîlmê navdar ê Hayao Miyazaki ''Howl''s Moving Castle'' (Kela Gerok a Howl, 2004) ji romana fantastîk a bi heman navî ya kîjan nivîskara brîtanî hatiye guncandin?', 'Fîlmê navdar ê Hayao Miyazaki "Howl''s Moving Castle" (Kela Gerok a Howl, 2004) ji romana fantastîk a bi heman navî ya kîjan nivîskara brîtanî hatiye guncandin?'),
  ('r14_sinema_248', 'ea81278d-3d88-579e-9f0c-1cc2170a599a'::uuid, 'prompt', 'Muzîkên efsûnî yên hema bêje hemû fîlmên Hayao Miyazaki yên wekî "Spirited Away", "Princess Mononoke" û ''Howl''s Moving Castle'' ji aliyê kîjan bestekarî ve hatine çêkirin?', 'Muzîkên efsûnî yên hema bêje hemû fîlmên Hayao Miyazaki yên wekî "Spirited Away", "Princess Mononoke" û "Howl''s Moving Castle" ji aliyê kîjan bestekarî ve hatine çêkirin?'),
  ('r14_siyaset_151', '315402a9-9f76-5107-b790-046eb162a55b'::uuid, 'prompt', 'Rêbaza matematîkî ya parvekirina kursiyên parlamentoyê ya bi navê ''D''Hondt'' navê xwe ji hiqûqnasê kîjan welatî girtiye?', 'Rêbaza matematîkî ya parvekirina kursiyên parlamentoyê ya bi navê "D''Hondt" navê xwe ji hiqûqnasê kîjan welatî girtiye?'),
  ('r14_siyaset_064', '1bd1a720-3450-5972-911f-e56060353f54'::uuid, 'prompt', 'Celadet Elî Bedirxan kovara ''Hawar''ê ya ku alfabeya kurdî ya latînî tê de da nasîn, di sala 1932an de li kîjan bajarî derxist?', 'Celadet Elî Bedirxan kovara "Hawar"ê ya ku alfabeya kurdî ya latînî tê de da nasîn, di sala 1932an de li kîjan bajarî derxist?'),
  ('r14_siyaset_256', 'fe71ea28-c18a-543b-9e43-a270294fd2b1'::uuid, 'explanation_tr', 'Machiavelli, ''Titus Livius''un İlk On Kitabı Üzerine Söylevler'' adlı eserinde sivil özgürlüğü, halk katılımını ve cumhuriyetçi yönetimi en kalıcı rejim biçimi olarak değerlendirir.', 'Machiavelli, "Titus Livius''un İlk On Kitabı Üzerine Söylevler" adlı eserinde sivil özgürlüğü, halk katılımını ve cumhuriyetçi yönetimi en kalıcı rejim biçimi olarak değerlendirir.'),
  ('r14_siyaset_239', '519efd01-6b04-5b73-9eab-653552363f08'::uuid, 'explanation_tr', '''Das Kapital''in birinci cildi Marx hayattayken 1867 yılında yayımlanmış; ikinci ve üçüncü ciltler ise ölümünden sonra Friedrich Engels tarafından yayına hazırlanmıştır.', '"Das Kapital"in birinci cildi Marx hayattayken 1867 yılında yayımlanmış; ikinci ve üçüncü ciltler ise ölümünden sonra Friedrich Engels tarafından yayına hazırlanmıştır.'),
  ('r14_siyaset_071', '610b5d14-7130-5f0a-a15a-f5f83a985360'::uuid, 'prompt', 'Serokê yekem ê rêxistina nihênî ya ''Azadî''yê (Komîteya Îstîqlala Kurdistanê) ya ku beriya serhildana 1925an li Erziromê hatibû avakirin kî bû?', 'Serokê yekem ê rêxistina nihênî ya "Azadî"yê (Komîteya Îstîqlala Kurdistanê) ya ku beriya serhildana 1925an li Erziromê hatibû avakirin kî bû?'),
  ('r14_muzik_116', '68214e69-16eb-57f4-b92e-2179cdb318f4'::uuid, 'explanation_ku', 'Reggae pêşî ji muzîka bilez a ''Ska''yê û piştre ji ''Rocksteady''yê ber bi rîtmeke girantir ve veguherî.', 'Reggae pêşî ji muzîka bilez a "Ska"yê û piştre ji "Rocksteady"yê ber bi rîtmeke girantir ve veguherî.'),
  ('r14_muzik_116', '68214e69-16eb-57f4-b92e-2179cdb318f4'::uuid, 'explanation', 'Reggae pêşî ji muzîka bilez a ''Ska''yê û piştre ji ''Rocksteady''yê ber bi rîtmeke girantir ve veguherî.', 'Reggae pêşî ji muzîka bilez a "Ska"yê û piştre ji "Rocksteady"yê ber bi rîtmeke girantir ve veguherî.'),
  ('r14_muzik_099', '13e9bf5c-d895-55c9-b91f-25153cbbba01'::uuid, 'prompt', 'Muzîkjenê ku bi strana "Johnny B. Goode" (1958) û teknîka xwe ya gîtarê wek yek ji pêşengên muzîka ''Rock and Roll''ê tê naskirin kî ye?', 'Muzîkjenê ku bi strana "Johnny B. Goode" (1958) û teknîka xwe ya gîtarê wek yek ji pêşengên muzîka "Rock and Roll"ê tê naskirin kî ye?'),
  ('r14_muzik_143', '0001b2f5-b27e-57fc-b32c-45b0f85acd2d'::uuid, 'explanation_tr', 'Syd Barrett, Pink Floyd''a adını vermiş ve ilk albüm ''The Piper at the Gates of Dawn''a liderlik etmiş, ancak ruh sağlığı sorunları nedeniyle 1968''de gruptan ayrılmıştır.', 'Syd Barrett, Pink Floyd''a adını vermiş ve ilk albüm "The Piper at the Gates of Dawn"a liderlik etmiş, ancak ruh sağlığı sorunları nedeniyle 1968''de gruptan ayrılmıştır.'),
  ('r14_muzik_105', '70ed3c72-5e45-545e-a398-1ca73d83786a'::uuid, 'prompt', 'Albûma "The Dark Side of the Moon" (1973) ku wek şahesera ''progressive rock''ê tê dîtin, berhema kîjan komê ye?', 'Albûma "The Dark Side of the Moon" (1973) ku wek şahesera "progressive rock"ê tê dîtin, berhema kîjan komê ye?'),
  ('r14_muzik_096', '5b59acbc-6e16-5cdf-b197-5b891624b5c0'::uuid, 'prompt', 'Hunermendê navdar ê ku muzîka reggae li seranserê cîhanê da naskirin û wek ''qralê reggae''yê tê naskirin kî ye?', 'Hunermendê navdar ê ku muzîka reggae li seranserê cîhanê da naskirin û wek "qralê reggae"yê tê naskirin kî ye?'),
  ('r14_muzik_101', '13093346-5344-5562-b2a8-16093a6334af'::uuid, 'explanation_ku', 'Strana ''Rapper''s Delight'' a koma The Sugarhill Gang hip-hop ji kolanan gihand raya giştî ya cîhanê.', 'Strana "Rapper''s Delight" a koma The Sugarhill Gang hip-hop ji kolanan gihand raya giştî ya cîhanê.'),
  ('r14_muzik_101', '13093346-5344-5562-b2a8-16093a6334af'::uuid, 'explanation', 'Strana ''Rapper''s Delight'' a koma The Sugarhill Gang hip-hop ji kolanan gihand raya giştî ya cîhanê.', 'Strana "Rapper''s Delight" a koma The Sugarhill Gang hip-hop ji kolanan gihand raya giştî ya cîhanê.'),
  ('r14_muzik_101', '13093346-5344-5562-b2a8-16093a6334af'::uuid, 'explanation_tr', 'The Sugarhill Gang''in ''Rapper''s Delight'' şarkısı, hip-hop kültürünü geniş kitlelere ulaştıran ilk büyük hit olmuştur.', 'The Sugarhill Gang''in "Rapper''s Delight" şarkısı, hip-hop kültürünü geniş kitlelere ulaştıran ilk büyük hit olmuştur.'),
  ('r14_muzik_091', '980376f9-ab50-54bb-93c3-6198ffc0076e'::uuid, 'prompt', 'Stranbêj û gîtarîstê navdar ê ''Delta Blues''ê ku bi strana "Cross Road Blues" tê naskirin kî ye?', 'Stranbêj û gîtarîstê navdar ê "Delta Blues"ê ku bi strana "Cross Road Blues" tê naskirin kî ye?'),
  ('r14_muzik_145', 'd5c312d0-4216-5196-b232-2f2577b6953b'::uuid, 'explanation_ku', 'Nile Rodgers wekî hilberînerê albuma "Like a Virgin" a Madonna û ''Let''s Dance'' a David Bowie di muzîka popê ya salên 1980yî de roleke sereke lîst.', 'Nile Rodgers wekî hilberînerê albuma "Like a Virgin" a Madonna û "Let''s Dance" a David Bowie di muzîka popê ya salên 1980yî de roleke sereke lîst.'),
  ('r14_muzik_145', 'd5c312d0-4216-5196-b232-2f2577b6953b'::uuid, 'explanation', 'Nile Rodgers wekî hilberînerê albuma "Like a Virgin" a Madonna û ''Let''s Dance'' a David Bowie di muzîka popê ya salên 1980yî de roleke sereke lîst.', 'Nile Rodgers wekî hilberînerê albuma "Like a Virgin" a Madonna û "Let''s Dance" a David Bowie di muzîka popê ya salên 1980yî de roleke sereke lîst.'),
  ('r14_muzik_145', 'd5c312d0-4216-5196-b232-2f2577b6953b'::uuid, 'explanation_tr', 'Nile Rodgers, Madonna''nın "Like a Virgin" ve David Bowie''nin ''Let''s Dance'' albümlerinin yapımcısı olarak 1980''ler pop müziğinde kilit bir rol oynamıştır.', 'Nile Rodgers, Madonna''nın "Like a Virgin" ve David Bowie''nin "Let''s Dance" albümlerinin yapımcısı olarak 1980''ler pop müziğinde kilit bir rol oynamıştır.'),
  ('r14_edebiyat_025', '8ede67a1-5ba6-5164-9b91-8ef75027a690'::uuid, 'prompt', 'Yekem şanoya nûjen a çapkirî ya kurdî ku di sala 1919an de ji aliyê Evdirehîm Rehmî Hekarî ve di kovara ''Jîn''ê de hatiye weşandin kîjan e?', 'Yekem şanoya nûjen a çapkirî ya kurdî ku di sala 1919an de ji aliyê Evdirehîm Rehmî Hekarî ve di kovara "Jîn"ê de hatiye weşandin kîjan e?'),
  ('r14_edebiyat_003', 'fae8cbf9-3de9-5849-84a3-6a65a5e385d3'::uuid, 'prompt', 'Hejmara yekem a kovara ''Hawar''ê di kîjan dîrokê de derketiye ku îro wekî Cejna Zimanê Kurdî tê pîrozkirin?', 'Hejmara yekem a kovara "Hawar"ê di kîjan dîrokê de derketiye ku îro wekî Cejna Zimanê Kurdî tê pîrozkirin?');

do $$
declare
  r record;
  n int;
  v_uygulanan int := 0;
  v_zaten int := 0;
  v_uyusmayan int := 0;
  v_yok int := 0;
  v_simdiki text;
begin
  for r in select * from _tirnak loop
    execute format('select %I from questions where id = $1', r.col)
      into v_simdiki using r.id;
    get diagnostics n = row_count;
    if n = 0 then
      v_yok := v_yok + 1;
    elsif v_simdiki is not distinct from r.yeni then
      v_zaten := v_zaten + 1;
    elsif v_simdiki is not distinct from r.eski then
      execute format('update questions set %I = $1 where id = $2 and %I = $3', r.col, r.col)
        using r.yeni, r.id, r.eski;
      v_uygulanan := v_uygulanan + 1;
    else
      v_uyusmayan := v_uyusmayan + 1;
      raise notice 'uyusmayan, dokunulmadi: % %', r.local_id, r.col;
    end if;
  end loop;
  raise notice 'tirnak gocu: uygulanan=% zaten=% uyusmayan=% bulunamayan=% (toplam %)',
    v_uygulanan, v_zaten, v_uyusmayan, v_yok, (select count(*) from _tirnak);
end $$;

commit;
