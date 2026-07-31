import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kısıtlı bir fonksiyonu çağıran her tetikleyici `security definer` olmalı.
///
/// ## Kusur
///
/// `2026-07-28_player_tag.sql` iki şey yapıyordu ve ikisi de tek başına
/// doğruydu:
///
/// 1. `generate_player_tag()` istemciden geri alındı — kullanıcı kod
///    havuzunu doğrudan tüketememeli.
/// 2. `profiles` üzerine BEFORE INSERT tetikleyicisi kondu ve o fonksiyon
///    `generate_player_tag()`i çağırıyor.
///
/// Ama tetikleyici fonksiyonu `security definer` DEĞİLDİ. PostgreSQL'de
/// varsayılan `security invoker`dır: tetikleyici, satırı ekleyen kullanıcının
/// yetkileriyle çalışır. Yani `authenticated` bir kullanıcı profil satırı
/// eklediğinde tetikleyici onun adına kısıtlı fonksiyonu çağırıyor ve
/// 1. maddedeki revoke tam da bunu engelliyordu:
///
///     permission denied for function generate_player_tag (42501)
///
/// `ensureProfile()` istisnayı yutuyordu, bu yüzden uygulama açılıyor ve
/// ana ekran normal görünüyordu — ama profil satırı HİÇ oluşmuyordu. Yeni
/// her kullanıcı kodsuz, liderlikte görünmez ve oda kuramaz kalıyordu.
///
/// Kusur kod okumasıyla görünmüyordu: iki ayrı dosyadaki iki doğru kararın
/// kesişimindeydi. 2026-08-01'de iOS simülatöründe canlı backend'e
/// bağlanınca ortaya çıktı.
///
/// Bu bekçi deseni genelleştirir: kısıtlanmış bir fonksiyonu çağıran her
/// tetikleyici, tanımlayıcı yetkisiyle çalışmak zorundadır.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'supabase/2026-08-01_player_tag_trigger_permission.sql',
    ).readAsStringSync();
  });

  test('düzeltme göçü var ve tetikleyici tanımlayıcı yetkisiyle çalışıyor', () {
    expect(source, contains('function public.assign_player_tag()'));
    expect(
      source,
      contains('security definer'),
      reason:
          'security invoker tetikleyici, kısıtlı generate_player_tag i '
          'çağıramaz — yeni kullanıcının profili hiç oluşmaz.',
    );
    expect(
      source,
      contains('set search_path = public'),
      reason:
          'security definer bir fonksiyon çağıranın arama yolunu miras '
          'alırsa sahte bir nesne gerçeğin önüne geçebilir.',
    );
  });

  test('generate_player_tag istemciye kapalı KALMAYA devam ediyor', () {
    // Düzeltme, korumayı gevşeterek değil tetikleyiciyi muaf tutarak
    // çalışmalı. Göç dosyası fonksiyona yeni bir grant vermemeli.
    expect(
      source,
      isNot(contains('grant execute on function public.generate_player_tag')),
      reason:
          'Kolay ama yanlış düzeltme: fonksiyonu istemciye açmak. O zaman '
          'kullanıcı kod havuzunu doğrudan tüketebilir.',
    );

    final original = File(
      'supabase/2026-07-28_player_tag.sql',
    ).readAsStringSync();
    expect(
      original,
      contains(
        'revoke all on function public.generate_player_tag() from public, '
        'anon, authenticated',
      ),
      reason: 'Asıl koruma yerinde durmalı.',
    );
  });

  test('kısıtlı fonksiyon çağıran her tetikleyici tanımlayıcı yetkili', () {
    // Deseni genelleştir: hangi fonksiyonlar istemciden geri alınmışsa,
    // onları çağıran her trigger fonksiyonu `security definer` olmalı.
    final migrations = Directory('supabase')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList();

    // İstemciden geri alınan fonksiyonlar.
    final revoked = <String>{};
    final revokePattern = RegExp(
      r'revoke\s+all\s+on\s+function\s+public\.([a-z_0-9]+)\s*\([^)]*\)'
      r'\s+from\s+[^;]*authenticated',
      caseSensitive: false,
    );
    for (final file in migrations) {
      revoked.addAll(
        revokePattern
            .allMatches(file.readAsStringSync())
            .map((m) => m.group(1)!),
      );
    }
    expect(
      revoked,
      contains('generate_player_tag'),
      reason: 'Bekçi kör kalmasın: en az bir bilinen örnek yakalanmalı.',
    );

    // Trigger fonksiyonlarını topla (returns trigger) ve gövdesinde
    // kısıtlı bir fonksiyon çağıranları denetle.
    final triggerFn = RegExp(
      r'create\s+or\s+replace\s+function\s+public\.([a-z_0-9]+)\s*\(\s*\)\s*'
      r'returns\s+trigger(.*?)\$\$;',
      caseSensitive: false,
      dotAll: true,
    );

    // Dosya adındaki tarih uygulama sırasıdır; SON tanım kazanır.
    // Bir fonksiyonun en geç tarihli tanımı doğruysa, daha eski bir
    // dosyadaki kırık hâli zararsızdır — sıra onu zaten eziyor.
    final latestDefinition = <String, ({String file, String body})>{};
    for (final file in migrations..sort((a, b) => a.path.compareTo(b.path))) {
      for (final match in triggerFn.allMatches(file.readAsStringSync())) {
        latestDefinition[match.group(1)!] = (
          file: file.uri.pathSegments.last,
          body: match.group(2)!,
        );
      }
    }

    final offenders = <String>[];
    latestDefinition.forEach((name, definition) {
      final callsRestricted = revoked.any(
        (fn) => definition.body.contains('public.$fn('),
      );
      if (!callsRestricted) return;
      if (!definition.body.toLowerCase().contains('security definer')) {
        offenders.add('${definition.file}: $name');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu tetikleyici(ler)in EN GEÇ tanımı kısıtlı bir fonksiyon '
          'çağırıyor ama çağıranın yetkisiyle çalışıyor; insert 42501 ile '
          'düşer:\n${offenders.join("\n")}',
    );
  });
}
