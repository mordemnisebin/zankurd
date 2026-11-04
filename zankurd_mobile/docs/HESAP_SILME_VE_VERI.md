# Hesap silme ve üçüncü taraf veri temizliği

Kaynak: GPT-6 Pro alan 9 denetimi (2026-11-04). Bu belge yeni bir rapor değil,
silme zincirinin güncel işleyişi ve açık işlerdir.

## Silme zinciri (istemci → sunucu)

1. Apple ile girilmişse Apple bağlantısı iptal edilir (`apple-revoke`).
2. **Profil fotoğrafı dosyaları Storage API'siyle silinir**
   (`SupabaseZanKurdRepository.removeAllOwnAvatarObjects`): sabit
   `<uid>/avatar.jpg|png` + profildeki `avatar_url`'den çıkan zaman damgalı yol.
   Sahip, kendi klasörünü silebilir (`Users delete own avatar photos` politikası,
   `supabase/2026-07-05_avatar_showcase.sql`). Başarısızlık silmeyi durdurmaz.
3. `delete_my_account` RPC'si çağrılır (build 43 istemcileri yalnız bunu yapar).
   Sunucuda: kalan oyunculara anonim sonuç anlık görüntüsü yazılır; **bütün mevcut
   `room_result_snapshots` JSON'larında silinen kullanıcının kimliği/adı
   anonimleştirilir** (`anonymize_deleted_user_in_snapshots`, göç
   `supabase/2026-11-08_hesap_silme_yasal.sql`); veriler silinir; `auth.users`
   satırı silinir. RPC içindeki doğrudan `DELETE FROM storage.objects` YEDEK yoldur
   (fiziksel dosyayı silmez; hata verirse artık hesap silmeyi geri almaz).

## Açık iş 1: build 43 ve öncesinde artakalan avatar dosyaları

Eski istemci yalnız RPC'yi çağırır; Storage API çağrısı yapmaz. Doğrudan SQL
silmesi fiziksel dosyayı silmediği için o hesapların `avatars/<uid>/…` dosyaları
kalmış olabilir. Çözüm: servis anahtarlı (service role) bir **Edge Function /
zamanlanmış iş**: `avatars` kovasındaki üst klasörleri listele, `auth.users`'ta
karşılığı olmayan `<uid>` klasörlerinin nesnelerini Storage API `remove` ile sil.
Servis anahtarı istemciye ASLA girmez; bu yüzden istemci tarafında uygulanmadı.
Yeni istemci (bu sürüm) kendi dosyalarını RPC'den önce zaten siler.

## Açık iş 2: RevenueCat müşteri kaydı silme

`kProEnabled=false` iken yeni sürümler RevenueCat'i HİÇ başlatmaz ve hesap kimliği
göndermez (`PremiumService._configure`, `main.dart` anahtar zorunluluğu). Yani
**Pro kapalıyken yeni build'ler için silinecek RevenueCat müşteri kaydı oluşmaz.**
Önceki sürümler (build 43 ve öncesi) kimlik göndermiş olabilir; Pro açıldığında da
silme gerekir. RevenueCat müşteri silme REST API'si (`DELETE /v1/subscribers/{app_user_id}`)
**gizli (secret) API anahtarı** ister; bu anahtar istemciye konamaz, bu yüzden
istemci tarafında UYGULANMADI. Plan (TODO, sunucu fonksiyonu):

- `delete-account` Edge Function'ı (service role + RevenueCat secret key, ikisi de
  Supabase secrets): çağıranın JWT'sinden `uid` al → RevenueCat'te `uid`'i (ve
  varsa alias'larını) sil → sonucu doğrula → başarısızsa kalıcı bir
  `account_deletion_queue` satırı bırak ve yeniden dene → ardından RPC'yi çağır.
- Saklanması gereken ödeme kayıtlarının istisnası ayrı tanımlanır (mağaza/yasal).
- O zamana dek silme talebi, gizlilik sayfasında söylendiği gibi RevenueCat'e
  İLETİLİR; bu elle yapılır (RevenueCat Dashboard → Customers → Delete) ve silme
  talebi e-postasıyla (`iletisim@zankurd.com`) kayıt altına alınır.

## Harici silme sayfası (`web/delete-account.html`)

Doğrulama hesap türüne göre: e-posta/Apple/Google hesabında kayıtlı adrese
doğrulama iletisi (gönderilen adresten bağımsız; Apple gizli adresi dahil);
misafir hesabında (e-postasız) birincil yol uygulama içinden silmedir. Oyuncu
kodu (`ZK-XXXX`) hesabı bulmak içindir, tek başına silme yetkisi SAYILMAZ.
Misafir için web'den sahiplik kanıtlayan bir anahtar henüz yok (kurtarma anahtarı
özelliği ürün kararıdır; bu sürüme girmedi).

## Web dağıtımı

`web/privacy.html` ve `web/delete-account.html` değişince web yeniden dağıtılır
(`docs/HOSTINGER_DEPLOY_CHECKLIST.md`).
