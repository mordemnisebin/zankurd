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
import '../providers/analytics_consent_provider.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';
import '../config/category_visibility.dart';
import 'mock_zankurd_repository.dart';
import 'xp_store.dart';
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

Map<String, dynamic> _requiredJsonObject(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
  }
  throw FormatException('${keys.join('/')} must be a non-empty string.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$key must be a string or null.');
}

int _requiredInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num && value.isFinite) {
      final parsed = value.toInt();
      if (value == parsed) return parsed;
    }
  }
  throw FormatException('${keys.join('/')} must be an integer.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a timestamp.');
  return DateTime.parse(value);
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('$key must be present.');
  }
  return _optionalString(json, key);
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String field,
) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw FormatException('$field contains missing or unexpected fields.');
  }
}

DateTime? _optionalDateTimeFromKeys(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key must be a timestamp or null.');
    }
    return DateTime.parse(value);
  }
  return null;
}

ResumedPendingAnswer? _requiredPendingAnswer(Map<String, dynamic> json) {
  if (!json.containsKey('pending_answer')) {
    throw const FormatException('pending_answer must be present.');
  }
  final rawPending = json['pending_answer'];
  if (rawPending == null) return null;

  final pending = _requiredJsonObject(rawPending, 'pending_answer');
  const forbiddenResultFields = {
    'correct_option',
    'correct_option_key',
    'is_correct',
    'points',
    'points_awarded',
    'new_score',
    'new_streak',
    'score',
    'streak',
    'explanation',
    'explanation_ku',
    'explanation_tr',
  };
  final leakedField = forbiddenResultFields
      .where(pending.containsKey)
      .firstOrNull;
  if (leakedField != null) {
    throw FormatException(
      'pending_answer must not contain result field $leakedField.',
    );
  }

  final questionIndex = _requiredInt(pending, const ['question_index']);
  final responseMs = _requiredInt(pending, const ['response_ms']);
  final selectedOptionKey = _requiredString(pending, const [
    'selected_option',
    'selected_option_key',
  ]);
  if (questionIndex < 0 || responseMs < 0) {
    throw const FormatException(
      'pending_answer index and response_ms must be non-negative.',
    );
  }
  if (!const {'A', 'B', 'C', 'D', 'TIMEOUT'}.contains(selectedOptionKey)) {
    throw const FormatException('pending_answer selected_option is invalid.');
  }

  return ResumedPendingAnswer(
    questionId: _requiredString(pending, const ['question_id']),
    questionIndex: questionIndex,
    selectedOptionKey: selectedOptionKey,
    responseMs: responseMs,
  );
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
  List<QuizQuestion> get playableQuestions => _offline.playableQuestions;

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

  /// Ağ hatasıyla sunucuya yazılamayan bir avatar değişikliği varken
  /// açık kalır. `loadAvatarIdentity` bu bayrak açıkken sunucu satırını
  /// okumaz — yoksa bağlantı dönünce eski avatar kullanıcının yüzüne geri
  /// gelirdi (yerel kopya zaten güncel, sunucu satırı henüz değil).
  static const _avatarIdentityDirtyKey = 'zankurd.avatarIdentity.dirtyPending';

  Future<bool> _avatarIdentityDirty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_avatarIdentityDirtyKey) ?? false;
  }

  Future<void> _setAvatarIdentityDirty(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_avatarIdentityDirtyKey, true);
    } else {
      await prefs.remove(_avatarIdentityDirtyKey);
    }
  }

  /// Sunucuya yazmayı bir kez dener; başarırsa bekleyen bayrağı temizler.
  Future<bool> _pushAvatarIdentity(AvatarIdentity identity) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;
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
      await _setAvatarIdentityDirty(false);
      return true;
    } on PostgrestException catch (error, stack) {
      // Sunucu veriyi REDDETTİ. Bu kalıcı bir rettir, geçici bir ağ
      // sorunu değil — ve yutulduğu için kullanıcıya yalan söylüyordu:
      // `avatar_editor_screen._save()` başarı sayıp `pop(true)` ile
      // kapanıyordu. 600 coin ödenen Neon çerçevesi tam buradan
      // kayboluyordu; `protect_paid_profile_cosmetics` `neon` değerini
      // reddediyor, istisna burada yutuluyor, ekran "kaydedildi" gibi
      // kapanıyordu (2026-08-06 denetimi).
      //
      // Kalıcı ret beklemede bırakılmaz — tekrar denemek de reddedilir.
      await _setAvatarIdentityDirty(false);
      _recordError(error, stack, reason: 'updateAvatarIdentity rejected');
      rethrow;
    } catch (error, stack) {
      // Ağ/bağlantı kaynaklı geçici hata: beklemede bırak, bir daha
      // denenebilsin.
      await _setAvatarIdentityDirty(true);
      _recordError(error, stack, reason: 'updateAvatarIdentity failed');
      return false;
    }
  }

  @override
  Future<AvatarIdentity> loadAvatarIdentity() async {
    if (await _avatarIdentityDirty()) {
      // Bekleyen bir yerel değişiklik var. Önce tekrar göndermeyi dene
      // (bağlantı dönmüş olabilir); olmazsa sunucudan OKUMA — bu, az önce
      // "kaydedildi" denen değişikliği kullanıcının yüzüne geri getirirdi
      // (2026-08-14 denetimi, bkz. updateAvatarIdentity).
      final local = await _offline.loadAvatarIdentity();
      final pushed = await _pushAvatarIdentity(local);
      if (!pushed) return local;
    }
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
    if (client.auth.currentUser == null) return;
    await _pushAvatarIdentity(identity);
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
  Future<void> deleteAvatarPhoto() async {
    final user = client.auth.currentUser;
    if (user == null) return _offline.deleteAvatarPhoto();
    // Uzantı içerik türünden seçiliyor (`uploadAvatarPhoto`), yani aynı
    // kullanıcının geçmişte hem .png hem .jpg nesnesi olabilir. İkisini de
    // kaldırmak gerekir; `remove` var olmayan yolu sorun etmez.
    await client.storage.from('avatars').remove([
      '${user.id}/avatar.jpg',
      '${user.id}/avatar.png',
    ]);
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
    return _offline.loadCategories();
  }

  @override
  Future<List<String>> loadMatchmakingCategories() async {
    final rows = await client
        .from('categories')
        .select('name')
        .eq('is_active', true)
        .order('name');
    return visibleCategories(rows.map((row) => row['name'] as String));
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
    int questionCount = 10,
    int entryFee = 0,
  }) async {
    try {
      if (client.auth.currentUser == null) {
        await signInAnonymously();
      }
      await ensureProfile();

      final response = await client.rpc(
        'create_online_room',
        params: {
          'p_category_name': category,
          'p_seconds_per_question': secondsPerQuestion,
          'p_question_count': questionCount,
          'p_entry_fee': entryFee,
        },
      );
      final snapshot = _requiredJsonObject(response, 'create_online_room');
      final roomId = _requiredString(snapshot, const ['room_id']);
      final roomCode = _requiredString(snapshot, const ['code']);
      final hostId = _requiredString(snapshot, const ['host_id']);
      final canonicalCategory = _requiredString(snapshot, const [
        'category_name',
      ]);
      final serverQuestionCount = _requiredInt(snapshot, const [
        'question_count',
      ]);
      final serverSeconds = _requiredInt(snapshot, const [
        'seconds_per_question',
      ]);
      final serverEntryFee = snapshot['entry_fee'] != null
          ? (snapshot['entry_fee'] as num).toInt()
          : entryFee;

      final players = await _loadRoomPlayersById(roomId);
      return GameRoom(
        id: roomId,
        name: '1vs1',
        code: roomCode,
        category: canonicalCategory,
        players: players,
        status: _roomStatusFromValue(snapshot['status'] ?? 'lobby'),
        questionCount: serverQuestionCount,
        secondsPerQuestion: serverSeconds,
        entryFee: serverEntryFee,
        hostId: hostId,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'createOnlineRoom failed');
      rethrow;
    }
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    final normalizedCode = normalizeRoomCode(code);
    if (!isSupportedRoomCode(normalizedCode)) {
      throw const FormatException('Invalid room code');
    }
    client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();

    late final dynamic response;
    try {
      response = await client.rpc(
        'join_room_by_code',
        params: {'p_code': normalizedCode},
      );
    } on PostgrestException catch (error, stack) {
      _recordError(error, stack, reason: 'joinOnlineRoom rejected');
      throw RoomJoinException(
        roomJoinFailureReasonForMessage(error.message),
        error.message,
      );
    }
    final rawSnapshot = response is List ? response.firstOrNull : response;
    if (rawSnapshot == null) {
      throw StateError('join_room_by_code boş yanıt döndürdü: oda bulunamadı');
    }
    final room = _requiredJsonObject(rawSnapshot, 'join_room_by_code');
    final roomId = _requiredString(room, const ['room_id']);
    final hostId = _requiredString(room, const ['host_id']);
    final players = await _loadRoomPlayersById(roomId);
    final category = room['category_name'] as String? ?? 'Ziman';

    final joined = createRoom(category: category).copyWith(
      id: roomId,
      // `createRoom()` yerel/solo oda için 'Hevalên Zanînê' adını taşır;
      // burada üzerine yazılmazsa katılan oyuncu aynı odayı ev sahibinin
      // gördüğü '1vs1' yerine bu adla görüyordu — aynı oda iki farklı
      // başlıkla açılıyordu. `createOnlineRoom`/`loadRoomSnapshot`
      // (ev sahibi ve sonraki yeniden-yüklemeler) zaten '1vs1' kullanıyor
      // (2026-08-14 denetimi).
      name: '1vs1',
      code: room['code'] as String,
      questionCount: room['question_count'] as int? ?? 10,
      players: players,
      hostId: hostId,
      secondsPerQuestion:
          (room['seconds_per_question'] as int?) ??
          GameRoom.defaultSecondsPerQuestion,
      entryFee: (room['entry_fee'] as num?)?.toInt() ?? 0,
    );

    // Katılan oyuncu `join_room_by_code`un yazdığı gibi HAZIR DEĞİL başlar.
    //
    // Burada bir zamanlar `updateReady(joined, true)` vardı. Amacı meşruydu:
    // ekranın anahtarı iki rolde de "açık" çiziliyordu, katılan kendini hazır
    // sanıyor ama listede "Bekliyor" görünüyordu ve ev sahibi yarışı hiç
    // başlatamıyordu (2026-08-01). O uyuşmazlığın asıl çaresi ekranın gerçek
    // durumu okuması oldu — `room_screen.dart` içindeki `ready` alıcısı.
    // Sunucuya zorla `true` yazmak ise ayrı ve istenmeyen bir şey yaptı:
    // odaya yeni giren kişi hiçbir şeye dokunmadan hazır sayılıyor ve ev
    // sahibi, öteki daha ekranı görmeden yarışı başlatabiliyordu
    // (2026-08-13 iki cihazlı denetimi, uygulama sahibinin bildirimi).
    //
    // "Hazırım" bir onaydır; onayı katılan kişi verir.
    return joined;
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    final row = await client
        .from('rooms')
        .select(
          'id, code, host_id, question_count, seconds_per_question, entry_fee, status, '
          'categories(name)',
        )
        .eq('id', roomId)
        .single();
    final players = await _loadRoomPlayersById(roomId);
    final category = row['categories'] as Map<String, dynamic>?;

    return GameRoom(
      id: row['id'] as String? ?? roomId,
      name: '1vs1',
      code: row['code'] as String? ?? '',
      category: category?['name'] as String? ?? 'Ziman',
      players: players,
      status: _roomStatusFromValue(row['status']),
      questionCount: (row['question_count'] as num?)?.toInt() ?? 10,
      secondsPerQuestion:
          (row['seconds_per_question'] as num?)?.toInt() ??
          GameRoom.defaultSecondsPerQuestion,
      entryFee: (row['entry_fee'] as num?)?.toInt() ?? 0,
      hostId: row['host_id'] as String?,
    );
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    final response = await client.rpc('get_my_resumable_room');
    if (response == null) return null;

    final json = _requiredJsonObject(response, 'get_my_resumable_room');
    final roomId = _requiredString(json, const ['room_id']);
    final room = await loadRoomSnapshot(roomId);
    if (room.id != roomId) {
      throw const FormatException(
        'Resumable room snapshot id does not match room_id.',
      );
    }

    final rawAnswers = json['answers'];
    if (rawAnswers is! List) {
      throw const FormatException('answers must be a JSON array.');
    }
    final answers = rawAnswers
        .map((rawAnswer) {
          final answer = _requiredJsonObject(rawAnswer, 'answers[]');
          return ResumedAnswer(
            questionId: _requiredString(answer, const ['question_id']),
            questionIndex: _requiredInt(answer, const ['question_index']),
            selectedOptionKey: _requiredString(answer, const [
              'selected_option',
              'selected_option_key',
            ]),
            correctOptionKey: _requiredString(answer, const [
              'correct_option',
              'correct_option_key',
            ]),
            isCorrect: _requiredBool(answer, 'is_correct'),
            pointsAwarded: _requiredInt(answer, const [
              'points_awarded',
              'points',
            ]),
            responseMs: _requiredInt(answer, const ['response_ms']),
            explanation: _optionalString(answer, 'explanation'),
            explanationKu: _optionalString(answer, 'explanation_ku'),
            explanationTr: _optionalString(answer, 'explanation_tr'),
          );
        })
        .toList(growable: false);

    return RoomResumeSnapshot(
      room: room,
      currentQuestionIndex: _requiredInt(json, const [
        'current_question_index',
      ]),
      ownScore: _requiredInt(json, const ['own_score']),
      streak: _requiredInt(json, const ['streak', 'own_streak']),
      bestStreak: _requiredInt(json, const ['best_streak', 'own_best_streak']),
      correctCount: _requiredInt(json, const ['correct_count']),
      wrongCount: _requiredInt(json, const ['wrong_count']),
      answers: answers,
      pendingAnswer: _requiredPendingAnswer(json),
      serverNow: _requiredDateTime(json, 'server_now'),
      questionStartedAt: _optionalDateTimeFromKeys(json, const [
        'current_question_started_at',
        'question_started_at',
      ]),
      deadline: _optionalDateTimeFromKeys(json, const [
        'current_question_deadline',
        'deadline',
      ]),
      remainingMs: _requiredInt(json, const [
        'current_question_remaining_ms',
        'remaining_ms',
      ]),
    );
  }

  @override
  Future<RoomResultSnapshot?> loadMyPendingRoomResult() async {
    final response = await client.rpc('get_my_pending_room_result');
    return _parseRoomResultResponse(
      response,
      source: 'get_my_pending_room_result',
    );
  }

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null || roomId.isEmpty) {
      throw ArgumentError.value(roomId, 'room.id', 'Room id is required.');
    }
    final response = await client.rpc(
      'get_my_room_result',
      params: {'p_room_id': roomId},
    );
    return _parseRoomResultResponse(
      response,
      source: 'get_my_room_result',
      expectedRoomId: roomId,
    );
  }

  RoomResultSnapshot? _parseRoomResultResponse(
    Object? response, {
    required String source,
    String? expectedRoomId,
  }) {
    if (response == null) return null;

    final json = _requiredJsonObject(response, source);
    _requireExactKeys(json, const {
      'room',
      'own_player_id',
      'players',
      'question_ids',
      'answers',
      'winner_id',
      'ended_reason',
      'forfeited_by',
      'finished_at',
    }, source);

    final roomJson = _requiredJsonObject(json['room'], 'room');
    _requireExactKeys(roomJson, const {
      'id',
      'code',
      'host_id',
      'category_name',
      'question_count',
      'seconds_per_question',
      'status',
      'current_question_index',
    }, 'room');
    final roomId = _requiredString(roomJson, const ['id']);
    if (expectedRoomId != null && roomId != expectedRoomId) {
      throw const FormatException(
        'Room result snapshot id does not match requested room.',
      );
    }
    final statusValue = _requiredString(roomJson, const ['status']);
    final questionCount = _requiredInt(roomJson, const ['question_count']);
    final currentQuestionIndex = _requiredInt(roomJson, const [
      'current_question_index',
    ]);
    final secondsPerQuestion = _requiredInt(roomJson, const [
      'seconds_per_question',
    ]);
    final hostId = _requiredNullableString(roomJson, 'host_id');
    if (statusValue != 'finished' ||
        questionCount < 1 ||
        currentQuestionIndex != questionCount ||
        !GameRoom.allowedSecondsPerQuestion.contains(secondsPerQuestion)) {
      throw const FormatException('Room result is not terminal and complete.');
    }

    final ownPlayerId = _requiredString(json, const ['own_player_id']);
    final rawPlayers = json['players'];
    if (rawPlayers is! List || rawPlayers.length != 2) {
      throw const FormatException('players must contain exactly two players.');
    }
    final players = rawPlayers
        .map((rawPlayer) {
          final player = _requiredJsonObject(rawPlayer, 'players[]');
          _requireExactKeys(player, const {
            'player_id',
            'display_name',
            'final_score',
            'final_streak',
          }, 'players[]');
          final score = _requiredInt(player, const ['final_score']);
          final streak = _requiredInt(player, const ['final_streak']);
          if (score < 0 || streak < 0) {
            throw const FormatException(
              'Final score and streak must be non-negative.',
            );
          }
          return Player(
            id: _requiredString(player, const ['player_id']),
            name: _requiredString(player, const ['display_name']),
            score: score,
            state: Player.readyState,
            streak: streak,
          );
        })
        .toList(growable: false);
    final playerIds = players.map((player) => player.id!).toSet();
    if (playerIds.length != 2 || !playerIds.contains(ownPlayerId)) {
      throw const FormatException(
        'Result players are not two distinct members.',
      );
    }
    if (hostId != null && !playerIds.contains(hostId)) {
      throw const FormatException('Room host is not a result player.');
    }

    final rawQuestionIds = json['question_ids'];
    if (rawQuestionIds is! List || rawQuestionIds.length != questionCount) {
      throw const FormatException(
        'question_ids must contain every room question.',
      );
    }
    final questionIds = rawQuestionIds
        .map((value) {
          if (value is! String || value.isEmpty) {
            throw const FormatException(
              'question_ids[] must be a non-empty string.',
            );
          }
          return value;
        })
        .toList(growable: false);
    if (questionIds.toSet().length != questionCount) {
      throw const FormatException('question_ids must be unique.');
    }

    final rawAnswers = json['answers'];
    if (rawAnswers is! List || rawAnswers.length != questionCount) {
      throw const FormatException('answers must contain every own answer.');
    }
    final answers = <ResumedAnswer>[];
    for (var index = 0; index < rawAnswers.length; index++) {
      final answer = _requiredJsonObject(rawAnswers[index], 'answers[]');
      _requireExactKeys(answer, const {
        'question_id',
        'question_index',
        'selected_option',
        'correct_option',
        'is_correct',
        'points_awarded',
        'response_ms',
        'explanation',
        'explanation_ku',
        'explanation_tr',
      }, 'answers[]');
      final questionId = _requiredString(answer, const ['question_id']);
      final questionIndex = _requiredInt(answer, const ['question_index']);
      final selectedOption = _requiredString(answer, const ['selected_option']);
      final correctOption = _requiredString(answer, const ['correct_option']);
      final isCorrect = _requiredBool(answer, 'is_correct');
      final points = _requiredInt(answer, const ['points_awarded']);
      final responseMs = _requiredInt(answer, const ['response_ms']);
      if (questionIndex != index || questionId != questionIds[index]) {
        throw const FormatException(
          'Answers are not in canonical question order.',
        );
      }
      if (!const {'A', 'B', 'C', 'D', 'TIMEOUT'}.contains(selectedOption) ||
          !const {'A', 'B', 'C', 'D'}.contains(correctOption) ||
          isCorrect != (selectedOption == correctOption) ||
          points < 0 ||
          (!isCorrect && points != 0) ||
          responseMs < 0 ||
          responseMs > secondsPerQuestion * 1000) {
        throw const FormatException('Answer result fields are inconsistent.');
      }
      answers.add(
        ResumedAnswer(
          questionId: questionId,
          questionIndex: questionIndex,
          selectedOptionKey: selectedOption,
          correctOptionKey: correctOption,
          isCorrect: isCorrect,
          pointsAwarded: points,
          responseMs: responseMs,
          explanation: _requiredNullableString(answer, 'explanation'),
          explanationKu: _requiredNullableString(answer, 'explanation_ku'),
          explanationTr: _requiredNullableString(answer, 'explanation_tr'),
        ),
      );
    }

    final ownPlayer = players.singleWhere((player) => player.id == ownPlayerId);
    final ownScore = answers.fold<int>(
      0,
      (total, answer) => total + answer.pointsAwarded,
    );
    var ownStreak = 0;
    for (final answer in answers.reversed) {
      if (!answer.isCorrect) break;
      ownStreak++;
    }
    if (ownPlayer.score != ownScore || ownPlayer.streak != ownStreak) {
      throw const FormatException('Own final score does not match answers.');
    }

    final endedReason = _requiredString(json, const ['ended_reason']);
    final forfeitedBy = _requiredNullableString(json, 'forfeited_by');
    if (endedReason != 'completed' || forfeitedBy != null) {
      throw const FormatException('Room result is not a normal completion.');
    }
    final winnerId = _requiredNullableString(json, 'winner_id');
    final sortedPlayers = [...players]
      ..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        return scoreOrder != 0 ? scoreOrder : a.id!.compareTo(b.id!);
      });
    final expectedWinner = sortedPlayers[0].score == sortedPlayers[1].score
        ? null
        : sortedPlayers[0].id;
    if (winnerId != expectedWinner) {
      throw const FormatException('winner_id does not match final scores.');
    }

    final room = GameRoom(
      id: roomId,
      name: '1vs1',
      code: _requiredString(roomJson, const ['code']),
      category: _requiredString(roomJson, const ['category_name']),
      players: List.unmodifiable(players),
      status: RoomStatus.finished,
      questionCount: questionCount,
      secondsPerQuestion: secondsPerQuestion,
      hostId: hostId,
    );
    return RoomResultSnapshot(
      room: room,
      ownPlayerId: ownPlayerId,
      questionIds: questionIds,
      answers: answers,
      winnerId: winnerId,
      endedReason: endedReason,
      forfeitedBy: forfeitedBy,
      finishedAt: _requiredDateTime(json, 'finished_at'),
    );
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null || roomId.isEmpty) {
      throw ArgumentError.value(roomId, 'room.id', 'Room id is required.');
    }
    await client.rpc('acknowledge_room_result', params: {'p_room_id': roomId});
  }

  Future<RoomResumeSnapshot?> _loadExpectedRoomResume(String roomId) async {
    final snapshot = await loadMyResumableRoom();
    if (snapshot != null && snapshot.room.id != roomId) {
      throw const FormatException(
        'Room session RPC returned a different resumable room.',
      );
    }
    return snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return null;

    await client.rpc('mark_room_client_ready', params: {'p_room_id': roomId});
    return _loadExpectedRoomResume(roomId);
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    final roomId = room.id;
    if (roomId == null) return null;

    await client.rpc(
      'advance_room_question',
      params: {
        'p_room_id': roomId,
        'p_expected_question_index': expectedQuestionIndex,
      },
    );
    return _loadExpectedRoomResume(roomId);
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null || roomId.isEmpty) {
      return RoomLeaveOutcome(
        status: room.status.name,
        reason: 'local_room',
        forfeitedBy: null,
      );
    }
    final response = await client.rpc(
      'leave_room',
      params: {'p_room_id': roomId},
    );
    final json = _requiredJsonObject(response, 'leave_room');
    _requireExactKeys(json, const {
      'status',
      'reason',
      'forfeited_by',
    }, 'leave_room');
    return RoomLeaveOutcome(
      status: _requiredString(json, const ['status']),
      reason: _requiredString(json, const ['reason']),
      forfeitedBy: _requiredNullableString(json, 'forfeited_by'),
    );
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
  Future<RoomEndState> loadRoomEndState(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) {
      return RoomEndState(
        status: room.status,
        endedReason: null,
        forfeitedBy: null,
      );
    }

    final row = await client
        .from('rooms')
        .select('status, ended_reason, forfeited_by')
        .eq('id', roomId)
        .single();
    return RoomEndState(
      status: _roomStatusFromValue(row['status']),
      endedReason: row['ended_reason'] as String?,
      forfeitedBy: row['forfeited_by'] as String?,
    );
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
  Future<bool> reportPlayerProfile({
    required String playerId,
    required String reason,
  }) async {
    try {
      await client.rpc(
        'report_player_profile',
        params: {'p_reported_id': playerId, 'p_reason': reason},
      );
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'reportPlayerProfile failed');
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
  Future<List<PlayerSearchResult>> loadBlockedPlayers() async {
    try {
      // `profiles!blocked_users_blocked_id_fkey(...)` embed'i PostgREST'te
      // HİÇBİR ZAMAN çalışmadı: `blocked_users.blocked_id` şemadaki tek
      // kısıtıyla `auth.users(id)`e bakıyor (2026-07-31_chat_moderation.sql),
      // `profiles`e değil — o isimde bir FK yok. Her çağrı şema/embed
      // hatasıyla düşüyor, catch onu boş listeye çeviriyordu; Ayarlar >
      // Engellenenler bu yüzden GERÇEKTEN engellenmiş kişisi olan bir
      // kullanıcıya bile "Kimseyi engellemedin" gösteriyor, "engeli
      // kaldır" düğmesi hiç çizilemiyordu (2026-08-14 denetimi).
      //
      // `loadBlockedPlayerIds` zaten aynı tabloyu embed'siz, iki adımda
      // okuyor — aynı deseni burada da kullan.
      final ids = await loadBlockedPlayerIds();
      if (ids.isEmpty) return const [];
      final profiles = await client
          .from('profiles')
          .select('id, display_name, player_tag')
          .inFilter('id', ids.toList());
      final byId = {for (final p in profiles) p['id'] as String: p};
      return ids.map((id) {
        final profile = byId[id];
        return PlayerSearchResult(
          id: id,
          displayName:
              (profile?['display_name'] as String?) ?? 'ZanKurd Oyuncusu',
          playerTag: profile?['player_tag'] as String?,
        );
      }).toList();
    } catch (e, s) {
      _recordError(e, s, reason: 'loadBlockedPlayers failed');
      // Okunamayan liste "kimse engelli değil" anlamına gelmez —
      // `loadBlockedPlayerIds`teki aynı gerekçeyle yukarı taşınır; ekran
      // hata durumunu gösterir, engellenmiş kişi sessizce kaybolmaz.
      rethrow;
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
      // Okunamayan engel durumu "kimse engelli değil" anlamına gelmez.
      // Hatayı çağırana taşı: ekran güvenli hata durumunu gösterebilsin ve
      // engellenmiş içeriği sessizce yeniden göstermesin.
      rethrow;
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

      final orderedIds = rows
          .map((row) => row['question_id'] as String)
          .toList();
      final byId = {
        for (final question in _offline.questions) question.id: question,
      };
      final unresolvedIds = orderedIds
          .where((id) => !byId.containsKey(id))
          .toList();

      // `unresolvedIds` çevrimiçi oda maçında kaydedilmiş favorilerdir:
      // `toggleFavoriteQuestion` gerçek `questions.id` uuid'sini yazar,
      // paketli bankada karşılığı yoktur. Eskiden bunlar süzülüp
      // atılıyordu — kayıt sunucuda dururken "Kaydedilen Sorular" hep
      // boş görünüyordu (2026-08-14 denetimi). Sunucudan çözülürler;
      // `correct_option` taşımadıkları için `hasHiddenAnswer` ile
      // işaretlenip yeniden oynatma bu soruları dışarıda bırakır
      // (favorite_questions_screen.dart).
      if (unresolvedIds.isNotEmpty) {
        try {
          final resolved = await _resolveServerFavoriteQuestions(unresolvedIds);
          byId.addAll(resolved);
        } catch (error, stack) {
          _recordError(
            error,
            stack,
            reason: 'loadFavoriteQuestions server resolve failed',
          );
        }
      }

      final questions = orderedIds
          .map((id) => byId[id])
          .whereType<QuizQuestion>()
          .toList();
      if (questions.isNotEmpty) return questions;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadFavoriteQuestions failed');
      return const [];
    }
    return const [];
  }

  Future<Map<String, QuizQuestion>> _resolveServerFavoriteQuestions(
    List<String> ids,
  ) async {
    final rows = await client
        .from('quiz_public_questions')
        .select(
          'id, category_id, prompt, option_a, option_b, option_c, '
          'option_d, question_type, image_url, difficulty',
        )
        .inFilter('id', ids);
    if (rows.isEmpty) return const {};

    final categoryIds = rows
        .map((row) => row['category_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final categoryNames = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final categories = await client
          .from('categories')
          .select('id, name')
          .inFilter('id', categoryIds);
      for (final row in categories) {
        categoryNames[row['id'] as String] = row['name'] as String? ?? 'Ziman';
      }
    }

    return {
      for (final row in rows)
        row['id'] as String: _roomQuestionFromRow({
          ...row,
          'category_name': categoryNames[row['category_id']] ?? 'Ziman',
        }),
    };
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
      // Ağ hatasında 0 dönmek, 3000 coini olan bir oyuncuya uçak modunda
      // "bakiyen bitti" gösterip dört jokeri birden kilitliyordu — hiçbir
      // yerde "çevrimdışısın" yazmıyordu, oyuncu coinlerini kaybettiğini
      // sanıyordu. Etki alanı hataları (yetki, şema) için 0 hâlâ makul bir
      // varsayılan; yalnız TAŞIMA hatasını yukarı taşı, çağıran (shop/home/
      // quiz ekranları) son bilinen bakiyeyi koruyup çevrimdışı durumunu
      // gösterebilsin (2026-08-14 denetimi).
      if (isLikelyOfflineError(error)) rethrow;
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

  /// Seri dondurma ücretini idempotent RPC ile tahsil eder.
  ///
  /// Göç (`2026-08-03_streak_freeze_idempotency.sql`) henüz uygulanmamış
  /// olabilir; o durumda PostgREST fonksiyonu bulamaz (`PGRST202`/42883) ve
  /// eski `spend_coins` yoluna düşülür. Düşülen yol idempotent OLMADIĞI
  /// için sonuçta `idempotent: false` döner ve çağıran belirsiz kalan bir
  /// tahsilatı tekrarlamaz. Böylece derleme, göçün önünde ya da ardında
  /// yayınlansa da çift çekim riski artmaz.
  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  }) async {
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'spend_streak_freeze',
        params: {'p_idempotency_key': idempotencyKey},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          return StreakFreezeChargeResult(
            outcome: response['already_charged'] == true
                ? StreakFreezeChargeOutcome.alreadyCharged
                : StreakFreezeChargeOutcome.charged,
            idempotent: true,
          );
        }
        return const StreakFreezeChargeResult(
          outcome: StreakFreezeChargeOutcome.insufficient,
          idempotent: true,
        );
      }
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.failed,
        idempotent: true,
      );
    } catch (error, stack) {
      if (_isMissingFunction(error)) {
        // Göç uygulanmamış: eski, idempotent OLMAYAN yol.
        final ok = await spendCoins(50, 'streak_freeze');
        return StreakFreezeChargeResult(
          outcome: ok
              ? StreakFreezeChargeOutcome.charged
              : StreakFreezeChargeOutcome.insufficient,
          idempotent: false,
        );
      }
      _recordError(error, stack, reason: 'spendStreakFreeze failed');
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.failed,
        idempotent: true,
      );
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
      // `loadCoinBalance`teki aynı gerekçe: taşıma hatasını yut, çağıranı
      // ("satın alınmadı") yalana zorla. `shop_screen.dart`ın dış catch'i
      // zaten `isLikelyOfflineError` ile çevrimdışı durumunu kuruyordu —
      // bu metod hiç fırlatmadığı için o dal hiç tetiklenemiyordu.
      if (isLikelyOfflineError(error)) rethrow;
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
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    // Ödül miktarını yalnızca sunucu belirler. İstemciden
    // coin_transactions'a yazma yolu yoktur. RPC/transport/parse hatası
    // yeniden deneme kuyruğuna alınabilmesi için çağırana taşınır;
    // sunucunun başarıyla döndürdüğü 0 ise geçerli bir sonuçtur.
    //
    // İki ayrı RPC var çünkü iki ayrı doğrulama rejimi var:
    //
    //   oda turu  → `claim_quiz_reward`: sunucu odayı, oyuncuları ve
    //               cevapları görebildiği için turu DOĞRULAR.
    //   solo tur  → `claim_solo_reward`: çevrimdışı banka istemcide
    //               olduğu için sunucu turu doğrulayamaz; talep
    //               doğrulanmadan kabul edilir ama günlük tavanla
    //               sınırlanır (bkz. 2026-08-10_solo_round_reward.sql).
    final isSolo = room?.id == null;
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      if (currentUserId?.trim() != user.id) {
        throw StateError('Quiz reward owner changed before claim RPC.');
      }
      final response = isSolo
          ? await client.rpc(
              'claim_solo_reward',
              params: {
                'p_correct_count': correctCount,
                'p_total_questions': totalQuestions,
                'p_best_streak': bestStreak,
              },
            )
          : await client.rpc(
              'claim_quiz_reward',
              params: {
                'p_room_id': room?.id,
                'p_score': score,
                'p_correct_count': correctCount,
                'p_best_streak': bestStreak,
                'p_total_questions': totalQuestions,
              },
            );
      if (currentUserId?.trim() != user.id) {
        throw StateError('Quiz reward owner changed during claim RPC.');
      }
      if (isSolo) {
        final amount = _amountFromRpcResponse(response) ?? 0;
        // `cap_reached` yalnız sunucu açıkça söylediğinde doğrudur.
        // Eksik alanı "tavana varıldı" saymak, olmayan bir sebep
        // uydurmak olurdu.
        final capReached = response is Map && response['cap_reached'] == true;
        return (amount: amount, dailyCapReached: capReached);
      }
      return (
        amount: _verifiedQuizRewardAmount(response, userId: user.id),
        dailyCapReached: false,
      );
    } on PostgrestException catch (error, stack) {
      // Göç henüz üretime uygulanmadıysa `claim_solo_reward` yoktur
      // (42883 undefined_function). Bu bir arıza değil, beklenen ara
      // durumdur: eski davranışa — solo turda sıfır jeton — sessizce
      // düşülür. Kuyruğa alınırsa hiç başarılamayacak bir talep birikir
      // ve oyuncuya yanlışlıkla "ödülün kaydedildi" denir.
      if (isSolo && error.code == '42883') {
        _recordError(
          error,
          stack,
          reason: 'claim_solo_reward missing — migration not applied yet',
        );
        return (amount: 0, dailyCapReached: false);
      }
      _recordError(error, stack, reason: 'claim quiz reward failed');
      rethrow;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'claim quiz reward failed');
      rethrow;
    }
  }

  @override
  Future<int> awardXp(int delta) async {
    if (delta <= 0) return 0;
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      if (currentUserId?.trim() != user.id) return 0;
      final response = await client.rpc<dynamic>(
        'award_xp_delta',
        params: {'p_delta': delta},
      );
      if (response is int) return response;
      if (response is num) return response.toInt();
      return 0;
    } on PostgrestException catch (error, stack) {
      // Göç uygulanmamışsa fonksiyon yoktur (42883). Bu bir arıza değil:
      // XP'nin cihazdaki hâli zaten yazıldı, sunucu tarafı sessizce
      // beklemeye devam eder.
      _recordError(
        error,
        stack,
        reason: error.code == '42883'
            ? 'award_xp_delta missing — migration not applied yet'
            : 'award_xp_delta failed',
      );
      return 0;
    } catch (error, stack) {
      // Ödül yolu OYUNCUYU BEKLETMEZ ve turu düşürmez: sunucuya XP
      // yazılamaması, tamamlanmış bir turu geçersiz kılmaz.
      _recordError(error, stack, reason: 'award_xp_delta failed');
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

  int _verifiedQuizRewardAmount(Object? response, {required String userId}) {
    final Map<String, dynamic>? json;
    if (response is Map) {
      json = Map<String, dynamic>.from(response);
    } else if (response is List && response.length == 1) {
      final first = response.single;
      json = first is Map ? Map<String, dynamic>.from(first) : null;
    } else {
      json = null;
    }

    if (json == null ||
        json.length != 2 ||
        !json.containsKey('amount') ||
        json['already_claimed'] is! bool) {
      throw StateError(
        'Quiz reward RPC returned an unverified result for $userId.',
      );
    }
    final rawAmount = json['amount'];
    if (rawAmount is! num ||
        !rawAmount.isFinite ||
        rawAmount != rawAmount.toInt() ||
        rawAmount < 0) {
      throw StateError(
        'Quiz reward RPC returned an invalid amount for $userId.',
      );
    }
    return rawAmount.toInt();
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
      // `_offline.canSpinToday()`nin yerel bir "bugün çevirdim" kaydı yok
      // — bu geri düşüş HER hatada sahte bir "hakkın var" üretiyordu.
      // Kullanıcı çevrimdışıyken düğme AÇIK görünüyor, "Çevir!"e basınca
      // `awardSpinCoins` de hatayı yutup 0 döndürüyor, ekran bunu "sunucu
      // reddetti" sayıp "Bugün zaten çevirdin." yazıyordu — oysa o gün
      // hiç çevrilmemişti. `spin_wheel_screen.dart` bu durum için doğru
      // yazılmıştı (`_statusOffline`, `isLikelyOfflineError` ile) ama bu
      // metod hiç fırlatmadığı için o dal ölü koddu (2026-08-14 denetimi).
      rethrow;
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
      // `canSpinToday`teki aynı gerekçe: 0 dönmek sunucunun bilinçli
      // reddiyle (gün sınırı) bir taşıma hatasını ayırt edilemez kılıyor,
      // ikisi de ekranda "Bugün zaten çevirdin." oluyordu. `RPC` gerçekten
      // `success:false` döndüğünde bu satıra hiç düşülmez (yukarıda ayrı
      // ele alınır) — buraya yalnız gerçek hata düşer, rethrow doğru olan.
      rethrow;
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
    try {
      return questionTypeFromStorage(row['question_type']);
    } on ArgumentError {
      return QuestionType.multipleChoice;
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
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    final response = await client.rpc('cancel_matchmaking');
    return _requiredJsonObject(response, 'cancel_matchmaking');
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
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME (addFriend'deki aynı kural).
      //
      // `_offline.markLessonCompleted` yalnız BELLEK İÇİ bir kümeye ekliyor
      // — SharedPreferences'a bile yazmıyor. Kullanıcı "Ders tamamlandı"
      // görüp ekrandan çıkıyor, ama `loadCompletedLessonIds` sunucudan
      // okuduğu için ders "tamamlanmadı" görünmeye devam ediyordu; ne bir
      // kuyruğa alınıyordu (SyncManager yalnız quiz ödülünü kuyruklar) ne
      // de kullanıcıya bir hata gösteriliyordu — uygulama kapanınca işaret
      // de kayboluyordu (2026-08-14 denetimi).
      return false;
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
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME.
      //
      // Bu çağrılar eskiden hata yolunda `_offline`a düşüyordu ve mock
      // karşılıkları gövdesizdi — düpedüz `return true`. Sonuç: kullanıcı
      // "istek gönderildi" görüyor, istek hiçbir zaman gitmiyor ve hiçbir
      // yere de kuyruklanmıyordu. `SyncManager` yalnız quiz ödülünü
      // kuyruklar (`queueQuizReward`); depo ona hiç dokunmuyor.
      //
      // Okuma yollarındaki `_offline` geri düşüşü MEŞRUDUR ve korunuyor —
      // çevrimdışı soru/kategori göstermek değerlidir. Yalan olan, yerel
      // karşılığı OLMAYAN bir yazımı başarılı saymaktı.
      //
      // Arayüz zaten doğru yazılmış: `K.acceptFailed` / `K.rejectFailed`
      // metinleri vardı ama hiç görünmüyordu, çünkü depo hep true
      // dönüyordu (2026-08-02 denetimi).
      return false;
    }
  }

  @override
  Future<void> setFcmToken(String token) async {
    try {
      await client.rpc<void>('set_fcm_token', params: {'p_token': token});
    } catch (e, s) {
      _recordError(e, s, reason: 'setFcmToken failed');
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
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME.
      //
      // Bu çağrılar eskiden hata yolunda `_offline`a düşüyordu ve mock
      // karşılıkları gövdesizdi — düpedüz `return true`. Sonuç: kullanıcı
      // "istek gönderildi" görüyor, istek hiçbir zaman gitmiyor ve hiçbir
      // yere de kuyruklanmıyordu. `SyncManager` yalnız quiz ödülünü
      // kuyruklar (`queueQuizReward`); depo ona hiç dokunmuyor.
      //
      // Okuma yollarındaki `_offline` geri düşüşü MEŞRUDUR ve korunuyor —
      // çevrimdışı soru/kategori göstermek değerlidir. Yalan olan, yerel
      // karşılığı OLMAYAN bir yazımı başarılı saymaktı.
      //
      // Arayüz zaten doğru yazılmış: `K.acceptFailed` / `K.rejectFailed`
      // metinleri vardı ama hiç görünmüyordu, çünkü depo hep true
      // dönüyordu (2026-08-02 denetimi).
      return false;
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
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME.
      //
      // Bu çağrılar eskiden hata yolunda `_offline`a düşüyordu ve mock
      // karşılıkları gövdesizdi — düpedüz `return true`. Sonuç: kullanıcı
      // "istek gönderildi" görüyor, istek hiçbir zaman gitmiyor ve hiçbir
      // yere de kuyruklanmıyordu. `SyncManager` yalnız quiz ödülünü
      // kuyruklar (`queueQuizReward`); depo ona hiç dokunmuyor.
      //
      // Okuma yollarındaki `_offline` geri düşüşü MEŞRUDUR ve korunuyor —
      // çevrimdışı soru/kategori göstermek değerlidir. Yalan olan, yerel
      // karşılığı OLMAYAN bir yazımı başarılı saymaktı.
      //
      // Arayüz zaten doğru yazılmış: `K.acceptFailed` / `K.rejectFailed`
      // metinleri vardı ama hiç görünmüyordu, çünkü depo hep true
      // dönüyordu (2026-08-02 denetimi).
      return false;
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
      // BAŞARISIZLIĞI SIFIR SONUÇMUŞ GİBİ GÖSTERME.
      //
      // `_offline.searchPlayers` de boş liste döner (gerçek oyuncu havuzu
      // taklit edilemez), yani buraya düşmek `friends_screen.dart`ın
      // gözünde ağ hatasıyla "gerçekten kimse bulunamadı"yı ayırt
      // edilemez kılıyordu: ekran zaten `K.searchFailed` metnini catch
      // bloğunda taşıyordu ama bu metod hiç fırlatmadığı için o metin
      // hiçbir zaman görünemiyordu, kullanıcı her ağ hıçkırığında
      // "Oyuncu bulunamadı" görüyordu (2026-08-14 denetimi). rethrow,
      // ekranın kendi ayrımını yapmasına izin verir.
      rethrow;
    }
  }

  @override
  Future<List<Friend>> loadFriends() async {
    try {
      final res = await client.rpc<List<dynamic>>('list_friends');
      return res.map((row) {
        final friend = Friend.fromJson(Map<String, dynamic>.from(row as Map));
        // `list_friends` seviye döndürmez (yalnız `total_score` = xp);
        // Arkadaşlar sekmesi rozet olarak seviye gösteriyor
        // (leaderboard_screen.dart _FriendRankRow). Aynı XP→seviye
        // formülü sunucudaki liderlik view'ının kullandığı `xp` ile
        // tutarlı olsun diye burada, tek yerde hesaplanır.
        return friend.copyWith(
          level: XPStore.calculateLevel(friend.totalScore),
        );
      }).toList();
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
    // Ayarlar > Gizlilik'teki "Kullanım analizi" anahtarı yalnız Firebase
    // Analytics'i durduruyordu; bu ikinci ölçüm yolu anahtar kapalıyken
    // (varsayılan da kapalı) bile kullanıcı kimliğiyle Supabase'e yazmaya
    // devam ediyordu (2026-08-14 denetimi). Tek boğaz noktası.
    if (!AnalyticsConsentProvider.isEnabled) return false;
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
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME.
      //
      // Bu çağrılar eskiden hata yolunda `_offline`a düşüyordu ve mock
      // karşılıkları gövdesizdi — düpedüz `return true`. Sonuç: kullanıcı
      // "istek gönderildi" görüyor, istek hiçbir zaman gitmiyor ve hiçbir
      // yere de kuyruklanmıyordu. `SyncManager` yalnız quiz ödülünü
      // kuyruklar (`queueQuizReward`); depo ona hiç dokunmuyor.
      //
      // Okuma yollarındaki `_offline` geri düşüşü MEŞRUDUR ve korunuyor —
      // çevrimdışı soru/kategori göstermek değerlidir. Yalan olan, yerel
      // karşılığı OLMAYAN bir yazımı başarılı saymaktı.
      //
      // Arayüz zaten doğru yazılmış: `K.acceptFailed` / `K.rejectFailed`
      // metinleri vardı ama hiç görünmüyordu, çünkü depo hep true
      // dönüyordu (2026-08-02 denetimi).
      return false;
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

  /// Sunucuda böyle bir fonksiyon yok mu.
  ///
  /// İki kod da aynı durumu anlatır: `42883` PostgreSQL'in kendi hatası,
  /// `PGRST202` ise PostgREST şema önbelleğinde fonksiyonu bulamadığında
  /// döndürdüğü koddur. Uygulanmamış bir göçün ardından yayınlanan derleme
  /// pratikte ikincisini görür.
  bool _isMissingFunction(Object error) =>
      error is PostgrestException &&
      (error.code == '42883' || error.code == 'PGRST202');

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
      // Göç uygulanmamışsa (`_isMissingFunction`) benzetime düşmek meşru.
      // Başka her hatada sahte depoya düşmek "Bot Opponent"lı, durumu
      // 'completed' bir sahte maç uyduruyordu; ekran dönen değeri
      // kullanmayıp brakete güvendiği için kullanıcı hiçbir hata
      // görmüyordu — ama skoru sunucuya HİÇ YAZILMAMIŞTI, maç hâlâ açık
      // ve az önce oynanan tur boşa gitmişti. Sunucu skoru tek sefer
      // kabul ettiği için tekrar denemek güvenlidir (2026-08-14 denetimi).
      if (_isMissingFunction(e)) {
        return _offline.submitTournamentMatch(
          matchId: matchId,
          playerScore: playerScore,
          opponentScore: opponentScore,
        );
      }
      _recordError(e, s, reason: 'submitTournamentMatch failed');
      rethrow;
    }
  }

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async {
    // Bu metod `profiles.total_score` kolonunu sorguyordu — böyle bir kolon
    // YOK (`total_score` yalnız `leaderboard_entries` view'ında ve
    // `profiles.xp`den türetilir). PostgREST her çağrıda 42703 döndürüyor,
    // catch sahte depoya düşüyor ve ekran gerçek turnuvaya hiç katılmamış
    // sabit üç sahte oyuncu ("Şampyon 400" vb.) gösteriyordu. Sorgu doğru
    // kolona çevrilse bile bu YİNE yanlış olurdu: `profiles` genel puan
    // liderleridir, turnuva katılımcısı değil — turnuvaya girmemiş yüksek
    // puanlı biri "turnuva sıralaması" diye listelenirdi.
    //
    // Doğru kaynak zaten elde: `get_tournament_bracket` RPC'si (bkz.
    // `loadRealTournamentBracket`) turnuvadaki HER oyuncuyu, her maçın
    // skorunu ve kazananını taşıyor. Sıralama sunucuya yeni bir RPC
    // eklemeden bu veriden türetilir (2026-08-14 denetimi).
    final bracket = await loadRealTournamentBracket();
    if (bracket == null) return _offline.loadTournamentStandings(limit: limit);
    final standings = _standingsFromBracket(bracket);
    if (standings.isEmpty) {
      return _offline.loadTournamentStandings(limit: limit);
    }
    return standings.take(limit).toList();
  }

  /// Bracket'teki maçlardan sıralama türetir — `champion`/`finalist` yalnız
  /// bracket TEK maçlık bir tura ulaştıysa (yani final oynandıysa) verilir;
  /// erken turda kaybeden `eliminated`, henüz elenmemiş/final oynanmamış
  /// herkes `active` kalır.
  List<TournamentStandings> _standingsFromBracket(TournamentBracket bracket) {
    final names = <String, String>{};
    final scores = <String, int>{};
    final status = <String, String>{};

    int? finalRound;
    for (final round in bracket.rounds) {
      if (round.matches.length == 1) finalRound = round.roundNumber;
    }

    void touch(String id, String name) {
      if (id.isEmpty) return;
      names[id] = name;
      scores.putIfAbsent(id, () => 0);
      status.putIfAbsent(id, () => 'active');
    }

    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        touch(match.playerOneId, match.playerOneName);
        touch(match.playerTwoId, match.playerTwoName);
        if (match.playerOneId.isNotEmpty) {
          scores[match.playerOneId] =
              (scores[match.playerOneId] ?? 0) + match.playerOneScore;
        }
        if (match.playerTwoId.isNotEmpty) {
          scores[match.playerTwoId] =
              (scores[match.playerTwoId] ?? 0) + match.playerTwoScore;
        }
        if (match.status != 'completed' || match.winnerId.isEmpty) continue;
        final loserId = match.playerOneId == match.winnerId
            ? match.playerTwoId
            : match.playerOneId;
        final isFinal = finalRound != null && round.roundNumber == finalRound;
        if (isFinal) {
          status[match.winnerId] = 'champion';
          if (loserId.isNotEmpty) status[loserId] = 'finalist';
        } else if (loserId.isNotEmpty) {
          status[loserId] = 'eliminated';
        }
      }
    }

    const statusWeight = {
      'champion': 0,
      'finalist': 1,
      'active': 2,
      'eliminated': 3,
    };
    final ids = names.keys.toList()
      ..sort((a, b) {
        final byStatus = (statusWeight[status[a]] ?? 2).compareTo(
          statusWeight[status[b]] ?? 2,
        );
        if (byStatus != 0) return byStatus;
        return (scores[b] ?? 0).compareTo(scores[a] ?? 0);
      });

    return List.generate(
      ids.length,
      (i) => TournamentStandings(
        rank: i + 1,
        playerId: ids[i],
        playerName: names[ids[i]] ?? '—',
        totalScore: scores[ids[i]] ?? 0,
        status: status[ids[i]] ?? 'active',
      ),
    );
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
      // Göç uygulanmamışsa (`_isMissingFunction`) benzetime düşmek meşru.
      // Başka her hatada (ağ, sunucu, 500) sahte depoya düşmek koşulsuz
      // 500 coin uyduruyordu: kullanıcı gerçek turnuvayı kazanıyor, RPC
      // geçici bir hatayla düşüyor, ekran "+500 coin" gösteriyor ama
      // `coin_transactions`ta hiçbir satır yok — bakiyeye hiçbir şey
      // eklenmiyor. `tournament_screen.dart`ın bu durum için yazılmış
      // dürüst `unverified` ("ödül henüz doğrulanmadı") durumu, depo
      // istisnayı yutup pozitif sayı döndürdüğü için hiç devreye
      // giremiyordu (2026-08-14 denetimi).
      if (_isMissingFunction(e)) {
        return _offline.claimTournamentChampionReward();
      }
      _recordError(e, s, reason: 'claimTournamentChampionReward failed');
      rethrow;
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
      return false;
    }
  }
}
