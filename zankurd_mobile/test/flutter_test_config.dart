import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/age_gate_store.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

/// Manzara şeridi cihaz saatini izler; testler belirleyici kalsın diye
/// varsayılan saat öğlen 12:00 (gündüz). Saate özel testler kendi saatini
/// kurar ve `SahneClock.now`'ı geri verir.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SahneClock.now = () => DateTime(2026, 10, 21, 12);
  // 2026-11-04: yaş beyanı cevapsızken sosyal yüzey KAPALI (bkz. `AgeGate`).
  // Sohbet/arkadaş testleri o kapıyı sınamaz; her test "13 üstü" beyanıyla
  // başlar. Kapıyı sınayan testler (`riza_yas_beyani_test`) kendi `setUp`ında
  // `debugSet(null)` yapar.
  setUp(() => AgeGate.debugSet(AgeDeclaration.adult));
  // Sonuç ekranının kendiliğinden yeniden denemesi (3 deneme, ~9 sn) mevcut
  // "Tekrar dene" testlerini yavaşlatıp bozar; varsayılan kapalı. Onu sınayan
  // test (`room_result_auto_retry_test`) kendi gecikmelerini kurar.
  setUp(() => roomResultAutoRetryDelays = const []);
  await testMain();
}
