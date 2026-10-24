// Oda turu ödülünün cevabı "tam iki alan" (amount, already_claimed)
// bekleniyordu. 2026-10-02'deki oda günlük tavanı göçü cevaba `daily_cap` ve
// `cap_reached` ekleyince her oda turunun ilk talebi "doğrulanamadı" diye
// reddedildi: jeton sunucuda ödendi, istemci "bağlantı yok" deyip talebi
// kuyruğa aldı, sonuç onayı hiç gönderilmedi ve biten oda her soğuk
// açılışta geri geldi. Sahte istemciler iki alanlı cevap döndürdüğünden
// testler kırılmadı; kalabalık oda simülatör denemesi yakaladı (2026-10-16).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

class _Http extends http.BaseClient {
  _Http(this.body);

  final Map<String, Object?> body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.url.path, '/rest/v1/rpc/claim_quiz_reward');
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client);

  @override
  String? get currentUserId => 'host';

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'host',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-16T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

const _room = GameRoom(
  id: '00000000-0000-0000-0000-000000000042',
  name: 'oda',
  code: 'ZK-ABCDEF0123',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
);

Future<QuizRewardClaimTestResult> _claim(Map<String, Object?> body) async {
  final repository = _Repo(
    SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: _Http(body),
    ),
  );
  final claim = await repository.awardQuizCoins(
    score: 300,
    correctCount: 3,
    bestStreak: 2,
    totalQuestions: 5,
    room: _room,
  );
  return (amount: claim.amount, cap: claim.dailyCapReached);
}

typedef QuizRewardClaimTestResult = ({int amount, bool cap});

void main() {
  test(
    'ilk talep: fazla alanlı (daily_cap, cap_reached) cevap kabul edilir',
    () async {
      final result = await _claim({
        'amount': 24,
        'already_claimed': false,
        'daily_cap': 300,
        'cap_reached': false,
      });
      expect(result.amount, 24);
      expect(result.cap, isFalse);
    },
  );

  test('tavana varıldıysa istemci bunu bilir', () async {
    final result = await _claim({
      'amount': 0,
      'already_claimed': false,
      'daily_cap': 300,
      'cap_reached': true,
    });
    expect(result.cap, isTrue);
  });

  test('zorunlu alan eksikse hâlâ reddedilir', () async {
    await expectLater(_claim({'amount': 24}), throwsStateError);
    await expectLater(
      _claim({'already_claimed': false, 'daily_cap': 300}),
      throwsStateError,
    );
  });

  test('oda tamamlanmadan kapandıysa (rakip ayrıldı) arıza sayılmaz', () async {
    final result = await _claim({
      'amount': 0,
      'room_not_completed': true,
      'ended_reason': 'forfeit',
    });
    expect(result.amount, 0);
    expect(result.cap, isFalse);
  });

  test(
    'rakip ortada çıkınca kapanan odanın yarım ilerlemesi arıza sayılmaz',
    () async {
      // crowd_room_member_leave: kalan tek oyuncu → `completed`, indeks
      // ilerlemez → claim_quiz_reward `room_progress_incomplete` döner.
      final result = await _claim({
        'amount': 0,
        'room_progress_incomplete': true,
      });
      expect(result.amount, 0);
      expect(result.cap, isFalse);
    },
  );

  test(
    'geçici durumlar ve bayraksız sıfır hâlâ reddedilir (kuyruğa girer)',
    () async {
      await expectLater(
        _claim({'amount': 0, 'room_not_finished': true}),
        throwsStateError,
      );
      await expectLater(
        _claim({'amount': 0, 'answers_incomplete': true}),
        throwsStateError,
      );
      await expectLater(_claim({'amount': 0}), throwsStateError);
    },
  );
}
