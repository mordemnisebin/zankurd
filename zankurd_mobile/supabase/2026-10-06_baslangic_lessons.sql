-- 2026-10-06: BAŞLANGIÇ YOLU — dört yeni ders (canlı sunucu).
--
-- NİÇİN: sıfırdan Kurmancî öğrenmeye başlayan test kullanıcıları uygulamayı
-- "Kürtçeyi zaten bilenler için" buldu: alfabe, aile, kendini tanıtma ve
-- ikinci bir selamlaşma/nezaket dersi yoktu. Yerel katalogda (2.0.1) bu dersler
-- `alphabet_1`, `family_1`, `intro_1`, `greetings_2` olarak var; sunucuda
-- (üretim `lessons` tablosu, 15 satır) yoktu, yani sunucu katalogunu okuyan
-- derleme yolu bu dersleri hiç göstermezdi. `LearningLessonAliases.bySlug`
-- bu dört slug'ı yerel kimliklere bağlar: alfabe, silav-u-rezdari,
-- xwe-nasandin, malbat. Slayt metinleri yerel slaytlarla AYNIDIR
-- (`mock_zankurd_repository.dart`).
--
-- NE YAPAR:
--   1. `lessons`a dört satır ekler (slug tekil; `on conflict (slug) do nothing`).
--   2. Her derse slaytlarını ekler (`(lesson_id, order_in_lesson)` tekil;
--      `on conflict ... do nothing`).
--   3. Öğrenme yolunda "everyday" sırasını başlangıca göre yeniden numaralar:
--      alfabe 1, silav-u-nasin 2, silav-u-rezdari 3, xwe-nasandin 4, malbat 5,
--      hejmar 6. Yalnız `order_in_category` değişir (mevcut iki satır için
--      UPDATE; değer zaten doğruysa dokunmaz).
--   4. Doğrulama bloğu: slug, slayt sayısı ve sıra tutmazsa işlemi geri alır.
--
-- TEKRAR: ikinci çalıştırma 0 satır ekler, 0 satır günceller.
-- SORULAR: bu göç soru eklemez; yeni çoktan seçmeli sorular yalnız yerel
-- bankada (ders kısa testi yerel bankadan okur); boşluk doldurma ve cümle kurma
-- çevrimiçi oda protokolüne girmez.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from lessons where slug in ('alfabe','silav-u-rezdari','xwe-nasandin','malbat');
--   update lessons set order_in_category = 1 where slug = 'silav-u-nasin';
--   update lessons set order_in_category = 2 where slug = 'hejmar';
--   (lesson_slides satırları ON DELETE CASCADE ile gider.)
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-06_baslangic_lessons.sql

begin;

insert into lessons (slug, title_ku, title_tr, description_ku, category, icon_name, order_in_category, language) values
  ('alfabe', 'Alfabe', 'Alfabe', 'Tîpên Kurmancî û dengên wan', 'everyday', 'sort_by_alpha', 1, 'ku'),
  ('silav-u-rezdari', 'Silav û rêzdarî 2', 'Selamlaşma ve nezaket 2', 'Silav, spas û xatirxwestin', 'everyday', 'forum', 3, 'ku'),
  ('xwe-nasandin', 'Xwe nasandin', 'Kendini tanıtma', 'Nav, temen, welat û pîşe', 'everyday', 'badge', 4, 'ku'),
  ('malbat', 'Malbat', 'Aile', 'Endamên malbatê', 'everyday', 'family_restroom', 5, 'ku')
on conflict (slug) do nothing;

-- Alfabe
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Alfabeya Kurmancî (Hawar) 31 tîp e:\n\nA B C Ç D E Ê F G H I Î J K L M N O P Q R S Ş T U Û V W X Y Z\n\nHeşt tîp dengdêr in, bîst û sê tîp dengdar in.\n\n• Alfabe: Alfabe\n• Tîp: Harf\n• Dengdêr: Ünlü harf\n• Dengdar: Ünsüz harf', E'Kurmancî (Hawar) alfabesi 31 harftir: 8 ünlü ve 23 ünsüz harf. Hawar alfabesi Latin harflerini kullanır.', E'A, B, C, Ç, D...'),
  (2, E'Dengdêr (ünlü) tîp:\n\na — av\ne — ez\nê — êvar\ni — dil\nî — îro\no — ode\nu — kur\nû — dûr', E'Sekiz ünlü: a, e, ê, i, î, o, u, û. Kısa ve uzun ünlüler ayrı harflerdir: i kısa ve gevşek bir i''dir (Türkçedeki ı değildir), î uzun i''dir; u kısa, û uzun u''dur; e açık ve kısa, ê kapalı ve uzun bir e''dir.', E'Av, ez, êvar, dil, îro, ode, kur, dûr.'),
  (3, E'Tîpên taybet 1:\n\nç — wekî di tirkî de: çay\nş — wekî di tirkî de: şev\nc — wekî di tirkî de: cil\nj — wekî di tirkî de: jin\nw — wekî "w" a îngilîzî (water): welat', E'Özel harfler 1: ç ve ş Türkçedeki gibi okunur. w, İngilizce water kelimesindeki w gibidir (Türkçede yoktur). c ve j de Türkçedeki gibidir.', E'Çay, şev, welat, cil, jin.'),
  (4, E'Tîpên taybet 2:\n\nx — dengê qirikê (mîna "خ" ya erebî), di tirkî de tune ye: xal\nq — dengekî "k" yê kûr ji qirikê: qelem\nê — dengê "e" yê dirêj: êvar\nî — dengê "i" yê dirêj: îro\nû — dengê "u" yê dirêj: dûr', E'Özel harfler 2: x boğazdan çıkan, Türkçede olmayan bir sestir (Arapça خ ya da Almanca Bach''taki ch gibi; Türkçe ğ ile aynı değildir). q boğazdan çıkan derin bir k''dır (Arapça ق gibi). ê, î, û uzun ünlülerdir.', E'Xal, qelem, êvar, îro, dûr.'),
  (5, E'Peyv û tîp (C–H):\n\n• Cil: Giysi\n• Çay: Çay\n• Dar: Ağaç\n• Fêkî: Meyve\n• Gul: Gül\n• Heval: Arkadaş', E'Harflerle örnek kelimeler: c, ç, d, f, g, h.', E'Ev gul e. Ew heval e.'),
  (6, E'Peyv û tîp (K–W) û çend peyvên din:\n\n• Ker: Eşek\n• Lêv: Dudak\n• Mal: Ev\n• Ode: Oda\n• Qelem: Kalem\n• Roj: Gün / Güneş\n• Welat: Ülke\n• Dil: Kalp\n• Dûr: Uzak\n• Ev: Bu', E'Harflerle örnek kelimeler: k, l, m, o, q, r, w. "Mal" ev (bina), "ev" ise "bu" demektir; ikisini karıştırma.', E'Ev qelem e. Ev ode ye.')
) as s(ord, ku, tr, ex) where slug = 'alfabe'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Silav û rêzdarî 2
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Silav û bi xêr hatin:\n\n• Silav: Selam\n• Bi xêr hatî: Hoş geldin\n• Sibeha te bi xêr: Günaydın\n• Êvara te bi xêr: İyi akşamlar\n• Şeva te bi xêr: İyi geceler', E'Selamlaşma kalıpları. "Xêr" hayır/iyilik demektir; "Sibeha te bi xêr" sabahın hayırlı olsun anlamındadır.', E'Silav heval! Bi xêr hatî!'),
  (2, E'Hal pirsîn:\n\n• Hûn çawa ne?: Nasılsınız?\n• Ez baş im: İyiyim\n• Ez gelek baş im: Çok iyiyim\n• Çawa: Nasıl\n• Baş: İyi\n• Gelek: Çok', E'Hal hatır sorma. "Tu çawa yî?" tek kişiye, "Hûn çawa ne?" birden çok kişiye ya da saygıyla sorulur.', E'Tu çawa yî? Ez gelek baş im, spas.'),
  (3, E'Spas û lêborîn:\n\n• Gelek spas: Çok teşekkürler\n• Bibore: Özür dilerim / Pardon', E'Teşekkür ve özür. "Spas" tek başına da kullanılır.', E'Gelek spas, heval!'),
  (4, E'Xatirxwestin:\n\n• Bi xatirê te: Hoşça kal\n• Bi xatirê we: Hoşça kalın\n• Oxir be: Güle güle\n• Xêr: Hayır / İyilik\n• We: Size / Sizin (tewandî hal)', E'Vedalaşma. "Te" tek kişiye, "we" birden çok kişiye ya da saygıyla söylenir.', E'Bi xatirê te, heval. — Oxir be!')
) as s(ord, ku, tr, ex) where slug = 'silav-u-rezdari'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Xwe nasandin
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Nav:\n\n• Nav: Ad / İsim\n• Navê min Rojîn e: Benim adım Rojîn.\n• Rojîn: Kız ismi\n• Çi: Ne\n• Navê te çi ye?: Adın ne?', E'Adını söyleme. "Navê min ... e" = benim adım ...', E'Navê min Rojîn e. Navê te çi ye?'),
  (2, E'Temen:\n\n• Tu çend salî yî?: Kaç yaşındasın?\n• Ez bîst salî me: Yirmi yaşındayım.\n• Sal: Yıl\n• Çend: Kaç', E'Yaşı söyleme: "Ez ... salî me." (sal + î = yaşında).', E'Ez deh salî me. Tu çend salî yî?'),
  (3, E'Welat û bajar:\n\n• Ez ji Wanê me: Vanlıyım.\n• Ji: -den / -dan\n• Ku: Nerede / Nere\n• Der: Yer (ku derê = nere)\n• Wan: Van\n• Mêrdîn: Mardin\n• Stenbol: İstanbul\n• Kurd: Kürt', E'Nerelisin? sorusu ve cevabı. "ji" ile dişil şehir adlarının sonuna -ê eklenir: Wan → Wanê, Mêrdîn → Mêrdînê, Stenbol → Stenbolê..', E'Tu ji ku derê yî? Ez ji Mêrdînê me.'),
  (4, E'Pîşe:\n\n• Pîşe: Meslek\n• Xwendekar: Öğrenci\n• Mamoste: Öğretmen\n• Doktor: Doktor\n• Karker: İşçi', E'Meslek söyleme: "Ez ... im" (ünsüzden sonra) ya da "Ez ... me" (ünlüden sonra).', E'Ez xwendekar im. Ez mamoste me.'),
  (5, E'Ziman:\n\n• Kurdî: Kürtçe\n• Kurmancî: Kurmancî (Kürtçenin bir lehçesi)\n• Tirkî: Türkçe\n• Zanîn: Bilmek\n• Bi: İle / -le / -ce (dil)', E'Dil bilme: "Ez bi Kurmancî dizanim" = Kurmancî biliyorum.', E'Ez bi Kurmancî dizanim. Tu bi Tirkî dizanî?')
) as s(ord, ku, tr, ex) where slug = 'xwe-nasandin'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Malbat
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Malbata nêzîk:\n\n• Malbat: Aile\n• Dê: Anne\n• Bav: Baba\n• Bira: Erkek kardeş\n• Xwişk: Kız kardeş\n• Kur: Oğul / Erkek çocuk\n• Keç: Kız (çocuk)', E'Yakın aile üyeleri. "Bavê min" = benim babam (bav + -ê).', E'Ev dê ye. Ev bavê min e.'),
  (2, E'Malbata mezin:\n\n• Dapîr: Büyükanne\n• Bapîr: Büyükbaba\n• Mam: Amca\n• Met: Hala\n• Xal: Dayı\n• Xaltî: Teyze', E'Geniş aile. Amca (mam) ve hala (met) baba tarafı, dayı (xal) ve teyze (xaltî) anne tarafıdır.', E'Dapîra min li malê ye.'),
  (3, E'Kes û zarok:\n\n• Jin: Kadın / Eş\n• Mêr: Erkek / Koca\n• Zarok: Çocuk', E'İnsan ve çocuk sözcükleri.', E'Bapîr mêr e. Dapîr jin e.'),
  (4, E'Hevok:\n\n• Ev dê ye: Bu anne.\n• Ev bavê min e: Bu benim babam.\n• Dê û bav li malê ne: Anne ve baba evde.\n• Û: Ve\n• Li: -de / -da (yer)', E'Basit aile cümleleri. "ye" ünlüyle biten sözcükten sonra, "e" ünsüzle bitenden sonra gelir.', E'Bira û xwişk li malê ne.')
) as s(ord, ku, tr, ex) where slug = 'malbat'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Öğrenme yolu sırası (yalnız everyday; yalnız farklıysa günceller).
update lessons set order_in_category = 2 where slug = 'silav-u-nasin' and order_in_category is distinct from 2;
update lessons set order_in_category = 6 where slug = 'hejmar' and order_in_category is distinct from 6;

-- Doğrulama: slug, kategori, sıra ve slayt sayısı tutmazsa işlem geri alınır.
do $$
declare
  r record;
  v_count int;
begin
  for r in select * from (values
    ('alfabe', 6),
    ('silav-u-rezdari', 4),
    ('xwe-nasandin', 5),
    ('malbat', 4)
  ) as t(slug, expected_slides) loop
    select count(*) into v_count
      from lesson_slides ls join lessons l on l.id = ls.lesson_id
     where l.slug = r.slug;
    if v_count <> r.expected_slides then
      raise exception 'baslangic: % slayt sayisi % (beklenen %)', r.slug, v_count, r.expected_slides;
    end if;
  end loop;

  if (select count(*) from lessons where category = 'everyday'
        and slug in ('alfabe','silav-u-nasin','silav-u-rezdari','xwe-nasandin','malbat','hejmar')
        and order_in_category = case slug when 'alfabe' then 1 when 'silav-u-nasin' then 2
              when 'silav-u-rezdari' then 3 when 'xwe-nasandin' then 4 when 'malbat' then 5
              when 'hejmar' then 6 end) <> 6 then
    raise exception 'baslangic: everyday ders sirasi beklenen degil';
  end if;
end
$$;

commit;
