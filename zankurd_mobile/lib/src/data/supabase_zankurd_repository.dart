import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_entry.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import 'mock_zankurd_repository.dart';

class SupabaseZanKurdRepository extends MockZanKurdRepository {
  SupabaseZanKurdRepository(this.client);

  final SupabaseClient client;

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
    String avatarColor = '#177A56',
  }) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'avatar_color': avatarColor,
    });
  }

  @override
  Future<void> ensureProfile() {
    return upsertProfile(displayName: 'ZanKurd Oyuncusu');
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
    } catch (_) {}
    return 'ZanKurd Oyuncusu';
  }

  @override
  Future<void> updateProfileName(String name) async {
    await upsertProfile(displayName: name);
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
        totalScore: row['total_score'] != null ? (row['total_score'] as num).toInt() : 0,
        bestStreak: row['best_streak'] != null ? (row['best_streak'] as num).toInt() : 0,
        roomsPlayed: row['rooms_played'] != null ? (row['rooms_played'] as num).toInt() : 0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> loadCategories() async {
    final rows = await client
        .from('categories')
        .select('name')
        .eq('is_active', true)
        .order('name');
    return rows.map((row) => row['name'] as String).toList();
  }

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) {
    return fetchApprovedQuestions(categoryId: categoryId, limit: limit);
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    int limit = 10,
  }) async {
    try {
      final categoryId = await _categoryIdByName(category);
      final rows =
          await _selectApprovedQuestions(
            categoryId: categoryId,
            limit: limit,
            includeRichColumns: true,
            difficultyMin: difficultyMin,
            difficultyMax: difficultyMax,
          ).catchError(
            (_) => _selectApprovedQuestions(
              categoryId: categoryId,
              limit: limit,
              includeRichColumns: false,
              difficultyMin: difficultyMin,
              difficultyMax: difficultyMax,
            ),
          );

      final questions = rows.map(_questionFromRow).toList();
      if (questions.isNotEmpty) return questions;
    } catch (_) {
      // Fall through to local examples if the rich schema is unavailable.
    }

    return super.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      limit: limit,
    );
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return super.loadRoomQuestions(room);

    try {
      final rows = await client
          .from('room_questions')
          .select(
            'question_index, questions(id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, question_type, image_url, difficulty)',
          )
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

  Future<List<QuizQuestion>> fetchApprovedQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final rows =
        await _selectApprovedQuestions(
          categoryId: categoryId,
          limit: limit,
          includeRichColumns: true,
        ).catchError(
          (_) => _selectApprovedQuestions(
            categoryId: categoryId,
            limit: limit,
            includeRichColumns: false,
          ),
        );
    return rows.map(_questionFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> _selectApprovedQuestions({
    required String? categoryId,
    required int limit,
    required bool includeRichColumns,
    int? difficultyMin,
    int? difficultyMax,
  }) async {
    final columns = includeRichColumns
        ? 'id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, question_type, image_url, difficulty'
        : 'id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty';
    final query = client
        .from('questions')
        .select(columns)
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

    final rows = await filteredQuery.order('difficulty').limit(limit);
    return rows;
  }

  @override
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'}) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await upsertProfile(displayName: 'ZanKurd Oyuncusu');

    final localRoom = createRoom(category: category);
    final categoryId = await _categoryIdByName(category);

    final room = await client
        .from('rooms')
        .insert({
          'code': localRoom.code,
          'host_id': user.id,
          'category_id': categoryId,
          'question_count': localRoom.questionCount,
          'seconds_per_question': 15,
        })
        .select('id, code')
        .single();

    await client.from('room_players').insert({
      'room_id': room['id'],
      'player_id': user.id,
      'is_ready': true,
    });

    final players = await _loadRoomPlayersById(room['id'] as String);
    return localRoom.copyWith(
      id: room['id'] as String,
      code: room['code'] as String,
      players: players.isEmpty ? localRoom.players : players,
    );
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await upsertProfile(displayName: 'ZanKurd Oyuncusu');

    final room = await client
        .from('rooms')
        .select('id, code, question_count, categories(name)')
        .eq('code', code.trim().toUpperCase())
        .single();

    try {
      await client.from('room_players').insert({
        'room_id': room['id'],
        'player_id': user.id,
        'is_ready': false,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    final players = await _loadRoomPlayersById(room['id'] as String);
    final category = room['categories'] is Map<String, dynamic>
        ? (room['categories'] as Map<String, dynamic>)['name'] as String
        : 'Ziman';

    return createRoom(category: category).copyWith(
      id: room['id'] as String,
      code: room['code'] as String,
      questionCount: room['question_count'] as int? ?? 10,
      players: players,
    );
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    final id = room.id;
    if (id == null) return room.players;
    return _loadRoomPlayersById(id);
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
  Future<int> getProfileCoins() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return 0;
      final profile = await client
          .from('profiles')
          .select('coins')
          .eq('id', user.id)
          .maybeSingle();
      return profile?['coins'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    int responseMs = 2000,
  }) async {
    final roomId = room.id;
    if (roomId == null) {
      return super.submitAnswer(
        room: room,
        question: question,
        selectedOptionOptionKey: selectedOptionOptionKey,
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
    await upsertProfile(displayName: 'ZanKurd Oyuncusu');

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
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await upsertProfile(displayName: 'ZanKurd Oyuncusu');
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
          .select(
            'questions(id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, question_type, image_url, difficulty)',
          )
          .eq('player_id', user.id)
          .order('created_at', ascending: false);

      final questions = rows
          .map((row) => row['questions'])
          .whereType<Map<String, dynamic>>()
          .map(_questionFromRow)
          .toList();

      if (questions.isNotEmpty) return questions;
    } catch (_) {
      // Fallback if favorites view/policy is not installed yet
    }
    return super.loadFavoriteQuestions();
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) async {
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
    } catch (_) {
      return super.loadLeaderboard(limit: limit);
    }
  }

  RealtimeChannel subscribeToRoom({
    required String roomId,
    required void Function(Map<String, dynamic> payload) onBroadcast,
  }) {
    final channel = client.channel('room:$roomId');
    channel
        .onBroadcast(
          event: 'room_state',
          callback: (payload) => onBroadcast(payload),
        )
        .subscribe();
    return channel;
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
        .select('player_id, score, streak, is_ready, profiles(display_name)')
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
}
