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
import 'src/config/app_config.dart';
import 'src/data/mock_zankurd_repository.dart';
import 'src/data/question_bank_loader.dart';
import 'src/data/supabase_zankurd_repository.dart';
import 'src/data/sync_manager.dart';
import 'src/data/zankurd_repository.dart';
import 'src/l10n/lang.dart';
import 'src/l10n/strings.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/reduced_motion_provider.dart';
import 'src/providers/sound_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/screens/app_shell.dart';
import 'src/screens/splash_screen.dart';
import 'src/services/analytics_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/premium_service.dart';
import 'src/theme/app_theme.dart';
import 'src/utils/error_reporter.dart';
import 'src/widgets/responsive_wrapper.dart';

/// Açılış penceresinde ısıtılan iş.
///
/// AppShell mount olduğunda iki kapı var: onboarding bayrağı
/// (SharedPreferences) ve oyuncu adı (`getProfileName`, ağ). İkisi de
/// splash'ten SONRA başlıyordu, yani kullanıcı 1800 ms logo + 450 ms
/// geçiş + iki spinner görüyordu — dört ayrı bekleme yüzeyi.
///
/// Burada ikisi de splash görünürken başlatılır. Hata yutulmaz ama
/// açılışı da engellemez: `SplashScreen` readiness başarısız olsa da
/// geçiş yapar, AppShell kendi kontrolünü yine çalıştırır.
Future<void> _warmUpShell(ZanKurdRepository repository) async {
  await SharedPreferences.getInstance();
  await repository.getProfileName();
}

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

      // Crash raporlama (web'de Crashlytics desteklenmez).
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (!kIsWeb) {
          FlutterError.onError =
              FirebaseCrashlytics.instance.recordFlutterFatalError;
          PlatformDispatcher.instance.onError = (error, stack) {
            FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
            return true;
          };
        }
      } catch (_) {
        // Firebase yapılandırması olmayan platformlarda sessizce devam et.
      }

      // Abonelik kimliği, AuthProvider mevcut oturumu eşlemeden önce hazır
      // olmalı; aksi halde ilk açılıştaki kullanıcı eşleşmesi kaçabilir.
      final premiumService = await PremiumService.load();

      final ZanKurdRepository repository;
      final AuthProvider authProvider;
      if (AppConfig.hasSupabaseConfig) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
        );
        repository = SupabaseZanKurdRepository(Supabase.instance.client);
        authProvider = AuthProvider(Supabase.instance.client);
      } else {
        repository = MockZanKurdRepository();
        authProvider = AuthProvider.test(authenticated: true);
      }

      await SyncManager.initialize(repository);

      // Bağımsız servis ve provider'ları paralel yükle. Sonuçlar indeksle
      // değil kendi future'larıyla okunur: `results[3] as ThemeProvider`
      // biçimi listeye bir eleman eklendiğinde sessizce kayar ve runtime'da
      // cast hatasına dönerdi.
      final languageFuture = LanguageProvider.load();
      final themeFuture = ThemeProvider.load();
      final soundFuture = SoundProvider.load();
      final reducedMotionFuture = ReducedMotionProvider.load();

      // İlk kare için gerçekten gereken iş: soru bankası ve dil/tema/ses
      // tercihleri. `AnalyticsService.initialize()` ve
      // `NotificationService.load()` buradan ÇIKARILDI — ikisi de ilk
      // karenin ne çizileceğini etkilemiyor, ama ikisi de bekletiyordu.
      //
      // NotificationService özellikle pahalıydı: `tz.initializeTimeZones()`
      // bütün saat dilimi veritabanını okuyor ve cihaz saat dilimi için
      // platform kanalına iniyor — bildirimler kapalı olsa bile
      // (2026-07-31 denetimi).
      await Future.wait<void>([
        QuestionBankLoader.instance.load(),
        languageFuture,
        themeFuture,
        soundFuture,
        reducedMotionFuture,
      ]);

      final languageProvider = await languageFuture;
      errorScreenIsKu = languageProvider.isKu;
      languageProvider.addListener(() {
        errorScreenIsKu = languageProvider.isKu;
      });
      final themeProvider = await themeFuture;
      final soundProvider = await soundFuture;
      final reducedMotionProvider = await reducedMotionFuture;

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
      startInBackground(
        AnalyticsService.instance.initialize(),
        'analytics init',
      );
      startInBackground(NotificationService.load(), 'notifications load');

      runApp(
        ZanKurdApp(
          repository: repository,
          authProvider: authProvider,
          languageProvider: languageProvider,
          themeProvider: themeProvider,
          soundProvider: soundProvider,
          reducedMotionProvider: reducedMotionProvider,
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
    AuthProvider? authProvider,
    LanguageProvider? languageProvider,
    ThemeProvider? themeProvider,
    SoundProvider? soundProvider,
    ReducedMotionProvider? reducedMotionProvider,
    PremiumService? premiumService,
    super.key,
  }) : authProvider = authProvider ?? AuthProvider.test(),
       languageProvider = languageProvider ?? LanguageProvider(),
       themeProvider = themeProvider ?? ThemeProvider(),
       soundProvider = soundProvider ?? SoundProvider(),
       reducedMotionProvider = reducedMotionProvider ?? ReducedMotionProvider(),
       premiumService = premiumService ?? PremiumService.fallback();

  final ZanKurdRepository repository;
  final AuthProvider authProvider;
  final LanguageProvider languageProvider;
  final ThemeProvider themeProvider;
  final SoundProvider soundProvider;
  final ReducedMotionProvider reducedMotionProvider;
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
        ChangeNotifierProvider<PremiumService>.value(value: premiumService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ZanKurd',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.mode,
          themeAnimationDuration: const Duration(milliseconds: 600),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: SplashScreen(
            // Marka penceresi artık boşa harcanmıyor: AppShell'in mount
            // olur olmaz yapacağı iki iş bu 600 ms içinde ısıtılıyor —
            // SharedPreferences ve `getProfileName()`. Eskiden splash
            // 1800 ms bekliyor, SONRA AppShell iki tam ekran spinner
            // daha çiziyordu (2026-07-31 denetimi).
            readiness: _warmUpShell(repository),
            next: AppShell(repository: repository),
          ),
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
    );
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
