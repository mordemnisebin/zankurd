/// Ders tamamlama önce yerele yazılır, sonra sunucu kuyruğuna girer.
///
/// ## Kusur
///
/// Ders tamamlama yalnız sunucudaydı: ağ yokken `mark_lesson_completed`
/// başarısız olur, ders hiçbir yere yazılmaz ve sonraki dersler, kilit
/// durumu sunucudan okunduğu için, bir daha eşitleme olmayacağından
/// kilitli kalırdı (2026-10-16 denetimi).
///
/// ## Niçin sessizdi
///
/// Hata yolu bir kez "false → hata mesajı" olarak sınanmıştı
/// (`supabase_offline_fallback_test.dart`); fakat başarısızlıktan SONRA
/// dersin yerelde bulunup bulunmadığına ve kilidin açılıp açılmadığına
/// bakan hiçbir test yoktu. Kullanıcıya dürüst bir hata gösteriliyordu,
/// yani kusur "çalışıyor" gibi görünüyordu.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/lesson_completion_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';

class _FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

class _OfflineMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.none,
  ];
}

/// Sunucu dersi onaylamaz (çevrimdışı); yerel yazım ekran tarafında olur.
class _UnackedLessonRepository extends MockZanKurdRepository {
  @override
  Future<bool> markLessonCompleted(String lessonId) async => false;

  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async => const [
    LessonSlide(
      id: 's1',
      lessonId: 'offline-lesson',
      order: 1,
      contentKu: 'Silav.',
    ),
  ];
}

class _SignedInRepository extends SupabaseZanKurdRepository {
  _SignedInRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _FailingHttpClient(),
        ),
      );

  @override
  String? get currentUserId => 'user-a';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.bind('user-a');
  });
  tearDown(LocalProgressScope.debugReset);

  test('çevrimdışı tamamlanan ders yerelde kalır ve kilidi açar', () async {
    final repository = _SignedInRepository();
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineMonitor(),
    );

    await manager.queueLessonCompletion('everyday_1');

    // Sunucu erişilemez; yine de ders tamamlanmış okunur.
    expect(await repository.loadCompletedLessonIds(), {'everyday_1'});
    expect(manager.pendingLessonCompletionCount, 1);
  });

  test('yerel yazım uygulama yeniden açılınca da durur', () async {
    final first = _SignedInRepository();
    final manager = await SyncManager.initialize(
      first,
      connectivityMonitor: _OfflineMonitor(),
    );
    await manager.queueLessonCompletion('everyday_2');

    // Yeni açılış: bellekteki her şey gitti, yalnız disk var.
    final second = _SignedInRepository();
    expect(await second.loadCompletedLessonIds(), contains('everyday_2'));
  });

  test('sunucuda tamamlanan ders sunucuya ulaşılamayınca da bilinir', () async {
    await LessonCompletionStore.cacheServer({'a', 'b'});
    await LessonCompletionStore.addPending('c');

    final repository = _SignedInRepository();
    expect(await repository.loadCompletedLessonIds(), {'a', 'b', 'c'});
  });

  test('sunucu onayı dersi bekleyenden düşer ama eşitlenmiş kalır', () async {
    await LessonCompletionStore.addPending('x', owner: 'user-a');
    await LessonCompletionStore.markSynced('x', owner: 'user-a');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(
        LocalProgressScope.physicalFor(
          'user-a',
          LessonCompletionStore.pendingKey,
        ),
      ),
      isEmpty,
    );
    expect(await LessonCompletionStore.loadLocal(), {'x'});
  });

  test('bir kullanıcının yerel dersi ötekine sızmaz', () async {
    await LessonCompletionStore.addPending('private');
    LocalProgressScope.bind('user-b');
    expect(await LessonCompletionStore.loadLocal(), isEmpty);
  });

  testWidgets('sunucu onaylamasa da ders yerelde tamamlanır, ekran kapanır', (
    tester,
  ) async {
    const lesson = Lesson(
      id: 'offline-lesson',
      slug: 'offline-lesson',
      titleKu: 'Ders',
      titleTr: 'Ders',
      category: 'everyday',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonDetailScreen(
                      lesson: lesson,
                      repository: _UnackedLessonRepository(),
                    ),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Tr.forKu(K.finish, false)));
    await tester.pumpAndSettle();

    // Hata değil "kaydedilecek" bildirimi; ekran kapandı; yerelde duruyor.
    expect(find.text(Tr.forKu(K.lessonSavedOffline, false)), findsOneWidget);
    expect(find.text(Tr.forKu(K.lessonCompleteFailed, false)), findsNothing);
    expect(find.byType(LessonDetailScreen), findsNothing);
    expect(await LessonCompletionStore.loadLocal(), {'offline-lesson'});
  });
}
