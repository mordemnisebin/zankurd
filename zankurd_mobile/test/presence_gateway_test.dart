import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/services/presence_controller.dart';

void main() {
  test('T1 RPC kimliği istemciden almaz ve tercih ayrı yazılır; yalnız '
      'model testleri yanlış ağ sözleşmesini gizliyordu', () async {
    final paths = <String>[];
    final bodies = <Object?>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        paths.add(request.url.path);
        bodies.add(jsonDecode(request.body));
        return request.url.path.endsWith('get_presence_visibility')
            ? http.Response(
                'true',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              )
            : http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabasePresenceGateway(client);
    expect(await gateway.loadVisibility(), isTrue);
    await gateway.setVisibility(false);
    await gateway.touch();
    expect(paths, [
      '/rest/v1/rpc/get_presence_visibility',
      '/rest/v1/rpc/set_presence_visibility',
      '/rest/v1/rpc/touch_presence',
    ]);
    // PostgREST 2.9.1 parametresiz RPC gövdesini JSON null gönderir.
    // Kimlik/istemci zamanı yine gönderilmez; tercih tek açık parametredir.
    expect(bodies, [
      null,
      {'p_visible': false},
      null,
    ]);
  });
  pulseTests();
}

/// Tek RPC'lik yoklama (2026-11-05_olcek_tur3): her 2 dakikada iki RPC yerine
/// `touch_presence_v2`; işlev yoksa eski ikiliye düşer ve bir daha denemez.
/// Eski gövde sessizce çalışırdı; yalnız çağrı sayısı iki katıydı.
void pulseTests() {
  SupabaseClient build(List<String> paths, {required bool v2Exists}) {
    return SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('touch_presence_v2')) {
          return v2Exists
              ? http.Response(
                  'true',
                  200,
                  request: request,
                  headers: {'content-type': 'application/json'},
                )
              : http.Response(
                  jsonEncode({'code': 'PGRST202', 'message': 'not found'}),
                  404,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
        }
        return request.url.path.endsWith('get_presence_visibility')
            ? http.Response(
                'true',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              )
            : http.Response('', 204, request: request);
      }),
    );
  }

  test('pulse: v2 varsa tek RPC', () async {
    final paths = <String>[];
    final client = build(paths, v2Exists: true);
    addTearDown(client.dispose);
    expect(await SupabasePresenceGateway(client).pulse(), isTrue);
    expect(paths, ['/rest/v1/rpc/touch_presence_v2']);
  });

  test(
    'pulse: v2 yoksa eski ikiliye düşer, ikinci turda v2 denenmez',
    () async {
      final paths = <String>[];
      final client = build(paths, v2Exists: false);
      addTearDown(client.dispose);
      final gateway = SupabasePresenceGateway(client);
      expect(await gateway.pulse(), isTrue);
      expect(await gateway.pulse(), isTrue);
      expect(paths, [
        '/rest/v1/rpc/touch_presence_v2',
        '/rest/v1/rpc/get_presence_visibility',
        '/rest/v1/rpc/touch_presence',
        '/rest/v1/rpc/get_presence_visibility',
        '/rest/v1/rpc/touch_presence',
      ]);
    },
  );
}
