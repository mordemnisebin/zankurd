# T3 maç başına şık sırası

Amaç: görünen sıra soru kimliği ve ortak maç/tur kimliğine bağlı deterministik permütasyon olsun; sunucu A–D anahtarları değişmesin.

Tasarım: QuizQuestion.forRound(roundId) değişmez sunum indekslerini yerelleştirmeden önce hesaplar. SHA-256 tabanlı Fisher–Yates tüm permütasyonlara izin verir; Dart Random/hashCode sürümüne dayanmaz. Sayısal şıklar mevcut yönlü sıralamada; diğer soru türleri kaynak sırasında kalır. Kaynak answers ve JSON sırası değişmez. Model kopyalama, yerelleştirme ve cevap açılması sunum indekslerini korur.

Kimlik: QuizScreen oda kimliğini; yerel turnuva açık maç kimliğini; solo mevcut _soloRoundId değerini kullanır. Açık roundId yeniden kurulan solo turu aynı kimlikle açmaya izin verir. Var olan solo resume uygulama yaşam döngüsüdür (State korunur); süreçten kurtarma yolu çevrimiçi oda ve sırayla düello içindir. Bu işe yeni solo kayıt/ekran kurtarma ürünü eklenmez. Sırayla düello ve gerçek turnuva sunucunun duelId/maç kimliğine bağlanır; sunumla gelen turnuva sorusu ilk gösterimden önce bağlanır.

- [x] Model bekçileri: farklı maç, aynı kimlik, iki istemci, iki dil, anahtarlar, sayısal ve özel türler, reveal, %25±3 ve tüm 24 sıra. Önce kırmızı, sonra yeşil.
- [x] Ekran bağlama: quiz/oda/canlı düello, sırayla düello ve turnuva; resume ve ilk kare bekçileri.
- [x] Mevcut konum ve geometri testlerini açık tur kimliğiyle uyarlama (eşikleri koruma).
- [ ] Analiz, format, ilgili testler, tam yerel CI ve mümkün olan görsel kontrol.
- [ ] Claude Opus incelemesine değişiklik/risk notu; Türkçe gerekçeli commit, push yok.

Sınırlar: canlı bağlantı, gizli dosya okuma, içerik değişikliği ve sunucu göçü yok. Yeni kullanıcı metni yok; KU tablosu boş. Özel türlerin dağılımı karıştırma istatistiğine dahil edilmez; ayrı değişmezlik bekçisi uygulanır. Sayısal sorunun tek başına dört konuma yayılması sıralama sözleşmesiyle mümkün değildir; tüm banka dağılımında korunur.

## İnceleme notları

- Üretim: `lib/src/models/quiz_question.dart`, `lib/src/screens/quiz_screen.dart`, `lib/src/screens/quiz/quiz_screen_ui.dart`, `lib/src/screens/async_duel/async_duel_play_screen.dart`, `lib/src/screens/tournament_screen.dart`.
- Yeni bekçiler: `test/round_answer_order_test.dart`, `test/round_answer_order_screens_test.dart`.
- Güncellenen bekçiler: `test/sik_konum_sozlesmesi_test.dart`, `test/answer_position_category_balance_test.dart`, `test/models/quiz_question_test.dart`, `test/quiz_flow_test.dart`, `test/quiz_accent_test.dart`, `test/quiz_effects_test.dart`, `test/quiz_multiplayer_advance_race_test.dart`, `test/quiz_room_resume_test.dart`, `test/expansion_runtime_flow_test.dart`, `test/soru_sigma_test.dart`, `test/soru_sigma_ek_test.dart`.
- Sayısal soruların sıralama yönü değişmediği için tek kategori/tek soru için dört konuma eşit dağılım iddiası yoktur. Eski kategori bekçisi korundu; yeni kategori bekçisi karıştırılabilen metin şıklarında %25±3 ölçer. Tüm çoktan seçmeli banka ayrıca 30 maçta %25±3 ile ölçülür.
- Yeni solo süreç-kurtarma altyapısı eklenmedi: mevcut yaşam döngüsü dönüşü State içindeki tohumu korur; yeniden kurulacak solo ekran için açık `roundId` vardır. Çevrimiçi soğuk resume oda/maç kimliğinden aynı sırayı kurar.
- Eski uygulama sürümü hâlâ eski algoritmayı çalıştırır; iki sürüm arasında aynı görünen sıra garantisi verilmez. Yeni sürümün istemcileri aynı v1 algoritmasını kullanır.
- Supabase göçü yok; canlı bağlantı yok; kaynak soru bankası, JSON/option_a..d sırası ve mevcut KU metinleri değişmedi.
- Claude Opus 5.5 incelemesi henüz yapılmadı.

## Doğrulama

- Son `flutter analyze --no-pub`: temiz (0 sorun).
- Son `dart format --set-exit-if-changed lib test`: 1201 dosya, 0 değişiklik.
- Standart `flutter test`: sandbox `127.0.0.1:0` soketi açmayı reddetti. Bu komut başarılı sayılmadı.
- Ek doğrulama: kaynak testler gerçek Flutter test motoruna derlenip, TCP/VM servisi açmadan test_api Declarer/Invoker ile çalıştırıldı. Standart runner veya tam CI yerine geçtiği iddia edilmez. Son kodda 603 test ve 6 setUpAll/tearDownAll adımı geçti; 0 hata. `soru_sigma_test`, `soru_sigma_ek_test`, `tur3_bulgu_test`, yeni model/ekran bekçileri ve güncellenen quiz/resume regresyonları dahildir. Çıkış kodu 0; kayıt `/private/tmp/zk-t3-final-run.log`.
- Tam `tool/ci_yerel.sh --tam`: format, dart analyze, soru kalitesi (baseline borcu artmadı), şık taraması ve dokunma hedefi kapısı geçti. Ekran turu aynı soket yasağında durdu (çıkış 1); tam test/cihazsız akış adımlarına ulaşmadı. Kayıt `/private/tmp/zk-t3-ci.log`.
- Dart MCP ve Playwright: oturumun `approval policy is never` kısıtı çağrıları reddetti. Tarayıcı/simülatör görsel onayı yok.
- Git staging: worktree'nin ortak Git dizini yazma izni dışında; `index.lock: Operation not permitted`. Commit oluşturulamadı; push yapılmadı. Hazırlanan Türkçe commit gövdesi `/private/tmp/zk-t3-commit-message.txt` dosyasında; istenen Co-Authored-By satırını içerir.

| Yeni metin | TR | KU |
|---|---|---|
| Yok | — | — |
