import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Realtime'a eklenen RLS'li her tabloya `replica identity full` gerekir.
///
/// ## Kusur
///
/// `add_realtime_room_tables.sql`, `rooms` ve `room_players`ı
/// `supabase_realtime` publication'ına ekledi ve "Realtime mevcut SELECT
/// policy'lerini kullanır" notunu düştü. Doğruydu ama eksikti.
///
/// RLS açık bir tabloda Realtime, UPDATE olayını aboneye iletmeden önce
/// satırı yetkilendirmek için WAL'daki ESKİ satıra bakar. PostgreSQL
/// varsayılanı `REPLICA IDENTITY DEFAULT`tur ve WAL'a yalnız birincil
/// anahtarı yazar; eksik satırla yetkilendirme yapılamayınca olay sessizce
/// düşer.
///
/// Sonuç, odada: katılım (INSERT) diğer oyuncuya ulaşıyor ama hazır
/// durumu, skor ve oda ilerlemesi (UPDATE) ulaşmıyordu. Ekran "Rewşa te
/// di odê de rasterast ji lîstikvanên din re tê nîşandan" diye vaat
/// ediyor, vaat tutulmuyordu.
///
/// INSERT'in geçmesi kusuru gizliyordu: realtime "çalışıyor" görünüyor,
/// yalnız bir olay türü eksik kalıyordu. 2026-08-01'de Android ev sahibi
/// ile iOS katılan arasında canlı denemede bulundu.
void main() {
  test('realtime oda tablolarında tam replica identity var', () {
    final migration = File(
      'supabase/2026-08-01_room_realtime_replica_identity.sql',
    ).readAsStringSync();

    for (final table in ['rooms', 'room_players']) {
      expect(
        migration,
        contains('alter table public.$table replica identity full'),
        reason:
            '$table üzerindeki UPDATE olayları abonelere ulaşmaz; '
            'oyuncular birbirinin durumunu göremez.',
      );
    }
  });

  test('publication üyeliği de tazeleniyor', () {
    // Ayar tek başına yetmez: tablo publication'da değilse olay hiç
    // doğmaz. İkisi bir arada uygulanmalı.
    final migration = File(
      'supabase/2026-08-01_room_realtime_replica_identity.sql',
    ).readAsStringSync();
    expect(
      migration,
      contains('alter publication supabase_realtime add table public.rooms'),
    );
    expect(
      migration,
      contains(
        'alter publication supabase_realtime add table public.room_players',
      ),
    );
    expect(
      migration,
      contains('when duplicate_object then null'),
      reason: 'Tablo zaten eklenmişse göç düşmemeli.',
    );
  });

  test('publication a eklenen her RLS li tablo kuralın kapsamında', () {
    // Bekçiyi desene bağla: ileride bir tablo daha realtime'a eklenirse
    // replica identity'si de ayarlanmalı, yoksa aynı sessiz kusur doğar.
    final addedTables = <String>{};
    final pattern = RegExp(
      r'alter\s+publication\s+supabase_realtime\s+add\s+table\s+'
      r'(?:public\.)?([a-z_0-9]+)',
      caseSensitive: false,
    );
    final identityPattern = RegExp(
      r'alter\s+table\s+(?:public\.)?([a-z_0-9]+)\s+replica\s+identity\s+full',
      caseSensitive: false,
    );
    final withIdentity = <String>{};

    for (final entity in Directory('supabase').listSync()) {
      if (entity is! File || !entity.path.endsWith('.sql')) continue;
      final sql = entity.readAsStringSync();
      addedTables.addAll(pattern.allMatches(sql).map((m) => m.group(1)!));
      withIdentity.addAll(
        identityPattern.allMatches(sql).map((m) => m.group(1)!),
      );
    }

    expect(
      addedTables,
      contains('room_players'),
      reason: 'Bekçi kör kalmasın: bilinen bir örnek yakalanmalı.',
    );

    // Yalnız-ekleme tabloları muaf: eski satırları hiç olmadığı için
    // UPDATE olayı da doğmaz, tam satırı loglamanın karşılığı yoktur.
    //
    // `matchmaking_queue` burada YOKTU (yanlışlıkla) — ama append-only
    // değil: `join_matchmaking()` rakip bulununca bekleyen oyuncunun
    // satırını `room_id` ile UPDATE ediyor ve istemci tam bu UPDATE'i
    // realtime ile dinliyor (2026-08-14 denetimi, bkz.
    // `supabase/2026-08-14_matchmaking_queue_replica_identity.sql`).
    const appendOnly = {'room_messages'};

    final missing = addedTables.difference(withIdentity).difference(appendOnly);
    expect(
      missing,
      isEmpty,
      reason:
          'Bu tablo(lar) realtime publication ında ama replica identity si '
          'ayarlanmamış; RLS altında UPDATE olayları abonelere hiç '
          'ulaşmaz:\n${missing.join("\n")}',
    );
  });
}
