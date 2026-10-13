/// Eşleşmede 20 sn'de rakip bulunamayınca çıkan teklife "Sırayla düello".
///
/// ## Kusur
///
/// Hızlı düello eşleşmesi 20 sn'de canlı rakip bulamayınca oyuncunun tek
/// seçenekleri botla oynamak ya da tamamen vazgeçmekti
/// (`MatchmakingScreen._showBotPrompt`). Küçük kullanıcı kitlesinde canlı
/// rakip çoğu zaman yok; oyuncu botu kabul ediyor ya da hiç oynamadan çıkıp
/// gidiyordu. Sunucu tarafı ve ekranları zaten hazır olan "sırayla düello"
/// (rakip aynı anda çevrimiçi olmasa da kendi zamanında oynar) bu diyalogda
/// hiç teklif edilmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `_showBotPrompt` yalnız `Future<bool?>` döndürüyordu: iki dal (bot/iptal)
/// vardı ve üçüncü bir seçenek tip sisteminde temsil edilmiyordu — hiçbir
/// switch/enum eksik dal göstermezdi çünkü ikisi de hiç yoktu. Mevcut
/// testler yalnız "Hayır"/"Evet" düğmelerini sınıyordu; bayrak
/// (`kAsyncDuelEnabled`) kapalıyken üçüncü düğmenin render EDİLMEDİĞİNİ
/// doğrulayan hiçbir bekçi yoktu — biri yanlışlıkla bayraksız üçüncü düğme
/// eklese, sunucu göçü uygulanmadan her dokunuş "Düello başlatılamadı" ile
/// düşerdi ama hiçbir test bunu kırmızı göstermezdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/services/matchmaking_metrics.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Eşleşme kuyruğuna katılır ama hiç rakip bulunamaz: `joinMatchmaking`
/// hep 'waiting' döner, kuyruk aboneliği hiç veri yaymaz ve 20 sn zaman
/// aşımında çağrılan `cancelMatchmaking` da eşleşmemiş ('cancelled')
/// döner. `matchmaking_screen_test.dart`'taki `_CancellationRaceRepository`
/// ile aynı desen — bot/sırayla düello teklifinin tetiklenmesi için
/// gereken tek senaryo budur.
class _NoOpponentRepository extends MockZanKurdRepository {
  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {'status': 'waiting'};
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() {
    return const Stream.empty();
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    return const {'status': 'cancelled'};
  }
}

/// `matchmaking_screen_test.dart`taki aynı adlı yardımcının bilinçli
/// kopyası: Dart'ta üst düzey `_` adları dosyaya (kütüphaneye) özeldir,
/// iki test dosyası aynı özel sembolü paylaşamaz.
Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  testWidgets(
    'asyncDuelEnabled açıkken zaman aşımı üç seçenekli diyalog gösterir, '
    'sırayla düello seçilince eşleşme ekranı yerini ona bırakır ve bekleme '
    'metriğini asyncDuel sonucuyla kaydeder',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final events = <Map<String, Object>>[];
      final elapsedValues = [Duration.zero, const Duration(seconds: 20)];
      final metrics = MatchmakingMetrics(
        elapsed: () => elapsedValues.removeAt(0),
        record: events.add,
      );
      final repository = _NoOpponentRepository();

      await tester.pumpWidget(
        _shell(
          MatchmakingScreen(
            repository: repository,
            metrics: metrics,
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rastgele eşleşme'));
      await tester.pump(const Duration(seconds: 20));

      // Üç düğme de soldan sağa sırayla var: cancel, bot, asyncDuel.
      expect(find.byKey(const ValueKey('mm-offer-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('mm-offer-bot')), findsOneWidget);
      expect(find.byKey(const ValueKey('mm-offer-async-duel')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mm-offer-async-duel')));
      // NOT: `pumpAndSettle` KULLANILMAZ — sırayla düello ekranındaki 20
      // sn'lik geri sayım aktif bir ticker'dır; settle sayacı sıfıra
      // indirip istemeden bir TIMEOUT tetikler (bkz. dosya başlığı).
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
      expect(find.byType(MatchmakingScreen), findsNothing);
      expect(events, [
        {'outcome': 'async_duel', 'wait_seconds': 20},
      ]);
    },
  );

  testWidgets(
    'asyncDuelEnabled parametresi verilmezse kAsyncDuelEnabled varsayılanını '
    'kullanır — bayrak açılırsa bu test kırılmaz',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repository = _NoOpponentRepository();

      await tester.pumpWidget(
        _shell(MatchmakingScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rastgele eşleşme'));
      await tester.pump(const Duration(seconds: 20));

      // Beklenti bilerek bayrağa bağlıdır: `kAsyncDuelEnabled` `applied.md`
      // güncellenip `true` yapıldığında bu test kendiliğinden yeni
      // varsayılanı sınamaya döner, eski varsayımda takılı kalmaz.
      expect(
        find.byKey(const ValueKey('mm-offer-async-duel')),
        kAsyncDuelEnabled ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Hayır'),
        kAsyncDuelEnabled ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Evet'),
        kAsyncDuelEnabled ? findsNothing : findsOneWidget,
      );
    },
  );

  testWidgets('Rastgele seçiminde sırayla düello ekranı kategorisiz açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = _NoOpponentRepository();

    await tester.pumpWidget(
      _shell(MatchmakingScreen(repository: repository, asyncDuelEnabled: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rastgele eşleşme'));
    await tester.pump(const Duration(seconds: 20));
    await tester.tap(find.byKey(const ValueKey('mm-offer-async-duel')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final screen = tester.widget<AsyncDuelPlayScreen>(
      find.byType(AsyncDuelPlayScreen),
    );
    expect(screen.category, isNull);
  });

  testWidgets(
    'belirli kategori seçiminde sırayla düello ekranı o kategoriyle açılır',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repository = _NoOpponentRepository();

      await tester.pumpWidget(
        _shell(
          MatchmakingScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      // 'Dil' — K.catZiman'ın Türkçe karşılığı ('Ziman' kategorisi).
      await tester.tap(find.text('Dil'));
      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.byKey(const ValueKey('mm-offer-async-duel')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final screen = tester.widget<AsyncDuelPlayScreen>(
        find.byType(AsyncDuelPlayScreen),
      );
      expect(screen.category, 'Ziman');
    },
  );
}
