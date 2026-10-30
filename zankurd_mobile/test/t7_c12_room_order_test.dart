import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/public_profile.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

void main() {
  Map<String, dynamic> row(String id, int second) => {
    'player_id': id,
    'joined_at': DateTime.utc(2026, 10, 30, 12, 0, second).toIso8601String(),
    'score': 0,
    'is_ready': false,
  };

  final server = {
    'ali': row('ali', 0),
    'bero': row('bero', 1),
    'cano': row('cano', 1), // Eşit zamanda player_id belirleyici.
    'dlan': row('dlan', 3),
  };

  List<Player> players(List<Map<String, dynamic>> rows) => [
    for (final r in rows)
      Player(
        id: r['player_id'] as String,
        joinedAt: DateTime.parse(r['joined_at'] as String),
        name: r['player_id'] as String,
        score: r['score'] as int? ?? 0,
        state: r['is_ready'] == true ? Player.readyState : '',
      ),
  ];

  test(
    'C12 iki istemci: farklı INSERT/UPDATE varışları aynı sırayı üretir',
    () async {
      Future<List<Player>> simulate(List<String> arrivals) async {
        final snapshot = <String, Map<String, dynamic>>{};
        final fetched = <String>[];
        List<Map<String, dynamic>> ordered = [];
        for (final id in arrivals) {
          // Supabase stream INSERT'i snapshot sonuna ekleyebilir. UPDATE
          // ise aynı anahtarı değiştirir; joined_at olayda eksik olabilir.
          snapshot[id] = {'player_id': id, 'is_ready': true, 'score': 1202};
          ordered = await resolveRoomPlayerRows(
            snapshot.values.toList(),
            fetchRow: (id) async {
              fetched.add(id);
              return server[id];
            },
          );
          final expected = server.keys.where(snapshot.containsKey).toList();
          expect(ordered.map((r) => r['player_id']), expected);
          // Ekrana ters geliş bile lobi sırasını değiştiremez.
          expect(
            orderRoomPlayersForDisplay(
              players(ordered.reversed.toList()),
              lobby: true,
            ).map((p) => p.id),
            expected,
          );
        }
        expect(fetched, containsAll(server.keys));
        return players(ordered);
      }

      final a = await simulate(['ali', 'dlan', 'cano', 'bero', 'dlan', 'ali']);
      final b = await simulate(['cano', 'bero', 'ali', 'dlan', 'bero', 'cano']);
      expect(a.map((p) => p.id), ['ali', 'bero', 'cano', 'dlan']);
      expect(b.map((p) => p.id), a.map((p) => p.id));
    },
  );

  test(
    'C12 tam anahtarlı INSERT/UPDATE yeniden sıralanır, ek okuma yok',
    () async {
      final raw = [
        server['dlan']!,
        server['cano']!,
        server['ali']!,
        server['bero']!,
      ];
      final ordered = await resolveRoomPlayerRows(
        raw,
        fetchRow: (_) async => fail('Tam katılma anahtarı yeniden okunmamalı'),
      );
      expect(ordered.map((r) => r['player_id']), [
        'ali',
        'bero',
        'cano',
        'dlan',
      ]);
      expect(
        raw.first['player_id'],
        'dlan',
        reason: 'SDK snapshotı değiştirilmez',
      );
      final update = {...server['dlan']!, 'score': 99999, 'is_ready': true};
      final updated = await resolveRoomPlayerRows([
        update,
        ...ordered.where((r) => r['player_id'] != 'dlan'),
      ], fetchRow: (_) async => fail('UPDATE zamanı zaten mevcut'));
      expect(updated.last['score'], 99999);
      expect(
        orderRoomPlayersForDisplay(players(updated), lobby: true).last.id,
        'dlan',
      );
    },
  );

  test('C12 eksik anahtar okunamazsa sahte sıra yayımlanmaz', () async {
    final raw = [
      {'player_id': 'dlan'},
    ];
    await expectLater(
      resolveRoomPlayerRows(
        raw,
        fetchRow: (_) async => throw StateError('offline'),
      ),
      throwsStateError,
    );
    await expectLater(
      resolveRoomPlayerRows(raw, fetchRow: (_) async => {'player_id': 'dlan'}),
      throwsStateError,
    );
    expect(
      await resolveRoomPlayerRows(raw, fetchRow: (_) async => null),
      isEmpty,
    );
  });

  test('C12 joinedAt model kopyalarında kaybolmaz', () {
    final original = players([server['ali']!]).single;
    expect(original.copyWith(score: 42).joinedAt, original.joinedAt);
    expect(original.mergeIdentity(original).joinedAt, original.joinedAt);
    expect(
      original
          .withProfile(const PublicProfile(id: 'ali', displayName: 'Ali'))
          .joinedAt,
      original.joinedAt,
    );
  });

  test('C12 yükleme ve canlı akış sunucu anahtarını modele taşır', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final load = source.substring(
      source.indexOf('Future<List<Player>> _loadRoomPlayersById'),
    );
    expect(load, contains('player_id, joined_at, score'));
    expect(
      load,
      contains("joinedAt: DateTime.parse(row['joined_at'] as String)"),
    );
    final live = source.substring(
      source.indexOf('Stream<List<Player>> subscribeRoomPlayers'),
      source.indexOf('Stream<RoomStatus> subscribeRoomStatus'),
    );
    final screen = File('lib/src/screens/room_screen.dart').readAsStringSync();
    expect(
      screen,
      isNot(contains('sorted.insert(')),
      reason: 'Ev sahibi ya da kendi oyuncum sonradan başa taşınamaz',
    );
    expect(live, contains('await resolveRoomPlayerRows('));
    expect(live, contains(".eq('room_id', roomId)"));
    expect(live, contains(".eq('player_id', playerId)"));
    expect(
      live,
      contains("joinedAt: DateTime.parse(row['joined_at'] as String)"),
    );
  });
}
