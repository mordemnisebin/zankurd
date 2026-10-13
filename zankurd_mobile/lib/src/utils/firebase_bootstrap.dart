import 'boot_step.dart';

Future<bool> initializeFirebaseForBoot({
  required Future<void> Function() initialize,
  required Future<void> Function() disableCrashlytics,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final ready = await bootStep<bool>(
    initialize().then((_) => true),
    reason: 'firebase init',
    fallback: () => false,
    timeout: timeout,
  );
  if (!ready) return false;

  await bootStepVoid(
    disableCrashlytics(),
    reason: 'crashlytics disable',
    timeout: timeout,
  );
  return true;
}
