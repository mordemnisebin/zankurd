/// Soru puanlama (2026-10-28) — bekçi.
///
/// ## Neyi korur
///
/// Cevap incelemesindeki başparmak yukarı/aşağı: (1) dokunuş depoya +1/-1
/// olarak gider ve seçim hemen görünür; (2) başka başparmak seçimi değiştirir
/// (yeni oy eskisini ezer); (3) sunucu hatasında seçim ESKİ haline döner;
/// (4) oturumsuz/çevrimdışı depoda ya da depo verilmediğinde satır hiç
/// çizilmez; (5) SQL RPC'si SECURITY DEFINER, sabit `search_path` ile yazılır
/// ve anon'a kapalıdır.
///
/// ## Niçin sessiz kalırdı
///
/// İyimser arayüz hatayı gizleyebilir: RPC düşse de başparmak dolu kalır,
/// sahip "puanlar geliyor" sanır ama tablo boştur. Hata geri alma olmadan
/// görünmez. SQL tarafında `security definer` + `search_path` unutulursa
/// çağrı çalışır, açık yalnız saldırıda ortaya çıkar.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/thumb_rating_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

class _FailingRepo extends MockZanKurdRepository {
  @override
  Future<void> rateQuestion(QuizQuestion question, int rating) async {
    throw StateError('rpc down');
  }
}

const _records = [
  AnswerRecord(
    id: 'ziman_x_0035',
    category: 'Ziman',
    prompt: 'Soru 1',
    answers: ['A', 'B'],
    correctAnswer: 'A',
    selectedAnswer: 'A',
    explanation: '',
  ),
];

Future<void> _open(WidgetTester tester, ZanKurdRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ReviewScreen(
          records: _records,
          room: repository.createRoom(),
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String key) {
  return tester
          .getSemantics(find.byKey(ValueKey(key)))
          .getSemanticsData()
          .flagsCollection
          .isSelected ==
      ui.Tristate.isTrue;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('beğenme +1 yollar ve seçili görünür', (tester) async {
    final repo = MockZanKurdRepository();
    await _open(tester, repo);

    expect(find.text('Bu soru nasıldı?'), findsOneWidget);
    expect(_selected(tester, 'rate-like'), isFalse);

    await tester.tap(find.byKey(const ValueKey('rate-like')));
    await tester.pumpAndSettle();

    expect(repo.ratedQuestions, [(id: 'ziman_x_0035', rating: 1)]);
    expect(_selected(tester, 'rate-like'), isTrue);
    expect(_selected(tester, 'rate-dislike'), isFalse);
    expect(find.text('Teşekkürler, puanın kaydedildi.'), findsOneWidget);
    expect(await QuestionRatingStore.read('ziman_x_0035'), 1);
  });

  testWidgets('beğenmeye geçmek -1 yollar', (tester) async {
    final repo = MockZanKurdRepository();
    await _open(tester, repo);

    await tester.tap(find.byKey(const ValueKey('rate-like')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rate-dislike')));
    await tester.pumpAndSettle();

    expect(repo.ratedQuestions.map((e) => e.rating), [1, -1]);
    expect(_selected(tester, 'rate-dislike'), isTrue);
    expect(_selected(tester, 'rate-like'), isFalse);
  });

  testWidgets('hata seçimi geri alır ve uyarır', (tester) async {
    await _open(tester, _FailingRepo());

    await tester.tap(find.byKey(const ValueKey('rate-like')));
    await tester.pumpAndSettle();

    expect(_selected(tester, 'rate-like'), isFalse);
    expect(find.text('Puan kaydedilemedi.'), findsOneWidget);
    expect(await QuestionRatingStore.read('ziman_x_0035'), isNull);
  });

  testWidgets('kayıtlı puan yeniden açılışta seçili gelir', (tester) async {
    await QuestionRatingStore.write('ziman_x_0035', -1);
    await _open(tester, MockZanKurdRepository());
    expect(_selected(tester, 'rate-dislike'), isTrue);
  });

  testWidgets('320 px / %200 yazıda taşmaz, dokunma hedefi >= 48', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('ku'),
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ReviewScreen(
            records: _records,
            room: repo.createRoom(),
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in ['rate-like', 'rate-dislike']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('çevrimdışı depoda puan satırı çizilmez', (tester) async {
    await _open(tester, OfflineZanKurdRepository());
    expect(find.byKey(const ValueKey('rate-like')), findsNothing);
  });

  test('göç RPC\'si security definer, sabit search_path, anon kapalı', () {
    final sql = File('supabase/2026-10-28_soru_puani.sql').readAsStringSync();
    expect(sql, contains('create or replace function public.rate_question('));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(sql, contains('auth.uid()'));
    expect(
      sql,
      contains('revoke all on function public.rate_question(text, smallint)'),
    );
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('check (rating in (-1, 1))'));
  });
}
