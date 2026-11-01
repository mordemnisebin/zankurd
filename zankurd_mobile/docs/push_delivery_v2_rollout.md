# Push V2 kurulumu ve yerel doğrulama

## 1 Kasım 2026 — G15 yerel kapalı geçiş kanıtı

**G15 canlı geçişi tamamlanmadı.** Bu görevde canlı veritabanına bağlanılmadı,
canlı tanımlar yeniden alınmadı, SQL uygulanmadı, Edge/cron dağıtılmadı ve
fiziksel cihazda FCM/APNs teslimatı yapılmadı. Aşağıdaki eski 31 Ekim kayıtları
bu görevin canlı doğrulama kanıtı değildir. Uygulama istemcisinin mevcut
sunucuyla çalışma sözleşmesi değişmedi; sender V2 yokken V1'e dönmemelidir.

Mevcut `2026-10-31_push_delivery_v2.sql` adayı ve lease/ack göndericisi
korundu. Yeni `2026-11-01_push_delivery_v2_closed_cutover.sql` bu adaydan
**sonra** uygulanacak idempotent bir kapalı geçiştir: kapıyı kapatır, V1 cron'u
pasifleştirir ve V1 claim RPC yetkisini PUBLIC/anon/authenticated/service_role
rollerinden kaldırır. Böylece cron dışındaki eski gönderici yeni işleri
`claimed_at` ile sessizce tüketemez. V1 fonksiyon gövdesi yeniden yazılmaz;
eski/legacy işlerin başarı durumu bilinmediği için replay yapılmaz. Rol
mirası/sahiplik nedeniyle V1 yetkisi açık kalırsa transaction hata verir.

`supabase/geri_al/2026-11-01_push_delivery_v2_closed_cutover.sql` tam şema
veya ACL geri dönüşü değil, **güvenli geri durdurmadır**. Kapıyı kapatır,
V1 tüketimini kapalı ve lease/ack kayıtlarını korur. Eski worker'a yetkiyi
ve cron'u geri açmak ayrı canlı inceleme ve açık sahip onayı gerektirir.
Devam eden FCM/ack çağrısını bu SQL iptal etmez; dağıtımda eski göndericilerin
sonlanması ve iki dakikalık bekleme ayrıca gerekir.

Yalnız bellekte PGlite PostgreSQL 17.5 ile sentetik yerel şema kullanıldı.
Vault/cron/net arayüzleri yerel taklitlerdi, hiçbir dış HTTP isteği çıkmadı.
`tool/test_push_delivery_v2_local.mjs` şu sonuçları üretti:

- Önce V2 adayı tek başınayken bekçi kırmızı: service_role V1 claim yetkisi
  açıktı. Önceki cron testi bu manuel worker yolunu kapsamıyordu.
- Mevcut `2026-10-31_push_delivery_v2_smoke.sql` bütünü geçti: iş alımı sonrası
  kesinti/lease kurtarma, eski lease reddi, retry gecikmesi ve ack idempotency.
- Yeni göç ve geri durdurma ayrı ayrı iki kez geçti. Üç rolde gerçek V1 RPC
  çağrısı `permission denied` verdi; V2 worker yetkisi korundu; kapı kapalı
  kaldı. Kuyruk, profiller, engeller ve tetikleyici durumu korundu.
- Deno gönderici testleri **13/13**, Python gönderici testleri **10/10** geçti.
  Python SQL sözleşmesinde **4 test geçti, 1 pglast testi açıkça atlandı**;
  SQL'nin gerçek parse/çalışma denetimi yukarıdaki PGlite provasında yapıldı.
- Tam Flutter CI ve Dart sözleşme bekçisi ana görevde ayrıca doğrulanır;
  burada canlı dağıtım veya fiziksel teslimat sonucu olarak sunulmaz.

Tekrar çalıştırma (ikinci argüman mevcut yerel PGlite modül dosyasıdır;
komut paket indirmez, ağ veya bağlantı dizesi almaz):

```sh
node tool/test_push_delivery_v2_local.mjs /yerel/pglite/dist/index.js
```

**Canlıya uygulanmadı.** Push V2 göçünün tamamı, teslimat duman testi ve oda daveti duman testi PGlite PostgreSQL 17.5 üzerinde geçti. 31 Ekim tarihli canlı `invite_friends_to_room`, `list_my_room_invites` ve `claim_push_outbox` tanımlarıyla iki duman testi de tekrar geçti. Teslimat testi sonunda kuyruk, tercihler, engeller, kapı ve tetikleyici önceki durumuna döndü. İlk yerel testte cron, Vault ve pg_net arayüzleri taklit edildi. Ardından izole Supabase Docker ortamında gerçek pg_cron, Vault ve pg_net ile iki rollback duman testi ve HTTP uyandırma zinciri de geçti. Gerçek FCM/APNs ve fiziksel cihaz teslimatı bu provanın dışında kaldı. Bu dosyadaki canlı yazma/deploy/etkinleştirme adımları sahibin ayrıca onayını gerektirir.

## Ön inceleme (salt okunur)

31 Ekim 2026 tarihinde bağlantılı projenin kataloğunda V1 gönderim işi
etkindi. V2 claim, ücretli davet listesi ve kimlikli davet sorgusu henüz
kurulmamıştı. Adayın beklediği 14 sütunun türü eşleşti. pg_net ve cron
işlev imzaları bulundu. İki Vault adı da birer kez kayıtlıydı. Gizli
değerler seçilmedi. Mac'teki eski launchd göndericisi yüklü görünmüyordu.

Son yedi gün için toplu kuyruk ölçümü:

| İş | Toplam | Süre sınırında veya sonrasında kapanan | Ölçüm anında alıcının token'ı boş |
|---|---:|---:|---:|
| Oda daveti | 72 | 57 | 44 |
| Arkadaşlık isteği | 20 | 14 | 12 |
| Arkadaşlık kabulü | 17 | 5 | 3 |

Süre sınırı oda için 30 dakika, diğer iki tür için 24 saattir. İki kapanmamış
arkadaşlık isteği toplam sayıya dahildir. Son iki sütun kesişebilir.
V1 süresi dolan işleri de `claimed_at` ile kapatır. Bu ölçümden telefona
teslim oranı veya geçmişteki token durumu hesaplanamaz.

Canlı katalogdan okunan üç işlevin gövdeleri yerel veritabanına yüklendi.
Push V2, hedefli davet ve oda koşulları göçleriyle iki rollback dumanı
PGlite PostgreSQL 17.5 üzerinde geçti. Yerel PostgreSQL 17.11'de iki ayrı
oturum aynı odaya eşzamanlı davet yolladığında ikinci oturum kilitte bekledi.
Alıcı sırası ters çevrildiğinde de alıcı başına tek davet ve tek iş oluştu.
Gönderim kapısı kapalıyken iş alınmadı. Bu deneylerde dış FCM çağrısı
yapılmadı. Gemini 4 Argon V2 SQL ve geçiş sıralamasını ayrıca inceledi.

Migration mevcut `claim_push_outbox`, arkadaşlık, düello ve oda işlevlerini değiştirmez. Yeni bir worker sözleşmesi ekler. Aşağıdaki yerel kaynaklar inceleme kanıtıdır; canlı tanım oldukları varsayılmaz:

- `supabase/2026-10-24_bildirim_seri_eposta.sql`: claim B1; push_social/push_duel, oda30dk/diğer24saat, iki yönde engel, token yoksa bekleme.
- `supabase/2026-10-24_sunucu_sertlestirme.sql`: from_user_id ve engel sınırı.
- `supabase/2026-10-13_push_delivery.sql`: mevcut Vault adları send_push_url/cron_secret.

Uygulamadan önce canlı SQL tanımı ve sütunları incele. Gizli değer veya token seçme:

```sql
select pg_get_functiondef('public.claim_push_outbox(integer)'::regprocedure);
select table_name,column_name,data_type,is_nullable,column_default
from information_schema.columns
where table_schema='public'
  and table_name in ('push_outbox','profiles','blocked_users')
  and column_name in ('id','to_user_id','from_user_id','kind','title','body',
    'created_at','claimed_at','fcm_token','push_social','push_duel',
    'blocker_id','blocked_id','data','claim_token','delivery_status')
order by table_name,ordinal_position;
select jobid,jobname,schedule,active from cron.job
where jobname in ('send-push','send-push-v2');
select name,count(*) from vault.decrypted_secrets
where name in ('send_push_url','cron_secret') group by name;
```

Canlı claim'e sonradan eklenmiş başka gizlilik/yaş/engelleme koşulu varsa önce V2'ye taşı ve tekrar incelet. Migration içindeki alan türü ve gövde işareti kontrolü tam canlı diff değildir. `data` veya V2 nesneleri zaten varsa ilk kurulum durur; kör `IF NOT EXISTS` ile devam etme. Vault adları tekil, URL doğru Edge endpoint'i ve cron_secret Edge CRON_SECRET ile eşleşmiş olmalı; sırları çıktıya yazma.

## Sözleşme

`claim_push_outbox_v2(p_limit integer default20)` en çok20 iş verir: job_id, to_user_id, kind, title, body, fcm_token, claim_token, attempt_count, data, expires_at. expires_at kuyruk created_at + oda30dk/diğer24saat değeridir; retry bunu uzatmaz. Gönderici FCM öncesi mutlak ömrü denetler; süresi dolan işi skipped ack eder. Android TTL tür tavanı (oda300sn/diğer86400sn) ile kalan ömrün küçüğüdür; APNs expiration aynı mutlak sınırı aşmaz. Lease120sn; expired lease yeni token ile tekrar alınır. `from_user_id` varsa data'ya yalnız gerçek sütundan eklenir; kimlikli oda işlerinde gerçek davet ve oda kimliği korunur. Yeniden verilen veya kapanan davetin bekleyen işi claim sırasında elenir.

`finish_push_outbox(p_job_id uuid,p_claim_token uuid,p_outcome text,p_error_code text default null,p_retry_after_seconds integer default null)` boolean döner. sent/skipped/failed terminal; retry gecikmesi saklanır. Sekizinci denemede retry terminal failed olur. Aynı token ve aynı outcome yeniden ack edilirse true; farklı outcome, eski token veya süresi geçmiş etkin lease false. `last_outcome` bu idempotency için tutulur. Gate kapalı olsa bile daha önce alınmış işin ack'i tamamlanabilir.

Eski claimed satırlar `legacy` olur. Kurulum sırasında hâlâ çalışan eski worker sonradan claim yaparsa claim_token null kalır; V2 bunu da tekrar göndermez. Eski worker V2 işlerini claimed_at nedeniyle seçemez. Legacy satırların geçmiş başarısı bilinmediğinden otomatik replay yok.

Gate kapalıyken claim boş, insert wake ve recovery cron no-op olur. Migration eski send-push cron'unu pasif yapar. Yeni trigger INSERT statement başına bir wake kuyruğa alır; HTTP istekleri commit sonrasında başlar. Net/Vault hatası arkadaşlık/oda işlemini bozamaz; dakika cron'u yeniden dener.

İlk token kaydı, alıcının bekleyen bir işi varsa göndericiyi uyandırır. Sorgu alıcı ve vade indeksini kullanır. Süresi dolan, engellenen, yeniden deneme vadesi gelmeyen veya hâlâ başka bir göndericide olan işler bu çağrıyı tetiklemez. Token yenilemesi ve aynı token’ın tekrar kaydı ek çağrı üretmez. PostgreSQL 17.11 denemesinde geçerli kimlikli davet bir çağrı üretti. 10.000 ilgisiz iş varken sorgu planı alıcı/vade indeksini seçti. Göndericiye yapay hata verildiğinde token kaydı korundu.

FCM ile Postgres ack arasında atomik işlem yoktur. FCM kabulünden sonra süreç ölürse lease sonunda nadir tekrar mümkündür. Göndericideki job_id sabittir; başarılı gönderimin ack hatası retry outcome'a çevrilmez.

## Yerel kontroller

31 Ekim’de `tool/ci_yerel.sh --tam` başarıyla tamamlandı. Dart analizinde bulgu çıkmadı. Ana test paketinde 7607 test geçti, 3 test atlandı. Ekran turunun 214 testi ve cihazsız 4 uygulama senaryosu da geçti.

```sh
deno check supabase/functions/send-push/index.ts
deno test supabase/functions/send-push/lib_test.ts
python3 -m unittest discover -s tool -p 'test_send_push_outbox.py'
python3 -m unittest discover -s tool -p 'test_push_delivery_v2_sql.py'
```

Son komut pglast kuruluysa PostgreSQL parser'ını da çalıştırır; yoksa o test açıkça skip olur. Bunlar ağ veya canlı bağlantı kullanmaz.

SQL smoke yalnız tek kullanımlık **yerel Supabase/test DB** içindir. Önce migration'ı o yerel DB'ye kur; en az iki test profili bulunsun. Yerel SQL oturumunda `SET zankurd.test_database = 'local-only';` verip `supabase/2026-10-31_push_delivery_v2_smoke.sql` dosyasını çalıştır. Script loopback/Unix bağlantısı ve kapalı gate arar, wake tetikleyicisini transaction içinde kapatır ve sonunda ROLLBACK yapar. Davet hedefi göçünden sonra aynı yerel oturumda `supabase/2026-10-31_room_invite_push_target_smoke.sql` dosyasını da çalıştır. Bu test üreticinin tekil işini, geri çekilmiş daveti, alıcı yetkisini ve claim kimliğini denetler. Canlı bağlantıda çalıştırma. Gerçek pg_net/FCM çağrısı üretmez.

Teslimat testi başarı ve tekrar onayını, yeniden deneme gecikmesini, eski lease ile gelen yanıtları, yarıda kalan işin kurtarılmasını, tokensuz beklemeyi, tercihleri, iki yönlü engeli, 30 dakika ve 24 saatlik süre sınırlarını, eski göndericinin kapsamını ve sekizinci denemeyi kontrol eder.

31 Ekim’de gerçek `send-push/index.ts` HTTP girişi yerel OAuth, PostgREST ve FCM uçlarıyla çağrıldı. Altı kontrol geçti. Başarılı istekte iş, oda ve davet kimlikleri ile kalan 300 saniyelik süre FCM isteğine taşındı. Gönderici sonucu aynı lease ile kaydetti. FCM 503 döndüğünde 90 saniyelik bekleme ile yeniden deneme kaydedildi. OAuth hatasında kuyruktan iş alınmadı. Geçersiz iş verisi veya yanlış cron anahtarı gönderim üretmedi.

31 Ekim’de ayrı 554xx portlarında yeni bir Supabase Docker projesi açıldı. Gerçek pg_cron 1.6.4, pg_net 0.20.3 ve Vault 0.3.1 üzerinde Push V2 → hedefli davet → oda koşulları göçleri uygulandı; iki repository rollback duman testi geçti. Alan tabloları ve oyuncular sentetikti, üç mevcut işlevin daha önce salt okunur alınmış canlı tanımı kullanıldı. Vault’a yalnız yerel sentetik değerler kondu; HTTP hedefi sadece bu projenin Docker ağı içindeki test sunucusuydu. Canlı Supabase veya Google FCM çağrısı yapılmadı.

Bu provada V1 cron’un pasifleşmesi ve V2’nin özgün dakika takvimi doğrulandı. Kapalı kapı claim/HTTP üretmedi; ROLLBACK edilen pg_net çağrısı gitmedi, COMMIT edilen çağrı ulaştı. İlk token tek HTTP çağrısı üretti; aynı token ve token yenilemesi çağrı üretmedi. Gerçek dakika cron’u üçüncü çağrıyı gönderdi ve başarılı çalışma kaydı bıraktı. Üç isteğin sentetik kimlik doğrulaması ve JSON gövdesi doğrulandı. Sonunda yalnız bu geçici projenin servisleri ve test hedefi durduruldu. Edge HTTP girişinin altı senaryolu ayrı provası yukarıdadır; bu Docker provası FCM teslimatını kanıtlamaz.

Flutter istemcisinde token yenileme olayı, Firebase’in o anda verdiği değeri doğrudan kaydeder. Eşzamanlı başka bir okuma boş döner veya hata verirse geçerli token sırasını korur. İstemcinin token eşitlemesine yönelik 35 test geçti.

iOS 26.5 simülatöründe kurulu 2.1.1 (41) sürümüne, uygulama kapalıyken yerel `simctl push` ile sentetik oda daveti verildi. SpringBoard kaydı, bildirimin Bildirim Merkezi listesinin başına eklendiğini ve banner için iletildiğini gösterdi. Fiziksel telefonda FCM/APNs teslimatı ve bildirime dokunarak ilgili odayı açma adımı henüz denenmedi.

31 Ekim’de yerel PostgreSQL 17.11 üzerinde iki ayrı oturum aynı oda için eşzamanlı davet gönderdi. Tek alıcıda ve iki alıcının ters sırayla verildiği durumda `pg_blocking_pids` ikinci işlemin birinciyi beklediğini doğruladı. İki işlem de tamamlandı ve her alıcı için tek davet kimliğiyle tek iş oluştu. Kapı kapalıyken üç iş bekledi, açılınca her biri bir kez alındı. Test kümesi yalnız Unix soketinde çalıştı ve işlem sonunda kaldırıldı.

## Onaydan sonraki sıralama

1. Canlı tanım/şema incelemesini ve yerel smoke'u tamamla; bağımsız kod incelemesini kapat.
2. Uygulama öncesi eski Mac göndericisinin kapalı olduğunu tekrar kontrol et.
   Sahibin onayıyla önce `2026-10-31_push_delivery_v2.sql`, hemen ardından
   `2026-11-01_push_delivery_v2_closed_cutover.sql`, sonra
   `2026-10-31_room_invite_push_target.sql` ve
   `2026-10-31_room_invite_terms.sql` uygulanır. Sonuncusu Ana ve Yarış
   kartlarına ücreti ve süreyi sağlar. Gövde farkını uygulama anında yeniden
   kontrol et. Kapı kapalı, eski cron pasif kalır. Oda oluşturma sınırlarının
   ayrı göçü ve geri alma koşulları `room_limits_rollout_2026_10_31.md`
   içindedir. Uygulanan dosyaları başarıları doğrulandıkça
   `supabase/applied.md` içinde işaretle.
3. Eski Edge çağrılarının bitmesi için en az iki dakika bekle; eski cron'un hâlâ pasif olduğunu doğrula.
4. Sahibin onayıyla V2 Edge Function'ı dağıt; kimlik doğrulama, OAuth ve boş/kapalı kuyruk kontrolünü yap. Yeni Python yedek de yalnız V2 RPC'yi kullanır.
5. Sahibin onayı migration, Edge dağıtımı ve etkinleştirmeyi birlikte kapsıyorsa
   doğrulamalardan sonra gate'i aç; aynı kapsam için yeniden onay isteme.
   Aşağıdaki komut migration'ın parçası değildir.

```sql
begin;
update public.push_delivery_v2_config set enabled=true where singleton;
select public.wake_push_delivery_v2();
commit;
```

Sahibin test hesaplarıyla arkadaşlık/oda bildirimi oluşturması gerçek teslimat kontrolüdür. FCM kabulü cihazda görünme kanıtı değildir. Toplu sağlık kontrolü kişisel veri seçmeden yapılabilir:

```sql
select delivery_status,count(*) from public.push_outbox group by delivery_status;
select delivery_status,last_error_code,count(*) from public.push_outbox
where created_at>now()-interval '1 hour' group by delivery_status,last_error_code;
select jobname,schedule,active from cron.job
where jobname in ('send-push','send-push-v2');
```

Geri durdurma: `update public.push_delivery_v2_config set enabled=false where singleton;`. Bu yeni claim/wake'i durdurur; devam eden FCM/ack iptal olmaz. Eski worker/cron'u otomatik açma, legacy satırları tekrar pending yapma. Yeni kolonları veya eski fonksiyonları silmek bu geri durdurmanın parçası değildir.

## API kaynakları

- [pg_cron](https://github.com/citusdata/pg_cron): cron.alter_job(jobid,active := false).
- [Supabase pg_net](https://supabase.com/docs/guides/database/extensions/pg_net): HTTP işlemleri commit sonrasında başlar.
- [FCM hata kodları](https://firebase.google.com/docs/cloud-messaging/error-codes):429 en az60sn;503 Retry-After ve backoff;500 retry.
- [FCM message şeması](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages): Android priority/ttl, APNs headers.
