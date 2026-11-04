import 'dart:async';

import 'boot_step.dart';
import 'error_reporter.dart';

/// Firebase'i ilk kareyi bekletmeden başlatır.
///
/// [timeout] yalnız İLK EKRANIN bekleme sınırıdır; altta çalışan
/// `initialize()` iptal edilmez. Süre aşılırsa `false` döner, ama başlatma
/// sonradan başarıyla bitince Crashlytics kapatılır ve [onLateReady] çağrılır
/// (bildirim dokunuşu ve ön plan push aboneliği buradan kurulur). Eskiden
/// zaman aşımı "Firebase hiç gelmedi" sayılıyor, abonelikler kalıcı olarak
/// atlanıyordu (GPT-6 Pro ALAN 4).
Future<bool> initializeFirebaseForBoot({
  required Future<void> Function() initialize,
  required Future<void> Function() disableCrashlytics,
  Future<void> Function()? onLateReady,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final init = initialize().then((_) => true);
  final ready = await bootStep<bool>(
    init,
    reason: 'firebase init',
    fallback: () => false,
    timeout: timeout,
  );
  if (!ready) {
    if (onLateReady != null) {
      unawaited(
        init.then(
          (_) async {
            try {
              await disableCrashlytics();
              await onLateReady();
            } catch (error, stack) {
              ErrorReporter.record(error, stack, reason: 'firebase late ready');
            }
          },
          // Gerçek başarısızlık bootStep tarafından zaten bildirildi.
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    return false;
  }

  await bootStepVoid(
    disableCrashlytics(),
    reason: 'crashlytics disable',
    timeout: timeout,
  );
  return true;
}
