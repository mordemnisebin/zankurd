import 'dart:math' as math;

import '../models/quiz_question.dart';
import 'mistake_store.dart';
import 'word_list_store.dart';

/// Bir "Tekrar" oturumunun en çok öğe sayısı (kelime + soru birlikte).
const int kTekrarSessionCap = 12;

/// Tekrar oturumunun başlık kategorisi: sorular tek konudansa o konu,
/// değilse Karışık (`mixed`). createRoom() varsayılanı ("Ziman") başlıkta
/// yanlış konu gösteriyordu.
String reviewRoomCategory(List<QuizQuestion> questions) {
  final categories = {for (final q in questions) q.category};
  return categories.length == 1 ? categories.single : 'mixed';
}

/// Tek "Tekrar" girişinin planı: bugün vadesi gelen kelimeler (Leitner) ve
/// yanlış defterindeki hazır sorular (iki oturumlu mezuniyet).
///
/// ## Niçin tek plan
///
/// Üç ayrı mekanizma vardı ("Kelimelerim" kartı, "Bugünkü tekrar" sorular
/// kartı, kart modları) ve kullanıcı hangisini kullanacağını ayırt
/// edemiyordu (2026-10-24 sahip kararı). Plan yalnız SAYAR ve SEÇER;
/// kutu/vade/mezuniyet kuralları hâlâ kendi depolarındadır
/// ([WordListStore.recordReview], [MistakeStore.markResolved]) ve burada
/// değiştirilmez.
class TekrarPlan {
  const TekrarPlan({
    required this.words,
    required this.questions,
    required this.dueWords,
    required this.dueQuestions,
  });

  /// Oturumun kelimeleri (en çok gecikenden başlar).
  final List<SavedWord> words;

  /// Oturumun soruları (en çok gecikenden başlar, oynanabilir olanlar).
  final List<QuizQuestion> questions;

  /// Vadesi gelmiş kelime sayısı (oturum kesilmeden önce).
  final int dueWords;

  /// Açılabilir hazır soru sayısı (oturum sınırı [kTekrarSessionCap] ile
  /// kesilmiş; kart neyi vaat ediyorsa oturum onu açar).
  final int dueQuestions;

  /// Kartın "bugün N" sayısı: iki kaynağın toplamı.
  int get dueTotal => dueWords + dueQuestions;

  /// Bu oturumda gerçekten sorulacak öğe sayısı.
  int get sessionTotal => words.length + questions.length;

  bool get isEmpty => sessionTotal == 0;

  /// [dueW] kelime ve [dueQ] soru için oturumun (kelime, soru) payı.
  ///
  /// Kural: toplam [cap]'i geçmez; her kaynak, öbürü yetmese bile en az
  /// yarısını (6) garanti eder; biri azsa boş payı öbürü alır. Kelime en
  /// çok [WordListStore.sessionCap]. Kelimeler soruların önündedir.
  static (int, int) allocate(
    int dueW,
    int dueQ, {
    int cap = kTekrarSessionCap,
  }) {
    var w = math.min(dueW, math.max(cap ~/ 2, cap - dueQ));
    w = math.min(w, WordListStore.sessionCap);
    final q = math.min(dueQ, cap - w);
    return (w, q);
  }

  /// Depolardan planı kurar. [playable] yalnız oynanabilir sorulardır
  /// (`repository.playableQuestions`): karantinadaki soru sayılmaz.
  static TekrarPlan build({
    required WordListStore wordStore,
    required MistakeStore mistakeStore,
    required List<QuizQuestion> playable,
    DateTime? now,
  }) {
    final byId = {for (final q in playable) q.id: q};
    final launchable = <QuizQuestion>[
      for (final id in mistakeStore.readyIdsMostOverdueFirst)
        if (byId[id] != null) byId[id]!,
    ].take(kTekrarSessionCap).toList();
    final dueWords = wordStore.dueWords(now: now);
    final (w, q) = allocate(dueWords.length, launchable.length);
    return TekrarPlan(
      words: dueWords.take(w).toList(growable: false),
      questions: launchable.take(q).toList(growable: false),
      dueWords: dueWords.length,
      dueQuestions: launchable.length,
    );
  }
}
