import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// İstemci-sunucu hayalet kuyruk satırı zaman aşımı uyuşmazlığı.
///
/// ## Kusur
///
/// `matchmaking_screen.dart` 20 saniyede eşleşme bulamazsa yerel olarak
/// vazgeçip `cancelMatchmaking()` çağırıyor. Ama `join_matchmaking()`
/// içindeki hayalet-satır temizliği (`2026-08-02_multiplayer_session_hardening.sql`)
/// yalnız 2 DAKİKADAN eski satırları siliyordu. `cancelMatchmaking()` ağ
/// kopması/uygulamanın arka plana atılması yüzünden sunucuya ulaşamazsa,
/// vazgeçmiş bir oyuncunun satırı 100 saniye daha "eşleştirilebilir"
/// kalıyor — o sırada gelen üçüncü bir oyuncu artık orada olmayan biriyle
/// eşleşebiliyor (2026-08-14 denetimi).
///
/// ## Düzeltme
///
/// `supabase/2026-08-14_matchmaking_queue_ttl_alignment.sql`,
/// `join_matchmaking()`i `create or replace function` ile yeniden yazıp
/// temizlik penceresini istemcinin 20sn'lik vazgeçme süresine + ağ/RPC
/// gecikmesi için bir paya (toplam 40 saniye) çekiyor. İstemci tarafı
/// BİLEREK değiştirilmedi (20sn kısa tutulmuş bir UX kararı); sunucu
/// penceresi istemciye yaklaştırıldı, tersi değil.
void main() {
  /// `player_tag_test.dart`'taki desenin aynısı: hangi tarihli göçün bu
  /// fonksiyonu EN SON tanımladığını bulur.
  String newestDefinitionOf(String function) {
    final pattern = RegExp(
      'create\\s+(?:or\\s+replace\\s+)?function\\s+(?:public\\.)?$function\\b',
      caseSensitive: false,
    );
    final dated =
        Directory('supabase')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .where((f) => RegExp(r'/\d{4}-\d{2}-\d{2}_').hasMatch(f.path))
            .where((f) => pattern.hasMatch(f.readAsStringSync()))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(
      dated,
      isNotEmpty,
      reason: '$function hiçbir tarihli göçte tanımlanmıyor',
    );
    return dated.last.readAsStringSync();
  }

  test(
    'join_matchmaking en son tanımı 40 saniyelik temizlik penceresi kullanır',
    () {
      final newest = newestDefinitionOf('join_matchmaking');
      expect(
        newest,
        contains("interval '40 seconds'"),
        reason:
            'en son tanım hâlâ eski 2 dakikalık pencereye geri düşmüş '
            'olabilir; istemcinin 20sn vazgeçme süresiyle uyumlu kalmalı',
      );
      expect(
        newest,
        isNot(contains("interval '2 minutes'")),
        reason:
            'eski hayalet-satır penceresi (2 dakika) istemcinin 20sn '
            'vazgeçme süresinden çok daha uzun — yarış penceresini '
            'kapatmalıydı',
      );
    },
  );

  test('göç dosyası yalnız temizlik aralığını değiştiriyor', () {
    final migration = File(
      'supabase/2026-08-14_matchmaking_queue_ttl_alignment.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains("interval '40 seconds'"),
      reason: 'yeni pencere açıkça 40 saniye olmalı',
    );
    expect(
      migration,
      contains('create or replace function public.join_matchmaking'),
      reason:
          'zaten yayınlanmış bir fonksiyon; ileri-yönlü create or replace '
          'ile düzeltilmeli, eski dosya düzenlenmemeli',
    );
  });
}
