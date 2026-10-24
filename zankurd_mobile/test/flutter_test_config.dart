import 'dart:async';

import 'package:zankurd_mobile/src/theme/sahne.dart';

/// Manzara şeridi cihaz saatini izler; testler belirleyici kalsın diye
/// varsayılan saat öğlen 12:00 (gündüz). Saate özel testler kendi saatini
/// kurar ve `SahneClock.now`'ı geri verir.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SahneClock.now = () => DateTime(2026, 10, 21, 12);
  await testMain();
}
