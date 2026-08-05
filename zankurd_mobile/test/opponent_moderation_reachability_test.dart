import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_moderation_button.dart';

/// Bildir/engelle, içerikle KARŞILAŞILAN yerde bulunmalı.
///
/// ## Kusur
///
/// Mekanizmalar vardı ama yerleşim yoktu. Depoda `blockPlayer`ın tek
/// çağıranı `room_chat.dart`ti ve oraya yalnız bir **long-press** ile
/// ulaşılıyordu; `reportPlayerProfile`ın tek çağıranı liderlik ekranıydı
/// ve o liste `loadLeaderboard(limit: 10)` ile çekiliyordu.
///
/// Oysa rakibin YÜKLEDİĞİ avatar fotoğrafı ve adı, eşleştirme VS kartında
/// tam ekran ve oda oyuncu listesinde satır satır gösteriliyor. O iki
/// ekranda hiçbir moderasyon aracı yoktu:
///
///   • Sıradan bir rakip ilk 10'a girmediği için liderlikten bildirilemez.
///   • Sohbete hiç mesaj yazmamış bir rakip long-press ile engellenemez.
///
/// Avatar, uygulamanın en filtresiz UGC yüzeyi:
/// `2026-08-02_profile_report_moderation.sql` kovanın yalnız MIME türünü
/// ve 2 MB sınırını denetlediğini yazıyor. Apple Guideline 1.2 ve Play
/// UGC politikası aracın karşılaşma noktasında olmasını bekler
/// (2026-08-06 denetimi).
///
/// ## Bekçi
///
/// Eski bekçi (`profile_ugc_moderation_test.dart`) yalnız liderlik
/// ekranının dizelerini doğruluyordu — tam da bu yüzden kör kaldı. Bu
/// bekçi ekranların KENDİSİNE bakar.
void main() {
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('moderasyon düğmesi', () {
    testWidgets('yabancı oyuncuda görünür', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerModerationButton(
            repository: MockZanKurdRepository(),
            playerId: 'other-player',
            playerName: 'Berfin',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('player-moderation-button')),
        findsOneWidget,
      );
    });

    testWidgets('kendi satırında GÖRÜNMEZ', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerModerationButton(
            repository: MockZanKurdRepository(),
            playerId: 'me',
            playerName: 'Ben',
            isSelf: true,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('player-moderation-button')),
        findsNothing,
        reason: 'İnsan kendini bildiremez/engelleyemez',
      );
    });

    testWidgets('bot rakipte (kimliksiz) görünmez', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerModerationButton(
            repository: MockZanKurdRepository(),
            playerId: null,
            playerName: 'Bot',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('player-moderation-button')),
        findsNothing,
        reason: 'Sunucuya gönderilecek bir kimlik yok',
      );
    });

    testWidgets('dokunuş hem bildir hem engelle sunuyor', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerModerationButton(
            repository: MockZanKurdRepository(),
            playerId: 'other-player',
            playerName: 'Berfin',
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player-report-action')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('player-block-action')), findsOneWidget);
    });

    testWidgets('dokunma hedefi 44x44 altına düşmüyor', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerModerationButton(
            repository: MockZanKurdRepository(),
            playerId: 'other-player',
            playerName: 'Berfin',
            compact: true,
          ),
        ),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('player-moderation-button')),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('karşılaşma yüzeylerinde gerçekten bağlı', () {
    test('eşleştirme VS kartı moderasyon düğmesi taşıyor', () {
      final source = File(
        'lib/src/screens/matchmaking_screen.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('PlayerModerationButton('),
        reason:
            'Rakibin yüklediği fotoğraf burada tam ekran gösteriliyor; '
            'moderasyon aracı da burada olmalı',
      );
      expect(
        source,
        contains('playerId: _opponentId'),
        reason: 'Bot rakipte kimlik null kalmalı, düğme kendiliğinden gizlenir',
      );
    });

    test('oda oyuncu satırı moderasyon düğmesi taşıyor', () {
      final source = File(
        'lib/src/screens/room_screen.dart',
      ).readAsStringSync();
      expect(source, contains('PlayerModerationButton('));
      expect(
        source,
        contains('isSelf:'),
        reason: 'Kendi satırında gösterilmemeli',
      );
    });

    test('gizli long-press tek yol olmaktan çıktı', () {
      // room_chat'teki sheet duruyor (mesaja özel bildirme oradan
      // anlamlı), ama artık TEK yol değil.
      final chat = File('lib/src/widgets/room_chat.dart').readAsStringSync();
      expect(chat, contains('onLongPress'));

      final matchmaking = File(
        'lib/src/screens/matchmaking_screen.dart',
      ).readAsStringSync();
      expect(
        matchmaking.contains('PlayerModerationButton('),
        isTrue,
        reason:
            'Keşfedilemeyen bir moderasyon aracı, moderasyon aracı '
            'sayılmaz',
      );
    });

    test('yeni backend eklenmedi — mevcut RPC\'ler kullanılıyor', () {
      final button = File(
        'lib/src/widgets/player_moderation_button.dart',
      ).readAsStringSync();
      expect(button, contains('reportPlayerProfile('));
      expect(button, contains('blockPlayer('));
      expect(
        button,
        isNot(contains('.rpc(')),
        reason: 'Bu bir yerleşim düzeltmesi; yeni sunucu yolu gerekmiyor',
      );
    });
  });
}
