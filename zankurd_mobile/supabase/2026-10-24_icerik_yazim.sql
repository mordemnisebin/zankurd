-- Yazım taraması (2026-10-24): «Kurmanci/Kurmancça/Kurmancicede» ve «kurmanciyeke»
-- yazımlarının sunucudaki eşleri. Sunucu yalnız Kurmancî soru metnini, şıkları
-- ve explanation_ku / explanation_tr alanlarını saklar; yerelde değişen Türkçe
-- açıklamalar explanation_tr, Kurmancî düzeltmeler (şık, explanation_ku) kendi
-- sütunundadır. Her satır (id, sütun) çiftine ve ESKİ METNE KORUMALIDIR: sunucuda
-- metin başka bir şeye dönmüşse 0 satır günceller (toplu bul-değiştir YOK).
-- Eşleme: sunucu satırı, eski yerel metnin birebir aynısını taşıyan satırdır
-- (20 satır, her biri tam bir eşleşme; salt-okunur sorguyla 2026-10-24'te doğrulandı).
--
-- Çalıştırma (uygulanmadı): supabase db query --linked -f supabase/2026-10-24_icerik_yazim.sql
-- Kuru deneme: begin…rollback ile önce; her update 1 satır (offline_2122 eşi
-- is_approved=false, yine de metni düzeltilir).

begin;

-- yerel: ds_cand_0033
update questions set
  explanation_tr = 'Dawet, Kurmancî''de evliliğin kutlandığı törendir. Bu kelime özellikle evlilik töreni için kullanılır ve Kürt kültüründe önemli bir yere sahiptir.'
where id = '78abbb10-0bc6-5e69-a7f5-8dcd76631e78'
  and explanation_tr = 'Dawet, Kurmanci''de evliliğin kutlandığı törendir. Bu kelime özellikle evlilik töreni için kullanılır ve Kürt kültüründe önemli bir yere sahiptir.';

-- yerel: ds_cand_0035
update questions set
  explanation_tr = 'Zava, Kurmancî''de evlenen kişidir. Düğünde damat özel kıyafetlerle süslenir ve birçok geleneksel uygulamada merkezi bir rol oynar.'
where id = 'af986efe-4565-5cb3-8c59-44765c19848f'
  and explanation_tr = 'Zava, Kurmanci''de evlenen kişidir. Düğünde damat özel kıyafetlerle süslenir ve birçok geleneksel uygulamada merkezi bir rol oynar.';

-- yerel: ds_muzik_0008
update questions set
  explanation_tr = 'Dengbêjlik geleneğinde kilamlar çoğunlukla Kürtçe (Kurmancî) söylenir. Türkçe, Farsça ve Arapça bu geleneğin ana dili değildir.'
where id = 'c91f3540-ce5f-5748-9c98-640ddcf85fa4'
  and explanation_tr = 'Dengbêjlik geleneğinde kilamlar çoğunlukla Kürtçe (Kurmanci) söylenir. Türkçe, Farsça ve Arapça bu geleneğin ana dili değildir.';

-- yerel: ds_muzik_0249
update questions set
  option_a = 'Ermeniyek bû ku kilamên herî kevn ên Serhed û Botanê bi kurmancîyeke resen parastin'
where id = '74d14987-404d-532d-ac54-23a6d0035f3f'
  and option_a = 'Ermeniyek bû ku kilamên herî kevn ên Serhed û Botanê bi kurmanciyeke resen parastin';

-- yerel: ds_ziman_0018
update questions set
  explanation_tr = '"Mala" dişil tekil izafedir. Kurmancîde, dişil bir isim bir sıfatla bağlandığında "-a" izafesi kullanılır. Örnek: "mala mezin" (büyük ev).'
where id = 'ae407a2a-8e39-57be-b806-228442d5cf20'
  and explanation_tr = '"Mala" dişil tekil izafedir. Kurmancicede, dişil bir isim bir sıfatla bağlandığında "-a" izafesi kullanılır. Örnek: "mala mezin" (büyük ev).';

-- yerel: ds_ziman_0028
update questions set
  explanation_tr = 'Gelecek zaman, gelecekte gerçekleşecek eylemler için kullanılır. Kurmancî''de bu zaman "ê" veya "dê" yardımcı fiili ve mastar ile kurulur, örn. "ez ê biçim" veya "ew dê bê".'
where id = '13217793-3be5-5486-a640-4dfbce8294cc'
  and explanation_tr = 'Gelecek zaman, gelecekte gerçekleşecek eylemler için kullanılır. Kurmanci''de bu zaman "ê" veya "dê" yardımcı fiili ve mastar ile kurulur, örn. "ez ê biçim" veya "ew dê bê".';

-- yerel: ds_ziman_0052
update questions set
  explanation_tr = 'Kurmancî''de, geçişli fiillerin geçmiş zamanı ergatif yapıyla kurulur. Özne oblik formdadır (min) ve nesne yalın formda kalır (zilam). Fiil de nesneyle uyumludur, bu yüzden "min zilam dît" doğrudur.'
where id = 'a3e53ee1-1bfe-5453-aeb0-f5eee97dc531'
  and explanation_tr = 'Kurmanci''de, geçişli fiillerin geçmiş zamanı ergatif yapıyla kurulur. Özne oblik formdadır (min) ve nesne yalın formda kalır (zilam). Fiil de nesneyle uyumludur, bu yüzden "min zilam dît" doğrudur.';

-- yerel: ds_ziman_0206
update questions set
  explanation_tr = '"Lezgîn" sıfatı Kürtçede (Kurmancî) hızlı ve çevik kişiler için kullanılır. "Hêdî" ve "tembel" zıttıdır, "xwerû" ise farklı bir anlama gelir.'
where id = 'ee933f3c-9662-5997-9c3f-f05be676ffef'
  and explanation_tr = '"Lezgîn" sıfatı Kürtçede (Kurmanci) hızlı ve çevik kişiler için kullanılır. "Hêdî" ve "tembel" zıttıdır, "xwerû" ise farklı bir anlama gelir.';

-- yerel: ds_ziman_0256
update questions set
  explanation_tr = '"Çavên xwe vekirin" Kurmancî''de mecazi anlamda uyanık olmak veya dikkatli olmak demektir. Bu deyim, gözleri açmanın gerçek anlamıyla ilgili değildir.'
where id = '1b8e0a84-0705-543f-bec6-db95ab55f81f'
  and explanation_tr = '"Çavên xwe vekirin" Kurmanci''de mecazi anlamda uyanık olmak veya dikkatli olmak demektir. Bu deyim, gözleri açmanın gerçek anlamıyla ilgili değildir.';

-- yerel: ds_ziman_0257
update questions set
  explanation_tr = '"Xwe avêtin ber bayî" Kurmancî''de kaderine razı olmak veya kendini kaderine bırakmak anlamına gelir. Bu deyim, kendini atmanın gerçek anlamıyla ilgili değildir.'
where id = '6de8d265-d6fb-533e-b6cd-ad4d3ceafa37'
  and explanation_tr = '"Xwe avêtin ber bayî" Kurmanci''de kaderine razı olmak veya kendini kaderine bırakmak anlamına gelir. Bu deyim, kendini atmanın gerçek anlamıyla ilgili değildir.';

-- yerel: ds_ziman_0266
update questions set
  explanation_tr = '"Devê xwe vekirin" Kurmancî''de mecazi anlamda konuşmak veya konuşmaya başlamak demektir. Bu deyim, ağzını açmanın gerçek anlamıyla ilgili değildir.'
where id = '6f8d52ec-5dcc-58a2-b5f5-0876acd5e481'
  and explanation_tr = '"Devê xwe vekirin" Kurmanci''de mecazi anlamda konuşmak veya konuşmaya başlamak demektir. Bu deyim, ağzını açmanın gerçek anlamıyla ilgili değildir.';

-- yerel: ds_ziman_0272
update questions set
  explanation_tr = '"Devê xwe girtin" Kurmancî''de mecazi anlamda sessiz olmak veya konuşmamak demektir. Bu deyim, ağzını kapatmanın gerçek anlamıyla ilgili değildir.'
where id = '1b1b7fb6-ef29-564d-b64b-cf3cc7f771e4'
  and explanation_tr = '"Devê xwe girtin" Kurmanci''de mecazi anlamda sessiz olmak veya konuşmamak demektir. Bu deyim, ağzını kapatmanın gerçek anlamıyla ilgili değildir.';

-- yerel: ds_ziman_0292
update questions set
  explanation_tr = 'Kurmancîde "kengî" kelimesi zamanı sormak için kullanılır ve geçmiş zaman da buna dahildir. "Çi" nesneler için, "kî" kişiler için ve "çima" sebep için kullanılır.'
where id = '8d31b1e7-941f-5dce-8ef3-3dc9ef4462e2'
  and explanation_tr = 'Kurmanccada "kengî" kelimesi zamanı sormak için kullanılır ve geçmiş zaman da buna dahildir. "Çi" nesneler için, "kî" kişiler için ve "çima" sebep için kullanılır.';

-- yerel: edit_ziman_0019
update questions set
  explanation_ku = 'Hawar di 1932an de li Şamê dest pê kir û alfabeya kurdî ya latînî belav kir. Bi xebatên xwe yên zimanî ew bû dibistana Kurmancîya nûjen.'
where id = '35d6e71b-ca12-59a4-b378-fa71da37c752'
  and explanation_ku = 'Hawar di 1932an de li Şamê dest pê kir û alfabeya kurdî ya latînî belav kir. Bi xebatên xwe yên zimanî ew bû dibistana Kurmanciya nûjen.';

-- yerel: hat_0025
update questions set
  explanation_tr = 'Bu eser 1692 yılında uzun bir mesnevi olarak yazılmış ve Kurmancî edebiyatının simgesi olmuştur.'
where id = 'de7496bc-19ae-52c2-932d-92d4d73c5407'
  and explanation_tr = 'Bu eser 1692 yılında uzun bir mesnevi olarak yazılmış ve Kurmanci edebiyatının simgesi olmuştur.';

-- yerel: hat_0028
update questions set
  explanation_tr = 'Bu eser Arapça-Kurmancî bir sözlüktür ve "Mem û Zîn"in yazarı tarafından kaleme alınmıştır.'
where id = '672e9e72-58b5-56ce-a45f-3aca1f4cd1a2'
  and explanation_tr = 'Bu eser Arapça-Kurmanci bir sözlüktür ve "Mem û Zîn"in yazarı tarafından kaleme alınmıştır.';

-- yerel: offline_2122
update questions set
  explanation_tr = 'Bugün kullanılan Latin temelli Kurmancî alfabesini Bedirxan düzenledi.'
where id = '4a484b38-5b44-47e1-a208-ec138afc7a07'
  and explanation_tr = 'Bugün kullanılan Latin temelli Kurmanci alfabesini Bedirxan düzenledi.';

-- yerel: offline_2674
update questions set
  explanation_tr = 'Cigerxwîn en tanınmış Kürt şairlerindendir ve şiirlerinin büyük bölümünü Kurmancî yazmıştır; özgürlük ve halk yaşamı şiirlerinin başlıca temalarındandır.'
where id = 'a6852f09-771c-574f-818a-cddc222eb46d'
  and explanation_tr = 'Cigerxwîn en tanınmış Kürt şairlerindendir ve şiirlerinin büyük bölümünü Kurmanci yazmıştır; özgürlük ve halk yaşamı şiirlerinin başlıca temalarındandır.';

-- yerel: offline_2699
update questions set
  explanation_tr = 'Mehmed Uzun modern Kürt romanının kurucularından sayılır; uzun yıllar İsveçte sürgünde yaşamasına rağmen eserlerinin çoğunu Kurmancî yazmıştır.'
where id = '386c015e-da07-5084-862b-27285a900089'
  and explanation_tr = 'Mehmed Uzun modern Kürt romanının kurucularından sayılır; uzun yıllar İsveçte sürgünde yaşamasına rağmen eserlerinin çoğunu Kurmanci yazmıştır.';

-- yerel: offline_tf_cog_0067
update questions set
  explanation_tr = 'Doğru. Behdinan, Duhok çevresindeki bölgedir ve behdinî bu bölgede konuşulan Kurmancî ağzıdır; lehçenin adı bu bölgeden gelir.'
where id = '48a9f9f0-3eb7-58e3-8a0b-469815b2cead'
  and explanation_tr = 'Doğru. Behdinan, Duhok çevresindeki bölgedir ve behdinî bu bölgede konuşulan Kurmancça ağzıdır; lehçenin adı bu bölgeden gelir.';

do $$
declare n int;
begin
  select count(*) into n from questions
   where id in ('78abbb10-0bc6-5e69-a7f5-8dcd76631e78', 'af986efe-4565-5cb3-8c59-44765c19848f', 'c91f3540-ce5f-5748-9c98-640ddcf85fa4', '74d14987-404d-532d-ac54-23a6d0035f3f', 'ae407a2a-8e39-57be-b806-228442d5cf20', '13217793-3be5-5486-a640-4dfbce8294cc', 'a3e53ee1-1bfe-5453-aeb0-f5eee97dc531', 'ee933f3c-9662-5997-9c3f-f05be676ffef', '1b8e0a84-0705-543f-bec6-db95ab55f81f', '6de8d265-d6fb-533e-b6cd-ad4d3ceafa37', '6f8d52ec-5dcc-58a2-b5f5-0876acd5e481', '1b1b7fb6-ef29-564d-b64b-cf3cc7f771e4', '8d31b1e7-941f-5dce-8ef3-3dc9ef4462e2', '35d6e71b-ca12-59a4-b378-fa71da37c752', 'de7496bc-19ae-52c2-932d-92d4d73c5407', '672e9e72-58b5-56ce-a45f-3aca1f4cd1a2', '4a484b38-5b44-47e1-a208-ec138afc7a07', 'a6852f09-771c-574f-818a-cddc222eb46d', '386c015e-da07-5084-862b-27285a900089', '48a9f9f0-3eb7-58e3-8a0b-469815b2cead')
     and (explanation_tr ~ 'Kurmanc(i|ça|ca|icede|cca)(?![a-zçşğıöüâêîû])'
          or option_a = 'Ermeniyek bû ku kilamên herî kevn ên Serhed û Botanê bi kurmanciyeke resen parastin'
          or explanation_ku ~ 'Kurmanciya');
  if n <> 0 then
    raise exception 'beklenen 0 eski yazım kaldı, bulunan %', n;
  end if;
end $$;

commit;
