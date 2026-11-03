/// Meydan okuma bağlantısı ömrü (`supabase/2026-11-04_meydan_okuma_suresi.sql`)
/// — sunucu sözleşmesi + süre etiketi bekçisi.
///
/// ## Kusur
///
/// Bağlantıyla paylaşılan meydan okuma (`create_async_duel_challenge`) yeni
/// satırı `expires_at` varsayılanıyla (now()+24 saat) açıyordu. Arkadaş
/// bağlantıyı bir gün sonra açınca "süresi doldu" görüyor, davet sessizce
/// ölüyordu. Sıra süresi kısa kalmalı (kabulden sonra 24 saat), DAVETİN ömrü
/// uzun olmalı (7 gün).
///
/// ## Niçin sessiz kalırdı
///
/// Süre bir sütun varsayılanında yaşıyordu; hiçbir RPC gövdesinde
/// görünmüyordu, bu yüzden "davet 24 saat" yazan hiçbir yer yoktu ve hiçbir
/// test ya da analiz bunu yakalamaz. Düzeltmenin kendisi de sessiz
/// bozulabilir: göç `room_duel_guards` sarmalayıcısından SONRA koşarsa
/// içerik gizlemeyi ezer; kabul de 7 günü rakibe taşırsa sıra süresi uzar.
///
/// ## Kural
///
/// * Göç yalnız `create_async_duel_challenge`ı değiştirir; INSERT açıkça
///   `now() + interval '7 days'` yazar; kabul/rastgele eşleşme 24 saat kalır.
/// * Gövde canlı (✅) `duello_inceleme_rovans` gövdesiyle, tek INSERT farkıyla
///   aynıdır.
/// * Basit biçim: küçük harf `begin;`/`commit;`, SECURITY DEFINER, sabit
///   search_path, anon çalıştıramaz; geri alma dosyası var; applied.md ✅ (canlıda).
/// * 48 saatten uzun süre etiketi gün olarak yazılır ("168 sa" değil).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_time.dart';

void main() {
  final sql = File(
    'supabase/2026-11-04_meydan_okuma_suresi.sql',
  ).readAsStringSync();
  final live = File(
    'supabase/2026-10-24_duello_inceleme_rovans.sql',
  ).readAsStringSync();

  String body(String text) {
    final a = text.indexOf(
      'create or replace function public.create_async_duel_challenge(',
    );
    final b = text.indexOf('\$function\$\n;', a);
    return text.substring(a, b);
  }

  test('INSERT 7 gün yazar; canlı gövdeden tek bu farkla ayrılır', () {
    final mine = body(sql);
    expect(mine, contains("now() + interval '7 days'"));
    final stripped = mine
        .replaceAll(
          ",\n        expires_at   -- 2026-11-04: tek fark; davet 7 gün açık kalır",
          '',
        )
        .replaceAll(",\n        now() + interval '7 days'", '');
    expect(stripped, body(live));
  });

  test('kabul ve rastgele eşleşme bu göçte yok (24 saat kalır)', () {
    final defs = RegExp(
      r'create or replace function public\.(\w+)',
      caseSensitive: false,
    ).allMatches(sql).map((m) => m.group(1)).toList();
    expect(defs, ['create_async_duel_challenge']);
  });

  test('biçim kuralları', () {
    expect(RegExp(r'^begin;$', multiLine: true).hasMatch(sql), isTrue);
    expect(RegExp(r'^commit;$', multiLine: true).hasMatch(sql), isTrue);
    expect(sql.toLowerCase(), contains('security definer'));
    expect(
      sql.toLowerCase(),
      contains("set search_path to 'public', 'pg_temp'"),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.create_async_duel_challenge(text, uuid)\n  from public, anon;',
      ),
    );
    expect(sql, contains('to authenticated;'));
  });

  test('room_duel_guards sarmalayıcısı varsa göç durur', () {
    expect(sql, contains('_guard_20261101_create_async_duel_challenge'));
    expect(sql, contains('raise exception'));
  });

  test('geri alma dosyası ve applied.md ✅ kaydı var', () {
    final geri = File(
      'supabase/geri_al/2026-11-04_meydan_okuma_suresi_geri.sql',
    ).readAsStringSync();
    expect(geri, isNot(contains('7 days')));
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(
      RegExp(r'\| 2026-11-04_meydan_okuma_suresi\.sql \| ✅').hasMatch(applied),
      isTrue,
    );
  });

  group('süre etiketi', () {
    Future<String?> label(
      WidgetTester tester,
      Duration left, {
      bool open = false,
    }) async {
      String? out;
      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                out = asyncDuelTimeLeftLabel(context, left, openInvite: open);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return out;
    }

    testWidgets('7 gün "7 gün kaldı", 47 saat hâlâ saat', (tester) async {
      expect(await label(tester, const Duration(days: 7)), '7 gün kaldı');
      expect(await label(tester, const Duration(hours: 47)), '47 sa kaldı');
      expect(await label(tester, const Duration(hours: 18)), '18 sa kaldı');
      expect(
        await label(tester, const Duration(days: 6, hours: 23), open: true),
        '7 gün içinde katılan olmazsa kapanır',
      );
    });
  });
}
