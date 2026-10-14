-- 2026-10-14: offline_questions Kurmancî düzeltmelerinin canlı kopyası.
--
-- NİÇİN: offline bankasının 1130 sorusunun tamamı çok modelli denetimden geçti
-- (Gemini 3.8 Flash önerdi, Grok 4.7 oyladı, ana ajan bağlam ve tutarlılık
-- vetosu uyguladı). Yerelde düzelen 51 soru 2026-10-01 parity göçüyle
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
-- offline_10314
update questions set
  prompt = '"awazên Serhedê" çi ne?',
  option_a = 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê', option_b = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_c = 'dengbêjê bi eslê xwe ermenî yê ku muzîka devkî ya kurdî berhev kir', option_d = 'hunermendê rîtmê yê ku erbane an defê bi hostatî lê dide'
where id = 'b6180e9e-1460-56fd-b07f-409fcd93dc3c';
-- offline_10423
update questions set
  prompt = '"tembûr" çi ye?',
  option_a = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_b = 'sazê têlî yê ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin', option_c = 'amûra pifê ya bi dengê bilind a ku li derve tê lêxistin', option_d = 'hunermendê rîtmê yê ku erbane an defê bi hostatî lê dide'
where id = 'e7333f15-0ae5-594e-b3be-366230238b4b';
-- offline_10813
update questions set
  prompt = '"kevneşopiya şabaşê" çi ye?',
  option_a = 'edeta ku ji muzîkjenan re pere tên avêtin', option_b = 'veguhastina muzîkal a bi têkiliya hoste-şagirt', option_c = 'dengê bihêz ê ku kurd jê re dibêjin "şahê dengbêjan"', option_d = 'kilama kevneşopî ya navdar a ku efsaneyekê vedibêje'
where id = '1d460377-37ec-5152-baa9-9436757d7e35';
-- offline_10878
update questions set
  prompt = '"Kardeş Türküler" çi ye?',
  option_a = 'muzîka devkî ya ku di şevbihêrkên zivistanê de tê gotin', option_b = 'koma ku muzîka kurdî di hawîrdoreke pirçandî de pêşkêş dike', option_c = 'stranbêjî an lêxistina bi tenê ya hunermendekî', option_d = 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê'
where id = '050cca2a-e567-568d-8846-d8f01ad565d4';
-- offline_10926
update questions set
  prompt = '"Mihemed Şêxo" kî bû?',
  option_a = 'dengbêjê ku tomarên destpêkê yên muzîka kurdî kirin', option_b = 'koma ku muzîka kurdî di hawîrdoreke pirçandî de pêşkêş dike', option_c = 'dengbêjê ku hestên neteweyî yên gelê kurd dianî ziman', option_d = 'amûra pifê ya bi dengê bilind a ku li derve tê lêxistin'
where id = '59bfeddd-0c33-5014-9534-3dfbbe134c72';
-- offline_11180
update questions set
  prompt = 'Têgeha "meqamê dengbêjan" tê çi wateyê?',
  option_a = 'şêwaza dengî ya bi rîtma azad a ku kilam pê tên gotin', option_b = 'muzîkjenê şoreşger ê hezkirî yê herêma Behdînan', option_c = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_d = 'stranbêjî an lêxistina bi tenê ya hunermendekî'
where id = '83665086-049e-51aa-ae63-163adde0d5bb';
-- offline_11597
update questions set
  prompt = 'Bi "rexneya patriyarkayê" çi tê xwestin?',
  option_a = 'federasyoneke ne-dewletgir a li ser bingeha binî', option_b = 'rolên çêkirî yên ku civakê ji jin û mêr re diyar kirine', option_c = 'eşkerekirina avahiya pergala serdestiya zilaman', option_d = 'yek pirrengî-dilxwazî ye, ya din yekreng-mecbûrî ye'
where id = '7b26ded7-27b6-5ce7-817d-e027b96677b5';
-- offline_11957
update questions set
  prompt = 'Dema "zayenda civakî" tê gotin, çi tê xwestin?',
  option_a = 'krîza navendîbûna aborî û siyasî ya destekî yekane', option_b = 'sîstema jiyanê ya alternatîf a modernîteya kapîtalîst', option_c = 'rolên çêkirî yên ku civakê ji jin û mêr re diyar kirine', option_d = 'pergaleke civakî ku zilamî serdest dike û jinê tepeser dike'
where id = 'd7d0cb69-399a-55ac-b1f1-316565247d35';
-- offline_12122
update questions set
  prompt = 'Derbarê "patriyarka" de vebijêrka rast kîjan e?',
  option_a = 'pergaleke civakî ku zilamî serdest dike û jinê tepeser dike', option_b = 'nîzameke wekhev a bêyî serdestî û mêtinkirinê', option_c = 'li seranserê cîhanê bûye sembola azadiya jinê', option_d = 'prensîbeke wekhevîxwaz a li dijî tepeserî û cudakariya zayendî'
where id = '070752cc-ae4d-565c-a6b2-af697ee89cad';
-- offline_12882
update questions set
  prompt = 'Derbarê "pêvajoya aştiyê" de vebijêrka rast kîjan e?',
  option_a = 'qonaxa bidawîkirina rewşa pevçûnê bi diyalogê', option_b = 'mafê parastinê li dadgehên serbixwe û bêalî', option_c = 'hêzê ji navendekê bo yekîneyên herêmî belavkirin', option_d = 'pergaleke ku jin di partiyan de wekhev xwedî deng in'
where id = '8f1c2fe4-68b1-5aae-b8fd-0ef7a54c20ea';
-- offline_13040
update questions set
  prompt = 'Ji bo "mafên hindikahiyan" ravekirina herî dirust kîjan e?',
  option_a = 'parastina komên ku ji piraniyê cuda ne', option_b = 'platforma hevbeş a aştiyê ya komên muxalif ên cuda', option_c = 'îradeya çareserkirina pevçûnan bi diyalogê li şûna çekan', option_d = 'hêzê ji navendekê bo yekîneyên herêmî belavkirin'
where id = 'e953efd8-6f54-5ea2-a72d-d61c0ece7c4a';
-- offline_13390
update questions set
  prompt = 'Derbarê "meşrûiyet" de ya rast a zanîn çi ye?',
  option_a = 'guncaniya rêveberiyê bi razîbûna gel û hiqûqê re', option_b = 'banga danîna çekan û hilweşandina avahiya rêxistinî', option_c = 'prensîba parvekirina wekhev a çavkanî û mafan', option_d = 'parastina komên ku ji piraniyê cuda ne'
where id = 'f521a0f8-18f7-56dc-9575-05b08d2fa9e5';
-- offline_curated_20375
update questions set
  prompt = 'Cegerxwîn di helbesta kurdî de bi çi tê naskirin?',
  option_a = 'helbestvanê ku Mewlûda Kurdî ya yekem bi zaravayê kurmancî nivîsiye', option_b = 'rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dibe', option_c = 'helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin', option_d = 'helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû'
where id = '86d45d6f-a690-58df-93ed-b0557ab297a5';
-- offline_curated_20504
update questions set
  prompt = '"Împaratoriya Medî" çi bû?',
  option_a = 'hikûmdariya kurd a ku di serdema Osmanî de xweser mabû', option_b = 'mîrektiya bi navenda Rewandizê ya ku hêza leşkerî berhev kir', option_c = 'mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû', option_d = 'hêza mezin a kevnar a li çiyayên Zagrosê ku kurd xwe wekî neviyên wan dibînin'
where id = 'd236250d-67f0-5452-bb15-7f0f588c96fa';
-- offline_curated_21376
update questions set
  prompt = 'Yek ji stûnên muzîka klasîk ên ku kilamên devera Botanê tomar kirine kî bû?',
  option_a = 'Meryem Xan', option_b = 'Hesen Cizrawî', option_c = 'heyran', option_d = 'lawik'
where id = 'd72e8f29-7c93-5925-81c2-92e35fccad60';
-- offline_curated_21475
update questions set
  prompt = 'Di muzîka kurdî de taybetmendiya kilamên bi navê "heyran" çi ye?',
  option_a = 'amûra têldar a ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin ku bi taybetî di civatên olî de tê lêdan', option_b = 'klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin', option_c = 'stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye', option_d = 'yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botanê tomar kirine'
where id = 'bb4d417e-241e-504f-ab15-882fe1ddb986';
-- offline_tf_0119
update questions set
  prompt = 'Rast e an şaş e: "mêvanperweriya kurdî" şêwaza jiyana kevnar a li ser zozan û germiyanan e ku çanda kurdî pir dewlemend kiriye.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'cfb1ebb6-f214-55c4-9852-6d0bc355e110';
-- offline_tf_siy_0020
update questions set
  prompt = 'Binirxîne: li gorî vê ravekirinê "muxalefeta civakî" ev e — redkirina eşkere û bêşîdet a qanûneke ku neheq tê dîtin. Rast e an şaş e?',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'a2cd1ed2-4317-5286-b841-e38ea4d84488';
-- offline_tf_ede_0024
update questions set
  prompt = 'Rast e an şaş e: "qafiye" lihevhatina dengên dawiya rêzan e ku rîtmê dide helbestê.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'eee41fe4-fbfe-5716-a324-0abbeec7852a';
-- offline_tf_ede_0025
update questions set
  prompt = 'Rast e an şaş e: "qafiye" vegotina dirêj e ku lehengî û bîra komî ya gelekî hildigire.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '18b8c5a7-d76e-5462-890d-a74b4e875f9b';
-- offline_tek_0009
update questions set
  prompt = 'Çima girêdanên bêtêl ji yên bi kablo bêtir hewceyî şîfrekirinê ne?',
  option_a = 'Ji ber ku girêdanên bêtêl her tim hêdîtir dixebitin', option_b = 'Ji ber ku amûrên bêtêl kêmtir enerjiyê xerc dikin', option_c = 'Ji ber ku sînyal li hewayê belav dibe û herkes dikare bigire', option_d = 'Ji ber ku kabloyên wan ji yên din kurttir tên çêkirin'
where id = 'ac709ea0-c523-5a80-a1b4-ccb8d8677363';
-- offline_tek_0028
update questions set
  prompt = 'Wêneyek bi çareseriya bilind her tim kêmtir cih digire.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'e404770e-4a58-54da-942e-56ff4899c418';
-- offline_tek_0041
update questions set
  prompt = 'Di bernamesaziyê de "algorîtma" bi giştî çi ye?',
  option_a = 'Zimanek ji bo nivîsandina bernameyan', option_b = 'Hêmaneke dîtbarî ya li ser ekranê', option_c = 'Rêbazek bi gavên diyarkirî', option_d = 'Pergalek ji bo hilanîna daneyan'
where id = '571f75c7-e506-5d42-b67c-b4a96fa9c111';
-- offline_tek_0085
update questions set
  prompt = 'Dema tu li malperekê digerî, "cookie" çi dike?',
  option_a = 'Girêdana înternetê bileztir û bêtêl dike', option_b = 'Şîfreyên te yên hesaban diguherîne û nû dike', option_c = 'Hemû reklaman ji rûpelên malperan radike û paqij dike', option_d = 'Agahiyên gera te li ser amûrê tomar dike'
where id = '6f287e0b-b1cc-58b7-83cc-be9e25648976';
-- offline_tek_2013
update questions set
  prompt = 'Yekîneya "wat" di jiyana rojane de çi dide zanîn?',
  option_a = 'Hêza ku amûrek xerc dike', option_b = 'Giraniya amûrê li ser mêzînê', option_c = 'Dirêjahiya kabloya amûrê', option_d = 'Dema ku amûr dixebite'
where id = 'a2af74aa-952a-5ec8-b3c9-4ff62edeed39';
-- offline_tek_2014
update questions set
  prompt = 'Amûreke ku vemirandî ye lê kabloya wê hîn jî girêdayî ye bi tu awayî elektrîkê naxwe.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '8e7cda6a-8ec8-561a-b62d-f7b447296032';

do $$
declare v_count integer;
begin
  select count(*) into v_count from questions where id in ('8b21a6ab-bae2-5681-bb3d-8841c21e35e9', 'a2abe123-b771-5b5e-bd5f-0140185b0175', '544927f6-f987-589c-a5bd-66bb385ce2ef', 'f24a54ca-36fd-5d91-8eec-bdbf9dd44950', 'fcb965f9-eb86-5f64-b593-f492adf19ffe', 'e99a7e8a-0beb-5ee5-9706-b2800af5d083', 'd7d3e1f4-562b-5e0a-a1b2-5b9ebda8ec4c', '17c96fd1-0fcf-5cf9-ad0b-71ce9ea801fa', 'c19c0e55-1ef6-50da-b2fc-08a07ad0c0f4', 'b838b9c3-9ee2-5011-bc1e-ca3007a78b74', 'd98d7c23-daca-5618-a097-8b06bbf11463', 'dbe62c63-14c1-584f-a2be-e1bfd3472fc9', '871f9df8-c339-5057-b456-f239051b6cb1', 'be738fd5-2c16-5ced-815d-9c1418bdb063', 'c7684a0d-e15b-5bf1-b8cd-560d4dcfbc76', '3cb2d81a-4ee7-5d81-8c5b-c7e2d434f547', 'e7b43ce4-77a0-5298-bac1-19a00d158652', '70e8412a-6f18-566a-8f75-1f5b7e29877a', 'b0a0fca8-aa88-5f74-a85a-16119b8655eb', 'c1900627-a209-52f4-a198-d4b85eb58581', '6e9f8007-63ad-5c56-b456-42cb3b7a3d93', 'c86835eb-006b-553e-92b5-33c55cc68d16', '585d04d5-4fd7-51f0-a83d-1f1d057f3904', '9230f7f0-1707-50d5-a194-242c170d559b', '593fbd25-9e49-5731-a04e-0358f7087ddf', 'b6180e9e-1460-56fd-b07f-409fcd93dc3c', 'e7333f15-0ae5-594e-b3be-366230238b4b', '1d460377-37ec-5152-baa9-9436757d7e35', '050cca2a-e567-568d-8846-d8f01ad565d4', '59bfeddd-0c33-5014-9534-3dfbbe134c72', '83665086-049e-51aa-ae63-163adde0d5bb', '7b26ded7-27b6-5ce7-817d-e027b96677b5', 'd7d0cb69-399a-55ac-b1f1-316565247d35', '070752cc-ae4d-565c-a6b2-af697ee89cad', '8f1c2fe4-68b1-5aae-b8fd-0ef7a54c20ea', 'e953efd8-6f54-5ea2-a72d-d61c0ece7c4a', 'f521a0f8-18f7-56dc-9575-05b08d2fa9e5', '86d45d6f-a690-58df-93ed-b0557ab297a5', 'd236250d-67f0-5452-bb15-7f0f588c96fa', 'd72e8f29-7c93-5925-81c2-92e35fccad60', 'bb4d417e-241e-504f-ab15-882fe1ddb986', 'cfb1ebb6-f214-55c4-9852-6d0bc355e110', 'a2cd1ed2-4317-5286-b841-e38ea4d84488', 'eee41fe4-fbfe-5716-a324-0abbeec7852a', '18b8c5a7-d76e-5462-890d-a74b4e875f9b', 'ac709ea0-c523-5a80-a1b4-ccb8d8677363', 'e404770e-4a58-54da-942e-56ff4899c418', '571f75c7-e506-5d42-b67c-b4a96fa9c111', '6f287e0b-b1cc-58b7-83cc-be9e25648976', 'a2af74aa-952a-5ec8-b3c9-4ff62edeed39', '8e7cda6a-8ec8-561a-b62d-f7b447296032');
  if v_count <> 51 then
    raise exception 'beklenen 51 soru, bulunan %', v_count;
  end if;
end
$$;

commit;
