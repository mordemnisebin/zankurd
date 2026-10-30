# T5 — Cevap açılışı ve geçiş kararı

30 Ekim 2026; bu worktree'nin kod incelemesi. Canlı veritabanına bağlanılmadı.
Kararı uygulayan: Astra görevi. Bağımsız aynı sağlayıcı incelemesi tamamlandı;
farklı sağlayıcı Claude/Gemini onayı alınmadı. Güncel kanıt: [t5_dogrulama.md](t5_dogrulama.md).

## Değişiklik öncesindeki durum

| Mod | Cevap sonrası | Erken açılış / geçiş | Son soru |
|---|---|---|---|
| Canlı düello, 2 kişilik özel oda | Sunucuda revealed_at + 5 sn; istemcide cevap ulaşınca tekrar 5 sn | İkisi cevaplayınca veya deadline dolunca açılır. Açılış atlanmaz. | Aynı bekleme; CAS terminal indeksi ve finished durumunu atomik yazar. |
| 3–50 kişilik kalabalık oda | Aynı 5 sn; misafir ilerletme isteğinde ek 0,3–1,5 sn jitter | Ayrılmamış üyeler cevaplayınca veya deadline dolunca. | Aynı terminal CAS; sonuç sıralaması. |
| Sunucu puanlı turnuva | AsyncDuelPlayScreen: yerel 1200 ms | Rakibin o anda cevaplaması beklenmez; her oyuncu kendi sunumunu oynar. | Sunucu son cevapta maçı kaydeder; istemci 1200 ms sonra sonuca/şemaya gider. |
| Sırayla düello | Aynı yerel 1200 ms | Rakip çevrimdışı olabilir; hazır oyu yok. | response.finished sonrası aynı bekleme. |
| Solo ve antrenman/eski turnuva | Otomatik bekleme yok; Devam et / Bitir | Kullanıcı açıklamayı istediği kadar okur. | Bitir dokunuşu. |

Kaynaklar: `lib/src/screens/quiz_screen.dart` (_startRevealPhase,
_checkMultiplayerSync, _advanceAuthoritativeIndex), `quiz/quiz_screen_ui.dart`,
`async_duel/async_duel_play_screen.dart` (_handleAnswerResponse),
`tournament_screen.dart` (_startMatch ve _startServerScoredMatch).
Sunucu temel sözleşmesi: `supabase/2026-08-02_multiplayer_session_hardening.sql`;
aktif üye sayısı ve 50 kişi: `2026-10-16_kalabalik_oda.sql` (advance_room_question,
submit_answer); resume JSON'un son yerel tam tanımı: `2026-10-18_oda_kod_kategori.sql`.
Turnuva: `2026-10-27_turnuva_sunucu_puani.sql`; sırayla düello:
`2026-09-28_async_duels.sql`, `2026-10-24_duello_sirasi.sql`.
Alanlar `started_at`, `revealed_at`, `server_now`, `current_question_deadline`;
mevcut kodda reveal_until/next_question_at yok. Cevap bekleme süresi ile cevap
AÇILDIKTAN sonraki süre ayrı. Kullanıcının gözlediği 3 sn bu checkout'un sabiti değil.

## Benzer ürünler: kanıt ile varsayımı ayırma

| Ürün | Doğrulanabilen davranış | Kesin açıklama süresi / dokunma |
|---|---|---|
| Kahoot | Herkes cevaplayınca veya süre bitince cevap dağılımı, ardından ilk beş lider tablosu. Sunucu/öğretmen yönetimli sunum. | Resmî sayfa evrensel sabit saniye vermiyor; sunuculu anlatım için doğal ara. ZanKurd'a sabit 5 sn kanıtı sayılamaz. |
| Quiz Planet | Arkadaşlarla sosyal quiz; resmi tanıtım hızlı akışı vurguluyor. | Güncel açıklama saniyesi, erken geçiş ve hazır düğmesi belgelenmiyor; ölçülmedi. |
| Trivia Crack | Klasik mod sırayla: doğruysa sıra sürer, yanlışsa rakibe geçer; cevap 20 sn, sıra penceresi 36 saat. | Canlı iki cihaz bariyeri değil; açıklama saniyesi belgelenmiyor. |
| QuizUp (özgün Glu ürünü) | 22 Mart 2021'de sonlandırılmış. | Güncel referans değil; hatıradan saniye uydurulmadı. Aynı adlı yeni siteler farklı ürün. |
| Pirs / Pêşbirka Kurdî | Geliştirici mağaza sayfası grup odası, özel kodla arkadaş ve liderlik listesi bildiriyor. | Açıklama süresi, beklenen kişi/erken geçiş/hazır dokunuşu yayınlanmıyor; cihaz ölçümü yok. |
| Duolingo Ligleri | Haftalık XP sıralaması, eşzamanlı soru yarışı değil. | Sorular arasında rakibi bekleyen bariyer için emsal değil. |

Kaynaklar (30 Ekim 2026'da okundu):
- [Kahoot cevap ve liderlik akışı](https://support.kahoot.com/hc/en-us/articles/360039900153-Tips-for-hosting-a-live-game)
- [Quiz Planet resmi tanıtım](https://quizplanet.game/)
- [Trivia Crack resmi klasik mod](https://triviacrack.help.etermax.com/hc/es/articles/360024774573-Modo-Cl%C3%A1sico)
- [QuizUp resmi kapanış](https://glumobile.helpshift.com/hc/en/94-quizup/faq/9680-quizup-has-been-discontinued/?f=quizup-has-been-discontinued&l=en&s=quizup-discontinued)
- [Pirs geliştirici mağaza açıklaması](https://play.google.com/store/apps/details?hl=tr&id=kurdi.leyzok.pirs)
- [Duolingo resmi lig açıklaması](https://blog.duolingo.com/duolingo-leagues-leaderboards/)

## Karar ve gerekçe

| Mod | Yeni açılış | Erken geçiş / okuma |
|---|---|---|
| Canlı düello / 2 kişilik oda | Sunucuda 3 sn | İki cevap veya deadline açılışı başlatır; 3 sn kısaltılmaz. |
| Kalabalık oda (kapasite >2) | Sunucuda 4 sn | Tüm aktif üyeler veya deadline; ayrılan beklenmez. 4 sn kısaltılmaz. |
| Sunucu puanlı turnuva / sırayla düello | Doğruda 1,2 sn; yanlış/TIMEOUT'ta 3 sn | Yerel okuma arası, rakibi beklemez; son cevapta da korunur. |
| Solo / botlu antrenman / eski turnuva | Elle Devam et / Bitir | Sınırsız okuma; otomatik geçiş eklenmez. |

3 sn kısa doğru şıkkı görmeye ayrılır; kalabalıkta skorları izlemek için 4 sn.
Uzun açıklamanın bütünü bu sürede okunamaz; maç sonundaki mevcut cevap incelemesi
korunur. Yanlışta sırayla oyunun 1,2 sn'si yetersiz olduğundan 3 sn seçildi.
Her oyuncuya göre canlı süre değiştirmek ortak ritmi bozar; doğru/yanlış canlıda
aynı süreyi paylaşır. "İkisi de gördü" kanıtı mevcut protokolde yoktur; cevap
verildi olayı görüldü sayılmaz. Yeni hazır oyu/RPC eklenmez. 0 sn veya 1 sn
atlama okunabilirliği bozar; 5 sn her cihazda tekrar başlatma ise yavaştır.

Ara lider tablosu: **zorunlu ara yok (0 sn, hiçbir soruda ek durak yok)**.
Mevcut canlı sıralama görünümü cevaplar geldikçe güncellenir, tam tablo sonda.
5–15 soruluk odada her 3/5 soruda bir modal hem akışı hem sabit ekranı bozar;
ayrı bir sınıf/sunucu modu istenirse daha sonra tasarlanabilir.

## Senkronizasyon ve uyumluluk

Yeni resume alanı `current_question_reveal_ends_at`, sunucudaki revealed_at +
ortak süreyi taşır. İstemci cihaz saatini karşılaştırmaz: server_now örneğinden
kalan süreyi çıkarıp monoton kronometreyle azaltır. RPC gidiş-dönüşünün yarısı
aktarım tahmini olarak düşülür; sonraki profil/oda yükleme gecikmesi de sayılır.
Aynı son tarih, farklı geliş anı ve farklı cihaz duvar saatinde aynı hedefe
ulaşır. Fiziksel ekranların milisaniye eşitliği ağ gecikmesinden dolayı garanti
edilemez: tek gerçek geçiş oda kilidi + expected-index CAS'tir; istemci süre
bitti diye kendi indeksini artırmaz. Erken RPC sunucuda mevcut indeksi döndürür.
Kalabalık misafir jitter'ı yalnız yedek RPC yükünü dağıtır; yeni indeks yayını
beklemeden işlenir. Son soru da aynı açılış kapısından geçer.

Göç uygulanmamış sunucu alanı göndermezse eski 5 sn korunur. Eski uygulamalar
yeni alanı yok sayar; 3/4 sn yararı yeni istemciyle elde edilir.
Göç eski tam gövdeyi kopyalamaz: uygulama anındaki pg_get_functiondef üzerinde
tekil ve bilinen çıpaları değiştirir; tanım sapmışsa exception ile transaction
iptal olur. Yayın sorumlusu uygulamadan önce canlı diff ve begin/rollback
kanıtını ayrıca almalı. Bu görevde canlıya bağlantı veya göç uygulama YOK.

## Uygulama ve doğrulama planı

1. Mod sabitleri ve sahte saat testleri (önce kırmızı).
2. Geri uyumlu snapshot saati; mevcut dock/metin/yerleşimi değiştirmeden timer.
3. İdempotent dar SQL göçü + ACL/RLS/doğrulama ve bekçiler.
4. Gerçek ekran akışında süre/son soru, mevcut sigma/tur3 ve ilgili testler.
5. Analyze/format, tam CI ve iki istemcili yerel web kontrolü; açık risklerle teslim.

Yeni TR/KU kullanıcı metni yok; strings.dart değişmez.

## Teslim notu

Kod commitlendi; sunucu göçü uygulanmadı. Tam CI geçti: 214 ekran turu,
7.000 ana test (3 atlandı), 4 cihazsız akış. Yerel Flutter web üzerinde iki
istemci sayaçları görsel olarak doğrulandı. Native simülatör/canlı iki cihaz
kontrolü, canlı SQL doğrulaması ve farklı sağlayıcı incelemesi açık kaldı.
Ayrıntı: [t5_dogrulama.md](t5_dogrulama.md). Belgeler bu worktree'dedir.
