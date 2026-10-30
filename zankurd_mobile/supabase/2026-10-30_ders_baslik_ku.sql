-- 2026-10-30 — Alfabe dersinin Kurmancî başlığı (kurul 3 D11, Astra + Sol).
--
-- Neden: Kurmancî arayüzde ders başlığı Türkçe "Alfabe" görünüyordu
-- (title_ku = title_tr = 'Alfabe'); dersin kendi içeriği kavramı "Elîfbê"
-- diye öğretir ("• Elîfbê: Alfabe"). Yalnız title_ku değişir.
-- Koruma: slug + eski değer; doğrulama bloğu. UYGULANMADI.

begin;

update lessons set title_ku = 'Elîfbê'
 where slug = 'alfabe' and title_ku = 'Alfabe';

do $$
begin
  if exists (select 1 from lessons where slug = 'alfabe' and title_ku <> 'Elîfbê') then
    raise exception 'ders_baslik_ku: alfabe title_ku beklenen değerde değil';
  end if;
end $$;

commit;
