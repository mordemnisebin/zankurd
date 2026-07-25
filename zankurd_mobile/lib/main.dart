import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/config/app_config.dart';
import 'src/data/mock_zankurd_repository.dart';
import 'src/data/question_bank_loader.dart';
import 'src/data/supabase_zankurd_repository.dart';
import 'src/data/sync_manager.dart';
import 'src/data/zankurd_repository.dart';
import 'src/l10n/lang.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/child_safety_provider.dart';
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
                    ku ? 'Şaşiyek çêbû' : 'Bir hata oluştu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ku
                        ? 'Tiştek şaş çû. Ji kerema xwe dîsa biceribîne.'
                        : 'Bir şeyler ters gitti. Lütfen tekrar dene.',
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
        authProvider = AuthProvider.test();
      }

      await SyncManager.initialize(repository);
      await NotificationService.load();

      // Bağımsız servis ve provider'ları paralel yükle. Sonuçlar indeksle
      // değil kendi future'larıyla okunur: `results[3] as ThemeProvider`
      // biçimi listeye bir eleman eklendiğinde sessizce kayar ve runtime'da
      // cast hatasına dönerdi.
      final languageFuture = LanguageProvider.load();
      final themeFuture = ThemeProvider.load();
      final soundFuture = SoundProvider.load();
      final reducedMotionFuture = ReducedMotionProvider.load();
      final childSafetyFuture = ChildSafetyProvider.load();
      final premiumFuture = PremiumService.load();

      await Future.wait<void>([
        QuestionBankLoader.instance.load(),
        AnalyticsService.instance.initialize(),
        languageFuture,
        themeFuture,
        soundFuture,
        reducedMotionFuture,
        childSafetyFuture,
        premiumFuture,
      ]);

      final languageProvider = await languageFuture;
      errorScreenIsKu = languageProvider.isKu;
      languageProvider.addListener(() {
        errorScreenIsKu = languageProvider.isKu;
      });
      final themeProvider = await themeFuture;
      final soundProvider = await soundFuture;
      final reducedMotionProvider = await reducedMotionFuture;
      final childSafetyProvider = await childSafetyFuture;
      final premiumService = await premiumFuture;

      runApp(
        ZanKurdApp(
          repository: repository,
          authProvider: authProvider,
          languageProvider: languageProvider,
          themeProvider: themeProvider,
          soundProvider: soundProvider,
          reducedMotionProvider: reducedMotionProvider,
          childSafetyProvider: childSafetyProvider,
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
    ChildSafetyProvider? childSafetyProvider,
    PremiumService? premiumService,
    super.key,
  }) : authProvider = authProvider ?? AuthProvider.test(),
       languageProvider = languageProvider ?? LanguageProvider(),
       themeProvider = themeProvider ?? ThemeProvider(),
       soundProvider = soundProvider ?? SoundProvider(),
       reducedMotionProvider = reducedMotionProvider ?? ReducedMotionProvider(),
       childSafetyProvider = childSafetyProvider ?? ChildSafetyProvider(),
       premiumService = premiumService ?? PremiumService.fallback();

  final ZanKurdRepository repository;
  final AuthProvider authProvider;
  final LanguageProvider languageProvider;
  final ThemeProvider themeProvider;
  final SoundProvider soundProvider;
  final ReducedMotionProvider reducedMotionProvider;
  final ChildSafetyProvider childSafetyProvider;
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
        ChangeNotifierProvider<ChildSafetyProvider>.value(
          value: childSafetyProvider,
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
          home: SplashScreen(next: AppShell(repository: repository)),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.85,
            maxScaleFactor: 2.0,
            child: ResponsiveWrapper(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
