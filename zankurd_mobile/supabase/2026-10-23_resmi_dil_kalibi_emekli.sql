-- Wikidata "resmî dil" kalıbındaki 7 soru yayından kalkar (2026-10-23).
--
-- Niçin: 2.1.0'ın ilk gecesinde "Kîjan ziman wekî zimanekî fermî an neteweyî
-- bi Tanzanya re tê girêdan?" sorusunu 4 kişinin 4'ü de yanlış yaptı. Kalıp
-- otomatik üretilmiş: şıklar İngilizce ("English", "Spanish", "Hebrew"),
-- çeldiriciler her soruda aynı ("Bobo", "Dogon", "Spanish"), Tanzanya'da asıl
-- dil Svahili şıklarda yok. Kalıbın 7 sorusunun hepsi aynı kusurda; onaylı
-- havuzda başka "Bobo/Dogon" çeldiricili soru yok.
--
-- Ne yapar: yalnız bu kalıbın satırlarını is_approved=false yapar; satır
-- silinmez, geri almak için aynı WHERE ile true yapılır.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-23_resmi_dil_kalibi_emekli.sql

begin;

update public.questions
set is_approved = false,
    updated_at = now()
where is_approved
  and prompt like 'Kîjan ziman wekî zimanekî fermî an neteweyî bi % re tê girêdan?'
  and ('Bobo' in (option_a, option_b, option_c, option_d)
       or 'Dogon' in (option_a, option_b, option_c, option_d));

-- Doğrulama: kalıpta onaylı satır 0, toplam onaylı 4217 - 7 = 4210.
select
  (select count(*) from public.questions
    where is_approved
      and prompt like 'Kîjan ziman wekî zimanekî fermî an neteweyî bi % re tê girêdan?') as kalip_onayli,
  (select count(*) from public.questions where is_approved) as onayli_toplam;

commit;
