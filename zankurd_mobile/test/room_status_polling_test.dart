import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oda başlangıcı realtime olayına ulaşmadığında katılımcı da host'un
/// başlattığı oyuna girebilmeli. Oyuncu yoklaması tek başına bunu doğrulamaz;
/// oda durumunun da periyodik yedek okuması gerekir.
void main() {
  late String repositoryCode;
  late String screenCode;

  setUpAll(() {
    repositoryCode = File(
      'lib/src/data/zankurd_repository.dart',
    ).readAsStringSync();
    screenCode = File('lib/src/screens/room_screen.dart').readAsStringSync();
  });

  test('repository exposes one-shot room status loading', () {
    expect(repositoryCode, contains('Future<RoomStatus> loadRoomStatus'));
  });

  test('room polling checks active status and opens quiz for participants', () {
    expect(screenCode, contains('loadRoomStatus(room)'));
    expect(screenCode, contains('Timer? _statusPollTimer;'));
    expect(screenCode, contains('_startStatusPolling();'));
    expect(
      screenCode,
      contains('if (status == RoomStatus.active && !quizOpened)'),
    );
    expect(screenCode, contains('_navigateToQuiz()'));
  });
}
