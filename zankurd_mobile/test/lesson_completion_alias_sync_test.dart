import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/lesson_completion_store.dart';
import 'package:zankurd_mobile/src/data/learning_lesson_aliases.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';

const _lessonUuid = '12345678-1234-4234-8234-123456789abc';

class _SignedInRepository extends SupabaseZanKurdRepository {
  _SignedInRepository(super.client);

  @override
  String? get currentUserId => 'user-a';
}

class _Connection extends ConnectivityMonitor {
  bool online = false;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    online ? ConnectivityResult.wifi : ConnectivityResult.none,
  ];
}

List<Map<String, Object?>> _seedSlides(String file, String slug) {
  final sql = File(file).readAsStringSync();
  final end = sql.indexOf(") as s(ord, ku, tr, ex) where slug = '$slug'");
  final start = sql.lastIndexOf(
    'select id, s.ord, s.ku, s.tr, s.ex from lessons, (values',
    end,
  );
  final row = RegExp(
    r"^\s*\((\d+), E'((?:[^']|'')*)', E'((?:[^']|'')*)', (?:E'((?:[^']|'')*)'|null::text)\)",
    multiLine: true,
  );
  String? decode(String? value) =>
      value?.replaceAll("''", "'").replaceAll(r'\n', '\n');
  return [
    for (final match in row.allMatches(sql.substring(start, end)))
      {
        'order': int.parse(match[1]!),
        'ku': decode(match[2]),
        'tr': decode(match[3]),
        'example': decode(match[4]),
      },
  ];
}

// Yalnız editoryal olarak denetlenmiş bu iki tam alan çifti kabul edilir.
// Yeni alan farkları veya bu literal değerlerdeki değişimler istisna değildir.
const _reviewedSlideDifferences = [
  (
    lessonId: 'greetings_2',
    order: 3,
    field: 'ku',
    sqlLiteral:
        'Spas û lêborîn:\n\n• Gelek spas: Çok teşekkürler\n• Bibore: Özür dilerim / Pardon',
    localLiteral:
        'Spas, lêborîn û gotin:\n\n• Gelek spas: Çok teşekkürler\n• Bibore: Özür dilerim / Pardon\n• Gotin: Söylemek',
  ),
  (
    lessonId: 'intro_1',
    order: 3,
    field: 'tr',
    sqlLiteral:
        'Nerelisin? sorusu ve cevabı. "ji" ile dişil şehir adlarının sonuna -ê eklenir: Wan → Wanê, Mêrdîn → Mêrdînê, Stenbol → Stenbolê..',
    localLiteral:
        'Nerelisin? sorusu ve cevabı. "ji" ile dişil şehir adlarının sonuna -ê eklenir: Wan → Wanê, Mêrdîn → Mêrdînê, Stenbol → Stenbolê.',
  ),
];

bool _allowsReviewedDifference(
  String lessonId,
  Object? order,
  String field,
  Object? sqlLiteral,
  Object? localLiteral,
) => _reviewedSlideDifferences.any(
  (difference) =>
      difference.lessonId == lessonId &&
      difference.order == order &&
      difference.field == field &&
      difference.sqlLiteral == sqlLiteral &&
      difference.localLiteral == localLiteral,
);

void main() {
  late List<String> lookups;
  late List<String> completions;
  late SupabaseClient client;
  late _SignedInRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.bind('user-a');
    lookups = [];
    completions = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: MockClient((request) async {
        if (request.url.path == '/rest/v1/lessons') {
          final slug = request.url.queryParameters['slug']!;
          lookups.add(slug);
          return http.Response(
            jsonEncode([
              if (const {
                'eq.alfabe',
                'eq.reng',
                'eq.newroz',
                'eq.ciya-u-cem',
                'eq.cinavk',
                'eq.silav-u-rezdari',
                'eq.xwe-nasandin',
              }.contains(slug))
                {'id': _lessonUuid},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/rest/v1/rpc/mark_lesson_completed') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          completions.add(body['p_lesson_id'] as String);
          return http.Response(
            'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Beklenmeyen HTTP isteği: ${request.url}');
      }),
    );
    repository = _SignedInRepository(client);
  });

  tearDown(() async {
    await SyncManager.resetForTesting();
    await client.dispose();
    LocalProgressScope.debugReset();
  });

  test('yerel birebir ders kimliği sunucu UUIDsiyle tamamlanır', () async {
    expect(await repository.markLessonCompleted('alphabet_1'), isTrue);
    expect(lookups, ['eq.alphabet_1', 'eq.alfabe']);
    expect(completions, [_lessonUuid]);
  });

  test('ikinci birebir alias da mevcut eşleme tablosundan çözülür', () async {
    expect(await repository.markLessonCompleted('colors_1'), isTrue);
    expect(lookups, ['eq.colors_1', 'eq.reng']);
    expect(completions, [_lessonUuid]);
  });

  test('doğrudan sunucu slugu tek lookupla çalışmayı sürdürür', () async {
    expect(await repository.markLessonCompleted('alfabe'), isTrue);
    expect(lookups, ['eq.alfabe']);
    expect(completions, [_lessonUuid]);
  });

  test('UUID doğrudan RPCye gider', () async {
    expect(await repository.markLessonCompleted(_lessonUuid), isTrue);
    expect(lookups, isEmpty);
    expect(completions, [_lessonUuid]);
  });

  test('bilinmeyen veya birleşik ders aliası tamamlatılmaz', () async {
    for (final id in [
      'unknown',
      'everyday_1',
      'everyday_2',
      'emotions_1',
      'emotions_2',
    ]) {
      expect(await repository.markLessonCompleted(id), isFalse);
    }
    expect(lookups, [
      'eq.unknown',
      'eq.everyday_1',
      'eq.everyday_2',
      'eq.emotions_1',
      'eq.emotions_2',
    ]);
    expect(completions, isEmpty);
  });

  for (final id in ['culture_2', 'geography_1', 'grammar_1']) {
    test('$id konu eşlemesi tamamlanma eşdeğerliği sayılmaz', () async {
      expect(await repository.markLessonCompleted(id), isFalse, reason: id);
      expect(lookups, ['eq.$id']);
      expect(completions, isEmpty);
    });
  }

  for (final entry in const {
    'greetings_2': 'silav-u-rezdari',
    'intro_1': 'xwe-nasandin',
  }.entries) {
    test('${entry.key} denetlenmiş kapsamıyla doğru UUIDyi tamamlar', () async {
      expect(await repository.markLessonCompleted(entry.key), isTrue);
      expect(lookups, ['eq.${entry.key}', 'eq.${entry.value}']);
      expect(completions, [_lessonUuid]);
    });
  }

  test('alan istisnası ders sıra alan ve iki literal kaymasını reddeder', () {
    for (final difference in _reviewedSlideDifferences) {
      bool allows({
        String? lessonId,
        int? order,
        String? field,
        String? sqlLiteral,
        String? localLiteral,
      }) => _allowsReviewedDifference(
        lessonId ?? difference.lessonId,
        order ?? difference.order,
        field ?? difference.field,
        sqlLiteral ?? difference.sqlLiteral,
        localLiteral ?? difference.localLiteral,
      );
      expect(allows(), isTrue);
      expect(allows(lessonId: 'unknown'), isFalse);
      expect(allows(order: 2), isFalse);
      expect(allows(field: 'example'), isFalse);
      expect(allows(sqlLiteral: '${difference.sqlLiteral} '), isFalse);
      expect(allows(localLiteral: '${difference.localLiteral} '), isFalse);
    }
  });

  const seedSources = {
    'supabase/2026-10-06_baslangic_lessons.sql': {
      'alphabet_1': 'alfabe',
      'family_1': 'malbat',
      'greetings_2': 'silav-u-rezdari',
      'intro_1': 'xwe-nasandin',
    },
    'supabase/2026-10-08_dersler2_lessons.sql': {
      'colors_1': 'reng',
      'body_1': 'las',
      'clothes_1': 'cil',
      'home_1': 'mal',
      'weather_1': 'hewa',
      'questions_1': 'pirs',
      'verbs_1': 'leker',
    },
    'supabase/2026-10-08_dersler3_lessons.sql': {
      'jobs_1': 'pise',
      'city_1': 'bajar',
      'shopping_1': 'kirin',
      'health_1': 'tenduristi',
      'school_1': 'dibistan',
      'transport_1': 'veguhestin',
      'past_1': 'dema-bori',
    },
  };
  for (final source in seedSources.entries) {
    for (final lesson in source.value.entries) {
      test(
        '${lesson.key} izinlistesi denetlenmiş SQL slayt kapsamıyla örtüşür',
        () async {
          final serverSlides = _seedSlides(source.key, lesson.value);
          final count = lesson.key == 'alphabet_1'
              ? 6
              : {'family_1', 'greetings_2'}.contains(lesson.key)
              ? 4
              : 5;
          expect(serverSlides, hasLength(count));
          final localSlides = await MockZanKurdRepository().loadLessonSlides(
            lesson.key,
          );
          expect(localSlides, hasLength(count));
          for (final difference in _reviewedSlideDifferences.where(
            (difference) => difference.lessonId == lesson.key,
          )) {
            final server = serverSlides.singleWhere(
              (slide) => slide['order'] == difference.order,
            );
            final slide = localSlides.singleWhere(
              (slide) => slide.order == difference.order,
            );
            final local = {
              'ku': slide.contentKu,
              'tr': slide.contentTr,
              'example': slide.exampleKu,
            };
            expect(server[difference.field], difference.sqlLiteral);
            expect(local[difference.field], difference.localLiteral);
          }
          for (var index = 0; index < count; index++) {
            final slide = localSlides[index];
            final local = {
              'order': slide.order,
              'ku': slide.contentKu,
              'tr': slide.contentTr,
              'example': slide.exampleKu,
            };
            for (final field in serverSlides[index].keys) {
              final sqlValue = serverSlides[index][field];
              final localValue = local[field];
              if (_allowsReviewedDifference(
                lesson.key,
                slide.order,
                field,
                sqlValue,
                localValue,
              )) {
                continue;
              }
              expect(
                localValue,
                sqlValue,
                reason: '${lesson.key} slayt ${index + 1} alan $field',
              );
            }
          }
          expect(
            LearningLessonAliases.completionSlugFor(lesson.key),
            lesson.value,
          );
        },
      );
    }
  }

  for (final lessonId in ['alphabet_1', 'greetings_2', 'intro_1']) {
    test('$lessonId çevrimdışı kuyruğu bağlantı gelince boşalır', () async {
      final connection = _Connection();
      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: connection,
      );
      await manager.queueLessonCompletion(lessonId);
      await manager.sync();
      expect(manager.pendingLessonCompletionCount, 1);
      expect(completions, isEmpty);

      connection.online = true;
      await manager.sync();

      expect(manager.pendingLessonCompletionCount, 0);
      expect(completions, [_lessonUuid]);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getStringList(
          LocalProgressScope.physicalFor(
            'user-a',
            LessonCompletionStore.pendingKey,
          ),
        ),
        isEmpty,
      );
      expect(await LessonCompletionStore.loadLocal(), contains(lessonId));
    });
  }
}
