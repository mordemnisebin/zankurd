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

## Avatar kalıntıları: saatlik sunucu süpürmesi (2026-11-04)

Eski istemci (build 43) yalnız RPC'yi çağırır; RPC içindeki doğrudan SQL silmesi
fiziksel dosyayı silmez, yeni istemcide de Storage silme hatası yutulur. `avatars`
kovası herkese açıktır, bu yüzden silinmiş kullanıcıların dosyaları kalabilirdi.
Çözüm: `supabase/functions/avatar-sweep` (service role; `x-cron-secret` = CRON_SECRET,
`verify_jwt = false`). Kovanın kökündeki uuid klasörlerini sayfa sayfa listeler;
kullanıcısı `profiles` VEYA `auth.users`'ta bulunmayanların nesnelerini Storage API
ile siler. uuid olmayan klasör, kullanıcısı var olan klasör ve hata veren sayfa
ASLA silinmez; çalıştırma başına en çok 1000 nesne (kalan sonraki saat); günlüğe
yalnız sayılar yazılır. `pg_cron` işi `avatar-supurme` her saat 17. dakikada
`send-push` ile aynı Vault desenini kullanır (`avatar_sweep_url` + `cron_secret`).
Dağıtım sırası ve geri alma `supabase/applied.md` satırında. Silmeden sonra dosya
genel URL'den bir sonraki süpürmeye dek (en çok ~1 saat) erişilebilir kalabilir.

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
