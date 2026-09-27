import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/utils/join_deep_link.dart';
import 'src/config/app_config.dart';
import 'src/data/offline_zankurd_repository.dart';
import 'src/data/question_bank_loader.dart';
import 'src/data/supabase_zankurd_repository.dart';
import 'src/data/sync_manager.dart';
import 'src/data/zankurd_repository.dart';
import 'src/l10n/lang.dart';
import 'src/l10n/material_locales.dart';
import 'src/l10n/strings.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/analytics_consent_provider.dart';
import 'src/providers/reduced_motion_provider.dart';
import 'src/providers/remote_availability.dart';
import 'src/providers/untimed_mode_provider.dart';
import 'src/utils/boot_step.dart';
import 'src/utils/firebase_bootstrap.dart';
import 'src/providers/sound_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/screens/app_shell.dart';
import 'src/screens/splash_screen.dart';
import 'src/services/analytics_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/premium_service.dart';
import 'src/services/push_tap_router.dart';
import 'src/services/push_token_sync.dart';
import 'src/services/firebase_push_token_source.dart';
import 'src/theme/app_theme.dart';
import 'src/utils/app_route.dart';
import 'src/utils/error_reporter.dart';
import 'src/widgets/responsive_wrapper.dart';

/// Açılış penceresinde ısıtılan iş.
///
/// AppShell'in kapıları yalnız yerel `SharedPreferences` bayraklarıyla
/// belirlenir. Oyuncu adı ağdan arka planda HomeScreen tarafından yüklenir;
/// bu yüzden açılış hazır oluşunun parçası değildir.
///
/// Yerel depo splash görünürken hazırlanır; ağ isteği burada beklenmez.
Future<void> _warmUpShell() => SharedPreferences.getInstance();

/// Global hata ekranının dili. `ErrorWidget.builder` widget ağacının dışında
/// çalıştığı için `LangContext`'e erişemez; dil tercihi yüklendiğinde burada
/// güncellenir. Varsayılan Kurmancî'dir (uygulamanın varsayılan dili).
bool errorScreenIsKu = true;

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Widget rendering hataları için şık global kurtarma UI'ı
      ErrorWidget.builder = (FlutterErrorDetails details) {
        ErrorReporter.record(
          details.exception,
          details.stack ?? StackTrace.empty,
          reason: 'Flutter ErrorWidget render exception',
        );
        final ku = errorScreenIsKu;
        return Material(
          color: Colors.transparent,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE53935),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Tr.forKu(K.genericErrorTitle, ku),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Tr.forKu(K.genericErrorBody, ku),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      };

      // Web'de ekran okuyucu kullanıcıları gizli "Enable accessibility" butonuna
      // bağımlı kalmasın: semantik ağaç uygulama açılışında otomatik kurulur.
      if (kIsWeb) {
        SemanticsBinding.instance.ensureSemantics();
      }

      final releaseConfigurationIssues = AppConfig.validateForRelease(
        isReleaseMode: kReleaseMode,
        requireRevenueCat:
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS),
      );
      if (releaseConfigurationIssues.isNotEmpty) {
        runApp(_ConfigurationErrorApp(issues: releaseConfigurationIssues));
        return;
      }

      // Birbirinden bağımsız açılış işleri ilk uzak beklemeden önce başlar.
      // Her future kendi zaman aşımı/fallback sınırına burada bağlanır; böylece
      // erken tamamlanan bir hata event loop'ta sahipsiz kalmaz ve başlangıç
      // süresi bu işlerin toplamına değil en yavaş zorunlu işe yaklaşır.
      final languageFuture = bootStep(
        LanguageProvider.load(),
        reason: 'LanguageProvider load',
        fallback: LanguageProvider.new,
      );
      final themeFuture = bootStep(
        ThemeProvider.load(),
        reason: 'ThemeProvider load',
        fallback: ThemeProvider.new,
      );
      final soundFuture = bootStep(
        SoundProvider.load(),
        reason: 'SoundProvider load',
        fallback: SoundProvider.new,
      );
      final reducedMotionFuture = bootStep(
        ReducedMotionProvider.load(),
        reason: 'ReducedMotionProvider load',
        fallback: ReducedMotionProvider.new,
      );
      final untimedModeFuture = bootStep(
        UntimedModeProvider.load(),
        reason: 'UntimedModeProvider load',
        fallback: UntimedModeProvider.new,
      );
      final analyticsConsentFuture = bootStep(
        AnalyticsConsentProvider.load(),
        reason: 'AnalyticsConsentProvider load',
        fallback: AnalyticsConsentProvider.new,
      );
      final questionBankFuture = bootStepVoid(
        QuestionBankLoader.instance.load(),
        reason: 'question bank load',
        timeout: const Duration(seconds: 8),
      );
      final premiumFuture = bootStep(
        PremiumService.load(),
        reason: 'premium load',
        fallback: PremiumService.fallback,
      );
      final remoteReadyFuture = AppConfig.hasSupabaseConfig
          ? bootStep(
              Supabase.initialize(
                url: AppConfig.supabaseUrl,
                publishableKey: AppConfig.supabaseAnonKey,
              ).then((_) => true),
              reason: 'supabase init',
              fallback: () => false,
            )
          : Future<bool>.value(false);

      // Crash raporlama (web'de Crashlytics desteklenmez).
      // Zaman sınırlı: Firebase'in yanıt vermemesi uygulamanın açılmasını
      // engellememeli. `catch` yalnız fırlatmayı yakalar, asılı kalmayı
      // yakalamaz — bkz. `bootStep`.
      final firebaseReady = await initializeFirebaseForBoot(
        initialize: () async {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        },
        disableCrashlytics: () async {
          if (!kIsWeb) {
            await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
              false,
            );
          }
        },
      );
      // Bildirime dokununca doğru ekrana yönlendirme yalnız Firebase gerçekten
      // kurulduysa anlamlıdır (`onMessageOpenedApp`/`getInitialMessage`
      // Firebase App'e ihtiyaç duyar). Başlatma başarısız olduysa
      // (`firebaseReady == false`) çağrılmaz; mevcut çevrimdışı/hatasız
      // açılış akışı bundan etkilenmemeli.
      if (firebaseReady) {
        unawaited(PushTapRouter.wireFirebase());
      }

      // Abonelik kimliği, AuthProvider mevcut oturumu eşlemeden önce hazır
      // olmalı; aksi halde ilk açılıştaki kullanıcı eşleşmesi kaçabilir.
      final premiumService = await premiumFuture;

      final ZanKurdRepository repository;
      final AuthProvider authProvider;
      // Supabase açılamazsa uygulama ÇEVRİMDIŞI açılır. Banka cihazda
      // olduğu için bu tam bir deneyim sunar; alternatif olan "hiç açılmama"
      // ise hiçbir şey sunmaz.
      final remoteReady = await remoteReadyFuture;
      if (remoteReady) {
        repository = SupabaseZanKurdRepository(Supabase.instance.client);
        authProvider = AuthProvider(Supabase.instance.client);
      } else {
        repository = OfflineZanKurdRepository();
        authProvider = AuthProvider.offline();
      }

      await bootStepVoid(
        SyncManager.initialize(repository),
        reason: 'sync init',
      );
      await bootStepVoid(
        authProvider.bindLocalProgressScope(),
        reason: 'local progress scope',
      );

      // İlk kare için gerçekten gereken iş: soru bankası ve dil/tema/ses
      // tercihleri. `AnalyticsService.initialize()` ve
      // `NotificationService.load()` buradan ÇIKARILDI — ikisi de ilk
      // karenin ne çizileceğini etkilemiyor, ama ikisi de bekletiyordu.
      //
      // NotificationService özellikle pahalıydı: `tz.initializeTimeZones()`
      // bütün saat dilimi veritabanını okuyor ve cihaz saat dilimi için
      // platform kanalına iniyor — bildirimler kapalı olsa bile
      // (2026-07-31 denetimi).
      // Soru bankasına daha geniş bir pay veriliyor: yerel varlık okuması
      // ağdan bağımsızdır ve içeriğin gelmemesi boş kategori demektir.
      // Yine de sınırsız değil — hiç açılmayan bir uygulama, eksik içerikli
      // bir uygulamadan kötüdür.
      await questionBankFuture;

      final languageProvider = await languageFuture;
      errorScreenIsKu = languageProvider.isKu;
      languageProvider.addListener(() {
        errorScreenIsKu = languageProvider.isKu;
      });
      final themeProvider = await themeFuture;
      final soundProvider = await soundFuture;
      final reducedMotionProvider = await reducedMotionFuture;
      final untimedModeProvider = await untimedModeFuture;
      final analyticsConsentProvider = await analyticsConsentFuture;

      // İlk kareyi bekletmeyen işler. Hatalar yutulmaz, bildirilir; ama
      // hiçbiri uygulamanın açılmasını engellemez.
      void startInBackground(Future<void> future, String reason) {
        unawaited(
          future.catchError((Object error, StackTrace stack) {
            ErrorReporter.record(error, stack, reason: reason);
          }),
        );
      }

      startInBackground(premiumService.warmUp(), 'premium warmUp');
      if (analyticsConsentProvider.enabled) {
        startInBackground(
          AnalyticsService.instance.initialize(enabled: true),
          'analytics init',
        );
        if (firebaseReady && !kIsWeb) {
          startInBackground(
            ErrorReporter.setCollectionEnabled(true),
            'crashlytics enable',
          );
        }
      }
      startInBackground(NotificationService.load(), 'notifications load');

      runApp(
        ZanKurdApp(
          repository: repository,
          authProvider: authProvider,
          languageProvider: languageProvider,
          themeProvider: themeProvider,
          soundProvider: soundProvider,
          reducedMotionProvider: reducedMotionProvider,
          untimedModeProvider: untimedModeProvider,
          analyticsConsentProvider: analyticsConsentProvider,
          remoteAvailability: RemoteAvailability(reachable: remoteReady),
          premiumService: premiumService,
        ),
      );
    },
    (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'Uncaught error in runZonedGuarded',
      );
    },
  );
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.issues});

  final List<ReleaseConfigurationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (issues.contains(ReleaseConfigurationIssue.supabase)) 'Supabase',
      if (issues.contains(ReleaseConfigurationIssue.revenueCat)) 'RevenueCat',
    ].join(', ');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_rounded, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Uygulama yapılandırması eksik',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$missing ayarları bu üretim derlemesine eklenmemiş. '
                    'Lütfen destek ekibiyle iletişime geç.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ZanKurdApp extends StatelessWidget {
  /// Verilmeyen provider'lar için yedek instance'lar burada, `build()`
  /// içinde değil, bir kez oluşturulur. `build()` içinde `?? Provider()`
  /// yazılırsa her yeniden çizimde yeni bir ChangeNotifier üretilir ve
  /// eski dinleyiciler sessizce kopar.
  ZanKurdApp({
    required this.repository,
    this.home,
    AuthProvider? authProvider,
    LanguageProvider? languageProvider,
    ThemeProvider? themeProvider,
    SoundProvider? soundProvider,
    ReducedMotionProvider? reducedMotionProvider,
    UntimedModeProvider? untimedModeProvider,
    AnalyticsConsentProvider? analyticsConsentProvider,
    RemoteAvailability? remoteAvailability,
    PremiumService? premiumService,
    super.key,
  }) : authProvider = authProvider ?? AuthProvider.test(),
       languageProvider = languageProvider ?? LanguageProvider(),
       themeProvider = themeProvider ?? ThemeProvider(),
       soundProvider = soundProvider ?? SoundProvider(),
       reducedMotionProvider = reducedMotionProvider ?? ReducedMotionProvider(),
       untimedModeProvider = untimedModeProvider ?? UntimedModeProvider(),
       analyticsConsentProvider =
           analyticsConsentProvider ?? AnalyticsConsentProvider(),
       remoteAvailability =
           remoteAvailability ?? RemoteAvailability(reachable: true),
       premiumService = premiumService ?? PremiumService.fallback();

  final ZanKurdRepository repository;
  final Widget? home;
  final AuthProvider authProvider;
  final LanguageProvider languageProvider;
  final ThemeProvider themeProvider;
  final SoundProvider soundProvider;
  final ReducedMotionProvider reducedMotionProvider;
  final UntimedModeProvider untimedModeProvider;
  final AnalyticsConsentProvider analyticsConsentProvider;
  final RemoteAvailability remoteAvailability;
  final PremiumService premiumService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository tek bir immutable instance olarak paylaşılıyor —
        // ekranların constructor'ından geçirmek yerine context üzerinden okunur.
        Provider<ZanKurdRepository>.value(value: repository),
        // Dışarıdan verilen instance'lar `.value` ile paylaşılır. `create:`
        // ile verilirse Provider bunların sahipliğini üstlenir ve ağaç
        // söküldüğünde dispose eder; oysa bu nesneler main() içinde
        // oluşturulmuş, başka yerlerden de erişilen singleton'lardır.
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<SoundProvider>.value(value: soundProvider),
        ChangeNotifierProvider<ReducedMotionProvider>.value(
          value: reducedMotionProvider,
        ),
        ChangeNotifierProvider<UntimedModeProvider>.value(
          value: untimedModeProvider,
        ),
        ChangeNotifierProvider<AnalyticsConsentProvider>.value(
          value: analyticsConsentProvider,
        ),
        ChangeNotifierProvider<RemoteAvailability>.value(
          value: remoteAvailability,
        ),
        ChangeNotifierProvider<PremiumService>.value(value: premiumService),
      ],
      child: Consumer2<ThemeProvider, ReducedMotionProvider>(
        // Davet bağlantısını `WidgetsApp`in kendi rota gözlemcisinden ÖNCE
        // yakalar (bkz. JoinDeepLinkScope): kapsam MaterialApp'in üstünde
        // olmalı ki gözlemcisi daha önce kaydolsun.
        builder: (context, themeProvider, reducedMotion, _) => JoinDeepLinkScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ZanKurd',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.mode,
            themeAnimationDuration: reducedMotion.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 600),
            themeAnimationCurve: Curves.easeInOutCubic,
            locale: const Locale('tr'),
            supportedLocales: AppMaterialLocales.supported,
            localizationsDelegates: AppMaterialLocales.delegates,
            navigatorObservers: [appRouteObserver, appPageRouteObserver],
            // `home:` yerine `routes` + `onGenerateInitialRoutes` — bkz.
            // `_buildInitialRoutes` üstündeki belge. `routes` yalnız "/" için
            // tek satırlık bir tablo: `home` alanının Flutter içindeki ikinci
            // görevini (Navigator'ın "bir rota kaynağım var" saymasını, bkz.
            // `WidgetsApp._usesNavigator`) devralır; asıl gösterimi hâlâ
            // `_home()` üretir.
            routes: {Navigator.defaultRouteName: (context) => _home()},
            onGenerateInitialRoutes: _buildInitialRoutes,
            builder: (context, child) {
              // Sistemin "Hareketi Azalt" tercihi 2026-07-31'e kadar HİÇ
              // okunmuyordu. `ReducedMotionProvider`ın sınıf belgesi
              // "kullanıcı tercihi VEYA sistem tercihi" diyor ve
              // `reduceMotion` getter'ı `_userReduce || _systemReduce`
              // döndürüyordu — ama `setSystemReduce`i çağıran tek satır
              // yoktu, yani ikinci koşul hep false kalıyordu. iOS/Android
              // erişilebilirlik ayarından hareketi kapatan kullanıcı,
              // uygulamada ayrıca aynı anahtarı bulup açmak zorundaydı.
              //
              // `build` içinde okunuyor: sistem tercihi çalışırken
              // değişebilir ve MediaQuery zaten yeniden çizim tetikler.
              final disableAnimations = MediaQuery.disableAnimationsOf(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                reducedMotionProvider.setSystemReduce(disableAnimations);
              });
              return MediaQuery.withClampedTextScaling(
                minScaleFactor: 0.85,
                maxScaleFactor: 2.0,
                // Durum çubuğu ikonları hiçbir yerde ayarlanmamıştı; açık
                // temada beyaz saat/pil krem zemin üzerine düşüyor ve
                // okunmuyordu (2026-07-25 canlı denetimi, iOS). Ekranların
                // çoğu AppBar kullanmadığı için stil uygulama kökünde,
                // etkin parlaklığa göre verilir.
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _overlayStyleFor(context),
                  child: ResponsiveWrapper(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Açılış ekranı: `home` verilmemişse marka penceresi + [AppShell].
  Widget _home() {
    return home ??
        SplashScreen(
          // Marka penceresi AppShell'in yerel kapı bayraklarını okumadan
          // önce tercih deposunu ısıtır. Profil adı ağdan arka planda
          // yüklendiği için splash hazır oluşunu asla geciktirmez.
          readiness: _warmUpShell(),
          next: AppShell(
            repository: repository,
            pushTokenSync: PushTokenSync(
              source: kIsWeb
                  ? const NoopPushTokenSource()
                  : const FirebasePushTokenSource(),
              repository: repository,
            ),
          ),
        );
  }

  /// İlk rotayı `initialRouteName`i YOK SAYARAK her zaman [_home] ile üretir.
  ///
  /// ## Kusur
  ///
  /// Flutter 3.8+'ta mobil deep linking varsayılan AÇIK: soğuk açılışta
  /// `defaultRouteName` platformdan `/join/KOD` gibi evrensel bir bağlantı
  /// yolu taşıyabilir. `MaterialApp` bu callback verilmediğinde
  /// `Navigator.defaultGenerateInitialRoutes`u kullanır — o da yolu `/`,
  /// `/join`, `/join/KOD` parçalarına bölüp HER biri için `onGenerateRoute`
  /// çağırır. Bu uygulamanın `/join` ve `/join/KOD` için bir rota üreticisi
  /// olmadığından ("routes" tablosu yalnız "/" içerir, bkz. `build()`),
  /// parçalama son parçada başarısız olur ve Flutter bunu
  /// `FlutterError.reportError` ile bildirip sessizce `/`e düşer.
  ///
  /// ## Niçin sessiz kalırdı
  ///
  /// Düşüş her zaman doğru ekrana (ana sayfa) vardığı için kullanıcı hiçbir
  /// şey fark etmiyordu; hata yalnız konsolu izleyen ya da
  /// `tester.takeException()` çağıran biri tarafından görülürdü. Soğuk
  /// açılış deep link'i bu değişiklikten önce hiç test edilmiyordu — bkz.
  /// `test/app_shell_join_deep_link_test.dart` ("soğuk açılış" grubu).
  ///
  /// Bu metot yol parçalama/onGenerateRoute deneme mekanizmasını hiç
  /// çalıştırmaz: yol ne olursa olsun (bilinen, bilinmeyen, `/join/...`)
  /// uygulama her zaman `home` ile ve hatasız açılır.
  /// `JoinDeepLink.consumeInitialRoute()` `defaultRouteName`'i PLATFORMDAN
  /// doğrudan okur — bu metottan bağımsız çalışmaya devam eder, yani deep
  /// link kodu burada kaybolmaz (bkz. `AppShell._consumeJoinDeepLink`).
  List<Route<dynamic>> _buildInitialRoutes(String initialRouteName) {
    return [
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: Navigator.defaultRouteName),
        builder: (context) => _home(),
      ),
    ];
  }

  /// Etkin temanın parlaklığına göre durum çubuğu stili. Açık temada koyu
  /// ikon, koyu temada açık ikon.
  ///
  /// Not: `statusBarBrightness` iOS'ta *zeminin* parlaklığını, Android'de
  /// karşılığı olan `statusBarIconBrightness` ise *ikonun* parlaklığını
  /// tanımlar — ikisi birbirinin tersidir.
  static SystemUiOverlayStyle _overlayStyleFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}
