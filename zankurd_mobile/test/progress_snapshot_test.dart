/// İlerleme anlık görüntüsü ([ProgressSnapshot]) birleştirme kuralları.
///
/// Kusur: kayıtlı kullanıcı seri/rozet/seviye/tekrar geçmişini çıkışta,
/// telefon değişiminde ve yeniden kurulumda kaybediyordu; hepsi yalnız
/// cihazdaydı. Anlık görüntü bunu hesaba taşır; yanlış birleştirme ise
/// sessiz veri kaybı olurdu (eski cihaz yeniyi ezer, rozet geri alınır).
///
/// Her kural burada tek tek ve iki yönde (simetri) sabitlenir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';

ProgressSnapshot _s({
  int xp = 0,
  SnapshotStreak streak = const SnapshotStreak(),
  Set<String> badges = const {},
  SnapshotAchievements achievements = const SnapshotAchievements(),
  Set<String> level = const {},
  Map<String, SnapshotMastery> mastery = const {},
  SnapshotMistakes mistakes = const SnapshotMistakes(),
  String? placement,
  bool skipped = false,
  Map<String, String> story = const {},
  String? goal,
}) => ProgressSnapshot(
  xp: xp,
  streak: streak,
  badges: badges,
  achievements: achievements,
  levelPlayed: level,
  mastery: mastery,
  mistakes: mistakes,
  placementLevel: placement,
  placementSkipped: skipped,
  story: story,
  learningGoal: goal,
);

void main() {
  group('sayaçlar: en yüksek', () {
    test('xp, başarı sayacı, ustalık sayaçları', () {
      final a = _s(
        xp: 500,
        achievements: const SnapshotAchievements(answered: 40),
        mastery: {
          'Ziman': const SnapshotMastery(
            correct: 10,
            answered: 20,
            evidence: 9,
          ),
        },
      );
      final b = _s(
        xp: 300,
        achievements: const SnapshotAchievements(answered: 90),
        mastery: {
          'Ziman': const SnapshotMastery(
            correct: 15,
            answered: 18,
            evidence: 4,
          ),
          'Çand': const SnapshotMastery(correct: 1, answered: 1, evidence: 1),
        },
      );
      for (final merged in [
        ProgressSnapshot.merge(a, b),
        ProgressSnapshot.merge(b, a),
      ]) {
        expect(merged.xp, 500);
        expect(merged.achievements.answered, 90);
        expect(merged.mastery['Ziman']!.correct, 15);
        expect(merged.mastery['Ziman']!.answered, 20);
        expect(merged.mastery['Ziman']!.evidence, 9);
        expect(merged.mastery['Çand']!.correct, 1);
      }
    });
  });

  group('birleşim', () {
    test('rozetler, başarılar, kategoriler, oynanan düğümler', () {
      final a = _s(
        badges: {'perfect_game'},
        level: {'Ziman|-|1'},
        achievements: const SnapshotAchievements(
          unlocked: {'first_game'},
          categories: {'Ziman'},
        ),
      );
      final b = _s(
        badges: {'speed_demon', 'perfect_game'},
        level: {'Ziman|-|2'},
        achievements: const SnapshotAchievements(
          unlocked: {'streak_3'},
          categories: {'Çand'},
        ),
      );
      for (final m in [
        ProgressSnapshot.merge(a, b),
        ProgressSnapshot.merge(b, a),
      ]) {
        expect(m.badges, {'perfect_game', 'speed_demon'});
        expect(m.levelPlayed, {'Ziman|-|1', 'Ziman|-|2'});
        expect(m.achievements.unlocked, {'first_game', 'streak_3'});
        expect(m.achievements.categories, {'Ziman', 'Çand'});
      }
    });
  });

  group('seri: son oynama günü yeni olan kayıt', () {
    const older = SnapshotStreak(
      current: 12,
      best: 12,
      lastDay: '2026-10-10',
      freeze: 1,
    );
    const newer = SnapshotStreak(
      current: 3,
      best: 5,
      lastDay: '2026-10-14',
      freeze: 0,
    );

    test('daha yeni günlü kayıt, daha uzun ama eski seriyi yener', () {
      for (final m in [
        SnapshotStreak.merge(older, newer),
        SnapshotStreak.merge(newer, older),
      ]) {
        expect(m.current, 3);
        expect(m.lastDay, '2026-10-14');
        // En iyi seri ikisinin en yükseği; dondurma jetonu en yüksek.
        expect(m.best, 12);
        expect(m.freeze, 1);
      }
    });

    test('aynı gün: büyük seri kazanır', () {
      const a = SnapshotStreak(current: 4, best: 4, lastDay: '2026-10-14');
      const b = SnapshotStreak(current: 6, best: 6, lastDay: '2026-10-14');
      expect(SnapshotStreak.merge(a, b).current, 6);
      expect(SnapshotStreak.merge(b, a).current, 6);
    });

    test('hiç oynamamış taraf (lastDay null) her zaman kaybeder', () {
      const empty = SnapshotStreak();
      expect(SnapshotStreak.merge(empty, newer).current, 3);
      expect(SnapshotStreak.merge(newer, empty).lastDay, '2026-10-14');
      expect(SnapshotStreak.merge(empty, empty).isEmpty, isTrue);
    });

    test(
      'takvim geçmişi (playedDays, frozenDays, repairMonth, firstSeen) birleşir ve playedDays baskındır',
      () {
        const a = SnapshotStreak(
          current: 2,
          best: 5,
          lastDay: '2026-10-14',
          playedDays: {'2026-10-13', '2026-10-14'},
          frozenDays: {'2026-10-12'},
          repairMonth: '2026-09',
          firstSeen: '2026-10-10',
        );
        const b = SnapshotStreak(
          current: 3,
          best: 4,
          lastDay: '2026-10-15',
          playedDays: {'2026-10-12', '2026-10-15'},
          frozenDays: {'2026-10-11', '2026-10-14'},
          repairMonth: '2026-10',
          firstSeen: '2026-10-08',
        );
        for (final m in [
          SnapshotStreak.merge(a, b),
          SnapshotStreak.merge(b, a),
        ]) {
          expect(m.playedDays, {
            '2026-10-12',
            '2026-10-13',
            '2026-10-14',
            '2026-10-15',
          });
          // 2026-10-12 ve 2026-10-14 oynandığı için frozenDays'ten düşer.
          expect(m.frozenDays, {'2026-10-11'});
          expect(m.repairMonth, '2026-10');
          expect(m.firstSeen, '2026-10-08');
        }
      },
    );

    test('takvim geçmişi 400 günü aşarsa en yeni 400 gün korunur', () {
      final days = {
        for (var i = 0; i < 450; i++)
          DateTime(
            2025,
            1,
            1,
          ).add(Duration(days: i)).toIso8601String().substring(0, 10),
      };
      final merged = SnapshotStreak.merge(
        SnapshotStreak(playedDays: days),
        const SnapshotStreak(),
      );
      expect(merged.playedDays.length, SnapshotStreak.maxHistoryDays);
      final sorted = days.toList()..sort();
      expect(merged.playedDays.contains(sorted.first), isFalse);
      expect(merged.playedDays.contains(sorted.last), isTrue);
      expect(
        merged.firstSeen,
        sorted[sorted.length - SnapshotStreak.maxHistoryDays],
      );
    });

    test(
      'geçersiz takvim tarihleri (2026-99-99, 2026-02-31, 2026-99) dışlanır ve eski oynanmış gün kırpılsa da donmuş güne dönüşmez',
      () {
        const oldPlayed = '2024-01-01';
        final recentPlayed = {
          for (var i = 0; i < 400; i++)
            DateTime.utc(
              2025,
              1,
              1,
            ).add(Duration(days: i)).toIso8601String().substring(0, 10),
        };
        final merged = SnapshotStreak.merge(
          SnapshotStreak(
            playedDays: {
              oldPlayed,
              ...recentPlayed,
              '2026-99-99',
              '2026-02-31',
            },
            repairMonth: '2026-99',
          ),
          const SnapshotStreak(
            frozenDays: {oldPlayed, '2026-13-01'},
            repairMonth: '2026-10',
          ),
        );
        expect(merged.playedDays.contains(oldPlayed), isFalse);
        expect(merged.frozenDays.contains(oldPlayed), isFalse);
        expect(merged.playedDays.contains('2026-99-99'), isFalse);
        expect(merged.playedDays.contains('2026-02-31'), isFalse);
        expect(merged.repairMonth, '2026-10');
      },
    );

    test('günlük sınav sayacı en yeni güne ait kayıttan gelir', () {
      const a = SnapshotAchievements(dailyQuiz: 9, dailyQuizDay: '2026-10-01');
      const b = SnapshotAchievements(dailyQuiz: 2, dailyQuizDay: '2026-10-14');
      expect(SnapshotAchievements.merge(a, b).dailyQuiz, 2);
      expect(SnapshotAchievements.merge(b, a).dailyQuiz, 2);
    });
  });

  group('tekrar kuyruğu', () {
    Map<String, dynamic> meta(int due, {int reps = 0, String? cat}) => {
      'nextReview': due,
      'intervalDays': 1,
      'repetitions': reps,
      'easeFactor': 2.5,
      // ignore: use_null_aware_elements
      if (cat != null) 'category': cat,
    };

    test('kimlik birleşimi; aynı kimlikte daha erken vade kazanır', () {
      final a = SnapshotMistakes(
        ids: {'q1', 'q2'},
        meta: {'q1': meta(2000), 'q2': meta(500)},
      );
      final b = SnapshotMistakes(
        ids: {'q2', 'q3'},
        meta: {'q2': meta(900), 'q3': meta(100)},
      );
      for (final m in [
        SnapshotMistakes.merge(a, b),
        SnapshotMistakes.merge(b, a),
      ]) {
        expect(m.ids, {'q1', 'q2', 'q3'});
        expect(m.meta['q1']!['nextReview'], 2000);
        expect(m.meta['q2']!['nextReview'], 500);
        expect(m.meta['q3']!['nextReview'], 100);
      }
    });

    test('vade eşitse daha çok tekrar yapılmış kayıt kazanır (simetrik)', () {
      final a = SnapshotMistakes(ids: {'q'}, meta: {'q': meta(1000, reps: 2)});
      final b = SnapshotMistakes(ids: {'q'}, meta: {'q': meta(1000, reps: 5)});
      expect(SnapshotMistakes.merge(a, b).meta['q']!['repetitions'], 5);
      expect(SnapshotMistakes.merge(b, a).meta['q']!['repetitions'], 5);
    });

    // 2026-10-25: ustalaşılıp kuyruktan çıkan soru, sunucudaki eski anlık
    // görüntüyle birleşince ("erken vade kazanır") geri geliyordu.
    test('ustalaşılan soru eski anlık görüntüyle geri gelmez (simetrik)', () {
      final local = SnapshotMistakes(
        meta: {
          'q': {...meta(9000, reps: 2), 'missCount': 1, 'graduated': true},
        },
      );
      final server = SnapshotMistakes(
        ids: {'q'},
        meta: {
          'q': {...meta(1000), 'missCount': 1},
        },
      );
      for (final m in [
        SnapshotMistakes.merge(local, server),
        SnapshotMistakes.merge(server, local),
      ]) {
        expect(m.ids, isEmpty);
        expect(m.meta['q']!['graduated'], isTrue);
      }
    });

    test('ustalaşmadan sonraki yeni yanlış kaybolmaz (simetrik)', () {
      final graduated = SnapshotMistakes(
        meta: {
          'q': {...meta(9000, reps: 2), 'missCount': 1, 'graduated': true},
        },
      );
      final missedAgain = SnapshotMistakes(
        ids: {'q'},
        meta: {
          'q': {...meta(2000), 'missCount': 2},
        },
      );
      for (final m in [
        SnapshotMistakes.merge(graduated, missedAgain),
        SnapshotMistakes.merge(missedAgain, graduated),
      ]) {
        expect(m.ids, {'q'});
        expect(m.meta['q']!['missCount'], 2);
      }
    });

    test('günlük performans günü gün en yüksek', () {
      const a = SnapshotMistakes(
        history: {
          '2026-10-14': {'correct': 5, 'wrong': 1},
        },
      );
      const b = SnapshotMistakes(
        history: {
          '2026-10-14': {'correct': 3, 'wrong': 4},
          '2026-10-15': {'correct': 1, 'wrong': 0},
        },
      );
      final m = SnapshotMistakes.merge(a, b);
      expect(m.history['2026-10-14'], {'correct': 5, 'wrong': 4});
      expect(m.history['2026-10-15'], {'correct': 1, 'wrong': 0});
    });
  });

  group('seviye sınavı, hikâye, hedef', () {
    test('daha yüksek seviye; seviye yoksa geçildi bayrağı VEYA', () {
      expect(
        ProgressSnapshot.merge(
          _s(placement: 'destpek'),
          _s(placement: 'pesketi'),
        ).placementLevel,
        'pesketi',
      );
      expect(
        ProgressSnapshot.merge(
          _s(placement: 'pesketi'),
          _s(placement: 'destpek'),
        ).placementLevel,
        'pesketi',
      );
      expect(
        ProgressSnapshot.merge(_s(skipped: true), _s()).placementSkipped,
        isTrue,
      );
      // Seviye belirlendiyse "geçildi" anlamsızdır.
      final withLevel = ProgressSnapshot.merge(
        _s(skipped: true),
        _s(placement: 'navin'),
      );
      expect(withLevel.placementLevel, 'navin');
      expect(withLevel.placementSkipped, isFalse);
    });

    test('hikâye ve hedef: yerel varsa yerel, yoksa uzak', () {
      final local = _s(story: {'s1': 'n3'}, goal: 'daily5');
      final remote = _s(story: {'s1': 'n1', 's2': 'n9'}, goal: 'daily10');
      final m = ProgressSnapshot.merge(local, remote);
      expect(m.story, {'s1': 'n3', 's2': 'n9'});
      expect(m.learningGoal, 'daily5');
      expect(ProgressSnapshot.merge(_s(), remote).learningGoal, 'daily10');
    });
  });

  group('JSON', () {
    test('gidiş-dönüş aynıdır ve kararlıdır (sıralı anahtarlar)', () {
      final snapshot = _s(
        xp: 12,
        streak: const SnapshotStreak(
          current: 2,
          best: 4,
          lastDay: '2026-10-14',
          freeze: 1,
        ),
        badges: {'b', 'a'},
        mastery: {'Ziman': const SnapshotMastery(correct: 1)},
        mistakes: const SnapshotMistakes(
          ids: {'q2', 'q1'},
          meta: {
            'q1': {'nextReview': 5, 'category': 'Ziman'},
          },
          history: {
            '2026-10-14': {'correct': 1, 'wrong': 0},
          },
        ),
        placement: 'navin',
        story: {'s': 'n'},
        goal: 'daily5',
      );
      final parsed = ProgressSnapshot.tryParse(snapshot.toJson());
      expect(parsed, snapshot);
      expect(parsed!.encode(), snapshot.encode());
      expect(snapshot.toJson()['v'], ProgressSnapshot.currentVersion);
      expect(snapshot.toJson()['badges'] as List, ['a', 'b']);
    });

    test('daha yeni sürüm, bozuk ve boş girdi null döner (yerel korunur)', () {
      expect(
        ProgressSnapshot.tryParse({'v': ProgressSnapshot.currentVersion + 1}),
        isNull,
      );
      expect(ProgressSnapshot.tryParse({'xp': 5}), isNull);
      expect(ProgressSnapshot.tryParse('x'), isNull);
      expect(ProgressSnapshot.tryParse(null), isNull);
    });

    test('bilinmeyen alanlar ve negatif sayılar zararsızdır', () {
      final parsed = ProgressSnapshot.tryParse({
        'v': 1,
        'xp': -5,
        'future': {'x': 1},
        'badges': ['a', 3, null, ''],
      });
      expect(parsed!.xp, 0);
      expect(parsed.badges, {'a'});
    });

    test('boş anlık görüntü isEmpty', () {
      expect(const ProgressSnapshot().isEmpty, isTrue);
      expect(_s(xp: 1).isEmpty, isFalse);
    });
  });
}
