/// Başlamamış turnuvadan AYRILMA bekçisi.
///
/// ## Kusur
///
/// `join_tournament` oyuncuyu açık kupaya yazıyordu ama çıkış yolu yoktu:
/// kontenjan dolmayan kupada oyuncu 24 saate dek kayıtlı kalıyor, vazgeçmek
/// için hesabı silmekten başka çare bulamıyordu.
///
/// ## Niçin sessizdi
///
/// Eksik bir eylem hiçbir testi kırmaz; ekran "çalışıyor" görünür. Bu dosya
/// (1) bekleme ekranında eylemin bulunduğunu, (2) onay istediğini,
/// (3) sunucu göçü canlıda değilken (unavailable) eylemin GİZLENDİĞİNİ,
/// (4) göçün yetki/kilit/idempotens kurallarını metin olarak sabitler.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  _Repo(this.result);
  TournamentLeaveResult result;
  int leaveCalls = 0;
  bool left = false;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> joinRealTournament() async => _waiting();

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async =>
      left ? null : _waiting();

  @override
  Future<TournamentLeaveResult> leaveRealTournament() async {
    leaveCalls++;
    if (result == TournamentLeaveResult.left) left = true;
    return result;
  }

  TournamentBracket _waiting() => TournamentBracket(
    tournamentId: 't1',
    userId: 'me',
    rounds: const [],
    createdAt: DateTime(2026, 11, 1),
    entryCount: 1,
    size: 4,
  );
}

/// Bekleme ekranı 375×667'de zaten kaydırılır (soru ekranı değil); eylem
/// kaydırılarak erişilir.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, _Repo repo) async {
  await tester.binding.setSurfaceSize(const Size(375, 667));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testShell(child: TournamentScreen(repository: repo)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true}),
  );

  testWidgets('bekleme ekranında ayrıl: onay sonrası RPC çağrılır', (
    tester,
  ) async {
    final repo = _Repo(TournamentLeaveResult.left);
    await _open(tester, repo);
    expect(find.byKey(const ValueKey('tournament-leave')), findsOneWidget);

    await _tapKey(tester, 'tournament-leave');
    // Onaysız çağrı yok.
    expect(repo.leaveCalls, 0);
    await _tapKey(tester, 'tournament-leave-cancel');
    expect(repo.leaveCalls, 0);

    await _tapKey(tester, 'tournament-leave');
    await _tapKey(tester, 'tournament-leave-confirm');
    expect(repo.leaveCalls, 1);
    // Ayrılınca bekleme ekranı kalmaz.
    expect(find.byKey(const ValueKey('tournament-waiting')), findsNothing);
  });

  testWidgets('göç canlıda değilse (unavailable) eylem gizlenir', (
    tester,
  ) async {
    final repo = _Repo(TournamentLeaveResult.unavailable);
    await _open(tester, repo);
    await _tapKey(tester, 'tournament-leave');
    await _tapKey(tester, 'tournament-leave-confirm');
    expect(repo.leaveCalls, 1);
    expect(find.byKey(const ValueKey('tournament-leave')), findsNothing);
    expect(find.byKey(const ValueKey('tournament-waiting')), findsOneWidget);
  });

  group('göç metni', () {
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n')
        .toLowerCase();
    final sql = code('supabase/2026-11-01_turnuva_ayril.sql');

    test('tek işlem, definer, sabit search_path, yalnız auth.uid()', () {
      expect(sql.trimLeft(), startsWith('begin;'));
      expect(sql.trimRight(), endsWith('commit;'));
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = public'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('function public.leave_tournament()'));
    });

    test('yalnız open kupada, kilit altında; başlamışsa silmez', () {
      expect(sql, contains('for update'));
      expect(sql, contains("is distinct from 'open'"));
      expect(sql, contains("'reason', 'started'"));
      expect(sql, contains('delete from public.tournament_entries'));
    });

    test('idempotent ve anon çalıştıramaz', () {
      expect(sql, contains("'already', true"));
      expect(sql, contains('revoke all on function public.leave_tournament()'));
      expect(sql, contains('from public, anon'));
      expect(sql, contains('to authenticated'));
    });

    test('geri alma ve applied.md satırı var', () {
      expect(
        code('supabase/geri_al/2026-11-01_turnuva_ayril_geri.sql'),
        contains('drop function if exists public.leave_tournament()'),
      );
      expect(
        File('supabase/applied.md').readAsStringSync(),
        contains('| 2026-11-01_turnuva_ayril.sql | ✅ |'),
      );
    });
  });
}
