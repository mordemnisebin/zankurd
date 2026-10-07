// 4. kusur (2026-10-02 denetimi): `main()`te başlatma bir kez olur ama
// onu bekleyen iki yol vardır — ilk kare kararı (`bootStep`) ve sonradan
// yapılan probe. Eski düzende probe, başlatma hatası alınca
// `Supabase.initialize`ı BİR DAHA çağırıyordu. `Supabase.initialize`
// idempotent olsa da ikinci deneme "already initialized" ile
// `Supabase.instance`ı hiç kurdurabilir ve uygulamayı kalıcı çevrimdışı
// bırakabilirdi.
//
// Bu dosya iki sözleşmeyi kilitler: başlatma ÖMÜR BOYU tek future'dır ve
// lib/ içinde `Supabase.initialize` TEK çağrı yeri vardır.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/utils/supabase_boot.dart';

void main() {
  group('SupabaseBoot — başlatma tek sefer', () {
    test('hatalı başlatma ikinci kez denenmez, ping yine atılır', () async {
      var starts = 0;
      var pings = 0;
      final failing = Completer<Supabase>();
      final boot = SupabaseBoot(
        start: () {
          starts += 1;
          return failing.future;
        },
        ping: () async {
          pings += 1;
          return true;
        },
      );

      final first = boot.probe();
      final second = boot.probe();
      expect(starts, 1, reason: 'ikinci probe başlatmayı yeniden çağırmamalı');
      expect(
        identical(first, second),
        isTrue,
        reason: 'eşzamanlı probe TEK yolculukta birleşmeli',
      );

      failing.completeError(StateError('already initialized'));

      expect(await first, isTrue, reason: 'başlatma hatası ping\'i engellemez');
      expect(await second, isTrue);
      expect(starts, 1, reason: 'Supabase.initialize ikinci kez çağrılmamalı');
      expect(pings, 1, reason: 'başlatma bitince sunucuya TEK bir ping gider');
      expect(identical(boot.boot, boot.boot), isTrue);

      // Yolculuk bitti: sonraki probe kendi turunu atar.
      expect(await boot.probe(), isTrue);
      expect(pings, 2, reason: 'yeni probe yeni tur atmalı');
      expect(starts, 1, reason: 'başlatma yine tek');
    });

    test('senkron fırlatma dâhil başlatma tek kalır', () async {
      var starts = 0;
      final boot = SupabaseBoot(
        start: () {
          starts += 1;
          throw StateError('senkron patlama');
        },
        ping: () async => true,
      );

      await expectLater(boot.boot, throwsA(isA<StateError>()));
      await expectLater(boot.boot, throwsA(isA<StateError>()));
      expect(starts, 1, reason: 'senkron hata da yeniden başlatma doğurmamalı');
      expect(await boot.probe(), isTrue, reason: 'ping yine denenir');
      expect(starts, 1);
    });

    test('başlatma sürerken probe onu bekler, ping erken atılmaz', () async {
      var pings = 0;
      final hanging = Completer<Supabase>();
      final boot = SupabaseBoot(
        start: () => hanging.future,
        ping: () async {
          pings += 1;
          return true;
        },
      );

      final probe = boot.probe();
      await Future<void>.delayed(Duration.zero);
      expect(pings, 0, reason: 'başlatma bitmeden ping atılmamalı');

      hanging.completeError(StateError('timeout'));
      expect(await probe, isTrue);
      expect(pings, 1);
    });

    test('zaman aşan denemeler başlatma bitince TEK pingte birleşir', () async {
      // 2. kusur: `RemoteAvailability` zaman aşınca denemeyi bırakıp
      // yenisini başlatır. Eski düzende her deneme kendi
      // `Supabase.initialize` + ping yolculuğunu koştuğu için başlatma
      // bittiğinde ONLARCA istek aynı anda çıkıyordu.
      var pings = 0;
      final hangingBoot = Completer<Supabase>();
      final boot = SupabaseBoot(
        start: () => hangingBoot.future,
        ping: () async {
          pings += 1;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return true;
        },
      );
      final availability = RemoteAvailability(
        reachable: false,
        probe: boot.probe,
        probeTimeout: const Duration(milliseconds: 500),
        retrySchedule: const [Duration(milliseconds: 10)],
      );
      addTearDown(availability.dispose);
      availability.startRetries();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(pings, 0, reason: 'başlatma sürerken ping atılmaz');

      hangingBoot.completeError(StateError('timeout'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(pings, 1, reason: 'başlatma bitince sunucuya TEK istek gider');
      expect(availability.reachable, isTrue, reason: 'karar alınır');
      expect(availability.retrying, isFalse, reason: 'takvim durmalı');
    });
  });

  group('açılış sözleşmesi', () {
    test('lib/ içinde Supabase.initialize tam bir çağrı yeri vardır', () {
      final pattern = RegExp(r'Supabase\.initialize\(');
      final hits = <String>[];
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in sources) {
        final count = pattern.allMatches(file.readAsStringSync()).length;
        if (count > 0) hits.add('${file.path} x$count');
      }

      expect(
        hits,
        hasLength(1),
        reason:
            'İkinci bir Supabase.initialize çağrısı "already initialized" '
            'ile uygulamayı kalıcı çevrimdışı bırakabilir: $hits',
      );
      expect(hits.single, startsWith('lib/main.dart'));
    });
  });
}
