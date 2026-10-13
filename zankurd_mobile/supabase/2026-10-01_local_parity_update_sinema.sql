-- 2026-10-01: Sînema kategorisinde sunucudaki 16 bayat satırı yerel denetlenmiş sürüme çek (canlı sunucu).
--
-- NİÇİN: kimliği uuid5('zankurd-local:' + yerel id) olan bu satırlar daha önce
-- yerel bankadan sunucuya eklendi; sonra yerelde metin düzeltildi (Kurmancî
-- yazım/terim düzeltmeleri, bir doğru cevap farkı) ama sunucu eski kopyayla
-- kaldı. Kimlik uuid5 olduğu için eşleşme kesindir. Yalnız soru metni, şık
-- KÜMESİ ya da doğru cevap ayrışanlar alınır; şık SIRASI farkı sayılmadı.
-- Güncellenen: 16; onaysızken yeniden onaylanan: 0.
--
-- Alanlar: prompt, option_a-d, correct_option, explanation(_ku/_tr);
-- is_approved = true, review_status = 'approved', updated_at = now().
--
-- TEKRAR ÇALIŞTIRILABİLİR: aynı değerleri yazar. Doğrulama bloğu 16 satırın
-- yerel metne eşit olduğunu denetler; tutmazsa işlem geri alınır.
--
-- GERİ ALMA: eski metin bu dosyada YOK; gerekirse sunucu dökümünden
-- (`tool/sync_local_parity_to_server.py` çalıştırılırken `.tmp/parity/
-- server_questions.json`) alınır. Yeniden onaylananlar için is_approved = false.
--
-- Üretici: tool/sync_local_parity_to_server.py (YEREL_OYNANABILIR: 2579)
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_local_parity_update_sinema.sql

begin;

-- Önkoşul: kategori sunucuda var (bu göç oluşturmaz).
do $$
begin
  if not exists (select 1 from categories where name = 'Sînema') then
    raise exception 'Eksik kategori: Sînema';
  end if;
end
$$;

create temp table _parity_guncel(
  id uuid primary key, prompt text, option_a text, option_b text,
  option_c text, option_d text, correct_option text,
  explanation text, explanation_ku text, explanation_tr text
) on commit drop;
insert into _parity_guncel values
  ('fadabce3-5283-5a09-abf6-4763b3bdd5ae'::uuid, 'Dîmenek ku bêyî qutkirinê bi kişandineke domdar tê tomarkirin, çawa tê binavkirin?', 'Montaja paralel', 'Plan-sekans', 'Fondu', 'Qutkirina xwêrû', 'B', 'Di plansekansê de kamera bêdawî dixebite û dîmen bi montajê nayê perçekirin; dem wek ku ye ji temaşevan re diherike. Montaja paralel û qutbûna bilez xwe dispêrin qutkirinê, tarîbûn jî efekteke derbasbûnê ye.', 'Di plansekansê de kamera bêdawî dixebite û dîmen bi montajê nayê perçekirin; dem wek ku ye ji temaşevan re diherike. Montaja paralel û qutbûna bilez xwe dispêrin qutkirinê, tarîbûn jî efekteke derbasbûnê ye.', 'Plan sekansta kamera durmadan çalışır ve sahne kurguyla parçalanmaz; zaman izleyiciye olduğu gibi akar. Paralel kurgu ile sıçramalı kesme kesmeye dayanır, kararma ise bir geçiş efektidir.'), -- yerel: cinema_0010
  ('2378a817-95ac-5de6-ae87-50cef3f0a62d'::uuid, 'Fîlmê ku bûyer û mirovên rastîn bêyî senaryoyeke çîrokî tomar dike, di kîjan cureyê de ye?', 'Belgefîlm', 'Zanistî-xeyalî', 'Animasyon', 'Muzîkal', 'A', 'Belgefîlm bûyer û mirovên rastîn tomar dike; berevajî fîlmên çîrokî, lîstikvan rol nagirin û cîhaneke xeyalî nayê avakirin.', 'Belgefîlm bûyer û mirovên rastîn tomar dike; berevajî fîlmên çîrokî, lîstikvan rol nagirin û cîhaneke xeyalî nayê avakirin.', 'Belgesel gerçek olay ve kişileri kaydeder; kurmaca filmlerin tersine oyuncular rol yapmaz ve hayali bir dünya kurulmaz.'), -- yerel: cinema_0013
  ('afccb2d5-dbeb-56a7-b393-360535c9224e'::uuid, 'Fîlmê 2000î "Dema Hesp Serxweş Dibin" ku li Cannesê Caméra d''Or wergirt, yê kîjan derhênerî ye?', 'Hîner Salêm', 'Bahman Ghobadî', 'Cafer Panahî', 'Mohsen Mexmelbaf', 'B', 'Fîlmê pêşîn ê dirêjmetraj ê Ghobadî zarokên gundekî kurdî yê li ser sînorê Îran-Iraqê dişopîne, ên ku bi bazirganiya sînorî hewl didin bijîn. Kamerayê Zêrîn tenê ji fîlmên pêşîn re tê dayîn; sê navên din jî derhênerên navdar in lê ev fîlm ne yê wan e.', 'Fîlmê pêşîn ê dirêjmetraj ê Ghobadî zarokên gundekî kurdî yê li ser sînorê Îran-Iraqê dişopîne, ên ku bi bazirganiya sînorî hewl didin bijîn. Kamerayê Zêrîn tenê ji fîlmên pêşîn re tê dayîn; sê navên din jî derhênerên navdar in lê ev fîlm ne yê wan e.', 'Ghobadi''nin ilk uzun metrajı, İran-Irak sınırındaki bir Kürt köyünde sınır ticaretiyle ayakta kalmaya çalışan çocukları izler. Altın Kamera yalnız ilk filmlere verilir; diğer üç isim de tanınmış yönetmenlerdir ama bu film onların değildir.'), -- yerel: cinema_0018
  ('528d8951-5521-5465-a70d-ff2fda82b76d'::uuid, 'Dengên wek gavan an vekirina derî yên ku piştî kişandinê li stûdyoyê ji nû ve tên çêkirin, çawa tên binavkirin?', 'Muzîka fîlmî', 'Dublaj', 'Dengê rasterast', 'Dengên foley', 'D', 'Dengên foley piştî kişandinê li stûdyoyê ji nû ve tên çêkirin; hunermend bi temaşekirina dîmenê dengên gav û derî bi destan zindî dike.', 'Dengên foley piştî kişandinê li stûdyoyê ji nû ve tên çêkirin; hunermend bi temaşekirina dîmenê dengên gav û derî bi destan zindî dike.', 'Foley sesleri çekimden sonra stüdyoda yeniden üretilir; sanatçı sahneyi izleyerek ayak ve kapı gibi sesleri elle canlandırır.'), -- yerel: cinema_0019
  ('a06d6957-309f-5376-94d1-b7f71ebda8b4'::uuid, 'Dîmenê ku tê de kamera rasterast ji jor ve li cihê bûyerê dinêre, çawa tê binavkirin?', 'Plana ji jêr', 'Plana hemwaz', 'Plana xwar', 'Plana çavê teyr', 'D', 'Ev goşe mekanê wek nexşeyekê vedike û kesan piçûk dike. Goşeya jêrîn berevajî laş mezin dike, asta çavan bêalî dimîne, goşeya xwar jî bi xwarkirina kadrajê aciziyê çêdike.', 'Ev goşe mekanê wek nexşeyekê vedike û kesan piçûk dike. Goşeya jêrîn berevajî laş mezin dike, asta çavan bêalî dimîne, goşeya xwar jî bi xwarkirina kadrajê aciziyê çêdike.', 'Bu açı mekânı harita gibi açar ve kişileri küçültür. Alt açı tersine figürü büyütür, göz hizası nötr durur, eğik açı ise kadrajı yana yatırarak tedirginlik yaratır.'), -- yerel: cinema_0028
  ('204501fa-b94c-533c-b550-10d9a5e86e1a'::uuid, 'Kî budçeya fîlmekî peyda dike û pêvajoya berhemanînê bi rê ve dibe?', 'Derhêner', 'Berhemhêner', 'Senarîst', 'Montajkar', 'B', 'Berhemhêner budçe, bername û tîmê bi hev re digire; biryarên hunerî yên li ser dîmenan li ba derhêner dimînin.', 'Berhemhêner budçe, bername û tîmê bi hev re digire; biryarên hunerî yên li ser dîmenan li ba derhêner dimînin.', 'Yapımcı bütçeyi, takvimi ve ekibi bir arada tutar; görüntülere ilişkin sanatsal kararlar yönetmende kalır.'), -- yerel: cinema_0031
  ('88dda395-f82e-5032-b23a-d1df7a9932d8'::uuid, 'Dîmenê destpêkê yê ku cih û dema sekansekê dide nasîn, çawa tê binavkirin?', 'Plana berevajî', 'Plana detayê', 'Plana danasînê', 'Plana subjektîf', 'C', 'Plana danasînê bi kadrajeke fireh cih û dem dide nasîn; dîmenên nêzîk ên piştre li ser vê nexşeya mekanê rûdinên.', 'Plana danasînê bi kadrajeke fireh cih û dem dide nasîn; dîmenên nêzîk ên piştre li ser vê nexşeya mekanê rûdinên.', 'Tanıtım planı geniş bir kadrajla yeri ve zamanı tanıtır; sonraki yakın çekimler bu mekân haritasına oturur.'), -- yerel: cinema_0034
  ('ff1d5a8e-ee87-5117-bb95-9677df998626'::uuid, 'Di sînemayê de şeklê çarçoveya dîmenê bi kîjan pîvanê tê diyarkirin?', 'Hejmara kadroyên ku di saniyeyekê de tên nîşandan', 'Kûrahiya qadê ya di navbera pêş û paş de', 'Asta bilindbûna dengê tomarkirî', 'Rêjeya firehî û bilindahiyê', 'D', 'Rêjeya firehî-bilindiyê şeklê çarçoveya dîmenê diyar dike; nirxên wek 1.85:1 an 2.39:1 destnîşan dikin ku perde dê çiqas fireh be. Hejmara kareyan bi lezê ve girêdayî ye, kûrahiya qadê jî bi qada tîzbûnê ve girêdayî ye.', 'Rêjeya firehî-bilindiyê şeklê çarçoveya dîmenê diyar dike; nirxên wek 1.85:1 an 2.39:1 destnîşan dikin ku perde dê çiqas fireh be. Hejmara kareyan bi lezê ve girêdayî ye, kûrahiya qadê jî bi qada tîzbûnê ve girêdayî ye.', 'En-boy oranı görüntünün çerçeve biçimini verir; 1.85:1 ya da 2.39:1 gibi değerler perdenin ne kadar geniş olacağını belirler. Kare sayısı hızla, alan derinliği ise netlik alanıyla ilgilidir.'), -- yerel: cinema_0043
  ('65076fbf-bd53-5bd6-8f9b-5d90277b4b96'::uuid, 'Du bûyerên ku di heman demê de li cihên cuda diqewimin bi dorê tên nîşandan; ev şêwaza montajê çi ye?', 'Montaja domdar', 'Montaja paralel', 'Elipsa demî', 'Fondu ya zincîrî', 'B', 'Montaja paralel du bûyerên hevdem bi dorê nîşan dide; ev şêwe aloziyê mezin dike û pir caran di dîmenên şopandinê de tê bikaranîn.', 'Montaja paralel du bûyerên hevdem bi dorê nîşan dide; ev şêwe aloziyê mezin dike û pir caran di dîmenên şopandinê de tê bikaranîn.', 'Paralel kurgu aynı anda olan iki olayı dönüşümlü gösterir; bu yapı gerilimi büyütür ve sıkça takip sahnelerinde kullanılır.'), -- yerel: cinema_0046
  ('49346461-0aa7-5458-82ed-bae80e76623a'::uuid, 'Fîlmê 1999an "Güneşe Yolculuk" yê kîjan derhênerî ye?', 'Zekî Demîrkubuz', 'Handan Îpekçî', 'Yeşîm Ustaoglu', 'Serdar Akar', 'C', 'Fîlm rêwîtiya du xortên ku li Stenbolê nas dibin ber bi rojhilatê welat ve dişopîne û li Berlînê xelat wergirtiye. Demîrkubuz, Îpekçî û Akar jî derhênerên ku di dawiya salên 1990î de derketine pêş in.', 'Fîlm rêwîtiya du xortên ku li Stenbolê nas dibin ber bi rojhilatê welat ve dişopîne û li Berlînê xelat wergirtiye. Demîrkubuz, Îpekçî û Akar jî derhênerên ku di dawiya salên 1990î de derketine pêş in.', 'Film, İstanbul''da tanışan iki genç adamın ülkenin doğusuna uzanan yolculuğunu izler ve Berlin''de ödül almıştır. Demirkubuz, İpekçi ve Akar da 1990''ların sonunda öne çıkan yönetmenlerdir.'), -- yerel: cinema_0055
  ('1c845b5a-f1a2-524f-b3e5-5ba03b96c1b5'::uuid, 'Dema ku rûyê lîstikvan bi tevahî dîmenê dagire, ev kîjan plan e?', 'plana dûr (uzak çekim)', 'plana nêzîk (yakın çekim)', 'plana navîn (orta çekim)', 'plana damezrîner (establishing shot)', 'B', 'Plana nêzîk rûyê lîstikvan an hûrgiliyekê bi awayekî mezin nîşan dide; bi vî awayî hest û reaksiyonên karakterê dibin navenda dîmenê. Plana dûr jî cih û têkiliyên di navbera hêmanan de nîşan dide.', 'Plana nêzîk rûyê lîstikvan an hûrgiliyekê bi awayekî mezin nîşan dide; bi vî awayî hest û reaksiyonên karakterê dibin navenda dîmenê. Plana dûr jî cih û têkiliyên di navbera hêmanan de nîşan dide.', 'Yakın çekim, oyuncunun yüzünü ya da bir ayrıntıyı büyük ölçüde gösterir; böylece karakterin duygu ve tepkileri çerçevenin merkezine gelir. Uzak çekim ise mekânı ve öğeler arasındaki ilişkileri gösterir.'), -- yerel: ds26_cinema_0001
  ('6776da15-b5ed-5a97-84eb-df64318d31cd'::uuid, 'Kîjan plan cih û hawîrdora ku çîrok lê derbas dibe bi tevahî nîşan dide?', 'plana damezrîner (establishing shot)', 'plana nêzîk (yakın çekim)', 'plana serpîrî (baş üstü çekim)', 'çarçoveya cemidî (freeze frame)', 'A', 'Plana damezrîner di destpêka dîmenekî de cihê bûyerê, dem û hawîrdora giştî nîşanî temaşevan dide. Ev plan bi gelemperî ji dûr ve tê kişandin da ku temaşevan berî çîrokê cihê bûyerê nas bike.', 'Plana damezrîner di destpêka dîmenekî de cihê bûyerê, dem û hawîrdora giştî nîşanî temaşevan dide. Ev plan bi gelemperî ji dûr ve tê kişandin da ku temaşevan berî çîrokê cihê bûyerê nas bike.', 'Geniş açılış çekimi (establishing shot), bir sahnenin başında olayın geçtiği yeri, zamanı ve genel çevreyi izleyiciye tanıtır. Bu plan genellikle uzaktan çekilir; izleyici öyküye girmeden önce mekânı kavrar.'), -- yerel: ds26_cinema_0002
  ('7cb87bb6-ee0a-5112-baab-764d28e79923'::uuid, 'Têgiha ku hemû hêmanên dîtbarî yên li ber kamerayê (dekor, ronahî, lîstik) di çarçoveyekê de berhev dike çi ye?', 'sînematografî', 'montaj', 'senaryo', 'mise-en-scène', 'D', 'Mise-en-scène hemû hêmanên dîtbarî yên di çarçoveyê de ye: dekor, cil, ronahî, cihê lîstikvanan û lîstika wan. Sînematografî ji vê cuda ye; ew bi kamerayê û kişandina dîmenê ve mijûl dibe.', 'Mise-en-scène hemû hêmanên dîtbarî yên di çarçoveyê de ye: dekor, cil, ronahî, cihê lîstikvanan û lîstika wan. Sînematografî ji vê cuda ye; ew bi kamerayê û kişandina dîmenê ve mijûl dibe.', 'Mise-en-scène, çerçeve içindeki tüm görsel öğelerdir: dekor, kostüm, ışık, oyuncu konumu ve oyunu. Sinematografi bundan ayrıdır; kamera ve görüntü çekimiyle ilgilenir.'), -- yerel: ds26_cinema_0035
  ('93149054-e690-5287-94d1-4674618d1bb2'::uuid, 'Fîlmê "Klama Dayika Min" xelata fîlmê herî baş li kîjan festîvalê wergirt?', 'Festîvala Fîlman a Cannesê', 'Festîvala Fîlman a Saraybosnayê', 'Festîvala Fîlman a Berlînê', 'Festîvala Fîlman a Venedîkê', 'B', 'Fîlmê Erol Mintaş di sala 2014''an de li wê festîvalê xelata sereke wergirt.', 'Fîlmê Erol Mintaş di sala 2014''an de li wê festîvalê xelata sereke wergirt.', 'Erol Mintaş''ın filmi 2014''te bu festivalde ana ödülü kazandı.'), -- yerel: edit_sinema_0007
  ('17e7cfdf-b172-5249-abec-95ff56b3e787'::uuid, 'Fîlmê "Sürü" (1978) ji hêla kîjan derhêner ve hatiye kişandin?', 'Şerîf Gören', 'Zeki Ökten', 'Atif Yilmaz', 'Ömer Lütfi Akad', 'B', 'Senaryo ya Yilmaz Güney bû; wî di girtîgehê de nivîsî bû û derhêneriya fîlmê jî Zeki Ökten kir.', 'Senaryo ya Yilmaz Güney bû; wî di girtîgehê de nivîsî bû û derhêneriya fîlmê jî Zeki Ökten kir.', 'Senaryo Yılmaz Güney''e aitti; o cezaevinde yazmıştı ve filmin yönetmenliğini de Zeki Ökten yaptı.'), -- yerel: edit_sinema_0025
  ('f838337f-0d9e-57f6-bc0f-987820d506e5'::uuid, 'Kurtefîlmê "Bawke" yê Hisham Zaman, ku li festîvalan zêdetirî 40 xelat wergirtin, sala 2005an xelata Amanda jî wergirt. Amanda xelata neteweyî ya kîjan welatî ye?', 'Swêd', 'Norwêc', 'Danîmarka', 'Fînlanda', 'B', 'Xelata Amanda wek hevtaya Oscarê ya Norwêcê tê zanîn. "Bawke" sala 2005an bi vê xelatê wek kurtefîlmê herî baş hate xelatkirin.', 'Xelata Amanda wek hevtaya Oscarê ya Norwêcê tê zanîn. "Bawke" sala 2005an bi vê xelatê wek kurtefîlmê herî baş hate xelatkirin.', 'Amanda Ödülü, Norveç''in Oscar''ı olarak bilinir. "Bawke" 2005''te bu ödülle en iyi kısa film seçildi.'); -- yerel: ex28_festival_belgefilm_009

do $$
declare
  v_known int;
begin
  select count(*) into v_known
  from questions q join _parity_guncel g on g.id = q.id
  where q.category_id = (select id from categories where name = 'Sînema');
  if v_known <> 16 then
    raise exception 'Sînema: güncellenecek 16 satırdan yalnız % sunucuda', v_known;
  end if;
end
$$;

update questions q
set prompt = g.prompt,
    option_a = g.option_a, option_b = g.option_b,
    option_c = g.option_c, option_d = g.option_d,
    correct_option = g.correct_option,
    explanation = g.explanation,
    explanation_ku = g.explanation_ku,
    explanation_tr = g.explanation_tr,
    is_approved = true,
    review_status = 'approved',
    updated_at = now()
from _parity_guncel g
where g.id = q.id;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from questions q join _parity_guncel g on g.id = q.id
  where q.is_approved = true
    and q.prompt = g.prompt
    and q.correct_option = g.correct_option
    and q.option_a = g.option_a and q.option_b = g.option_b
    and q.option_c = g.option_c and q.option_d = g.option_d;
  if v_count <> 16 then
    raise exception 'Sînema: beklenen 16 güncel onayli satir, bulunan %', v_count;
  end if;
end
$$;

commit;
