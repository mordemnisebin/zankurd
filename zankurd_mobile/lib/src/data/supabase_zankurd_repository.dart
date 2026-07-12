import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
import '../utils/question_cache.dart';
import 'mock_zankurd_repository.dart';
import 'seen_question_store.dart';
import 'zankurd_repository.dart';
import '../config/subcategory_config.dart';

/// Supabase destekli üretim deposu.
///
/// Çevrimdışı/şema-eksik durumlarda [_offline] (yerel soru bankası) devreye
/// girer. Bu ilişki bilinçli olarak kalıtım değil kompozisyondur: mock'a
/// eklenen sahte davranışların sessizce üretime sızmasını önler.
class SupabaseZanKurdRepository implements ZanKurdRepository {
  SupabaseZanKurdRepository(this.client);

  final MockZanKurdRepository _offline = MockZanKurdRepository();

  @override
  List<String> get categories => _offline.categories;

  @override
  List<QuizQuestion> get questions => _offline.questions;

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  List<QuizLevel> levelsForCategory(String category) =>
      _offline.levelsForCategory(category);

  @override
  GameRoom joinRoom(String code) => _offline.joinRoom(code);

  static const _questionColumns =
      'id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, explanation_ku, explanation_tr, question_type, image_url, difficulty';
  static const _roomQuestionColumns =
      'question_index, questions($_questionColumns)';

  final SupabaseClient client;
  final _cache = QuestionCache();

  /// Oda başına tek realtime kanalı; gönderme ve dinleme paylaşır.
  /// Eskiden her broadcast'te yeni kanal açılıyordu (nesne sızıntısı).
  final Map<String, RealtimeChannel> _roomChannels = {};

  RealtimeChannel _roomChannel(String roomId) {
    return _roomChannels.putIfAbsent(roomId, () {
      final channel = client.channel('room:$roomId');
      channel.subscribe();
      return channel;
    });
  }

  Future<void> _releaseRoomChannel(String roomId) async {
    final channel = _roomChannels.remove(roomId);
    if (channel != null) {
      await client.removeChannel(channel);
    }
  }

  Future<User> signInAnonymously() async {
    final response = await client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw StateError('Anonymous sign-in did not return a user.');
    }
    return user;
  }

  Future<void> upsertProfile({
    required String displayName,
    String avatarColor = '#E94560',
  }) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'avatar_color': avatarColor,
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
    );
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
        return profile['display_name'] as String;
      }
    } catch (error, stack) {
      _recordError(error, stack, reason: 'getProfileName failed');
    }
    return 'ZanKurd Oyuncusu';
  }

  @override
  Future<void> updateProfileName(String name) async {
    await upsertProfile(displayName: name);
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
      return rows.map((row) => row['name'] as String).toList();
    });
  }

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final key = '${categoryId ?? "all"}_$limit';
    final cached = _cache.get(key);
    if (cached != null) return cached;
    try {
      final result = await fetchApprovedQuestions(
        categoryId: categoryId,
        limit: limit,
      );
      // Onaylı havuz daralırsa (içerik denetimi vb.) boş liste ile quiz
      // açmak yerine yerel bankaya düş.
      if (result.isEmpty) {
        return _offline.loadQuestions(categoryId: categoryId, limit: limit);
      }
      _cache.set(key, result);
      return result;
    } catch (_) {
      return _offline.loadQuestions(categoryId: categoryId, limit: limit);
    }
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    try {
      final categoryId = await _categoryIdByName(category);
      final fetchLimit = subCategory != null ? limit * 3 : limit;
      final rows = await _selectApprovedQuestions(
        categoryId: categoryId,
        limit: fetchLimit,
        difficultyMin: difficultyMin,
        difficultyMax: difficultyMax,
        randomize: true,
      );

      var parsedQuestions = rows.map(_questionFromRow).toList();
      if (subCategory != null) {
        final matched = parsedQuestions
            .where((q) => SubcategoryConfig.getSubcategoryId(q) == subCategory)
            .toList();
        // Alt kategori etiketi gerçek bir DB kolonu değil, soru id'sinin
        // hash'inden türetilir (bkz. SubcategoryConfig.getSubcategoryId) —
        // yani kategori+zorluk havuzunun rastgele ~1/3'ü eşleşir. Eşleşen
        // sayı istenen limit'in altında kalırsa seviyeyi eksik soruyla
        // bitirmek yerine aynı kategori+zorluktaki diğer sorularla
        // tamamla; alt kategori zaten sabit bir içerik sınırı değil.
        if (matched.length < limit) {
          final matchedIds = matched.map((q) => q.id).toSet();
          final need = limit - matched.length;
          final fillers = parsedQuestions
              .where((q) => !matchedIds.contains(q.id))
              .take(need * 3);
          parsedQuestions = [...matched, ...fillers];
        } else {
          parsedQuestions = matched;
        }
      }

      final store = await SeenQuestionStore.load();
      final selected = store.preferUnseen(parsedQuestions, limit);
      final questions = await _withRemoteVisualBlend(
        selected,
        categoryId: categoryId,
        limit: limit,
        difficultyMin: difficultyMin,
        difficultyMax: difficultyMax,
      );
      if (questions.isNotEmpty) return questions;
    } catch (_) {
      // Fall through to local examples if the rich schema is unavailable.
    }

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
      final rows = await client
          .from('room_questions')
          .select(_roomQuestionColumns)
          .eq('room_id', roomId)
          .order('question_index');

      final roomQuestions = rows
          .map((row) => row['questions'])
          .whereType<Map<String, dynamic>>()
          .map(_questionFromRow)
          .toList();

      if (roomQuestions.isNotEmpty) return roomQuestions;
    } catch (_) {
      // The SQL sync view/policy may not be installed yet. Use approved questions.
    }

    return loadQuestions(limit: room.questionCount);
  }

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    try {
      final seed = MockZanKurdRepository.dailySeed();

      // Soru sayısını öğren (SELECT ile aynı onay filtresiyle),
      // gün tohumlu pencereden çek.
      final total = await client
          .from('questions')
          .count(CountOption.exact)
          .eq('is_approved', true);
      if (total <= 0) return _offline.loadDailyQuestions(limit: limit);

      const windowSize = 60;
      final maxOffset = total > windowSize ? total - windowSize : 0;
      final offset = maxOffset == 0 ? 0 : (seed * 37) % maxOffset;

      final rows = await client
          .from('questions')
          .select(_questionColumns)
          .eq('is_approved', true)
          .order('id')
          .range(offset, offset + windowSize - 1);

      final pool = rows.map(_questionFromRow).toList()..shuffle(Random(seed));
      final selected = pool.take(limit).toList();
      if (selected.isNotEmpty) return selected;
    } catch (_) {
      // Şema/politika eksikse yerel soru bankasına düş.
    }
    return _offline.loadDailyQuestions(limit: limit);
  }

  Future<List<QuizQuestion>> fetchApprovedQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final rows = await _selectApprovedQuestions(
      categoryId: categoryId,
      limit: limit,
      randomize: true,
    );
    final store = await SeenQuestionStore.load();
    final selected = store.preferUnseen(
      rows.map(_questionFromRow).toList(),
      limit,
    );
    return _withRemoteVisualBlend(
      selected,
      categoryId: categoryId,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> _selectApprovedQuestions({
    required String? categoryId,
    required int limit,
    int? difficultyMin,
    int? difficultyMax,
    bool randomize = false,
    String? questionType,
  }) async {
    return _retryOnNetworkFailure(() async {
      final query = client
          .from('questions')
          .select(_questionColumns)
          .eq('is_approved', true);

      var filteredQuery = categoryId == null
          ? query
          : query.eq('category_id', categoryId);
      if (difficultyMin != null) {
        filteredQuery = filteredQuery.gte('difficulty', difficultyMin);
      }
      if (difficultyMax != null) {
        filteredQuery = filteredQuery.lte('difficulty', difficultyMax);
      }
      if (questionType != null) {
        filteredQuery = filteredQuery.eq('question_type', questionType);
      }

      if (randomize) {
        // Pencere kaydırması, SELECT ile AYNI filtrelerle sayılan toplam
        // üzerinden hesaplanmalı; yoksa küçük kategorilerde offset filtreli
        // sonucun dışına düşer ve seçim hep aynı ilk kayıtlara sabitlenir.
        var countQuery = client
            .from('questions')
            .count(CountOption.exact)
            .eq('is_approved', true);
        if (categoryId != null) {
          countQuery = countQuery.eq('category_id', categoryId);
        }
        if (difficultyMin != null) {
          countQuery = countQuery.gte('difficulty', difficultyMin);
        }
        if (difficultyMax != null) {
          countQuery = countQuery.lte('difficulty', difficultyMax);
        }
        if (questionType != null) {
          countQuery = countQuery.eq('question_type', questionType);
        }
        final total = await countQuery;
        const windowSize = 120;
        final maxOffset = total > windowSize ? total - windowSize : 0;
        final offset = maxOffset == 0 ? 0 : Random().nextInt(maxOffset);
        final rows = await filteredQuery
            .order('id')
            .range(offset, offset + windowSize - 1);
        if (rows.isNotEmpty) {
          // Pencereyi olduğu gibi döndür; tekrar-önleyici seçim üst katmanda
          // (SeenQuestionStore.preferUnseen) limit'e indirger.
          return (rows..shuffle()).toList(growable: false);
        }
      }

      final rows = await filteredQuery.order('id').limit(limit);
      return rows;
    });
  }

  Future<List<QuizQuestion>> _withRemoteVisualBlend(
    List<QuizQuestion> selected, {
    required String? categoryId,
    required int limit,
    int? difficultyMin,
    int? difficultyMax,
  }) async {
    const minVisualQuestions = 2;
    if (selected.where((question) => question.hasImage).length >=
        minVisualQuestions) {
      return selected.take(limit).toList(growable: false);
    }

    try {
      final visualRows = await _selectApprovedQuestions(
        categoryId: categoryId,
        limit: minVisualQuestions,
        difficultyMin: difficultyMin,
        difficultyMax: difficultyMax,
        randomize: true,
        questionType: 'visual',
      );
      final ids = selected.map((question) => question.id).toSet();
      final blended = [...selected];
      for (final question in visualRows.map(_questionFromRow)) {
        if (ids.contains(question.id)) continue;
        if (blended.where((q) => q.hasImage).length >= minVisualQuestions) {
          break;
        }
        if (blended.length >= limit) {
          final replaceAt = blended.lastIndexWhere((q) => !q.hasImage);
          if (replaceAt == -1) break;
          blended[replaceAt] = question;
        } else {
          blended.add(question);
        }
      }
      return (blended.take(limit).toList(growable: false)..shuffle());
    } catch (error, stack) {
      _recordError(error, stack, reason: 'visual question blend failed');
      return selected.take(limit).toList(growable: false);
    }
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
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'}) async {
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
              'seconds_per_question': 15,
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

    await client.from('room_players').insert({
      'room_id': room['id'],
      'player_id': user.id,
      'is_ready': true,
    });

    final players = await _loadRoomPlayersById(room['id'] as String);
    return localRoom.copyWith(
      id: room['id'] as String,
      code: room['code'] as String,
      players: players,
      hostId: user.id,
    );
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();

    final response = await client.rpc(
      'join_room_by_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    final room = response is Map<String, dynamic>
        ? response
        : (response as List).first as Map<String, dynamic>;
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
    } catch (_) {}

    return createRoom(category: category).copyWith(
      id: roomId,
      code: room['code'] as String,
      questionCount: room['question_count'] as int? ?? 10,
      players: players,
      hostId: hostId,
    );
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    final id = room.id;
    if (id == null) return room.players;
    return _loadRoomPlayersById(id);
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
    } catch (e) {
      return _offline.loadRoomMessages(roomId);
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
        .asyncMap((_) => _loadRoomPlayersById(roomId));
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    final roomId = room.id;
    if (roomId == null) return Stream.value(room.status);
    return client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).map(
      (rows) {
        if (rows.isEmpty) return RoomStatus.lobby;
        final statusStr = rows.first['status'] as String? ?? 'lobby';
        return statusStr == 'active'
            ? RoomStatus.active
            : statusStr == 'finished'
            ? RoomStatus.finished
            : RoomStatus.lobby;
      },
    );
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {
    final roomId = room.id;
    if (roomId == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;
    await client
        .from('room_players')
        .update({'is_ready': isReady})
        .eq('room_id', roomId)
        .eq('player_id', user.id);
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
  }

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      final rows = await client
          .from('favorite_questions')
          .select('questions($_questionColumns)')
          .eq('player_id', user.id)
          .order('created_at', ascending: false);

      final questions = rows
          .map((row) => row['questions'])
          .whereType<Map<String, dynamic>>()
          .map(_questionFromRow)
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
          .from('coin_transactions')
          .select('id')
          .eq('player_id', user.id)
          .eq('reason', 'purchase_$itemId')
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
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
  Future<void> updateProfileXP(int xp) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return;
      await client.from('profiles').update({'xp': xp}).eq('id', user.id);
    } catch (error, stack) {
      _recordError(error, stack, reason: 'updateProfileXP failed');
      rethrow;
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

  @override
  Future<bool> canSpinToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSpinStr = prefs.getString('zankurd.last_spin_date');
      final todayStr = spinDayKey(DateTime.now());
      if (lastSpinStr == todayStr) {
        return false;
      }
      return await client.rpc<bool>('can_spin_today');
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
        _recordError(
          Exception(row['message'] ?? 'Award spin coins failed'),
          StackTrace.current,
          reason: 'awardSpinCoins RPC unsuccessful',
        );
        return 0;
      }

      final amount = (row['reward_amount'] as num?)?.toInt() ?? 0;
      if (amount > 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'zankurd.last_spin_date',
            spinDayKey(DateTime.now()),
          );
        } catch (_) {}
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
    } catch (_) {
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
      final profile = row['profiles'] as Map<String, dynamic>?;
      final name = profile?['display_name'] as String? ?? 'Oyuncu';
      final ready = row['is_ready'] as bool? ?? false;
      return Player(
        id: row['player_id'] as String?,
        name: name,
        score: row['score'] as int? ?? 0,
        streak: row['streak'] as int? ?? 0,
        state: ready ? 'Hazır' : 'Bekliyor',
        avatarIcon: profile?['avatar_icon'] as String?,
        avatarColor: profile?['avatar_color'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        avatarFrame: profile?['avatar_frame'] as String?,
        showcaseTitle: profile?['showcase_title'] as String?,
      );
    }).toList();
  }

  QuizQuestion _questionFromRow(Map<String, dynamic> row) {
    final correctOption = row['correct_option'] as String;
    final category = row['categories'] is Map<String, dynamic>
        ? (row['categories'] as Map<String, dynamic>)['name'] as String
        : row['category_id'] as String;
    final answerMap = {
      'A': row['option_a'] as String? ?? '',
      'B': row['option_b'] as String? ?? '',
      'C': row['option_c'] as String? ?? '',
      'D': row['option_d'] as String? ?? '',
    };
    final answers = [
      answerMap['A']!,
      answerMap['B']!,
      answerMap['C']!,
      answerMap['D']!,
    ].where((answer) => answer.trim().isNotEmpty && answer != '-').toList();

    return QuizQuestion(
      id: row['id'] as String,
      category: category,
      prompt: row['prompt'] as String,
      answers: answers,
      correctAnswer: answerMap[correctOption] ?? answers.first,
      explanation: row['explanation'] as String? ?? '',
      explanationKu: row['explanation_ku'] as String?,
      explanationTr: row['explanation_tr'] as String?,
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
    _roomChannel(roomId).onBroadcast(
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
    await _roomChannel(
      roomId,
    ).sendBroadcastMessage(event: 'game_event', payload: payload);
  }

  @override
  Future<Contest?> loadTodayContest() async {
    try {
      final res = await client.rpc('get_today_contest');
      if (res == null || res.isEmpty) return null;
      return Contest.fromJson(res);
    } catch (e) {
      return _offline.loadTodayContest();
    }
  }

  @override
  Future<ContestEntry?> submitContestEntry({
    required String contestId,
    required int correctCount,
  }) async {
    try {
      final res = await client.rpc(
        'submit_contest_entry',
        params: {'p_contest_id': contestId, 'p_correct_count': correctCount},
      );
      if (res == null) return null;
      return ContestEntry.fromJson({
        'id': res['entry_id'],
        'contest_id': contestId,
        'user_id': client.auth.currentUser?.id ?? '',
        'score': res['score'],
        'correct_count': correctCount,
        'finished_at': DateTime.now().toIso8601String(),
        'rank': res['rank'],
      });
    } catch (e) {
      return _offline.submitContestEntry(
        contestId: contestId,
        correctCount: correctCount,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> claimContestReward(String contestId) async {
    try {
      final res = await client.rpc(
        'claim_contest_reward',
        params: {'p_contest_id': contestId},
      );
      return res;
    } catch (e) {
      return _offline.claimContestReward(contestId);
    }
  }

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async {
    try {
      final res =
          await client.rpc(
                'get_contest_leaderboard',
                params: {'p_contest_id': contestId, 'p_limit': limit},
              )
              as List<dynamic>;
      return res
          .map(
            (row) =>
                ContestLeaderboardRow.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return _offline.getContestLeaderboard(contestId: contestId, limit: limit);
    }
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      return _offline.loadFriends();
    }
  }

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async {
    try {
      final friends = await loadFriends();
      friends.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      return friends;
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      return _offline.saveTournamentProgress(
        stage,
        userScore,
        opponentScore,
        botWinners,
      );
    }
  }

  @override
  Future<TournamentBracket> joinTournament() async {
    try {
      return _offline.joinTournament();
    } catch (e) {
      return _offline.joinTournament();
    }
  }

  @override
  Future<TournamentBracket?> loadTournamentBracket() async {
    try {
      return _offline.loadTournamentBracket();
    } catch (e) {
      return _offline.loadTournamentBracket();
    }
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    try {
      return _offline.submitTournamentMatch(
        matchId: matchId,
        playerScore: playerScore,
        opponentScore: opponentScore,
      );
    } catch (e) {
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
      return _offline.loadTournamentStandings(limit: limit);
    } catch (e) {
      return _offline.loadTournamentStandings(limit: limit);
    }
  }

  @override
  Future<int> claimTournamentChampionReward() async {
    try {
      final response = await client.rpc<dynamic>('claim_tournament_reward');
      return (_firstRow(response)?['coins'] as int?) ?? 0;
    } catch (e) {
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
    } catch (e) {
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
