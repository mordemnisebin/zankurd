import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'src/config/app_config.dart';
import 'src/data/mock_zankurd_repository.dart';
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
import 'src/theme/app_theme.dart';
import 'src/widgets/responsive_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Anonim analitik servisi başlat
  await AnalyticsService.instance.initialize();

  final languageProvider = await LanguageProvider.load();
  final themeProvider = await ThemeProvider.load();
  final soundProvider = await SoundProvider.load();
  final reducedMotionProvider = await ReducedMotionProvider.load();
  final childSafetyProvider = await ChildSafetyProvider.load();

  runApp(
    ZanKurdApp(
      repository: repository,
      authProvider: authProvider,
      languageProvider: languageProvider,
      themeProvider: themeProvider,
      soundProvider: soundProvider,
      reducedMotionProvider: reducedMotionProvider,
      childSafetyProvider: childSafetyProvider,
    ),
  );
}

class ZanKurdApp extends StatelessWidget {
  const ZanKurdApp({
    required this.repository,
    this.authProvider,
    this.languageProvider,
    this.themeProvider,
    this.soundProvider,
    this.reducedMotionProvider,
    this.childSafetyProvider,
    super.key,
  });

  final ZanKurdRepository repository;
  final AuthProvider? authProvider;
  final LanguageProvider? languageProvider;
  final ThemeProvider? themeProvider;
  final SoundProvider? soundProvider;
  final ReducedMotionProvider? reducedMotionProvider;
  final ChildSafetyProvider? childSafetyProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => languageProvider ?? LanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => authProvider ?? AuthProvider.test(),
        ),
        ChangeNotifierProvider(create: (_) => themeProvider ?? ThemeProvider()),
        ChangeNotifierProvider(create: (_) => soundProvider ?? SoundProvider()),
        ChangeNotifierProvider(
          create: (_) => reducedMotionProvider ?? ReducedMotionProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => childSafetyProvider ?? ChildSafetyProvider(),
        ),
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
          builder: (context, child) =>
              ResponsiveWrapper(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
