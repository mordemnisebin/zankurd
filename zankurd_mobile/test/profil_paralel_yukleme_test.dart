// Alan 9 #7 (2026-11-06): profil ekranı sekiz bağımsız sunucu isteğini
// ARDIŞIK bekliyordu; açılış gecikmesi isteklerin toplamıydı. Bekçi: istekler
// birlikte uçar (aynı anda en az 5 açık istek) ve biri hata verse de ekran
// yine çizilir, yakalanmamış istisna doğmaz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

class _SlowRepository extends MockZanKurdRepository {
  int open = 0;
  int maxOpen = 0;

  Future<T> _slow<T>(T Function() read) async {
    open += 1;
    if (open > maxOpen) maxOpen = open;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    open -= 1;
    return read();
  }

  @override
  Future<String> getProfileName() => _slow(() => 'Berfin');

  @override
  Future<String?> getPlayerTag() => _slow(() => null);

  @override
  Future<int> loadCoinBalance() => _slow(() => throw StateError('bakiye yok'));
}

void main() {
  tearDown(() async => SyncManager.resetForTesting());

  testWidgets('profil istekleri birlikte uçar ve hata ekranı bozmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _SlowRepository();
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      repository.maxOpen,
      greaterThanOrEqualTo(3),
      reason: 'ad, etiket ve jeton istekleri ardışık değil birlikte başlamalı',
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  });
}
