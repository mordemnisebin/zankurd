// 2.1.2 W9 dayanıklılık/ölçek bekçileri (alan 9 #10, #12, #13; alan 10 G-09).
//
// ## Kusurlar ve niçin sessizdiler
//
// * #10 Sıralama sekmesi ÖNDE değilken uygulama ön plana dönünce (resumed)
//   görünürlük kontrolsüz `_loadData()` çağrılıyordu: her dönüşte gizli sekme
//   için ağ/RPC. Hata üretmez, yalnız kota ve pil yer.
// * #12/#13 Doğrulanmış tur kuyrukları ve profil önbellekleri oturum boyunca
//   temizlenmiyordu: bellek yavaş büyür, çökme değil; kimse fark etmez.
// * G-09 Crashlytics'in döndürdüğü Future beklenmiyordu: asenkron hata
//   yakalanmamış istisna olup raporlayıcının kendisini sessizce susturuyordu.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

class _CountingBoard extends MockZanKurdRepository {
  int loads = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    loads += 1;
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
  testWidgets('#10 gizli sıralama sekmesi ön plana dönüşte tazelenmez', (
    tester,
  ) async {
    var visible = false;
    final repository = _CountingBoard();
    await tester.pumpWidget(
      _shell(
        LeaderboardScreen(repository: repository, isVisible: () => visible),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final before = repository.loads;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      repository.loads,
      before,
      reason: 'sekme önde değilken dönüş ağ isteği başlatmamalı',
    );

    visible = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      repository.loads,
      greaterThan(before),
      reason: 'sekme öndeyken dönüş tazelemeli',
    );
  });

  test('#12/#13 bellek temizliği yerinde (sözleşme)', () {
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    // Ödemesi/sonucu alınan tur bellekten atılır; sınır dolunca teslimi biten
    // turlar elenir.
    expect(src, contains('_verifiedRounds.remove(clientRoundId)'));
    expect(src, contains('_verifiedRounds.length >= 16'));
    // Profil önbellekleri sınırlı.
    expect(src, contains('_profileCacheLimit = 400'));
    expect(src, contains('_boundCache(_chatProfiles)'));
    expect(src, contains('_boundCache(_profileCache)'));
  });

  test('G-09 Crashlytics Future hataları yutulur (sözleşme)', () {
    final src = File('lib/src/utils/error_reporter.dart').readAsStringSync();
    expect(
      RegExp(r'_swallowAsync\(').allMatches(src).length,
      greaterThanOrEqualTo(4),
      reason: 'tanım + üç Crashlytics çağrısı',
    );
    expect(src, contains('pending.catchError'));
  });
}
