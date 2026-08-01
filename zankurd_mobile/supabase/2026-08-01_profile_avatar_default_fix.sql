-- Yeni profillerin avatar varsayılanını uygulamanın marka paletiyle eşitle.
--
-- Kök şemadaki eski varsayılan `#177a56` küçük harf içeriyordu. Profil
-- güvenlik trigger'ı yalnız büyük harfli #RRGGBB biçimini kabul ettiği için
-- avatar_color göndermeyen yeni kullanıcı kayıtları `Invalid avatar color`
-- ile geri alınıyordu.

begin;

alter table public.profiles
  alter column avatar_color set default '#2E9E93';

-- Eski varsayılanla oluşmuş satırları da uygulamanın geçerli paletine getir.
-- Güncelleme trigger'ın mevcut biçim kontrolünden geçer; trigger kaldırılmaz
-- ve renk doğrulaması gevşetilmez.
update public.profiles
set avatar_color = '#2E9E93'
where lower(btrim(avatar_color)) = '#177a56';

commit;
