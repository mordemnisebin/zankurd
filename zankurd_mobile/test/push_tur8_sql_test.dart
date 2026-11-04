/// `2026-11-06_push_tur8.sql` bekçisi: cihaz başına FCM jetonu temizliği.
///
/// ## Kusur (GPT-6 Pro ALAN 4)
///
/// `clear_my_fcm_token()` yalnız kullanıcı kimliğine bakıp jetonu siliyordu:
/// aynı hesabın ikinci cihazı T2'yi kaydettikten sonra birinci cihazın çıkışı
/// T2'yi de kaldırıyor, ikinci cihaz yeniden kayıt tetikleyene kadar push
/// alamıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// İşlemler sıralı çalışsa bile hata oluşur, ama hiçbir şey fırlatmaz: RPC
/// başarıyla döner, çıkış yapan kullanıcı bir şey görmez; yalnız öteki cihazın
/// bildirimleri sessizce kesilir. Göç additive'dir (yeni aşırı yükleme); sıfır
/// parametreli işlev build 43 için olduğu gibi kalır. Canlı DB'ye bağlanılmaz,
/// metin sabitlenir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File('supabase/2026-11-06_push_tur8.sql').readAsStringSync();
  final geriRaw = File(
    'supabase/geri_al/2026-11-06_push_tur8_geri.sql',
  ).readAsStringSync();
  final applied = File('supabase/applied.md').readAsStringSync();
  String strip(String s) =>
      s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
  final code = strip(raw);
  final geri = strip(geriRaw);

  test('tek işlem, küçük harfli begin/commit; geri alma da; applied ✅', () {
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(geri.trimLeft(), startsWith('begin;'));
    expect(geri.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(geriRaw, isNot(contains('COMMIT')));
    expect(applied, contains('2026-11-06_push_tur8.sql | ✅'));
  });

  test('yeni aşırı yükleme yalnız verilen jetonu siler; eskisine dokunmaz', () {
    expect(
      code,
      contains('create function public.clear_my_fcm_token(p_token text)'),
    );
    // `create or replace` YOK: mevcut sıfır parametreli gövde ezilmez.
    expect(code, isNot(contains('create or replace function')));
    expect(code, contains('fcm_token = btrim(p_token)'));
    expect(code, contains('id = auth.uid()'));
    expect(code, contains('security definer'));
    expect(code, contains("set search_path to 'public', 'pg_temp'"));
    expect(code, contains('from public, anon'));
    expect(code, contains('to authenticated, service_role'));
  });

  test('önkoşul: işlev zaten varsa durur; sonda ACL/definer doğrulanır', () {
    expect(
      code,
      contains(
        "to_regprocedure('public.clear_my_fcm_token(text)') is not null",
      ),
    );
    expect(code, contains('p.prosecdef'));
    expect(code, contains("has_function_privilege('anon'"));
    expect(code, contains("has_function_privilege('public'"));
    expect(
      code,
      contains("to_regprocedure('public.clear_my_fcm_token()') is null"),
    );
  });

  test(
    'geri alma yalnız yeni işlevi kaldırır ve eskisinin kaldığını doğrular',
    () {
      expect(
        geri,
        contains('drop function if exists public.clear_my_fcm_token(text);'),
      );
      expect(geri, isNot(contains('clear_my_fcm_token();')));
      expect(
        geri,
        contains("to_regprocedure('public.clear_my_fcm_token()') is null"),
      );
    },
  );

  test(
    'istemci: jeton bilinirse tek parametreli, yoksa/eksikse eskisine düşer',
    () {
      final auth = File(
        'lib/src/providers/auth_provider.dart',
      ).readAsStringSync();
      expect(auth, contains("params: {'p_token': deviceToken}"));
      expect(auth, contains('PushTokenSync.lastRegisteredToken'));
      expect(auth, contains('revokeFirebaseDeviceToken'));
      // Eski, koşulsuz çağrı yedek yol olarak kalır (build 43 sunucusu / jeton yok).
      expect(auth, contains(".rpc<void>('clear_my_fcm_token')"));
    },
  );
}
