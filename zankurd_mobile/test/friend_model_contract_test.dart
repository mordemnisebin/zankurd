import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/friend.dart';

/// `Friend.fromJson` her `list_friends` satırında çöküyordu.
///
/// ## Kusur
///
/// `list_friends` RPC'si (supabase/2026-08-06_friend_identity_and_resend.sql
/// ve öncesindeki her sürümü) yalnız beş kolon döndürür:
/// `id, friend_id, friend_name, friend_avatar_color, created_at`.
/// `user_id` hiçbir sürümde dönmedi — satır zaten çağıran kullanıcıya
/// ait olduğu için sunucu tarafında filtre olarak kullanılır, seçilen
/// kolon değildir.
///
/// `Friend.fromJson` yine de `json['user_id'] as String` diye zorunlu
/// cast yapıyordu. Liste boşken sorun görünmezdi (map hiç çalışmaz);
/// ama bir arkadaşlık isteği kabul edilir edilmez `loadFriends()` bir
/// satır döndürür, cast `null` üzerinde patlar,
/// `SupabaseZanKurdRepository` bunu yakalayıp `_offline.loadFriends()`
/// = `const []` döner. Kullanıcı hiçbir hata görmez — FriendsScreen ve
/// Liderlik > Arkadaşlar sekmesi sonsuza kadar "Arkadaş yok" yazar
/// (2026-08-14 denetimi).
///
/// Kardeş model `FriendRequest.toUserId` (friend.dart:132) bu kusur
/// sınıfını zaten yaşamış ve `as String? ?? ''` ile düzeltilmişti;
/// `Friend.userId` gözden kaçmıştı.
void main() {
  group('Friend.fromJson — list_friends sözleşmesi', () {
    /// `list_friends`'in gerçek dönüş şekli — user_id YOK.
    Map<String, dynamic> serverRow({String friendName = 'Rojda'}) => {
      'id': 'f1',
      'friend_id': 'u2',
      'friend_name': friendName,
      'friend_avatar_color': '#4CAF50',
      'created_at': '2026-08-14T10:00:00Z',
    };

    test('user_id olmadan çökmez', () {
      expect(() => Friend.fromJson(serverRow()), returnsNormally);
    });

    test('arkadaş adı ve kimliği doğru okunur', () {
      final friend = Friend.fromJson(serverRow(friendName: 'Berfin'));
      expect(friend.friendId, 'u2');
      expect(friend.friendName, 'Berfin');
      expect(friend.userId, ''); // sunucu vermiyor; boş varsayılan
    });

    test('sıralama alanları (total_score/level) sunucu verirse okunur', () {
      final row = serverRow()
        ..addAll({'total_score': 8420, 'level': 12, 'games_played': 30});
      final friend = Friend.fromJson(row);
      expect(friend.totalScore, 8420);
      expect(friend.level, 12);
      expect(friend.gamesPlayed, 30);
    });
  });
}
