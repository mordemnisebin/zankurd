import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/widgets/friend_activity_label.dart';

import 'support/widget_test_helpers.dart';

Friend presenceFriend({DateTime? seen, DateTime? active}) => Friend.fromJson({
  'id': 'f',
  'friend_id': 'u',
  'friend_name': 'Rojda',
  'created_at': '2026-01-01T00:00:00Z',
  'last_seen_at': seen?.toIso8601String(),
  'last_active_at': active?.toIso8601String(),
});

class _Friends extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => [
    presenceFriend(seen: DateTime.now()).copyWith(friendName: 'Rojda'),
    presenceFriend(active: DateTime.now()).copyWith(friendName: 'Diyar'),
    presenceFriend(
      seen: DateTime.now().subtract(const Duration(days: 2)),
    ).copyWith(friendName: 'Berfin'),
  ];
}

void main() {
  testWidgets('T1 yeşil nokta yalnız izinli kalp atışında görünür; eski '
      'örnekler güncel profil tarihini çevrimiçi sanıyordu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(child: FriendsScreen(repository: _Friends())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-online-dot')), findsOneWidget);
    expect(find.text('Çevrimiçi'), findsOneWidget);
    expect(find.text('2 gün önce etkindi'), findsOneWidget);
    expect(find.text('Son 24 saatte etkindi'), findsNothing);
    final unknown = find.byKey(const ValueKey('friend-row-Diyar'));
    expect(
      find.descendant(of: unknown, matching: find.text('Çevrimiçi')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('T1 profil zenginleştirme son görülmeyi düşürmez; eski copyWith '
      'yalnız XP zamanını taşıyordu', () {
    final seen = DateTime.utc(2026, 10, 30);
    final friend = presenceFriend(seen: seen).copyWith(level: 7);
    expect(friend.lastSeenAt, seen);
    expect(friend.toJson()['last_seen_at'], '2026-10-30T00:00:00.000Z');
  });

  test('T1 XP/ad güncellemesi çevrimiçi sayılmaz; eski testler profil '
      'zamanını varlık sanıyordu', () {
    expect(presenceFriend(active: DateTime.now()).isOnline, isFalse);
  });

  test('T1 üç dakika sınırı ve gelecek tarih; beş dakikalık XP vekili '
      'misafirin gerçek varlığını gizliyordu', () {
    final now = DateTime.now();
    expect(presenceFriend(seen: now).isOnline, isTrue);
    expect(
      presenceFriend(seen: now.subtract(const Duration(seconds: 179))).isOnline,
      isTrue,
    );
    expect(
      presenceFriend(seen: now.subtract(const Duration(minutes: 3))).isOnline,
      isFalse,
    );
    expect(
      presenceFriend(seen: now.add(const Duration(minutes: 1))).isOnline,
      isFalse,
    );
  });

  testWidgets('T1 gizli/eksik varlıkta etiket yok; eski XP alanına geri '
      'düşüş gizlilik tercihini sessizce deliyordu', (tester) async {
    final labels = <String?>[];
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) {
            for (final friend in [
              presenceFriend(active: DateTime.now()),
              presenceFriend(seen: DateTime.now()),
              presenceFriend(
                seen: DateTime.now().subtract(const Duration(hours: 4)),
              ),
              presenceFriend(
                seen: DateTime.now().subtract(const Duration(hours: 49)),
              ),
            ]) {
              labels.add(friendActivityLabel(context, friend));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(labels, [
      null,
      'Çevrimiçi',
      'Son 24 saatte etkindi',
      '2 gün önce etkindi',
    ]);
  });
}
