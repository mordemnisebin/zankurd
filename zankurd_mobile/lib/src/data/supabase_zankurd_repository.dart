import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_identity.dart';
import '../models/contest.dart';
import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/room_message.dart';
import '../models/tournament.dart';
import '../utils/error_reporter.dart';
import '../config/category_visibility.dart';
import 'mock_zankurd_repository.dart';
import 'zankurd_repository.dart';
import '../services/question_content_policy.dart';

class _ManagedRoomChannel {
  _ManagedRoomChannel(this.channel);

  final RealtimeChannel channel;
  int listenerCount = 0;
}

RoomStatus _roomStatusFromValue(Object? value) {
  return switch (value) {
    'active' => RoomStatus.active,
    'finished' => RoomStatus.finished,
    _ => RoomStatus.lobby,
  };
}

class SupabaseZanKurdRepository implements ZanKurdRepository {
  SupabaseZanKurdRepository(this.client);

  static const _contentPolicy = QuestionContentPolicy();
  static const _defaultAvatarColor = '#2E9E93';

  final MockZanKurdRepository _offline = MockZanKurdRepository();

  @override
  List<String> get categories => _offline.categories;

  @override
  List<QuizQuestion> get questions => _offline.questions;

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  List<QuizLevel> levelsForCategory(String category) =>
      _offline.levelsForCategory(category);

  @override
  GameRoom joinRoom(String code) => _offline.joinRoom(code);

  final SupabaseClient client;
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Oda başına tek realtime kanalı; gönderme ve dinleme paylaşır.
  /// Dinleyici referans sayısı tutulur; tek abonelik iptalinde ortak kanal
  /// kapatılmaz.
  final Map<String, _ManagedRoomChannel> _roomChannels = {};

  _ManagedRoomChannel _ensureRoomChannel(String roomId) {
    return _roomChannels.putIfAbsent(roomId, () {
      final channel = client.channel('room:$roomId');
      channel.subscribe();
      return _ManagedRoomChannel(channel);
    });
  }

  RealtimeChannel _retainRoomChannel(String roomId) {
    final managed = _ensureRoomChannel(roomId);
    managed.listenerCount++;
    return managed.channel;
  }

  Future<void> _releaseRoomChannel(String roomId) async {
    final managed = _roomChannels[roomId];
    if (managed == null) return;
    if (managed.listenerCount > 0) {
      managed.listenerCount--;
    }
    if (managed.listenerCount > 0) return;
    _roomChannels.remove(roomId);
    await client.removeChannel(managed.channel);
  }

  Future<void> _disposeUnretainedRoomChannel(String roomId) async {
    final managed = _roomChannels[roomId];
    if (managed == null || managed.listenerCount > 0) return;
    _roomChannels.remove(roomId);
    await client.removeChannel(managed.channel);
  }

  @visibleForTesting
  int debugRoomChannelListenerCount(String roomId) =>
      _roomChannels[roomId]?.listenerCount ?? 0;

  @visibleForTesting
  bool debugHasRoomChannel(String roomId) => _roomChannels.containsKey(roomId);

  Future<User> signInAnonymously() async {
    final response = await client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw StateError('Anonymous sign-in did not return a user.');
    }
    return user;
  }

  /// Profili yazar. [avatarColor] verilmezse renk alanına HİÇ dokunulmaz.
  ///
  /// Eskiden varsayılan `'#E94560'` idi ve iki ayrı zarar veriyordu.
  ///
  /// 1. O hex marka paletinin dışında. `avatar_presets.dart` iki liste
  ///    tutuyor — kullanıcının seçebileceği 8 marka tonu (`avatarColors`)
  ///    ve isim hash'ine eşlenen 12 ton (`avatarNamePalette`) — ve
  ///    `#E94560` ikisinde de yok. Her yeni kullanıcı, hiç seçmediği ve
  ///    hiçbir yerden seçemeyeceği bir pembeyle başlıyordu.
  ///
  /// 2. Daha kötüsü: `updateProfileName` de bu fonksiyonu çağırıyor ve
  ///    varsayılan yazıldığı için ADINI DEĞİŞTİREN KULLANICI seçtiği
  ///    avatar rengini kaybediyordu.
  ///
  /// Renk yazılmadığında sütun null kalır ve `avatarColorForName`
  /// devreye girer — sistem zaten bunun için tasarlanmış: isme bağlı
  /// deterministik ton, `resolveAvatarColors` ile aynı ekrandaki çakışma
  /// çözümü dahil (2026-08-01, canlı profil ve liderlik ekranında
  /// görüldü).
  Future<void> upsertProfile({
    required String displayName,
    String? avatarColor,
  }) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'avatar_color': ?avatarColor,
    });
  }

  /// Profil satırı yoksa oluşturur; varsa adı EZMEZ.
  /// Yeni profil adı, kayıt sırasında verilen display_name'den gelir.
  @override
  Future<void> ensureProfile() async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    final metadataName = user.userMetadata?['display_name'];
    await upsertProfile(
      displayName: metadataName is String && metadataName.trim().isNotEmpty
          ? metadataName.trim()
          : 'ZanKurd Oyuncusu',
      avatarColor: _defaultAvatarColor,
    );
  }

  @override
  Future<String?> getPlayerTag() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;
      final profile = await client
          .from('profiles')
          .select('player_tag')
          .eq('id', user.id)
          .maybeSingle();
      final tag = profile?['player_tag'] as String?;
      if (tag != null && tag.trim().isNotEmpty) return tag.trim();
    } on PostgrestException catch (error, stack) {
      // Göç uygulanmadan önce sütun yok (42703). Bu bir hata değil,
      // "henüz kod yok" demek — çökme raporuna gitmesi gürültü olur.
      if (error.code != '42703') {
        _recordError(error, stack, reason: 'getPlayerTag failed');
      }
    } catch (error, stack) {
      _recordError(error, stack, reason: 'getPlayerTag failed');
    }
    return null;
  }

  @override
  Future<String> getProfileName() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return 'ZanKurd Oyuncusu';
      final profile = await client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && profile['display_name'] != null) {
        return (profile['display_name'] as String?) ?? 'ZanKurd Oyuncusu';
      }
    } catch (error, stack) {
      _recordError(error, stack, reason: 'getProfileName failed');
    }
    return 'ZanKurd Oyuncusu';
  }

  @override
  Future<void> updateProfileName(String name) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    await upsertProfile(
      displayName: name,
      // Yeni satırda canlı trigger'ın kabul ettiği geçerli rengi gönder;
      // mevcut satırda avatar seçimini ad değişimi ezmesin.
      avatarColor: existing == null ? _defaultAvatarColor : null,
    );
  }

  @override
  Future<AvatarIdentity> loadAvatarIdentity() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return _offline.loadAvatarIdentity();
      final row = await client
          .from('profiles')
          .select(
            'avatar_icon, avatar_color, avatar_url, avatar_frame, showcase_title',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return const AvatarIdentity();
      return AvatarIdentity(
        iconId: row['avatar_icon'] as String?,
        colorHex: row['avatar_color'] as String?,
        photoUrl: row['avatar_url'] as String?,
        frameId: row['avatar_frame'] as String?,
        showcaseTitle: row['showcase_title'] as String?,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadAvatarIdentity failed');
      return _offline.loadAvatarIdentity();
    }
  }

  @override
  Future<void> updateAvatarIdentity(AvatarIdentity identity) async {
    // Yereli her durumda güncelle: çevrimdışı görünürlük + fallback tutarlılığı.
    await _offline.updateAvatarIdentity(identity);
    try {
      final user = client.auth.currentUser;
      if (user == null) return;
      await client
          .from('profiles')
          .update({
            'avatar_icon': identity.iconId,
            'avatar_color': identity.colorHex,
            'avatar_url': identity.photoUrl,
            'avatar_frame': identity.frameId,
            'showcase_title': identity.showcaseTitle,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (error, stack) {
      _recordError(error, stack, reason: 'updateAvatarIdentity failed');
    }
  }

  @override
  Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType) async {
    final user = client.auth.currentUser;
    if (user == null) {
      return _offline.uploadAvatarPhoto(bytes, contentType);
    }
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final path = '${user.id}/avatar.$ext';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    // Aynı yol üzerine yazıldığı için URL sabit kalır; önbellek kırıcı ekle.
    final publicUrl = client.storage.from('avatars').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> deleteMyAccount() async {
    try {
      await client.rpc('delete_my_account');
    } catch (error, stack) {
      _recordError(error, stack, reason: 'delete_my_account failed');
      rethrow;
    }
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final row = await client
          .from('leaderboard_entries')
          .select('*')
          .eq('player_id', user.id)
          .maybeSingle();

      if (row == null) return null;

      return LeaderboardEntry(
        rank: row['rank'] != null ? (row['rank'] as num).toInt() : 0,
        playerId: row['player_id'] as String,
        displayName: row['display_name'] as String,
        totalScore: row['total_score'] != null
            ? (row['total_score'] as num).toInt()
            : 0,
        bestStreak: row['best_streak'] != null
            ? (row['best_streak'] as num).toInt()
            : 0,
        roomsPlayed: row['rooms_played'] != null
            ? (row['rooms_played'] as num).toInt()
            : 0,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'getPlayerStats failed');
      return null;
    }
  }

  @override
  Future<List<String>> loadCategories() async {
    return _retryOnNetworkFailure(() async {
      final rows = await client
          .from('categories')
          .select('name')
          .eq('is_active', true)
          .order('name');
      // Uygulama içi gizli kategoriler (içerik hazır olana dek) listeden
      // düşülür; veritabanına dokunulmaz.
      return visibleCategories(rows.map((row) => row['name'] as String));
    });
  }

  @override
  /// Kategori başına soru sayısı — **soruların gerçekten geldiği yerden**.
  ///
  /// Bu sayı bir zamanlar SUNUCUDAN okunuyordu (`quiz_public_questions`
  /// üzerinde kategori başına exact count), oysa `loadQuestions` hemen
  /// aşağıda görüldüğü gibi soruları YEREL bankadan veriyor. İki kaynak
  /// birbirinden kopuktu ve sonuç iki ayrı yerde görünüyordu:
  ///
  /// * Kategori kartındaki "260 soru" etiketi, oyuncunun gerçekte
  ///   karşılaşacağı havuzu tarif etmiyordu.
  /// * Daha kötüsü, `categories_tab.dart` bir kategoriyi `questionCount! <
  ///   20` olduğunda "Yakında" diye KİLİTLİYOR. Yani sunucuda az kayıt
  ///   olan bir kategori, yerel bankada 200 sorusu olduğu hâlde
  ///   oynanamaz görünebiliyordu — ya da tersi.
  ///
  /// Sayı artık soruların geldiği bankadan okunuyor: etiket dürüst,
  /// kilit kararı doğru (2026-07-31 denetimi).
  ///
  /// Sunucu tarafı soru dağıtımı devreye girdiğinde bu metot da o kaynağa
  /// geçmeli — ama `loadQuestions` ile BİRLİKTE, ayrı değil.
  Future<Map<String, int>> loadCategoryQuestionCounts() async {
    return _offline.loadCategoryQuestionCounts();
  }

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    return _offline.loadQuestions(categoryId: categoryId, limit: limit);
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    return _offline.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      subCategory: subCategory,
      limit: limit,
    );
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return _offline.loadRoomQuestions(room);

    try {
      final response = await client.rpc(
        'get_room_questions',
        params: {'p_room_id': roomId},
      );
      final roomQuestions = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(_roomQuestionFromRow)
          .where(_contentPolicy.isPlayableWithHiddenAnswer)
          .toList();

      if (roomQuestions.isNotEmpty) return roomQuestions;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadRoomQuestions failed');
    }

    throw StateError('Online room questions are unavailable.');
  }

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    return _offline.loadDailyQuestions(limit: limit);
  }

  @override
  GameRoom createRoom({String category = 'Ziman'}) {
    return GameRoom(
      name: 'Hevalên Zanînê',
      code: generateRoomCode(),
      category: category,
      questionCount: 10,
      status: RoomStatus.lobby,
      players: const [Player(name: 'Tu', score: 0, state: 'Hazır', streak: 0)],
      hostId: client.auth.currentUser?.id ?? 'user',
    );
  }

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
  }) async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();

      final localRoom = createRoom(category: category);
      final categoryId = await _categoryIdByName(category);

      // Kod çakışırsa (unique ihlali) yeni kodla birkaç kez dene.
      Map<String, dynamic>? room;
      var code = localRoom.code;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          room = await client
              .from('rooms')
              .insert({
                'code': code,
                'host_id': user.id,
                'category_id': categoryId,
                'question_count': localRoom.questionCount,
                'seconds_per_question': secondsPerQuestion,
              })
              .select('id, code')
              .single();
          break;
        } on PostgrestException catch (error) {
          final isUniqueViolation = error.code == '23505';
          if (!isUniqueViolation || attempt == 2) rethrow;
          code = generateRoomCode();
        }
      }
      if (room == null) {
        throw StateError('Room insert failed after retries.');
      }

      final roomId = (room['id'] as String?) ?? '';
      final roomCode = (room['code'] as String?) ?? '';

      await client.from('room_players').insert({
        'room_id': roomId,
        'player_id': user.id,
        'is_ready': true,
      });

      final players = await _loadRoomPlayersById(roomId);
      return localRoom.copyWith(
        id: roomId,
        code: roomCode,
        players: players,
        hostId: user.id,
        secondsPerQuestion: secondsPerQuestion,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'createOnlineRoom failed');
      rethrow;
    }
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();

    final response = await client.rpc(
      'join_room_by_code',
      params: {'p_code': normalizeRoomCode(code)},
    );
    final room = response is Map<String, dynamic>
        ? response
        : (response as List).firstOrNull as Map<String, dynamic>?;
    if (room == null) {
      throw StateError('join_room_by_code boş yanıt döndürdü: oda bulunamadı');
    }
    final roomId = room['room_id'] as String;
    final players = await _loadRoomPlayersById(roomId);
    final category = room['category_name'] as String? ?? 'Ziman';

    String? hostId;
    try {
      final hostRow = await client
          .from('rooms')
          .select('host_id')
          .eq('id', roomId)
          .single();
      hostId = hostRow['host_id'] as String?;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadRoom host lookup failed');
    }

    final joined = createRoom(category: category).copyWith(
      id: roomId,
      code: room['code'] as String,
      questionCount: room['question_count'] as int? ?? 10,
      players: players,
      hostId: hostId,
      secondsPerQuestion:
          (room['seconds_per_question'] as int?) ??
          GameRoom.defaultSecondsPerQuestion,
    );

    // `join_room_by_code` katılanı `is_ready = false` ile ekliyor, oysa
    // `createOnlineRoom` ev sahibini `is_ready: true` ile ekliyor ve oda
    // ekranının anahtarı iki rolde de "hazır" varsayılanını gösteriyor.
    // Katılan kişi bu yüzden hazır olduğunu sanıp bekliyordu. Varsayılanı
    // sunucuya bildirmek, ekranın gösterdiğiyle veritabanının söylediğini
    // aynı yere getirir (2026-08-01).
    try {
      await updateReady(joined, true);
    } catch (error, stack) {
      // Bildirim düşerse oda yine de açılmalı: ekran artık gerçek durumu
      // okuduğu için kullanıcı anahtarı kendisi açabilir.
      _recordError(error, stack, reason: 'joinOnlineRoom ready sync failed');
    }
    return joined;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    final id = room.id;
    if (id == null) return room.players;
    return _loadRoomPlayersById(id);
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return room.status;

    final row = await client
        .from('rooms')
        .select('status')
        .eq('id', roomId)
        .maybeSingle();
    return _roomStatusFromValue(row?['status']);
  }

  @override
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final name = await getProfileName();
    final identity = await loadAvatarIdentity();
    await client.from('room_messages').insert({
      'room_id': roomId,
      'sender_id': user.id,
      'sender_name': name,
      'sender_avatar_color': identity.colorHex,
      'text': text.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) {
    return client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map(
          (rows) => rows
              .map(
                (row) =>
                    RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)),
              )
              .toList(),
        );
  }

  @override
  Future<List<RoomMessage>> loadRoomMessages(String roomId) async {
    try {
      final rows = await client
          .from('room_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('created_at');
      return rows
          .map(
            (row) =>
                RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadRoomMessages failed');
      return _offline.loadRoomMessages(roomId);
    }
  }

  // ─── Sohbet moderasyonu (Apple 1.2 / Google Play UGC) ───────────────
  //
  // Tablolar `supabase/2026-07-31_chat_moderation.sql` ile gelir. Göç
  // uygulanmamışsa çağrılar hata alır ve `false` döner — arayüz bunu
  // "bildirilemedi" olarak gösterir, çöker değil.

  @override
  Future<bool> reportRoomMessage({
    required String messageId,
    required String reason,
  }) async {
    try {
      await client.rpc(
        'report_room_message',
        params: {'p_message_id': messageId, 'p_reason': reason},
      );
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'reportRoomMessage failed');
      return false;
    }
  }

  @override
  Future<bool> blockPlayer(String playerId) async {
    try {
      await client.rpc('block_player', params: {'p_blocked_id': playerId});
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'blockPlayer failed');
      return false;
    }
  }

  @override
  Future<bool> unblockPlayer(String playerId) async {
    try {
      await client.rpc('unblock_player', params: {'p_blocked_id': playerId});
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'unblockPlayer failed');
      return false;
    }
  }

  @override
  Future<Set<String>> loadBlockedPlayerIds() async {
    try {
      final rows = await client.from('blocked_users').select('blocked_id');
      return rows.map((row) => row['blocked_id'] as String).toSet();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadBlockedPlayerIds failed');
      // Engel listesi okunamazsa hiç kimseyi engelli SAYMA: sohbet
      // çalışmaya devam etsin. Ters yön (herkesi engelli saymak) sohbeti
      // sessizce boşaltırdı.
      return const <String>{};
    }
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    final roomId = room.id;
    if (roomId == null) return Stream.value(room.players);
    return client
        .from('room_players')
        .stream(primaryKey: ['room_id', 'player_id'])
        .eq('room_id', roomId)
        .asyncMap((rows) async {
          final List<Player> players = [];
          final List<String> missingProfileIds = [];

          for (final row in rows) {
            final playerId = row['player_id'] as String;
            if (!_profileCache.containsKey(playerId)) {
              missingProfileIds.add(playerId);
            }
          }

          if (missingProfileIds.isNotEmpty) {
            try {
              final profiles = await client
                  .from('profiles')
                  .select(
                    'id, display_name, avatar_icon, avatar_color, avatar_url, avatar_frame, showcase_title',
                  )
                  .inFilter('id', missingProfileIds);
              for (final p in profiles) {
                final id = p['id'] as String;
                _profileCache[id] = p;
              }
            } catch (e, s) {
              _recordError(e, s, reason: 'Failed to fetch missing profiles');
            }
          }

          for (final row in rows) {
            final playerId = row['player_id'] as String;
            final cachedProfile = _profileCache[playerId];
            final name = cachedProfile?['display_name'] as String? ?? 'Oyuncu';
            final ready = row['is_ready'] as bool? ?? false;
            players.add(
              Player(
                id: playerId,
                name: name,
                score: row['score'] as int? ?? 0,
                streak: row['streak'] as int? ?? 0,
                state: ready ? Player.readyState : 'Bekliyor',
                avatarIcon: cachedProfile?['avatar_icon'] as String?,
                avatarColor: cachedProfile?['avatar_color'] as String?,
                avatarUrl: cachedProfile?['avatar_url'] as String?,
                avatarFrame: cachedProfile?['avatar_frame'] as String?,
                showcaseTitle: cachedProfile?['showcase_title'] as String?,
              ),
            );
          }
          return players;
        });
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    final roomId = room.id;
    if (roomId == null) return Stream.value(room.status);
    return client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).map(
      (rows) {
        if (rows.isEmpty) return RoomStatus.lobby;
        return _roomStatusFromValue(rows.first['status']);
      },
    );
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {
    final roomId = room.id;
    if (roomId == null) return;
    await client.rpc(
      'set_room_ready',
      params: {'p_room_id': roomId, 'p_is_ready': isReady},
    );
  }

  @override
  Future<void> startGame(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return;
    await client.rpc('start_room_game', params: {'p_room_id': roomId});
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return;
    await client.rpc('finish_room_game', params: {'p_room_id': roomId});
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    final roomId = room.id;
    if (roomId == null) {
      return _offline.submitAnswer(
        room: room,
        question: question,
        selectedOptionOptionKey: selectedOptionOptionKey,
        responseMs: responseMs,
      );
    }

    final response = await client.rpc(
      'submit_answer',
      params: {
        'p_room_id': roomId,
        'p_question_id': question.id,
        'p_selected_option': selectedOptionOptionKey,
        'p_response_ms': responseMs,
      },
    );

    return response as Map<String, dynamic>;
  }

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();

    if (favorite) {
      await client.from('favorite_questions').upsert({
        'player_id': user.id,
        'question_id': question.id,
      });
      return true;
    }

    await client
        .from('favorite_questions')
        .delete()
        .eq('player_id', user.id)
        .eq('question_id', question.id);
    return false;
  }

  @override
  Future<bool> isFavoriteQuestion(QuizQuestion question) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;
      final rows = await client
          .from('favorite_questions')
          .select('question_id')
          .eq('player_id', user.id)
          .eq('question_id', question.id)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'isFavoriteQuestion failed');
      return false;
    }
  }

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();
    await client.from('question_reports').insert({
      'question_id': question.id,
      'reporter_id': user.id,
      'reason': reason.trim().isEmpty ? 'Kontrol edilmeli' : reason.trim(),
    });

    // Editör kuyruğuna giden sayaç, eski rapor tablosuyla birlikte tutulur.
    // RPC henüz uygulanmamış eski ortamlarda bildirim yine de kaydedilmiş olur.
    try {
      await client.rpc(
        'report_question',
        params: {'p_question_id': question.id},
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'report_question RPC failed');
    }
  }

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      final rows = await client
          .from('favorite_questions')
          .select('question_id')
          .eq('player_id', user.id)
          .order('created_at', ascending: false);

      final byId = {
        for (final question in _offline.questions) question.id: question,
      };
      final questions = rows
          .map((row) => byId[row['question_id'] as String])
          .whereType<QuizQuestion>()
          .toList();

      if (questions.isNotEmpty) return questions;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadFavoriteQuestions failed');
      return const [];
    }
    return const [];
  }

  @override
  Future<int> loadCoinBalance() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      final rows = await client
          .from('coin_transactions')
          .select('amount')
          .eq('player_id', user.id);

      return rows.fold<int>(
        0,
        (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadCoinBalance failed');
      return 0;
    }
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'spend_coins',
        params: {'p_amount': amount, 'p_reason': reason},
      );
      if (response is Map<String, dynamic>) {
        return response['success'] as bool? ?? false;
      }
      return false;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'spendCoins failed');
      return false;
    }
  }

  @override
  Future<bool> hasPurchased(String itemId) async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      final rows = await client
          .from('shop_purchases')
          .select('id')
          .eq('player_id', user.id)
          .eq('item_id', itemId)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'hasPurchased failed');
      return false;
    }
  }

  @override
  Future<int> claimMissionReward({
    required String missionKey,
    required int fallbackReward,
  }) async {
    // Miktarı yalnızca sunucu tarifesi belirler; RPC başarısızsa
    // ödül verilmemiş sayılır (0 döner).
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'claim_mission_reward',
        params: {'p_mission_key': missionKey},
      );
      return _amountFromRpcResponse(response) ?? 0;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'claim_mission_reward failed');
      return 0;
    }
  }

  @override
  Future<int> claimTournamentReward() async {
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc('claim_tournament_reward');
      return _amountFromRpcResponse(response) ?? 0;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'claim_tournament_reward failed');
      return 0;
    }
  }

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    // Ödül miktarını yalnızca sunucu belirler (claim_quiz_reward RPC).
    // İstemciden coin_transactions'a yazma yolu yoktur; RPC başarısızsa
    // coin kazanılmamış sayılır.
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'claim_quiz_reward',
        params: {
          'p_room_id': room?.id,
          'p_score': score,
          'p_correct_count': correctCount,
          'p_best_streak': bestStreak,
          'p_total_questions': totalQuestions,
        },
      );
      final amount = _amountFromRpcResponse(response);
      if (amount != null) return amount;
      throw StateError('Quiz reward RPC returned no amount for ${user.id}.');
    } catch (error, stack) {
      _recordError(error, stack, reason: 'claim_quiz_reward failed');
      return 0;
    }
  }

  void _recordError(Object error, StackTrace stack, {String? reason}) {
    ErrorReporter.record(error, stack, reason: reason);
  }

  int? _amountFromRpcResponse(Object? response) {
    if (response is Map<String, dynamic>) {
      return (response['amount'] as num?)?.toInt();
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) {
        return (first['amount'] as num?)?.toInt();
      }
    }
    return null;
  }

  /// `RETURNS TABLE` RPC'leri PostgREST'te satır listesi döndürür;
  /// tek satırlı sonuçların ilk satırını Map olarak çıkarır.
  static Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is List) {
      return response.isEmpty
          ? null
          : Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return null;
  }

  /// Çark guard'ı için gün anahtarı. Sunucudaki `can_spin_today` /
  /// `award_spin_coins` RPC'leri `CURRENT_DATE` (UTC) ile gün sınırı çizer;
  /// yerel saat kullanılırsa yerel gece yarısı ile UTC gece yarısı arasında
  /// buton aktif görünüp sunucunun reddettiği "çark dönmüyor" tutarsızlığı
  /// doğar. Ekrandaki geri sayım da UTC gece yarısını hedefler.
  static String spinDayKey(DateTime now) {
    final utc = now.toUtc();
    return '${utc.year}-${utc.month}-${utc.day}';
  }

  Future<bool> _hasUnusedExtraSpin() async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    final purchased = await client
        .from('shop_purchases')
        .count(CountOption.exact)
        .eq('player_id', user.id)
        .eq('item_id', 'spin_wheel_extra');
    final used = await client
        .from('coin_transactions')
        .count(CountOption.exact)
        .inFilter('reason', ['extra_spin:server', 'daily_spin:extra_purchase']);
    return purchased > used;
  }

  @override
  Future<bool> canSpinToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSpinStr = prefs.getString('zankurd.last_spin_date');
      final todayStr = spinDayKey(DateTime.now());
      if (lastSpinStr == todayStr) {
        return await _hasUnusedExtraSpin();
      }
      final freeSpinAvailable = await client.rpc<bool>('can_spin_today');
      return freeSpinAvailable || await _hasUnusedExtraSpin();
    } catch (error, stack) {
      _recordError(error, stack, reason: 'canSpinToday failed');
      return _offline.canSpinToday();
    }
  }

  @override
  Future<int> awardSpinCoins() async {
    try {
      final row = _firstRow(await client.rpc<dynamic>('award_spin_coins'));
      if (row == null) return 0;

      final success = row['success'] as bool? ?? false;
      if (!success) {
        final extraRow = _firstRow(
          await client.rpc<dynamic>('claim_extra_spin'),
        );
        return (extraRow?['amount'] as num?)?.toInt() ?? 0;
      }

      final amount = (row['reward_amount'] as num?)?.toInt() ?? 0;
      if (amount > 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'zankurd.last_spin_date',
            spinDayKey(DateTime.now()),
          );
        } catch (error, stack) {
          _recordError(
            error,
            stack,
            reason: 'awardSpinCoins preference update failed',
          );
        }
      }
      return amount;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'awardSpinCoins failed');
      return 0;
    }
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    try {
      final rows = await client.rpc<List<dynamic>>(
        'get_leaderboard',
        params: {'p_days': period.days, 'p_limit': limit},
      );
      return rows.indexed.map((item) {
        final index = item.$1;
        final row = item.$2 as Map<String, dynamic>;
        return LeaderboardEntry(
          rank: index + 1,
          playerId: row['player_id'] as String? ?? '',
          displayName: row['display_name'] as String? ?? 'Oyuncu',
          totalScore: (row['total_score'] as num?)?.toInt() ?? 0,
          bestStreak: (row['best_streak'] as num?)?.toInt() ?? 0,
          roomsPlayed: (row['rooms_played'] as num?)?.toInt() ?? 0,
          // Eski RPC sürümü bu kolonları döndürmez; null-güvenli okunur ve
          // migration uygulanana kadar baş-harf avatarı gösterilir.
          avatarIcon: row['avatar_icon'] as String?,
          avatarColor: row['avatar_color'] as String?,
          avatarUrl: row['avatar_url'] as String?,
          avatarFrame: row['avatar_frame'] as String?,
          showcaseTitle: row['showcase_title'] as String?,
        );
      }).toList();
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadLeaderboard RPC failed');
      // RPC henüz kurulu değilse all-time view'a geri dön
      try {
        final rows = await client
            .from('leaderboard_entries')
            .select(
              'player_id, display_name, total_score, best_streak, rooms_played',
            )
            .order('total_score', ascending: false)
            .order('best_streak', ascending: false)
            .limit(limit);
        return rows.indexed.map((item) {
          final index = item.$1;
          final row = item.$2;
          return LeaderboardEntry(
            rank: index + 1,
            playerId: row['player_id'] as String? ?? '',
            displayName: row['display_name'] as String? ?? 'Oyuncu',
            totalScore: row['total_score'] as int? ?? 0,
            bestStreak: row['best_streak'] as int? ?? 0,
            roomsPlayed: row['rooms_played'] as int? ?? 0,
          );
        }).toList();
      } catch (error, stack) {
        _recordError(error, stack, reason: 'loadLeaderboard failed');
        return const [];
      }
    }
  }

  Future<String> _categoryIdByName(String categoryName) async {
    final row = await client
        .from('categories')
        .select('id')
        .eq('name', categoryName)
        .maybeSingle();

    if (row == null) {
      final fallback = await client
          .from('categories')
          .select('id')
          .eq('slug', 'ziman')
          .single();
      return fallback['id'] as String;
    }

    return row['id'] as String;
  }

  Future<List<Player>> _loadRoomPlayersById(String roomId) async {
    final rows = await client
        .from('room_players')
        .select(
          'player_id, score, streak, is_ready, '
          'profiles(display_name, avatar_icon, avatar_color, avatar_url, '
          'avatar_frame, showcase_title)',
        )
        .eq('room_id', roomId)
        .order('joined_at');

    return rows.map((row) {
      final playerId = row['player_id'] as String;
      final rawProfile = row['profiles'] as Map<String, dynamic>?;
      if (rawProfile != null) {
        _profileCache[playerId] = rawProfile;
      }

      final profile = _profileCache[playerId] ?? rawProfile;
      final name = profile?['display_name'] as String? ?? 'Oyuncu';
      final ready = row['is_ready'] as bool? ?? false;
      return Player(
        id: playerId,
        name: name,
        score: row['score'] as int? ?? 0,
        streak: row['streak'] as int? ?? 0,
        state: ready ? Player.readyState : 'Bekliyor',
        avatarIcon: profile?['avatar_icon'] as String?,
        avatarColor: profile?['avatar_color'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        avatarFrame: profile?['avatar_frame'] as String?,
        showcaseTitle: profile?['showcase_title'] as String?,
      );
    }).toList();
  }

  QuizQuestion _roomQuestionFromRow(Map<String, dynamic> row) {
    final answers = <String>[
      row['option_a'] as String? ?? '',
      row['option_b'] as String? ?? '',
      row['option_c'] as String? ?? '',
      row['option_d'] as String? ?? '',
    ].where((answer) => answer.trim().isNotEmpty && answer != '-').toList();

    return QuizQuestion(
      id: row['id'] as String,
      category: row['category_name'] as String? ?? 'Ziman',
      prompt: row['prompt'] as String,
      answers: answers,
      correctAnswer: '',
      explanation: '',
      type: _questionTypeFromRow(row),
      imageUrl: row['image_url'] as String?,
      difficulty: row['difficulty'] as int? ?? 2,
    );
  }

  QuestionType _questionTypeFromRow(Map<String, dynamic> row) {
    final value = row['question_type'] as String?;
    return switch (value) {
      'true_false' => QuestionType.trueFalse,
      'visual' => QuestionType.visual,
      'word_ordering' || 'wordOrdering' => QuestionType.wordOrdering,
      'fill_in_blank' || 'fillInBlank' => QuestionType.fillInBlank,
      _ => QuestionType.multipleChoice,
    };
  }

  Future<T> _retryOnNetworkFailure<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= 3) {
          rethrow;
        }
        final delay = Duration(milliseconds: 500 * (1 << (attempts - 1)));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    final response = await client.rpc(
      'join_matchmaking',
      params: {'p_category_name': categoryName},
    );
    return response as Map<String, dynamic>;
  }

  @override
  Future<void> cancelMatchmaking() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('matchmaking_queue').delete().eq('player_id', user.id);
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() {
    final user = client.auth.currentUser;
    if (user == null) return Stream.value(null);
    return client
        .from('matchmaking_queue')
        .stream(primaryKey: ['player_id'])
        .eq('player_id', user.id)
        .map((rows) {
          if (rows.isEmpty) return null;
          return rows.first;
        });
  }

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    final controller = StreamController<Map<String, dynamic>>();
    _retainRoomChannel(roomId).onBroadcast(
      event: 'game_event',
      callback: (payload) {
        if (!controller.isClosed) {
          controller.add(payload);
        }
      },
    );

    controller.onCancel = () async {
      await _releaseRoomChannel(roomId);
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final channel = _ensureRoomChannel(roomId).channel;
      await channel.sendBroadcastMessage(event: 'game_event', payload: payload);
      await _disposeUnretainedRoomChannel(roomId);
    } catch (error, stack) {
      _recordError(
        error,
        stack,
        reason: 'sendRoomBroadcast failed for room $roomId',
      );
    }
  }

  @override
  Future<Contest?> loadTodayContest() async {
    try {
      final res = await client
          .rpc('get_today_contest')
          .timeout(const Duration(seconds: 8));
      if (res == null) return null;

      // `get_today_contest` bir `RETURNS TABLE` fonksiyonu
      // (2026-07-05_contest_system.sql:63), yani PostgREST onu JSON
      // DİZİSİ olarak döndürür. Kod ise doğrudan `Contest.fromJson(res)`
      // diyordu — haritanın kendisini bekliyordu.
      //
      // `res.isEmpty` diziyle de çalıştığı için boş gün doğru davranıyordu;
      // ama DOLU bir gün `fromJson`da tip hatasına düşüyor, hata yakalanıp
      // çevrimdışı yedeğe geçiliyordu. Yani sunucudan gelen "Günün
      // Etkinliği" HİÇBİR ZAMAN kullanılamıyordu ve kusur sessizdi, çünkü
      // yedek her zaman makul bir şey gösteriyordu (2026-07-31 denetimi).
      final row = res is List ? (res.isEmpty ? null : res.first) : res;
      if (row == null) return null;
      if (row is! Map) return null;
      return Contest.fromJson(Map<String, dynamic>.from(row));
    } catch (e, s) {
      _recordError(e, s, reason: 'loadTodayContest failed');
      return _offline.loadTodayContest();
    }
  }

  @override
  Future<ContestEntry?> submitContestEntry({
    required String contestId,
    required int correctCount,
  }) async {
    // Contest sonuçları sunucuda doğrulanana kadar istemci beyanıyla skor
    // yazılmaz. İmza uyumluluk için korunur; güvenli sonuç "kayıt yok"tur.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> claimContestReward(String contestId) async {
    // Doğrulanmamış contest sonucu için ödül talep edilmez.
    return null;
  }

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async {
    // Doğrulanmamış skorlar gösterilmez; API uyumluluğu korunur.
    return const [];
  }

  @override
  Future<List<UserContestBadge>> loadUserContestBadges() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const [];
      final res = await client
          .from('user_contest_badges')
          .select()
          .eq('user_id', uid)
          .order('earned_at', ascending: false);
      return (res as List<dynamic>)
          .map((row) => UserContestBadge.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadUserContestBadges failed');
      return _offline.loadUserContestBadges();
    }
  }

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async {
    try {
      final res =
          await client.rpc(
                'load_lessons_by_category',
                params: {'p_category': category},
              )
              as List<dynamic>;
      return res.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['category'] == null || (map['category'] as String).isEmpty) {
          map['category'] = category;
        }
        return Lesson.fromJson(map);
      }).toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadLessonsByCategory failed');
      return _offline.loadLessonsByCategory(category);
    }
  }

  @override
  Future<Map<String, dynamic>?> loadLesson(String lessonId) async {
    try {
      final res =
          await client.rpc('load_lesson', params: {'p_lesson_id': lessonId})
              as List<dynamic>;
      if (res.isEmpty) return null;
      return res.first as Map<String, dynamic>;
    } catch (e, s) {
      _recordError(e, s, reason: 'loadLesson failed');
      return _offline.loadLesson(lessonId);
    }
  }

  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async {
    try {
      final res =
          await client.rpc(
                'load_lesson_slides',
                params: {'p_lesson_id': lessonId},
              )
              as List<dynamic>;
      return res
          .map((row) => LessonSlide.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadLessonSlides failed');
      return _offline.loadLessonSlides(lessonId);
    }
  }

  @override
  Future<bool> markLessonCompleted(String lessonId) async {
    try {
      await client.rpc(
        'mark_lesson_completed',
        params: {'p_lesson_id': lessonId},
      );
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'markLessonCompleted failed');
      return _offline.markLessonCompleted(lessonId);
    }
  }

  @override
  Future<Set<String>> loadCompletedLessonIds() async {
    try {
      final rows = await client
          .from('user_lesson_progress')
          .select('lesson_id')
          .eq('completed', true);
      return rows
          .map((row) => row['lesson_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadCompletedLessonIds failed');
      return _offline.loadCompletedLessonIds();
    }
  }

  @override
  Future<bool> addFriend(String friendId, String friendName) async {
    try {
      final response = await client.rpc<dynamic>(
        'add_friend',
        params: {'p_friend_id': friendId, 'p_friend_name': friendName},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'addFriend failed');
      return _offline.addFriend(friendId, friendName);
    }
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final response = await client.rpc<dynamic>(
        'accept_friend_request',
        params: {'p_request_id': requestId},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'acceptFriendRequest failed');
      return _offline.acceptFriendRequest(requestId);
    }
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      final response = await client.rpc<dynamic>(
        'reject_friend_request',
        params: {'p_request_id': requestId},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'rejectFriendRequest failed');
      return _offline.rejectFriendRequest(requestId);
    }
  }

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String query) async {
    try {
      final res = await client.rpc<List<dynamic>>(
        'search_profiles',
        params: {'p_query': query},
      );
      return res
          .map(
            (row) => PlayerSearchResult.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'searchPlayers failed');
      return _offline.searchPlayers(query);
    }
  }

  @override
  Future<List<Friend>> loadFriends() async {
    try {
      final res = await client.rpc<List<dynamic>>('list_friends');
      return res
          .map((row) => Friend.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadFriends failed');
      return _offline.loadFriends();
    }
  }

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async {
    try {
      final friends = await loadFriends();
      friends.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      return friends;
    } catch (e, s) {
      _recordError(e, s, reason: 'loadFriendsLeaderboard failed');
      return _offline.loadFriendsLeaderboard();
    }
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    try {
      final res = await client.rpc<List<dynamic>>(
        'list_pending_friend_requests',
      );
      return res
          .map(
            (row) =>
                FriendRequest.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadPendingFriendRequests failed');
      return _offline.loadPendingFriendRequests();
    }
  }

  @override
  Future<bool> syncMissionCompletion(
    String missionKey,
    int coinReward,
    int xpReward,
  ) async {
    try {
      final response = await client.rpc<dynamic>(
        'sync_mission_completion',
        params: {
          'p_mission_key': missionKey,
          'p_coin_reward': coinReward,
          'p_xp_reward': xpReward,
        },
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'syncMissionCompletion failed');
      return _offline.syncMissionCompletion(missionKey, coinReward, xpReward);
    }
  }

  @override
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  ) async {
    try {
      final response = await client.rpc<dynamic>(
        'log_analytics_event',
        params: {'p_event_name': eventName, 'p_event_params': params},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'logAnalyticsEvent failed');
      return _offline.logAnalyticsEvent(eventName, params);
    }
  }

  @override
  Future<bool> saveTournamentProgress(
    String stage,
    int userScore,
    int opponentScore,
    List<String> botWinners,
  ) async {
    try {
      final response = await client.rpc<dynamic>(
        'save_tournament_progress',
        params: {
          'p_stage': stage,
          'p_user_score': userScore,
          'p_opponent_score': opponentScore,
          'p_bot_winners': botWinners,
        },
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'saveTournamentProgress failed');
      return _offline.saveTournamentProgress(
        stage,
        userScore,
        opponentScore,
        botWinners,
      );
    }
  }

  // ── Turnuva ────────────────────────────────────────────────────────
  //
  // Bu üç yöntem sunucuya bağlanana kadar sahte depoya yönleniyordu: yani
  // Supabase deposunda bile turnuva bir bot benzetimiydi ve oyuncular hiç
  // karşılaşmıyordu (2026-07-26). Artık gerçek eşleşme sunucuda kurulur;
  // eşleştirmeyi, kazananı ve ilerlemeyi `2026-07-26_real_player_tournament
  // .sql` içindeki fonksiyonlar belirler.
  //
  // Migration henüz uygulanmamışsa PostgREST 42883 ("function does not
  // exist") döner. O durumda ekran boş kalmasın diye eski bot benzetimine
  // düşülür — bu bir yedek yol, hedef değil.

  bool _isMissingFunction(Object error) =>
      error is PostgrestException && error.code == '42883';

  @override
  Future<TournamentBracket?> joinRealTournament() async {
    try {
      client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      await client.rpc('join_tournament');
      return await loadRealTournamentBracket();
    } catch (e, s) {
      if (!_isMissingFunction(e)) {
        _recordError(e, s, reason: 'joinRealTournament failed');
      }
      return null;
    }
  }

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async {
    try {
      final response = await client.rpc('get_tournament_bracket');
      if (response == null) return null;
      return TournamentBracket.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e, s) {
      if (!_isMissingFunction(e)) {
        _recordError(e, s, reason: 'loadRealTournamentBracket failed');
      }
      return null;
    }
  }

  @override
  Future<TournamentBracket> joinTournament() async {
    final real = await joinRealTournament();
    return real ?? await _offline.joinTournament();
  }

  @override
  Future<TournamentBracket?> loadTournamentBracket() async {
    final real = await loadRealTournamentBracket();
    return real ?? await _offline.loadTournamentBracket();
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    try {
      // Rakibin skoru gönderilmez: onu rakip kendi bildirir. İstemcinin
      // karşı tarafın skorunu yazabilmesi, maçı tek başına kazanabilmesi
      // demekti.
      await client.rpc(
        'submit_tournament_match',
        params: {'p_match_id': matchId, 'p_score': playerScore},
      );
      final bracket = await loadTournamentBracket();
      final match = bracket?.rounds
          .expand((round) => round.matches)
          .firstWhere(
            (m) => m.id == matchId,
            orElse: () => const TournamentMatch(
              id: '',
              playerOneId: '',
              playerOneName: '',
              playerTwoId: '',
              playerTwoName: '',
              playerOneScore: 0,
              playerTwoScore: 0,
              status: 'pending',
              winnerId: '',
            ),
          );
      if (match != null && match.id.isNotEmpty) return match;
      return _offline.submitTournamentMatch(
        matchId: matchId,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
    } catch (e, s) {
      if (!_isMissingFunction(e)) {
        _recordError(e, s, reason: 'submitTournamentMatch failed');
      }
      return _offline.submitTournamentMatch(
        matchId: matchId,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
    }
  }

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async {
    try {
      final rows = await client
          .from('profiles')
          .select('id, display_name, total_score')
          .order('total_score', ascending: false)
          .limit(limit);
      if (rows.isEmpty) return _offline.loadTournamentStandings(limit: limit);
      return List.generate(rows.length, (i) {
        final row = rows[i];
        final score = (row['total_score'] as num?)?.toInt() ?? 0;
        final String status;
        if (i == 0) {
          status = 'champion';
        } else if (i < 4) {
          status = 'finalist';
        } else {
          status = 'eliminated';
        }
        return TournamentStandings(
          rank: i + 1,
          playerId: row['id'] as String? ?? '',
          playerName: row['display_name'] as String? ?? '—',
          totalScore: score,
          status: status,
        );
      });
    } catch (e, s) {
      _recordError(e, s, reason: 'loadTournamentStandings failed');
      return _offline.loadTournamentStandings(limit: limit);
    }
  }

  @override
  Future<int> claimTournamentChampionReward() async {
    try {
      // RPC alanı `amount`; burada `coins` okunuyordu ve şampiyon ödülü
      // her zaman 0 dönüyordu. Aynı RPC'yi okuyan diğer yol (`claim
      // TournamentReward`) doğru alanı kullanıyordu — iki yol aynı yanıtı
      // iki ayrı biçimde okuyordu (2026-07-26).
      final response = await client.rpc<dynamic>('claim_tournament_reward');
      return _amountFromRpcResponse(response) ?? 0;
    } catch (e, s) {
      _recordError(e, s, reason: 'claimTournamentChampionReward failed');
      return _offline.claimTournamentChampionReward();
    }
  }

  @override
  Future<bool> submitSuggestedQuestion({
    required String category,
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    String? explanation,
    int difficulty = 3,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      await client.from('suggested_questions').insert({
        'user_id': userId,
        'category': category,
        'prompt': prompt,
        'option_a': optionA,
        'option_b': optionB,
        'option_c': optionC,
        'option_d': optionD,
        'correct_option': correctOption,
        'explanation': explanation,
        'difficulty': difficulty,
        'status': 'pending',
      });
      return true;
    } catch (e, stack) {
      _recordError(e, stack, reason: 'submitSuggestedQuestion failed');
      // Çevrimdışı durumda mock'a düş.
      return _offline.submitSuggestedQuestion(
        category: category,
        prompt: prompt,
        optionA: optionA,
        optionB: optionB,
        optionC: optionC,
        optionD: optionD,
        correctOption: correctOption,
        explanation: explanation,
        difficulty: difficulty,
      );
    }
  }
}
