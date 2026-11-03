// Yük bekçisi (2026-11-03): istemci yedek yoklamaları realtime'ın yedeği
// olmalı, asıl yolu DEĞİL.
//
// Kusur: lobi 3 sn'de iki sorgu, kalabalık quiz 1 sn'de ilerleme + 4–6 sn'de
// oda sırası, sıralama 30 sn'de bir sorgu, sohbet akışı bütün geçmişi
// taşıyordu. 10.000 eşzamanlı kullanıcıda bu on binlerce istek/sn eder.
// Sessizdi: hiçbir test, hata ya da ekran bozulmaz; yalnız sunucu yavaşlar.
// Bu dosya (1) aralıkların dakika başına istek bütçesini sahte saatle,
// (2) ekranların bu sabitleri GERÇEKTEN kullandığını ve sohbet penceresinin
// sınırlı olduğunu kaynaktan doğrular.
import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/poll_cadence.dart';

int _ticksIn(Duration interval, Duration window) {
  var n = 0;
  fakeAsync((async) {
    final t = Timer.periodic(interval, (_) => n++);
    async.elapse(window);
    t.cancel();
  });
  return n;
}

void main() {
  const minute = Duration(minutes: 1);

  test(
    'lobi: oyuncu+durum yedek yoklaması dakikada <=8 istek, heartbeat 45 sn kuralına sığar',
    () {
      // iki sorgu (oyuncular + durum) + heartbeat
      final perPoll = _ticksIn(PollCadence.lobbyFallback, minute);
      expect(perPoll * 3, lessThanOrEqualTo(12)); // eskiden 3 sn: 60
      expect(PollCadence.lobbyFallback.inSeconds, lessThan(45 ~/ 2));
      expect(PollCadence.lobbyCrowdFallback.inSeconds, lessThan(45 ~/ 2));
    },
  );

  test('kalabalık quiz: ilerleme+oda sırası dakikada <=10 istek', () {
    final n =
        _ticksIn(PollCadence.crowdProgressFallback, minute) +
        _ticksIn(PollCadence.crowdRoomIndexFallback, minute);
    expect(n, lessThanOrEqualTo(10)); // eskiden 60 + 10
  });

  test('sıralama: dakikada <=1 istek', () {
    expect(
      _ticksIn(PollCadence.leaderboardRefresh, minute),
      lessThanOrEqualTo(1),
    );
    expect(PollCadence.perMinute(PollCadence.leaderboardRefresh), 0.5);
  });

  test('ekranlar sabitleri kullanır, sert kodlu sık aralık yok', () {
    String src(String p) => File('lib/src/screens/$p').readAsStringSync();
    expect(
      src('leaderboard_screen.dart'),
      contains('PollCadence.leaderboardRefresh'),
    );
    expect(src('room_screen.dart'), contains('PollCadence.lobbyFallback'));
    final quiz = src('quiz_screen.dart');
    expect(quiz, contains('PollCadence.crowdProgressFallback'));
    expect(
      quiz,
      isNot(
        contains(
          'Timer.periodic(const Duration(seconds: 1), (_) {\n        if (!_terminalHandling',
        ),
      ),
    );
    // Realtime hatasında hemen yoklama turu.
    expect(src('room_screen.dart'), contains('_onRealtimeDropped'));
  });

  test('sohbet akışı yalnız son N mesajı taşır', () {
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final i = repo.indexOf('subscribeRoomMessages(String roomId)');
    final body = repo.substring(i, i + 1500);
    expect(body, contains('.limit(PollCadence.chatWindow)'));
    expect(body, contains('ascending: false'));
    expect(body, contains('rows.reversed'));
    expect(PollCadence.chatWindow, lessThanOrEqualTo(50));
  });
}
