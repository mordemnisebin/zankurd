/// 2026-11-07 idempotent_ops temizlik göçü sözleşmesi (GPT-6 Pro ALAN 10).
///
/// ## Kusur
///
/// 14 günlük temizlik yalnız çağıran kullanıcının SONRAKİ işleminde
/// çalışıyordu; etkin olmayan hesapların kayıtları süresiz birikirdi.
///
/// ## Niçin sessiz kalırdı
///
/// Tablo RLS ile istemciye kapalı; büyüme hiçbir hata vermez, yalnız depolama
/// ve yedek maliyeti olarak görünür.
///
/// ## Kural
///
/// Genel işin tüm koruyucuları yerinde durur: iş adı varsa göç durur, silme
/// 14 gün penceresini korur, partiler sınırlı ve `skip locked`, indeks var,
/// küçük harfli begin/commit, geri alma işi kaldırır, tur9 dosyası değişmez.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sql(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'--[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

void main() {
  final sql = _sql('supabase/2026-11-07_idempotency_temizlik.sql');
  final rollback = _sql(
    'supabase/geri_al/2026-11-07_idempotency_temizlik_geri.sql',
  );

  test('göç küçük harfli begin/commit ile sarılı', () {
    expect(sql.trimLeft().startsWith('begin;'), isTrue);
    expect(sql.trimRight().endsWith('commit;'), isTrue);
  });

  test('iş adı zaten varsa göç durur (henüz uygulanmamış ön koşulu)', () {
    expect(
      sql,
      contains(
        "exists (select 1 from cron.job where jobname = 'idempotent-ops-temizlik')",
      ),
    );
    expect(sql, contains('raise exception'));
  });

  test('silme 14 günü korur, sınırlı ve kilitli satırları atlar', () {
    expect(sql, contains("created_at < now() - interval '14 days'"));
    expect(sql, contains('limit 20000'));
    expect(sql, contains('for update skip locked'));
    expect(sql, contains('on public.idempotent_ops (created_at)'));
  });

  test('geri alma işi kaldırır ve indeksi siler', () {
    expect(rollback, contains('cron.unschedule'));
    expect(rollback, contains('drop index if exists'));
  });

  test('tur9 göçü bu turda değişmedi: temizlik işlevlere eklenmedi', () {
    final tur9 = _sql('supabase/2026-11-07_idempotency_tur9.sql');
    expect(tur9, isNot(contains('idempotent-ops-temizlik')));
  });
}
