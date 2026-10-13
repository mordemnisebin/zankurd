/// `get_my_leaderboard_rank` RPC'sinin sözleşme testi.
///
/// ## Niçin
///
/// Sabitlenen "benim sıram" satırı, listedeki satırlarla AYNI süzgeçten
/// gelmeli (biten çevrimiçi odalar, dönem `p_days`, `sum(score) > 0`) —
/// yoksa aynı ekranda iki ayrı sayı aynı etiketle görünür. Bu test üç
/// şeyi bağlar:
///
/// 1. İstemcinin çağırdığı RPC adı ve tek parametresi (`p_days` = seçili
///    dönemin gün sayısı).
/// 2. Cevap yokken / RPC yokken / oturum yokken satırın ÇİZİLMEESİ ve
///    eski `leaderboard_entries` (toplam XP) yoluna DÜŞÜLMEMESİ.
/// 3. Göç dosyasının `get_leaderboard` ile aynı süzgeç ve sıralama
///    anahtarlarını taşıması, anon/public yetkisinin kapalı olması.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';

/// Canlı RPC'nin tek satırlık cevabı (RETURNS TABLE → JSON dizisi).
Map<String, Object?> _row({
  int rank = 12,
  int totalScore = 210,
  int bestStreak = 2,
  int roomsPlayed = 3,
}) => {
  'rank': rank,
  'player_id': '00000000-0000-0000-0000-000000000042',
  'display_name': 'Rojhat',
  'total_score': totalScore,
  'best_streak': bestStreak,
  'rooms_played': roomsPlayed,
  'avatar_icon': 'book-open',
  'avatar_color': '#2E9E93',
  'avatar_url': 'https://example.supabase.co/avatars/me.png',
  'avatar_frame': 'frame_gold',
  'showcase_title': null,
};

http.StreamedResponse _json(
  http.BaseRequest request,
  Object? body, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    statusCode,
    request: request,
    contentLength: bytes.length,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

class _MyRankHttpClient extends http.BaseClient {
  _MyRankHttpClient({this.rows = const [], this.missingFunction = false});

  /// RPC'nin döndüreceği satırlar.
  final List<Object?> rows;

  /// true → PostgREST'in fonksiyonu bulamadığındaki cevabı (404/PGRST202).
  final bool missingFunction;

  final requestedPaths = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) {
        requestBodies.add(Map<String, dynamic>.from(decoded));
      }
    }
    if (missingFunction) {
      return _json(request, {
        'code': 'PGRST202',
        'message': 'function public.get_my_leaderboard_rank does not exist',
        'details': null,
        'hint': null,
      }, statusCode: 404);
    }
    return _json(request, rows);
  }
}

/// Oturum sahibi varmış gibi davranan depo (`currentUserId` override'ı
/// `supabase_offline_fallback_test.dart`teki desenle aynı).
class _SignedInRepository extends SupabaseZanKurdRepository {
  _SignedInRepository(super.client);

  @override
  String? get currentUserId => '00000000-0000-0000-0000-000000000042';
}

_SignedInRepository _repo(_MyRankHttpClient client) => _SignedInRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: client,
  ),
);

void main() {
  test('RPC adı get_my_leaderboard_rank, p_days seçili dönemin günü', () async {
    const expectedDays = {
      LeaderboardPeriod.daily: 1,
      LeaderboardPeriod.weekly: 7,
      LeaderboardPeriod.monthly: 30,
    };

    for (final entry in expectedDays.entries) {
      final client = _MyRankHttpClient(rows: [_row()]);
      final repository = _repo(client);

      final rank = await repository.getMyLeaderboardRank(entry.key);

      expect(client.requestedPaths, [
        '/rest/v1/rpc/get_my_leaderboard_rank',
      ], reason: '${entry.key} için tek çağrı bu RPC olmalı');
      expect(client.requestBodies.single, {'p_days': entry.value});

      expect(rank, isNotNull);
      expect(rank!.rank, 12);
      expect(rank.playerId, '00000000-0000-0000-0000-000000000042');
      expect(rank.displayName, 'Rojhat');
      expect(rank.totalScore, 210);
      expect(rank.bestStreak, 2);
      expect(rank.roomsPlayed, 3);
      expect(rank.avatarIcon, 'book-open');
      expect(rank.avatarColor, '#2E9E93');
      expect(rank.avatarFrame, 'frame_gold');
      expect(rank.showcaseTitle, isNull);
    }
  });

  test('dönemde puan yoksa (boş cevap) satır null olur', () async {
    final client = _MyRankHttpClient(rows: const []);
    final repository = _repo(client);

    expect(
      await repository.getMyLeaderboardRank(LeaderboardPeriod.weekly),
      isNull,
    );
    expect(client.requestedPaths, ['/rest/v1/rpc/get_my_leaderboard_rank']);
  });

  test('0 puanlı cevap satırı çizilmez', () async {
    final client = _MyRankHttpClient(rows: [_row(totalScore: 0, rank: 9)]);
    final repository = _repo(client);

    expect(
      await repository.getMyLeaderboardRank(LeaderboardPeriod.daily),
      isNull,
    );
  });

  test('RPC yoksa eski leaderboard_entries yoluna düşülmez', () async {
    final client = _MyRankHttpClient(missingFunction: true);
    final repository = _repo(client);

    expect(
      await repository.getMyLeaderboardRank(LeaderboardPeriod.monthly),
      isNull,
    );
    expect(client.requestedPaths, ['/rest/v1/rpc/get_my_leaderboard_rank']);
    expect(
      client.requestedPaths.any((path) => path.contains('leaderboard_entries')),
      isFalse,
      reason: 'Eski (toplam XP) kaynağına fallback yasak: 2026-09-30',
    );
    expect(
      client.requestedPaths.any((path) => path.contains('get_leaderboard')),
      isFalse,
      reason: 'Sabit satır liste RPC\'sini de çağırmaz; kendi RPC\'si var',
    );
  });

  test('oturum yoksa istek bile atılmaz', () async {
    final client = _MyRankHttpClient(rows: [_row()]);
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: client,
      ),
    );

    expect(
      await repository.getMyLeaderboardRank(LeaderboardPeriod.weekly),
      isNull,
    );
    expect(client.requestedPaths, isEmpty);
  });

  test('göç dosyası get_leaderboard ile aynı süzgeci ve yetkiyi taşıyor', () {
    final source = File(
      'supabase/2026-09-30_my_leaderboard_rank.sql',
    ).readAsStringSync();
    final board = File(
      'supabase/2026-09-30_leaderboard_positive_scores.sql',
    ).readAsStringSync();

    // Fonksiyon biçimi: tekrar çalıştırılabilir, stable, security definer.
    expect(
      source,
      contains('create or replace function public.get_my_leaderboard_rank'),
    );
    expect(source, contains('p_days integer default -1'));
    expect(source, contains('begin;'));
    expect(source, contains('commit;'));
    expect(source, contains('language sql'));
    expect(source, contains('stable security definer'));
    expect(source, contains('set search_path = public'));

    // Yetki: anon/public kapalı, authenticated açık.
    expect(
      source,
      contains(
        'revoke all on function public.get_my_leaderboard_rank(integer)',
      ),
    );
    expect(source, contains('from public, anon'));
    expect(
      source,
      contains(
        'grant execute on function public.get_my_leaderboard_rank(integer)',
      ),
    );
    expect(source, contains('to authenticated'));

    // Süzgeç `get_leaderboard` ile birebir aynı.
    for (final fragment in [
      "where r.status = 'finished'",
      'and (p_days <= 0',
      'having coalesce(sum(rp.score), 0) > 0',
    ]) {
      expect(source, contains(fragment), reason: fragment);
      expect(board, contains(fragment), reason: 'get_leaderboard: $fragment');
    }

    // Sıralama anahtarları aynı sırayla: puan desc, en iyi seri desc,
    // oda sayısı desc (yazımlar farklı — biri CTE kolonu, diğeri aggregate).
    for (final fragment in [
      'total_score desc',
      'best_streak desc',
      'rooms_played desc',
    ]) {
      expect(source, contains(fragment), reason: fragment);
    }
    for (final fragment in [
      'coalesce(sum(rp.score), 0) desc',
      'coalesce(max(rp.streak), 0) desc',
      'count(distinct rp.room_id) desc',
    ]) {
      expect(board, contains(fragment), reason: 'get_leaderboard: $fragment');
    }

    // Sonuç yalnız oyuncunun kendisi.
    expect(source, contains('where o.player_id = auth.uid()'));
  });
}
