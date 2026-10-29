-- Kapışma içerik düzeltmeleri — Kurmancî alanlar (2026-10-29).
--
-- Jüri: Gemini 4 Argon + Gemini 3.8 Flash + GPT-6.1 Terra; (id, alan) bazında ≥2 oy
-- (dağınıkta aday oylaması). Toplu bul-değiştir YOK: her satır tek soru + tek sütun.
-- Ayrıca U8: açıklaması olmayan sorulara TR+KU açıklama (explanation_tr eski NULL ise).
-- Satırlar yerel kimliğin uuid5'iyle eşlenir; her güncelleme ESKİ değerle korumalıdır
-- (idempotent; eşi olmayan ya da elle değişmiş satır 0 satır günceller).
-- correct_option değişmez: şık konumları korunur.
--
-- Çalıştırma (önce kuru): supabase db query --linked -f supabase/2026-10-29_icerik_kapisma_ku.sql

begin;

create temp table _kapisma_ku (id uuid, yerel text, sutun text, eski text, yeni text) on commit drop;

insert into _kapisma_ku (id, yerel, sutun, eski, yeni) values
  ('44ab0464-2fa5-54f4-b77d-436a50983824', 'ds_cografya_0248', 'option_b', 'Hêzar gola cemedî ye, Nemrûd gola kembera karstîk e', 'Hêzar gola setê ya volkanîk e, Nemrûd gola tektonîk a daketî ye'),
  ('44ab0464-2fa5-54f4-b77d-436a50983824', 'ds_cografya_0248', 'option_c', 'Hêzar gola setê ya çem e, Nemrûd gola tektonîk a kûr e', 'Hêzar gola karstîk a helînê ye, Nemrûd gola setê ya volkanîk e'),
  ('44ab0464-2fa5-54f4-b77d-436a50983824', 'ds_cografya_0248', 'option_d', 'Hêzar gola çêkirî ye, Nemrûd gola sirûştî ya aluvyal e', 'Hêzar gola setê ya şemitînê ye, Nemrûd gola kolandina cemedê ye'),
  ('4b0b208e-26f7-5abf-b54a-e948a2166334', 'ds_cografya_0249', 'option_a', 'Rêjeya baranê ji ya hemû herêmên cîran gelekî zêdetir bûye', 'Aluvyonên Çemê Bedlîsê bi demê re derketina golê bi temamî girtiye'),
  ('4b0b208e-26f7-5abf-b54a-e948a2166334', 'ds_cografya_0249', 'option_b', 'Çemê Dîcleyê ava xwe bi temamî rijandiye nav vê newalê', 'Lavên Sîpanê herikîna derve ya hewzeyê birriye û goleke girtî çêkiriye'),
  ('4b0b208e-26f7-5abf-b54a-e948a2166334', 'ds_cografya_0249', 'option_c', 'Tektonîka Zagrosê ava deryayê rasterast kişandiye nav golê', 'Çemê Muradê rêya xwe guhertiye û ava kaniyên sodavî aniye golê'),
  ('72fb90c4-f869-5e7c-86ff-f7680e97fad3', 'ds_cografya_0252', 'option_a', 'Gola Urmiyeyê ya şor', 'Gola Urmiyeyê (hewzeya girtî)'),
  ('72fb90c4-f869-5e7c-86ff-f7680e97fad3', 'ds_cografya_0252', 'option_b', 'Deryaya Navîn (Spî)', 'Gola Aralê (hewzeya girtî)'),
  ('72fb90c4-f869-5e7c-86ff-f7680e97fad3', 'ds_cografya_0252', 'option_c', 'Kendava Farsê ya germ', 'Kendava Farsê (hewzeya deryayî)'),
  ('b270471d-1d13-5347-a1f2-e63d60fb235f', 'ds_cografya_0253', 'option_a', 'Ji ber ku herêma herî nizm a ji bo çandiniya birincê bû', 'Ji bo çandiniya aluvyonî di nîvê deşta lehiyê de cih girtin'),
  ('b270471d-1d13-5347-a1f2-e63d60fb235f', 'ds_cografya_0253', 'option_c', 'Ji bo dûrketina ji hemû rêyên bazirganiyê yên herêmî', 'Sûdwergirtina ji bendereke xwezayî ya fireh û kûr a guncaw bo veguhastina çemî'),
  ('b270471d-1d13-5347-a1f2-e63d60fb235f', 'ds_cografya_0253', 'option_d', 'Ji ber ku li ser xeta herikîna lavên germ ên nû bû', 'Ji bo parastina ji bayên zivistanê li cihê herî nizm ê newalê cih girtin'),
  ('427bf48d-0bd5-5427-bbf0-cae3169704b2', 'ds_cografya_0255', 'option_a', 'Ji bo diyarkirina rêyên balafiran bi şêwaza herî kurt', 'Ji bo nîşandana rêyên pûsûleyê yên deryageran bi xetên rast'),
  ('427bf48d-0bd5-5427-bbf0-cae3169704b2', 'ds_cografya_0255', 'option_c', 'Ji bo mezinkirina welatên Ewropayê li gorî Asyayê', 'Ji bo rakirina bi temamî ya şêwandina şeklê li herêmên cemseran'),
  ('427bf48d-0bd5-5427-bbf0-cae3169704b2', 'ds_cografya_0255', 'option_d', 'Ji bo hêsankirina sefera deryageran li okyanûsan', 'Ji bo nîşandana rêyên balafiran ên çembera mezin bi xetên rast'),
  ('0a3cc564-53aa-58a8-9334-e9fe2b812492', 'ds_cografya_0256', 'option_a', 'Arîtmetîk tenê jinan dijmêre, fîzyolojîk tenê karkerên bajêr digire nav xwe', 'Arîtmetîk nifûsa bajêr, fîzyolojîk nifûsa gundan dihesibîne'),
  ('0a3cc564-53aa-58a8-9334-e9fe2b812492', 'ds_cografya_0256', 'option_b', 'Arîtmetîk li seranserê çolê ye, fîzyolojîk li herêmên berfê tê pîvan', 'Arîtmetîk li gorî qada çandiniyê ye, fîzyolojîk li gorî tevahiya rûberê ye'),
  ('0a3cc564-53aa-58a8-9334-e9fe2b812492', 'ds_cografya_0256', 'option_c', 'Arîtmetîk nifûsa şevê ye, fîzyolojîk nifûsa rojane ya kar nîşan dide', 'Arîtmetîk li gorî qadên niştecihbûnê, fîzyolojîk li gorî daristan û çêrgehan e'),
  ('ecefa0a2-894e-539b-a127-e4faae0b4fc9', 'ds_cografya_0260', 'option_a', 'Nebûna çemên mezin li seranserê herêmê', 'Piraniya herêmê di çalên binê asta deryayê de ye'),
  ('ecefa0a2-894e-539b-a127-e4faae0b4fc9', 'ds_cografya_0260', 'option_b', 'Rûberên qûmî yên ku germê qet nagirin', 'Çiyayên peravê bi derbasgehên nizm parçe bûne û li ber bandora deryayê vekirî ne'),
  ('ecefa0a2-894e-539b-a127-e4faae0b4fc9', 'ds_cografya_0260', 'option_d', 'Kêmbûna radyasyona tavê di werzê havînê de', 'Hewaya ku li qeraxên çiyan bilind dibe her tim şiliyê dibe herêmên hundir'),
  ('1667c257-6de2-5076-a539-166921db4ab7', 'ds_cografya_0263', 'option_a', 'Ji bo çêkirina cihên fireh ên ji bo firîna balafiran', 'Bi lezkirina herikîna avê li ser qeraxê derxistina avê zêde kirin'),
  ('1667c257-6de2-5076-a539-166921db4ab7', 'ds_cografya_0263', 'option_c', 'Ji bo dîtina madenên bin erdê bi awayekî hêsantir', 'Bi dirêjkirina dema tavê ya axê zû gihîştina berheman misoger kirin'),
  ('1667c257-6de2-5076-a539-166921db4ab7', 'ds_cografya_0263', 'option_d', 'Ji bo parastina gund ji bayên germ ên havînê', 'Bi xurtkirina gera hewayê zirara qeşayê li riwekan kêm kirin'),
  ('70819ef4-4da6-57ed-85fb-e4b7458f29be', 'ds_cografya_0264', 'option_a', 'Rewşa hewayê tenê ji bo deryayê ye, avhewa tenê ji bo çiyê ye', 'Rewşa hewayê navîniya demdirêj e, avhewa guherîna rojane ye'),
  ('70819ef4-4da6-57ed-85fb-e4b7458f29be', 'ds_cografya_0264', 'option_b', 'Rewşa hewayê qet naguhere, avhewa her roj diguhere', 'Rewşa hewayê germahiyê, avhewa jî tenê rêjeya baranê dipîve'),
  ('70819ef4-4da6-57ed-85fb-e4b7458f29be', 'ds_cografya_0264', 'option_d', 'Rewşa hewayê bi piyanoyê tê pîvan, avhewa bi termometreyê', 'Rewşa hewayê parzemînên mezin, avhewa tenê herêmên biçûk digire'),
  ('27b6bf7d-c4ca-5d31-8e9f-37f1474da3e7', 'ds_cografya_0265', 'option_b', 'Herikîna lavên bazaltî yên sarbûyî', 'Sarbûn û hilweşîna tunelên lavên bazaltî (volkanîk)'),
  ('27b6bf7d-c4ca-5d31-8e9f-37f1474da3e7', 'ds_cografya_0265', 'option_c', 'Hilweşîna cemedên deryayî li deştan', 'Kolandina zinaran ji aliyê cemedan ve (cemedî)'),
  ('27b6bf7d-c4ca-5d31-8e9f-37f1474da3e7', 'ds_cografya_0265', 'option_d', 'Kevirbûna qûmên çolê bi bayên xurt', 'Xwarina zinaran bi qûma ku ba dibe (korazyon)'),
  ('95dcee2a-2f36-5d56-8582-79835dd3ffab', 'ds_cografya_0266', 'option_a', 'Kêmbûna radyasyona tavê ya li seranserê herêmê', 'Kişandina avê ya zêde ji golê ji bo sarkirina saziyên pîşesaziyê'),
  ('95dcee2a-2f36-5d56-8582-79835dd3ffab', 'ds_cografya_0266', 'option_b', 'Vekirina kanaleke mezin a ber bi Deryaya Spî ve', 'Qirêjiya kîmyewî ya ji kaniyên madenan ên li dora golê'),
  ('95dcee2a-2f36-5d56-8582-79835dd3ffab', 'ds_cografya_0266', 'option_d', 'Zêdebûna hejmara masîgirên kevneşopî yên li ser golê', 'Zêdebûna bilez a daxwaza ava vexwarinê ya bajarên li peravê golê'),
  ('89d948c5-c7a7-5f7a-a182-f5312b84ecd6', 'ds_cografya_0267', 'option_a', 'Di nîveka zivistanê ya herî sar de', 'Di nîveka zivistanê de, mehên herî sar'),
  ('89d948c5-c7a7-5f7a-a182-f5312b84ecd6', 'ds_cografya_0267', 'option_c', 'Di dawiya payîzê ya hişk de', 'Di mehên pêşîn ên baranî yên payîzê de'),
  ('89d948c5-c7a7-5f7a-a182-f5312b84ecd6', 'ds_cografya_0267', 'option_d', 'Tenê di meha tebaxê ya germ de', 'Di dawiya havînê de, tebax û îlonê'),
  ('bdcc8022-ab37-5e8c-b2b7-c0ce075ef616', 'ds_cografya_0269', 'option_b', 'Germahiyê kêm dike û baranê zêde dike', 'Germahiyê kêm dike û şiliyê zêde dike, mij çêdike'),
  ('bdcc8022-ab37-5e8c-b2b7-c0ce075ef616', 'ds_cografya_0269', 'option_c', 'Hewayê dicemidîne û dibe sedema berfê', 'Germahiyê zêde dike û şiliyê bilind dike, baranê dibarîne'),
  ('bdcc8022-ab37-5e8c-b2b7-c0ce075ef616', 'ds_cografya_0269', 'option_d', 'Ti guhertinekê di hewayê de çênake', 'Germahiyê wekî xwe dihêle, tenê leza bayê zêde dike'),
  ('ed231b2d-fe9a-5d6e-9551-9651712a17b9', 'ds_cografya_0270', 'option_a', 'Herikîna hêdî ya li ser deştên qûmî yên bê kevir', 'Zimanên cemedê binê newalê bi şeklê U fireh kiriye û kolaye'),
  ('ed231b2d-fe9a-5d6e-9551-9651712a17b9', 'ds_cografya_0270', 'option_c', 'Çêbûna bendavên xwezayî yên ji qeşayê li ber avê', 'Çem li deşta fireh bi menderesan rêya xwe ber bi aliyan ve vekiriye'),
  ('ed231b2d-fe9a-5d6e-9551-9651712a17b9', 'ds_cografya_0270', 'option_d', 'Nebûna ti herikîna avê di werzê bihar û havînê de', 'Herikînên lavê newal tije kiriye û di sarbûnê de qelişîne'),
  ('8884736b-cdfa-5b74-9ce8-8833ca58edce', 'ds_cografya_0273', 'option_a', 'Kêmbûna zexta hewayê ji ber barîna berfê ya li çiyayan', 'Girseya hewaya sar dadikeve binê deştê û zexta bilind çêdike'),
  ('8884736b-cdfa-5b74-9ce8-8833ca58edce', 'ds_cografya_0273', 'option_b', 'Herikîna sermayê ya ji deryayên bakur ber bi başûr', 'Bayên şil ên ji çiyayan tên li ser deştê kom dibin û gerdav çêdikin'),
  ('8884736b-cdfa-5b74-9ce8-8833ca58edce', 'ds_cografya_0273', 'option_c', 'Hebûna daristanên pir çirr ên li dora deştê', 'Hewaya hênik a şevê di nîvro de ber bi erdê ve dadikeve'),
  ('ca7a2945-730f-57b0-a1cd-b36ed09a5136', 'ds_cografya_0274', 'option_a', 'Pembû, birinc û mûz', 'Pembû, garis û silqa şekir'),
  ('ca7a2945-730f-57b0-a1cd-b36ed09a5136', 'ds_cografya_0274', 'option_c', 'Çay, fistiqên şil û findiq', 'Birinc, fasûlyeya soyayê û fistiqa erdê'),
  ('ca7a2945-730f-57b0-a1cd-b36ed09a5136', 'ds_cografya_0274', 'option_d', 'Qamîşê şekir û tûtina avî', 'Kartol, gulberoj û tûtin'),
  ('d28041fc-9626-556d-97aa-df309ad3bcf7', 'ds_cografya_0275', 'option_a', 'Nebûna ti zinar û çiyayan li tevahiya herêmê', 'Zivistana nerm, guncawbûna bo çandiniya deştê û nêzîkbûna bazarê'),
  ('d28041fc-9626-556d-97aa-df309ad3bcf7', 'ds_cografya_0275', 'option_b', 'Hebûna germahiya zêde ya ji bo çandiniya pembû', 'Havînên hişk, giyayên kêm û kêmbûna nexweşiyên ajalan'),
  ('d28041fc-9626-556d-97aa-df309ad3bcf7', 'ds_cografya_0275', 'option_c', 'Dûrketina ji hemû çavkaniyên avê yên xwezayî', 'Zivistana nerm, çêrgehên zivistanê yên fireh û demeke çêrandinê ya dirêj'),
  ('9ddc5840-c0f5-5a3f-b42f-d0a16a80588c', 'ds_cografya_0276', 'option_a', 'Tenê di navbera welatên Ewropayê de bazirganiyê dikin', 'Bajarên Anatoliya Navîn bi benderên Egeyê û bazarên Anatoliya Rojava ve girêdidin'),
  ('9ddc5840-c0f5-5a3f-b42f-d0a16a80588c', 'ds_cografya_0276', 'option_b', 'Rêya çandiniya pembû ji bo zozanên sar vedikin', 'Hewzeya Gola Wanê bi peravên Qezwînê yên Kafkasyayê ve girêdidin'),
  ('9ddc5840-c0f5-5a3f-b42f-d0a16a80588c', 'ds_cografya_0276', 'option_d', 'Têkiliya Kendava Farsê bi Okyanûsa Pasîfîk re saz dikin', 'Deştên başûrê rojhilat bi rêya derbasgehên Torosê bi benderên Deryaya Spî ve girêdidin'),
  ('ea9aefd2-0816-59a8-82cc-5f9b4497e8fa', 'ds_cografya_0277', 'option_a', 'Urmiye ava şêrîn a vexwarinê ye, Wan ava tehl a jehrî ye', 'Urmiye xwedî ava sodavî ya karbonatî ye, Wan xwedî ava şor a klorûrî ye'),
  ('ea9aefd2-0816-59a8-82cc-5f9b4497e8fa', 'ds_cografya_0277', 'option_b', 'Urmiye bi temamî ji petrolê pêk tê, Wan tenê ava berfê ye', 'Her du gol jî sodavî û karbonatî ne; tenê kûrahiya wan cuda ye'),
  ('ea9aefd2-0816-59a8-82cc-5f9b4497e8fa', 'ds_cografya_0277', 'option_c', 'Her du gol jî xwedî ava şêrîn a wekhev in û ti şorayî tê de nîne', 'Urmiye ava tehl a sulfatî ye, Wan ava şêrîn a kêmşor e'),
  ('2643da36-fe95-5dda-8c96-22be4df82306', 'ds_cografya_0279', 'option_a', 'Helîna zinarên kilsî yên mezin di bin ava deryayê de', 'Platoyên lavê yên ku bi tijîbûna newalan ji lavên volkanîk çêbûne'),
  ('2643da36-fe95-5dda-8c96-22be4df82306', 'ds_cografya_0279', 'option_b', 'Komkirina qûmên çolê ji aliyê bayên xurt ên başûr ve', 'Deltayên ku bi komkirina aluvyonên çeman çêbûne'),
  ('2643da36-fe95-5dda-8c96-22be4df82306', 'ds_cografya_0279', 'option_c', 'Hilweşîna daran di serdemên qeşayê de li ser newalan', 'Çalên cemedî yên ku bi kolandina newalan ji aliyê cemedan ve çêbûne'),
  ('aa75cc75-04df-5e27-8310-703ac4407629', 'ds_cografya_0280', 'option_b', 'Herikîna avê bi temamî diguherînin ber bi Deryaya Spî ve', 'Rêyên çeman fireh dikin û li jêr deştên lehiyê yên nû çêdikin'),
  ('aa75cc75-04df-5e27-8310-703ac4407629', 'ds_cografya_0280', 'option_c', 'Avhewaya tevahiya Mezopotamyayê dikin cemserî û sar', 'Her sal aluvyonên zêdetir dibin peravên deltayê û peravê ber bi deryayê ve pêş dixin'),
  ('aa75cc75-04df-5e27-8310-703ac4407629', 'ds_cografya_0280', 'option_d', 'Rêjeya barana salane li seranserê çiyayan kêm dikin', 'Şoriya çeman kêm dikin û zûnkavên deltayê dikin golên şêrîn'),
  ('8c7a33ca-d0ab-5a0e-b171-ea37303e84c4', 'ds_cografya_0282', 'option_b', 'Ji ber ku li serê çiyayan germahiya havînê ji her derê zêdetir e', 'Bikaranîna axa berdar a binê deştê rasterast wekî baxçeyên xaniyan'),
  ('8c7a33ca-d0ab-5a0e-b171-ea37303e84c4', 'ds_cografya_0282', 'option_c', 'Ji bo gihîştina hêsan a keştiyên deryayî yên bazirganiyê', 'Li quntarên çiyayan zivistanê qatê berfê ji binê deştê ziravtir e'),
  ('8c7a33ca-d0ab-5a0e-b171-ea37303e84c4', 'ds_cografya_0282', 'option_d', 'Ji bo dûrketina ji hemû çavkaniyên daristanî yên herêmê', 'Ji bo parastina ji heywanên kovî hilbijartina cihên bilind û zinarî'),
  ('7f30b988-0f46-58bd-9399-ded429c7cf5e', 'ds_cografya_0283', 'option_a', 'Tenê xeta Ekwatorê ya nizm', 'Derdora Ekwatorê (kembera tropîkal)'),
  ('7f30b988-0f46-58bd-9399-ded429c7cf5e', 'ds_cografya_0283', 'option_b', 'Tenê herêma Cemsera Bakur', 'Derdora cemseran (hêlîpanên bilind)'),
  ('7f30b988-0f46-58bd-9399-ded429c7cf5e', 'ds_cografya_0283', 'option_d', 'Tenê rûberên okyanûsên kûr', 'Hemû hêlîpan (xeletî li her derê wekhev e)'),
  ('23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'ds_cografya_0284', 'option_b', 'Tenê ji xwêya spî û kilsa heliyayî pêk tê', 'Ji aliyê karbonata kalsiyûmê ve ji axên kilsî dewlemendtir e'),
  ('23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'ds_cografya_0284', 'option_c', 'Ti mîneralan di nav xwe de nagire û zû hişk dibe', 'Ji aliyê madeyên organîk ve pir xizan e, qûmî ye û avê nagire'),
  ('23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'ds_cografya_0284', 'option_d', 'Tenê ji kilsên asîdî yên avnegir ava bûye', 'Ji ber kombûna xwêyê ji bo çandiniyê ne guncaw e, şorax û hişk bûye'),
  ('cce6f321-dc09-59e2-9897-e6901ad494cc', 'ds_cografya_0285', 'option_a', 'Herikîna avên okyanûsan ji rojava ber bi rojhilat', 'Plakaya Afrîkayê Plakaya Anatoliyê ber bi rojava ve dide pêş û vedike'),
  ('cce6f321-dc09-59e2-9897-e6901ad494cc', 'ds_cografya_0285', 'option_b', 'Kêmbûna zexta atmosferê ya li ser Çola Erebistanê', 'Plakaya Ewrasyayê ber bi başûrê rojava ve dikeve binê Plakaya Erebistanê'),
  ('cce6f321-dc09-59e2-9897-e6901ad494cc', 'ds_cografya_0285', 'option_c', 'Teqîna volkanên binê deryayê li Kendava Farsê', 'Blok li ser Şikesta Anatoliya Rojhilat bi alî ve dişemitin û li ser hev kom dibin'),
  ('0cf507aa-639e-52c5-81b1-c0b2f6f20092', 'ds_cografya_0286', 'option_b', 'Çolên qûmî -> daristanên tropîkal -> mêweyên germ', 'Darên derzîkî -> darên pelweşîn (berû) -> çêrgehên alpîn'),
  ('0cf507aa-639e-52c5-81b1-c0b2f6f20092', 'ds_cografya_0286', 'option_c', 'Darên mûzê -> darên çamê -> baxçeyên firingiyan', 'Çêrgehên alpîn -> darên derzîkî -> darên pelweşîn (berû)'),
  ('0cf507aa-639e-52c5-81b1-c0b2f6f20092', 'ds_cografya_0286', 'option_d', 'Darên berûyê -> zeviyên pembû -> darên hejîran', 'Darên pelweşîn (berû) -> çêrgehên alpîn -> darên derzîkî'),
  ('fb2ade10-d4b7-5787-adf5-e3ea67b30422', 'ds_cografya_0287', 'option_a', 'Zêdebûna hewaya germ a li ser serê lûtkeyên çiyayan', 'Peydakirina kedê ji bo karên dirûnê yên zivistanê li deştê û nêzîkbûna bazaran'),
  ('fb2ade10-d4b7-5787-adf5-e3ea67b30422', 'ds_cografya_0287', 'option_b', 'Ji bo firotina hemû ajalan di bazarên Ewropayê de', 'Hişkesaliya payîzê ya li zozanan û şorbûna ava kaniyan'),
  ('fb2ade10-d4b7-5787-adf5-e3ea67b30422', 'ds_cografya_0287', 'option_d', 'Dîtina kaniyên nû yên avê li ser lûtkeyên berfîn', 'Di mehên zivistanê de nêzîkî navendên bazirganiyê bûn û zêdekirina firotina berhemên ajalan'),
  ('a9a7a739-a477-553d-a696-3d7e75fae5bd', 'ds_cand_1179', 'option_a', 'Tenê ji bo cejnên neteweyî guhertina bajêr', 'Xwesteka eşîran ku di demên bacê de ji rêveberiyên bajaran dûr bimînin'),
  ('a9a7a739-a477-553d-a696-3d7e75fae5bd', 'ds_cand_1179', 'option_b', 'Ji bo bazirganiya deryayî ya di navbera dewletan de', 'Mecbûriya çandina dexlê li zozanan di zivistanê de û dirûna wê li deştê di havînê de'),
  ('a9a7a739-a477-553d-a696-3d7e75fae5bd', 'ds_cand_1179', 'option_d', 'Ji bo xwendina zarokan di dibistanên zivistanê de', 'Girêdana bi kevneşopiya serdana cihên pîroz a salê du caran'),
  ('2a4de7ab-2c4b-5a94-9045-f9365bfd9281', 'ds_cand_1180', 'option_a', 'Zilamê ku berpirsê ewlehiya konên zozanê ye', 'Pêşengê şandeya ku di dawetan de bûkê ji mala bavê wê tîne'),
  ('2a4de7ab-2c4b-5a94-9045-f9365bfd9281', 'ds_cand_1180', 'option_b', 'Kesê ku tenê kincên dawetê bi destan didûre', 'Jina pîr a ku di şînan de dilorîne û şînê bi rê ve dibe'),
  ('2a4de7ab-2c4b-5a94-9045-f9365bfd9281', 'ds_cand_1180', 'option_c', 'Dengbêjê ku kilamên şer di civatê de dibêje', 'Jina çîrokbêj a hoste ku di sohbetên şevên zivistanê de çîrok û destanan dibêje'),
  ('a242354c-e9b0-5a1f-a53e-358b2f0b8952', 'ds_cand_1181', 'option_a', 'Ji hevrîşimê çînî yê tenik ku tenê di dawetan de tê lixwekirin', 'Ji tayê pembû tê hûnandin; xwêdanê dikişîne lê zivistanê sar digire'),
  ('a242354c-e9b0-5a1f-a53e-358b2f0b8952', 'ds_cand_1181', 'option_c', 'Ji pembûyê nerm ê ku tenê ji bo herêmên germ guncaw e', 'Ji hiriya pez wekî kulav tê kutan; giran e, di zivistanê de tê lixwekirin'),
  ('a242354c-e9b0-5a1f-a53e-358b2f0b8952', 'ds_cand_1181', 'option_d', 'Ji çermê sewalan ê giran ku qet avê bernade hundir', 'Ji têla kenefê tê hûnandin; hişk û xurt e, baranê derbas nake'),
  ('6715b57b-f5f9-5359-9c9e-aa948ea4f765', 'ds_cand_1182', 'option_a', 'Tenê ji kincên reş ên bê reng û bê nexş pêk tê', 'Kirasekî hirî yê yek-parçe yê mil-kurt heta çokan û şûtikeke hirî'),
  ('6715b57b-f5f9-5359-9c9e-aa948ea4f765', 'ds_cand_1182', 'option_b', 'Tenê şalwarekî teng ê ji çermê hespan ê boyaxkirî ye', 'Çarşefeke reş a sade û şalwarekî pembû yê bê nexş li binê wê'),
  ('a5a3a752-6996-5e73-a4ac-4f0f54d4d296', 'ds_cand_1183', 'option_a', 'Nîşaneya çekên leşkerî yên serdema kevnar', 'Serkeftinên şer û mêrxasiya eşîrên koçer'),
  ('a5a3a752-6996-5e73-a4ac-4f0f54d4d296', 'ds_cand_1183', 'option_b', 'Tenê hejmara sewalên ku di zozanan de hene', 'Baweriyên li ser mirin, şîn û rêwîtiya axretê'),
  ('a5a3a752-6996-5e73-a4ac-4f0f54d4d296', 'ds_cand_1183', 'option_d', 'Nexşeya sînorên mîrektiyên kevn ên herêmê', 'Rêyên karwanan, bazirganî û bêriya welatên dûr'),
  ('32b9ad48-80eb-5238-bafa-3d8ce0576fc7', 'ds_cand_1185', 'option_a', 'Li deştên sar ên Qersê', 'Li zozanên Qers, Erdexan û Erzeromê'),
  ('32b9ad48-80eb-5238-bafa-3d8ce0576fc7', 'ds_cand_1185', 'option_c', 'Li qiraxa Deryaya Qezwînê', 'Li gundên çiyayî yên Wan, Colemêrg û Elbakê'),
  ('32b9ad48-80eb-5238-bafa-3d8ce0576fc7', 'ds_cand_1185', 'option_d', 'Li giravên başûrê Deryaya Egeyê', 'Li derdora Dêrsim, Erzîngan û Elezîzê'),
  ('4882723a-6c58-54d0-aaaa-9aa4abad7539', 'ds_cand_1186', 'option_a', 'Tenê ji bo cezakirina kesên ku nehatine sersaxiyê', 'Ragihandina li ber civakê ka mîrateya mirî dê ji kê re bimîne'),
  ('4882723a-6c58-54d0-aaaa-9aa4abad7539', 'ds_cand_1186', 'option_b', 'Diyarkirina mîrateya maddî ya di navbera zarokan de', 'Pirsîna sedema mirinê û diyarkirina berpirsiyar li ber civakê'),
  ('4882723a-6c58-54d0-aaaa-9aa4abad7539', 'ds_cand_1186', 'option_c', 'Pêşbirkek ji bo xelata herî bilind a dengbêjiyê', 'Diyarkirina rêz û pergala mêvandariya kesên ku tên sersaxiyê'),
  ('fb78d683-7f0b-5009-8a9c-061df77f2021', 'ds_cand_1187', 'option_a', 'Bêrîvan (dotinvan)', 'Bêrîvan'),
  ('fb78d683-7f0b-5009-8a9c-061df77f2021', 'ds_cand_1187', 'option_b', 'Pêşmerge (şervan)', 'Birazava'),
  ('fb78d683-7f0b-5009-8a9c-061df77f2021', 'ds_cand_1187', 'option_d', 'Çawîş (cerdevan)', 'Dengbêj'),
  ('78bb8251-66fd-5328-8a44-441ac38cfbc3', 'ds_cand_1188', 'option_a', 'Giranî tenê bi rûniştî tê lîstin, Şêxanî tenê li ser hespan e', 'Şêxanî bi gavên giran û seknekê ye, Giranî bileztir û livdar e'),
  ('78bb8251-66fd-5328-8a44-441ac38cfbc3', 'ds_cand_1188', 'option_b', 'Giranî tenê bi jinan e, Şêxanî tenê lîstika zarokan e', 'Her du jî bi heman rîtmê ne; Giranî di dawetan de, Şêxanî di cejnan de tê lîstin'),
  ('78bb8251-66fd-5328-8a44-441ac38cfbc3', 'ds_cand_1188', 'option_c', 'Giranî ti caran bê def nabe, Şêxanî qet muzîkê naxwaze', 'Giranî bi tenê tê lîstin, Şêxanî tenê bi cotên du kesî tê lîstin'),
  ('604b70fc-0eb9-5295-a32b-43768578e22e', 'ds_cand_1189', 'option_a', 'Cejna Qurbanê ya Payîzê', 'Cejna Êzîd (cejna rojiya Kanûnê)'),
  ('604b70fc-0eb9-5295-a32b-43768578e22e', 'ds_cand_1189', 'option_c', 'Cejna Remezanê ya Mezin', 'Cejna Cemayê (civîna payîzê ya Lalişê)'),
  ('604b70fc-0eb9-5295-a32b-43768578e22e', 'ds_cand_1189', 'option_d', 'Şeva Yeldayê ya Zivistanê', 'Newroz (cejna biharê ya 21ê Adarê)'),
  ('eb1aca6d-a1b6-5c33-823c-a158dc1a13ab', 'ds_cand_1191', 'option_b', 'Tenê qonaxên dewlemendan ên li navenda bajaran', 'Cihên civînê yên hevpar ên li qadên gundan ku di cejnan de tên bikaranîn'),
  ('eb1aca6d-a1b6-5c33-823c-a158dc1a13ab', 'ds_cand_1191', 'option_c', 'Bazarên bazirganiyê yên ku di cejnan de vedibin', 'Xan û karwansarayên li ser rêyên karwanan ên kevn ku rêwî lê dimînin'),
  ('eb1aca6d-a1b6-5c33-823c-a158dc1a13ab', 'ds_cand_1191', 'option_d', 'Kelehên leşkerî yên serdema şerên kevn ên navçeyê', 'Baxçeyên taybet ên malbatan ku gorên serokeşîran lê ne'),
  ('827d658b-a598-59f2-94d0-7df2fd69c607', 'ds_cand_1192', 'option_a', 'Tenê fêrkirina zimanên biyanî ji bo bazirganiyê', 'Parvekirina karên zevî û çêrgehên hevpar ên gund ji bo sala bê'),
  ('827d658b-a598-59f2-94d0-7df2fd69c607', 'ds_cand_1192', 'option_b', 'Qedexekirina axaftinê di şevên dirêj ên zivistanê de', 'Danasîn û destgirtina ciwanan ji bo zewacê ji aliyê mezinên malbatê ve'),
  ('827d658b-a598-59f2-94d0-7df2fd69c607', 'ds_cand_1192', 'option_c', 'Tomarkirina dîjîtal a hemû kilam û stranên herêmê', 'Çareserkirina nakokiyên di navbera eşîran de li ber heyeta navbeynkar'),
  ('b01bd24b-e2f2-5704-9cd1-e6a217d7eaf7', 'ds_cand_1193', 'option_b', 'Tenê çêkirina şerbeta şîrîn ji bo firotina li bazaran', 'Derketina xortên gund bo nêçîrê di serê salê de û parvekirina wê bi malbatan re'),
  ('b01bd24b-e2f2-5704-9cd1-e6a217d7eaf7', 'ds_cand_1193', 'option_c', 'Qedexekirina derketina derve di tevahiya meha çileyê de', 'Vemirandina ocaxan di şeva dawî ya salê de û ji nû ve vêxistina wan'),
  ('b01bd24b-e2f2-5704-9cd1-e6a217d7eaf7', 'ds_cand_1193', 'option_d', 'Komkirina bacê ji bo dewletê di dawiya salê de', 'Birina diyariyan bi hev re bo malên mezinên gund di roja yekem a salê de'),
  ('5207c871-b193-5559-a69a-ea2265c3c666', 'ds_cand_1195', 'option_b', 'Ji bo ku agirê binê erdê penêr zû biqelîne', 'Zêdekirina hewagirtina penêr û pêşxistina kifikê li ser rûyê wî'),
  ('5207c871-b193-5559-a69a-ea2265c3c666', 'ds_cand_1195', 'option_c', 'Ji bo ku keda mirovan ji çavên dizan veşartî bimîne', 'Ji bo ziwakirina giyayên nav penêr û hişkmayîna wî di tevahiya havînê de'),
  ('5207c871-b193-5559-a69a-ea2265c3c666', 'ds_cand_1195', 'option_d', 'Tenê ji bo ku rengê penêr ji spî veguhere reş', 'Derbaskirina şiliya axê bo penêr û bilindkirina rêjeya avê ya wî'),
  ('adefc83e-9509-55ba-84db-b186df2748b8', 'ds_cand_1196', 'option_a', 'Tenê peymaneke aborî ya ji bo kirîna zeviyên çandiniyê ye', 'Peymaneke ku sînorên erdê di navbera gundan de diyar dike û milkiyetê diparêze'),
  ('adefc83e-9509-55ba-84db-b186df2748b8', 'ds_cand_1196', 'option_c', 'Tenê cejnek e ku salê carekê bi lîstikan tê derbaskirin', 'Hilanîna berhemê ya hevpar a gundên cîran û bikaranîna wê di salên xelayê de'),
  ('b3087fec-a35c-5535-802c-57e74c5c5ac4', 'ds_cand_1197', 'option_b', 'Tenê di pêşbirkên bazdana hespan de ji bo betlaneyê', 'Di karên merasîmî de ku ji bilî amadekariya cejn û dawetan nayên kirin'),
  ('b3087fec-a35c-5535-802c-57e74c5c5ac4', 'ds_cand_1197', 'option_c', 'Tenê di dema nîqaşên siyasî yên li nav bajaran de', 'Di karên wekî lênêrîna dibistan û mizgefta gund de ku karmendên fermî dikin'),
  ('b3087fec-a35c-5535-802c-57e74c5c5ac4', 'ds_cand_1197', 'option_d', 'Di bazirganiya bi dewletên derve re li ser sînoran', 'Di karên hevpariya bazirganî ya kirîn û firotina ajalan de li bazaran'),
  ('1cfd5326-1758-5988-ac13-61cdddd4e068', 'ds_cand_1198', 'option_a', 'Tenê perwerdeya leşkerî ya deryayî ji bo xortên herêmê dida', 'Tenê zanistên olî yên bi erebî dihatin xwendin, kurdî ji dersan derxistî bû'),
  ('1cfd5326-1758-5988-ac13-61cdddd4e068', 'ds_cand_1198', 'option_b', 'Tenê qursên bazirganiya hevrîşimê ya rojavayî dihundirand', 'Wêjeya dîwanê ya farisî û hunera xetê ji katiban re dihat hînkirin'),
  ('1cfd5326-1758-5988-ac13-61cdddd4e068', 'ds_cand_1198', 'option_d', 'Hemû cureyên xwendin û nivîsandina bi kurdî qedexe dikir', 'Hînkirina kurdî tenê bi axaftina rojane re sînordar dibû û wêjeya nivîskî nedihat xwendin'),
  ('793b516a-bec9-5b6a-9d86-51ddb3ff26ed', 'ds_cand_1200', 'option_b', 'Voleybola ser masê', 'Beyzbol an krîketa îngilîzî'),
  ('793b516a-bec9-5b6a-9d86-51ddb3ff26ed', 'ds_cand_1200', 'option_c', 'Avjenî û melevaniyê', 'Bocce an bîlardo'),
  ('793b516a-bec9-5b6a-9d86-51ddb3ff26ed', 'ds_cand_1200', 'option_d', 'Tenîsa ser maseyê', 'Lakros an lîstika topa dergehê'),
  ('c45c2776-23ff-56bf-8462-aa6b3d729533', 'ds_cand_1202', 'option_a', 'Tenê komkirina bacên salane ji bo axayên herêmê', 'Pîrozkirina dawiya dirûnê û parvekirina zexîreya zivistanê di navbera malbatan de'),
  ('c45c2776-23ff-56bf-8462-aa6b3d729533', 'ds_cand_1202', 'option_c', 'Qedexekirina her cure lîstik û govendê li derve', 'Jimartina keriyan berî koça zozanê û parvekirina çêrgehan di navbera malbatan de'),
  ('c45c2776-23ff-56bf-8462-aa6b3d729533', 'ds_cand_1202', 'option_d', 'Diyarkirina sînorên nû yên parêzgehan bi kevirên spî', 'Bîranîna miriyên zivistanê û paqijkirin û çêkirina goristanan bi hev re'),
  ('1237b936-23b4-5aa3-aa27-7fa7f78e3bf5', 'ds_cand_1203', 'option_a', 'Tenê heft rojên ku di zivistanê de berf nabare', 'Heft cejnên pîroz ên salê û serdana ku di her yekê de tê kirin'),
  ('1237b936-23b4-5aa3-aa27-7fa7f78e3bf5', 'ds_cand_1203', 'option_b', 'Heft padîşahên ku beriya zayînê şer kirine', 'Rêwîtiya heft pêxemberên ku wekî damezrînerên baweriyê tên hesibandin'),
  ('1237b936-23b4-5aa3-aa27-7fa7f78e3bf5', 'ds_cand_1203', 'option_d', 'Tenê heft cureyên çandiniyê yên herêmê', 'Heft qatên axretê yên ku giyan piştî mirinê di wan re derbas dibe'),
  ('bd950be5-e5d6-5aed-8704-24641f1f181d', 'ds_cand_1204', 'option_b', 'Her tim hundirê konê mîna cemedê sar dihêle di zivistanê de', 'Mûyên şil sist dibin, kun vedibin û kon zûtir hişk dibe'),
  ('bd950be5-e5d6-5aed-8704-24641f1f181d', 'ds_cand_1204', 'option_c', 'Ti carî bi bayê xurt nahêle ku çadir li ser lingan bimîne', 'Hûnandina çirr di her demsalê de heman derbasbûna hewayê diparêze'),
  ('bd950be5-e5d6-5aed-8704-24641f1f181d', 'ds_cand_1204', 'option_d', 'Tenê ronahiya tavê ya zêde dikişîne nav nivîn û odeyan', 'Ji ber ku qumaş pir sivik e, kesek dikare di saetekê de hilgire û vegire'),
  ('577a6f3e-8780-51b4-af70-58eb2fd82f05', 'ds_cand_1205', 'option_a', 'Tenê li gorî leza hespê yê ku herî pêşîn hatiye', 'Li gorî rêza ketina odeyê; yê pêşîn diçe serê odê, yê dawî li ber derî'),
  ('577a6f3e-8780-51b4-af70-58eb2fd82f05', 'ds_cand_1205', 'option_b', 'Tenê li gorî rengê kincên ku li xwe kirine', 'Li gorî rêzeke ku bi nirxê çek û hespê kesî tê diyarkirin'),
  ('577a6f3e-8780-51b4-af70-58eb2fd82f05', 'ds_cand_1205', 'option_d', 'Li gorî bejna herî dirêj di nav ciwanan de', 'Li gorî rêzeke ku xwediyê malê her êvar bi pişkê ji nû ve diyar dike'),
  ('afabb6d9-868b-5205-acd3-dba1343a2ffd', 'ds_cand_1206', 'option_a', 'Tenê wekî kincê fermî di dadgehan de tê lixwekirin', 'Ji ber ku sivik û zirav e, di germa havînê de siyê dide'),
  ('afabb6d9-868b-5205-acd3-dba1343a2ffd', 'ds_cand_1206', 'option_c', 'Tenê di bin avê de ji bo melevaniyê tê bikaranîn', 'Bi rengên xwe yên geş dihêle ku di hewaya mijdar de şivan ji dûr ve bê dîtin'),
  ('afabb6d9-868b-5205-acd3-dba1343a2ffd', 'ds_cand_1206', 'option_d', 'Ji ber ku ji hesinê sivik hatiye çêkirin li dijî guleyan e', 'Bi rengê xwe heywanên dirr ditirsîne û ji keriyê dûr dixe'),
  ('5f36571b-10a1-5e06-a477-e94d0e56faa3', 'ds_cand_1207', 'option_a', 'Tenê baca ku ji bo firotina xwêya gulan tê dayîn', 'Xwêya xwarina ku ji mêvan re tê danîn comerdiya xwediyê malê nîşan dide'),
  ('5f36571b-10a1-5e06-a477-e94d0e56faa3', 'ds_cand_1207', 'option_b', 'Qanûna ku xwarina xwêyê di şîvê de qedexe dike', 'Şîreta teserûfê ku dibêje divê nan û xwê neyên avêtin'),
  ('5f36571b-10a1-5e06-a477-e94d0e56faa3', 'ds_cand_1207', 'option_d', 'Pêşbirkek ji bo çêkirina nanê herî mezin ê herêmê', 'Parvekirina wekhev a xwêya ku bi karwanan tê di nav xelkê gund de'),
  ('19add189-7a66-5a18-aa9d-1a4d22707bf1', 'ds_edebiyat_0244', 'option_b', 'Xanî hemû lehengên destanê ji holê rakirine û tenê behsa şerê dîrokî kiriye', 'Xanî çîroka gelêrî qet neguhertiye, tenê bi tîpên erebî nivîsandiye û berhev kiriye'),
  ('19add189-7a66-5a18-aa9d-1a4d22707bf1', 'ds_edebiyat_0244', 'option_c', 'Memê Alan bi alfabeya latînî hatiye nivîsandin lê Mem û Zîn tenê bi devkî ye', 'Xanî dawiya trajîk a destanê guhertiye û dawiyeke kêfxweş a gihîştina Mem û Zînê nivîsandiye'),
  ('19add189-7a66-5a18-aa9d-1a4d22707bf1', 'ds_edebiyat_0244', 'option_d', 'Mem û Zîn tenê lîstikeke şanoyê ya nûjen e ku di sedsala bîstan de hatiye nivîsandin', 'Xanî mesnewî bi farisî nivîsandiye, wergera wê ya kurmancî paşê şagirtên wî amade kiriye'),
  ('19b9848a-6147-5952-819d-abee8a690037', 'ds_edebiyat_0245', 'option_a', 'Nîqaşa li ser bihayê genim û deştên çandiniyê', 'Dadperweriya mîrên Cizîrê û sivikkirina barê bacê li ser gel'),
  ('19b9848a-6147-5952-819d-abee8a690037', 'ds_edebiyat_0245', 'option_b', 'Diyarkirina rêzikên bazirganiya hevrîşimê li Cizîrê', 'Kurdî wekî zimanê edebî ne kêmî farisî û erebî ye'),
  ('19b9848a-6147-5952-819d-abee8a690037', 'ds_edebiyat_0245', 'option_d', 'Şerê di navbera împaratoriyên rojava û rojhilat de', 'Bedewiya biharê û sadebûna jiyana koçeran li zozanan'),
  ('69be4d7f-3805-5891-b6bc-698752e4b998', 'ds_edebiyat_0246', 'option_a', 'Hawar tenê bi zimanê fransî derket, Rêya Teze tenê bi zimanê ermenî bû', 'Her du jî bi tîpên erebî derketin, lê Rêya Teze nîşanên zêde ji bo dengdêran bi kar anîn'),
  ('69be4d7f-3805-5891-b6bc-698752e4b998', 'ds_edebiyat_0246', 'option_c', 'Hawar tenê kovareke wêneyî bû, Rêya Teze qet tiştek çap nedikir', 'Hawar bi latînî, Rêya Teze jî ji hejmara xwe ya yekem ve tenê bi kirîlî derket'),
  ('69be4d7f-3805-5891-b6bc-698752e4b998', 'ds_edebiyat_0246', 'option_d', 'Her du weşanan jî tenê alfabeya erebî ya kevn a osmanî bi kar dianî', 'Hawar bi tîpên erebî, Rêya Teze jî bi tîpên ermenî yên guncandî derket'),
  ('1ea2be4c-5b71-5869-a305-75e6ee313d87', 'ds_edebiyat_0248', 'option_b', 'Hemû cureyên helbestê qedexe kirin û tenê çîrokên zarokan nivîsandin', 'Helbest ji zimanê gel dûr xist û ber bi zimanekî dîwanê yê bi giranî farisî û erebî ve bir'),
  ('1ea2be4c-5b71-5869-a305-75e6ee313d87', 'ds_edebiyat_0248', 'option_c', 'Helbest tenê bi zimanê latînî yê kevnar di nav dêran de xwend', 'Erûz bi temamî berda û tenê bi helbesta azad li ser evîn û xwezaya kesane nivîsî'),
  ('1ea2be4c-5b71-5869-a305-75e6ee313d87', 'ds_edebiyat_0248', 'option_d', 'Tenê behsa xwezaya Ewropayê kir û ji jiyana welat bi temamî dûr ket', 'Kevneşopiya dîwanê ya klasîk wekî xwe domand û mijarên tesewifî ji nû ve vejandin'),
  ('4cf1534a-28ce-5a0c-9b7c-5510b31dd5f4', 'bilim_0051', 'option_b', 'Veguherandina fosfora di axê de bo oksîjena ku riwek dikare bikar bîne', 'Amonyaka axê oksîde dike û dike nîtrît'),
  ('4cf1534a-28ce-5a0c-9b7c-5510b31dd5f4', 'bilim_0051', 'option_c', 'Depokirina hemû ava ku riwek ji axê dikişîne di girêkên kokê de', 'Nîtrata ku di kokê de kom bûye wekî gaza nîtrojenê dîsa berdide atmosferê'),
  ('4cf1534a-28ce-5a0c-9b7c-5510b31dd5f4', 'bilim_0051', 'option_d', 'Sekinandina bi tevahî ya çêkirina klorofîlê di pelên riwekê de', 'Nîtrîta axê vediguherîne nîtrat'),
  ('74eae4a8-7462-5082-8b24-4f565f1cd399', 'offline_tek_2006', 'option_a', 'Ji ber ku av di boriyan de sartir dibe û kêm dibe', 'Ji ber ku av rasterast digihîje qatên kûr ên axê'),
  ('74eae4a8-7462-5082-8b24-4f565f1cd399', 'offline_tek_2006', 'option_c', 'Ji ber ku dilop ji lehiyê giran in', 'Ji ber ku ava di boriyan de tê berhevkirin û dîsa tê bikaranîn'),
  ('8800d2fb-b58b-5a97-aeac-15270193a913', 'offline_6059', 'explanation_ku', '"hewran": kincê dirêj ê ku li ser kincên din tê lixistin.', 'Hewran kincê dirêj ê derve ye ku li ser kincên din tê lixwekirin; ne qata rojane, qata herî jor e.'),
  ('b0a0fca8-aa88-5f74-a85a-16119b8655eb', 'offline_6093', 'explanation_ku', '"tûrik": tûrikê ku ji bo hilgirtina xwarinê tê hûnandin.', 'Tûrik tûrikekî hûnandî ye; ji bo birina nan û zad di rê û zeviyê de tê bikaranîn.'),
  ('a7f1b481-b1e1-5559-975e-c29ae42be8b1', 'offline_6117', 'explanation_ku', '"nanê tenûrê": nanê kevneşopî yê ku di tenûrê de tê patin.', 'Nanê tenûrê nanê tenik e ku bi dîwarê hundirê tenûrê ve tê zeliqandin û tê patin; nav jî ji tenûrê tê.'),
  ('4e28dece-a151-5b47-8d78-2abe2bc43d93', 'offline_6136', 'explanation_ku', '"koçerî": şêwaza jiyana koçeran a ku bi demsalan di navbera zozan û germiyanan de digere.', 'Koçerî şêwaza jiyanê ye ku li ser koça demsalî ya di navbera zozan û germiyanê de ava bûye; bi heman navî rîtmeke govendê jî heye.'),
  ('992b5825-d7da-528f-84c0-11d4b53b4e4a', 'offline_6189', 'explanation_ku', '"cîranî": cîrantî û hevkariya civakî.', 'Cîranî ji peyva "cîran" tê; têkiliya cîrantiyê û alîkariya di navbera cîranan de vedibêje.'),
  ('056a6a6f-6811-5da1-8660-f4e31476c213', 'offline_6457', 'explanation_ku', '"şabaş": kevneşopiya avêtina baxşîşê ji muzîkjenan re.', 'Şabaş kevneşopiya dayîna pere an diyariyan e di dawet û şahiyan de; li gelek deveran baxşîşa ku ji muzîkjen û dengbêjan re tê dayîn vedibêje.'),
  ('d82f6053-3c83-5856-a18a-1fcae2184ee1', 'offline_6465', 'explanation_ku', '"sersal": pîrozkirina serê salê di salnameya gelêrî ya kurdî de.', 'Sersal ji "ser" û "sal" pêk tê; di salnameya gelêrî de pîrozkirina destpêka sala nû vedibêje.'),
  ('536d2683-b5d1-56db-9934-3c015ffb93d5', 'offline_6533', 'explanation_ku', '"vegotina çîrokan": vegotina ku ji nifşekî diçe nifşekî din.', 'Çîrok di kevneşopiya devkî de ji nifşekî bo nifşekî din tên gotin û veguhastin; bi demê re bi nivîsandinê jî tên parastin.'),
  ('c1900627-a209-52f4-a198-d4b85eb58581', 'offline_6538', 'explanation_ku', '"şevbêrk": civînên şevê yên zivistanê.', 'Şevbêrk civîna şevên dirêj ên zivistanê ye ku cîran li malekê kom dibin û bi çîrok, kilam û sohbetê dem derbas dikin.'),
  ('6e9f8007-63ad-5c56-b456-42cb3b7a3d93', 'offline_6730', 'explanation_ku', '"serpêhatî": vegotina bûyerên balkêş ên jiyayî.', 'Serpêhatî vegotina bûyerên ku hatine jiyîn û ji serê kesekî derbas bûne ye; bi vê yekê ji çîroka xeyalî cuda dibe.'),
  ('aaadbd89-176c-5541-aee0-4a3785b2729f', 'offline_6835', 'explanation_ku', '"qutik": êlek an cilê kurdî yê kevneşopî.', 'Qutik navê êlek an kincê jor e di cilên kevneşopî de; vebijarkên din ne cil in, hêmanên din ên çandê ne.'),
  ('8ff79e66-cf2b-526a-b1ad-3c7413d73fc8', 'offline_6841', 'explanation_ku', '"reşmal": çadira ku ji mûyê reş ê bizinan tê çêkirin.', 'Reşmal yanî "mala reş": konê koçeran e ku ji mûyê bizinan tê hûnandin; mû di baranê de diwerime û avê bernade.'),
  ('b74aada5-767d-5b34-983c-c53c92f8b4e4', 'offline_7066', 'explanation_ku', '"Dêrsim 1937": operasyona leşkerî ya 1937-38an û kuştinên girseyî.', 'Dêrsim 1937–38 operasyona leşkerî ya dewletê ya li herêmê û kuştin û sirgûnên girseyî yên wê demê vedibêje.'),
  ('eecba717-363e-569d-9e6e-3a90d9bae4a2', 'offline_7145', 'explanation_ku', '"Şêx Seîd": rêberê serhildana 1925an a ji bo mafên kurdan.', 'Şêx Seîd rêberê serhildana 1925an bû; dîroknas aliyên olî û neteweyî yên serhildanê bi awayên cuda dinirxînin. Serhildan hat tepisandin û Şêx Seîd heman salê li Amedê hat darvekirin.'),
  ('a1f9f20b-0554-5687-9664-e06b387ff657', 'offline_7151', 'explanation_ku', '"Mîrgeha Babanê": mîrnişîna kurd a bihêz a bi navenda Silêmaniyê.', 'Mîrgeha Babanê mîrgeheke kurd a bihêz bû ku navenda wê Silêmanî bû; bajar di 1784an de ji aliyê Babaniyan ve hat avakirin.'),
  ('06d3f7a1-e623-5400-a584-b08308cb429d', 'offline_7223', 'explanation_ku', '"Peymana Qesrişîrînê": peymana ku sînorê Osmanî û Sefewiyan diyar kir.', 'Peymana Qesrişîrînê (1639) sînorê Osmanî û Sefewiyan rêk xist û parvekirina herêmên kurdan di navbera du dewletan de bi giranî xurt kir.'),
  ('ae03650d-527b-5848-867f-cffc9187f457', 'offline_7249', 'explanation_ku', '"Şêx Mehmûdê Berzencî": rêberê ku li Iraqê xwe wek padîşahê Kurdistanê ragihand.', 'Şêx Mehmûdê Berzencî di salên 1920î de li Silêmaniyê xwe wekî padîşahê Kurdistanê ragihand û li dijî rêveberiya Brîtanî li ber xwe da.'),
  ('51cf256f-3581-5fcb-9f08-0229341c4780', 'offline_7300', 'explanation_ku', '"Mela Mehmûdê Bazîdî": lêkolînerê yekem ê ku adet û kevneşopiyên kurdan berhev kir.', 'Mela Mehmûdê Bazîdî di sedsala 19an de berhema pêşeng a ku adet û kevneşopiyên kurdan bi kurdî berhev dike amade kir; xebat bi teşwîqa dîplomatê rûs Aleksandr Jaba hat nivîsandin.'),
  ('1a22fe3e-1366-5098-8d04-798bc1e8e936', 'offline_7417', 'explanation_ku', '"şîroveya dîrokî": derxistina wateyê ji delîlan.', 'Şîroveya dîrokî berhevkirina delîlên çavkaniyan û derxistina wate û encaman ji wan e; tenê rêzkirina bûyeran ne şîrove ye.'),
  ('cc708a55-98ca-53f1-b6c8-208f802c7df6', 'offline_7474', 'explanation', '"dîroka devkî": rêbaza têgihiştina rabirdûyê bi şahidî û vegotinan.', 'Dîroka devkî rabirdûyê bi şahidiyên devkî yên kesên ku ew bûyer jiyane an bihîstine lêkolîn dike; ev şahidî bi belgeyên nivîskî û çavkaniyên din re tên nirxandin.'),
  ('cc708a55-98ca-53f1-b6c8-208f802c7df6', 'offline_7474', 'explanation_ku', '"dîroka devkî": rêbaza têgihiştina rabirdûyê bi şahidî û vegotinan.', 'Dîroka devkî rabirdûyê bi şahidiyên devkî yên kesên ku ew bûyer jiyane an bihîstine lêkolîn dike; ev şahidî bi belgeyên nivîskî û çavkaniyên din re tên nirxandin.'),
  ('8614c98b-9514-5398-9501-ba79056f87e4', 'offline_7497', 'explanation_ku', '"Mistefa Barzanî": rêberê leşkerî û siyasî yê navdar ê tevgera kurdî.', 'Mistefa Barzanî (1903–1979) bi salan serokatiya leşkerî û siyasî ya tevgera kurdî li Başûrê Kurdistanê kir; di artêşa Komara Mehabadê de jî fermandar bû.'),
  ('5c89b78c-9abb-51c9-b8f7-2d05f939e98b', 'offline_7507', 'explanation_ku', '"koçberî": guhertina cihê jiyanê ya komên mirovan.', 'Koçberî guhertina cihê jiyanê ya komên mirovan e ji ber sedemên wekî şer, debar an zordarî; dikare demkî an mayînde be.'),
  ('43d87741-9576-5920-ad2e-10a58a68ce2d', 'offline_7605', 'explanation_ku', '"çavkaniya seretayî": belge an tiştê ku ji wê serdemê maye.', 'Çavkaniya seretayî çavkaniyek e ku rasterast li ser mijara lêkolînê şahidiyê dike an daneyên resen pêşkêş dike; belge, tişt û vegotinên şahidên wê serdemê mînakên wê ne.'),
  ('f580690b-21d1-5b8a-9f80-4e1778aeb76f', 'offline_7643', 'explanation_ku', '"Mîqdat Mîdhad Bedirxan": rojnamevanê kurd ê yekem ê ku rojnameya Kurdistan derxist.', 'Miqdad Midhad Bedirxan rojnameya kurdî ya yekem, Kurdistan, di 22ê Nîsana 1898an de li Qahîreyê derxist; ev roj wekî roja rojnamegeriya kurdî tê bibîranîn.'),
  ('c6a33f83-73cc-52e7-ab5f-a1440cc5d626', 'offline_7763', 'explanation_ku', '"Mîrgeha Botan": mîrnişîna kurd a girîng a bi navenda Cizîrê.', 'Navenda Mîrgeha Botan Cizîr bû (Cizîra Botan); mîrê wê yê mezin ê dawî, Bedirxan Beg, di 1847an de li hember Osmaniyan têk çû.'),
  ('4cbea941-2a07-5c24-8b0b-7576468bc76a', 'offline_7798', 'explanation_ku', '"Îhsan Nûrî Paşa": efserê ku ji bo Xoybûnê rêberiya leşkerî kir.', 'Îhsan Nûrî Paşa fermandarê leşkerî yê serhildana Agiriyê (1927–1930) bû ku komeleya Xoybûnê piştgirî dida.'),
  ('ba592679-02c6-5cc1-818b-22f10dcdca19', 'offline_7852', 'explanation_ku', '"Kovara Hawarê": kovara kurdî ya yekem a ku bi tîpên latînî hat çapkirin.', 'Kovara Hawarê di 1932an de li Şamê ji aliyê Celadet Alî Bedirxan ve hat derxistin; alfabeya kurmancî ya bi tîpên latînî belav kir.'),
  ('275b9299-3d48-591a-9ea6-492bc702f907', 'offline_7905', 'explanation_ku', '"Operasyona Enfalê": jenosîda ku rejîma Iraqê li dijî kurdan pêk anî.', 'Enfal kampanyaya rejîma Baasê ya Iraqê ye ku di 1988an de li dijî kurdan meşand; gund hatin wêrankirin û bi deh hezaran mirov hatin kuştin. Gelek welat û sazî wê wekî jenosîd nas dikin.'),
  ('c362c08b-fe14-517f-8250-4cab07423e09', 'offline_8023', 'explanation_ku', '"Heskîf": bajarê dîrokî yê hezaran salî yê li ser çemê Dîcleyê.', 'Heskîf bajarekî pir kevnar e li ser Dîcleyê ku bi şikeftên di zinaran de kolayî tê naskirin; di 2020an de ava Bendava Ilisûyê piraniya bajarê kevn binav kir.'),
  ('181dcca2-6fa9-5d45-8b2c-3c46c4cedb88', 'offline_8141', 'explanation_ku', '"Gola Derbendîxanê": bendava ku li ser çemê Diyalayê hatiye avakirin.', 'Gola Derbendîxanê gola çêkirî ye ku bendava li ser Çemê Diyala (Sîrwan) çêkiriye; ne gola xwezayî ye.'),
  ('3ac95f40-e4d2-509a-ac6b-2316aaafff60', 'offline_8200', 'explanation_ku', '"Deşta Sêwregê": deşta kevirî ya ku ji lavên Karacadaxê pêk hatiye.', 'Deşta Sêwregê deşteke kevirî ye ku lavên bazaltî yên Qerejdaxê ew nixumandiye; loma axa wê bi kevir e.'),
  ('d5fef95b-da03-593d-80fb-c7853af3eaa1', 'offline_8255', 'explanation_ku', '"Rêzeçiyayên Zagrosê": çiyayên ku erdnîgariya Kurdistanê ji serî heta binî dabeş dikin.', 'Rêzeçiyayên Zagrosê ji bakurê rojava ber bi başûrê rojhilat ve dirêj dibin û stûna erdnîgariya Kurdistanê pêk tînin.'),
  ('366222d8-55ed-53e3-ab3a-98012fece2e6', 'offline_8384', 'explanation_ku', '"Deşta Hewlêrê": deşta çandiniyê ya herî berdar a başûrê Kurdistanê.', 'Deşta Hewlêrê deşteke berdar e ku di navbera Zapa Mezin û Zapa Biçûk de ye; bi çandiniya dexlê tê naskirin.'),
  ('c33e360d-6b01-535b-9d45-cc6a5899f8f8', 'offline_8480', 'explanation_ku', '"Qerejdax": volkana bazaltî ya berfireh a li deşta Amedê ye.', 'Qerejdax volkaneke mertalî ya fireh û nizm e ku di navbera Amed û Rihayê de belav dibe; kevirên bazaltî yên derdora wê di sûrên Amedê de jî hatine bikaranîn.'),
  ('bc8f62d2-023f-5ff9-9866-269807506092', 'offline_8523', 'explanation_ku', '"Çemê Dîcleyê": çemê ku ji binê sûrên Amedê derbas dibe.', 'Dîcle di newala binê sûrên dîrokî yên Amedê re diherike; Baxçeyên Hewselê di navbera sûran û çem de ne.'),
  ('cc221d3b-f542-54d4-9969-69e9d9df2f36', 'offline_8532', 'explanation_ku', '"Gola Dokanê": bendava çêkirî ya li nêzîkî Silêmaniyê.', 'Gola Dokanê gola çêkirî ye ku bendava li ser Zapa Biçûk çêkiriye û girêdayî parêzgeha Silêmaniyê ye.'),
  ('85e345da-da12-5082-90cc-cced11451cb9', 'offline_8539', 'explanation_ku', '"Avhewaya Kurdistanê": li deverên parzemînî û çiyayî zivistanên sar.', 'Li piraniya Kurdistanê avhewaya parzemînî serdest e: ji ber bilindahî û dûrbûna ji deryayê zivistan sar û bi berf, havîn germ û hişk derbas dibin.'),
  ('41665ecf-07e3-5ff9-8e6d-aa347103af83', 'offline_8603', 'explanation_ku', '"Gola Hazarê": gola tektonîk a li herêma Elezîzê.', 'Gola Hazarê gola tektonîk e ku li Elezîzê li ser Xeta Şikesta Anatoliya Rojhilat çêbûye; Dîcle ji derdora vê golê derdikeve.'),
  ('eea6815d-efe3-564d-a823-173738e4f778', 'offline_8950', 'explanation_ku', '"Gola Dokanê": bendava çêkirî ya li nêzîkî Silêmaniyê.', 'Gola Dokanê bi Bendava Dokanê ya li ser Zapa Biçûk çêbûye û gola çêkirî ye; nêzîkî Silêmaniyê ye.'),
  ('2fe04d59-bcbe-523a-bf78-61f211522280', 'offline_9132', 'explanation_ku', '"Çemê Xabûrê": şaxê Dîcleyê yê ku sînorê Tirkiye û Iraqê diyar dike.', 'Çemê Xabûrê şaxekî Dîcleyê ye ku nêzîkî Zaxoyê derbas dibe û tevlî Dîcleyê dibe; beşek ji wî sînorê Tirkiye û Iraqê pêk tîne.'),
  ('3778b742-5722-5f4b-b6fc-c60c0fa3f570', 'offline_9207', 'explanation_ku', '"Kovara Ronahî": kovara wêjeyî ya ku li Şamê bi tîpên latînî derket.', 'Kovara Ronahî di navbera 1942 û 1945an de li Şamê ji aliyê Celadet Alî Bedirxan ve hat derxistin; weşana xwişk a Hawarê bû û bi wêne bû.'),
  ('5f0a48c4-22df-58a6-985e-971081806482', 'offline_9227', 'explanation_ku', '"Cegerxwîn": helbestvanê civakî yê pêşeng ê helbesta kurdî ya modern.', 'Cegerxwîn (1903–1984) bi sûdwergirtina ji şêweyên klasîk jî di helbesta xwe de jiyana gel, mafên civakî û azadî anî ziman; yek ji pêşengên helbesta kurdî ya civakî ya nûjen tê hesibandin.'),
  ('ff6ea5ed-7d02-518c-8737-82c3e09423ba', 'offline_9410', 'explanation_ku', '"Destana Memê Alan": destana gelêrî ya ku Ehmedê Xanî ji bo Mem û Zînê jê îlham girtiye.', 'Memê Alan destaneke gelêrî ya devkî ye; Ehmedê Xanî di mesnewiya Mem û Zînê ya ku di 1692an de nivîsî de ji vê vegotinê sûd wergirt.'),
  ('c2532d7c-87e6-56a9-899f-53defea20d83', 'offline_9434', 'explanation_ku', '"Rojnameya Riya Taza": rojnameya kurdî ya ku bi salan li Rewanê hat çapkirin.', 'Riya Teze rojnameya kurdî ye ku di 1930an de li Rewanê dest bi weşanê kir; piştî ku weşana wê demekê sekinî, di 1955an de ji nû ve dest pê kir.'),
  ('ba2759a3-1e8f-58a5-9b65-7c675166802a', 'offline_9552', 'explanation_ku', '"Mestûre Erdelan": dîroknas û helbestvana kurd a yekem a ku dîwan nivîsandiye.', 'Mestûre Erdelan (1805–1848) dîroka Mîrgeha Erdelanê nivîsî û helbestên xwe di dîwanekê de kom kirin; wekî dîroknasa kurd a jin a yekem tê bibîranîn.'),
  ('1512d71a-288b-5a23-80db-3b6968d2c79c', 'offline_9594', 'explanation_ku', '"Nûbihara Biçûkan": ferhenga kurdî ya yekem a ku Ehmedê Xanî nivîsî.', 'Nûbihara Biçûkan ferhenga erebî–kurdî ya bi helbest e ku Ehmedê Xanî ji bo hînbûna erebî ya zarokan nivîsî; peyv di beytên ji bo jiberkirinê de tên dayîn.'),
  ('421bf996-e228-5b7e-b029-32378213f3e5', 'offline_9625', 'explanation_ku', '"Osman Sebrî": yek ji navên damezrîner ên çîroknivîsiya kurdî ya modern.', 'Osman Sebrî (1905–1993) nivîskar û helbestvanekî derdora Hawarê ye; yek ji navên damezrîner ên çîroknivîsiya kurdî ya nûjen tê hesibandin.'),
  ('8d92ec5b-8537-5cf0-99ad-fda48ab582e3', 'offline_9724', 'explanation_ku', '"Ekola Hawarê": tevgera wêjeyî ya ku ronakbîriya kurdî û alfabeya latînî belav kir.', 'Ekola Hawarê di salên 1930–40î de li derdora birayên Bedirxan pêş ket; zimanê nivîskî yê kurmancî yê bi tîpên latînî û ronakbîriya kurdî belav kir.'),
  ('c50304aa-5a2e-573f-b066-16598ca81a59', 'offline_9778', 'explanation_ku', '"Nalî": helbestvanê dîwanê yê herî mezin ê ekola klasîk a soranî.', 'Nalî helbestvanê dîwanê ye ku di sedsala 19an de, di serdema Mîrgeha Babanê de bi soranî nivîsî; yek ji navên damezrîner ên helbesta klasîk a soranî tê hesibandin.'),
  ('4343de02-d742-5b98-81a5-a309e00d0d0f', 'offline_10074', 'explanation_ku', '"Dîwana Melayê Cizîrî": dîwana helbestê ya navdar a bi evîna mîstîk û felsefeyê.', 'Dîwana Melayê Cizîrî evîna tesewifî û ramana felsefî dike mijar; yek ji berhemên helbesta kurmancî ya klasîk e ku herî zêde tên xwendin.'),
  ('b6180e9e-1460-56fd-b07f-409fcd93dc3c', 'offline_10314', 'explanation_ku', '"awazên Serhedê": şêwaza muzîka lîrîk a taybetî ya devera Qers, Agirî û Wanê.', 'Awazên Serhedê ji devera Qers, Agirî û Wanê tên; bi gotina dengbêjiyê ya lîrîk û bêhnfireh tên naskirin.'),
  ('11a79256-9ebb-5b2a-8cf5-10c39409d74b', 'offline_10320', 'explanation_ku', '"dibistana dengbêjiyê": veguhastina muzîkî ya bi têkiliya hoste-şagirt.', 'Dengbêjî bi têkiliya hoste-şagirt tê hînbûn: dengbêjê ciwan guh dide hosteyê xwe, kilaman jiber dike û şêwaza wî didomîne.'),
  ('65970ee9-2dfb-524e-b130-61cff68f505f', 'offline_10379', 'explanation_ku', '"meqam": pergala ku avahiya awazê diyar dike.', 'Meqam pergala rêz û qaîdeyan e ku diyar dike awaz ji kîjan dengan ava dibe û çawa pêş ve diçe; ne rîtmê, awazê birêk dixe.'),
  ('e7333f15-0ae5-594e-b3be-366230238b4b', 'offline_10423', 'explanation_ku', '"tembûr": amûra têlî ya ku di muzîka gelêrî ya kurdî de herî pîroz tê hesibandin.', 'Tembûr amûreke têldar a destikdirêj e; di baweriya Yarsanê (Ehlê Heq) de pîroz tê hesibandin û di merasîmên cemê de tê lêdan.'),
  ('5840fb72-4df1-5971-9170-8c40a337bf2b', 'offline_10480', 'explanation_ku', '"awazên Botanê": muzîka rîtmîk û meqamî ya devera Şirnex û Cizîrê.', 'Awazên Botanê aîdî devera Şirnex û Cizîrê ne; bi avahiya xwe ya rîtmîk û meqamî ji şêwazên deverên din cuda dibin.'),
  ('74f436dc-cd10-53f9-9655-c003f190d9dc', 'offline_10498', 'explanation_ku', '"Koma Amed": koma muzîkê ya alternatîf a ku di salên 90î de di muzîka kurdî de şoreş çêkir.', 'Koma Amed komeke muzîkê ya alternatîf e ku amûrên nûjen û sazkirinên nû anîn muzîka kurdî.'),
  ('199ad51d-6132-58a8-8436-49c6bedef930', 'offline_10566', 'explanation_ku', '"nota": nîşanên gerdûnî yên ku pê muzîk tê nivîsandin.', 'Nota pergala nîşanan e ku bilindahî û dirêjahiya dengan bi nivîsê nîşan dide; bi vî awayî awazek ji ser kaxezê tê xwendin û lêdan.'),
  ('4efa354e-b0f0-5425-b4f5-085c3713c393', 'offline_10572', 'explanation_ku', '"Hesen Cizrawî": dengbêjê ku tomarên muzîka kurdî yên serdema destpêkê çêkirin.', 'Hesen Cizrawî dengbêjekî ji Cizîrê ye ku bi salan di weşanên kurdî yên Radyoya Bexdayê de kilam gotin.'),
  ('1d460377-37ec-5152-baa9-9436757d7e35', 'offline_10813', 'explanation_ku', '"kevneşopiya şabaşê": edeta avêtina pereyan ji muzîkjenan re.', 'Şabaş kevneşopiya dayîna pere an diyariyan e di dawetan de; li gelek deveran baxşîşa ku ji muzîkjenan re tê dayîn jî digire nav xwe.'),
  ('59bfeddd-0c33-5014-9534-3dfbbe134c72', 'offline_10926', 'explanation_ku', '"Mihemed Şêxo": ozanê ku hestên neteweyî yên gelê kurd dianî ziman.', 'Mihemed Şêxo (1948–1989) hunermendekî ji Rojava ye; bi stranên xwe yên neteweyî û civakî yên bi tembûrê tê naskirin.'),
  ('40ee687a-2280-566d-b7c9-d3659cf5cde1', 'offline_11068', 'explanation_ku', '"awazên behdînî": şêwaza muzîkê ya taybetî ya devera Dihok û Zaxoyê.', 'Awazên behdînî taybetî derdora Dihok û Zaxoyê (Behdînan) ne; bi zarava û rîtmên xwe yên taybet tên naskirin.'),
  ('1a33d5cf-9c5a-5047-9562-e1ef5f9bc716', 'offline_11136', 'explanation_ku', '"rîtm": lêdanên birêkûpêk ên ku bingeha muzîkê pêk tînin.', 'Rîtm di muzîkê de ji aliyê dem û giraniyê ve rêkxistina deng û bêdengiyan e; berevajî awazê, ne bilindahiya dengan lê dema wan diyar dike.'),
  ('9b118378-3bf5-58d1-8a3f-aaffb4706c67', 'offline_11294', 'explanation_ku', '"erbane": defa bi zengil a ku di muzîka gelêrî de belav tê lêxistin.', 'Erbane defeke mezin e ku zengil an xelek bi çarçoveya wê ve hatine girêdan; di civatên olî û muzîka gelêrî de ji bo rîtmê tê lêxistin.'),
  ('8b73c0ae-af0a-598f-9776-02fa29944ee7', 'offline_12899', 'explanation_ku', '"nenavendîbûn": belavkirina hêzê ji navendê ber bi yekîneyên herêmî ve.', 'Di nenavendîbûnê de beşek ji desthilata biryarê ji rêveberiya navendî tê veguhastin bo yekîneyên herêmî yên wekî parêzgeh, herêm û şaredariyan.'),
  ('e953efd8-6f54-5ea2-a72d-d61c0ece7c4a', 'offline_13040', 'explanation', '"azınlık hakları": parastina komên ku ji piraniyê cuda ne.', 'Mafên hindikahiyan armanc dikin ku ziman, ol û çanda komên kêmhejmar li hember piraniyê biparêzin.'),
  ('e953efd8-6f54-5ea2-a72d-d61c0ece7c4a', 'offline_13040', 'explanation_ku', '"azınlık hakları": parastina komên ku ji piraniyê cuda ne.', 'Mafên hindikahiyan armanc dikin ku ziman, ol û çanda komên kêmhejmar li hember piraniyê biparêzin.'),
  ('12ffd15e-531d-5f5d-9ae0-3031d7c4fd55', 'offline_13122', 'explanation', '"barış hakkı": mafê gerdûnî yê civakê yê jiyana bêyî şer.', 'Mafê aştiyê mafê kes û civakan e ku bêyî xetera şer û şîdetê bijîn; di nifşê "mafên piştevaniyê" yê mafên mirovan de tê hejmartin.'),
  ('12ffd15e-531d-5f5d-9ae0-3031d7c4fd55', 'offline_13122', 'explanation_ku', '"barış hakkı": mafê gerdûnî yê civakê yê jiyana bêyî şer.', 'Mafê aştiyê mafê kes û civakan e ku bêyî xetera şer û şîdetê bijîn; di nifşê "mafên piştevaniyê" yê mafên mirovan de tê hejmartin.'),
  ('51cd0509-a55f-543e-a98b-d1f1d69a354a', 'offline_13252', 'explanation', '"insan hakları": mafên gerdûnî yên ku her kes ji dayikbûnê xwedî wan e.', 'Mafên mirovan mafên gerdûnî ne ku her mirov ji dayikbûnê ve xwedî wan e, bêyî ku bi bexşandina kesekî ve girêdayî bin; Danezana Gerdûnî ya Mafên Mirovan (1948) wan dihejmêre.'),
  ('51cd0509-a55f-543e-a98b-d1f1d69a354a', 'offline_13252', 'explanation_ku', '"insan hakları": mafên gerdûnî yên ku her kes ji dayikbûnê xwedî wan e.', 'Mafên mirovan mafên gerdûnî ne ku her mirov ji dayikbûnê ve xwedî wan e, bêyî ku bi bexşandina kesekî ve girêdayî bin; Danezana Gerdûnî ya Mafên Mirovan (1948) wan dihejmêre.'),
  ('26f36d38-a675-5830-99bf-b37e4434dc00', 'offline_13729', 'explanation', '"müzakere": rêbaza çareserkirina pirsgirêkan bi rêya diyalogê.', 'Muzakere hewla aliyan e ku pirsgirêkan bêyî bikaranîna hêzê, bi danûstandin û lihevkirinê çareser bikin.'),
  ('26f36d38-a675-5830-99bf-b37e4434dc00', 'offline_13729', 'explanation_ku', '"müzakere": rêbaza çareserkirina pirsgirêkan bi rêya diyalogê.', 'Muzakere hewla aliyan e ku pirsgirêkan bêyî bikaranîna hêzê, bi danûstandin û lihevkirinê çareser bikin.'),
  ('c7eb5be1-0bb8-5f79-841a-d4eb05e710ce', 'offline_13745', 'explanation', '"çoğulculuk": qebûlkirina wekhev a nasname û baweriyên cuda.', 'Pirrengî diparêze ku nasname, bawerî û nêrînên cuda yên civakê bi hev re û bi wekhevî hebin.'),
  ('c7eb5be1-0bb8-5f79-841a-d4eb05e710ce', 'offline_13745', 'explanation_ku', '"çoğulculuk": qebûlkirina wekhev a nasname û baweriyên cuda.', 'Pirrengî diparêze ku nasname, bawerî û nêrînên cuda yên civakê bi hev re û bi wekhevî hebin.'),
  ('4374f3ad-1c34-5e95-b4bc-408be1df17d9', 'offline_curated_20001', 'explanation', '"ergatîf" tê vê wateyê: avahiya rêzimanî ya ku kirdeya lêkerên gerguhêz di dema borî de tewandî nîşan dide.', 'Di avahiya ergatîf de kirdeya lêkera gerguhêz di dema borî de tewandî ye: di hevoka "Min nan xwar" de kirde ne "ez", "min" e.'),
  ('4374f3ad-1c34-5e95-b4bc-408be1df17d9', 'offline_curated_20001', 'explanation_ku', '"ergatîf" tê vê wateyê: avahiya rêzimanî ya ku kirdeya lêkerên gerguhêz di dema borî de tewandî nîşan dide.', 'Di avahiya ergatîf de kirdeya lêkera gerguhêz di dema borî de tewandî ye: di hevoka "Min nan xwar" de kirde ne "ez", "min" e.'),
  ('9acbc43f-b9d9-585e-8e54-eae85a2dfde6', 'offline_curated_20026', 'explanation', '"tewandin" tê vê wateyê: guhertina paşgira navdêr an cînavkan li gorî rola wan a di hevokê de.', 'Tewandin guhertina şeklê navdêr û cînavkan e li gorî rola wan di hevokê de: "ez" bi tewandinê dibe "min", "jin" jî dibe "jinê".'),
  ('9acbc43f-b9d9-585e-8e54-eae85a2dfde6', 'offline_curated_20026', 'explanation_ku', '"tewandin" tê vê wateyê: guhertina paşgira navdêr an cînavkan li gorî rola wan a di hevokê de.', 'Tewandin guhertina şeklê navdêr û cînavkan e li gorî rola wan di hevokê de: "ez" bi tewandinê dibe "min", "jin" jî dibe "jinê".'),
  ('f9c06f28-dbe6-5d78-97e4-02d4b5949e98', 'offline_curated_20051', 'explanation', '"ezafe" tê vê wateyê: têkiliya veqetandeka mê (a) û nêr (ê) ya ku navdêran bi hev ve girê dide.', 'Veqetandek navdêrê bi peyva piştî xwe ve girê dide: di navdêrên mê de "-a" (mala min), di yên nêr de "-ê" (bavê min).'),
  ('f9c06f28-dbe6-5d78-97e4-02d4b5949e98', 'offline_curated_20051', 'explanation_ku', '"ezafe" tê vê wateyê: têkiliya veqetandeka mê (a) û nêr (ê) ya ku navdêran bi hev ve girê dide.', 'Veqetandek navdêrê bi peyva piştî xwe ve girê dide: di navdêrên mê de "-a" (mala min), di yên nêr de "-ê" (bavê min).'),
  ('38fbf109-6c46-570f-83ed-9e1125dc2beb', 'offline_curated_20076', 'explanation', '"cînavkên tewandî" tê vê wateyê: cînavkên wekî "min, te, wî, wê, me, we, wan" ku di bin tewandinê de ne.', 'Cînavkên tewandî (min, te, wî, wê, me, we, wan) di hevoka gerguhêz a dema niha de bireser, di ya dema borî de kirde ne: "Ez wî dibînim", "Min ew dît".'),
  ('38fbf109-6c46-570f-83ed-9e1125dc2beb', 'offline_curated_20076', 'explanation_ku', '"cînavkên tewandî" tê vê wateyê: cînavkên wekî "min, te, wî, wê, me, we, wan" ku di bin tewandinê de ne.', 'Cînavkên tewandî (min, te, wî, wê, me, we, wan) di hevoka gerguhêz a dema niha de bireser, di ya dema borî de kirde ne: "Ez wî dibînim", "Min ew dît".'),
  ('2b5cf310-88bb-5a54-a88b-d65c756d14bd', 'offline_curated_20126', 'explanation', '"lêkera gerguhêz" tê vê wateyê: lêkerên ku hewcedariya wan bi bireserê tewandî heye bo temamkirina wateyê.', 'Lêkerên gerguhêz dikarin bireser bigirin: bi "xwarin" dikare bê gotin ka çi tê xwarin ("Ez nan dixwim"); "hatin" jî negerguhêz e û bireser nagire.'),
  ('2b5cf310-88bb-5a54-a88b-d65c756d14bd', 'offline_curated_20126', 'explanation_ku', '"lêkera gerguhêz" tê vê wateyê: lêkerên ku hewcedariya wan bi bireserê tewandî heye bo temamkirina wateyê.', 'Lêkerên gerguhêz dikarin bireser bigirin: bi "xwarin" dikare bê gotin ka çi tê xwarin ("Ez nan dixwim"); "hatin" jî negerguhêz e û bireser nagire.'),
  ('b3d2fac6-10e1-5df6-8cd6-7bcf72f3ac9c', 'offline_curated_20151', 'explanation', '"rênivîsa Hawarê" tê vê wateyê: pergala alfabeya kurdî ya bi tîpên latînî ku ji aliyê Celadet Bedirxan ve hatibû amadekirin.', 'Rênivîsa Hawarê alfabeya kurmancî ya latînî ya 31 tîpî ye ku Celadet Alî Bedirxan di 1932an de bi kovara Hawarê belav kir; îro bi berfirehî tê bikaranîn.'),
  ('b3d2fac6-10e1-5df6-8cd6-7bcf72f3ac9c', 'offline_curated_20151', 'explanation_ku', '"rênivîsa Hawarê" tê vê wateyê: pergala alfabeya kurdî ya bi tîpên latînî ku ji aliyê Celadet Bedirxan ve hatibû amadekirin.', 'Rênivîsa Hawarê alfabeya kurmancî ya latînî ya 31 tîpî ye ku Celadet Alî Bedirxan di 1932an de bi kovara Hawarê belav kir; îro bi berfirehî tê bikaranîn.'),
  ('3a4274cb-5e1a-5101-b418-3c3ac192d9e1', 'offline_curated_20176', 'explanation', '"cînavkên kesane" tê vê wateyê: cînavkên wekî "ez, tu, ew, em, hûn, ew" ên ku bo kesan tên bikaranîn.', 'Cînavkên kesane (ez, tu, ew, em, hûn, ew) rewşa xwerû ya netewandî ne; di dema niha de wekî kirde tên bikaranîn: "Ez diçim".'),
  ('3a4274cb-5e1a-5101-b418-3c3ac192d9e1', 'offline_curated_20176', 'explanation_ku', '"cînavkên kesane" tê vê wateyê: cînavkên wekî "ez, tu, ew, em, hûn, ew" ên ku bo kesan tên bikaranîn.', 'Cînavkên kesane (ez, tu, ew, em, hûn, ew) rewşa xwerû ya netewandî ne; di dema niha de wekî kirde tên bikaranîn: "Ez diçim".'),
  ('561527f4-5679-5fe3-83c2-ff90010d2b87', 'offline_curated_20201', 'explanation', '"dema borî ya dûr" tê vê wateyê: avahiya lêkerê ya ku kiryarek berî kiryareke din a rabirdûyê qediyaye nîşan dide.', 'Dema borî ya dûr kiryareke ku berî kiryareke din a rabirdûyê temam bûye vedibêje: "Ez hatibûm", "Min xwaribû".'),
  ('561527f4-5679-5fe3-83c2-ff90010d2b87', 'offline_curated_20201', 'explanation_ku', '"dema borî ya dûr" tê vê wateyê: avahiya lêkerê ya ku kiryarek berî kiryareke din a rabirdûyê qediyaye nîşan dide.', 'Dema borî ya dûr kiryareke ku berî kiryareke din a rabirdûyê temam bûye vedibêje: "Ez hatibûm", "Min xwaribû".'),
  ('508123b7-3a59-5da3-97d5-4e5567c80bc4', 'offline_curated_20226', 'explanation', '"paşgirên tewandinê" tê vê wateyê: hêmanên wekî "-î, -ê, -an" ku di tewandina navdêran de cih digirin.', 'Paşgirên tewandinê li gorî rola navdêrê tên zêdekirin: di nêrê yekjimar de "-î" (mêrî), di mêya yekjimar de "-ê" (jinê), di pirjimar de "-an" (zarokan).'),
  ('508123b7-3a59-5da3-97d5-4e5567c80bc4', 'offline_curated_20226', 'explanation_ku', '"paşgirên tewandinê" tê vê wateyê: hêmanên wekî "-î, -ê, -an" ku di tewandina navdêran de cih digirin.', 'Paşgirên tewandinê li gorî rola navdêrê tên zêdekirin: di nêrê yekjimar de "-î" (mêrî), di mêya yekjimar de "-ê" (jinê), di pirjimar de "-an" (zarokan).'),
  ('d5d1dc8d-428e-5d48-865f-1693c1ce35ed', 'offline_curated_20251', 'explanation', '"Melayê Cizîrî" tê vê wateyê: helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin.', 'Melayê Cizîrî (sedsala 16–17an) helbestvanê kurmancî yê klasîk e ku di dîwana xwe de evîna tesewifî û ramana felsefî dihûne; li Cizîrê jiyaye.'),
  ('d5d1dc8d-428e-5d48-865f-1693c1ce35ed', 'offline_curated_20251', 'explanation_ku', '"Melayê Cizîrî" tê vê wateyê: helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin.', 'Melayê Cizîrî (sedsala 16–17an) helbestvanê kurmancî yê klasîk e ku di dîwana xwe de evîna tesewifî û ramana felsefî dihûne; li Cizîrê jiyaye.'),
  ('cec40864-20c2-5066-90b8-c844e70fe42a', 'offline_curated_20276', 'explanation_ku', '"Feqiyê Teyran" tê vê wateyê: helbestvanê klasîk ê ku bi berhema "Şêx Sen"an'' û axaftina bi çûkan re navdar e.', 'Navê Feqiyê Teyran ji efsaneya axaftina wî bi teyran re tê; bi çîroka xwe ya bi helbest "Şêx Sen''an" tê naskirin.'),
  ('89461275-3ebd-58bb-b783-6b4bc39f993b', 'offline_curated_20326', 'explanation', '"Melayê Bateyî" tê vê wateyê: helbestvanê ku Mewlûda Kurdî ya yekem bi zaravayê kurmancî nivîsiye.', 'Melayê Bateyî bi Mewlûda Kurdî ya ku bi kurmancî nivîsî tê naskirin; ev mewlûd îro jî di civatên olî de tê xwendin. Li ser serdema jiyana wî nêrînên cuda hene.'),
  ('89461275-3ebd-58bb-b783-6b4bc39f993b', 'offline_curated_20326', 'explanation_ku', '"Melayê Bateyî" tê vê wateyê: helbestvanê ku Mewlûda Kurdî ya yekem bi zaravayê kurmancî nivîsiye.', 'Melayê Bateyî bi Mewlûda Kurdî ya ku bi kurmancî nivîsî tê naskirin; ev mewlûd îro jî di civatên olî de tê xwendin. Li ser serdema jiyana wî nêrînên cuda hene.'),
  ('86d45d6f-a690-58df-93ed-b0557ab297a5', 'offline_curated_20375', 'explanation', '"Cegerxwîn" tê vê wateyê: helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû.', 'Cegerxwîn her çend şêweyên klasîk bi kar anî jî, mijara helbestê ji tesewifê ber bi xizanî, maf û azadiya gel ve guhert.'),
  ('86d45d6f-a690-58df-93ed-b0557ab297a5', 'offline_curated_20375', 'explanation_ku', '"Cegerxwîn" tê vê wateyê: helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû.', 'Cegerxwîn her çend şêweyên klasîk bi kar anî jî, mijara helbestê ji tesewifê ber bi xizanî, maf û azadiya gel ve guhert.'),
  ('3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808', 'offline_curated_20426', 'explanation', '"Mehmed Uzun" tê vê wateyê: romannivîsê kurd ê modern ku bi zimanekî kûr û edebî şoreşek di romana kurdî de çêkir.', 'Mehmed Uzun (1953–2007) bi romanên wekî "Siya Evînê" û "Bîra Qederê" romana kurmancî ji aliyê ziman û kûrahiya edebî ve gihand asteke nû.'),
  ('3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808', 'offline_curated_20426', 'explanation_ku', '"Mehmed Uzun" tê vê wateyê: romannivîsê kurd ê modern ku bi zimanekî kûr û edebî şoreşek di romana kurdî de çêkir.', 'Mehmed Uzun (1953–2007) bi romanên wekî "Siya Evînê" û "Bîra Qederê" romana kurmancî ji aliyê ziman û kûrahiya edebî ve gihand asteke nû.'),
  ('e2383ed2-23aa-56f5-b7ce-60e7a686af4c', 'offline_curated_20451', 'explanation', '"şevbêrkên wêjeyî" tê vê wateyê: civînên şevê yên ku tê de helbest û çîrokên klasîk û modern dihatin xwendin.', 'Şevbêrkên wêjeyî civînên şevên zivistanê ne ku tê de helbest û çîrokên klasîk û nûjen tên xwendin; cihên veguhastina edebiyata devkî ne.'),
  ('e2383ed2-23aa-56f5-b7ce-60e7a686af4c', 'offline_curated_20451', 'explanation_ku', '"şevbêrkên wêjeyî" tê vê wateyê: civînên şevê yên ku tê de helbest û çîrokên klasîk û modern dihatin xwendin.', 'Şevbêrkên wêjeyî civînên şevên zivistanê ne ku tê de helbest û çîrokên klasîk û nûjen tên xwendin; cihên veguhastina edebiyata devkî ne.'),
  ('d8c3d439-b1cc-5988-8d8b-368611243b0c', 'offline_curated_20476', 'explanation', '"Helbesta Azad" tê vê wateyê: rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dide.', 'Helbesta Azad mecbûriya pîvan û serwayê radike; serwa dikare bê bikaranîn lê ne şert e, wate û bandor bi hilbijartina peyvan ava dibin.'),
  ('d8c3d439-b1cc-5988-8d8b-368611243b0c', 'offline_curated_20476', 'explanation_ku', '"Helbesta Azad" tê vê wateyê: rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dide.', 'Helbesta Azad mecbûriya pîvan û serwayê radike; serwa dikare bê bikaranîn lê ne şert e, wate û bandor bi hilbijartina peyvan ava dibin.'),
  ('e0a361e9-03d5-53f1-8590-b2d2b4226d66', 'offline_curated_20501', 'explanation', '"Împaratoriya Medî" tê vê wateyê: hêza mezin a kevnar a li Zagrosê ku di hin vegotinên kurdî de bi kalan ve girêdayî ye.', 'Medan di sedsala 7–6an a berî zayînê de împaratoriyeke bi navenda Zagrosê ava kir; hin vegotinên dîroka kurdî koka kurdan bi Medan ve girê didin.'),
  ('e0a361e9-03d5-53f1-8590-b2d2b4226d66', 'offline_curated_20501', 'explanation_ku', '"Împaratoriya Medî" tê vê wateyê: hêza mezin a kevnar a li Zagrosê ku di hin vegotinên kurdî de bi kalan ve girêdayî ye.', 'Medan di sedsala 7–6an a berî zayînê de împaratoriyeke bi navenda Zagrosê ava kir; hin vegotinên dîroka kurdî koka kurdan bi Medan ve girê didin.'),
  ('cf1d8cee-f9c5-5683-bb7e-8683c546db06', 'offline_curated_20526', 'explanation', '"Dewleta Merwaniyan" tê vê wateyê: xanedaniya kurdî ya serdema navîn ku navenda wê Amed û derdorên wê bûn.', 'Merwanî xanedaniya kurd a serdema navîn e ku ji dawiya sedsala 10an heta 1085an li derdora Amed û Farqînê (Silvan) hukum kir.'),
  ('cf1d8cee-f9c5-5683-bb7e-8683c546db06', 'offline_curated_20526', 'explanation_ku', '"Dewleta Merwaniyan" tê vê wateyê: xanedaniya kurdî ya serdema navîn ku navenda wê Amed û derdorên wê bûn.', 'Merwanî xanedaniya kurd a serdema navîn e ku ji dawiya sedsala 10an heta 1085an li derdora Amed û Farqînê (Silvan) hukum kir.'),
  ('566fc3c0-6b02-5384-9876-6ec99961c911', 'offline_curated_20625', 'explanation', '"Selaheddînê Eyûbî" tê vê wateyê: serokê mezin ê kurd ku Quds ji xaçperestan rizgar kir û xanedaniya Eyûbiyan ava kir.', 'Selaheddînê Eyûbî yê bi eslê xwe kurd di 1171an de bingeha rêveberiya Eyûbiyan danî; di 1187an de piştî serkeftina Hittînê Quds ji Xaçparêzan girt.'),
  ('566fc3c0-6b02-5384-9876-6ec99961c911', 'offline_curated_20625', 'explanation_ku', '"Selaheddînê Eyûbî" tê vê wateyê: serokê mezin ê kurd ku Quds ji xaçperestan rizgar kir û xanedaniya Eyûbiyan ava kir.', 'Selaheddînê Eyûbî yê bi eslê xwe kurd di 1171an de bingeha rêveberiya Eyûbiyan danî; di 1187an de piştî serkeftina Hittînê Quds ji Xaçparêzan girt.'),
  ('a97da665-c2f8-5802-a724-f3b2b8928578', 'offline_curated_20679', 'explanation_ku', '"Rojnameya Kurdistan": rojnameya kurdî ya yekem ku di 1898an de li Qahîreyê ji aliyê Mîqdat Mîdhad Bedirxan ve derket.', 'Rojnameya Kurdistan di 22ê Nîsana 1898an de li Qahîreyê ji aliyê Miqdad Midhad Bedirxan ve hate weşandin; ji ber ku rojnameya kurdî ya yekem e, ev roj roja rojnamegeriya kurdî tê hesibandin.'),
  ('11637dbd-8ca6-541f-b8b6-783aaa304c72', 'offline_curated_20701', 'explanation', '"Mîrgeha Erdelanê" tê vê wateyê: mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû.', 'Navenda Mîrgeha Erdelanê Sine (Sanandaj) bû; mîrgeheke Rojhilatê Kurdistanê bû ku bi sedsalan dom kir û Mestûre Erdelan dîroka wê nivîsî.'),
  ('11637dbd-8ca6-541f-b8b6-783aaa304c72', 'offline_curated_20701', 'explanation_ku', '"Mîrgeha Erdelanê" tê vê wateyê: mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû.', 'Navenda Mîrgeha Erdelanê Sine (Sanandaj) bû; mîrgeheke Rojhilatê Kurdistanê bû ku bi sedsalan dom kir û Mestûre Erdelan dîroka wê nivîsî.'),
  ('b6d66019-4aad-59dd-b116-a42bef42c3a4', 'offline_curated_20750', 'explanation', '"çiyayên Zagrosê" tê vê wateyê: rêzeçiyayên mezin û asê yên ku sînorê xwezayî yê welatê kurdan pêk tînin.', 'Çiyayên Zagrosê rêzeçiyayekî asê ye ku ji bakurê rojava ber bi başûrê rojhilat ve dirêj dibe; yek ji sînorên xwezayî û stûnên erdnîgariya kurdan e.'),
  ('b6d66019-4aad-59dd-b116-a42bef42c3a4', 'offline_curated_20750', 'explanation_ku', '"çiyayên Zagrosê" tê vê wateyê: rêzeçiyayên mezin û asê yên ku sînorê xwezayî yê welatê kurdan pêk tînin.', 'Çiyayên Zagrosê rêzeçiyayekî asê ye ku ji bakurê rojava ber bi başûrê rojhilat ve dirêj dibe; yek ji sînorên xwezayî û stûnên erdnîgariya kurdan e.'),
  ('1e1d5a70-f478-502d-9121-5d4f129a573a', 'offline_curated_20826', 'explanation', '"Çiyayê Cûdî" tê vê wateyê: çiyayê pîroz ê ku li gorî baweriyan keştiya Nûh Pêxember li ser rûniştiye.', 'Çiyayê Cûdî li Şirnexê ye; di kevneşopiya îslamî û hin çavkaniyên kevn de wekî cihê ku keştiya Nûh lê rûniştiye tê bibîranîn.'),
  ('1e1d5a70-f478-502d-9121-5d4f129a573a', 'offline_curated_20826', 'explanation_ku', '"Çiyayê Cûdî" tê vê wateyê: çiyayê pîroz ê ku li gorî baweriyan keştiya Nûh Pêxember li ser rûniştiye.', 'Çiyayê Cûdî li Şirnexê ye; di kevneşopiya îslamî û hin çavkaniyên kevn de wekî cihê ku keştiya Nûh lê rûniştiye tê bibîranîn.'),
  ('13f09861-251b-5ac7-8edd-b8c74a5c17a1', 'offline_curated_20851', 'explanation', '"Girê Mirazan" tê vê wateyê: şûna herî kevn a perestgehên mirovahiyê ku li nêzîkî bajarê Rihayê ye.', 'Girê Mirazan (Göbeklitepe) qadeke Neolîtîk e li nêzîkî Rihayê ku bi avahiyên xwe yên abîdeyî yên nêzîkî 11.600 salî tê naskirin; avahî bi karên merasîmî re tên girêdan û ji avahiyên perestgehan ên herî kevn ên naskirî tên hesibandin.'),
  ('13f09861-251b-5ac7-8edd-b8c74a5c17a1', 'offline_curated_20851', 'explanation_ku', '"Girê Mirazan" tê vê wateyê: şûna herî kevn a perestgehên mirovahiyê ku li nêzîkî bajarê Rihayê ye.', 'Girê Mirazan (Göbeklitepe) qadeke Neolîtîk e li nêzîkî Rihayê ku bi avahiyên xwe yên abîdeyî yên nêzîkî 11.600 salî tê naskirin; avahî bi karên merasîmî re tên girêdan û ji avahiyên perestgehan ên herî kevn ên naskirî tên hesibandin.'),
  ('34705932-2632-59da-a12f-aca9f2087b8a', 'offline_curated_20901', 'explanation', '"Çiyayê Sîpanê" tê vê wateyê: çiyayê volkanîk ê bilind û berfîn ê li bakurê Gola Wanê.', 'Çiyayê Sîpanê volkaneke vemirî ye ku li perava bakur a Gola Wanê bilind dibe; yek ji çiyayên herî bilind ên Tirkiyeyê ye.'),
  ('34705932-2632-59da-a12f-aca9f2087b8a', 'offline_curated_20901', 'explanation_ku', '"Çiyayê Sîpanê" tê vê wateyê: çiyayê volkanîk ê bilind û berfîn ê li bakurê Gola Wanê.', 'Çiyayê Sîpanê volkaneke vemirî ye ku li perava bakur a Gola Wanê bilind dibe; yek ji çiyayên herî bilind ên Tirkiyeyê ye.'),
  ('f97a2f0c-70ac-53db-9565-7d29204ca7ce', 'offline_curated_20926', 'explanation', '"Geliyê Zapê" tê vê wateyê: geliyê kûr û teng ê ku ava Zapê ya hov tê re diherike ber bi başûr ve.', 'Geliyê Zapê geliyekî kûr û teng e ku Zapa Mezin a ku ji çiyayên Colemêrgê ber bi başûr ve diherike ew vekiriye; Zap di dawiyê de tevlî Dîcleyê dibe.'),
  ('f97a2f0c-70ac-53db-9565-7d29204ca7ce', 'offline_curated_20926', 'explanation_ku', '"Geliyê Zapê" tê vê wateyê: geliyê kûr û teng ê ku ava Zapê ya hov tê re diherike ber bi başûr ve.', 'Geliyê Zapê geliyekî kûr û teng e ku Zapa Mezin a ku ji çiyayên Colemêrgê ber bi başûr ve diherike ew vekiriye; Zap di dawiyê de tevlî Dîcleyê dibe.'),
  ('bac807de-18f9-55ab-9d60-d74dbf95b631', 'offline_curated_20951', 'explanation', '"Heskîf" tê vê wateyê: bajarê kevnar û dîrokî yê li ser çemê Dîcleyê ku xwedî şikeftên bêhempa ye.', 'Heskîf bi hezaran malên şikeftî yên li perava Dîcleyê ku di zinaran de hatine kolandin tê naskirin; piraniya bajarê kevn di bin ava Bendava Ilisûyê de ma.'),
  ('bac807de-18f9-55ab-9d60-d74dbf95b631', 'offline_curated_20951', 'explanation_ku', '"Heskîf" tê vê wateyê: bajarê kevnar û dîrokî yê li ser çemê Dîcleyê ku xwedî şikeftên bêhempa ye.', 'Heskîf bi hezaran malên şikeftî yên li perava Dîcleyê ku di zinaran de hatine kolandin tê naskirin; piraniya bajarê kevn di bin ava Bendava Ilisûyê de ma.'),
  ('43bcb411-91b7-5c77-aeb3-b030a5ec2691', 'offline_curated_20976', 'explanation', '"Qerejdax" tê vê wateyê: çiyayê volkanîk ê bazaltî ku deşta Amedê ji ya Rihayê vediqetîne.', 'Qerejdax volkaneke mertalî ya fireh e ku di navbera deştên Amed û Rihayê de dirêj dibe; lavên wê yên bazaltî her du deştan ji hev vediqetînin.'),
  ('43bcb411-91b7-5c77-aeb3-b030a5ec2691', 'offline_curated_20976', 'explanation_ku', '"Qerejdax" tê vê wateyê: çiyayê volkanîk ê bazaltî ku deşta Amedê ji ya Rihayê vediqetîne.', 'Qerejdax volkaneke mertalî ya fireh e ku di navbera deştên Amed û Rihayê de dirêj dibe; lavên wê yên bazaltî her du deştan ji hev vediqetînin.'),
  ('ea1f3a69-b8c9-5d3a-8671-2b838c14da19', 'offline_curated_21001', 'explanation', '"Sazîbûna Dengbêjiyê" tê vê wateyê: kela parastina ziman û dîrokê ku bi riya stran û klamên dengbêjan tê meşandin.', 'Dengbêjiyê di serdemên ku nivîs belav nebû de dîrok, şer û evîn bi kilaman ji nifşekî bo nifşekî din veguhastin û ziman û bîr parastin.'),
  ('ea1f3a69-b8c9-5d3a-8671-2b838c14da19', 'offline_curated_21001', 'explanation_ku', '"Sazîbûna Dengbêjiyê" tê vê wateyê: kela parastina ziman û dîrokê ku bi riya stran û klamên dengbêjan tê meşandin.', 'Dengbêjiyê di serdemên ku nivîs belav nebû de dîrok, şer û evîn bi kilaman ji nifşekî bo nifşekî din veguhastin û ziman û bîr parastin.'),
  ('c2471c74-2b7e-560a-a16b-2076a08b536f', 'offline_curated_21076', 'explanation', '"Govenda Kurdî" tê vê wateyê: dansa komî û gelêrî ya ku bi hevgirtina destan û ruhê hevkariyê tê gerandin.', 'Govend dansa gelêrî ya komî ye ku tê de beşdar destên hev digirin an mil didin hev û bi awayê xelek an rêzê dilîzin.'),
  ('c2471c74-2b7e-560a-a16b-2076a08b536f', 'offline_curated_21076', 'explanation_ku', '"Govenda Kurdî" tê vê wateyê: dansa komî û gelêrî ya ku bi hevgirtina destan û ruhê hevkariyê tê gerandin.', 'Govend dansa gelêrî ya komî ye ku tê de beşdar destên hev digirin an mil didin hev û bi awayê xelek an rêzê dilîzin.'),
  ('278b149d-3a62-5cdd-aecd-02abffe46efd', 'offline_curated_21101', 'explanation', '"çanda koçeriyê" tê vê wateyê: şêwaza jiyana kevnar a li ser zozan û germiyanê ku çanda kurdî pir dewlemend kiriye.', 'Di koçeriyê de kerî havînê tên birin zozanên hênik, zivistanê tên birin germiyana nizm; jiyan li gorî vê çerxa demsalî ava dibe.'),
  ('278b149d-3a62-5cdd-aecd-02abffe46efd', 'offline_curated_21101', 'explanation_ku', '"çanda koçeriyê" tê vê wateyê: şêwaza jiyana kevnar a li ser zozan û germiyanê ku çanda kurdî pir dewlemend kiriye.', 'Di koçeriyê de kerî havînê tên birin zozanên hênik, zivistanê tên birin germiyana nizm; jiyan li gorî vê çerxa demsalî ava dibe.'),
  ('63827b58-2d46-5781-9f67-76ca544b1ddd', 'offline_curated_21176', 'explanation', '"Destana Memê Alan" tê vê wateyê: destana neteweyî ya kurdî ya ku hîmê Mem û Zîna Xanî pêk tîne.', 'Ehmedê Xanî di Mem û Zîna ku di 1692an de nivîsî de ji destana devkî ya Memê Alan sûd wergirt û ew kir mesnewiyeke evînê ya neteweyî.'),
  ('63827b58-2d46-5781-9f67-76ca544b1ddd', 'offline_curated_21176', 'explanation_ku', '"Destana Memê Alan" tê vê wateyê: destana neteweyî ya kurdî ya ku hîmê Mem û Zîna Xanî pêk tîne.', 'Ehmedê Xanî di Mem û Zîna ku di 1692an de nivîsî de ji destana devkî ya Memê Alan sûd wergirt û ew kir mesnewiyeke evînê ya neteweyî.'),
  ('bcb4471c-f216-5c5b-b2d3-6b66c383f370', 'offline_curated_21200', 'explanation', '"hewran" tê vê wateyê: kincê hewrî yê dirêj ê ku li ser kincên din tê wergirtin.', 'Hewran kincê dirêj ê derve ye ku li ser kincên din tê lixwekirin; wekî qata herî jor tê lixwekirin.'),
  ('bcb4471c-f216-5c5b-b2d3-6b66c383f370', 'offline_curated_21200', 'explanation_ku', '"hewran" tê vê wateyê: kincê hewrî yê dirêj ê ku li ser kincên din tê wergirtin.', 'Hewran kincê dirêj ê derve ye ku li ser kincên din tê lixwekirin; wekî qata herî jor tê lixwekirin.'),
  ('80e0767c-3872-55cb-9f40-e9fafa8be3b6', 'offline_curated_21226', 'explanation', '"şevbêrk" tê vê wateyê: civînên şevê yên zivistanê ku tê de çîrokên gelêrî û metelok dihatin gotin.', 'Şevbêrk civîna şevên dirêj ên zivistanê ye ku tê de mirov li malekê kom dibin û bi çîrok, mamik û kilaman demê derbas dikin.'),
  ('80e0767c-3872-55cb-9f40-e9fafa8be3b6', 'offline_curated_21226', 'explanation_ku', '"şevbêrk" tê vê wateyê: civînên şevê yên zivistanê ku tê de çîrokên gelêrî û metelok dihatin gotin.', 'Şevbêrk civîna şevên dirêj ên zivistanê ye ku tê de mirov li malekê kom dibin û bi çîrok, mamik û kilaman demê derbas dikin.'),
  ('dee39536-39d7-5f58-9905-c487d6f39943', 'offline_curated_21251', 'explanation', '"tembûr" tê vê wateyê: amûra têldar a ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin ku bi taybetî di civatên olî de tê lêdan.', 'Tembûr amûreke têldar a destikdirêj e; di baweriya Yarsanê (Ehlê Heq) de pîroz tê hesibandin û di merasîmên cemê de tê lêdan.'),
  ('dee39536-39d7-5f58-9905-c487d6f39943', 'offline_curated_21251', 'explanation_ku', '"tembûr" tê vê wateyê: amûra têldar a ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin ku bi taybetî di civatên olî de tê lêdan.', 'Tembûr amûreke têldar a destikdirêj e; di baweriya Yarsanê (Ehlê Heq) de pîroz tê hesibandin û di merasîmên cemê de tê lêdan.'),
  ('b9ccc63f-ac26-59b8-b4d8-625105ec4190', 'offline_curated_21276', 'explanation', '"erbane" tê vê wateyê: amûra lêdanê ya zildar ku di muzîka kurdî ya olî û gelêrî de xwedî cihekî girîng e.', 'Erbane defeke mezin e ku zengil an xelek bi çarçoveya wê ve hatine girêdan; di tekye û civatên olî de hevaltiya zikrê û di muzîka gelêrî de jî hevaltiya rîtmê dike.'),
  ('b9ccc63f-ac26-59b8-b4d8-625105ec4190', 'offline_curated_21276', 'explanation_ku', '"erbane" tê vê wateyê: amûra lêdanê ya zildar ku di muzîka kurdî ya olî û gelêrî de xwedî cihekî girîng e.', 'Erbane defeke mezin e ku zengil an xelek bi çarçoveya wê ve hatine girêdan; di tekye û civatên olî de hevaltiya zikrê û di muzîka gelêrî de jî hevaltiya rîtmê dike.'),
  ('a7cb2c9b-b992-563f-9842-87e1a55ff705', 'offline_curated_21301', 'explanation', '"bilûr" tê vê wateyê: amûra bayê ya şivanan ku bi dengê xwe yê xemgîn û lîrîk tê naskirin.', 'Bilûr amûreke pifkirinê ya ji cureyê kawalê ye ku şivan bi xwe re digerînin; bi dengê xwe yê nerm û xemgîn tê naskirin.'),
  ('a7cb2c9b-b992-563f-9842-87e1a55ff705', 'offline_curated_21301', 'explanation_ku', '"bilûr" tê vê wateyê: amûra bayê ya şivanan ku bi dengê xwe yê xemgîn û lîrîk tê naskirin.', 'Bilûr amûreke pifkirinê ya ji cureyê kawalê ye ku şivan bi xwe re digerînin; bi dengê xwe yê nerm û xemgîn tê naskirin.'),
  ('b9ae7f7e-1b22-598a-9e8a-359e757917e0', 'offline_curated_21326', 'explanation', '"lîrîka klaman" tê vê wateyê: avahiya helbestî ya kilamên dengbêjiyê ku çîrokên evîn û şeran vedibêjin.', 'Kilamên dengbêjan çîrokên evîn û şer bi zimanekî helbestî, bi dubarekirin û bi gotina awazî ya dirêj vedibêjin.'),
  ('b9ae7f7e-1b22-598a-9e8a-359e757917e0', 'offline_curated_21326', 'explanation_ku', '"lîrîka klaman" tê vê wateyê: avahiya helbestî ya kilamên dengbêjiyê ku çîrokên evîn û şeran vedibêjin.', 'Kilamên dengbêjan çîrokên evîn û şer bi zimanekî helbestî, bi dubarekirin û bi gotina awazî ya dirêj vedibêjin.'),
  ('3d29e580-9e55-56fc-b738-071562af70cf', 'offline_curated_21351', 'explanation', '"Şakiro" tê vê wateyê: dengbêjê mezin ê ku wekî "Şahê Dengbêjan" tê naskirin û xwedî dengekî bêhempa bû.', 'Şakiro (1936–1996) bi dengê xwe yê xurt û gelek kilamên xwe di nav dengbêjan de wekî "şahê dengbêjan" tê bibîranîn.'),
  ('3d29e580-9e55-56fc-b738-071562af70cf', 'offline_curated_21351', 'explanation_ku', '"Şakiro" tê vê wateyê: dengbêjê mezin ê ku wekî "Şahê Dengbêjan" tê naskirin û xwedî dengekî bêhempa bû.', 'Şakiro (1936–1996) bi dengê xwe yê xurt û gelek kilamên xwe di nav dengbêjan de wekî "şahê dengbêjan" tê bibîranîn.'),
  ('d72e8f29-7c93-5925-81c2-92e35fccad60', 'offline_curated_21376', 'explanation', '"Hesen Cizrawî" tê vê wateyê: yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botan tomar kirine.', 'Hesen Cizrawî dengbêjekî ji Cizîrê ye ku bi kilamên Botanê yên ku wî di weşanên kurdî yên Radyoya Bexdayê de gotine tê naskirin.'),
  ('d72e8f29-7c93-5925-81c2-92e35fccad60', 'offline_curated_21376', 'explanation_ku', '"Hesen Cizrawî" tê vê wateyê: yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botan tomar kirine.', 'Hesen Cizrawî dengbêjekî ji Cizîrê ye ku bi kilamên Botanê yên ku wî di weşanên kurdî yên Radyoya Bexdayê de gotine tê naskirin.'),
  ('f0b35b33-3d94-54a1-a028-e7ca04b782b2', 'offline_curated_21401', 'explanation', '"Meryem Xan" tê vê wateyê: stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye.', 'Meryem Xan (1904–1949) yek ji stranbêjên jin ên kurd ên pêşîn e ku di salên 1920 û 1930an de plak tomar kirin.'),
  ('f0b35b33-3d94-54a1-a028-e7ca04b782b2', 'offline_curated_21401', 'explanation_ku', '"Meryem Xan" tê vê wateyê: stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye.', 'Meryem Xan (1904–1949) yek ji stranbêjên jin ên kurd ên pêşîn e ku di salên 1920 û 1930an de plak tomar kirin.'),
  ('8d89bae8-ac07-5b59-9ac8-b1dabdf2c113', 'offline_curated_21451', 'explanation', '"lawik" tê vê wateyê: şêwaza kilama dengbêjiyê ya lîrîk ku bi piranî li ser evîn û hesretê ye.', 'Lawik di kevneşopiya dengbêjiyê de cureyekî kilama lîrîk e ku bi piranî behsa evîn, hesret û veqetînê dike.'),
  ('8d89bae8-ac07-5b59-9ac8-b1dabdf2c113', 'offline_curated_21451', 'explanation_ku', '"lawik" tê vê wateyê: şêwaza kilama dengbêjiyê ya lîrîk ku bi piranî li ser evîn û hesretê ye.', 'Lawik di kevneşopiya dengbêjiyê de cureyekî kilama lîrîk e ku bi piranî behsa evîn, hesret û veqetînê dike.'),
  ('bb4d417e-241e-504f-ab15-882fe1ddb986', 'offline_curated_21475', 'explanation', '"heyran" tê vê wateyê: klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin.', 'Heyranok (heyran) kilamên evînê ne ku li devera Serhedê bi piranî jin dibêjin û gazî hezkiriyê xwe dikin.'),
  ('bb4d417e-241e-504f-ab15-882fe1ddb986', 'offline_curated_21475', 'explanation_ku', '"heyran" tê vê wateyê: klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin.', 'Heyranok (heyran) kilamên evînê ne ku li devera Serhedê bi piranî jin dibêjin û gazî hezkiriyê xwe dikin.'),
  ('4871a5b2-2479-536f-a069-d310f26bb12f', 'offline_curated_21601', 'explanation', '"nenavendîbûn" tê vê wateyê: parvekirina desthilatê ji navendê ber bi herêm û rêveberiyên xweser ve.', 'Di nenavendîbûnê de desthilat di rêveberiya navendî de kom nabe; li herêm û rêveberiyên herêmî tê belavkirin.'),
  ('4871a5b2-2479-536f-a069-d310f26bb12f', 'offline_curated_21601', 'explanation_ku', '"nenavendîbûn" tê vê wateyê: parvekirina desthilatê ji navendê ber bi herêm û rêveberiyên xweser ve.', 'Di nenavendîbûnê de desthilat di rêveberiya navendî de kom nabe; li herêm û rêveberiyên herêmî tê belavkirin.'),
  ('523101c4-385b-54a2-863e-4a8af327459f', 'offline_curated_21651', 'explanation', '"pirrengî" tê vê wateyê: prensîba parastin û pejirandina hemû nasnameyên cuda yên di civakê de.', 'Pirrengî prensîbek e ku hebûna bi hev re û naskirina wekhev a nasnameyên cuda yên civakê diparêze.'),
  ('523101c4-385b-54a2-863e-4a8af327459f', 'offline_curated_21651', 'explanation_ku', '"pirrengî" tê vê wateyê: prensîba parastin û pejirandina hemû nasnameyên cuda yên di civakê de.', 'Pirrengî prensîbek e ku hebûna bi hev re û naskirina wekhev a nasnameyên cuda yên civakê diparêze.'),
  ('b9f95b18-db36-585c-a9b7-0c9be820e5c3', 'offline_curated_21676', 'explanation', '"demokrasiya rasterast" tê vê wateyê: şêwazê rêveberiyê ku tê de gel bêyî nûneran biryaran dide.', 'Di demokrasiya rasterast de gel bêyî hilbijartina nûneran bi xwe biryaran dide; di meclîsan an referandûman de rasterast deng dide.'),
  ('b9f95b18-db36-585c-a9b7-0c9be820e5c3', 'offline_curated_21676', 'explanation_ku', '"demokrasiya rasterast" tê vê wateyê: şêwazê rêveberiyê ku tê de gel bêyî nûneran biryaran dide.', 'Di demokrasiya rasterast de gel bêyî hilbijartina nûneran bi xwe biryaran dide; di meclîsan an referandûman de rasterast deng dide.'),
  ('872e482d-52cc-5bb4-a208-d2f4eb6d0737', 'offline_tf_siy_0031', 'explanation', 'Erê. Ji heman qadê têgeheke din: "dadgehkirina dadperwer" tê vê wateyê: mafê her kesî yê darizandina eşkere, bêalî û di demeke maqûl de.', 'Rast e. Kotaya zayendî diyarkirina pareke herî kêm e da ku jin di sazî û organên hilbijartî de ji rêjeyeke diyar kêmtir neyên temsîlkirin.'),
  ('872e482d-52cc-5bb4-a208-d2f4eb6d0737', 'offline_tf_siy_0031', 'explanation_ku', 'Erê. Ji heman qadê têgeheke din: "dadgehkirina dadperwer" tê vê wateyê: mafê her kesî yê darizandina eşkere, bêalî û di demeke maqûl de.', 'Rast e. Kotaya zayendî diyarkirina pareke herî kêm e da ku jin di sazî û organên hilbijartî de ji rêjeyeke diyar kêmtir neyên temsîlkirin.'),
  ('544927f6-f987-589c-a5bd-66bb385ce2ef', 'offline_2227', 'option_c', 'Serokkomarê Iraqê', 'Dehaqê zalim'),
  ('544927f6-f987-589c-a5bd-66bb385ce2ef', 'offline_2227', 'option_d', 'Mîrtî', 'Ferhad (evîndarê Şîrînê)'),
  ('eecba717-363e-569d-9e6e-3a90d9bae4a2', 'offline_7145', 'option_a', 'Kahire', 'rêberê berxwedana Dêrsimê ya 1937an'),
  ('eecba717-363e-569d-9e6e-3a90d9bae4a2', 'offline_7145', 'option_b', 'bajarê dîrokî yê hezaran salî yê li ser çemê Dîclê', 'fermandarê leşkerî yê serhildana Agiriyê (1927–1930)'),
  ('eecba717-363e-569d-9e6e-3a90d9bae4a2', 'offline_7145', 'option_d', 'yekem dewleta kurdî ya kurtjiyan a ku di 1946an de hat damezrandin', 'serokkomarê Komara Mehabadê ya ku di 1946an de hat damezrandin'),
  ('0900b118-afec-57ce-9fe4-126032b52627', 'offline_7201', 'option_a', 'tevgera neteweyî ya ku bi salan li Başûrê Kurdistanê dom kir', 'alimê olî yê ku rêberiya serhildana 1925an kir'),
  ('09407abb-973a-5511-883f-1d4d3802b67b', 'offline_7210', 'option_b', 'belge an tiştê ku ji wê serdemê maye (çavkaniya yekemîn)', 'mîrê mezin ê dawî yê Mîrgeha Botanê'),
  ('09407abb-973a-5511-883f-1d4d3802b67b', 'offline_7210', 'option_c', 'mîrektiya kurd a ku li başûrê Gola Wanê hukum kir', 'mîrê Bedlîsê yê ku Şerefname nivîsî'),
  ('51cf256f-3581-5fcb-9f08-0229341c4780', 'offline_7300', 'option_a', 'avahiya ku bi rêveberiya navendî ve hat girêdan / hat rakirin', 'mîrê Bedlîsê yê ku Şerefname nivîsî'),
  ('51cf256f-3581-5fcb-9f08-0229341c4780', 'offline_7300', 'option_b', 'belge an tiştê ku ji wê serdemê maye (çavkaniya yekemîn)', 'zimannasê ku kovara Hawarê derxist'),
  ('51cf256f-3581-5fcb-9f08-0229341c4780', 'offline_7300', 'option_d', 'peymana ku sînorê Osmanî û Sefewî diyar kir', 'fermandarê leşkerî yê serhildana Agiriyê (1927–1930)'),
  ('8614c98b-9514-5398-9501-ba79056f87e4', 'offline_7497', 'option_a', 'Çemê Batmanê', 'serokkomarê Komara Mehabadê ya ku di 1946an de hat damezrandin'),
  ('8614c98b-9514-5398-9501-ba79056f87e4', 'offline_7497', 'option_c', 'hukumdariya kurd a ku di serdema Osmanî de xweser mabû', 'zimannasê ku kovara Hawarê derxist'),
  ('8614c98b-9514-5398-9501-ba79056f87e4', 'offline_7497', 'option_d', 'rojnameya kurdî ya serdema destpêkê ya ku li Silêmaniyê hat çapkirin', 'alimê olî yê ku rêberiya serhildana 1925an kir'),
  ('d4f8d579-9c79-5e15-b727-c3e4cc1351a7', 'offline_7633', 'option_a', 'tevgera neteweyî ya ku bi salan li Başûrê Kurdistanê dom kir', 'siyasetmedara jin a kurd a ku li Tirkiyeyê parlamenterî kir'),
  ('f580690b-21d1-5b8a-9f80-4e1778aeb76f', 'offline_7643', 'option_a', 'tevgera neteweyî ya ku ji 1961an ve li Başûrê Kurdistanê dom kir', 'alimê olî yê ku rêberiya serhildana 1925an kir'),
  ('4cbea941-2a07-5c24-8b0b-7576468bc76a', 'offline_7798', 'option_a', 'tevgera neteweyî ya ku bi salan li Başûrê Kurdistanê dom kir', 'serokkomarê Komara Mehabadê ya ku di 1946an de hat damezrandin'),
  ('ae03650d-527b-5848-867f-cffc9187f457', 'offline_7249', 'option_b', 'jenosîda ku rejîma Iraqê li dijî kurdan pêk anî', 'rêberê berxwedana Dêrsimê ya 1937an'),
  ('5f0a48c4-22df-58a6-985e-971081806482', 'offline_9227', 'option_c', 'belavbûna alfabeya kurdî ya bi bingehê latînî', 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('16c9ac61-18b9-5d34-8b1b-c1797a1cd034', 'offline_9378', 'option_b', 'destana gelêrî ya ku bingeha Mem û Zînê ye', 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('16c9ac61-18b9-5d34-8b1b-c1797a1cd034', 'offline_9378', 'option_d', 'çîrok, destan û vegotinên dengbêjan', 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe tê naskirin'),
  ('fe24147e-d6f3-58d3-abad-ae3b3bc7f581', 'offline_9409', 'option_b', 'çîrok, destan û vegotinên dengbêjan', 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('88e607b2-0fea-5c32-b6e2-f9a735523899', 'offline_9950', 'option_d', 'belavbûna alfabeya kurdî ya bi bingehê latînî', 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('4fccdab1-1beb-534e-a9f8-2c28be060e00', 'offline_10071', 'option_b', 'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir', 'helbestvanê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('8ed12694-33e7-5254-b96b-bddfba9726e5', 'offline_10433', 'option_b', 'amûra bayî ya kevneşopî ya ku şivan jî lê dixin', 'hunermendê ku bayê rock û caz anî muzîka kurdî'),
  ('8ed12694-33e7-5254-b96b-bddfba9726e5', 'offline_10433', 'option_c', 'cureya muzîkê ya ku bêtir li ser evîn û mêrxasiyê tê gotin', 'yek ji stranbêjên jin ên kurd ên pêşîn ku dengê xwe li ser plakan tomar kiriye'),
  ('b3955d28-8ad5-512c-a3c5-bf828c7f9c9b', 'offline_10537', 'option_d', 'amûra bayî ya kevneşopî ya ku şivan jî lê dixin', 'yek ji stranbêjên jin ên kurd ên pêşîn ku dengê xwe li ser plakan tomar kiriye'),
  ('c0be96d9-3c93-5001-b9a6-da7712664000', 'offline_10715', 'option_a', 'şêwaza dengî ya bi rîtma azad a ku kilam pê tên gotin', 'hunermendê ku bayê rock û caz anî muzîka kurdî'),
  ('c0be96d9-3c93-5001-b9a6-da7712664000', 'offline_10715', 'option_c', 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', 'muzîkjenê hoste yê bi eslê xwe ermenî yê ku bi stranên kurdî tê naskirin'),
  ('59bfeddd-0c33-5014-9534-3dfbbe134c72', 'offline_10926', 'option_b', 'koma ku muzîka kurdî di hawîrdoreke pirçandî de pêşkêş dike', 'hunermendê ku bayê rock û caz anî muzîka kurdî'),
  ('59bfeddd-0c33-5014-9534-3dfbbe134c72', 'offline_10926', 'option_d', 'amûra pifê ya bi dengê bilind a ku li derve tê lêxistin', 'muzîkjenê hoste yê bi eslê xwe ermenî yê ku bi stranên kurdî tê naskirin'),
  ('864374c2-4022-5691-9a85-c80324479194', 'offline_10963', 'option_a', 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê', 'dengbêjê mezin ê ku wekî şahê dengbêjan tê bibîranîn'),
  ('864374c2-4022-5691-9a85-c80324479194', 'offline_10963', 'option_d', 'cureya muzîkê ya ku bêtir li ser evîn û mêrxasiyê tê gotin', 'yek ji stranbêjên jin ên kurd ên pêşîn ku dengê xwe li ser plakan tomar kiriye'),
  ('c48de691-6c34-537d-8c95-93c5df996523', 'offline_11125', 'option_b', 'kilamên destanî yên dirêj ên ku Şakiro digotin', 'dengbêjê mezin ê ku wekî şahê dengbêjan tê bibîranîn'),
  ('4941ebd0-eca1-523a-9f26-52e04e9914be', 'offline_11431', 'option_b', 'şêwaza muzîkê ya taybetî ya herêma Dihok û Zaxoyê', 'folklornasê ku kilaman dinivîse'),
  ('4941ebd0-eca1-523a-9f26-52e04e9914be', 'offline_11431', 'option_d', 'bêyî amûr û bi awaza xweberî', 'muzîkjenê ku di dawetan de zirne û dahol lê dide'),
  ('d5d1dc8d-428e-5d48-865f-1693c1ce35ed', 'offline_curated_20251', 'option_b', 'kovara Hawarê', 'Feqiyê Teyran'),
  ('d5d1dc8d-428e-5d48-865f-1693c1ce35ed', 'offline_curated_20251', 'option_d', 'Helbesta Azad', 'Cegerxwîn'),
  ('7c6a799d-67a2-5261-8d52-a289f517c3e2', 'offline_curated_20304', 'option_c', 'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye', 'helbestvanê klasîk ê Cizîrî yê ku bi dîwana xwe ya felsefî û tesewifî tê naskirin'),
  ('3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808', 'offline_curated_20426', 'option_c', 'Helbesta Azad', 'Erebê Şemo'),
  ('3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808', 'offline_curated_20426', 'option_d', 'kovara Hawarê', 'Cegerxwîn'),
  ('cec40864-20c2-5066-90b8-c844e70fe42a', 'offline_curated_20276', 'option_a', 'şevbêrkên wêjeyî', 'Melayê Cizîrî'),
  ('896ddb0a-ca48-5407-be00-a11d45dc3495', 'edit_muzik_0001', 'option_c', 'cureyê muzîkê yê ku bêtir li ser evîn û mêrxasiyê tê gotin', 'Muzîkjenê ku di dawetan de zirne û dahol lê dide'),
  ('991a74f7-0786-53d9-a3eb-97555aebda77', 'offline_7983', 'option_a', 'Celadet Alî Bedirxan', 'pergala jiyana koçeriyê'),
  ('991a74f7-0786-53d9-a3eb-97555aebda77', 'offline_7983', 'option_c', 'rojnameyeke kurdî ya destpêkê ku li Silêmaniyê hate çapkirin', 'pergala nîvkoçerî ya di navbera zozan û germiyanê de'),
  ('991a74f7-0786-53d9-a3eb-97555aebda77', 'offline_7983', 'option_d', 'yekem kovara kurdî ya ku bi alfabeya latînî hat çapkirin', 'pergala kampa demkî ya di konan de'),
  ('5701a6c0-be34-578b-8500-a6b25da7eed0', 'offline_2304', 'option_a', 'veguhastina êş, windahî û bîra civakî', 'rêveberiya mîrgehan û pergala bacê ya serdema Osmanî'),
  ('5701a6c0-be34-578b-8500-a6b25da7eed0', 'offline_2304', 'option_b', 'Îranî û gelek gelên din (wek Newrozê)', 'zimanê nivîskî yê ku li derdora kovara Hawarê pêş ket'),
  ('5701a6c0-be34-578b-8500-a6b25da7eed0', 'offline_2304', 'option_c', 'tora rêxistinbûna civakî, ewlehî, hilberîn û têkiliya siyasî', 'perwerdeya medreseyan û helbesta dîwanê ya klasîk'),
  ('4a67d849-bd4a-5d30-9a05-5155fdb92b52', 'offline_curated_20601', 'option_c', 'Peymana Lozanê', 'Kovara Ronahî'),
  ('11637dbd-8ca6-541f-b8b6-783aaa304c72', 'offline_curated_20701', 'option_a', 'Selaheddînê Eyûbî', 'Mîrgeha Babanê'),
  ('f4e67d62-aea8-56a1-88e8-878db7b034d9', 'ds_cografya_0199', 'explanation_ku', 'Tora koordînat (graticule) ji xetên ku hêlîpan û hêlîdirêjan li ser nexşeyê nîşan didin pêk tê. Xetên îzolîn bilindahiyê nîşan didin.', 'Tora koordînatan (graticule) li ser nexşeyê tora xetên hêlîpan (paralel) û hêlîdirêjan (merîdyen) e. Îzolîn jî ew xet e ku xalên xwedî heman nirxî bi hev ve girê dide; xeta bilindahiyê ya wekhev cureyê wê yê ji bo bilindahiyê ye.'),
  ('97a7c8aa-a36e-5e01-9225-ea3c1c6ea478', 'cinema_0005', 'explanation_ku', 'Bi pergala Vitaphone axaftin û stran bi dîmenê re hevdemî hatin dayîn; ev yek bû sedem ku serdema bêdengiyê di nav çend salan de bi dawî bibe. Nûbûnên pêvajoya rengîn û anîmasyona dirêjmetraj heta dawiya salên 1930an li benda mane.', 'Bi pergala Vitaphone stran û hin axaftin bi dîmenê re hevdem hatin dayîn. Dayîna hevdem a deng û dîmenê derbasbûna ji fîlmê bêdeng bo fîlmê bideng lezand.'),
  ('443e4a83-d9f6-52da-af86-3a99352d3eed', 'ds_teknoloji_0339', 'explanation_ku', 'Di stûnî de tenê qadên têkildar tên xwendin û ji ber ku dane ji heman tîpê ne, bi algorîtmayên wekî Parquet pir baş tên şidandin.', 'Di depokirina stûnî de tenê qadên têkildar tên xwendin û ji ber ku dane ji heman cureyê ne, di formatên pelan ên wekî Parquet de pir baş tên şidandin.'),
  ('da5dbcb8-c9de-5ce7-8a88-af9a272a9675', 'ders_2026_10_01_0055', 'explanation_ku', 'Wateya "dilşad"ê, dilxweşî û şadî ye.', '"Dilşad" tê wateya kesê dilxweş û şad; ji "dil" û "şad" pêk tê. "Xemgîn" jî tê wateya bêkêf.'),
  ('c1f8e390-1284-5240-9e23-1f3e3e35c12e', 'ds_cografya_0205', 'explanation_ku', 'Koçberiya hundirîn tê wateya koçkirina di nav welatekî de, wek ji gund bo bajar. Koçberiya derveyî derbasî welatekî din dibe, ya demkî û çerxî jî demkî ne.', 'Koçberiya hundirîn koçkirina di nav sînorên welatekî de ye; koçkirina ji gund bo bajar û ji bajarekî bo bajarekî din mînakên wê ne. Koçberiya derveyî bo welatekî din e; koçberiya demkî û çerxî jî ji bo demeke an demsaleke diyar e û armanca bicihbûna mayînde nîne.'),
  ('aeac1b1a-4b93-5161-a3c6-b24f83c94d2e', 'ds_teknoloji_0136', 'option_d', 'Veguhestina çewtkirinê', 'Birrîna gradyanê (gradient clipping)'),
  ('c6e1fc68-5dff-502a-9360-ae4a7ff8ea68', 'ds_teknoloji_0328', 'option_a', 'Xetereya binesaziyê ya ji ber nebûna yekîneya hesabkirina matematîkî', 'Girêdayîbûna nivîsandinê piştî xwendinê (WAR)'),
  ('c6e1fc68-5dff-502a-9360-ae4a7ff8ea68', 'ds_teknoloji_0328', 'option_b', 'Zêdebûna germahiya navenda pêvajoyê di dema lîstina lîstikên giran de', 'Girêdayîbûna nivîsandinê piştî nivîsandinê (WAW)'),
  ('c6e1fc68-5dff-502a-9360-ae4a7ff8ea68', 'ds_teknoloji_0328', 'option_c', 'Rakirina pêdiviya bîrgeha lezgîn a asta duyem (L2 Cache) ji ser çîpê', 'Girêdayîbûna kontrolê ya ji şaxbûnê'),
  ('c6e1fc68-5dff-502a-9360-ae4a7ff8ea68', 'ds_teknoloji_0328', 'option_d', 'Sekinîna ji ber xetereya daneyan (Data Hazard) bi şandina rasterast a encamê', 'Girêdayîbûna xwendinê piştî nivîsandinê (RAW)'),
  ('c01560a2-2d59-554b-91c0-28ff7cc365ed', 'offline_tf_siy_0018', 'explanation', 'Na — ev ravekirina "muxalefeta civakî" ye; "muxalefeta demokratîk" rexnekirina desthilatê ye di nav sînorên hiqûqî de bêyî çekan.', 'Şaş e. Muxalefeta demokratîk ne tenê partî; rêxistinên civaka sivîl, sendîka û tevgerên civakî jî dikarin bi rêyên aştiyane û hiqûqî bimeşînin.'),
  ('c01560a2-2d59-554b-91c0-28ff7cc365ed', 'offline_tf_siy_0018', 'explanation_ku', 'Na — ev ravekirina "muxalefeta civakî" ye; "muxalefeta demokratîk" rexnekirina desthilatê ye di nav sînorên hiqûqî de bêyî çekan.', 'Şaş e. Muxalefeta demokratîk ne tenê partî; rêxistinên civaka sivîl, sendîka û tevgerên civakî jî dikarin bi rêyên aştiyane û hiqûqî bimeşînin.'),
  ('4efa354e-b0f0-5425-b4f5-085c3713c393', 'offline_10572', 'option_c', 'dengbêjê ku tomarên destpêkê yên muzîka kurdî kirin', 'dengbêjê Cizîrî yê ku bi salan li Radyoya Bexdayê kilam gotin'),
  ('2643da36-fe95-5dda-8c96-22be4df82306', 'ds_cografya_0279', 'option_d', 'Daketina blokên erdê di navbera xetên şikestekan de (graben)', 'Daketina blokên erdê yên di navbera xetên şikestekan de ber bi jêr ve'),
  ('6715b57b-f5f9-5359-9c9e-aa948ea4f765', 'ds_cand_1182', 'option_d', 'Kirasê jêrîn ê mil-dirêj (lewendî) û fîstanê rengîn ê qedîfe li ser', 'Kirasê jêrîn ê bi milên dirêj û daliqandî û fîstanê rengîn ê qedîfe li ser'),
  ('fb78d683-7f0b-5009-8a9c-061df77f2021', 'ds_cand_1187', 'option_c', 'Berbûk (şandeya bûkê)', 'Berbûk'),
  ('09407abb-973a-5511-883f-1d4d3802b67b', 'offline_7210', 'option_d', 'serokê bihêz ê mîrektiya Soranê yê bi leqeba kor', 'mîrê bihêz ê ku Mîrgeha Soranê birêve bir'),
  ('d4f8d579-9c79-5e15-b727-c3e4cc1351a7', 'offline_7633', 'option_b', 'efserê ku bi navê komeleya Xoybûnê serokatiya leşkerî kir', 'siyasetmedara jin a kurd a ku li Parîsê hat kuştin'),
  ('d4f8d579-9c79-5e15-b727-c3e4cc1351a7', 'offline_7633', 'option_c', 'kesê ku di 1898an de rojnameya kurdî ya yekem, Kurdistan, derxist', 'nivîskara jin a ku bi kurdî roman û çîrok nivîsîn'),
  ('8ed12694-33e7-5254-b96b-bddfba9726e5', 'offline_10433', 'option_a', 'hunermendê dengî yê herî navdar ê ku muzîka kurdî da nasîn cîhanê', 'dengbêjê mezin ê ku wekî şahê dengbêjan tê bibîranîn'),
  ('b3955d28-8ad5-512c-a3c5-bf828c7f9c9b', 'offline_10537', 'option_b', 'hunermendê ku bayê rock û caz anî muzîka kurdî', 'muzîkjenê hoste yê bi eslê xwe ermenî yê ku bi stranên kurdî tê naskirin'),
  ('b3955d28-8ad5-512c-a3c5-bf828c7f9c9b', 'offline_10537', 'option_c', 'hunermendê dengî yê herî navdar ê ku muzîka kurdî da nasîn cîhanê', 'dengbêjê mezin ê ku wekî şahê dengbêjan tê bibîranîn'),
  ('4941ebd0-eca1-523a-9f26-52e04e9914be', 'offline_11431', 'option_c', 'sazê rîtmê yê ku bi zirneyê re tê lêxistin', 'hosteyê ku amûrên kevneşopî çêdike û tamîr dike'),
  ('7c6a799d-67a2-5261-8d52-a289f517c3e2', 'offline_curated_20304', 'option_b', 'nivîskarê destana nemir a "Mem û Zîn" ku hîmê ramanî yê kurdewariyê daniye', 'helbestvanê kurd ê klasîk ê ku mesnewiya Mem û Zînê nivîsî'),
  ('e0a361e9-03d5-53f1-8590-b2d2b4226d66', 'offline_curated_20501', 'option_a', 'Mîrê Kor', 'Împaratoriya Hîtîtan'),
  ('e0a361e9-03d5-53f1-8590-b2d2b4226d66', 'offline_curated_20501', 'option_b', 'Şerefname', 'Keyaniya Urartuyê'),
  ('cf1d8cee-f9c5-5683-bb7e-8683c546db06', 'offline_curated_20526', 'option_b', 'Şerefname', 'Dewleta Hesenweyhiyan'),
  ('4a67d849-bd4a-5d30-9a05-5155fdb92b52', 'offline_curated_20601', 'option_b', 'Rojnameya Kurdistan', 'Rojnameya Azadiya Welat'),
  ('1e1d5a70-f478-502d-9121-5d4f129a573a', 'offline_curated_20826', 'option_b', 'Heskîf', 'Çiyayê Sîpanê'),
  ('1e1d5a70-f478-502d-9121-5d4f129a573a', 'offline_curated_20826', 'option_c', 'Çemê Firatê', 'Çiyayê Nemrûdê'),
  ('13f09861-251b-5ac7-8edd-b8c74a5c17a1', 'offline_curated_20851', 'option_a', 'Çiyayê Sîpanê', 'Nînewaya kevnar'),
  ('13f09861-251b-5ac7-8edd-b8c74a5c17a1', 'offline_curated_20851', 'option_b', 'Newala Dîcleyê', 'Babîla kevnar'),
  ('13f09861-251b-5ac7-8edd-b8c74a5c17a1', 'offline_curated_20851', 'option_d', 'Çemê Firatê', 'Hattuşaya kevnar'),
  ('34705932-2632-59da-a12f-aca9f2087b8a', 'offline_curated_20901', 'option_c', 'Geliyê Zapê', 'Çiyayê Nemrûdê'),
  ('34705932-2632-59da-a12f-aca9f2087b8a', 'offline_curated_20901', 'option_d', 'Newala Dîcleyê', 'Çiyayê Erciyesê'),
  ('f97a2f0c-70ac-53db-9565-7d29204ca7ce', 'offline_curated_20926', 'option_a', 'Girê Mirazan', 'Geliyê Arasê'),
  ('f97a2f0c-70ac-53db-9565-7d29204ca7ce', 'offline_curated_20926', 'option_d', 'Gola Wanê', 'Geliyê Muradê'),
  ('bac807de-18f9-55ab-9d60-d74dbf95b631', 'offline_curated_20951', 'option_a', 'Çemê Firatê', 'Mêrdîn'),
  ('bac807de-18f9-55ab-9d60-d74dbf95b631', 'offline_curated_20951', 'option_b', 'Qerejdax', 'Xelat'),
  ('bac807de-18f9-55ab-9d60-d74dbf95b631', 'offline_curated_20951', 'option_d', 'Newala Dîcleyê', 'Bedlîs'),
  ('43bcb411-91b7-5c77-aeb3-b030a5ec2691', 'offline_curated_20976', 'option_c', 'Girê Mirazan', 'Çiyayê Sîpanê'),
  ('43bcb411-91b7-5c77-aeb3-b030a5ec2691', 'offline_curated_20976', 'option_d', 'Geliyê Zapê', 'Çiyayê Nemrûdê'),
  ('e2383ed2-23aa-56f5-b7ce-60e7a686af4c', 'offline_curated_20451', 'option_a', 'Melayê Cizîrî', 'şevên hinneyê yên berî dawetê'),
  ('e2383ed2-23aa-56f5-b7ce-60e7a686af4c', 'offline_curated_20451', 'option_b', 'kovara Hawarê', 'civînên zîbarê'),
  ('e2383ed2-23aa-56f5-b7ce-60e7a686af4c', 'offline_curated_20451', 'option_c', 'Ehmedê Xanî', 'civatên zikrê yên olî'),
  ('4871a5b2-2479-536f-a069-d310f26bb12f', 'offline_curated_21601', 'option_b', 'xweseriya demokratîk', 'rêveberiya navendî'),
  ('b9f95b18-db36-585c-a9b7-0c9be820e5c3', 'offline_curated_21676', 'option_b', 'komûn û meclîs', 'demokrasiya nûneratiyê'),
  ('eecba717-363e-569d-9e6e-3a90d9bae4a2', 'offline_7145', 'option_c', 'serokê sereke yê Serhildana Şêx Seîd a 1925an', 'alimê olî yê ku rêberiya serhildana 1925an kir'),
  ('51cf256f-3581-5fcb-9f08-0229341c4780', 'offline_7300', 'option_c', 'yekem lêkolînerê ku edet û kevneşopiyên kurdî berhev kirin', 'nivîskarê pêşeng ê ku adet û kevneşopiyên kurdan bi kurdî berhev kirin'),
  ('16c9ac61-18b9-5d34-8b1b-c1797a1cd034', 'offline_9378', 'option_a', 'helbestvanê kurd ê navdar ê ku bi zimanê teyran dizanibû', 'helbestvanê kurd ê klasîk ê ku li gorî efsaneyê zimanê teyran dizanibû'),
  ('aeac1b1a-4b93-5161-a3c6-b24f83c94d2e', 'ds_teknoloji_0136', 'option_b', 'Veguhestina rastkirinê', 'Daketina gradyanê (gradient descent)'),
  ('4efa354e-b0f0-5425-b4f5-085c3713c393', 'offline_10572', 'option_a', 'dengbêjê ku hestên neteweyî yên gelê kurd dianî ziman', 'hunermendê ku bi xebatên rock û caza kurdî tê naskirin'),
  ('4efa354e-b0f0-5425-b4f5-085c3713c393', 'offline_10572', 'option_d', 'stranbêjî an lêxistina bi tenê ya hunermendekî', 'dengbêjê mezin ê ku wekî şahê dengbêjan tê bibîranîn'),
  ('fe24147e-d6f3-58d3-abad-ae3b3bc7f581', 'offline_9409', 'option_a', 'Mehmed Uzun', 'romannivîsê ku romana "Siya Evînê" nivîsî'),
  ('1ea2be4c-5b71-5869-a305-75e6ee313d87', 'ds_edebiyat_0248', 'option_a', 'Zimanê helbestê ji qalibên giran ên erûzê ber bi zimanê gel û têkoşîna civakî ve bir', 'Bi sûdwergirtina ji şêweyên klasîk jî jiyana gel û têkoşîna civakî xist navenda helbesta xwe'),
  ('1a33d5cf-9c5a-5047-9562-e1ef5f9bc716', 'offline_11136', 'option_c', 'lêdanên birêkûpêk ên ku bingeha muzîkê ne', 'rêkxistina deng û bêdengiyan ji aliyê dem û giraniyê ve'),
  ('23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'ds_cografya_0284', 'option_a', 'Ji hesin, magnezyûm û mîneralên volkanîk gelekî dewlemend e', 'Hebûna mîneralên bi hesin û magnezyûm ên ku ji materyala bingehîn a bazaltê tên'),
  ('23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'ds_cografya_0284', 'explanation_ku', 'Axa volkanîk a Qerecdaxê xwedî mîneralên bihêz ên hesin û magnezyumê ye û ji bo berhemdariyê gelekî dewlemend e.', 'Axên ku ji bazalta Qerejdaxê çêbûne mîneralên bi hesin û magnezyûm ên ji materyala bingehîn digirin; berdariya çandiniyê her wiha bi pêşketina axê û şert û mercan ve girêdayî ye.'),
  ('a5e4583f-719a-598f-b9b9-f6239fe996e6', 'comm_muz_0001', 'explanation_ku', NULL, 'Koma Wetan di 1973an de li Tiflîsa Gurcistana Sovyetê hat damezrandin; wekî koma yekem a ku gotinên kurdî bi muzîka rockê re anî cem hev tê bibîranîn.'),
  ('a5e4583f-719a-598f-b9b9-f6239fe996e6', 'comm_muz_0001', 'explanation_tr', NULL, 'Koma Wetan 1973''te Sovyet Gürcistanı''nın Tiflis kentinde kuruldu; Kürtçe sözleri rock müzikle buluşturan ilk grup olarak anılır.'),
  ('236b2ecf-4ead-5847-96ec-e3f3b6afd562', 'comm_muz_0004', 'explanation_ku', NULL, 'Serhado rapbêjekî kurd e ku li Stockholmê ji dayik bûye; "Ax" navê mînî-albûma wî ya pênc stranî û yek ji stranên wê ye.'),
  ('236b2ecf-4ead-5847-96ec-e3f3b6afd562', 'comm_muz_0004', 'explanation_tr', NULL, 'Serhado Stockholm doğumlu bir Kürt rapçidir; "Ax" onun beş parçalık mini albümünün ve albümdeki bir şarkının adıdır.'),
  ('6dd3c43f-0b54-5e30-80e6-3c80dc359564', 'comm_muz_0005', 'explanation_ku', NULL, 'Şerîfê Omerî (Şerîfo) rapbêjekî kurd ê Qamişloyî ye; bi stranên wekî "Rojvala" û "Megrî bajarê min" ên ku behsa Rojava dikin tê naskirin.'),
  ('6dd3c43f-0b54-5e30-80e6-3c80dc359564', 'comm_muz_0005', 'explanation_tr', NULL, 'Şerifê Omerî (Şerîfo) Qamişlo''lu bir Kürt rapçidir; "Rojvala" ve "Megrî bajarê min" gibi Rojava''yı anlatan parçalarıyla tanınır.'),
  ('d50e3219-340a-5add-ba48-d01e89a514a4', 'comm_dir_0003', 'explanation_ku', NULL, 'Arîn Mîrkan şervana YPJê ye ku di 5ê Cotmeha 2014an de li girê Miştenûrê yê Kobanê li dijî mewziyên DAIŞê çalakiya fedayî pêk anî; bû yek ji sembolên berxwedana Kobanê.'),
  ('d50e3219-340a-5add-ba48-d01e89a514a4', 'comm_dir_0003', 'explanation_tr', NULL, 'Arîn Mîrkan, 5 Ekim 2014''te Kobanê''deki Miştenur tepesinde IŞİD mevzilerine karşı fedai eylemi gerçekleştiren YPJ savaşçısıdır; Kobanê direnişinin simgelerinden biri oldu.'),
  ('bd076f90-f561-51f5-b57f-3fc88f172ad0', 'comm_dir_0004', 'explanation_ku', NULL, 'Viyan Peyman hunermend û şervaneke YPJê ya ji Rojhilatê Kurdistanê bû ku bi kilamên xwe dihat naskirin; beşdarî berxwedana Kobanê bû û di 6ê Nîsana 2015an de li nêzîkî Serêkaniyê jiyana xwe ji dest da.'),
  ('bd076f90-f561-51f5-b57f-3fc88f172ad0', 'comm_dir_0004', 'explanation_tr', NULL, 'Viyan Peyman, kilamlarıyla tanınan Doğu Kürdistanlı bir sanatçı ve YPJ savaşçısıydı; Kobanê direnişine katıldı ve 6 Nisan 2015''te Serêkaniyê yakınında hayatını kaybetti.'),
  ('642fe7fb-8402-5948-b577-00706ce82324', 'comm_dir_0006', 'explanation_ku', NULL, 'Kemal Pîr li Gumuşxaneyê ji dayik bûye; ji ber ku ji Deryaya Reş bû wekî "Laz Kemal" dihat binavkirin. Di 1982an de di rojiya mirinê ya Girtîgeha Amedê de jiyana xwe ji dest da.'),
  ('642fe7fb-8402-5948-b577-00706ce82324', 'comm_dir_0006', 'explanation_tr', NULL, 'Kemal Pir Gümüşhane doğumludur; Karadenizli olduğu için "Laz Kemal" diye anıldı. 1982''de Diyarbakır Cezaevi''ndeki ölüm orucunda hayatını kaybetti.'),
  ('0fc248b7-728f-5a51-82b4-fdbf798799fe', 'comm_dir_0007', 'explanation_ku', NULL, 'Hakî Karer li Orduyê ji dayik bûye; ji kadroyên pêşîn ên tevgera ku paşê PKK ava kir bû û di 1977an de li Entabê hat kuştin.'),
  ('0fc248b7-728f-5a51-82b4-fdbf798799fe', 'comm_dir_0007', 'explanation_tr', NULL, 'Haki Karer Ordu doğumludur; sonradan PKK''yi kuracak hareketin ilk kadrolarındandı ve 1977''de Antep''te öldürüldü.'),
  ('e1f9e510-efdb-57fc-a3cc-de7db9423990', 'comm_dir_0008', 'explanation_ku', NULL, 'Ocalan di nivîsên xwe de Hakî Karerê ku di 1977an de hat kuştin wekî "cêwiyê ruhê min" bi bîr tîne; Karer ji kadroya pêşîn a tevgerê bû.'),
  ('e1f9e510-efdb-57fc-a3cc-de7db9423990', 'comm_dir_0008', 'explanation_tr', NULL, 'Öcalan, 1977''de öldürülen Haki Karer''i yazılarında "ruh ikizim" diye anar; Karer hareketin ilk kadrosundandı.'),
  ('bb3cea42-15f7-5910-a813-584ffe691f12', 'comm_dir_0009', 'explanation_ku', NULL, 'Bavê Teyar (Cuma Xelîl Îbrahîm) lîstikvanê şanoyê û komedyenekî kurd ê Qamişloyî bû; di çalakiya rûniştinê ya li Bendava Tişrînê de di êrîşa hewayî ya 18ê Çileya 2025an de birîndar bû û roja din jiyana xwe ji dest da.'),
  ('bb3cea42-15f7-5910-a813-584ffe691f12', 'comm_dir_0009', 'explanation_tr', NULL, 'Bavê Teyar (Cuma Xelîl Îbrahîm), Qamişlo''lu bir Kürt tiyatro oyuncusu ve komedyendi; Tişrin Barajı''ndaki oturma eyleminde 18 Ocak 2025''teki hava saldırısında yaralandı ve ertesi gün hayatını kaybetti.'),
  ('8a0de8e6-0a13-5b7a-bdcd-f1a137e06823', 'offline_0005', 'explanation_ku', NULL, '"Av" bi tirkî "su" ye.'),
  ('6e13c677-1f76-5157-ab51-6643fd71d3b1', 'offline_0010', 'explanation_ku', NULL, 'Du wateyên sereke yên peyva "roj"ê hene: "gün" (roj) û "güneş" (tav).'),
  ('f1fc671b-e9c5-5497-9172-033588aada1b', 'offline_0015', 'explanation_ku', NULL, '"Mal" bi tirkî "ev" e. Hişyar be: peyva "ev" di kurmancî de tê wateya "bu".'),
  ('d1ccfc36-88a8-5136-9419-5f5ea57fe7f9', 'offline_0020', 'explanation_ku', NULL, '"Pirtûk" bi tirkî "kitap" e.'),
  ('ebb432d8-ff0f-583d-accd-2202bb0fa88c', 'offline_0025', 'explanation_ku', NULL, '"Zanîn" bi tirkî "bilmek" e; "Ez dizanim" yanî "biliyorum".'),
  ('9fd3f984-7c0f-5af9-8513-38e326333171', 'offline_0030', 'explanation_ku', NULL, '"Hatin" bi tirkî "gelmek" e; "Ez têm" yanî "geliyorum".'),
  ('a8fd8d4f-9568-545c-8804-d04a99efbe9a', 'offline_0040', 'explanation_ku', NULL, '"Dil" bi tirkî "kalp" e; di wateya "gönül" de jî tê bikaranîn. Peyva "dil" a tirkî (lisan) bi kurmancî "ziman" e.'),
  ('133b39ae-ac3a-5891-b40d-c3f9b47ebe29', 'offline_0050', 'explanation_ku', NULL, '"Bajar" bi tirkî "şehir" e.'),
  ('f53febe0-c5cf-5380-a5ee-ee9c9b03c46e', 'offline_0055', 'explanation_ku', NULL, '"Nan" bi tirkî "ekmek" e.'),
  ('b9e855b5-886b-552f-b299-b1d342e52636', 'offline_0060', 'explanation_ku', NULL, '"Rê" bi tirkî "yol" e.'),
  ('4b6e3ad8-3cb8-5071-9d7a-8aa525f0ead5', 'offline_0062', 'explanation_ku', NULL, '"Teşekkür" bi kurmancî "spas" e; "Gelek spas" yanî "çok teşekkürler".'),
  ('0156aef6-6bde-5d09-9466-df2cbe4683cd', 'offline_0065', 'explanation_ku', NULL, '"Spas" bi tirkî "teşekkür" e.'),
  ('d4e89411-c754-536e-ab97-07e0486c32f8', 'offline_0070', 'explanation_ku', NULL, '"Xweş" bi tirkî "güzel/iyi" ye; "Roj xweş!" yanî "iyi günler".'),
  ('1de0a09f-93d4-5786-ba97-311ae8970529', 'offline_0075', 'explanation_ku', NULL, '"Sar" bi tirkî "soğuk" e; dijberê wê "germ" e.'),
  ('ceabc400-851f-5d96-9fd4-3a01872f4a83', 'offline_0080', 'explanation_ku', NULL, '"Biçûk" bi tirkî "küçük" e; dijberê wê "mezin" e.'),
  ('8c0c200d-073a-5695-9b16-103c765cd444', 'offline_0085', 'explanation_ku', NULL, '"Kevin" bi tirkî "eski" ye; dijberê wê "nû" ye.'),
  ('dad61aa5-9f08-58e1-8450-09e28f54b20d', 'offline_0090', 'explanation_ku', NULL, '"Îro" bi tirkî "bugün" e.'),
  ('a41c6da7-c100-5389-bfee-79818c9ad65a', 'offline_0095', 'explanation_ku', NULL, '"Duh" bi tirkî "dün" e; "sibê" jî "yarın" e.'),
  ('2bf6a934-161f-59f3-b5cd-c040cfec5a99', 'offline_0110', 'explanation_ku', NULL, '"Xwendekar" bi tirkî "öğrenci" ye; ji "xwendin" (okumak) tê.'),
  ('a17e0a1d-a927-59fb-9aef-881ba1688d89', 'offline_0745', 'explanation_ku', NULL, 'Di erdnîgariyê de "çiya" bi tirkî "dağ" e: şeklekî bilind ê rûyê erdê.'),
  ('3d87b42f-01f8-5539-9112-68551dfbd55b', 'offline_0748', 'explanation_ku', NULL, '"Çiya" bi tirkî "dağ" e.'),
  ('41050b79-60bc-53e3-b25c-d15c372362da', 'offline_0756', 'explanation_ku', NULL, '"Av" bi tirkî "su" ye.'),
  ('2b51f3fc-58b0-523b-9295-c9905d99c2b5', 'offline_0760', 'explanation_ku', NULL, '"Çem" bi tirkî "nehir/ırmak" e.'),
  ('a22f2d46-dcd6-58a0-b2ff-466c016f3a06', 'offline_0772', 'explanation_ku', NULL, '"Newal" bi tirkî "vadi" ye.'),
  ('d5f1b922-96a8-5afa-b90a-56786d8bc744', 'offline_2629', 'explanation_ku', NULL, '"Kirin" bi tirkî "yapmak/etmek" e; "kar kirin" yanî "çalışmak".'),
  ('a84c9ee8-9acb-5142-97df-de34a3bc38c6', 'offline_2749', 'explanation_ku', NULL, '"Nivîsîn" bi tirkî "yazmak" e; ji vê "nivîskar" (yazar) tê.'),
  ('9c0260aa-97f0-50d0-90bf-af17e1de7d7b', 'offline_5094', 'explanation_ku', NULL, '"Şev" bi tirkî "gece" ye; "Şev baş!" yanî "iyi geceler".'),
  ('277778ce-29ea-51ff-96bc-debfb84f2b7d', 'offline_5221', 'explanation_ku', NULL, '"Kal" bi tirkî "dede" ye; jina wî "pîr" e.'),
  ('d44d06b9-ee3b-5591-9f8f-d11ebd4720e9', 'offline_5685', 'explanation_ku', NULL, '"Ay" (li ezmên) bi kurmancî "heyv" e; "ay" a salnameyê jî "meh" e.');

-- Kökler: eşi olan satırın kökü ne eski ne yeni metinse (elle değişmiş) göç durur.
do $$
begin
  if exists (
    select 1 from questions q join (values
      ('c1f8e390-1284-5240-9e23-1f3e3e35c12e'::uuid, 'Kîjan têgih ji bo koçkirina mirovan ji gundan bo bajaran tê bikaranîn?', 'Koçkirina ji gundan bo bajaran di nav welatekî de kîjan cureya koçberiyê ye?'),
      ('aeac1b1a-4b93-5161-a3c6-b24f83c94d2e'::uuid, 'Di fêrbûna kûr de, kîjan rêbaz ji bo sererastkirina parametreyên modelê li gorî xeletiya hilberînê tê bikaranîn?', 'Di tora demarî ya çêkirî de kîjan rêbaz gradyanên fonksiyona windabûnê li gorî parametreyan bi qaîdeya zincîrê hesab dike?'),
      ('c6e1fc68-5dff-502a-9360-ae4a7ff8ea68'::uuid, 'Di pêvajoyera pîplînê de (Pipelining), rêbaza "Operand Forwarding" kîjan pirsgirêkê çareser dike?', 'Di pîplîna pêvajoyerê de, şandina rasterast a operandê (forwarding) bendemayînên ji kîjan girêdayîbûna daneyan kêm dike?'),
      ('c01560a2-2d59-554b-91c0-28ff7cc365ed'::uuid, '"muxalefeta demokratîk" nerazîbûna ku ji hêla komên civakî ve tê nîşandan e, ne ji hêla partiyan ve. Ev rast e an şaş e?', '"Muxalefeta demokratîk" tenê ji aliyê partiyên siyasî ve dikare bê meşandin. Ev rast e an şaş e?'),
      ('d8c3d439-b1cc-5988-8d8b-368611243b0c'::uuid, 'Rêbaza helbesta nûjen a bê pîvan û bê qafiye ku giraniya xwe dide ser peyvan çi ye?', 'Şêwaza helbestê ya ku bêyî girêdana bi pîvan û serwayeke diyar tê nivîsandin kîjan e?'),
      ('cf1d8cee-f9c5-5683-bb7e-8683c546db06'::uuid, 'Xanedaniya kurdî ya serdema navîn a ku navenda wê Amed û derdorên wê bûn, kîjan e?', 'Xanedaniya kurd a serdema navîn ku navenda wê Farqîn (Silvan) bû û li Amed û derdora wê jî hukum kir kîjan e?'),
      ('13f09861-251b-5ac7-8edd-b8c74a5c17a1'::uuid, 'Şûna herî kevn a perestgehên mirovahiyê ku li nêzîkî bajarê Rihayê ye, kîjan e?', 'Qada Neolîtîk a li nêzîkî Rihayê ku bi avahiyên xwe yên abîdeyî yên nêzîkî 11.600 salî tê naskirin kîjan e?'),
      ('3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808'::uuid, 'Romannivîsê kurd ê modern ku bi zimanekî kûr û edebî şoreşek di romana kurdî de çêkir kî bû?', 'Nivîskarê romanên "Siya Evînê" û "Bîra Qederê" kî ye?'),
      ('cec40864-20c2-5066-90b8-c844e70fe42a'::uuid, 'Helbestvanê klasîk ê ku bi "Şêx Sen''an"ê û axaftina bi çûkan re navdar e kî bû?', 'Helbestvanê klasîk ê ku bi berhema "Şêx Sen''an" û bi efsaneya axaftina bi teyran re tê naskirin kî bû?'),
      ('ca7a2945-730f-57b0-a1cd-b36ed09a5136'::uuid, 'Sîstema çandiniya bejî (bêavî) li herêmê herî zêde bi kîjan berheman ve tê nasîn?', 'Li herêmê di qadên çandiniya bejî (bêavî) de koma berhemên bingehîn a ku herî berbelav tê çandin kîjan e?'),
      ('0cf507aa-639e-52c5-81b1-c0b2f6f20092'::uuid, 'Li ser çiyayên herêmê bi zêdebûna bilindahiyê re qadên daristanan çawa diguherin?', 'Li kaşê çiyayekî ku kembera daristanên pelderzî jî lê heye, bi zêdebûna bilindahiyê re rêzbûna kemberên rûpûşa nebatan kîjan e?')
    ) as k(id, eski, yeni) on q.id = k.id
    where q.prompt is distinct from k.eski and q.prompt is distinct from k.yeni
  ) then
    raise exception 'kapisma-ku: kok eski/yeni metinle eslesmiyor';
  end if;
end
$$;

-- yerel: ds_cografya_0205
update questions set
  prompt = 'Koçkirina ji gundan bo bajaran di nav welatekî de kîjan cureya koçberiyê ye?'
where id = 'c1f8e390-1284-5240-9e23-1f3e3e35c12e';

-- yerel: ds_teknoloji_0136
update questions set
  prompt = 'Di tora demarî ya çêkirî de kîjan rêbaz gradyanên fonksiyona windabûnê li gorî parametreyan bi qaîdeya zincîrê hesab dike?'
where id = 'aeac1b1a-4b93-5161-a3c6-b24f83c94d2e';

-- yerel: ds_teknoloji_0328
update questions set
  prompt = 'Di pîplîna pêvajoyerê de, şandina rasterast a operandê (forwarding) bendemayînên ji kîjan girêdayîbûna daneyan kêm dike?'
where id = 'c6e1fc68-5dff-502a-9360-ae4a7ff8ea68';

-- yerel: offline_tf_siy_0018
update questions set
  prompt = '"Muxalefeta demokratîk" tenê ji aliyê partiyên siyasî ve dikare bê meşandin. Ev rast e an şaş e?'
where id = 'c01560a2-2d59-554b-91c0-28ff7cc365ed';

-- yerel: offline_curated_20476
update questions set
  prompt = 'Şêwaza helbestê ya ku bêyî girêdana bi pîvan û serwayeke diyar tê nivîsandin kîjan e?'
where id = 'd8c3d439-b1cc-5988-8d8b-368611243b0c';

-- yerel: offline_curated_20526
update questions set
  prompt = 'Xanedaniya kurd a serdema navîn ku navenda wê Farqîn (Silvan) bû û li Amed û derdora wê jî hukum kir kîjan e?'
where id = 'cf1d8cee-f9c5-5683-bb7e-8683c546db06';

-- yerel: offline_curated_20851
update questions set
  prompt = 'Qada Neolîtîk a li nêzîkî Rihayê ku bi avahiyên xwe yên abîdeyî yên nêzîkî 11.600 salî tê naskirin kîjan e?'
where id = '13f09861-251b-5ac7-8edd-b8c74a5c17a1';

-- yerel: offline_curated_20426
update questions set
  prompt = 'Nivîskarê romanên "Siya Evînê" û "Bîra Qederê" kî ye?'
where id = '3bad7ce2-4c0c-58e9-8dc9-06b08c8a0808';

-- yerel: offline_curated_20276
update questions set
  prompt = 'Helbestvanê klasîk ê ku bi berhema "Şêx Sen''an" û bi efsaneya axaftina bi teyran re tê naskirin kî bû?'
where id = 'cec40864-20c2-5066-90b8-c844e70fe42a';

-- yerel: ds_cografya_0274
update questions set
  prompt = 'Li herêmê di qadên çandiniya bejî (bêavî) de koma berhemên bingehîn a ku herî berbelav tê çandin kîjan e?'
where id = 'ca7a2945-730f-57b0-a1cd-b36ed09a5136';

-- yerel: ds_cografya_0286
update questions set
  prompt = 'Li kaşê çiyayekî ku kembera daristanên pelderzî jî lê heye, bi zêdebûna bilindahiyê re rêzbûna kemberên rûpûşa nebatan kîjan e?'
where id = '0cf507aa-639e-52c5-81b1-c0b2f6f20092';

update questions q set explanation = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'explanation'
   and q.explanation is not distinct from k.eski;

update questions q set explanation_ku = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'explanation_ku'
   and q.explanation_ku is not distinct from k.eski;

update questions q set explanation_tr = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'explanation_tr'
   and q.explanation_tr is not distinct from k.eski;

update questions q set option_a = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'option_a'
   and q.option_a is not distinct from k.eski;

update questions q set option_b = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'option_b'
   and q.option_b is not distinct from k.eski;

update questions q set option_c = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'option_c'
   and q.option_c is not distinct from k.eski;

update questions q set option_d = k.yeni
  from _kapisma_ku k
  where q.id = k.id and k.sutun = 'option_d'
   and q.option_d is not distinct from k.eski;

-- Doğrulama: eski değer hâlâ duruyorsa göç eksik çalışmıştır.
do $$
declare
  v_kalan int;
  v_yeni int;
begin
  select count(*) into v_kalan
    from questions q join _kapisma_ku k on q.id = k.id
   where k.eski is not null and (case k.sutun
        when 'explanation' then q.explanation
        when 'explanation_ku' then q.explanation_ku
        when 'explanation_tr' then q.explanation_tr
        when 'option_a' then q.option_a
        when 'option_b' then q.option_b
        when 'option_c' then q.option_c
        when 'option_d' then q.option_d
        end) = k.eski;
  if v_kalan > 0 then
    raise exception 'kapisma-ku: % alanda eski deger kaldi', v_kalan;
  end if;
  select count(*) into v_yeni
    from questions q join _kapisma_ku k on q.id = k.id
   where (case k.sutun
        when 'explanation' then q.explanation
        when 'explanation_ku' then q.explanation_ku
        when 'explanation_tr' then q.explanation_tr
        when 'option_a' then q.option_a
        when 'option_b' then q.option_b
        when 'option_c' then q.option_c
        when 'option_d' then q.option_d
        end) = k.yeni;
  raise notice 'kapisma-ku: yeni degerde % alan (yerelde % kayit)', v_yeni, (select count(*) from _kapisma_ku);
end
$$;

commit;
