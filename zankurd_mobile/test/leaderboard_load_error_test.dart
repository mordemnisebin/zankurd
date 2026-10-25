import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Okunamayan sıralama boş sıralama değildir.
///
/// ## Kusur
///
/// `SupabaseZanKurdRepository.loadLeaderboard`, `get_leaderboard` RPC'si
/// düşünce `const []` dönüyordu. Ekran bağlantı varken boş listeyi
/// "Henüz puan yok" diye çiziyordu: sunucu hatası, kimsenin puanı yokmuş
/// gibi görünüyordu ve "Tekrar dene" yolu hiç çıkmıyordu.
///
/// ## Bekçi
///
/// Depo hatayı taşır; ekran hata durumunu (K.boardLoadFailed) çizer.
/// Gerçek boş sonuç hâlâ boş durumdur.
class _FailingRpcClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final bytes = utf8.encode(
      jsonEncode({
        'code': 'XX000',
        'message': 'injected: get_leaderboard failed',
        'details': null,
        'hint': null,
      }),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      500,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _BoardRepository extends MockZanKurdRepository {
  _BoardRepository({this.fail = false});

  final bool fail;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    if (fail) throw StateError('injected: get_leaderboard failed');
    return const [];
  }
}

Widget _shell(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
    ),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.dark(), home: child),
);

void main() {
  test('get_leaderboard düşerse depo boş liste değil hata döner', () async {
    final client = _FailingRpcClient();
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: client,
      ),
    );

    await expectLater(repository.loadLeaderboard(), throwsA(anything));
    expect(client.requestedPaths, ['/rest/v1/rpc/get_leaderboard']);
  });

  testWidgets('yükleme hatası "Henüz puan yok" değil, hata durumu çizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(LeaderboardScreen(repository: _BoardRepository(fail: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yüklenemedi'), findsOneWidget);
    expect(find.text('Henüz puan yok'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gerçek boş sonuç boş durumu çizer', (tester) async {
    await tester.pumpWidget(
      _shell(LeaderboardScreen(repository: _BoardRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henüz puan yok'), findsOneWidget);
    expect(find.text('Yüklenemedi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
