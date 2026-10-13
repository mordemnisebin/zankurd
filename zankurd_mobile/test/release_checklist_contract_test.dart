import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release checklist covers the complete user journey', () {
    final checklist = File('../docs/release-readiness.md').readAsStringSync();

    for (final gate in [
      'Android',
      'iOS',
      '1v1',
      'oda kurma',
      'bildirim',
      'hesap silme',
      'Geri bildirim',
      'kozmetik',
    ]) {
      expect(checklist.toLowerCase(), contains(gate.toLowerCase()));
    }
  });

  test('README links to the checked-in release checklist', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('../docs/release-readiness.md'));
    expect(File('../docs/release-readiness.md').existsSync(), isTrue);
  });

  // README `flutter test --exclude-tags preview` diyordu; kök CI ise
  // `flutter test --coverage` koşar. Preview üreticileri `test/` değil
  // `tool/screenshots/` altındadır — exclude bayrağı yerel koşuyu
  // CI'dan saptırıyor ve preview'in ana pakette olduğu izlenimini
  // bırakıyordu.
  test('README unit test command matches CI coverage step', () {
    final readme = File('README.md').readAsStringSync();
    final ci = File('../.github/workflows/flutter_ci.yml').readAsStringSync();

    expect(ci, contains('flutter test --coverage'));
    expect(readme, contains('flutter test --coverage'));
    expect(readme, isNot(contains('--exclude-tags preview')));
    expect(
      readme,
      contains('tool/screenshots'),
      reason: 'preview üreticilerinin yeri README’de doğru yazılmalı.',
    );
  });

  // README çıktı klasörünü varmış gibi gösteriyordu. Dizin
  // `.gitignore` ile dışarıda; 2026-07-15 CSV/rapor silindi.
  // Kaynak `tool/question_quality/adjudication/` kodudur.
  test('README does not treat adjudication audit output as checked in', () {
    final readme = File('README.md').readAsStringSync();
    final gitignore = File('.gitignore').readAsStringSync();
    final start = readme.indexOf('adjudication.dart report');
    expect(start, greaterThanOrEqualTo(0));
    final section = readme.substring(
      start,
      (start + 700).clamp(0, readme.length),
    );

    expect(gitignore, contains('/docs/audit/question_quality/'));
    expect(
      File('tool/question_quality/adjudication/adjudication.dart').existsSync(),
      isTrue,
    );
    expect(
      section,
      contains('docs/audit/question_quality/adjudication_2026-07-15/'),
    );
    expect(section, contains('.gitignore'));
    expect(section, contains('repoda yok'));
    expect(section, contains('tool/question_quality/adjudication/'));
  });

  test('mobile release guide matches the enforced configuration gate', () {
    final guide = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();

    expect(guide, contains('--dart-define-from-file=.env.mobile.release.json'));
    expect(
      guide,
      contains('RevenueCat anahtarları release derlemesinde zorunludur'),
    );
    expect(
      guide,
      isNot(
        contains(
          'RevenueCat anahtarları verilmezse premium **mock modda** kalır',
        ),
      ),
    );
  });
}
