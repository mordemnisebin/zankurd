import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

// D22: küçük geliştirme verisi hatayı gizliyordu. Gerçek 1.202 skor, ödül
// ve 4.404 haftalık puan hem TR hem KU'da aynı noktadan biçimlenmeli.
class _WeeklyRepo extends MockZanKurdRepository {
  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async => const LeaderboardEntry(
    rank: 1202,
    playerId: 'me',
    displayName: 'Ali',
    totalScore: 4404,
    bestStreak: 5,
    roomsPlayed: 1436,
  );
}

/// UI alanlarında ham ekonomik/başarı sayacı enterpolasyonunu yakalar.
/// Anahtarlar veri kimliğidir; görsel metin değillerdir. Formatlanmış String
/// değişkenleri Text/Label ekiyle ayrılır. Yorumlar ve tanı iletileri taranmaz.
String _withoutGroupedNumbers(String expression) {
  var remaining = expression;
  const call = 'groupThousands(';
  while (true) {
    final start = remaining.indexOf(call);
    if (start < 0) return remaining;
    var depth = 1;
    var end = start + call.length;
    while (end < remaining.length && depth > 0) {
      if (remaining[end] == '(') depth++;
      if (remaining[end] == ')') depth--;
      end++;
    }
    if (depth != 0) return remaining;
    remaining = remaining.replaceRange(start, end, '');
  }
}

List<String> rawNumberDisplays(String source, {String sourcePath = ''}) {
  final interpolation = RegExp(r'\$\{([^{}]+)\}|\$([a-zA-Z_]\w*)');
  final numericName = RegExp(
    r'(?:score|xp|coins?|points?|rank|balance|fee|price|amount|rewards?|cost|bonus|weekly|counts?|total|level|leveled|streak|stock|progress|correct|wrong|blank|done|number|steps?|capacity|difficulty|answered|played|remaining|target|completed|filled|index|length|rounds?|missing|failed|pending|seconds|days|hours|minutes)'
    r'(?:Awarded|Reward|InLevel|Needed|Total|Champion|Questions|Players|Rounds|Unlocked|All|UpTo|Left|Elapsed|Shortfall)?$',
    caseSensitive: false,
  );
  // Bunlar tam sayı değil, önceden biçimlenmiş saat/ondalık süre dizeleridir.
  final formattedTime = <String, Set<String>>{
    'lib/src/screens/spin_wheel_screen.dart': {'hours', 'minutes', 'seconds'},
    'lib/src/screens/async_duel/async_duel_review.dart': {'seconds'},
    'lib/src/screens/home/daily_tour_card.dart': {'left.hours', 'left.minutes'},
    'lib/src/widgets/daily_event_board.dart': {'left.hours', 'left.minutes'},
  };
  final offenders = <String>[];
  final filteredLines = <String>[];
  final lines = source
      .replaceAll(RegExp(r'ValueKey(?:<[^>]+>)?\([^)]*\)'), '')
      .split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//') ||
        line.contains('ValueKey(') ||
        line.contains('key:') ||
        RegExp(r'\b\w*[Ii]d:').hasMatch(line) ||
        line.contains("name: 'TBD:") ||
        // Şema izleme imzası: ekrana yazılmaz, değişim algılamanın veri anahtarı.
        line.trim() == r"return '${b.currentRound}|${b.status}|$completed';") {
      continue;
    }
    filteredLines.add(line);
    for (final match in interpolation.allMatches(line)) {
      final expression = (match[1] ?? match[2]!).trim();
      if (expression == 'info.buildNumber' ||
          (formattedTime[sourcePath]?.contains(expression) ?? false)) {
        continue;
      }
      // Seçimli skor ifadelerini de kapsar: mine ? a.score : b.score.
      final identifiers = RegExp(r'[a-zA-Z_]\w*(?:!?\.[a-zA-Z_]\w*)*')
          .allMatches(
            _withoutGroupedNumbers(
              expression,
            ).replaceAll(RegExp(r'K\.\w+'), ''),
          );
      if (identifiers.any(
        (id) =>
            id[0] == 'stat.value' ||
            numericName.hasMatch(id[0]!.split('.').last),
      )) {
        offenders.add('${i + 1}: ${match[0]}');
      }
    }
  }
  // Satır bölünerek yazılan `entry.totalScore\n.toString()` de kaçmasın.
  final numericStringCalls = RegExp(
    r'([a-zA-Z_]\w*(?:!?\.[a-zA-Z_]\w*)*)!?\s*\.\s*toString\(\)',
  );
  final filteredSource = filteredLines.join('\n');
  for (final call in numericStringCalls.allMatches(filteredSource)) {
    final name = call[1]!.split('.').last;
    final paddedClock =
        {
          'inHours',
          'inMinutes',
          'inSeconds',
          'hour',
          'minute',
          'second',
        }.contains(name) &&
        filteredSource.substring(call.end).trimLeft().startsWith('.padLeft(');
    if (!paddedClock &&
        (call[1] == 'stat.value' || numericName.hasMatch(name))) {
      offenders.add('ham toString: ${call[0]}');
    }
  }
  return offenders;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('D22 kaynak bekçisi ham, üye ve seçimli sayıları yakalar', () {
    expect(rawNumberDisplays(r"Text('$score XP')"), isNotEmpty);
    expect(rawNumberDisplays(r"Text('+$coinsAwarded')"), isNotEmpty);
    expect(rawNumberDisplays(r"Text('$xpInLevel / $xpNeeded XP')"), isNotEmpty);
    expect(rawNumberDisplays(r"Text('${entry.totalScore}')"), isNotEmpty);
    expect(
      rawNumberDisplays(r"Text('${mine ? a.score : b.score}')"),
      isNotEmpty,
    );
    expect(rawNumberDisplays('Text(score.toString())'), isNotEmpty);
    expect(
      rawNumberDisplays('Text(entry.weeklyTotal\n.toString())'),
      isNotEmpty,
    );
    expect(rawNumberDisplays(r"Text('${groupThousands(score)} XP')"), isEmpty);
    expect(rawNumberDisplays(r"ValueKey('rank-$rank')"), isEmpty);
    expect(rawNumberDisplays(r"Text('$scoreText')"), isEmpty);
    expect(rawNumberDisplays('Text(myRank!.toString())'), isNotEmpty);
    expect(rawNumberDisplays('// score.toString()'), isEmpty);
    expect(rawNumberDisplays("d.inHours.toString().padLeft(2, '0')"), isEmpty);
    expect(rawNumberDisplays("score.toString().padLeft(2, '0')"), isNotEmpty);
    expect(rawNumberDisplays('key: ValueKey(score.toString())'), isEmpty);
    expect(rawNumberDisplays('playerOneId: score.toString()'), isEmpty);
    expect(
      rawNumberDisplays(r"Text('${mine ? groupThousands(a.score) : b.score}')"),
      isNotEmpty,
    );
    expect(
      rawNumberDisplays(
        r"Text('${groupThousands(coinShortfall(cost: fee, balance: coins))}')",
      ),
      isEmpty,
    );
    for (final expression in [
      'counts[s]',
      'rewards[i]',
      'steps[i]',
      '_leveledUpTo',
      'missing',
      'failed',
      'pending',
      '_secondsLeft',
      '_secondsElapsed',
      'days',
      'stat.value',
    ]) {
      expect(
        rawNumberDisplays("Text('\${$expression}')"),
        isNotEmpty,
        reason: expression,
      );
    }
    for (final name in [
      'weeklyTotal',
      'count',
      'total',
      'level',
      'streak',
      'progress',
    ]) {
      expect(rawNumberDisplays("Text('\$$name')"), isNotEmpty, reason: name);
    }
  });

  test('D22 tüm ekran/widget kaynaklarında ham puan XP jeton sıra yok', () {
    final offenders = <String>[];
    final files = [
      ...Directory('lib/src/screens').listSync(recursive: true),
      ...Directory('lib/src/widgets').listSync(recursive: true),
      File('lib/src/utils/result_sharer.dart'),
    ].whereType<File>().where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      for (final offender in rawNumberDisplays(
        file.readAsStringSync(),
        sourcePath: file.path,
      )) {
        offenders.add('${file.path}:$offender');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  for (final ku in [false, true]) {
    final lang = ku ? 'KU' : 'TR';
    testWidgets('D22 $lang ödül XP/jeton ve seviye ilerlemesi', (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: const Scaffold(
            body: SahneResultRewards(
              coins: 1202,
              xp: 1202,
              progress: SahneResultLevelProgress(
                levelLabel: '12',
                xpInLevel: 1436,
                xpNeeded: 2500,
                progress: 1436 / 2500,
              ),
            ),
          ),
        ),
      );
      expect(find.text('+1.202'), findsOneWidget);
      expect(find.text('+1.202 XP'), findsOneWidget);
      expect(find.text('1.436 / 2.500 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D22 $lang 1v1 sonuç özetinde büyük ve küçük skor', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          reducedMotion: true,
          child: QuizResultScreen(
            repository: repo,
            room: repo.createRoom(),
            score: 1202,
            correctCount: 8,
            wrongCount: 2,
            totalQuestions: 10,
            bestStreak: 5,
            coinsAwarded: 1202,
            answerRecords: const [],
            opponents: const [
              Player(id: 'opp', name: 'Bero', score: 888, state: 'Bot'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('result-duel-score-me')))
            .data,
        '1.202',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('result-duel-score-opponent')),
            )
            .data,
        '888',
      );
      expect(find.textContaining('1202'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D22 $lang Yarış haftalık puan sıra ve tur sayısı', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: PlayHubScreen(repository: _WeeklyRepo()),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('play-hub-this-week'));
      await tester.ensureVisible(card);
      expect(
        find.descendant(of: card, matching: find.text('4.404')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('#1.202')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('1.436')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
