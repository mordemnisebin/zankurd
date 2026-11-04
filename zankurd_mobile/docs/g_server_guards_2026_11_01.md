# G5 G6 G7 G8 G9 G12 G15 — yerel uygulama ve geçiş kaydı

1 Kasım 2026. Kapsam yalnız iş listesindeki bu yedi maddedir. Canlı
veritabanına bağlanılmadı; göç, Edge dağıtımı veya etkinleştirme yapılmadı.
`.env` okunmadı, simülatör ve cihaz kullanılmadı. Yeni Kurmancî dize yok.

## Davranış

- **G5:** Solo soru seçimini sunucu tek kullanımlık biletle üretir. Oturum,
  cevap sırası ve ilk cevap kalıcıdır; ödeme yalnız tamamlanan oturumdan,
  bir kez ve günlük 45 jeton sınırıyla hesaplanır. Eski üç/dört parametreli
  beyan RPC'leri ödeme yapmaz. Önceki günün ödenmemiş turu yeni günün
  bütçesini kullanamaz; önceden yapılmış ödeme yeniden yazılmaz.
- **G6:** Eski ve V2 katılım aynı kullanıcı kilidi ve deneme sayacını
  kullanır. Sınırsız çekirdek istemciye kapalıdır. Başarısız denemeler
  dışarıya hata JSON'u olarak dönerek COMMIT sonrasında korunur.
- **G7:** Gelecek oda soruları yalnız kimlik/sıra taşır. İstemci etkin
  soru içeriğini yükler; boş içerikte sayaç/cevap açılmaz. Geçmiş ve bitmiş
  soruların inceleme erişimi korunur.
- **G8:** Düello başlangıç/devam yanıtları gelecek içeriği açmaz. Sunum ve
  içerik aynı RPC'dedir; sunum kaydı bulunmayan normal cevap reddedilir.
  Mevcut 20 saniye + 5 saniye ağ payı korunur. TIMEOUT yanlış cevap olarak
  mevcut terk akışını destekler.
- **G9:** Günlük soru seti sunucuda bir kez rastgele seçilir. Kullanıcıya
  ilk verildiği an kalıcıdır; yeniden almak süreyi sıfırlamaz. Resmî sonuç
  sunucu cevap toplamı ve süresinden gelir. Eski beyanlar ayrı kalır.
- **G12:** Ana anahtar da bekleyen sunucu tercihidir. Etkili bayraklar
  `enabled && duelOn/socialOn`; maskelenmiş false kategori seçimini silmez.
  Başarısız gönderim kalıcı bekler ve ayar satırında mevcut TR/KU metniyle
  gösterilir.
- **G15:** Yeni kuyruk yazılmadı. Mevcut V2 adayının ardından kapalı geçiş
  eski V1 claim yetkisini kaldırır; eski işler otomatik yeniden gönderilmez.

## Göç olmadan ve dağıtım sırasında

Yeni istemci eski sunucuda yerel oyun/ilerlemeyi sürdürür. Doğrulanmış solo
RPC yoksa beyanla ödeme yoluna dönmez; jeton sıfırdır. Resmî günlük pano
RPC'si yoksa eski doğrulanmamış pano gösterilmez. Sunucu soru UUID'leri
yerel bankada bulunamazsa yerel öğrenme sürer; o tur doğrulanmış ödül veya
resmî sıralama üretmez. Oda ve düello eski içerik/sunum sözleşmesine geri
düşebilir; yeni sunucunun boş yer tutucusunu oynatmaz.

G9 resmî geçişi **göçü izleyen İstanbul günü 00:00** başlar. Kurulum günü
resmî günlük oturum açılmaz, yerel tur çalışır. Kullanıcı/gün başına tek
resmî giriş vardır; farklı tur kimliğiyle ikinci giriş reddedilir.

G5/G9 (`solo_daily_verified`) ve G6–G8 (`room_duel_guards`) 2026-11-05'te canlıya uygulandı (applied.md ✅). Yeni üç göç yazıldığında `supabase/applied.md` içinde **⏳** durumundaydı ve her birinin
`supabase/geri_al/` karşılığı vardır. G5–G9 göçleri güncel fonksiyon
tanımlarını uygulama anında `pg_get_functiondef` ile saklar. Bu, canlı
tanımın önceden incelendiği anlamına gelmez: operatör uygulamadan önce
gövde/ACL diff'ini, şema önkoşullarını ve rollback dumanını incelemelidir.
Sonraki bir sunucu değişikliğinden sonra eski yedekle kör tekrar yapılmaz.

G6–G8 için önce uyumlu istemci dağıtılmalıdır. G15 sırası ve güvenli geri
durdurma [Push V2 geçiş belgesinde](push_delivery_v2_rollout.md) bulunur.
G15 geri alma dosyası tam şema geri dönüşü değil, kapalı güvenli durdurmadır;
teslim öncesi kalıcı tüketen V1'i yeniden açmaz. Canlı karşılaştırma,
eski göndericilerin durumu, Edge dağıtımı, kapı açma ve gerçek cihaz
teslimatı **bu görevde tamamlanmadı**.

## Yerel kanıt

- Son kaynaklarla `./tool/ci_yerel.sh --tam` çıkış kodu **0**: analiz ve
  kalite kapıları geçti; ekran turu **214/214**, ana test paketi **7650 geçti,
  3 atlandı**, cihazsız uygulama akışları **4/4**. Son satır:
  `CI yerel: bütün adımlar geçti.`
- İlk tam koşuda yakalanan hata raporlama sözleşmesi eksikleri ve geciken
  bildirim RPC'sinde anahtarın hemen kapanmaması düzeltildi. Bekçiler
  korundu; son tam koşu bu düzeltmelerle baştan çalıştırıldı.
- Dart analizinde bulgu yok. Hedef Flutter testleri: G5/G9 21, G6–G8 93
  ve iki etkin soru yükleme bekçisi; G12/G15 hedefleri ayrıca çalıştırıldı.
- Üç yeni göçün tamamı bellekte PGlite PostgreSQL 17.5'te çalıştırıldı;
  tekrar uygulama, geri alma/yeniden uygulama, yetkiler, yanlış ilk cevap,
  ödeme tekilliği, günlük tavan, ilk soru açıklama süresi ve eski imza
  kontrolleri geçti. Gerçek veritabanı bağlantısı kullanılmadı.
- G6/G7/G8 düzeneği gerçek katılım V2 ve sunum gövdelerini kullanır;
  G8 eski cevap çekirdeği çok sayıdaki ödül bağımlılığı yerine süre
  davranışını taşıyan sentetik fixture'dır. PGlite tek bağlantılıdır;
  gerçek eşzamanlı bağlantı testi değildir.
- G15 mevcut tam lease/ack smoke'u yeniden çalıştırıldı. Gönderici Deno
  testleri 13/13, Python testleri 10/10. Python SQL sözleşmesi 4 geçti;
  pglast kurulu olmadığı için ayrı parser testi atlandı. PGlite göçün
  tamamını gerçekten ayrıştırıp yürüttü.
- Gemini 4 Argon bağımsız incelemesi G12, G6–G8 ve G15'i onayladı.
  G5/G9 ilk incelemesinin seçim/ödül günü/ilk açıklama süresi bulguları
  düzeltildi; son inceleme **ONAY** verdi. Ana ajan difflere ve SQL
  provalarına ayrıca baktı.
- Bildirim satırı Playwright ile çevrimdışı gönderim taklidinde kontrol
  edildi: [TR 390 px](qa_2026_11_01_g/g12-offline-tr.png),
  [KU 320 px ve %200 yazı](qa_2026_11_01_g/g12-offline-ku-320-200.png).
  Ana anahtar kapandı, bekleme bilgisi kaldı, kategori satırları gizlendi;
  tarayıcı hata günlüğü boştu. Web girişi yalnız mock repository kullanır.

Tekrarlanabilir SQL provaları (PGlite modülünün yerel yolu verilmelidir):

```sh
node tool/test_room_duel_guards_local.mjs /absolute/path/to/pglite/dist/index.js
node tool/test_push_delivery_v2_local.mjs /absolute/path/to/pglite/dist/index.js
PGLITE_MODULE=/absolute/path/to/pglite/dist/index.js node tool/verified_quiz_sql_smoke.mjs
./tool/ci_yerel.sh --tam
```
