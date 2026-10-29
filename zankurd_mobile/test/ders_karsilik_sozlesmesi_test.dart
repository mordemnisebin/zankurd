import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/lesson_vocab_tiles.dart';

import 'support/widget_test_helpers.dart';

/// Ders slaydı Türkçe karşılığının VERİ SÖZLEŞMESİ (kapışma U20, Astra
/// 6b1a66c6 incelemesi, 2026-10-29).
///
/// Karşılık her Kurmancî açıklama cümlesinin hemen altında gösterilir; eşleme
/// `content_tr`nin boş satırla ayrılmış paragraflarının sırasına dayanır.
/// Paragraf sayısı Kurmancî açıklama blok sayısına eşit değilse ekran güvenlik
/// ağına düşer (tamamı ilk bloğun altında) — eşleme sessizce bozulur. Bu
/// bekçi bütün ders verisini tarar: uyuşmazlık 0 olmalı.
///
/// Sessiz kalırdı çünkü metin her iki durumda da ekranda; yalnız YERİ yanlış.
void main() {
  test(
    'paketli ders verisinde paragraf sayısı = açıklama blok sayısı',
    () async {
      final repo = freshMockRepository();
      const categories = [
        'everyday',
        'grammar',
        'culture',
        'food',
        'animals',
        'emotions',
        'time',
        'alphabet',
        'greetings',
        'family',
        'intro',
        'numbers',
        'body',
      ];
      var withTr = 0;
      final mismatches = <String>[];
      for (final c in categories) {
        for (final lesson in await repo.loadLessonsByCategory(c)) {
          for (final s in await repo.loadLessonSlides(lesson.id)) {
            final tr = s.contentTr;
            if (tr == null || tr.trim().isEmpty) continue;
            withTr++;
            final k = LessonContentBlocks.explanationBlockCount(s.contentKu);
            final t = LessonContentBlocks.translationParagraphs(tr).length;
            if (k != t) mismatches.add('${s.id}: KU $k blok, TR $t paragraf');
          }
        }
      }
      expect(withTr, greaterThan(100), reason: 'tarama boşa dönmesin');
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    },
  );

  test('sunucu verisi: düzeltme göçü iki slaytı sözleşmeye getirir', () {
    final sql = File(
      'supabase/2026-10-29_ders_karsilik_paragraf.sql',
    ).readAsStringSync();
    // Göçteki yeni değerler (E'' dizgisi; \n gerçek satır sonu).
    final values = RegExp(
      r"set content_tr = E'((?:[^']|'')*)'",
    ).allMatches(sql).map((m) => m.group(1)!.replaceAll(r'\n', '\n')).toList();
    expect(values, hasLength(2));
    // Kurmancî metinler paketli veriyle aynı (alfabe/1, leker/1).
    const alfabeKu =
        'Alfabeya Kurmancî (Hawar) 31 tîp e:\n\n'
        'A B C Ç D E Ê F G H I Î J K L M N O P Q R S Ş T U Û V W X Y Z\n\n'
        'Heşt tîp dengdêr in, bîst û sê tîp dengdar in.\n\n• Elîfbê: Alfabe';
    const lekerKu =
        'Lêker çi ye?\n\nDi kurmancî de lêker di dawiya hevokê de ye.\n\n'
        '• ez nan dixwim: ben ekmek yiyorum\n\nHatin cuda ye, di- naxe:\n\n'
        '• ew tên: onlar geliyorlar\n\nForma neyînî bi na- ye:\n\n'
        '• ez naçim: ben gitmiyorum';
    expect(
      LessonContentBlocks.translationParagraphs(values[0]).length,
      LessonContentBlocks.explanationBlockCount(alfabeKu),
    );
    expect(
      LessonContentBlocks.translationParagraphs(values[1]).length,
      LessonContentBlocks.explanationBlockCount(lekerKu),
    );
    // Metin değişmez: boş satırlar çıkarılınca eski değerle aynı.
    final olds = RegExp(
      r"and ls\.content_tr = '((?:[^']|'')*)';",
    ).allMatches(sql).map((m) => m.group(1)!).toList();
    expect(olds, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(values[i].replaceAll('\n\n', ' '), olds[i]);
    }
  });
}
