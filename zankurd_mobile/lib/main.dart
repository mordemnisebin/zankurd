import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/app_config.dart';
import 'src/data/mock_zankurd_repository.dart';
import 'src/data/supabase_zankurd_repository.dart';
import 'src/data/zankurd_repository.dart';
import 'src/screens/splash_screen.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ZanKurdRepository repository;
  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    repository = SupabaseZanKurdRepository(Supabase.instance.client);
  } else {
    repository = MockZanKurdRepository();
  }

  runApp(ZanKurdApp(repository: repository));
}

class ZanKurdApp extends StatelessWidget {
  const ZanKurdApp({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZanKurd',
      theme: AppTheme.light(),
      home: SplashScreen(repository: repository),
    );
  }
}
