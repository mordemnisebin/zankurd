import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'support/widget_test_helpers.dart';

/// Çevrimiçi oda maçında kaydedilen favori, doğru cevabı hiç taşımaz.
///
/// ## Kusur
///
/// `favorite_questions.question_id` üretimde `uuid not null` idi; paketli
/// (yerel) banka soruları `curated_movement_0001` gibi serbest metin
/// kimlik taşıyor. Sonuç: tek kişilik turların TAMAMINDA (Günün Dersi,
/// seviye, kategori, günlük soru — hepsi paketli bankadan gelir) yer imi
/// düğmesi sunucuda `22P02 invalid input syntax for type uuid` ile
/// reddediliyor, ikon geri boşalıyor, "Soru kaydedilemedi" çıkıyordu.
///
/// Ayrı bir kusur: gerçek oda maçında (sorular `get_room_questions` ile
/// geldiği için kimlikler gerçek uuid) kaydedilen bir favori sunucuda
/// duruyordu ama `loadFavoriteQuestions` okuma yolu yalnız paketli
/// bankada arıyordu — kayıt hiçbir zaman geri gelmiyordu.
///
/// 2026-08-14 düzeltmesi: `question_id` sütunu `text`e çevrildi (yazma
/// çalışır), `loadFavoriteQuestions` paketli bankada bulamadığı kimlikleri
/// `quiz_public_questions`ten çözer (okuma çalışır). Ama çözülen satır
/// `correct_option` TAŞIMAZ (hile önlemi — bkz. `_roomQuestionFromRow`),
/// yani bu sorular YEREL olarak yeniden puanlanamaz. Bu bekçi, ekranın bu
/// soruları oynatılabilir gibi göstermediğini — listelediğini ama "oyna"
/// eylemini kapattığını — ölçer.
void main() {
  test('migration: question_id sütunları text\'e çevrilir, FK düşer', () {
    final sql = File(
      'supabase/2026-08-14_local_bank_question_ids.sql',
    ).readAsStringSync();
    for (final table in ['favorite_questions', 'question_reports']) {
      expect(
        sql,
        contains('alter table public.$table\n  drop constraint'),
        reason: '$table üzerindeki questions FK\'si düşürülmeli',
      );
      expect(
        sql,
        contains(
          'alter table public.$table\n  alter column question_id type text',
        ),
        reason: '$table.question_id text olmalı',
      );
    }
  });

  test('QuizQuestion.hasHiddenAnswer boş cevabı işaretler', () {
    const hidden = QuizQuestion(
      id: 'x',
      category: 'Ziman',
      prompt: 'Soru?',
      answers: ['A', 'B'],
      correctAnswer: '',
      explanation: '',
    );
    const visible = QuizQuestion(
      id: 'y',
      category: 'Ziman',
      prompt: 'Soru?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    );
    expect(hidden.hasHiddenAnswer, isTrue);
    expect(visible.hasHiddenAnswer, isFalse);
  });

  group('FavoriteQuestionsScreen', () {
    const hiddenQuestion = QuizQuestion(
      id: 'server-only',
      category: 'Ziman',
      prompt: 'Sunucu sorusu?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: '',
      explanation: '',
    );
    const playableQuestion = QuizQuestion(
      id: 'curated_movement_0001',
      category: 'Ziman',
      prompt: 'Yerel soru?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: '',
    );

    Widget pumpWith(List<QuizQuestion> favorites) {
      final repository = _FavoritesRepository(favorites);
      return testShell(child: FavoriteQuestionsScreen(repository: repository));
    }

    testWidgets('cevabı gizli favori dokununca oynatmıyor, ipucu gösteriyor', (
      tester,
    ) async {
      await tester.pumpWidget(pumpWith([hiddenQuestion]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-answer-hidden-hint')),
        findsOneWidget,
      );
      // Tek favori de oynatılamaz olduğu için "Tümünü Oyna" hiç çizilmez.
      expect(find.text('Kaydedilen Soruları Oyna'), findsNothing);

      await tester.tap(find.text('Sunucu sorusu?'));
      await tester.pumpAndSettle();

      // Dokunma hiçbir yere gitmedi: hâlâ favoriler ekranındayız.
      expect(find.byType(FavoriteQuestionsScreen), findsOneWidget);
    });

    testWidgets(
      'oynatılabilir favori varken "Tümünü Oyna" yalnız onları kullanır',
      (tester) async {
        await tester.pumpWidget(pumpWith([hiddenQuestion, playableQuestion]));
        await tester.pumpAndSettle();

        expect(find.text('Kaydedilen Soruları Oyna'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('favorite-answer-hidden-hint')),
          findsOneWidget,
        );
      },
    );
  });
}

class _FavoritesRepository extends MockZanKurdRepository {
  _FavoritesRepository(this.favorites);

  final List<QuizQuestion> favorites;

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async => favorites;
}
