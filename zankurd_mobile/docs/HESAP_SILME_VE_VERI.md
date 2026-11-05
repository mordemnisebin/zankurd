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
   satırı silinir. (2026-11-16, W4 göçü `2026-11-16_w4_apple_hesap_silme.sql`:
   RPC içindeki doğrudan `DELETE FROM storage.objects` KALDIRILDI; yalnız meta
   satırını siler, fiziksel dosya kalır ve satır gidince süpürücü dosyayı bir daha
   göremezdi. Yeni istemci klasörün gerçek içeriğini Storage API'siyle listeleyip
   siler; kalanı süpürücü siler.)
   **Apple iptali:** Apple ile girişli hesapta jeton silmeden ÖNCE iptal edilir;
   Apple başarısız olursa jeton hesapla birlikte silinmez (FK kaldırıldı), yetim
   kalır ve apple-revoke `sweep` eylemi (pg_cron, 15 dk) iptali yeniden dener.

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
`web/privacy.html` ve `web/delete-account.html` bunu açıkça söyler: dosyalar silme
sırasında uygulama tarafından kaldırılır, hata olursa en geç ~1 saat içinde süpürülür
ve o zamana dek adresi bilen biri görebilir (koşulsuz "silindi" denmez).

## Yönetim kayıtları (2026-11-18, W7 göçü)

`delete_my_account` auth.users silinmeden önce `anonymize_deleted_user_in_admin_records`
çağırır (göç `supabase/2026-11-18_w7_hesap_silme_yonetim.sql`; ⏳ = canlıda uygulanana
dek geçerli değil, `applied.md`). `admin_audit_log` (hedef/yazan kimlik sıfır-UUID,
`detail.note` atılır, `detail.label` 'Hesabê jêbirî'), `admin_reward_grants` ve
`admin_contributor_rewards` (kimlik satır başına rastgele uuid; sayılar korunur),
`user_moderation.updated_by`, `admin_settings.updated_by` anonimleşir. Pano sayaç
tablosu `usage_daily_active` zaten auth.users CASCADE ile gider. Gizlilik metni bu
davranışı söyler.

## Analitik rızası ve etkinlik sayacı (2.1.2, W7)

Rıza anahtarları cihaz geneli, yaş beyanı hesaba bağlı: yetişkin beyanı kaybolunca
(başka hesaba geçiş, çocuk beyanı, hesap silme) `AgeGate.adultLost` tetiklenir,
`AnalyticsConsentProvider` bellekteki rızayı, Firebase Analytics/Crashlytics SDK'sını
ve diskteki seçimi sıfırlar. `ActivityPing` (kişi bazlı gün+hesap satırı) yalnız
kullanım analizi açıkken yazılır; yönetim panosunun "aktif" sayıları bu yüzden
"analizi açan hesaplar" üzerindendir.

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
- O zamana dek RevenueCat kaydı hesap silinirken OTOMATİK silinmez. Gizlilik
  sayfası bunu söyler (2026-11-18): Pro hiç sunulmadığından kayıt satın alma
  bilgisi içermez; kullanıcı `iletisim@zankurd.com`'a yazarsa silme talebi elle
  iletilir (RevenueCat Dashboard → Customers → Delete) ve e-postayla kayıt altına
  alınır. Pro açılmadan önce yukarıdaki Edge Function yapılmalıdır.

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
