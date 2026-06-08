Aşağıdaki APK analizinden yola çıkarak telifli/proprietary kodu kopyalamadan, sıfırdan Android/Kotlin tabanlı benzer bir Kürtçe online quiz uygulaması oluştur.

Kaynak bağlamı:
- Paket: kurdi.leyzok.pirs
- Uygulama türü: online quiz / soru-cevap / matematik öğrenme / yarışma / multiplayer battle / leaderboard.
- Launcher: SplashActivity benzeri açılış ekranı.
- Ana modüller: auth, profil, kategori, alt kategori, level, quiz play, review, bookmark, daily quiz, contest, tournament, leaderboard, battle, one-to-one, robot opponent, reward/coin store, spin wheel, notifications, settings, privacy/instructions.
- Yerel DB şemaları:
  - tbl_bookmark(id, que_id, question, answer, option_a, option_b, option_c, option_d, option_e, image_url, extra_note, cate_name, lang_id)
  - level(id, cat_id, sub_cat_id, level_no)
- Entegrasyonlar: Firebase Auth, Firebase Database/Firestore, Firebase Storage, FCM, Google Ads/AdMob, Play Billing, isteğe bağlı Facebook login/ads.
- Matematik içerikleri için MathJax veya WebView tabanlı TeX render desteği düşün.

İstek:
1. Modern Android projesi kur: Kotlin, Jetpack Compose veya XML tabanlı Material UI, MVVM, Hilt, Room, Retrofit/Firebase repository yapısı.
2. Paket adını yeni bir ad yap; mevcut APK’nin paket adını, anahtarlarını, API key’lerini, assetlerini veya birebir görsellerini kopyalama.
3. Sıfırdan domain model ve ekran akışı tasarla.
4. Önce proje klasör yapısını ve veri modellerini oluştur.
5. Sonra minimum çalışan MVP yap: Splash → Login/Guest → Category → Level → Quiz Play → Result → Bookmark.
6. Ardından leaderboard, tournament, battle, notifications, coin/reward, ads ve billing modüllerini feature flag ile ekle.
7. Soru içeriğini örnek/demo veriyle başlat; admin/backend yapısı daha sonra eklenecek şekilde soyutla.
8. Güvenlik: client tarafına gizli anahtar koyma; Firebase rules ve remote config için TODO bırak.

Bu analiz paketindeki şu dosyalara bak:
- AndroidManifest.decoded.xml
- reports/APK_ANALYSIS_SUMMARY_TR.md
- reports/resources_overview.md
- reports/app_classes.txt
- databases/*_schema.sql
- dex_info/*.app_classes.txt

Çıktı olarak önce uygulanabilir bir geliştirme planı, sonra dosya ağacı, sonra MVP kodlarını üret.
