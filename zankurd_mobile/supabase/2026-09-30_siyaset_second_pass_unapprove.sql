-- 2026-09-30: Siyaset'te tartışmalı tanımlı ya da riskli 64 soru onaydan çıkarıldı.
--
-- NİÇİN: 2026-09-30_contested_questions_unapprove.sql'den sonra kalan
-- Siyaset soruları bağımsız bir model ailesine (ChatGPT) de okutuldu.
-- İki tür sorun çıktı: (1) RİSK — siyasi yüklü bir terime normatif tek
-- tanım ya da bir partiye ideolojik etiket (ör. "demokratik uzlaşı",
-- "anadil hakkı", parti konumu) doğru cevap diye veriliyor; (2) YANLIŞ —
-- tartışmalı bir siyaset bilimi kavramına ("radikal demokrasi",
-- "katılımcı bütçe") tek bir "doğru tanım" dayatılıyor. Bilgi yarışmasında
-- cevabı tartışılabilir soru kötü sorudur; ürün sahibinin "tartışmalıları
-- ayıkla" kararıyla aynı çizgide çıkarıldı.
--
-- Sorular SİLİNMEZ: yalnız is_approved = false. Geri alma: aynı listeyle true.
-- Uygulama: supabase db query --linked -f supabase/2026-09-30_siyaset_second_pass_unapprove.sql
begin;

with ids(id) as (values
  ('039fb235-2783-4f0a-8708-bd34fed205a2'::uuid),
  ('098ebe0e-1229-49f5-a76a-02004f17b927'::uuid),
  ('0c401c38-1277-4527-816b-28c55c9a88af'::uuid),
  ('16a08c9f-34b7-4d4d-a69a-b5446431ea22'::uuid),
  ('1aa715f3-c6f5-4fa7-aa38-9d6af0975fc0'::uuid),
  ('1b8eacbb-869a-4efa-aa8b-11b598e41e5d'::uuid),
  ('1c17c161-1db6-473a-9ad4-1a93f7e6e5d7'::uuid),
  ('25c54244-ddb8-4683-961e-2a7418875f53'::uuid),
  ('2676857d-34eb-4cec-9af0-3576b874128f'::uuid),
  ('2a75873e-f358-4080-97e9-a63b9a1f901b'::uuid),
  ('2acdd734-a5da-42a7-bffe-c62515ce1787'::uuid),
  ('32c3211f-841d-46f0-8408-56fb5ab8f924'::uuid),
  ('3b9e4752-5a4b-438f-a089-c86e280efeff'::uuid),
  ('3f3c4a4c-1414-434c-a931-146987f35c4f'::uuid),
  ('41843e84-429b-4ada-9450-3748b5fd5ffb'::uuid),
  ('418442e2-40d1-42af-b76d-87006e257ed7'::uuid),
  ('4414a24e-524b-4673-a158-032449782ce9'::uuid),
  ('4e1e9057-7d9e-4b0c-a679-592574adc783'::uuid),
  ('51875965-e96d-4a03-bf87-f7cd65a3cc45'::uuid),
  ('52b3c3f0-eee1-4ef6-ab99-29c5e257af89'::uuid),
  ('59bd0388-05d7-40df-b0e7-e8a17f7f6b00'::uuid),
  ('5b68a20b-f33b-40aa-9ee4-c1ec98fd33cc'::uuid),
  ('5c19b3e5-928d-434b-a3b4-a552964e7771'::uuid),
  ('5fc86753-e456-435b-a6b3-fc173a11a034'::uuid),
  ('60f52e97-8a3e-420f-8300-a1cf9071513d'::uuid),
  ('62162a32-a15a-45a5-af9d-cd196f3025bd'::uuid),
  ('68416028-85b0-4bd5-9dd1-c34708bd8f46'::uuid),
  ('745a2317-e00d-4570-9609-8157f49425d0'::uuid),
  ('78cc547b-68d8-4b54-9aeb-4bfbf82f433c'::uuid),
  ('7a04e3e0-08e1-443e-bc6b-8387a48d3738'::uuid),
  ('7a8f5e91-7a4f-4459-9846-43c71a96b5be'::uuid),
  ('7e4456ac-6ff8-417d-82b6-b33de7a29fc9'::uuid),
  ('7e8773ff-355f-43dd-9c75-acfb487eaf9b'::uuid),
  ('7fff2e7a-560c-4d2f-aa84-f1638ea17d72'::uuid),
  ('83af4f07-4bc7-4c0e-a2fc-f27263347249'::uuid),
  ('83d5d7eb-7a2a-48f4-85c9-d4b9fd10988e'::uuid),
  ('84b5ec0f-cb40-48ab-8f2b-8b3958d05ea5'::uuid),
  ('857af761-e8d7-47e6-9342-804c8ad0791e'::uuid),
  ('8611d6ce-5f28-402b-860d-e30e529446f5'::uuid),
  ('8a0a953c-6af5-4814-8045-ed4f0515b5bc'::uuid),
  ('8dd277a6-98c3-4f32-bf66-12c6d9127121'::uuid),
  ('8ea2f7f6-e262-4d23-b8d9-a6fd45068070'::uuid),
  ('92ea942a-9de8-4322-b0c4-93a4b7793e84'::uuid),
  ('93311d21-6a64-4a50-a575-b4547f99bda4'::uuid),
  ('95a97951-f969-4e7a-8a0d-e3c05ff8789e'::uuid),
  ('980643fd-87f0-477b-bfe5-5bac76efb28c'::uuid),
  ('9cb95d92-6be9-4219-b22e-4e5b3a0c8725'::uuid),
  ('9cecd1e0-5943-4b6c-a68f-5000fee2b747'::uuid),
  ('9e1ec1fa-7f44-43e6-b1c6-bfdd91402c7f'::uuid),
  ('a9a682c6-538b-41bb-930a-c912959ac20a'::uuid),
  ('accf8af7-9b7b-46f0-aa6f-849b54570510'::uuid),
  ('b54c3ce1-01dd-4959-93f6-8564d8726aac'::uuid),
  ('bcb8e7a8-fb66-43af-9abd-45d1b36888d8'::uuid),
  ('bd540e5f-a499-4554-84e0-8c72d1e3a692'::uuid),
  ('c3104fd0-43c7-4dbc-8aba-70486cb03bc6'::uuid),
  ('cd845196-d0cf-4702-9340-c5504161284d'::uuid),
  ('cdee2d37-6cc2-4b1b-b6b1-60087e52d45d'::uuid),
  ('cf29a5b2-741e-45b2-b972-29cddabb4fb7'::uuid),
  ('db39a82d-2cae-4dee-8e4b-d5daec872810'::uuid),
  ('e7a85ced-a398-40ec-9e5c-06943ba5a0c4'::uuid),
  ('e9ce8b70-9997-4579-a731-52a5afafff1d'::uuid),
  ('eff7f7e6-5395-48ba-8e34-fef9de7f9f07'::uuid),
  ('fa59667a-991a-4674-897f-662c9a42a610'::uuid),
  ('fcc811d3-fadf-444f-bcf0-881aa0b61d82'::uuid)
)
update public.questions q set is_approved = false
from ids where q.id = ids.id and q.is_approved;

do $$
declare v_left integer;
begin
  select count(*) into v_left from public.questions q
  where q.is_approved and q.id in (values
  ('039fb235-2783-4f0a-8708-bd34fed205a2'::uuid),
  ('098ebe0e-1229-49f5-a76a-02004f17b927'::uuid),
  ('0c401c38-1277-4527-816b-28c55c9a88af'::uuid),
  ('16a08c9f-34b7-4d4d-a69a-b5446431ea22'::uuid),
  ('1aa715f3-c6f5-4fa7-aa38-9d6af0975fc0'::uuid),
  ('1b8eacbb-869a-4efa-aa8b-11b598e41e5d'::uuid),
  ('1c17c161-1db6-473a-9ad4-1a93f7e6e5d7'::uuid),
  ('25c54244-ddb8-4683-961e-2a7418875f53'::uuid),
  ('2676857d-34eb-4cec-9af0-3576b874128f'::uuid),
  ('2a75873e-f358-4080-97e9-a63b9a1f901b'::uuid),
  ('2acdd734-a5da-42a7-bffe-c62515ce1787'::uuid),
  ('32c3211f-841d-46f0-8408-56fb5ab8f924'::uuid),
  ('3b9e4752-5a4b-438f-a089-c86e280efeff'::uuid),
  ('3f3c4a4c-1414-434c-a931-146987f35c4f'::uuid),
  ('41843e84-429b-4ada-9450-3748b5fd5ffb'::uuid),
  ('418442e2-40d1-42af-b76d-87006e257ed7'::uuid),
  ('4414a24e-524b-4673-a158-032449782ce9'::uuid),
  ('4e1e9057-7d9e-4b0c-a679-592574adc783'::uuid),
  ('51875965-e96d-4a03-bf87-f7cd65a3cc45'::uuid),
  ('52b3c3f0-eee1-4ef6-ab99-29c5e257af89'::uuid),
  ('59bd0388-05d7-40df-b0e7-e8a17f7f6b00'::uuid),
  ('5b68a20b-f33b-40aa-9ee4-c1ec98fd33cc'::uuid),
  ('5c19b3e5-928d-434b-a3b4-a552964e7771'::uuid),
  ('5fc86753-e456-435b-a6b3-fc173a11a034'::uuid),
  ('60f52e97-8a3e-420f-8300-a1cf9071513d'::uuid),
  ('62162a32-a15a-45a5-af9d-cd196f3025bd'::uuid),
  ('68416028-85b0-4bd5-9dd1-c34708bd8f46'::uuid),
  ('745a2317-e00d-4570-9609-8157f49425d0'::uuid),
  ('78cc547b-68d8-4b54-9aeb-4bfbf82f433c'::uuid),
  ('7a04e3e0-08e1-443e-bc6b-8387a48d3738'::uuid),
  ('7a8f5e91-7a4f-4459-9846-43c71a96b5be'::uuid),
  ('7e4456ac-6ff8-417d-82b6-b33de7a29fc9'::uuid),
  ('7e8773ff-355f-43dd-9c75-acfb487eaf9b'::uuid),
  ('7fff2e7a-560c-4d2f-aa84-f1638ea17d72'::uuid),
  ('83af4f07-4bc7-4c0e-a2fc-f27263347249'::uuid),
  ('83d5d7eb-7a2a-48f4-85c9-d4b9fd10988e'::uuid),
  ('84b5ec0f-cb40-48ab-8f2b-8b3958d05ea5'::uuid),
  ('857af761-e8d7-47e6-9342-804c8ad0791e'::uuid),
  ('8611d6ce-5f28-402b-860d-e30e529446f5'::uuid),
  ('8a0a953c-6af5-4814-8045-ed4f0515b5bc'::uuid),
  ('8dd277a6-98c3-4f32-bf66-12c6d9127121'::uuid),
  ('8ea2f7f6-e262-4d23-b8d9-a6fd45068070'::uuid),
  ('92ea942a-9de8-4322-b0c4-93a4b7793e84'::uuid),
  ('93311d21-6a64-4a50-a575-b4547f99bda4'::uuid),
  ('95a97951-f969-4e7a-8a0d-e3c05ff8789e'::uuid),
  ('980643fd-87f0-477b-bfe5-5bac76efb28c'::uuid),
  ('9cb95d92-6be9-4219-b22e-4e5b3a0c8725'::uuid),
  ('9cecd1e0-5943-4b6c-a68f-5000fee2b747'::uuid),
  ('9e1ec1fa-7f44-43e6-b1c6-bfdd91402c7f'::uuid),
  ('a9a682c6-538b-41bb-930a-c912959ac20a'::uuid),
  ('accf8af7-9b7b-46f0-aa6f-849b54570510'::uuid),
  ('b54c3ce1-01dd-4959-93f6-8564d8726aac'::uuid),
  ('bcb8e7a8-fb66-43af-9abd-45d1b36888d8'::uuid),
  ('bd540e5f-a499-4554-84e0-8c72d1e3a692'::uuid),
  ('c3104fd0-43c7-4dbc-8aba-70486cb03bc6'::uuid),
  ('cd845196-d0cf-4702-9340-c5504161284d'::uuid),
  ('cdee2d37-6cc2-4b1b-b6b1-60087e52d45d'::uuid),
  ('cf29a5b2-741e-45b2-b972-29cddabb4fb7'::uuid),
  ('db39a82d-2cae-4dee-8e4b-d5daec872810'::uuid),
  ('e7a85ced-a398-40ec-9e5c-06943ba5a0c4'::uuid),
  ('e9ce8b70-9997-4579-a731-52a5afafff1d'::uuid),
  ('eff7f7e6-5395-48ba-8e34-fef9de7f9f07'::uuid),
  ('fa59667a-991a-4674-897f-662c9a42a610'::uuid),
  ('fcc811d3-fadf-444f-bcf0-881aa0b61d82'::uuid)
  );
  if v_left <> 0 then
    raise exception 'siyaset ikinci tur: % soru hala onayli', v_left;
  end if;
end
$$;

commit;
