import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';

/// Kupa boyutu istemci ile sunucuda aynı (2026-10-27).
///
/// ## Kusur
///
/// `TournamentConfig.totalPlayers` 16 idi; lobi "16 oyuncu · 4 tur ·
/// 16→8→4→2→1" diyordu. Canlı `tournaments.size` varsayılanı ise 4 (2 tur).
/// Sessizdi: iki sayı ayrı yerlerde yaşıyordu ve turnuva bayrakla kapalı
/// olduğu için ekranı kimse görmüyordu.
///
/// ## Bekçi
///
/// Göçteki `size` varsayılanı istemci sabitine eşit; tur sayısı da
/// oyuncu sayısının ikili logaritması.
void main() {
  test('istemci kupa boyutu sunucu varsayılanına eşit', () {
    final sql = File(
      'supabase/2026-07-26_real_player_tournament.sql',
    ).readAsStringSync();
    final match = RegExp(r'size int not null default (\d+)').firstMatch(sql);
    expect(match, isNotNull, reason: 'tournaments.size varsayılanı bulunamadı');
    expect(TournamentConfig.totalPlayers, int.parse(match!.group(1)!));

    var players = TournamentConfig.totalPlayers;
    var rounds = 0;
    while (players > 1) {
      players ~/= 2;
      rounds++;
    }
    expect(TournamentConfig.roundCount, rounds);
    expect(TournamentConfig.generateBracket(), hasLength(rounds));
  });
}
