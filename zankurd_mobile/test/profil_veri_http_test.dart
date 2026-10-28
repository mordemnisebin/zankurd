// Bekçi: soru önerisi lisans alanı ve tekrar bildirim (2026-10-17).
//
// Kusur 1: `submitSuggestedQuestion` `license_version` göndermiyordu; canlı
// INSERT politikası `license_version = '2026-08-11'` ister, bu yüzden "Soru
// öner" HER ZAMAN reddedilirdi. İstemci hatayı yutup `false` döndüğü ve
// sınama ağı olmadan politika görünmediği için kimse fark etmedi.
//
// Kusur 2: avatar düzenleyici unvanı "<seviye> · <kategori>" yazar; kategori
// "Zanist û Raman"a dönüşüp Cîhan eklenince tetikleyici regex'i bu adları
// reddetti ve TÜM profil kaydı düştü. Kaydet hatası genel mesajla gösterildiği
// ve yalnız o kategoride seviye kazanan oyuncuda çıktığı için sessizdi.
//
// Kusur 6: aynı soruyu ikinci kez bildirmek (reporter_id, question_id) tekil
// kısıtına (23505) çarpıp "bildirim başarısız" gösteriyordu; oysa kayıt zaten
// vardı.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/mastery_level.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client);

  @override
  String? get currentUserId => 'u1';

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-02T00:00:00.000Z',
  );

  @override
  Future<void> ensureProfile() async {}
}

class _Http extends http.BaseClient {
  _Http(this.handler);
  final http.StreamedResponse Function(http.BaseRequest r) handler;
  final paths = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map<String, dynamic>) bodies.add(decoded);
    }
    return handler(request);
  }
}

http.StreamedResponse _json(
  http.BaseRequest r,
  Object? body, {
  int status = 200,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    request: r,
    contentLength: bytes.length,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

_Repo _repo(_Http c) => _Repo(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: c,
  ),
);

void main() {
  test('Soru önerisi katkı lisansı sürümünü gönderir', () async {
    final c = _Http((r) => _json(r, [], status: 201));
    final ok = await _repo(c).submitSuggestedQuestion(
      category: 'Ziman',
      prompt: 'Pirs?',
      optionA: 'a',
      optionB: 'b',
      optionC: 'c',
      optionD: 'd',
      correctOption: 'A',
    );
    expect(ok, isTrue);
    final body = c.bodies.single;
    expect(body['license_version'], '2026-08-11');
    expect(body['status'], 'pending');
    expect(body['user_id'], 'u1');
    // Politika bu ikisinin NULL olmamasını ister (sütun varsayılanı false).
    expect(body['attribution_requested'], false);
    expect(body['do_not_publish'], false);
  });

  test('Aynı soruyu ikinci kez bildirmek başarı sayılır (23505)', () async {
    const q = QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'p',
      answers: ['a', 'b'],
      correctAnswer: 'a',
      explanation: '',
    );
    final c = _Http((r) {
      if (r.url.path.endsWith('/question_reports')) {
        return _json(r, {
          'code': '23505',
          'message': 'duplicate key value violates unique constraint',
          'details': null,
          'hint': null,
        }, status: 409);
      }
      return _json(r, null);
    });
    await _repo(c).reportQuestion(q, 'yanlış');
    expect(c.paths.where((p) => p.contains('/rpc/')), isEmpty);
  });

  test('Başka bildirim hataları yine fırlar', () async {
    const q = QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'p',
      answers: ['a', 'b'],
      correctAnswer: 'a',
      explanation: '',
    );
    final c = _Http(
      (r) => _json(r, {
        'code': '42501',
        'message': 'denied',
        'details': null,
        'hint': null,
      }, status: 403),
    );
    await expectLater(
      _repo(c).reportQuestion(q, 'x'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('Düzenleyicinin üretebildiği her unvan sunucu regex\'ine uyar', () {
    final sql = File('supabase/2026-10-17_profil_veri.sql').readAsStringSync();
    final rule = RegExp(
      r"showcase_title !~ '(\^\(Xwendekar[^']*\$)'",
    ).firstMatch(sql);
    expect(rule, isNotNull, reason: 'unvan regex\'i SQL dosyasında bulunamadı');
    final re = RegExp(rule!.group(1)!);
    final categories = {...MockZanKurdRepository().categories, 'Cîhan'};
    expect(categories, contains('Paradigma'));
    for (final cat in categories) {
      for (final level in MasteryLevel.values) {
        if (level == MasteryLevel.none) continue;
        final title = '${level.titleKu} · ${CategoryNames.showcaseName(cat)}';
        expect(
          re.hasMatch(title),
          isTrue,
          reason: '$title sunucuda reddedilir',
        );
      }
    }
  });
}
