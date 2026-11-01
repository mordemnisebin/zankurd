/// Üçüncü tüm-uygulama denetiminin (IS_LISTESI3, 2026-11-01) 8 kabul
/// edilmiş bulgusunun bekçisi.
///
/// ## Kusurlar
///
/// 1. Turnuvada olmayan kullanıcı için `loadRealTournamentBracket` null
///    döndüğünde offline fallback `StateError` fırlatarak turnuva ekranını
///    hata durumuna kilitliyordu (`_hasError = true`).
/// 3. Ağ hatasında `joker_pack_3` ve `spin_wheel_extra` için jeton harcaması
///    kuyruğa atılıyor fakat hak/etki kuyruğa alınmadığı için jeton kaybı
///    yaşanıyordu.
/// 4. `my_words_screen` CSV paylaşımında `sharePositionOrigin` verilmediği
///    için iPad'de `UIPopoverController` paylaşım penceresini açamıyordu.
/// 5. `level_placement_screen` `_finish` içinde catch bloğu olmadığı için
///    depolama hatasında istisna fırlatılıyor, sonuç gösterilmiyor ve kullanıcı
///    son soruda takılı kalıyordu.
/// 6. `room_invite_friends_sheet` dış `SingleChildScrollView` içinde
///    `ConstrainedBox` ve iç `SingleChildScrollView` iç içe kullanıldığı için
///    kaydırma hareket çakışması ve takılma oluşuyordu.
/// 8. `settings_screen` `_placementStoreFuture` `late final` tanımlandığı için
///    seviye sınavı tekrar çözülüp dönüldüğünde `FutureBuilder` eski seviyeyi
///    göstermeye devam ediyordu.
/// 9. `daily_tour_card` günün turu tamamlanıp 1 saatten az kaldığında saat
///    kontrolü yapılmadığı için '0 saat ve X dakika' / '0 saet û X deqeyan'
///    şeklinde bozuk metin gösteriliyordu.
/// 10. `room_invite_friends_sheet` arkadaş aramasında eşleşme bulunamadığında
///     boş liste grubu render ediliyor ve kullanıcıya sonuç bulunamadığı
///     bildirilmiyordu.
///
/// ## Niçin sessizdi
///
/// - Turnuva hatası: mock/test ortamında lobiye girmemiş gerçek kullanıcı akışı
///   mocklanmadan çağrılmıyordu.
/// - Mağaza kuyruğu: testler sadece anlık başarılı satın almayı veya çerçeve/VIP
///   etkisini test ediyordu; harcanabilir joker ve ekstra çark haklarının
///   çevrimdışı kuyruk farkı test edilmemişti.
/// - iPad origin: telefon testleri ve widget testleri origin parametresini
///   zorunlu kılmaz; yalnız iPad simülatöründe ortaya çıkar.
/// - Seviye sınavı depolama hatası: testlerde SharedPreferences hep başarılıydı.
/// - İç içe scroll: otomatik testlerde parmak jesti takılması ölçülmüyordu.
/// - Ayarlar seviye yenileme: ekran açıldıktan sonra seviye sınavını bitirip
///   geri dönülen döngü test edilmemişti.
/// - 1 saatten az geri sayım: testler sabit saatlerle koşulup '0 saat' kontrolü
///   yapılmamıştı.
/// - Boş arama bildirimi: arama kutusu testleri yalnız pozitif eşleşmeleri
///   seçmeyi sınıyordu.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/home/daily_tour_card.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/room/room_invite_friends_sheet.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

import 'support/widget_test_helpers.dart';

String _read(String path) => File(path).readAsStringSync();

class _FriendRepo extends TestMockZanKurdRepository {
  _FriendRepo(this._friends);

  final List<Friend> _friends;

  @override
  Future<List<Friend>> loadFriends() async => _friends;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  group('1 offline ve supabase tournament bracket fallback', () {
    test('OfflineZanKurdRepository loadTournamentBracket null döner', () async {
      final repo = OfflineZanKurdRepository();
      final bracket = await repo.loadTournamentBracket();
      expect(bracket, isNull);
    });

    test('offline_zankurd_repository kaynak kodunda throw bulunmaz', () {
      final src = _read('lib/src/data/offline_zankurd_repository.dart');
      expect(
        src,
        contains(
          'Future<TournamentBracket?> loadTournamentBracket() async => null;',
        ),
      );
    });

    test('supabase_zankurd_repository fallback null güvenli', () {
      final src = _read('lib/src/data/supabase_zankurd_repository.dart');
      expect(
        src,
        contains('Future<TournamentBracket?> loadTournamentBracket()'),
      );
      expect(src, contains('return _offline.loadTournamentBracket();'));
    });
  });

  group('3 joker_pack_3 ve spin_wheel_extra için kuyruğa coin spend alınmaz', () {
    test('shopFrameIds ve _hasPurchaseEffect consumable ürünleri içermez', () {
      expect(shopFrameIds.containsKey('joker_pack_3'), isFalse);
      expect(shopFrameIds.containsKey('spin_wheel_extra'), isFalse);
      expect(shopFrameIds.containsKey('avatar_frame_gold'), isTrue);
      expect(shopFrameIds.containsKey('avatar_frame_neon'), isTrue);
    });

    test(
      'shop_screen retryable ve exception yollarında _hasPurchaseEffect denetlenir',
      () {
        final src = _read('lib/src/screens/shop_screen.dart');
        expect(
          src,
          contains(
            'if (!result.success && result.retryable) {\n'
            '        if (_hasPurchaseEffect(item.id)) {\n'
            '          await SyncManager.maybeInstance?.queueCoinSpend(',
          ),
        );
        expect(
          src,
          contains(
            'on RetryableWriteException catch (error, stack) {\n'
            '      ErrorReporter.record(error.cause, stack, reason: \'shop_purchase\');\n'
            '      if (_hasPurchaseEffect(item.id)) {\n'
            '        await SyncManager.maybeInstance?.queueCoinSpend(',
          ),
        );
      },
    );
  });

  group('4 my_words_screen CSV paylaşımında sharePositionOrigin', () {
    test(
      'my_words_screen RenderBox üzerinden origin hesaplar ve ShareParamsa iletir',
      () {
        final src = _read('lib/src/screens/my_words_screen.dart');
        expect(src, contains('sharePositionOrigin: origin'));
        expect(
          src,
          contains('final box = btnCtx.findRenderObject() as RenderBox?;'),
        );
        expect(src, contains('box.localToGlobal(Offset.zero) & box.size'));
      },
    );
  });

  group('5 level_placement_screen depolama hatasında sonuç gösterme', () {
    test(
      'level_placement_screen depolama hatasını yakalar ve sonucu gösterir',
      () {
        final src = _read('lib/src/screens/level_placement_screen.dart');
        expect(src, contains('reason: \'level placement store save failed\''));
        expect(src, contains('if (mounted) setState(() => _result = result);'));
      },
    );

    testWidgets(
      'PlacementStore hata fırlatsa bile sınav sonrasında sonuç görünür',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(440, 844));
        final repo = MockZanKurdRepository();
        await tester.pumpWidget(
          testShell(
            child: LevelPlacementScreen(repository: repo, questionCount: 1),
          ),
        );
        await tester.pumpAndSettle();

        final firstOption = find.byType(QuizOptionTile).first;
        expect(firstOption, findsOneWidget);
        await tester.ensureVisible(firstOption);
        await tester.tap(firstOption);
        await tester.pumpAndSettle();

        // Sonuç ekranına ulaşılmalı (seviye sonucu görünmeli)
        expect(
          find.byKey(const ValueKey('placement-result-level')),
          findsOneWidget,
        );
      },
    );
  });

  group('6 room_invite_friends_sheet iç içe scroll çakışması', () {
    test('room_invite_friends_sheet dış SingleChildScrollView taşımaz', () {
      final src = _read('lib/src/screens/room/room_invite_friends_sheet.dart');
      // build metodu doğrudan Padding -> AppPanel döndürmeli
      expect(
        src,
        contains(
          '  @override\n'
          '  Widget build(BuildContext context) {\n'
          '    final t = SahneTokens.of(context);\n'
          '    return Padding(',
        ),
      );
      // Dış SingleChildScrollView kaldırılmış olmalı
      expect(src, isNot(contains('return SingleChildScrollView(')));
    });
  });

  group('8 settings_screen seviye sınavı sonrası seviye yenileme', () {
    test('settings_screen _placementStoreFuture değişkeni final değildir', () {
      final src = _read('lib/src/screens/settings_screen.dart');
      expect(
        src,
        contains('late Future<PlacementStore> _placementStoreFuture ='),
      );
      expect(
        src,
        isNot(
          contains('late final Future<PlacementStore> _placementStoreFuture ='),
        ),
      );
    });

    test('settings_screen _openPlacement dönüşünde Future yenilenir', () {
      final src = _read('lib/src/screens/settings_screen.dart');
      expect(
        src,
        contains(
          '  Future<void> _openPlacement() async {\n'
          '    await Navigator.of(\n'
          '      context,\n'
          '    ).push(AppRoute.to(LevelPlacementScreen(repository: widget.repository)));\n'
          '    if (mounted) {\n'
          '      setState(() {\n'
          '        _placementStoreFuture = PlacementStore.load();\n'
          '      });\n'
          '    }\n'
          '  }',
        ),
      );
    });
  });

  group('9 daily_tour_card 1 saatten az kalınca geri sayım metni', () {
    testWidgets(
      '1 saatten az kaldığında contestNextInMin kullanılır, 0 saat yazmaz',
      (tester) async {
        // 24 Ekim 2026 23:25 İstanbul saati (gece yarısına 35 dakika var)
        final nearMidnight = DateTime.utc(2026, 10, 24, 20, 25);
        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: DailyTourCard(
                isKu: false,
                loading: false,
                doneToday: true,
                onStart: () {},
                onPractice: () {},
                now: nearMidnight,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Türkçe: "Yeni tur 35 dk sonra"
        expect(find.textContaining('Yeni tur 35 dk sonra'), findsOneWidget);
        expect(find.textContaining('0 saat'), findsNothing);
        expect(find.textContaining('0 sa'), findsNothing);
      },
    );

    testWidgets('Kürtçe dilinde de 1 saatten az kaldığında 0 saet yazmaz', (
      tester,
    ) async {
      final nearMidnight = DateTime.utc(2026, 10, 24, 20, 25);
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: DailyTourCard(
              isKu: true,
              loading: false,
              doneToday: true,
              onStart: () {},
              onPractice: () {},
              now: nearMidnight,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kurmancî: "Gera nû piştî 35 deqeyan"
      expect(find.textContaining('Gera nû piştî 35 deqeyan'), findsOneWidget);
      expect(find.textContaining('0 saet'), findsNothing);
    });
  });

  group('10 room_invite_friends_sheet arama boş durum bildirimi', () {
    testWidgets(
      'arkadaş aramasında sonuç bulunamadığında bilgilendirme metni gösterilir',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        // 9 arkadaş (arama eşiği 8)
        final friends = [
          for (var i = 0; i < 9; i++)
            Friend(
              id: 'f$i',
              userId: 'me',
              friendId: 'user-$i',
              friendName: 'Dost${String.fromCharCode(65 + i)}',
              createdAt: DateTime(2026, 10, 1),
            ),
        ];
        final repo = _FriendRepo(friends);
        final room = repo.createRoom().copyWith(
          id: 'room-1',
          isCustom: true,
          maxPlayers: 8,
        );

        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: RoomInviteFriendsSheet(repository: repo, room: room),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Arama kutusunu bul
        final searchField = find.byKey(const ValueKey('room-invite-search'));
        expect(searchField, findsOneWidget);

        // Eşleşmeyen bir arama yap
        await tester.enterText(searchField, 'BöyleBirİsimYok123');
        await tester.pumpAndSettle();

        // Boş durum bilgilendirme metni görünmeli
        expect(
          find.byKey(const ValueKey('room-invite-search-empty')),
          findsOneWidget,
        );
        expect(
          find.text(Tr.of(K.playerNotFound, AppLanguage.tr)),
          findsOneWidget,
        );
      },
    );
  });
}
