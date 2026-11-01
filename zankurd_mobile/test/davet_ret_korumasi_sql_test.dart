/// Davet reddi korumasi (`2026-11-01_davet_ret_korumasi.sql`) bekçisi.
///
/// ## Kusur
///
/// `invite_friends_to_room` mevcut davet satırını `on conflict do update`
/// ile 'pending'e çeviriyordu. Daveti REDDEDEN arkadaş, sahip tekrar
/// davet edince (2 dakikadan eskiyse) aynı bildirimi yeniden alıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Fonksiyon çalışır, sayı döner, hata yoktur; hiçbir derleme/widget testi
/// reddin yeniden açılmasını görmez. Bu dosya göçü metin olarak okuyup
/// korumayı ve değişmeyen parçaları (grant, search_path) sabitler.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/2026-11-01_davet_ret_korumasi.sql',
  ).readAsStringSync();
  final geri = File(
    'supabase/geri_al/2026-11-01_davet_ret_korumasi.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(sql);

  test('tek işlemde: begin … commit', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
  });

  test('yalnız invite_friends_to_room tanımlanır', () {
    expect('create or replace function'.allMatches(code).length, 1);
    expect(code, contains('public.invite_friends_to_room('));
  });

  test('reddedilen davet atlanır: sıfırlama ve bildirim öncesinde', () {
    final guard = code.indexOf("i.status = 'declined'");
    expect(guard, greaterThan(0));
    expect(code.indexOf('continue;', guard), greaterThan(guard));
    expect(guard, lessThan(code.indexOf('insert into public.room_invites')));
    expect(guard, lessThan(code.indexOf('insert into public.push_outbox')));
  });

  test('SECURITY DEFINER, sabit search_path, anon kapalı', () {
    expect(code, contains('security definer'));
    expect(code, contains("set search_path to 'public', 'pg_temp'"));
    expect(code, contains('from public, anon'));
    expect(code, contains('to authenticated'));
  });

  test('geri alma eski gövdeyi yükler, koruma yok', () {
    final g = strip(geri);
    expect(g, contains('public.invite_friends_to_room('));
    expect(g, isNot(contains("i.status = 'declined'")));
    expect(g.trimLeft(), startsWith('begin;'));
    expect(g.trimRight(), endsWith('commit;'));
  });

  test('applied.md satırı ⏳', () {
    expect(
      RegExp(r'2026-11-01_davet_ret_korumasi\.sql \| ⏳').hasMatch(applied),
      isTrue,
    );
  });
}
