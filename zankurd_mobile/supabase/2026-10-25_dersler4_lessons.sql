-- 2026-10-25: DİL BİLGİSİ DERİNLİĞİ — dört yeni ders (canlı sunucu).
--
-- NİÇİN: canlıda dil bilgisi yalnız `cinavk` (zamirler) ve `lekera-bun`
-- (olmak fiili) ile duruyordu; şimdiki zaman (`leker`) ve ergatif geçmiş
-- (`dema-bori`) everyday yolunda vardı ama izafe, gelecek zaman ve emir kipi
-- hiç yoktu; ay adları dersi de canlıda yoktu. Yerel katalogda bu
-- dersler `izafe_1`, `future_1`, `imperative_1` (grammar 3..5) ve `months_1`
-- (time 3) olarak var. `LearningLessonAliases.bySlug` slug'ları yerel
-- kimliklere bağlar: izafe, dema-be, fermani, mehen-sale. Slayt metinleri
-- yerel slaytlarla AYNIDIR (`mock_zankurd_repository.dart`).
--
-- ÖNKOŞUL (salt okunur, 2026-10-25): lessons 33, lesson_slides 151; grammar
-- sırası cinavk 1, lekera-bun 2; time sırası rojen-hefteye 1, demsal 2; dört
-- slug da boş. Bu göç grammar 3..5 ve time 3 verir.
--
-- NE YAPAR: (1) `lessons`a dört satır ekler (`on conflict (slug) do nothing`);
-- (2) beşer slayt ekler (`on conflict (lesson_id, order_in_lesson) do nothing`);
-- (3) doğrulama bloğu: slayt sayısı, kategori/sıra, çift nokta ve çift boşluk
-- artığı (meşru "..." sayılmaz), grammar 5 ve time 3 ders. Mevcut satırlara
-- dokunmaz. Soru eklemez (sorular yerel bankada: dersler4_2026_10_25).
--
-- TEKRAR: ikinci çalıştırma 0 satır ekler.
-- GERİ ALMA: delete from lessons where slug in ('izafe','dema-be','fermani','mehen-sale');
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-25_dersler4_lessons.sql

begin;

insert into lessons (slug, title_ku, title_tr, description_ku, description_tr, category, icon_name, order_in_category, language) values
  ('izafe', 'Îzafe', 'İzafe (tamlama)', 'Veqetandekên -a, -ê û -ên', '-a, -ê ve -ên ekleri', 'grammar', 'link', 3, 'ku'),
  ('dema-be', 'Dema bê', 'Gelecek zaman', 'Lêkerên dema bê', 'Gelecek zaman fiilleri', 'grammar', 'schedule', 4, 'ku'),
  ('fermani', 'Fermanî', 'Emir kipi', 'Were, rûne, bixwe', 'Gel, otur, ye', 'grammar', 'directions_run', 5, 'ku'),
  ('mehen-sale', 'Mehên salê', 'Yılın ayları', 'Diwanzdeh mehên salê', 'Yılın on iki ayı', 'time', 'calendar_today', 3, 'ku')
on conflict (slug) do nothing;

-- Îzafe
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Îzafe Çi Ye?\n\nÎzafe du peyvan bi hev ve girê dide. Pêşî tişt tê, paşê xwedî. Mînak:\n\n• mal: ev\n• mala min: evim\n• bav: baba\n• bavê te: baban\n• heval: arkadaş\n• hevalên me: arkadaşlarımız', E'İzafe iki kelimeyi birbirine bağlar. Türkçedeki tamlamanın tersine önce sahip olunan şey, sonra sahibi gelir: mal (ev) + min (ben) = mala min (evim). Ek, ilk kelimenin cinsine ve sayısına göre -a, -ê ya da -ên olur.', null::text),
  (2, E'Navên Mê (-a):\n\nNavdêrên mê di îzafeyê de -a digirin. Mînak:\n\n• keç: kız\n• keça min: kızım\n• pirtûka te: kitabın\n• dibistana me: okulumuz\n• xwişka wî: onun kız kardeşi\n• mala wan: onların evi', E'Dişil (mê) isimler izafede -a alır: keç → keça min (kızım), pirtûk → pirtûka te (kitabın). İkinci kelime zamirse bükümlü biçim gelir: min, te, wî, wê, me, we, wan.', null::text),
  (3, E'Navên Nêr (-ê):\n\nNavdêrên nêr di îzafeyê de -ê digirin. Mînak:\n\n• kur: oğul\n• kurê min: oğlum\n• bavê wê: onun babası\n• gundê me: köyümüz\n• bajarê wan: onların şehri\n• hevalê te: arkadaşın', E'Eril (nêr) isimler izafede -ê alır: kur → kurê min (oğlum), gund → gundê me (köyümüz). Kelimenin eril mi dişil mi olduğunu kelimeyle birlikte öğrenmek gerekir.', null::text),
  (4, E'Pirjimar (-ên):\n\nDi pirjimariyê de her du zayend -ên digirin. Piştî dengdêran y tê. Mînak:\n\n• hevalên min: arkadaşlarım\n• pirtûkên me: kitaplarımız\n• kurên wê: onun oğulları\n• birayê min: erkek kardeşim\n• mamosteya me: öğretmenimiz (kadın)\n• mamosteyên te: öğretmenlerin', E'Çoğulda eril ve dişil isimler aynı eki alır: -ên. Kelime ünlüyle bitiyorsa araya y girer: bira → birayê min, mamoste → mamosteya me, mamosteyên te.', null::text),
  (5, E'Rengdêr û Nediyar:\n\nRengdêr jî bi îzafeyê tê girêdan. Di nediyariyê de -eke (mê) û -ekî (nêr) tê. Mînak:\n\n• keça baş: iyi kız\n• kurê mezin: büyük oğul\n• hevalên baş: iyi arkadaşlar\n• ava sar: soğuk su\n• keçeke baş: iyi bir kız\n• kurekî mezin: büyük bir oğul\n• pirtûkeke nû: yeni bir kitap', E'Sıfat da izafeyle bağlanır: keça baş (iyi kız), kurê mezin (büyük oğul). Belirsiz isimde ek dişilde -eke, erilde -ekî olur: keçeke baş (iyi bir kız), kurekî mezin (büyük bir oğul).', null::text)
) as s(ord, ku, tr, ex) where slug = 'izafe'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Dema bê
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Dema Bê Çi Ye?\n\nDema bê ji bo karên ku hê nebûne û dê paşê bibin e. Mînak:\n\n• sibe: yarın\n• paşê: sonra\n• hefteya bê: gelecek hafta\n• sala bê: gelecek yıl\n• ez ê biçim: gideceğim\n• ez ê bixwim: yiyeceğim', E'Gelecek zaman, henüz olmamış ve ileride olacak işler içindir. sibe (yarın), paşê (sonra), hefteya bê (gelecek hafta) gibi zaman sözcükleriyle sık kullanılır.', null::text),
  (2, E'Ê û Bi-:\n\nDema bê: cînavk + ê + bi- + reh + paşgir. Mînak:\n\n• ez ê biçim: gideceğim\n• tu yê biçî: gideceksin\n• ew ê biçe: gidecek\n• em ê biçin: gideceğiz\n• hûn ê biçin: gideceksiniz\n• ew ê biçin: gidecekler', E'Gelecek zaman: zamir + ê + bi- + fiil kökü + kişi eki. Zamir ünlüyle bitince ê, yê olur: tu yê biçî. Kişi ekleri şimdiki zamandakiyle aynıdır: -im, -î, -e, -in.', null::text),
  (3, E'Kurt û bi Dê:\n\nÊ dikare bi cînavkê ve were nivîsîn. Li hin herêman dê tê gotin. Mînak:\n\n• ezê bixwim: yiyeceğim\n• tuyê bixwî: yiyeceksin\n• ewê bixwe: yiyecek\n• emê bixwin: yiyeceğiz\n• ez dê bixwim: yiyeceğim\n• ew dê bixwe: yiyecek', E'ê zamire bitişik de yazılabilir: ez ê = ezê, tu yê = tuyê. Bazı yörelerde ê yerine dê kullanılır: ez dê bixwim. Üçü de aynı anlamdadır.', null::text),
  (4, E'Hatin û Kirin:\n\nHin lêker di dema bê de bi awayekî din in. Mînak:\n\n• ez ê bêm: geleceğim\n• tu yê bêyî: geleceksin\n• ew ê bê: gelecek\n• ez ê bikim: yapacağım\n• ew ê bike: yapacak\n• ez ê bixwînim: okuyacağım\n• em ê vexwin: içeceğiz', E'Bazı fiiller farklıdır: hatin (gelmek) bi- almaz, kökü bê olur: ez ê bêm. Önekli fiiller de bi- almaz: vexwarin → em ê vexwin. kirin (yapmak) → ez ê bikim.', null::text),
  (5, E'Neyînî û Hevok:\n\nDi forma neyînî de ne- li şûna bi- tê. Mînak:\n\n• ez ê neçim: gitmeyeceğim\n• tu yê nexwî: yemeyeceksin\n• ew ê neyê: gelmeyecek\n• ez ê nekim: yapmayacağım\n• Sibe ez ê biçim dibistanê: Yarın okula gideceğim\n• Hefteya bê em ê bên: Gelecek hafta geleceğiz', E'Olumsuzda bi- yerine ne- gelir: ez ê biçim → ez ê neçim (gitmeyeceğim). hatin için ew ê neyê (gelmeyecek) denir.', null::text)
) as s(ord, ku, tr, ex) where slug = 'dema-be'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Fermanî
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Fermanî Çi Ye?\n\nBi fermanî em ji kesekî tiştekî dixwazin. Pêşî bi- tê, paşê reh û -e. Mînak:\n\n• bixwe: ye\n• bike: yap\n• bixwîne: oku\n• binêre: bak\n• bide: ver\n• bibêje: söyle', E'Emir kipiyle birinden bir şey isteriz. Tekil emir: bi- + fiil kökü + -e. xwarin (yemek) → bixwe (ye), kirin (yapmak) → bike (yap), nêrîn (bakmak) → binêre (bak).', null::text),
  (2, E'Yek û Gelek (-e, -in):\n\nJi yek kesî re -e, ji gelek kesan re -in tê. Mînak:\n\n• bixwe: ye\n• bixwin: yiyin\n• bike: yap\n• bikin: yapın\n• binêre: bak\n• binêrin: bakın\n• bixwînin: okuyun', E'Tek kişiye -e, birden çok kişiye -in eklenir: bixwe (ye) → bixwin (yiyin), bike (yap) → bikin (yapın).', null::text),
  (3, E'Were, Here, Rûne:\n\nHin lêker di fermanê de bi awayekî din in. Mînak:\n\n• were: gel\n• werin: gelin\n• here: git\n• herin: gidin\n• rûne: otur\n• rabe: kalk\n• vexwe: iç', E'Bazı fiillerin emri farklıdır: hatin (gelmek) → were, çûn (gitmek) → here (biçe de denir), rûniştin (oturmak) → rûne, rabûn (kalkmak) → rabe. Önekli fiiller bi- almaz: vexwarin → vexwe (iç).', null::text),
  (4, E'Neyînî (me-):\n\nFermana neyînî bi me- çêdibe. Mînak:\n\n• mexwe: yeme\n• mexwin: yemeyin\n• meke: yapma\n• mekin: yapmayın\n• meçe: gitme\n• mebêje: söyleme', E'Olumsuz emirde bi- yerine me- gelir: bixwe (ye) → mexwe (yeme), bike (yap) → meke (yapma). çûn için meçe (gitme) denir.', null::text),
  (5, E'Bi Nezaket:\n\nJi bo nezaketê em dibêjin: ji kerema xwe. Mînak:\n\n• Ji kerema xwe were: Lütfen gel\n• Ji kerema xwe rûne: Lütfen otur\n• Ji kerema xwe binêre: Lütfen bak\n• Avê vexwe: Suyu iç\n• Werin vir: Buraya gelin\n• Tu meke, ez ê bikim: Sen yapma, ben yapacağım', E'Kibar istek için emirle birlikte ji kerema xwe (lütfen) söylenir: Ji kerema xwe rûne (Lütfen otur).', null::text)
) as s(ord, ku, tr, ex) where slug = 'fermani'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Mehên salê
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Meh û Sal:\n\nSal diwanzdeh meh e. Her mehê navekî xwe heye. Mînak:\n\n• sal: yıl\n• meh: ay\n• diwanzdeh: on iki\n• ev meh: bu ay\n• meha bê: gelecek ay\n• meha borî: geçen ay', E'Bir yıl on iki aydır. Kurmancîde ayların iki ad takımı vardır; bu derste ikisini de öğreneceğiz. meha bê gelecek ay, meha borî geçen ay demektir.', null::text),
  (2, E'Şeş Mehên Pêşîn:\n\nNavên şeş mehên pêşîn ên salê. Mînak:\n\n• Rêbendan: Ocak\n• Reşemî: Şubat\n• Adar: Mart\n• Avrêl: Nisan\n• Gulan: Mayıs\n• Pûşper: Haziran', E'Yılın ilk altı ayının Kurmancî adları. Adar ayı Nevruz’un ayıdır.', null::text),
  (3, E'Şeş Mehên Dawî:\n\nNavên şeş mehên dawî yên salê. Mînak:\n\n• Tîrmeh: Temmuz\n• Gelawêj: Ağustos\n• Rezber: Eylül\n• Kewçêr: Ekim\n• Sermawez: Kasım\n• Berfanbar: Aralık', E'Yılın son altı ayının Kurmancî adları. Berfanbar yılın son ayıdır.', null::text),
  (4, E'Navên Din:\n\nLi bakur navên din jî pir tên bikaranîn. Adar, Gulan û Tîrmeh di her du rêzan de wek hev in. Mînak:\n\n• Çile: Ocak\n• Sibat: Şubat\n• Hezîran: Haziran\n• Tebax: Ağustos\n• Îlon: Eylül\n• Cotmeh: Ekim\n• Mijdar: Kasım\n• Kanûn: Aralık', E'Kuzeyde ikinci bir ad takımı da çok yaygındır. Adar, Gulan ve Tîrmeh iki takımda da aynıdır; Nisan için Nîsan da denir. Ekim ve Kasım için Çiriya Pêşîn ve Çiriya Paşîn adları da kullanılır.', null::text),
  (5, E'Meh di Hevokê de:\n\nDi hevokê de navê mehê -ê digire. Mînak:\n\n• meha Gulanê: Mayıs ayı\n• di meha Gulanê de: Mayıs ayında\n• di Adarê de: Mart’ta\n• Newroz di 21ê Adarê de ye: Nevruz 21 Mart’tadır\n• Ev meh Kewçêr e: Bu ay Ekim’dir\n• Rojbûna min di Tîrmehê de ye: Doğum günüm Temmuz’dadır', E'Cümlede ay adı -ê eki alır: Gulan → di meha Gulanê de (Mayıs ayında), Adar → di 21ê Adarê de (21 Mart’ta). Tarihte sayıya da -ê eklenir: 21ê.', null::text)
) as s(ord, ku, tr, ex) where slug = 'mehen-sale'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Doğrulama
do $$
declare
  r record;
  v_count int;
begin
  for r in select * from (values
    ('izafe', 5, 'grammar', 3),
    ('dema-be', 5, 'grammar', 4),
    ('fermani', 5, 'grammar', 5),
    ('mehen-sale', 5, 'time', 3)
  ) as t(slug, expected_slides, expected_category, expected_order) loop
    select count(*) into v_count from lesson_slides ls join lessons l on l.id = ls.lesson_id where l.slug = r.slug;
    if v_count <> r.expected_slides then
      raise exception 'dersler4: % slayt sayisi % (beklenen %)', r.slug, v_count, r.expected_slides;
    end if;
    if not exists (select 1 from lessons where slug = r.slug and category = r.expected_category and order_in_category = r.expected_order and language = 'ku') then
      raise exception 'dersler4: % kategori/sira beklenen degil', r.slug;
    end if;
    if exists (
      select 1 from lesson_slides ls join lessons l on l.id = ls.lesson_id
       where l.slug = r.slug
         and (ls.content_ku ~ '(^|[^.])\.\.([^.]|$)' or ls.content_tr ~ '(^|[^.])\.\.([^.]|$)'
              or ls.content_ku ~ '  ' or ls.content_tr ~ '  ')
    ) then
      raise exception 'dersler4: % slaytinda yazim artigi', r.slug;
    end if;
  end loop;
  if (select count(*) from lessons where category = 'grammar') <> 5 then
    raise exception 'dersler4: grammar ders sayisi 5 degil';
  end if;
  if (select count(*) from lessons where category = 'time') <> 3 then
    raise exception 'dersler4: time ders sayisi 3 degil';
  end if;
end
$$;

commit;
