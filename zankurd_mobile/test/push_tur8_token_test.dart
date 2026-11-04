/// FCM jeton kaydı — geçici hatada yeniden deneme + cihaz jetonu bekçisi.
///
/// ## Kusurlar (GPT-6 Pro ALAN 4)
///
/// 1. `setFcmToken` RPC hatasını yutuyor, AppShell kullanıcı/depo çiftini
///    denemeden önce "kaydedildi" sayıyordu: geçici sunucu hatasında zamanlı
///    tekrar yoktu; kayıt ancak sonraki resume/reconnect'e kalıyor, cihaz o
///    sırada arka plana giderse bildirim adresi eksik kalıyordu.
/// 2. Çıkışta yalnız kullanıcı kimliğiyle temizlik: aynı hesabın ikinci
///    cihazının jetonu da siliniyordu (bkz. push_tur8_sql_test.dart).
///
/// ## Niçin sessiz kalırdı
///
/// Hata yutulduğu için ne kullanıcı ne test bir şey görür; yalnız push'un
/// ulaşmadığı gün fark edilir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';

class _Source implements PushTokenSource {
  @override
  Future<String?> currentToken() async => ' tok-1 ';
}

class _Flaky extends MockZanKurdRepository {
  _Flaky(this.failures);
  int failures;
  int attempts = 0;
  final written = <String>[];
  @override
  Future<void> setFcmToken(String token) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw StateError('geçici sunucu hatası');
    }
    written.add(token);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(PushTokenSync.resetForTest);
  tearDown(PushTokenSync.resetForTest);

  PushTokenSync sync(_Flaky repo) => PushTokenSync(
    source: _Source(),
    repository: repo,
    remoteEnabled: () => true,
    retryDelays: const [
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
    ],
  );

  test('geçici hatadan sonra kayıt kendiliğinden yeniden denenir', () async {
    final repo = _Flaky(2);
    await sync(repo).sync();
    expect(repo.written, isEmpty);
    for (var i = 0; i < 100 && repo.written.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(repo.attempts, 3);
    expect(repo.written, ['tok-1']);
    expect(PushTokenSync.lastRegisteredToken, 'tok-1');
  });

  test('deneme sayısı sınırlıdır (sonsuz döngü yok)', () async {
    final repo = _Flaky(100);
    await sync(repo).sync();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.attempts, 4, reason: 'ilk deneme + 3 yeniden deneme');
    expect(PushTokenSync.lastRegisteredToken, isNull);
  });

  test('çıkış bariyeri bekleyen yeniden denemeyi iptal eder', () async {
    final repo = _Flaky(100);
    await sync(repo).sync();
    await PushTokenSync.suspendRegistrationsDuring(() async {});
    final seen = repo.attempts;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(repo.attempts, seen, reason: 'çıkmış hesap yeniden bağlanmamalı');
  });
}
