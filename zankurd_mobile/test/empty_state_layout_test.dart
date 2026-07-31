import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/app_state.dart';

import 'support/widget_test_helpers.dart';

/// Boş durum paneli, kaydırılan bir listenin içinde de çizilebilmeli.
///
/// 2026-07-26: `AppEmptyState` yüksekliği `constraints.maxHeight - 48` ile
/// kuruyordu. Kaydırılan bir kapsayıcının içinde `maxHeight` sonsuzdur;
/// çıkarma da sonsuz kalır ve düzen çöker. Sonuç, **arkadaşı olmayan her
/// yeni kullanıcının** arkadaşlar ekranını kırmızı görmesiydi — yani kusur
/// tam olarak ilk kullanımda ortaya çıkıyordu.
///
/// Depo dolu geldiği için ne testler ne ekran turu bunu görmüştü; boş liste
/// hiç denenmemişti.
class _NoFriendsRepository extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
  });

  testWidgets('arkadaşı olmayan kullanıcı ekranı sorunsuz açar', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: FriendsScreen(repository: _NoFriendsRepository())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Arkadaş yok'), findsOneWidget);
  });

  testWidgets('boş durum paneli sınırsız yükseklikte de çizilir', (
    tester,
  ) async {
    // Kuralın kendisi: panel, yüksekliği sınırsız bir kapsayıcının içinde
    // de çizilmeli. Ekran üzerinden değil doğrudan widget üzerinden
    // ölçülür — böylece bir sonraki kullanım yeri de korunur.
    await tester.pumpWidget(
      testShell(
        child: ListView(
          children: const [
            AppEmptyState(
              icon: AppIcons.peopleGroup,
              title: 'Boş',
              message: 'Burada henüz bir şey yok.',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Boş'), findsOneWidget);
  });

  testWidgets('sınırlı yükseklikte panel yine ortalanır ve kaydırılabilir', (
    tester,
  ) async {
    // Karşı taraf: sınırsız dal eklenirken sınırlı dalın kaybolmadığından
    // emin olunur. Yalnız birini yazmak, "her zaman düz dolgu" gibi yanlış
    // bir düzeltmeyi de geçirirdi.
    await tester.pumpWidget(
      testShell(
        child: const SizedBox(
          height: 300,
          child: AppEmptyState(
            icon: AppIcons.peopleGroup,
            title: 'Boş',
            message: 'Burada henüz bir şey yok.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
