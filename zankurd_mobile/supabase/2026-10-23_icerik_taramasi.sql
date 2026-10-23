-- Soru kalitesi taraması: paket sorularında değişen metinlerin sunucu eşleri
-- (2026-10-23). Satırlar yerel kimliğin uuid5'iyle eşlenir
-- (bkz. test/local_parity_server_sync_test.dart). Eşi olmayan id'ler 0 satır
-- günceller; zararsız. Aynı tarama canlıda metin+şık eşleşmesiyle de
-- uygulanmıştı (84 satır); bu dosya kaydı ve eksik kalan eşleri tamamlar.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-23_icerik_taramasi.sql

begin;

update questions set
  prompt = 'Piştî meha rojiyê kîjan cejn tê?'
where id = '55a96a24-61a7-5a4a-b7b5-b078a596c575';

update questions set
  prompt = 'Di ___ de ajal wekî ayîn têne serjêkirin.'
where id = '6938d316-8c69-5a70-9972-97530df8e9a1';

update questions set
  prompt = 'Di alfabeya kurdî ya latînî de çend dengdêr hene?'
where id = '2b5b3057-0fc4-52af-9de7-cd6d5f728437';

update questions set
  prompt = 'Nîşana pirjimariyê ya rewşa tewandî di Kurmancî de kîjan e?'
where id = '8600cd83-25fd-5d3b-bd2b-04263beedf0d';

update questions set
  prompt = 'Di Kurmancî de "daçek" çi ye?'
where id = '34b37f94-781f-510f-bb60-5df823f2c448';

update questions set
  prompt = 'Di Kurmancî de "raweya bilanî" bi kîjan pêşgirê tê çêkirin?'
where id = '89979f9b-0c27-5e5e-8576-89d9b9b3f0ed';

update questions set
  prompt = 'Deşta Herîrê li Başûrê Kurdistanê bi giştî bi çi tê nasîn?'
where id = 'e5e23b53-d06e-5ba9-b71b-fa48f5d4005d';

update questions set
  prompt = 'Hejmara dehanî 13 di pergala duyî de çawa tê nivîsandin?'
where id = '81687d91-d4c9-50cf-abf2-412e5705f22f';

update questions set
  prompt = 'Nirxa dehanî ya hejmara dualî 11111111 çi ye?'
where id = '7563411b-f174-5410-82ba-b3a74cebe9f9';

update questions set
  prompt = 'Têgeha derengiyê (latency) di torê de çi dipîve?'
where id = 'bfbfe16a-2e21-5509-83f0-108534fae711';

update questions set
  prompt = 'Pîla yekem a ku di sala 1800î de cereyanek berdewam da kê çêkir?'
where id = '0d92b182-62d4-5955-8a23-01cb9403a27f';

update questions set
  prompt = 'Neyîniya "ez dizanim" çi ye?'
where id = '40e900eb-7226-5c76-9765-d79d77f38699';

update questions set
  prompt = 'Fermana lêkera "hatin" çi ye?'
where id = '60eb87b3-b88e-5ce0-923a-72f22bd653c8';

update questions set
  prompt = 'Vexwarina ji cureyê doogh bi kîjan madeya sereke re têkildar e?'
where id = 'fcb965f9-eb86-5f64-b593-f492adf19ffe';

update questions set
  prompt = 'Peyva "heft" bi tirkî kîjan hejmar e?'
where id = 'e79ac27e-2ddd-5e23-9aa2-c09428fc74ea';

update questions set
  prompt = 'Peyva "bîst" bi tirkî çi ye?'
where id = 'eb0b8a38-657d-5193-b8c5-e2206076fc59';

update questions set
  prompt = 'Peyva "zer" bi tirkî kîjan reng e?'
where id = '553191dc-92cc-5a91-9e76-be13f0cc6515';

update questions set
  prompt = '"destan" kîjan cureyê vegotinê ye?'
where id = '72902832-220c-59b6-b67c-159b2b3870da';

update questions set
  prompt = 'Cînavkên wekî "min, te, wî, wê, me, we, wan" çi ne?'
where id = '38fbf109-6c46-570f-83ed-9e1125dc2beb';

update questions set
  prompt = 'Cînavkên wekî "ez, tu, ew, em, hûn, ew" çi ne?'
where id = '3a4274cb-5e1a-5101-b418-3c3ac192d9e1';

update questions set
  prompt = 'Geliyê kûr û teng ê ku ava wî ya hov ber bi başûr, ber bi Dîcleyê ve diherike, kîjan e?'
where id = 'f97a2f0c-70ac-53db-9565-7d29204ca7ce';

update questions set
  prompt = 'Tiştoka "Reng spî ye lê ne berf e, tê xwarin lê ne heywan e, tama wê şor e" bersiva wê çi ye?'
where id = 'f0e683ae-9592-5c40-b5a2-7cf08d42b4c9';

update questions set
  prompt = '"Veqetandina hêzan" ew zanîn e ku mirov beşek ji xwezayê ye, ne xwediyê wê ye. Ev rast e an şaş e?'
where id = '8d5af883-de8a-50a0-ab3e-36fbddc79c97';

update questions set
  prompt = 'Pêşbaziya fermî cara yekem di kîjan salê de ket nav Festîvala Fîlman a Venedîkê?'
where id = '7dfcc320-fd6b-5fa8-b26b-b4bb15ccb900';

-- Emekli (retired_question_ids.dart): sunucu eşi de oyundan çıkar.
update public.questions set is_approved = false, updated_at = now() where id = '66f2e690-67aa-5624-b0c9-ecd26dee105e'; -- offline_2818
update public.questions set is_approved = false, updated_at = now() where id = '2b5b3057-0fc4-52af-9de7-cd6d5f728437'; -- edit_ziman_0003

commit;
