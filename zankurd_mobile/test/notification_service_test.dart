import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.resetInstance();
  });

  group('NotificationService', () {
    test('varsayılan olarak bildirimler kapalıdır', () async {
      final service = await NotificationService.load();
      expect(service.enabled, false);
    });

    test("varsayılan saat 19:00'dır", () async {
      final service = await NotificationService.load();
      expect(service.hour, 19);
      expect(service.minute, 0);
      expect(service.timeDisplay, '19:00');
    });

    test('bildirim açılıp kapatılabilir', () async {
      final service = await NotificationService.load();
      await service.setEnabled(true);
      expect(service.enabled, true);
      await service.setEnabled(false);
      expect(service.enabled, false);
    });

    test('bildirim saati değiştirilebilir', () async {
      final service = await NotificationService.load();
      await service.setTime(8, 30);
      expect(service.hour, 8);
      expect(service.minute, 30);
      expect(service.timeDisplay, '08:30');
    });

    test('singleton örneği korunur', () async {
      final service1 = await NotificationService.load();
      final service2 = await NotificationService.load();
      expect(identical(service1, service2), true);
    });

    group('nextFireTime', () {
      test('hedef saat bugün geçmemişse bugünü döner', () async {
        final service = await NotificationService.load();
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 10, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 21, 19, 0));
      });

      test('hedef saat bugün geçmişse yarını döner', () async {
        final service = await NotificationService.load();
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 20, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 22, 19, 0));
      });

      test('hedef saate tam denk gelirse yarını döner', () async {
        final service = await NotificationService.load();
        await service.setTime(19, 0);
        final from = DateTime(2026, 6, 21, 19, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 22, 19, 0));
      });

      test('dakikalı hedef saat doğru hesaplanır', () async {
        final service = await NotificationService.load();
        await service.setTime(8, 30);
        final from = DateTime(2026, 6, 21, 7, 0);
        final next = service.nextFireTime(from: from);
        expect(next, DateTime(2026, 6, 21, 8, 30));
      });
    });
  });
}
