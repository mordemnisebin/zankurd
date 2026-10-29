import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_award_publisher.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';

/// Geciken oda XP yanıtı başka hesabın ilerlemesine yazılmaz.
///
/// ## Kusur (Codex denetimi 2026-10-29, hata #1)
///
/// `XpAwardPublisher.publish` sunucu toplamını beklerken hesap değişirse,
/// dönen A toplamı `XPStore.load()` ile o an etkin olan B deposuna (ve
/// `LocalProgressScope.physical` getter'ı yazım anında çözüldüğünden B'nin
/// anahtarına) yazılıyordu. Hata sessizdi: B'nin XP'si bir başkasının
/// toplamına dönüşüyordu. Bekçi: sahip istek başında yakalanır, yanıt
/// geldiğinde değiştiyse yazım atlanır.
class _SlowRepo extends MockZanKurdRepository {
  final gate = Completer<int>();
  @override
  bool get xpAwardIsServerTotal => true;
  @override
  Future<int> awardRoomXp(String roomId) => gate.future;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    XPStore.resetInstance();
  });

  test(
    'yanıt gelmeden hesap değişirse B deposu A toplamıyla ezilmez',
    () async {
      LocalProgressScope.bind('user-a');
      final repo = _SlowRepo();
      final pending = XpAwardPublisher.publish(
        repository: repo,
        delta: 0,
        roomId: 'room-1',
      );
      LocalProgressScope.bind('user-b');
      XPStore.resetInstance();
      final storeB = await XPStore.loadForTest(7);
      repo.gate.complete(9999);
      await pending;
      expect(storeB.totalXP, 7);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('zankurd.scope.user-b.zankurd.xp.total'),
        isNot(9999),
      );
    },
  );

  test('hesap değişmediyse sunucu toplamı yazılır', () async {
    LocalProgressScope.bind('user-a');
    final store = await XPStore.loadForTest(7);
    final repo = _SlowRepo();
    final pending = XpAwardPublisher.publish(
      repository: repo,
      delta: 0,
      roomId: 'room-1',
    );
    repo.gate.complete(120);
    await pending;
    expect(store.totalXP, 120);
  });
}
