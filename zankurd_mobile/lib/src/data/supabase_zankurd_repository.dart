import 'dart:math';

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

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    try {
      final seed = MockZanKurdRepository.dailySeed();

      // Soru sayısını öğren, gün tohumlu pencereden çek.
      final countResponse = await client
          .from('questions')
          .count(CountOption.exact);
      final total = countResponse;
      if (total <= 0) return super.loadDailyQuestions(limit: limit);

      const windowSize = 60;
      final maxOffset = total > windowSize ? total - windowSize : 0;
      final offset = maxOffset == 0 ? 0 : (seed * 37) % maxOffset;

      final rows = await client
          .from('questions')
          .select(
            'id, category_id, categories(name), prompt, option_a, option_b, option_c, option_d, correct_option, explanation, question_type, image_url, difficulty',
          )
          .eq('is_approved', true)
          .order('id')
          .range(offset, offset + windowSize - 1);

      final pool = rows.map(_questionFromRow).toList()..shuffle(Random(seed));
      final selected = pool.take(limit).toList();
      if (selected.isNotEmpty) return selected;
    } catch (_) {
      // Şema/politika eksikse yerel soru bankasına düş.
    }
    return super.loadDailyQuestions(limit: limit);
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
    await ensureProfile();

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
    await ensureProfile();

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
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
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
        'p_response_ms': 2000, // Hardcoded for now
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
    } catch (_) {
      return super.loadCoinBalance();
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
    final earned = await super.awardQuizCoins(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
      room: room,
    );

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
    } catch (_) {
      return _insertQuizCoinsFallback(
        earned: earned,
        score: score,
        correctCount: correctCount,
        bestStreak: bestStreak,
        totalQuestions: totalQuestions,
      );
    }
  }

  Future<int> _insertQuizCoinsFallback({
    required int earned,
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) async {
    if (earned <= 0) return 0;

    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      await client.from('coin_transactions').insert({
        'player_id': user.id,
        'amount': earned,
        'reason':
            'quiz_complete:score=$score,correct=$correctCount,streak=$bestStreak,total=$totalQuestions',
      });
      return earned;
    } catch (_) {
      return earned;
    }
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

  @override
  Future<bool> canSpinToday() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      final rows = await client
          .from('coin_transactions')
          .select('created_at')
          .eq('player_id', user.id)
          .like('reason', 'daily_spin%')
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return true;
      final last = DateTime.parse(rows.first['created_at'] as String).toUtc();
      final now = DateTime.now().toUtc();
      return last.year != now.year ||
          last.month != now.month ||
          last.day != now.day;
    } catch (_) {
      return super.canSpinToday();
    }
  }

  @override
  Future<int> awardSpinCoins() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();

      final response = await client.rpc('claim_daily_spin');
      if (response is Map<String, dynamic>) {
        final amount = (response['amount'] as num?)?.toInt() ?? 0;
        if (amount >= 0) return amount;
      }
      if (response is List && response.isNotEmpty) {
        final first = response.first;
        if (first is Map<String, dynamic>) {
          final amount = (first['amount'] as num?)?.toInt() ?? 0;
          if (amount >= 0) return amount;
        }
      }
      throw StateError('Daily spin RPC returned no reward for ${user.id}.');
    } catch (_) {
      return super.awardSpinCoins();
    }
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
