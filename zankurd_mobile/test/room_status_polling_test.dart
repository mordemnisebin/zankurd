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
      contains(
        'if (status == RoomStatus.active &&\n'
        '          !quizOpened &&\n'
        '          !_questionLoadExhausted) {',
      ),
    );
    expect(screenCode, contains('_navigateToQuiz()'));
  });

  // 2026-08-14 denetimi: soru yükleme sunucu tarafında sürekli başarısız
  // olursa (bkz. `test/room_question_load_retry_cap_test.dart`), bu koşul
  // ikinci bir kilit olmadan sonsuz döngüye izin verirdi — poll her 3
  // saniyede aktif durumu görüp `_navigateToQuiz`ı tekrar tetiklerdi.
  // `_questionLoadExhausted` bayrağı olmadan bu satır eksik kalır.
  test('active status re-check is gated by the question load retry cap', () {
    expect(screenCode, contains('bool _questionLoadExhausted = false;'));
  });
}
