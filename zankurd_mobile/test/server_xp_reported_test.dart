import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Kazanılan XP'nin SUNUCUYA da bildirildiğinin bekçisi.
///
/// ## Kusur
///
/// XP iki yerde yaşıyordu ve yalnız biri gerçekti. Cihazdaki `XPStore`
/// seviyeyi ve ilerleme çubuğunu besliyordu; `profiles.xp` ise sıralamanın,
/// toplam puanın ve lig rozetinin kaynağıydı.
///
/// İkincisine hiçbir zaman yazılmadı. `award_xp_delta` RPC'si 2026-07-25'te
/// yazıldı, İKİ TEST onun SQL dosyasında var olduğunu doğruladı — ve hiçbir
/// istemci kodu onu çağırmadı. Testler dosyayı okuyordu, davranışı değil.
///
/// Ölçüldü (2026-08-12, üretim yedeğinin yerel klonu): 21 profilin
/// hiçbirinde `xp > 0` yok, en yüksek değer 0. Yani `get_leaderboard`ın
/// `total_score`u herkes için sıfırdı, profil ekranında «Sıralama» ve
/// «Toplam Puan» her oyuncuda kalıcı olarak «—» görünüyordu ve lig rozeti
/// hiç açılmıyordu. Sıralama özelliğinin verisi yoktu.
///
/// Profildeki tirelerin "sahte sıra göstermemek için bilerek gizli" olduğu
/// söylenmişti; gizleme gerçekten kasıtlıydı ama gizlenen değer HİÇBİR
/// ZAMAN dolmayacaktı — kapı doğru, arkasında su yoktu.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );

  testWidgets('tur bitince sunucuya XP bildiriliyor', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 800,
          correctCount: 8,
          wrongCount: 2,
          totalQuestions: 10,
          bestStreak: 5,
          coinsAwarded: 0,
          answerRecords: const [
            AnswerRecord(
              id: 'q1',
              category: 'Ziman',
              prompt: 'Ev gotin çi wateyê dide?',
              answers: ['A', 'B', 'C', 'D'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: 'Rast bersiv A ye.',
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      repository.awardedXpTotal,
      greaterThan(0),
      reason:
          'Tur bitti ve sunucuya hiç XP bildirilmedi. `profiles.xp` boş '
          'kalırsa sıralama, toplam puan ve lig rozeti hiçbir oyuncuda '
          'çalışmaz.',
    );
  });

  test('sunucu tarafı XP kapısı hâlâ tek yazım yolu', () {
    // Bu bekçinin dayanağı, yazımın YALNIZ RPC üzerinden olmasıdır: göç
    // istemcinin `profiles` satırına doğrudan yazmasını bir tetikleyiciyle
    // engelliyor. O kapı kalkarsa istemci XP'yi kendi belirler ve sunucu
    // yetkisi biter.
    final sql = File(
      'supabase/2026-07-25_xp_server_authority.sql',
    ).readAsStringSync();
    expect(sql, contains('create or replace function public.award_xp_delta'));
    expect(
      sql,
      contains('profiles_client_write_guard'),
      reason: 'İstemci yazımını durduran tetikleyici kaldırılmış.',
    );
  });
}
