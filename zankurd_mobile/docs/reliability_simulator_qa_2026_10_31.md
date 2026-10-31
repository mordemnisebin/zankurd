# Yerel kurtarma ve davet doğrulaması

Kullanıcı 31 Ekim güncel önizlemesini Terminal'den başlattı. iPhone SE
(375×667 pt) üzerinde DTD bağlantısı ve hot restart ile güncel kod kontrol edildi.
Önceki 29 Ekim binary kontrolü aşağıdaki sonuçların kaynağı değildir.

Son doğrulamada standart `tool/ci_yerel.sh --tam` Mac üzerinde başarıyla
tamamlandı. Analiz, içerik ve dokunma hedefi kapıları, 214 ekran turu,
7.598 test (3 atlanan) ve dört cihazsız uygulama akışı geçti. İlk oturumun
SDK/soket engeli, bu sonraki başarılı normal CI koşusunun sonucu değildir.

Gemini 4 Argon bağımsız incelemesi ders çeldiricileri ve puanlama sınırındaki
sorunları buldu. Düzeltmeleri yeniden inceleyip onayladı. DeepSeek ve MiMo
ücretsiz çağrıları kullanım limiti nedeniyle yanıt üretemedi.

Güncel kaynak `flutter build ios --simulator --debug --no-pub
-t tool/reliability_preview.dart` ile derlendi. Ayrı yerel QA uygulamasında
ilk beş soruluk pratik, profil ve bildirim iznini reddetme akışı görüldü.
[İlk pratik](qa_2026_10_31/first_practice_current.png) ·
[İzin reddi](qa_2026_10_31/notification_permission_denied_current.png)

## Arkadaşlık isteği çakışma deneyi

İkinci arkadaşlık olayı, ilk liste sorgusu sürerken üretildi. İlk sorgu
eski listeyi döndürdü. Önceki istemciyle bağımsız Dart deneyinde yeni kayıt
19,95 saniye bekledi. Yenileme sırasında gelen olayları tek ek sorguda
toplayan kodla aynı deneyde kayıt 316 ms sonra listeye geçti.

Build 42'nin yerel iOS simülatör önizlemesinde ilk sorgu 302 ms sonra
bırakıldı, yeni isteğin adı ikinci olaydan **357 ms** sonra ekrandaydı
(bir koşu, 20 ms gözlem aralığı). Depo ve olay yereldi. Gerçek FCM/APNs
teslim süresi bu deneyin kapsamına girmedi. [Simülatör karesi](qa_2026_10_31/friend_refresh_overlap.png)

## Ücretli oda daveti

Kimlikli test bildirimi iOS simülatöründe Rojda'nın davetini açtı. Kart 50
soru, soru başına 120 saniye ve 25 jeton gösterdi. “Katıl · 25 jeton”
düğmesine dokununca ücret ile vazgeçme seçeneği ayrı bir pencerede göründü.
[Davet kartı](qa_2026_10_31/paid_invite_target.png) ·
[Katılım onayı](qa_2026_10_31/paid_invite_confirmation.png)

Son yerel koşuda 35 dosyadaki 329 hedefli test ve ekran turundaki 214 test
Flutter test motorunda geçti. Proje genelinde Dart analizi temizdi. Soru
kalitesi kapısı 3.832 benzersiz kayıtta yeni borç bulmadı. Standart tam CI
eğitim içeriği ve erişilebilirlik kontrollerinden sonra ekran turunda
yerel test sunucusu için soket açma iznine takıldı.

## 31 Ekim simülatör sonuçları

| Kontrol | Sonuç ve sınırı |
| --- | --- |
| Türkçe/açık tema oda ayarları | 50 soru ve 120 sn seçildi; özet ve oda açma düğmesi kullanılabildi. |
| Lobi ve oyun | Lobi 50 soru/120 sn gösterdi; oyun `Soru 1/50` ve 120 saniye ile başladı. |
| Oyun çıkışı | Onay diyaloğuyla lobiye, ardından Yarış sekmesine dönüldü. |
| Seri kurtarma | Hazırlanan 7→8 senaryosu açılışta 8 gün olarak Yarış ve Profil'de görüldü; profil 0 XP gösterdi. Takvimde gün bazlı doğrulama yapılmadı. |
| Yerel davet | Push üretilmeyen önizlemede Rojda daveti Ana ve Yarış sekmelerinde göründü. Kesin teslim gecikmesi ölçülmedi. |
| Kurmancî/koyu tema | Uygulama ayarlarından geçiş yapıldı; davet kartı, katıl/reddet eylemleri ve sekmeler dar ekranda görüntülendi. |
| Çalışma zamanı | Tamamlanan gezinmelerde Dart MCP `No runtime errors found` döndürdü. |
| Arka plandan dönüş ve davet reddi | iOS ana ekranından uygulamaya dönüldüğünde Yarış sekmesinde Rojda daveti görüldü. `Red bike` seçilince davet kartının kalktığı ve sekmenin açık kaldığı ekrandan doğrulandı. Arka plandayken yeni bir davetin teslim süresi ölçülmedi. |
| Büyük yazı ve gerçek push | Henüz doğrulanmadı. |

Kanıtlar: [oda ayarları](qa_2026_10_31/room_50_120_tr.png),
[lobi](qa_2026_10_31/lobby_50_120_tr.png),
[oyun](qa_2026_10_31/quiz_50_120_tr.png),
[Kurmancî/koyu davet](qa_2026_10_31/invite_dark_ku.png).

İlk önizleme koşusunda Mock repository küçük yedek bankayı kullanarak 44 soru
üretti. Yalnız önizleme girişine `QuestionBankLoader.instance.load()` eklendi;
analiz ve hot restart sonrasında 50 soruluk gerçek akış tekrar doğrulandı.
Bu değişiklik üretim soru bankası içeriğini değiştirmedi.

Bağımsız görsel ikinci göz dört kanıtta belirgin metin taşması veya ana eylemi
kapatan çakışma bulmadı. Tek karelerin doğrulamadığı ek durumlar: lobide alt
oyunculara kaydırarak erişim ve quiz klavyesi açıkken kontrol düğmesine erişim.

## Güncel kodu canlı hesaba bağlanmadan açma

Normal macOS Terminal'de:

```sh
cd /Users/kocer/Projects/zankurd/zankurd_mobile
flutter run --no-pub -t tool/reliability_preview.dart -d CA57ACB3-4C9C-4CB6-AE25-7805B48A6F34
```

Bu özel giriş yalnız Mock repository ve bellek içi SharedPreferences kullanır.
Üretim `main()` fonksiyonunu, Firebase veya Supabase başlatmasını çağırmaz.
Gerçek hesaba giriş, gerçek davet veya ödeme oluşturmaz. Mağazaya gönderilecek
bir uygulama girişi değildir. Hot restart yerel senaryoyu sıfırlar.

Başlangıçta dün için yarım kalmış 7→8 seri koruması hazırlanır. Ana ekran
açılışında kurtarma bunu dünün kaydına uygular; bugün oynanmış sayılmamalıdır.
5. saniyede yerel bir oda daveti eklenir. Varsayılan koşuda push olayı yoktur:
görünür Ana/Yarış kartı 20 saniyelik yoklamayla daveti bulmalıdır.

Anlık ön plan olayını sınamak için komuta `--dart-define=PREVIEW_PUSH=true`
eklenir. Aynı derlemeyi Kurmancî/gece modunda görmek için
`--dart-define=PREVIEW_LANG=ku --dart-define=PREVIEW_DARK=true` kullanılabilir.

## Görsel ve etkileşim kontrolü

- Ana ve Yarış sekmesinde yeni davet görünmeli. Gizli sekmeler sorgulamamalı.
- Arkadaşlar ekranı açıkken friend push olayı mevcut listeyi yenilemeli
  (otomatik testte sahte mesaj, gerçek cihaz aşamasında gerçek test hesabı).
- Oda kurmada 50 soru ve 120 saniye seçilebilmeli; özet doğru olmalı.
  Dar ekran ve büyük yazıda seçenek/eylem taşması olmamalı.
- Uygulamayı arka plana alıp döndürün: görünür davet listesi hemen tazelenmeli.
- Yanlış davete otomatik katılım olmamalı; kimliksiz bildirimin dokunuşu güncel
  davet kartını göstermeli ve katılım karttan açıkça yapılmalı.
- Seri takviminde dünün onarımı ve bugünün henüz oynanmamış durumu kontrol edilmeli.

## Otomatik doğrulama

```sh
tool/ci_yerel.sh --tam
```

Odak dosyaları: `app_shell_paid_freeze_recovery_test.dart`,
`paid_freeze_recovery_service_test.dart`, `streak_paid_freeze_persistence_test.dart`,
`app_shell_social_refresh_test.dart`, `room_invite_polling_test.dart`,
`friends_lifecycle_polling_test.dart`, `play_hub_room_duration_test.dart`.

Canlı bildirim teslimatı bu yerel önizlemeyle doğrulanmaz. Sunucu SQL runtime
smoke, canlı tanım incelemesi ve sahip onaylı dağıtımdan sonra iki cihazda
ön plan/arka plan/kapalı uygulama testi ayrıca yapılmalıdır.
