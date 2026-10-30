# T9 — T5 zamanlama testlerinin deterministikleştirilmesi

Tarih: 2026-10-30. Başlangıç commit'i: `77213626`.

## Kök neden ve değişiklik

`quiz_room_resume_test.dart` içindeki `_snapshot`, `RoomResumeSnapshot`'ın
varsayılan `ServerClock`'unu kullanıyordu. Bu saat gerçek `Stopwatch` ile,
widget zamanlayıcıları ise Flutter test binding'inin sahte saatiyle ilerliyordu.
Yoğun CPU altında ekran kurulumu 12 saniyelik sunucu bekleme bütçesini tüketebilir;
`_startOpponentWaitTimer` bu azalan süreyle erken `advance` isteği planlayabilirdi.

Fixture artık `TestWidgetsFlutterBinding.instance.clock` kaynağını enjekte eder.
`tester.pump(duration)` gerçek uyku değildir: binding'in sahte zamanını açıkça
ilerletir; snapshot da artık tam aynı miktarda ilerler. İlk test mevcut gizli
cevap/açılış beklentilerini korur, ayrıca 3 saniyelik saat ilerlemesini ve
11.999 saniyede ilerleme yokken tam 12 saniyede tek advance çağrısını doğrular.

`SupabaseZanKurdRepository`'ye varsayılanı `Stopwatch.new` olan kronometre
üreticisi eklendi. RPC RTT ölçümü ve yanıt sonrasındaki süre aynı enjekte
edilebilir kaynağı kullanır. Üretimde monoton `Stopwatch` davranışı korunur.
Testler `FakeAsync.getClock(...).stopwatch` kullanır; oda yanıtı `Completer`
ile tutulur ve saat `elapse` ile ilerletilir. Gerçek iki saniyelik bekleme yoktur.
Supabase JSON çözümü ayrı isolate kullandığından RPC normal async ortamında
tamamlanır; bütün RPC'yi `fakeAsync` zone'una almak yerine yalnız saat enjekte edilir.

Tolerans aralıkları kaldırıldı: 200 ms RPC RTT için 100 ms telafi, 1.900 ms
reveal ve 14.900 ms soru süresi; iki saniye oda gecikmesi için 3.000 ms reveal
ve 13.000 ms soru süresi kesin olarak doğrulanır. Üç saniye daha ilerletilince
reveal sıfırlanır ve soru için 10 saniye kalır.

## Tarama kapsamı

| Dosya | T5 zamanlama değerlendirmesi |
| --- | --- |
| `quiz_room_resume_test.dart` | Bütün ortak snapshot'lar sahte saate bağlandı. Diğer T5 reveal saatleri zaten binding saatini kullanıyordu. |
| `supabase_repository_test.dart` | Gerçek bekleme ve gerçek kronometre bağımlılığı kaldırıldı; kesin süre ve olay kapısı doğrulamaları eklendi. |
| `turnuva_sunucu_puani_istemci_test.dart` | Yanlış cevap için 2.999 + 1 ms bekçisi `Timer` üzerinden sahte zamanda çalışır. |
| `async_duel_screens_test.dart` | Reveal/dispose ve TIMEOUT bekçileri binding'in Timer/Ticker zamanını kullanır; TIMEOUT yanlış cevabı kesinleştirir. |
| `duello_sirasi_istemci_test.dart` | T5'in değiştirdiği süre dolumu akışında sunum süresi fixture ile verilir; reveal beklemesi sahte Timer'dır. |
| `friend_challenge_ui_test.dart` | T5 cevap yardımcısı sahte Timer ile okuma arasını ilerletir; doğru/yanlış kararını geçen CPU süresi belirlemez. |
| `t5_server_clock_test.dart`, `t5_reveal_timing_test.dart` | Süreler zaten açıkça kontrol edilen callback'lerle enjekte edilir; tekrar paketine dahil edildi. |

Kapsam dışındaki eski 24 saatlik mock son kullanma zamanı/sunum testleri
yeniden tasarlanmadı. Ekran tasarımı ve kullanıcıya görünen metin değişmedi;
simülatör/tarayıcı görsel kontrolü bu görevde çalıştırılmadı.

## Kanıt

- RED: Enjeksiyondan önce 3 saniye widget zamanı ilerletildiğinde snapshot
  yaklaşık 355 ms ilerledi; ek saat eşitliği bekçisi kırıldı.
- `dart analyze`: `No issues found!` (Dart MCP analizi de temiz).
- Gemini 4 Argon High bağımsız son inceleme: ONAY; beklenti gevşemesi veya
  üretimde monoton saat davranışının bozulması bulunmadı.
- Seri tekrar: 8 dosya × 10 koşu, her koşuda 223 test; 10/10 başarılı.
- CPU yükü altında tekrar: aynı 8 dosya × 10 koşu, 223 test/koşu; 10/10 başarılı.
- Eşzamanlı iki tam `flutter test --no-pub -r expanded`: her birinde
  7.202 geçti, 3 atlandı; ikisi de çıkış kodu 0. Süreler 1.579,3 ve 1.540,2 sn.
- Başlangıç/bitiş kayıtlarıyla doğrulandı: 10 hedefli yük turunun HER BİRİ,
  her iki tam paketin çalışma aralığının tamamen içindedir.
- Hedefli koşular `flutter test --no-pub --concurrency=1 -r failures-only`
  ile yukarıdaki sekiz test dosyası verilerek çalıştırıldı. Toplam 4.460 başarılı
  hedefli test geçişi; kod değiştirilmeden 10 seri + 10 yüklü tekrar.
- `./tool/ci_yerel.sh --tam`: çıkış kodu 0. Format, analiz, soru/şık kalite
  kapıları, erişilebilirlik taraması, 214 ekran turu testi, tam test paketi ve
  4 cihazsız uygulama akışı geçti. CI de ayrı `TMPDIR` ile çalıştırıldı.
- CI son satırı: `CI yerel: bütün adımlar geçti.`

Günlükler: `/tmp/zk-t9-evidence/`. `serial.json`, `loaded.json`, `full-0.json`
ve `full-1.json` komutları, başlangıç/bitiş zamanlarını ve çıkış kodlarını saklar.
İki tam test paketi ayrı geçici worktree'lerde aynı kaynak SHA-256 değerleriyle
çalışır; derleme çıktıları birbirine karışmaz. `tested-source-sha256.json`
bu eşitliğin kaydıdır. Gizli dosya/canlı DB erişimi ve push yapılmadı.

İlk yük denemesinde iki paketin `pronunciation_sheet_test.dart` testi ortak
`Directory.systemTemp` içindeki `zankurd_telaffuz_*` dosyalarını birbirinden
sildi (`PathNotFoundException`, test satırı 207). Bu, T5 saat hatası değildi.
Kaynak/beklenti değiştirmeden tam paketler ve hedefli koşucu için ayrı `TMPDIR`
atandı; Dart'ın gerçekten farklı klasörler kullandığı doğrulandı. İlk deneme
`attempt-shared-temp/` altında korunuyor. Yüklü 10 tekrar yeni izolasyonla
baştan sayılır; önceki deneme başarılı tam paket kanıtı olarak sayılmaz.

Test edilen kaynakların SHA-256 değerleri (commit öncesi tekrar doğrulandı):

- `lib/src/data/supabase_zankurd_repository.dart`: `62660e73b2d609a6112eaaa0911e50967f74ab0781bd265ef021edef9d7aca45`
- `test/quiz_room_resume_test.dart`: `7a2baae13306e6130378f86a9a863ffb41fda020a526f54b5110d7ef359ddfcb`
- `test/supabase_repository_test.dart`: `c29228ba8be4d1e924c2b9b9607689083c5970680bcc8cebd3ed2ab0d160da43`
