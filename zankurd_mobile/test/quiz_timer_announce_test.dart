import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-10-25 (Opus 5.5 karar 5, "ilk sıra: duyuru"): süre sayacı ekran
/// okuyucuya süre dolduğunda ve son 5 saniyede duyuru yapar. Etiket her
/// saniye değiştiği için sürekli değil, yalnız bu iki an duyurulur.
void main() {
  testWidgets('süre uyarısı ve süre dolumu ekran okuyucuya duyurulur', (
    tester,
  ) async {
    // Öğretici (coach-mark) açıksa sayaç ertelenir; bu test sayacı görmek
    // istediği için öğreticiyi görülmüş sayar.
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') {
          final data = map['data'] as Map<dynamic, dynamic>;
          announced.add(data['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );

    final repository = MockZanKurdRepository();
    final room = repository.createRoom();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: repository.questions.take(1).toList(),
            enableTimer: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // Gerçek akış gibi bir saniyelik adımlarla ilerlet: 5 saniye eşiği
    // ancak böyle yakalanır (tek büyük adımda ara değerler atlanır).
    for (var i = 0; i < room.secondsPerQuestion + 2; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();

    expect(
      announced,
      contains('5 saniye kaldı'),
      reason: 'son 5 saniye uyarısı duyurulmalı',
    );
    expect(
      announced,
      contains('Süre doldu'),
      reason: 'süre dolunca duyuru yapılmalı',
    );
  });
}
