-- 2026-10-29 — Ders slaydı Türkçe karşılığının paragraf ayrımı (kapışma U20).
--
-- Neden: uygulama `content_tr`yi artık kartın sonunda değil, Kurmancî
-- açıklama cümlesinin HEMEN ALTINDA gösterir. Veri sözleşmesi: `content_tr`
-- boş satırla ayrılmış paragraflardan oluşur ve paragraf sayısı Kurmancî
-- açıklama bloklarının sayısına eşittir (sıralı eşleşir; bkz.
-- `LessonContentBlocks.explanationBlockCount`). Tarama (171 slayt) iki
-- uyuşmazlık buldu; ikisinde de METİN DEĞİŞMEZ, yalnız cümle aralarına boş
-- satır girer. Kurmancî alana dokunulmaz.
--
-- Etki: 2 satır (alfabe/1, leker/1). Koşul eski değerin birebir eşitliğidir:
-- metin bu arada değiştiyse güncelleme 0 satır etkiler, sessizce yanlış
-- bölmez.
--
-- GERİ ALMA: aynı iki güncellemenin yeni/eski değerleri yer değiştirerek.

begin;

update lesson_slides ls
set content_tr = E'Kurmancî (Hawar) alfabesi 31 harftir:\n\n8 ünlü ve 23 ünsüz harf. Hawar alfabesi Latin harflerini kullanır.'
from lessons l
where ls.lesson_id = l.id
  and l.slug = 'alfabe'
  and ls.order_in_lesson = 1
  and ls.content_tr = 'Kurmancî (Hawar) alfabesi 31 harftir: 8 ünlü ve 23 ünsüz harf. Hawar alfabesi Latin harflerini kullanır.';

update lesson_slides ls
set content_tr = E'Kurmancîde fiil cümlenin sonunda yer alır. Şimdiki/geniş zaman çoğu fiilde di- önekiyle yapılır. Özne + nesne + fiil sırası vardır.\n\nHatin (gelmek) di- almaz: ew tên onlar geliyorlar.\n\nOlumsuzluk na- ile yapılır: ez naçim ben gitmiyorum.'
from lessons l
where ls.lesson_id = l.id
  and l.slug = 'leker'
  and ls.order_in_lesson = 1
  and ls.content_tr = 'Kurmancîde fiil cümlenin sonunda yer alır. Şimdiki/geniş zaman çoğu fiilde di- önekiyle yapılır. Özne + nesne + fiil sırası vardır. Hatin (gelmek) di- almaz: ew tên onlar geliyorlar. Olumsuzluk na- ile yapılır: ez naçim ben gitmiyorum.';

-- Doğrulama: iki satır da yeni biçimde (paragraf sayısı 2 ve 3).
do $$
declare
  n int;
begin
  select count(*) into n
  from lesson_slides ls join lessons l on l.id = ls.lesson_id
  where (l.slug = 'alfabe' and ls.order_in_lesson = 1
         and ls.content_tr like E'%31 harftir:\n\n8 ünlü%')
     or (l.slug = 'leker' and ls.order_in_lesson = 1
         and ls.content_tr like E'%vardır.\n\nHatin%na- ile%');
  if n <> 2 then
    raise exception 'ders_karsilik_paragraf: beklenen 2 satır, bulunan %', n;
  end if;
end $$;

commit;
