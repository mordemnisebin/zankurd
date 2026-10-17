// Bekçi: oturum kapatınca kalan sahipsiz yerel anahtarlar (2026-10-17).
//
// Kusur: `zankurd.last_spin_date`, `zankurd.avatarIdentity`,
// `zankurd.avatarIdentity.dirtyPending` ve `shop_pending_purchase_effects`
// kullanıcıya göre ayrılmıyordu ve çıkışta silinmiyordu. Aynı cihaza giren
// hesap B, A'nın "bugün çevirdim" kaydını görüp sunucuya sormadan "yarın çevir"
// diyordu; A'nın bekleyen avatar değişikliği B'nin profiline yazılabiliyordu.
// Sessizdi: tek hesaplı sınamada anahtar hep sahibine aitti.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client, this.uid);
  final String uid;

  @override
  String? get currentUserId => uid;
}

class _Http extends http.BaseClient {
  final paths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    final body = request.url.path.endsWith('/rpc/can_spin_today')
        ? 'true'
        : '0';
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      headers: const {
        'content-type': 'application/json; charset=utf-8',
        'content-range': '0-0/0',
      },
    );
  }
}

void main() {
  setUp(() {
    LocalProgressScope.debugReset();
  });
  tearDown(LocalProgressScope.debugReset);

  test('avatar kimliği hesaplar arasında sızmaz', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockZanKurdRepository();
    LocalProgressScope.bind('A');
    await repo.updateAvatarIdentity(const AvatarIdentity(iconId: 'roj'));
    expect((await repo.loadAvatarIdentity()).iconId, 'roj');
    LocalProgressScope.bind('B');
    expect((await repo.loadAvatarIdentity()).iconId, isNull);
    LocalProgressScope.bind('A');
    expect((await repo.loadAvatarIdentity()).iconId, 'roj');
  });

  test(
    '"bugün çevirdim" işareti başka hesaba aitse sunucuya sorulur',
    () async {
      final day = SupabaseZanKurdRepository.spinDayKey(DateTime.now());
      SharedPreferences.setMockInitialValues({
        // Eski sabit anahtar biçimi (yalnız gün) ve başka hesabın işareti.
        'zankurd.last_spin_date': day,
        'zankurd.scope.B.zankurd.last_spin_date': 'A|$day',
      });
      LocalProgressScope.bind('B');
      final http1 = _Http();
      final repo = _Repo(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http1,
        ),
        'B',
      );
      expect(await repo.canSpinToday(), isTrue);
      expect(http1.paths, contains('/rest/v1/rpc/can_spin_today'));
    },
  );

  test('bekleyen avatar ve mağaza etkisi anahtarları kullanıcıya bağlıdır', () {
    for (final entry in {
      'lib/src/data/supabase_zankurd_repository.dart':
          "LocalProgressScope.physical('zankurd.avatarIdentity.dirtyPending')",
      'lib/src/data/mock_zankurd_repository.dart':
          "LocalProgressScope.physical('zankurd.avatarIdentity')",
      'lib/src/screens/shop_screen.dart':
          "LocalProgressScope.physical('shop_pending_purchase_effects')",
      'lib/src/data/supabase_zankurd_repository.dart ':
          "LocalProgressScope.physical('zankurd.last_spin_date')",
    }.entries) {
      expect(
        File(entry.key.trim()).readAsStringSync(),
        contains(entry.value),
        reason: '${entry.key} sabit anahtar kullanıyor',
      );
    }
  });
}
