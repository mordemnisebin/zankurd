import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

/// 2026-07-25 denetim bulgusu: `profiles.xp` istemciden MUTLAK değerle
/// yazılıyordu. RLS kendi satırına yazmaya izin verdiği için JWT'si olan
/// biri REST çağrısını döngüye alıp her istekte +2000 XP kazanabiliyordu;
/// aynı clamp, çevrimdışı 2000'den fazla XP biriktiren dürüst kullanıcının
/// farkını da sessizce siliyordu.
void main() {
  test('repository delta tabanlı XP yazımı sunar', () async {
    final repo = MockZanKurdRepository();
    expect(await repo.awardProfileXPDelta(120), 120);
    expect(await repo.awardProfileXPDelta(80), 200);
    // Negatif/sıfır delta bakiyeyi düşürmez.
    expect(await repo.awardProfileXPDelta(0), 200);
    expect(await repo.awardProfileXPDelta(-500), 200);
  });

  test('XP yazan ekranlar mutlak değer değil delta gönderir', () {
    final result = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final quizUi = File(
      'lib/src/screens/quiz/quiz_screen_ui.dart',
    ).readAsStringSync();

    for (final source in [result, quizUi]) {
      expect(source, contains('awardProfileXPDelta'));
      expect(
        source,
        isNot(contains('updateProfileXP(')),
        reason: 'Mutlak XP yazımı geri geldi',
      );
      expect(source, contains('delta:'));
    }
  });

  test('migration istemci XP yazımını tamamen kapatır', () {
    final sql = File(
      'supabase/2026-07-25_xp_server_authority.sql',
    ).readAsStringSync();

    // Trigger artık +2000 clamp'e izin vermiyor, kolonu tamamen dondurmalı.
    expect(sql, contains('new.xp := old.xp'));
    expect(sql, contains('create or replace function public.award_xp_delta'));
    expect(sql, contains('security definer'));
    expect(sql, contains('grant execute on function public.award_xp_delta'));
    expect(
      sql,
      contains('revoke all on function public.award_xp_delta(integer)'),
    );
    // Gün başına tavan olmadan RPC de döngüyle sömürülebilirdi.
    expect(sql, contains('xp_daily_total'));
  });
}
