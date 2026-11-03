import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'branded_loader.dart';

/// `runApp`'in İLK karede çizdiği, hiçbir uzak/ağır işe bağlı olmayan kök.
///
/// ## Kusur
///
/// `main()` eskiden `runApp`'ı Firebase, Supabase, RevenueCat, SyncManager,
/// yerel ilerleme kapsamı ve 2173 soruluk bankanın okunmasından SONRA
/// çağırıyordu. Her adım zaman sınırlıydı ama sınırlar toplanıyordu:
/// yavaş ağda Flutter'ın ilk karesi saniyelerce gelmiyor, kullanıcı yalnız
/// iOS'un yerel açılış ekranını görüyordu. Bağımlılık yönü de tersti —
/// çevrimdışı-öncelikli bir uygulamada uzak servisler ilk kareyi değil,
/// ilk kare onları beklememeliydi.
///
/// ## Niçin sessiz kalırdı
///
/// Hızlı ağda ve geliştirici cihazında toplam süre kısa olduğundan kusur
/// görünmezdi; yalnız yavaş ağ / eski cihaz / soğuk açılışta ortaya çıkar,
/// hiçbir test de `runApp`'ın ne zaman çağrıldığını ölçmezdi.
///
/// ## Sözleşme
///
/// * İlk kare [app] tamamlanmadan çizilir (yalnız zemin + yükleyici).
/// * Oturum durumu belli olmadan hiçbir giriş/giriş-dışı ekran çizilmez:
///   gerçek kök (`ZanKurdApp`, oturumu geri yüklenmiş `AuthProvider` ile)
///   hazır olana dek bu kare kalır. Yani oturumlu kullanıcı bir an bile
///   çıkış yapmış arayüz görmez; yerel oturum geri yükleme hızlıdır,
///   ağ tazelemesi beklenmez.
/// * [app] hata verirse [onError] ile yedek kök kurulur; açılış hataya
///   kilitlenmez.
class BootHost extends StatefulWidget {
  const BootHost({required this.app, this.themeMode, this.onError, super.key});

  final Future<Widget> app;

  /// Kullanıcının tema tercihi (yerel, hızlı). Gelene dek karanlık varsayılan.
  final Future<ThemeMode>? themeMode;

  /// [app] hata verirse kurulacak yedek kök.
  final Widget Function(Object error)? onError;

  @override
  State<BootHost> createState() => _BootHostState();
}

class _BootHostState extends State<BootHost> {
  Widget? _root;
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    widget.themeMode
        ?.then((mode) {
          if (mounted && _root == null) setState(() => _mode = mode);
        })
        .catchError((Object _) {});
    widget.app.then(
      (root) {
        if (mounted) setState(() => _root = root);
      },
      onError: (Object error, StackTrace stack) {
        ErrorReporter.record(error, stack, reason: 'boot host app');
        final fallback = widget.onError;
        if (mounted && fallback != null) {
          setState(() => _root = fallback(error));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = _root;
    if (root != null) return root;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZanKurd',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      home: Builder(
        builder: (context) => Scaffold(
          key: const ValueKey('boot-frame'),
          backgroundColor: AppTheme.bgOf(context),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.backgroundGradient(context),
            ),
            child: const Center(
              child: BrandedLoader(size: 24, strokeWidth: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}
