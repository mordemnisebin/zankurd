import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test('mobile auth redirect is app deep link and never localhost', () {
    expect(AuthProvider.authRedirectUri, 'com.zankurd.app://login-callback/');
    expect(AuthProvider.authRedirectUri, isNot(contains('localhost')));
  });

  test('Android manifest handles the Supabase login deep link', () {
    final source = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(source, contains('android:scheme="com.zankurd.app"'));
    expect(source, contains('android:host="login-callback"'));
  });

  test('daily reminders avoid exact alarm Play policy risk', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final notificationService = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();

    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(
      notificationService,
      contains('AndroidScheduleMode.inexactAllowWhileIdle'),
    );
    expect(
      notificationService,
      isNot(contains('AndroidScheduleMode.exactAllowWhileIdle')),
    );
  });

  test('iOS declares the photo-library reason used by avatar editing', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    expect(plist, contains('profil fotoğrafınızı seçebilmek'));
  });

  test('iOS açılış zemini koyu temayı da tanıyor', () {
    // Android açılışı 2026-07-27'de iki temaya ayrılmıştı: koyu temada
    // açılışta beyaz/krem bir kare çakıp sonra karanlığa geçiyordu. Aynı
    // kusur iOS'ta kalmıştı — storyboard tek bir sabit krem taşıyordu.
    //
    // Çözüm adlandırılmış renk: `LaunchBackground` açık temada #F7F4EE,
    // koyu temada #0E1512. Sabit renge dönüş bu bekçiyi kırar.
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(
      storyboard,
      contains('name="LaunchBackground"'),
      reason: 'açılış zemini adlandırılmış renge bağlanmamış',
    );
    expect(
      File(
        'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
      ).existsSync(),
      isTrue,
      reason: 'LaunchBackground renk kümesi yok',
    );

    final colorSet = File(
      'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
    ).readAsStringSync();
    expect(
      colorSet,
      contains('"value" : "dark"'),
      reason: 'renk kümesinde koyu tema varyantı yok',
    );
  });

  test('bildirim ikonu siluete uygun tek renkli kaynak kullanıyor', () {
    // 2026-07-27: bildirimler `@mipmap/ic_launcher` kullanıyordu. Android
    // bildirim küçük ikonunu **siluete** çevirir — rengi atar, yalnız
    // alfayı kullanır. Başlatıcı simgesinin zemini mağaza şartı gereği
    // opak beyaz olduğu için bildirimde düz beyaz bir kare çıkıyordu; hem
    // de günlük hatırlatıcının her gösteriminde.
    //
    // Kusur simge dosyaları renkli logoya geçirilince doğdu ve yalnız
    // gerçek cihazda bildirim gelince görünürdü.
    final source = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('@drawable/ic_stat_zankurd'),
      reason: 'bildirim ikonu tek renkli kaynağa bağlanmamış',
    );
    expect(
      source,
      isNot(contains("AndroidInitializationSettings('@mipmap")),
      reason: 'bildirim ikonu yine başlatıcı simgesine bağlanmış',
    );

    for (final density in const ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/drawable-$density/ic_stat_zankurd.png',
        ).existsSync(),
        isTrue,
        reason: '$density için bildirim ikonu üretilmemiş',
      );
    }
  });

  test('paylaşım önizlemesi var olan bir görsele işaret ediyor', () {
    // 2026-07-27: `og:image` `icons/icon-192x192.png` diyordu ama öyle bir
    // dosya hiç yok (gerçek adlar Icon-192 / Icon-512). Bağlantı
    // paylaşılınca önizleme kırık geliyordu. Ayrıca kart
    // `summary_large_image` olarak ilan edilmiş ama hiç `twitter:image`
    // konmamıştı — görsel isteyen bir kart, görselsiz.
    final html = File('web/index.html').readAsStringSync();
    final imageUrls = RegExp(
      r'(?:og:image|twitter:image)"\s+content="([^"]+)"',
    ).allMatches(html).map((m) => m.group(1)!).toList();

    expect(imageUrls, hasLength(2), reason: 'iki önizleme görseli beklenir');
    for (final url in imageUrls) {
      final fileName = url.split('/').last;
      expect(
        File('web/icons/$fileName').existsSync(),
        isTrue,
        reason: '$url web/icons altında yok',
      );
    }
  });

  test('web tarafı emekli marka turuncusunu taşımıyor', () {
    // 2026-07-24'te eylem rengi Tîrêj'e (#C2560E) geçti çünkü eski
    // #F5931E beyaz metinle 2.2:1 veriyordu. Web tarafı o geçişte geride
    // kaldı: tarayıcı çubuğu rengi, PWA tema rengi ve klavye odak halkası
    // 2026-07-27'ye kadar eski turuncuydu — uygulama ile site iki ayrı
    // marka turuncusu gösteriyordu.
    //
    // Palet değişimi kaynak kodda güvenle yapılıyor (sabitler tek yerde),
    // ama web klasörü Dart'ın dışında kaldığı için kimse oraya bakmamış.
    // Bekçi tam da o kör noktayı tutuyor.
    for (final path in const ['web/index.html', 'web/manifest.json']) {
      final source = File(path).readAsStringSync();
      // Yorum satırlarında geçmesi serbest: niçin değiştiğini anlatıyor.
      final withoutComments = source
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      expect(
        withoutComments,
        isNot(contains('#F5931E')),
        reason: '$path emekli marka turuncusunu kullanıyor',
      );
    }
  });

  test('yasal bağlantıların işaret ettiği belgeler gerçekten var', () {
    // 2026-07-27: uygulama hem Ayarlar'da hem paywall'da
    // `zankurd.com/terms.html` bağlantısı gösteriyordu ama öyle bir belge
    // hiç yazılmamıştı. Bağlantı ölü olduğu için değil, **var olmayan bir
    // sayfaya** işaret ettiği için tehlikeliydi: App Store otomatik
    // yenilenen abonelikte kullanım koşulu bağlantısını şart koşar ve
    // inceleyen kişi ona tıklar.
    //
    // Bekçi, her yasal URL'nin karşılığı olan kaynak belgenin depoda
    // durduğunu doğrular. Sitenin canlı olup olmadığını ölçemez — o
    // yüklemeyle ilgili; ama "hiç yazılmamış" hâlini bir daha yaşatmaz.
    const documents = {
      'privacy.html': 'docs/privacy_policy.html',
      'terms.html': 'docs/terms_of_service.html',
    };
    for (final url in [
      AppConfig.privacyPolicyUrl,
      AppConfig.termsOfServiceUrl,
    ]) {
      final fileName = url.split('/').last;
      final source = documents[fileName];
      expect(
        source,
        isNotNull,
        reason: '$url için kaynak belge eşlemesi yok',
      );
      expect(
        File(source!).existsSync(),
        isTrue,
        reason: '$url $source dosyasına işaret ediyor ama dosya yok',
      );
    }
  });

  test('iOS declares export compliance so uploads need no manual answer', () {
    // Anahtar yoksa App Store Connect her yüklemede "şifreleme kullanıyor
    // musunuz?" diye sorar ve yanıtlanana kadar build "Missing Compliance"
    // durumunda bekler. Yani eksikliği bir hata vermez — yalnız her
    // sürümde elle bir adım ekler ve o adım unutulursa build yayına
    // çıkmaz (2026-07-27).
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('ITSAppUsesNonExemptEncryption'));
  });

  test('iOS declares both interface languages for the store listing', () {
    // App Store liste sayfasındaki "Diller" satırı bu anahtardan üretilir.
    // Anahtar yokken yalnız geliştirme dili görünür — iki dilli bir
    // uygulama için mağazada yanlış bilgi demektir.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('CFBundleLocalizations'));
    for (final code in const ['ku', 'tr']) {
      expect(
        plist,
        contains('<string>$code</string>'),
        reason: '$code dili beyan edilmemiş',
      );
    }
  });

  test('app preserves the supported 200 percent system text scale', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('maxScaleFactor: 2.0'));
    expect(source, isNot(contains('maxScaleFactor: 1.35')));
  });

  test('app shell mounts expensive tabs only after first visit', () {
    final source = File('lib/src/screens/app_shell.dart').readAsStringSync();

    expect(source, contains('final Set<int> _visitedTabs = {0};'));
    expect(source, contains('_visitedTabs.add(i)'));
    expect(source, contains('_visitedTabs.contains(index)'));
  });

  test('leaderboard podium does not render a large empty pedestal block', () {
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('height: height,')));
  });
}
