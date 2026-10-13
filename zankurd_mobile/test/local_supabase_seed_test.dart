import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const configPath = 'supabase/config.toml';
  const seedPath = 'supabase/seed.sql';

  test('local Supabase reset explicitly enables the deterministic seed', () {
    final config = File(configPath).readAsStringSync();

    expect(config, contains('[db.seed]'));
    expect(config, contains('enabled = true'));
    expect(config, contains('sql_paths = ["./seed.sql"]'));
    expect(File(seedPath).existsSync(), isTrue);
  });

  test('local seed is data-only and has enough approved Ziman questions', () {
    final seed = File(seedPath).readAsStringSync();
    final normalized = seed.toLowerCase();

    expect(normalized, isNot(contains('alter table')));
    expect(normalized, isNot(contains('drop table')));
    expect(normalized, isNot(contains('delete from')));
    expect(normalized, isNot(contains('truncate')));
    expect(normalized, isNot(contains('http://')));
    expect(normalized, isNot(contains('https://')));
    expect(normalized, isNot(contains('service_role')));

    expect(seed, contains("'Ziman'"));
    expect(seed, contains("'zankurd_local_seed'"));

    final approvedRows = RegExp(
      r"'zankurd_local_seed'",
    ).allMatches(seed).length;
    expect(
      approvedRows,
      greaterThanOrEqualTo(12),
      reason: '1v1 odasi icin en az 10 soru ve bir miktar yedek gerekir.',
    );
  });
}
