/// T2 (`2026-11-03_rovans_oda_sahibi.sql`) bekçisi: rövanşta aynı kod, sahip
/// korunması, sahiplik devri ve lobi ayarı.
///
/// ## Kusurlar
///
/// * `create_room_rematch` yeni oda için yeni kod üretiyordu; "aynı koda
///   dön" diyen oyuncular koda baktığında başka bir oda görüyordu.
/// * Rövanş odasının sahibi rövanşa İLK BASAN oluyordu; asıl sahip ikinci
///   basınca misafir kalıyordu.
/// * İki kişilik özel odada lobide sahip çıkınca oda `host_left` ile
///   kapanıyor, kalan oyuncu atılıyordu; sahip lobiye hiç girmezse kimse
///   devralamıyordu.
/// * Lobide kategori/süre/soru sayısını değiştirmenin sunucu yolu yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsi çalışan SQL'dir: hata fırlamaz, sayı döner. Yalnız "yanlış kişi
/// sahip", "kod değişti" ya da "oda kapandı" olur; hiçbir derleme/widget
/// testi bunu görmez. Bu dosya göçü metin olarak okuyup kuralları sabitler
/// (canlı DB'ye bağlanmaz; canlı gövde ön koşul bloğuyla uygulama anında
/// doğrulanır).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File(
    'supabase/2026-11-03_rovans_oda_sahibi.sql',
  ).readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-03_rovans_oda_sahibi.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();
  final code = strip(raw);
  final geri = strip(geriRaw);

  /// `name` fonksiyonunun gövdesi (create … sonraki `$function$;`).
  String body(String source, String name) {
    final start = source.indexOf('function public.$name(');
    expect(start, greaterThanOrEqualTo(0), reason: '$name tanımı yok');
    final end = source.indexOf(
      r'$function$;',
      source.indexOf(r'$function$', start) + 1,
    );
    return source.substring(start, end);
  }

  test('tek işlemde, küçük harfli begin/commit; büyük harfli COMMIT yok', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    // Kuru çalıştırma betiği büyük harfli COMMIT'i rollback'e çeviremez
    // (2026-11-01 olayı).
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
  });

  test('yalnız beklenen fonksiyonlar tanımlanır', () {
    final names = RegExp(
      r'create or replace function public\.([a-z_]+)\(',
    ).allMatches(code).map((m) => m.group(1)).toList();
    expect(
      names,
      unorderedEquals([
        'room_lobby_state_json',
        'create_room_rematch',
        'leave_room',
        'room_heartbeat',
        'update_room_settings',
      ]),
    );
  });

  test('canlı gövde ön koşulu ve idempotent kaynak denetimi var', () {
    expect(code, contains('pg_get_functiondef'));
    expect(
      code,
      contains('t2: canlı create_room_rematch beklenen kaynakta değil'),
    );
    expect(code, contains('t2: canlı leave_room beklenen kaynakta değil'));
    expect(code, contains('add column if not exists rematch_owner_id'));
    expect(code, contains('add column if not exists last_seen_at'));
  });

  test('rövanş: imza aynı; eski kodu korur; çakışmada yeni kod kalır', () {
    final f = body(code, 'create_room_rematch');
    expect(f, contains('create_room_rematch(p_room_id uuid)'));
    expect(f, contains('returns json'));
    expect(f, contains('create_online_room_impl('));
    // Aynı kod: yeni odanın kodu eski odanın koduna yazılır…
    expect(f, contains('set code = v_room.code'));
    // …benzersiz dizin reddederse sessizce yeni kod kalır.
    expect(f, contains('when unique_violation'));
    expect(f, contains("jsonb_build_object('code', v_room.code)"));
    // Yalnız BU çağrının yeni açtığı lobiye dokunulur.
    expect(
      f,
      isNot(contains('created_at')),
      reason: 'created_at ilgisiz odayı ayıramaz',
    );
    // Başka açık odadaki oyuncunun "rövanşı" ilgisiz odayı işaretleyemez:
    // yardımcıdan ÖNCE, üyelik kilidi altında reddedilir.
    final lock = f.indexOf(
      "pg_advisory_xact_lock(hashtextextended('room-membership'",
    );
    final guard = f.indexOf(
      "raise exception 'player is already in another live room'",
    );
    final helper = f.indexOf('v_result := public.create_online_room_impl(');
    expect(lock, greaterThan(0));
    expect(guard, greaterThan(lock));
    expect(helper, greaterThan(guard));
    // rematch_room_id yalnız BU çağrının kurduğu odaya yazılır (if içinde).
    final mark = f.indexOf('set rematch_room_id = v_new_id');
    expect(mark, greaterThan(f.indexOf('v_new_id is distinct from p_room_id')));
    // Eşzamanlı ikinci basan: eski oda satırı kilitli, mevcut lobiye katılır.
    expect(
      f.indexOf('for update'),
      lessThan(f.indexOf('v_room.rematch_room_id is not null')),
    );
    // Eski ayarların hepsi hâlâ kopyalanır.
    for (final field in [
      'seconds_per_question',
      'question_count',
      'entry_fee',
      'max_players',
    ]) {
      expect(f, contains('v_room.$field'));
    }
  });

  test('rövanş: önceki sahip korunur; ayrıldıysa basan sahip kalır', () {
    final f = body(code, 'create_room_rematch');
    expect(f, contains('rematch_owner_id = v_room.host_id'));
    expect(f, contains('v_room.host_id <> v_uid'));
    // Sahip oyunda kaldı mı: terk etmedi (forfeited_by) ve left_at boş.
    expect(f, contains('v_room.forfeited_by is distinct from v_room.host_id'));
    expect(f, contains('rp.left_at is null'));
    // İkinci basan sahipse sahiplik ona döner.
    expect(f, contains('v_next.rematch_owner_id = v_uid'));
    expect(f, contains('set host_id = v_uid'));
  });

  test(
    'lobide sahip çıkınca iki kişilik ÖZEL odada devir, eşleşmede değil',
    () {
      final f = body(code, 'leave_room');
      final transfer = f.indexOf('if v_room.is_custom then');
      final finish = f.indexOf("ended_reason = 'host_left'");
      expect(transfer, greaterThan(0));
      expect(finish, greaterThan(transfer), reason: 'devir kapanıştan ÖNCE');
      expect(f, contains('order by rp.joined_at, rp.player_id'));
      expect(f, contains("'host_transferred'"));
      expect(f, contains("'new_host_id', v_new_host"));
      // Ayrılan sahip ücretini geri alır.
      expect(f, contains('refund_room_entry_fee(p_room_id, v_uid)'));
      // Oyun sırasındaki forfeit ve kalabalık yolu korunur.
      expect(f, contains("ended_reason = 'forfeit'"));
      expect(f, contains('crowd_room_member_leave'));
      expect(f, contains('v_final_revealed'));
    },
  );

  test('heartbeat: 45 sn sessiz sahip, NULL=eski istemci devredilmez', () {
    final f = body(code, 'room_heartbeat');
    expect(f, contains("interval '45 seconds'"));
    expect(
      f,
      contains('rp.last_seen_at is not null'),
      reason: 'hiç sinyal vermemiş (build 42/43) sahip düşürülmez',
    );
    expect(f, contains('order by rp.joined_at, rp.player_id'));
    // Adaylar sinyal veren (aktif) üyelerdir.
    expect(f, contains('rp.last_seen_at >= clock_timestamp() - c_grace'));
    // Yalnız lobide ve özel odada; devir kilit altında yeniden doğrulanır.
    expect(f, contains("v_room.status = 'lobby' and v_room.is_custom"));
    expect(f, contains('for update'));
    // 10 sn'de bir yazım: kalabalık lobide yük düşük.
    expect(f, contains("interval '10 seconds'"));
    // Üye olmayan çağıran reddedilir.
    expect(f, contains("raise exception 'player is not in the room'"));
    // Rövanşın önceki sahibi lobiye girince sahiplik ona geçer.
    expect(f, contains('v_room.rematch_owner_id'));
  });

  test('ayar: yalnız sahip, yalnız lobide; ücret ve kapasite değişmez', () {
    final f = body(code, 'update_room_settings');
    expect(f, contains('v_room.host_id is distinct from v_uid'));
    expect(
      f,
      contains("raise exception 'only the room host can change settings'"),
    );
    expect(f, contains("v_room.status <> 'lobby'"));
    expect(
      f,
      contains("raise exception 'room settings can only change in the lobby'"),
    );
    // Oda kilidi start_room_game ile yarışmayı önler.
    expect(f, contains('for update'));
    // create_online_room_impl ile aynı izinli değerler.
    expect(f, contains('(10, 15, 20, 30, 45, 60, 90, 120)'));
    expect(f, contains('(5, 10, 15, 20, 25, 30, 40, 50)'));
    // Değişen sütunlar yalnız bu dördü.
    final update = f.substring(f.indexOf('update public.rooms r'));
    final setPart = update.substring(0, update.indexOf('where r.id'));
    expect(setPart, contains('category_id'));
    expect(setPart, contains('category_ids'));
    expect(setPart, contains('seconds_per_question'));
    expect(setPart, contains('question_count'));
    expect(setPart, isNot(contains('entry_fee')));
    expect(setPart, isNot(contains('max_players')));
    expect(setPart, isNot(contains('host_id')));
  });

  test('SECURITY DEFINER, sabit search_path, anon kapalı', () {
    expect(r'security definer'.allMatches(code).length, 5);
    expect(
      RegExp(r"set search_path to 'public', 'pg_temp'").allMatches(code).length,
      5,
    );
    for (final fn in [
      'create_room_rematch(uuid)',
      'leave_room(uuid)',
      'room_heartbeat(uuid)',
      'update_room_settings(uuid, text[], integer, integer)',
    ]) {
      expect(code, contains('revoke all on function public.$fn'));
      expect(code, contains('grant execute on function public.$fn'));
    }
    // İç yardımcı istemciye kapalı.
    expect(
      code,
      contains(
        'revoke all on function public.room_lobby_state_json(uuid)\n  from public, anon, authenticated;',
      ),
    );
  });

  test('eski RPC imzaları (build 42/43) korunur', () {
    // Eski istemci create_room_rematch(uuid) ve leave_room(uuid) çağırır;
    // yeni parametre eklenmedi, dönüş json kaldı.
    expect(
      code,
      contains('function public.create_room_rematch(p_room_id uuid)'),
    );
    expect(code, contains('function public.leave_room(p_room_id uuid)'));
    expect(code, isNot(contains('drop function')));
    expect(code, isNot(contains('p_new_')));
  });

  test('geri alma eski gövdeleri yükler, yeni RPC\'leri siler', () {
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(
      geri,
      contains('drop function if exists public.update_room_settings'),
    );
    expect(geri, contains('drop function if exists public.room_heartbeat'));
    expect(
      geri,
      contains('drop function if exists public.room_lobby_state_json'),
    );
    expect(geri, isNot(contains('host_transferred')));
    expect(geri, isNot(contains('rematch_owner_id')));
    expect(geri, contains("ended_reason = 'host_left'"));
    expect(
      geri,
      contains('set code'.replaceAll('set code', 'rematch_room_id')),
    );
  });

  test('applied.md satırı ✅ (canlıda)', () {
    expect(
      RegExp(r'2026-11-03_rovans_oda_sahibi\.sql \| ✅').hasMatch(applied),
      isTrue,
    );
  });
}
