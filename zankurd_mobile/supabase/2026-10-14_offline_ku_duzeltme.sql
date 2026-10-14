-- 2026-10-14: offline_questions Kurmancî düzeltmelerinin canlı kopyası.
--
-- NİÇİN: offline bankasının ilk 400 sorusu çok modelli denetimden geçti
-- (Gemini 3.8 Flash önerdi, Grok 4.7 oyladı, ana ajan bağlam ve tutarlılık
-- vetosu uyguladı). Yerelde düzelen 25 soru 2026-10-01 parity göçüyle
-- sunucuya da eklenmişti; oda ve düello sorularını sunucudan çektiği için
-- canlı kopya eski yazımda kalıyordu. Örnekler: "têgiha"→"têgeha",
-- "Kamûran"→"Kamiran", "hukim"→"hikim", "distirên"→"distirin",
-- "Dengbêjler"→"Dengbêjan".
--
-- Satırlar parity ekleme satırındaki şık sırasıyla üretildi; eski metnin
-- sunucu satırıyla birebir eşleştiği doğrulandı, doğru cevap harfi değişmez.
-- Yalnız prompt ve şık sütunları güncellenir; tekrar çalıştırılabilir.
-- Uygulama: supabase db query --linked -f supabase/2026-10-14_offline_ku_duzeltme.sql

begin;

-- offline_2119
update questions set
  prompt = 'Kovara "Hawar"ê kê derxist?',
  option_a = 'Kamiran Alî Bedirxan', option_b = 'Celadet Alî Bedirxan', option_c = 'Mela Ehmedê Xasî', option_d = 'Osman Sebrî'
where id = '8b21a6ab-bae2-5681-bb3d-8841c21e35e9';
-- offline_2122
update questions set
  prompt = 'Alfabeya Kurmancî ya Latînî kê amade kir?',
  option_a = 'Kamiran Alî Bedirxan', option_b = 'Celadet Alî Bedirxan', option_c = 'Mela Ehmedê Xasî', option_d = 'Qedrîcan'
where id = 'a2abe123-b771-5b5e-bd5f-0140185b0175';
-- offline_2227
update questions set
  prompt = 'Di vegotina Newrozê de sembola berxwedana li dijî zalimî kî ye?',
  option_a = 'Kawayê Hesinkar', option_b = 'Şerefxanê Bidlîsî', option_c = 'Serokkomarê Iraqê', option_d = 'Mîrtî'
where id = '544927f6-f987-589c-a5bd-66bb385ce2ef';
-- offline_2241
update questions set
  prompt = 'Di xebatên naskirina axaftina kurdî de projeya Jira di kîjan qadê de wek mînak tê nîşandan?',
  option_a = 'Korpusa dengî û pergala tîpguhêziyê ya Kurmancî', option_b = 'Korpusa dengî û pergala naskirinê ya Kurdiya Navîn', option_c = 'Korpusa nivîskî û pergala wergerê ya Zazakî', option_d = 'Korpusa dengî û pergala sentezê ya Hewramî'
where id = 'f24a54ca-36fd-5d91-8eec-bdbf9dd44950';
-- offline_2271
update questions set
  prompt = 'Vexwarina ji cureyê Dew/doogh bi kîjan madeya sereke re têkildar e?',
  option_a = 'lîkora qehweyê', option_b = 'tenê qalikê lîmonê', option_c = 'mast/dew', option_d = 'arê garisî'
where id = 'fcb965f9-eb86-5f64-b593-f492adf19ffe';
-- offline_2307
update questions set
  prompt = 'Di civaka kurdî de avahiyên eşîrî di dîrokê de xwedî kîjan fonksiyonê bûne?',
  option_a = 'tora rêxistinbûna civakî, ewlehî, hilberîn û têkiliya siyasî', option_b = 'xwarina kevneşopî ya ku bi mirîşk û birincê tê çêkirin', option_c = 'ziman, çand, weşangerî, hevgirtin û veguhastina nasnameyê', option_d = 'xwarina sebzeyan an pelan a ku bi dagirtinê tê tijîkirin'
where id = 'e99a7e8a-0beb-5ee5-9706-b2800af5d083';
-- offline_2452
update questions set
  prompt = 'Di çanda herêmê de heyîna efsaneyî ya bi motîfa mar a berbelav kîjan e?',
  option_a = 'efsaneya hespê bibask', option_b = 'Şahmaran', option_c = 'efsaneya keça deryayê', option_d = 'efsaneya teyrê dêw'
where id = 'd7d3e1f4-562b-5e0a-a1b2-5b9ebda8ec4c';
-- offline_2459
update questions set
  prompt = '"Şerefname" çi ye?',
  option_a = 'têkoşîna li dijî seferên xaçparêzan', option_b = 'Împeratoriya Medan (berî Farisan)', option_c = 'yekîneyên siwar ên ku ji eşîretan hatibûn pêkanîn', option_d = 'dîroka xanedan û mîrektiyên kurdan'
where id = '17c96fd1-0fcf-5cf9-ad0b-71ce9ea801fa';
-- offline_2599
update questions set
  prompt = 'Di Kurmancî de peyva "mast" kîjan xwarinê nîşan dide?',
  option_a = 'Madeya şîrîn a ku mêşhingiv çêdikin', option_b = 'Xwarina hişk a ku ji şîr tê çêkirin', option_c = 'Rûnê ku ji şîr tê derxistin', option_d = 'Xwarina şîrî ya bi tirşandinê tê çêkirin'
where id = 'c19c0e55-1ef6-50da-b2fc-08a07ad0c0f4';
-- offline_2638
update questions set
  prompt = 'Xanedana kurdî ya Hesenweyhî li kîjan herêmê hikim kiriye?',
  option_a = 'Qefqasya (derdora Gence-Aniyê)', option_b = 'Şerefxan (mîrê Bidlîsê)', option_c = 'tevgera neteweyî ya kurdên Iraqê', option_d = 'rojavayê Îranê / derdora Zagrosê'
where id = 'b838b9c3-9ee2-5011-bc1e-ca3007a78b74';
-- offline_2682
update questions set
  prompt = '"Civaka Ekolojîk" ji civaka pîşesaziyê bi kîjan aliyî ve cuda dibe?',
  option_a = 'Ji ber ku xwezayê tenê wek tiştekî mêtinkirinê nabîne', option_b = 'Geşkirina hişmendiya civakî û ramana azad', option_c = 'Li seranserê cîhanê bûye sembola azadiya jinê', option_d = 'Mafê civakê yê xweparastin û xwerêxistinê'
where id = 'd98d7c23-daca-5618-a097-8b06bbf11463';
-- offline_2705
update questions set
  prompt = '"Çiyayê Sîpanê" nêzîkî kîjan golê ye?',
  option_a = 'Gola Wanê', option_b = 'Gola Egîrdîrê', option_c = 'Gola Xwê', option_d = 'Gola Beyşehîrê'
where id = 'dbe62c63-14c1-584f-a2be-e1bfd3472fc9';
-- offline_2782
update questions set
  prompt = 'Di Êzidîtiyê de kevneşopiya duakirinê ya ber bi rojê ve çi nîşan dide?',
  option_a = 'pîroziya ku ji ronahiyê/rojê re tê dayîn', option_b = 'Melek Tawis û motîfa ronahiyê/rojê', option_c = 'bi çanda rojane re girêdayî ye', option_d = 'xurtkirina girêdanên civakî'
where id = '871f9df8-c339-5057-b456-f239051b6cb1';
-- offline_2787
update questions set
  prompt = 'Wêjeya devkî ya kurdî ji nifşekî bo nifşekî din kê veguhastiye?',
  option_a = 'Askerler', option_b = 'Denizciler', option_c = 'Dengbêjan', option_d = 'Ehmedê Xanî'
where id = 'be738fd5-2c16-5ced-815d-9c1418bdb063';
-- offline_2811
update questions set
  prompt = 'Di dîroka kurdî de piştî "serdema mîrektiyan" kîjan pêvajo derketiye holê?',
  option_a = 'dewleta mezin a ku Selahedînê Eyûbî damezrand', option_b = 'mîrektiya kurd a bihêz a bi navenda Silêmaniyê', option_c = 'mîrektiya kurd a girîng a bi navenda Cizîrê', option_d = 'navendîbûn û rêveberiya rasterast'
where id = 'c7684a0d-e15b-5bf1-b8cd-560d4dcfbc76';
-- offline_2826
update questions set
  prompt = '"Şerefname" ji aliyê kê ve hatiye nivîsandin?',
  option_a = 'serokê Komara Mehabadê', option_b = 'Mesûd Barzanî', option_c = 'YNK (Yekîtiya Nîştimanî ya Kurdistanê)', option_d = 'Şerefxan (mîrê Bedlîsê)'
where id = '3cb2d81a-4ee7-5d81-8c5b-c7e2d434f547';
-- offline_5188
update questions set
  prompt = 'Wateya peyva "kaxez" bi tirkî çi ye?',
  option_a = 'kağıt', option_b = 'here!', option_c = 'doğru', option_d = 'yazmak'
where id = 'e7b43ce4-77a0-5298-bac1-19a00d158652';
-- offline_5270
update questions set
  prompt = '"sevmek" bi Kurmancî çi ye?',
  option_a = 'xwarin', option_b = 'bihîstin', option_c = 'rêvebirin', option_d = 'hezkirin'
where id = '70e8412a-6f18-566a-8f75-1f5b7e29877a';
-- offline_6093
update questions set
  prompt = '"tûrik" çi ye?',
  option_a = 'şivantiya kevneşopî û zanîna xwezayê', option_b = 'cejna berdana beran û ajaldariyê', option_c = 'çîrok û kilam/stran', option_d = 'tûrê hûnandî yê ku xwarin tê de tê hilgirtin'
where id = 'b0a0fca8-aa88-5f74-a85a-16119b8655eb';
-- offline_6538
update questions set
  prompt = '"şevbêrk" çi ye?',
  option_a = 'bi jiyana di erdnîgariya çiyayî de di dirêjahiya dîrokê de', option_b = 'kincên rengîn, gelek-tebeqe û dirêj (kiras)', option_c = 'lîstik an reqsên kevneşopî yên jinan', option_d = 'civînên axaftinê yên şevên zivistanê'
where id = 'c1900627-a209-52f4-a198-d4b85eb58581';
-- offline_6730
update questions set
  prompt = '"serpêhatî" çi ye?',
  option_a = 'zêrên ku di dawetan de li bûkê tên kirin', option_b = 'cejna kevneşopî ya rakirin û bereketê', option_c = 'vegotina bûyerên balkêş ên rastî', option_d = 'rolên kevneşopî yên civakî-olî'
where id = '6e9f8007-63ad-5c56-b456-42cb3b7a3d93';
-- offline_8149
update questions set
  prompt = '"Geliyê Munzurê" çi ye?',
  option_a = 'deşta keviran a ku ji lavên Karacadaxê pêk hatiye', option_b = 'geliyê bi statûya parka neteweyî ya li Dêrsimê', option_c = 'deşta çandiniyê ya mezin a ku bi çemikên Firatê tê avdan', option_d = 'çiyayê ku gola kraterê ya duyemîn a herî mezin a cîhanê lê ye'
where id = 'c86835eb-006b-553e-92b5-33c55cc68d16';
-- offline_8479
update questions set
  prompt = '"Gever (Yüksekova)" çi ye?',
  option_a = 'geliyê bi statuya parka neteweyî ya li Dêrsimê', option_b = 'deşta bi bereket a ku deştên Cizîr û Silopiyê digire', option_c = 'çemê girîng ê ku ji Êlihê derbas dibe û dirije Dîcleyê', option_d = 'deşta tektonîk a bilind a li Colemêrgê'
where id = '585d04d5-4fd7-51f0-a83d-1f1d057f3904';
-- offline_9215
update questions set
  prompt = 'Kîjan cureyê vegotinê bi gelemperî kurt e û li ser bûyerekê an çend bûyeran e?',
  option_a = 'Çîrok', option_b = 'Helbest', option_c = 'Destan', option_d = 'Şano'
where id = '9230f7f0-1707-50d5-a194-242c170d559b';
-- offline_9459
update questions set
  prompt = 'Têgeha "vebêj" çi pêk tîne?',
  option_a = 'kesayeta sereke ya çîrokê', option_b = 'cihê ku bûyer tê de diqewime', option_c = 'ramana sereke ya berhemê', option_d = 'dengê ku çîrokê vedibêje'
where id = '593fbd25-9e49-5731-a04e-0358f7087ddf';

do $$
declare v_count integer;
begin
  select count(*) into v_count from questions where id in ('8b21a6ab-bae2-5681-bb3d-8841c21e35e9', 'a2abe123-b771-5b5e-bd5f-0140185b0175', '544927f6-f987-589c-a5bd-66bb385ce2ef', 'f24a54ca-36fd-5d91-8eec-bdbf9dd44950', 'fcb965f9-eb86-5f64-b593-f492adf19ffe', 'e99a7e8a-0beb-5ee5-9706-b2800af5d083', 'd7d3e1f4-562b-5e0a-a1b2-5b9ebda8ec4c', '17c96fd1-0fcf-5cf9-ad0b-71ce9ea801fa', 'c19c0e55-1ef6-50da-b2fc-08a07ad0c0f4', 'b838b9c3-9ee2-5011-bc1e-ca3007a78b74', 'd98d7c23-daca-5618-a097-8b06bbf11463', 'dbe62c63-14c1-584f-a2be-e1bfd3472fc9', '871f9df8-c339-5057-b456-f239051b6cb1', 'be738fd5-2c16-5ced-815d-9c1418bdb063', 'c7684a0d-e15b-5bf1-b8cd-560d4dcfbc76', '3cb2d81a-4ee7-5d81-8c5b-c7e2d434f547', 'e7b43ce4-77a0-5298-bac1-19a00d158652', '70e8412a-6f18-566a-8f75-1f5b7e29877a', 'b0a0fca8-aa88-5f74-a85a-16119b8655eb', 'c1900627-a209-52f4-a198-d4b85eb58581', '6e9f8007-63ad-5c56-b456-42cb3b7a3d93', 'c86835eb-006b-553e-92b5-33c55cc68d16', '585d04d5-4fd7-51f0-a83d-1f1d057f3904', '9230f7f0-1707-50d5-a194-242c170d559b', '593fbd25-9e49-5731-a04e-0358f7087ddf');
  if v_count <> 25 then
    raise exception 'beklenen 25 soru, bulunan %', v_count;
  end if;
end
$$;

commit;
