import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'launch_frame.dart';

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
  const BootHost({required this.app, this.onError, super.key});

  final Future<Widget> app;

  /// [app] hata verirse kurulacak yedek kök.
  final Widget Function(Object error)? onError;

  @override
  State<BootHost> createState() => _BootHostState();
}

class _BootHostState extends State<BootHost> {
  Widget? _root;

  @override
  void initState() {
    super.initState();
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
    // Kök gelince kısa solma; hareket azaltma açıksa anında.
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
      child: root != null
          ? KeyedSubtree(key: const ValueKey('boot-root'), child: root)
          : MaterialApp(
              key: const ValueKey('boot-app'),
              debugShowCheckedModeBanner: false,
              title: 'ZanKurd',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              // Uygulama temasına ASLA geçmez: yerel açılış ekranı kullanıcının
              // uygulama içi tema tercihini bilemez; sistem parlaklığını izler.
              themeMode: ThemeMode.system,
              home: const Scaffold(
                key: ValueKey('boot-frame'),
                body: LaunchFrame(),
              ),
            ),
    );
  }
}
