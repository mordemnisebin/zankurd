import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eşleşme, günlük görev ve depo catch'leri ErrorReporter'a gitmeli.
///
/// ## Kusur
///
/// Bekçi dosyada bir kez `ErrorReporter.record` ve bir kez
/// `catch (error, stack)` geçmesini yeterli sayıyordu. On beş catch'ten
/// on dördü yutulsa, gerekçe silinse veya `catch (_)` ile yığın düşürülse
/// test yeşil kalırdı. Sözleşme her catch gövdesinin raporlamasıdır.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
    .split('\n')
    .map((line) {
      final index = line.indexOf('//');
      return index == -1 ? line : line.substring(0, index);
    })
    .join('\n');

class _CatchBlock {
  const _CatchBlock({
    required this.line,
    required this.params,
    required this.body,
  });

  final int line;
  final String params;
  final String body;

  bool get reports =>
      body.contains('ErrorReporter.record') || body.contains('_recordError(');

  Iterable<String> get reasons => RegExp(
    r"reason:\s*'([^']+)'",
  ).allMatches(body).map((match) => match.group(1)!);
}

List<_CatchBlock> _catchBlocks(String source) {
  final results = <_CatchBlock>[];
  final pattern = RegExp(r'catch\s*\(');
  for (final match in pattern.allMatches(source)) {
    final paramsEnd = _matchingParen(source, match.end - 1);
    if (paramsEnd == null) {
      fail('catch parantezi kapanmıyor (offset ${match.start})');
    }
    var bodyStart = paramsEnd + 1;
    while (bodyStart < source.length &&
        (source[bodyStart] == ' ' ||
            source[bodyStart] == '\n' ||
            source[bodyStart] == '\r' ||
            source[bodyStart] == '\t')) {
      bodyStart++;
    }
    if (bodyStart >= source.length || source[bodyStart] != '{') {
      fail('catch gövdesi yok (offset ${match.start})');
    }
    final bodyEnd = _matchingBrace(source, bodyStart);
    if (bodyEnd == null) {
      fail('catch gövdesi kapanmıyor (offset ${match.start})');
    }
    final line = source.substring(0, match.start).split('\n').length;
    results.add(
      _CatchBlock(
        line: line,
        params: source.substring(match.end, paramsEnd).trim(),
        body: source.substring(bodyStart + 1, bodyEnd),
      ),
    );
  }
  return results;
}

int? _matchingParen(String source, int openIndex) {
  var depth = 0;
  var inSingle = false;
  for (var i = openIndex; i < source.length; i++) {
    final ch = source[i];
    if (inSingle) {
      if (ch == '\\') {
        i++;
        continue;
      }
      if (ch == "'") inSingle = false;
      continue;
    }
    if (ch == "'") {
      inSingle = true;
      continue;
    }
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

int? _matchingBrace(String source, int openIndex) {
  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  for (var i = openIndex; i < source.length; i++) {
    final ch = source[i];
    if (inSingle) {
      if (ch == '\\') {
        i++;
        continue;
      }
      if (ch == "'") inSingle = false;
      continue;
    }
    if (inDouble) {
      if (ch == '\\') {
        i++;
        continue;
      }
      if (ch == '"') inDouble = false;
      continue;
    }
    if (ch == "'") {
      inSingle = true;
      continue;
    }
    if (ch == '"') {
      inDouble = true;
      continue;
    }
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

void _expectEveryCatchReports(String path, List<_CatchBlock> blocks) {
  expect(blocks, isNotEmpty, reason: '$path içinde catch yok');
  for (final block in blocks) {
    expect(
      block.params,
      contains(','),
      reason:
          '$path:${block.line} catch yığın izini düşürüyor '
          '(${block.params})',
    );
    expect(
      block.params,
      isNot(contains('_')),
      reason: '$path:${block.line} hata veya yığını yok sayıyor',
    );
    expect(
      block.reports,
      isTrue,
      reason:
          '$path:${block.line} catch ErrorReporter.record / '
          '_recordError çağırmıyor',
    );
    expect(
      block.body.contains('reason:'),
      isTrue,
      reason: '$path:${block.line} catch gerekçesiz raporluyor',
    );
  }
}

void main() {
  test('critical matchmaking and mission catches report errors', () {
    final matchmaking = _withoutComments(
      File('lib/src/screens/matchmaking_screen.dart').readAsStringSync(),
    );
    final missions = _withoutComments(
      File('lib/src/data/daily_mission_store.dart').readAsStringSync(),
    );
    final repository = _withoutComments(
      File('lib/src/data/supabase_zankurd_repository.dart').readAsStringSync(),
    );

    final matchmakingCatches = _catchBlocks(matchmaking);
    final missionCatches = _catchBlocks(missions);
    final repositoryCatches = _catchBlocks(repository);

    _expectEveryCatchReports(
      'lib/src/screens/matchmaking_screen.dart',
      matchmakingCatches,
    );
    _expectEveryCatchReports(
      'lib/src/data/daily_mission_store.dart',
      missionCatches,
    );
    _expectEveryCatchReports(
      'lib/src/data/supabase_zankurd_repository.dart',
      repositoryCatches,
    );

    expect(
      matchmakingCatches.expand((block) => block.reasons).toSet(),
      unorderedEquals({
        'matchmaking_dispose_join_timeout',
        'matchmaking_dispose_join_settle',
        'matchmaking_dispose_cancel',
        'matchmaking_join_settle_timeout',
        'matchmaking_join_settle_before_cancel',
        'matchmaking_cancel_and_pop',
        'matchmaking_best_effort_cancel',
        'matchmaking_late_join_cleanup',
        'matchmaking_load_categories',
        'matchmaking_load_room_snapshot',
        'matchmaking_timeout_cancel',
        'matchmaking_timeout_matched_room',
        'matchmaking_start',
        'matchmaking_load_room_questions',
        'matchmaking_load_questions',
      }),
    );
    expect(matchmakingCatches, hasLength(15));

    expect(
      missionCatches.expand((block) => block.reasons).toSet(),
      unorderedEquals({
        'daily_mission_load_preferences',
        'daily_mission_test_preferences',
      }),
    );
    expect(missionCatches, hasLength(2));

    expect(
      repository,
      contains('ErrorReporter.record(error, stack, reason: reason)'),
      reason: '_recordError ErrorReporter.record iletmezse yutma gizlenir',
    );
    expect(repository, isNot(contains('catch (_)')));
    expect(
      repositoryCatches.length,
      greaterThanOrEqualTo(60),
      reason:
          'Depo catch sayısı sessizce eridi; her yutma '
          '_recordError ile raporlanmalı',
    );
  });

  test('PlayHub oda hazırlığı fallback hatalarını sessizce yutmaz', () {
    final source = File(
      'lib/src/screens/play_hub_screen.dart',
    ).readAsStringSync();
    final catches = _catchBlocks(source);

    _expectEveryCatchReports('lib/src/screens/play_hub_screen.dart', catches);
    expect(source, isNot(contains('catch (_)')));
    expect(
      catches.expand((block) => block.reasons),
      containsAll({
        'play_hub_load_matchmaking_categories',
        'play_hub_load_coin_balance',
      }),
    );
  });
}
