import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'support/widget_test_helpers.dart';

/// `loadBlockedPlayers` sunucuya hiç ulaşamayan sahte depo — gerçek
/// üretim kusurunu (şema-aşan embed → PostgREST hatası) taklit eder.
class _BlockedLoadFailsRepository extends MockZanKurdRepository {
  @override
  Future<List<PlayerSearchResult>> loadBlockedPlayers() async {
    throw Exception('schema cache error: could not find relationship');
  }
}

/// Engel kaldırmanın hiçbir arayüz yolu yoktu (2026-08-02 denetimi).
///
/// `unblockPlayer` depoda, arayüz sözleşmesinde ve mock'ta vardı — ama
/// `lib/src/screens` altında TEK bir çağıranı bile yoktu. Kullanıcı birini
/// engelledikten sonra kararını geri alamıyordu.
///
/// Engelleme, geri alınabilir olmadıkça bir moderasyon aracı değil tek
/// yönlü bir kapıdır: yanlışlıkla engellenen bir arkadaş kalıcı olarak
/// kayboluyordu. Apple 1.2 engelleme maddesi de yönetilebilir bir engel
/// bekler.
void main() {
  test('engel kaldırma arayüzden çağrılıyor', () {
    final found = Directory('lib/src/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('unblockPlayer'))
        .map((f) => f.path)
        .toList();
    expect(
      found,
      isNotEmpty,
      reason:
          'unblockPlayer depoda duruyor ama hiçbir ekran onu çağırmıyor — '
          'engel tek yönlü bir kapı',
    );
  });

  test('engellenenler ADLARIYLA listeleniyor', () {
    // Kullanıcıya UUID listesi göstermek engeli yönetilebilir kılmaz.
    final contract = File(
      'lib/src/data/zankurd_repository.dart',
    ).readAsStringSync();
    expect(contract, contains('loadBlockedPlayers()'));
  });

  test('ayarlarda bölüm ve boş durum var', () {
    final src = File('lib/src/screens/settings_screen.dart').readAsStringSync();
    expect(src, contains('_BlockedUsersSection'));
    expect(
      src,
      contains('blocked-empty'),
      reason: 'hiç engellenmemişse kullanıcı boş bir panel görür',
    );
  });

  test('mock depo engelle/kaldır döngüsünü destekliyor', () async {
    final repo = MockZanKurdRepository();
    await repo.blockPlayer('p9');
    expect((await repo.loadBlockedPlayers()).map((e) => e.id), contains('p9'));
    await repo.unblockPlayer('p9');
    expect(await repo.loadBlockedPlayers(), isEmpty);
  });

  group('loadBlockedPlayers üretim sözleşmesi (2026-08-14 denetimi)', () {
    late String src;
    late String executableSrc;

    setUpAll(() {
      src = File(
        'lib/src/data/supabase_zankurd_repository.dart',
      ).readAsStringSync();
      // Yorum satırları atılmış hâli: düzeltmeyi anlatan yorum kusurun
      // ADINI bilerek alıntılıyor, ham metin araması bunu düzeltmenin
      // kendisi sanmamalı.
      executableSrc = src
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    });

    test('şema-aşan embed kullanılmıyor', () {
      // `blocked_users.blocked_id`nin tek kısıtı auth şemasınadır
      // (2026-07-31_chat_moderation.sql); `profiles`e FK yok, yani PostgREST
      // bunu bir tabloya gömme (embed) olarak asla çözemez — her çağrı
      // şema hatasıyla düşüyordu.
      final brokenEmbed = ['profiles!blocked_users_blocked_id', 'fkey'].join(
        '_',
      );
      expect(
        executableSrc,
        isNot(contains(brokenEmbed)),
        reason: 'FK olmayan embed her çağrıda 42703/şema hatası verir',
      );
    });

    test('okunamayan liste sessizce boşa düşmüyor', () {
      // Yalnız catch bloğunun kendisine bakılır — `ids.isEmpty` için
      // erken `return const []` (aramaya değer engel yoksa) meşrudur;
      // yalnızca HATA yolunda boşa düşmek yanlıştı.
      final match = RegExp(
        r"reason: 'loadBlockedPlayers failed'\);([\s\S]{0,400})",
      ).firstMatch(executableSrc);
      expect(match, isNotNull, reason: 'hata kaydı satırı bulunamadı');
      final afterErrorLog = match!.group(1)!;
      expect(
        afterErrorLog,
        isNot(contains('return const [];')),
        reason:
            'hata yutulup boş dönerse gerçekten engellenmiş biri '
            '"kimseyi engellemedin" ekranında kayboluyordu',
      );
      expect(afterErrorLog, contains('rethrow'));
    });
  });

  test('ayarlar okunamayan listede hata + yeniden dene gösterir', () {
    final src = File('lib/src/screens/settings_screen.dart').readAsStringSync();
    expect(
      src,
      contains('blocked-error'),
      reason:
          'liste okunamadığında boş durum kılığına girmemesi için ayrı bir '
          'hata anahtarı gerekir',
    );
    expect(src, contains('snapshot.hasError'));
  });

  testWidgets(
    'engel listesi okunamazsa "kimseyi engellemedin" DEĞİL hata gösterilir',
    (tester) async {
      await tester.pumpWidget(
        testShell(
          child: SettingsScreen(repository: _BlockedLoadFailsRepository()),
        ),
      );
      final finder = find.byKey(const ValueKey('blocked-error'));
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(finder, findsOneWidget);
      expect(find.byKey(const ValueKey('blocked-empty')), findsNothing);
      expect(find.text('Engellenenler listesi yüklenemedi.'), findsOneWidget);
    },
  );
}
