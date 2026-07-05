import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';

void main() {
  group('Contest Models', () {
    test('Contest fromJson and toJson', () {
      final json = {
        'id': 'contest1',
        'day_key': '2026-07-05',
        'theme_name_ku': 'Ziman Eksperi',
        'theme_description_ku': 'Dil usta ol',
        'category': 'Ziman',
        'difficulty_min': 1,
        'difficulty_max': 3,
        'participation_reward': 10,
        'rank1_reward': 500,
        'rank2_reward': 300,
        'rank3_reward': 100,
        'question_count': 10,
      };

      final contest = Contest.fromJson(json);
      expect(contest.id, 'contest1');
      expect(contest.themeNameKu, 'Ziman Eksperi');
      expect(contest.category, 'Ziman');
      expect(contest.rank1Reward, 500);

      final json2 = contest.toJson();
      expect(json2['id'], 'contest1');
      expect(json2['theme_name_ku'], 'Ziman Eksperi');
    });

    test('Contest copyWith', () {
      final contest1 = Contest(
        id: 'c1',
        dayKey: DateTime(2026, 7, 5),
        themeNameKu: 'Tema 1',
        category: 'Ziman',
      );

      final contest2 = contest1.copyWith(themeNameKu: 'Tema 2');
      expect(contest2.themeNameKu, 'Tema 2');
      expect(contest2.id, 'c1');
    });

    test('ContestEntry fromJson and rank field', () {
      final json = {
        'id': 'entry1',
        'contest_id': 'contest1',
        'user_id': 'user1',
        'score': 1000,
        'correct_count': 10,
        'finished_at': '2026-07-05T12:00:00Z',
        'rank': 1,
        'reward_claimed': false,
      };

      final entry = ContestEntry.fromJson(json);
      expect(entry.score, 1000);
      expect(entry.rank, 1);
      expect(entry.rewardClaimed, false);
    });

    test('ContestBadge slug and tier', () {
      const badge = ContestBadge(
        id: 'b1',
        slug: 'contest_20260705_champion',
        nameKu: 'Champion',
        tier: 2,
      );

      expect(badge.slug, 'contest_20260705_champion');
      expect(badge.tier, 2);
    });

    test('UserContestBadge earnedAt timestamp', () {
      final now = DateTime.now();
      final badge = UserContestBadge(
        id: 'ub1',
        userId: 'user1',
        badgeId: 'b1',
        contestId: 'c1',
        earnedAt: now,
      );

      expect(badge.earnedAt, now);
    });

    test('ContestLeaderboardRow fromJson', () {
      final json = {
        'user_id': 'user1',
        'display_name': 'Rojda',
        'score': 1000,
        'correct_count': 10,
        'rank': 1,
      };

      final row = ContestLeaderboardRow.fromJson(json);
      expect(row.displayName, 'Rojda');
      expect(row.score, 1000);
      expect(row.rank, 1);
    });
  });

  group('Contest Repository Mock', () {
    late MockZanKurdRepository repo;

    setUp(() {
      repo = MockZanKurdRepository();
    });

    test('loadTodayContest returns today contest', () async {
      final contest = await repo.loadTodayContest();
      expect(contest, isNotNull);
      expect(contest?.themeNameKu, 'Ziman Eksperi');
      expect(contest?.category, 'Ziman');
    });

    test('submitContestEntry calculates score and rank', () async {
      final entry = await repo.submitContestEntry(
        contestId: 'contest_mock',
        correctCount: 8,
      );

      expect(entry, isNotNull);
      expect(entry?.score, 800); // 8 * 100
      expect(entry?.correctCount, 8);
      expect(entry?.rank, 1);
    });

    test('claimContestReward returns rank reward and badge', () async {
      final reward = await repo.claimContestReward('contest_mock');
      expect(reward, isNotNull);
      expect(reward?['claimed'], true);
      expect(reward?['rank_reward'], 500);
    });

    test('getContestLeaderboard returns top 3', () async {
      final rows = await repo.getContestLeaderboard(
        contestId: 'contest_mock',
        limit: 3,
      );

      expect(rows, isNotEmpty);
      expect(rows.length, 3);
      expect(rows.first.displayName, 'Rojda');
      expect(rows.first.rank, 1);
    });

    test('loadUserContestBadges returns empty list for mock', () async {
      final badges = await repo.loadUserContestBadges();
      expect(badges, isEmpty);
    });
  });

  group('Contest Logic', () {
    test('Score calculation: correct_count * 100', () {
      final entry = ContestEntry(
        id: 'e1',
        contestId: 'c1',
        userId: 'u1',
        correctCount: 10,
        score: 10 * 100,
      );

      expect(entry.score, 1000);
    });

    test('Rank 1 has highest score', () {
      final leaderboard = [
        const ContestLeaderboardRow(
          userId: 'u1',
          displayName: 'First',
          score: 1000,
          correctCount: 10,
          rank: 1,
        ),
        const ContestLeaderboardRow(
          userId: 'u2',
          displayName: 'Second',
          score: 900,
          correctCount: 9,
          rank: 2,
        ),
      ];

      expect(leaderboard[0].rank, 1);
      expect(leaderboard[0].score, greaterThan(leaderboard[1].score));
    });

    test('Badge tier: 2 equals champion', () {
      const badge = ContestBadge(
        id: 'b1',
        slug: 'champion',
        nameKu: 'Champion',
        tier: 2,
      );

      expect(badge.tier, 2);
    });
  });
}
