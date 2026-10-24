-- Ders kartlarının alt başlığı Türkçe modda da Kurmancî görünüyordu: lessons
-- tablosunda description_tr yoktu (learning_screen descriptionKu okuyordu).
-- Çeviri: Gemini 3.8 Flash taslağı, ana ajan denetimi (2026-10-15).
begin;
alter table public.lessons add column if not exists description_tr text;
update public.lessons set description_tr = 'Evde beslenen hayvanlar' where slug = 'ajalen-male';
update public.lessons set description_tr = 'Kır ve orman hayvanları' where slug = 'ajalen-kovi';
update public.lessons set description_tr = 'Newroz bayramı ve anlamı' where slug = 'newroz';
update public.lessons set description_tr = 'Dengbejlik sanatı' where slug = 'dengbeji';
update public.lessons set description_tr = 'Duygu isimleri ve kullanımları' where slug = 'hesten-bingehin';
update public.lessons set description_tr = 'Kurmancî harfleri ve sesleri' where slug = 'alfabe';
update public.lessons set description_tr = 'Selamlaşma ve kendini tanıtma' where slug = 'silav-u-nasin';
update public.lessons set description_tr = 'Selam, teşekkür ve vedalaşma' where slug = 'silav-u-rezdari';
update public.lessons set description_tr = 'İsim, yaş, memleket ve meslek' where slug = 'xwe-nasandin';
update public.lessons set description_tr = 'Aile bireyleri' where slug = 'malbat';
update public.lessons set description_tr = 'Temel sayılar 1-1000' where slug = 'hejmar';
update public.lessons set description_tr = 'Temel renkler ve diğer renkler' where slug = 'reng';
update public.lessons set description_tr = 'Vücudun bölümleri' where slug = 'las';
update public.lessons set description_tr = 'Günlük giysiler' where slug = 'cil';
update public.lessons set description_tr = 'Ev ve ev eşyaları' where slug = 'mal';
update public.lessons set description_tr = 'Hava nasıl?' where slug = 'hewa';
update public.lessons set description_tr = 'Kim? Ne? Nerede? Ne zaman?' where slug = 'pirs';
update public.lessons set description_tr = 'Temel fiiller' where slug = 'leker';
update public.lessons set description_tr = 'Meslek isimleri' where slug = 'pise';
update public.lessons set description_tr = 'Şehrin önemli yerleri' where slug = 'bajar';
update public.lessons set description_tr = 'Alım ve satım' where slug = 'kirin';
update public.lessons set description_tr = 'Doktor ve hastane' where slug = 'tenduristi';
update public.lessons set description_tr = 'Öğrenim yeri' where slug = 'dibistan';
update public.lessons set description_tr = 'Taşıtlar ve biletler' where slug = 'veguhestin';
update public.lessons set description_tr = 'Geçmiş zaman fiilleri' where slug = 'dema-bori';
update public.lessons set description_tr = 'Kürtlerin geleneksel yemekleri' where slug = 'xwarinen-kurdi';
update public.lessons set description_tr = 'Meyve ve sebze isimleri' where slug = 'feki-u-sebze';
update public.lessons set description_tr = 'Ünlü dağlar, nehirler ve göller' where slug = 'ciya-u-cem';
update public.lessons set description_tr = 'Temel coğrafya kelimeleri' where slug = 'cih-u-war';
update public.lessons set description_tr = 'Kişi zamirleri' where slug = 'cinavk';
update public.lessons set description_tr = 'Şimdiki zamanda olmak fiili' where slug = 'lekera-bun';
update public.lessons set description_tr = 'Haftanın yedi günü' where slug = 'rojen-hefteye';
update public.lessons set description_tr = 'Yılın dört mevsimi' where slug = 'demsal';
-- Dönüş tipine description_tr eklendi; tip değişince CREATE OR REPLACE yetmez.
-- Fazladan sütun eski istemcide zararsız: Lesson.fromJson yalnız bildiği
-- alanları okur.
drop function if exists public.load_lessons_by_category(text);
create function public.load_lessons_by_category(p_category text)
 returns table(id uuid, slug text, title_ku text, title_tr text, description_ku text, description_tr text, icon_name text, "order" integer)
 language plpgsql
 stable
 set search_path to 'public'
as $function$
begin
  return query
  select
    l.id, l.slug, l.title_ku, l.title_tr, l.description_ku, l.description_tr, l.icon_name, l.order_in_category
  from lessons l
  where l.category = p_category
  order by l.order_in_category asc;
end;
$function$;
grant execute on function public.load_lessons_by_category(text) to anon, authenticated, service_role;
do $$ begin if exists (select 1 from public.lessons where description_tr is null) then raise exception 'description_tr eksik ders var'; end if; end $$;
commit;
