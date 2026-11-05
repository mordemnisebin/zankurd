/// Hesap silmede avatar kalıntıları (son sürüm incelemesi, engelleyici).
///
/// ## Kusur
///
/// Build 43 istemcisi yalnız `delete_my_account` çağırır; RPC içindeki
/// `DELETE FROM storage.objects` fiziksel dosyayı silmez ve hatası yutulur.
/// `avatars` kovası herkese açıktır: silinmiş kullanıcıların fotoğrafları
/// adreslenebilir kalırdı.
///
/// ## Niçin sessiz kalırdı
///
/// Silme hatasız "başarılı" dönüyordu; kimse kovayı `auth.users` ile
/// karşılaştırmıyordu. Bekçi saatlik süpürmenin üç parçasını sabitler: Edge
/// Function (sırla korunan, JWT'siz), göç (send-push deseni, hardcode yok,
/// henüz uygulanmamış ön koşulu) ve geri alma.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Edge Function sırla korunur, service role kullanır, uuid dışına dokunmaz',
    () {
      final index = File(
        'supabase/functions/avatar-sweep/index.ts',
      ).readAsStringSync();
      final lib = File(
        'supabase/functions/avatar-sweep/lib.ts',
      ).readAsStringSync();
      expect(index, contains('x-cron-secret'));
      expect(index, contains('CRON_SECRET'));
      expect(index, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(index, contains('MAX_OBJECTS_PER_RUN'));
      expect(index, contains('existingUserIds'));
      // 2026-11-16: sahipsiz süzme folderEntries (orijinal harf büyüklüğü) +
      // existing kümesiyle yapılır; orphanFolders yardımcısı lib'de durur.
      expect(index, contains('folderEntries'));
      expect(index, contains('!existing.has('));
      expect(lib, contains('orphanFolders'));
      expect(lib, contains('isUserFolder'));
      expect(
        File('supabase/functions/avatar-sweep/lib_test.ts').existsSync(),
        isTrue,
      );
      expect(
        File('supabase/config.toml').readAsStringSync(),
        contains('[functions.avatar-sweep]\nverify_jwt = false'),
      );
    },
  );

  test(
    'göç send-push desenini izler: Vault, pg_net, düz URL/sır yok, ön koşul',
    () {
      final sql = File(
        'supabase/2026-11-08_avatar_supurme.sql',
      ).readAsStringSync();
      final geri = File(
        'supabase/geri_al/2026-11-08_avatar_supurme_geri.sql',
      ).readAsStringSync();
      expect(sql, contains('begin;'));
      expect(sql, contains('commit;'));
      expect(sql, contains("jobname = 'avatar-supurme'"));
      expect(sql, contains('göç zaten uygulanmış'));
      expect(sql, contains('net.http_post'));
      expect(sql, contains("s.name = 'avatar_sweep_url'"));
      expect(sql, contains("s.name = 'cron_secret'"));
      expect(sql, contains("'x-cron-secret'"));
      expect(sql, contains("'17 * * * *'"));
      expect(
        RegExp(r'https?://').hasMatch(sql.replaceAll(RegExp(r'--[^\n]*'), '')),
        isFalse,
      );
      expect(geri, contains('begin;'));
      expect(geri, contains('commit;'));
      expect(geri, contains("cron.unschedule('avatar-supurme')"));
      final applied = File('supabase/applied.md').readAsStringSync();
      expect(
        applied,
        matches(RegExp(r'\| 2026-11-08_avatar_supurme\.sql \| ✅')),
      );
    },
  );
}
