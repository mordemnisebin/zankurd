begin;

update questions set
  prompt = '"Ekolojî, azadiya jinê û demokrasî" stûnên kîjan paradîgmayê ne?',
  quality_version = coalesce(quality_version, 0) + 1,
  updated_at = now()
where id = '59236644-9dbe-49c0-a4d0-16d735457ca2'
  and correct_option = 'D' and is_approved;

update questions set
  prompt = 'Di paradîgmayê de "azadiya jinê" pîvana çi tê hesibandin?',
  quality_version = coalesce(quality_version, 0) + 1,
  updated_at = now()
where id = '17e5df3d-9a75-4bc7-839b-c3d5a076492c'
  and correct_option = 'C' and is_approved;

update questions set
  prompt = 'Girîngiya Öcalan a li ser "şoreşa jinê" herî zêde çi îfade dike?',
  quality_version = coalesce(quality_version, 0) + 1,
  updated_at = now()
where id = '4280c0a5-7e53-4324-88a2-6410b8418ca1'
  and correct_option = 'A' and is_approved;

commit;
