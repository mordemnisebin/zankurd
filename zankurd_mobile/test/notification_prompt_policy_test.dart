// Bildirim kartı iOS'un tek seferlik izin istemine giden kapıdır: erken ya da
// sık sorarsa oyuncu reddeder ve iOS bir daha sormaz. Kurallar sessizce
// gevşerse hiçbir şey kırılmaz, yalnız izin oranı düşer; bu yüzden bekçi.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/notification_prompt_policy.dart';

void main() {
  const rounds = 'zankurd.notifPrompt.rounds';
  const asked = 'zankurd.notifPrompt.asked';
  const laterAt = 'zankurd.notifPrompt.laterAt';
  const granted = 'zankurd.notifPrompt.granted';

  Future<NotificationPromptPolicy> policyWith(Map<String, Object> v) async {
    SharedPreferences.setMockInitialValues(v);
    return NotificationPromptPolicy.load();
  }

  int daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).millisecondsSinceEpoch;

  test('ilk iki tur bitmeden sormaz', () async {
    final p = await policyWith({});
    await p.recordRoundCompleted();
    expect(await p.shouldShow(), isFalse);
    await p.recordRoundCompleted();
    expect(await p.shouldShow(), isTrue);
  });

  test('"Şimdi değil"den sonra yedi gün susar', () async {
    var p = await policyWith({rounds: 5});
    await p.recordLater();
    expect(await p.shouldShow(), isFalse);

    p = await policyWith({rounds: 5, asked: 1, laterAt: daysAgo(6)});
    expect(await p.shouldShow(), isFalse);
    p = await policyWith({rounds: 5, asked: 1, laterAt: daysAgo(8)});
    expect(await p.shouldShow(), isTrue);
  });

  test('en fazla iki kez sorar', () async {
    final p = await policyWith({rounds: 9, asked: 2, laterAt: daysAgo(30)});
    expect(await p.shouldShow(), isFalse);
  });

  test('izin verildiyse bir daha sormaz', () async {
    final p = await policyWith({rounds: 9});
    await p.recordGranted();
    expect(await p.shouldShow(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(granted), isTrue);
  });
}
