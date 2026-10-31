import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/foreground_push_center.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';

void main() {
  tearDown(ForegroundPushCenter.resetForTest);

  test(
    'aynı kuyruk işi farklı FCM kimliğiyle yeniden gelirse bir kez yayınlanır',
    () async {
      final received = <ForegroundPush>[];
      final subscription = ForegroundPushCenter.events.listen(received.add);
      for (final messageId in ['first-send', 'retry-send']) {
        ForegroundPushCenter.emit(
          ForegroundPush(
            messageId: messageId,
            data: const {'kind': 'friend_request', 'job_id': 'same-job'},
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      await subscription.cancel();
    },
  );

  test('job_id olmayan aynı FCM iletisi bir kez yayınlanır', () async {
    final received = <ForegroundPush>[];
    final subscription = ForegroundPushCenter.events.listen(received.add);
    const push = ForegroundPush(messageId: 'fcm-id');
    ForegroundPushCenter.emit(push);
    ForegroundPushCenter.emit(push);
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    await subscription.cancel();
  });

  test('aynı türde ayrı işler ve kimliksiz iletiler bastırılmaz', () async {
    final received = <ForegroundPush>[];
    final subscription = ForegroundPushCenter.events.listen(received.add);
    for (final job in ['first', 'second', null, null]) {
      ForegroundPushCenter.emit(
        ForegroundPush(data: {'kind': 'friend_request', 'job_id': job}),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(4));
    await subscription.cancel();
  });

  test(
    'tekilleştirme belleği sınırlıdır; eski kimlikler serbest bırakılır',
    () async {
      final received = <ForegroundPush>[];
      final subscription = ForegroundPushCenter.events.listen(received.add);
      for (var id = 0; id < 257; id++) {
        ForegroundPushCenter.emit(ForegroundPush(messageId: 'id-$id'));
      }
      ForegroundPushCenter.emit(const ForegroundPush(messageId: 'id-0'));
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(258));
      await subscription.cancel();
    },
  );
}
