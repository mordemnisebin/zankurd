import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';

class _FakeTimeZoneResolver implements TimeZoneResolver {
  const _FakeTimeZoneResolver(this.value);

  final String? value;

  @override
  Future<String?> resolve() async => value;
}

class _BlockingTimeZoneResolver implements TimeZoneResolver {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<String?> resolve() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return 'Europe/Istanbul';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.resetInstance();
  });

  group('NotificationService', () {
    test('varsayılan olarak bildirimler kapalıdır', () async {
      final service = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
      );
      expect(service.enabled, false);
    });

    test("varsayılan saat 19:00'dır", () async {
      final service = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
      );
      expect(service.hour, 19);
      expect(service.minute, 0);
      expect(service.timeDisplay, '19:00');
    });

    test('bildirim açılıp kapatılabilir', () async {
      final service = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
      );
      await service.setEnabled(true);
      expect(service.enabled, true);
      await service.setEnabled(false);
      expect(service.enabled, false);
    });

    test('bildirim saati değiştirilebilir', () async {
      final service = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
      );
      await service.setTime(8, 30);
      expect(service.hour, 8);
      expect(service.minute, 30);
      expect(service.timeDisplay, '08:30');
    });

    test('singleton örneği korunur', () async {
      final service1 = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
      );
      final service2 = await NotificationService.load(
        timeZoneResolver: const _FakeTimeZoneResolver('Europe/Istanbul'),
      );
      expect(identical(service1, service2), true);
    });

    test(
      'eşzamanlı load çağrıları aynı singleton init işini paylaşır',
      () async {
        final resolver = _BlockingTimeZoneResolver();

        final firstLoad = NotificationService.load(timeZoneResolver: resolver);
        await resolver.entered.future;
        final secondLoad = NotificationService.load(timeZoneResolver: resolver);
        resolver.release.complete();

        final services = await Future.wait([firstLoad, secondLoad]);
        expect(identical(services[0], services[1]), isTrue);
        expect(identical(NotificationService.instance, services[0]), isTrue);
      },
    );

    test(
      'platform bildirim eklentisi testte yokken sessizce devam eder',
      () async {
        final originalDebugPrint = debugPrint;
        final messages = <String>[];
        debugPrint = (message, {wrapWidth}) {
          if (message != null) messages.add(message);
        };

        try {
          final service = await NotificationService.load(
            timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
          );
          await service.setEnabled(true);
          await service.setEnabled(false);
        } finally {
          debugPrint = originalDebugPrint;
        }

        expect(
          messages.where((message) => message.startsWith('Failed to ')),
          isEmpty,
        );
      },
    );

    test(
      'yerel saat dilimi cihazdan çözülür, sabit Istanbul zorlaması yoktur',
      () {
        final source = File(
          'lib/src/services/notification_service.dart',
        ).readAsStringSync();

        expect(source, contains('FlutterTimezone.getLocalTimezone()'));
        expect(source, isNot(contains("tz.getLocation('Europe/Istanbul')")));
      },
    );

    test('günlük hatırlatıcı günün dersi anahtarını kullanır', () {
      expect(
        File('lib/src/services/notification_service.dart').readAsStringSync(),
        contains('K.huhuGununSorulukEtkinligi'),
      );
    });

    group('nextFireTime', () {
      test('hedef saat bugün geçmemişse bugünü döner', () async {
        final service = await NotificationService.load(
          timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
        );
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 10, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 21, 19, 0));
      });

      test('hedef saat bugün geçmişse yarını döner', () async {
        final service = await NotificationService.load(
          timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
        );
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 20, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 22, 19, 0));
      });

      test('hedef saate tam denk gelirse yarını döner', () async {
        final service = await NotificationService.load(
          timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
        );
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 19, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 22, 19, 0));
      });

      test('dakikalı hedef saat doğru hesaplanır', () async {
        final service = await NotificationService.load(
          timeZoneResolver: const _FakeTimeZoneResolver('Europe/Berlin'),
        );
        await service.setTime(8, 30);
        final from = DateTime(2026, 6, 21, 7, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 21, 8, 30));
      });
    });
  });
}
