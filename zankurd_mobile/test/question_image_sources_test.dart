import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';

import '../tool/question_images/validate_image_reference.dart';

void main() {
  String? check(Object? value) => validateImageReference(
    value,
    assetExists: (path) => path == 'assets/question_images/av.webp',
    assetIsBundled: (path) => path.startsWith('assets/question_images/'),
    allowedHosts: {'upload.wikimedia.org'},
  );

  test('eksik îro varlığı bankaya geri giremez', () {
    expect(check('asset://assets/question_images/iro.webp'), isNotNull);
    expect(check('asset://assets/question_images/av.webp'), isNull);
    expect(check(null), isNull);
  });

  test('geçersiz yol, tür, protokol ve bilinmeyen alan adı reddedilir', () {
    for (final value in <Object>[
      '',
      42,
      'assets/question_images/av.webp',
      'asset://assets/question_images/../av.webp',
      'asset://assets/question_images/av.webp?x=1',
      'asset://assets/question_images/av.webp#x',
      'asset://assets/question_images/%61v.webp',
      ' asset://assets/question_images/av.webp',
      'http://upload.wikimedia.org/image.webp',
      'https://upload.wikimedia.org.evil.example/image.webp',
      'https://user:password@upload.wikimedia.org/image.webp',
      'https://upload.wikimedia.org:8443/image.webp',
      'https://upload.wikimedia.org/',
      'https://upload.wikimedia.org/image.webp#x',
    ]) {
      expect(check(value), isNotNull, reason: '$value');
    }
    expect(check('https://upload.wikimedia.org/image.webp'), isNull);
  });

  test('diskte olsa bile pakete bildirilmeyen varlık reddedilir', () {
    expect(
      validateImageReference(
        'asset://assets/hidden.webp',
        assetExists: (_) => true,
        assetIsBundled: (_) => false,
      ),
      isNotNull,
    );
  });

  test('bilinmeyen alan adları ve iç içe listelerde asset yolu kaçmaz', () {
    final references = questionImageReferences({
      'id': 'fixture',
      'metadata': {
        'newImageKey': 'asset://assets/question_images/iro.webp',
        'nested': ['assets/question_images/also_missing.webp'],
      },
      'image_url': 'https://upload.wikimedia.org/image.webp',
    }).toList();
    expect(references, hasLength(3));
    expect(references.every((r) => r.id == 'fixture'), isTrue);
    expect(
      references.take(2).map((r) => check(r.value)),
      everyElement(isNotNull),
    );
    expect(check(references.last.value), isNull);
  });

  test('T13 SQL hedefi ve eski değeri kilitler; varsayılanı kuru çalışmadır', () {
    final sql = File(
      'supabase/2026-10-30_t13_question_image_cleanup.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains("WHERE id = 'd596f0be-684e-4f9d-9451-9308d0eb3cbf'::uuid"),
    );
    expect(sql, contains('FOR UPDATE;'));
    for (final column in [
      'prompt',
      'option_a',
      'option_b',
      'option_c',
      'option_d',
    ]) {
      expect(sql, contains('q.$column IS DISTINCT FROM'));
    }
    expect(sql, contains("q.correct_option::text IS DISTINCT FROM 'D'"));
    expect(
      sql,
      contains(
        "q.image_url IS DISTINCT FROM 'asset://assets/question_images/iro.webp'",
      ),
    );
    expect(
      sql,
      contains("AND image_url = 'asset://assets/question_images/iro.webp'"),
    );
    expect(sql, contains('IF changed <> 1 THEN'));
    expect(sql.trim(), endsWith('ROLLBACK;'));
    expect(RegExp(r'^COMMIT;', multiLine: true).hasMatch(sql), isFalse);
    expect(RegExp(r'UPDATE public.questions').allMatches(sql), hasLength(1));
  });

  test(
    'tüm JSON bankalarının ve Dart bankasının görsel kaynakları geçerli',
    () {
      final declared = RegExp(r'^\s+- (assets/[^\s]*)$', multiLine: true)
          .allMatches(File('pubspec.yaml').readAsStringSync())
          .map((m) => m[1]!)
          .toList();
      final errors = <String>[];
      var imageCount = 0;
      void inspect(Object? data, String source) {
        for (final reference in questionImageReferences(data)) {
          if (reference.value != null) imageCount++;
          final error = validateImageReference(
            reference.value,
            assetExists: (path) => File(path).existsSync(),
            assetIsBundled: (path) => declared.any(
              // Flutter dizin bildirimi yalnız doğrudan alt dosyaları kapsar.
              (d) =>
                  d == path ||
                  (d.endsWith('/') &&
                      path.startsWith(d) &&
                      !path.substring(d.length).contains('/')),
            ),
            // Bankada onaylanmış uzak görsel alan adı yok.
          );
          if (error != null) errors.add('$source/${reference.id}: $error');
        }
      }

      for (final file
          in Directory('assets/data')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))) {
        inspect(jsonDecode(file.readAsStringSync()), file.path);
      }
      for (final question in curatedQuestionBank) {
        inspect(question.toJson(), 'curatedQuestionBank');
      }
      expect(imageCount, greaterThan(0), reason: 'Boş tarama başarı sayılmaz');
      expect(errors, isEmpty, reason: errors.join('\n'));
    },
  );
}
