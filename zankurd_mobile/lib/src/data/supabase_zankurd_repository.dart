import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'durable_write.dart';
import '../game/reveal_timing.dart';
import '../game/server_clock.dart';
import '../models/async_duel.dart';
import '../models/match_history.dart';
import '../models/my_suggestion.dart';
import '../models/avatar_identity.dart';
import '../models/contest.dart';
import '../models/add_friend_outcome.dart';
import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/public_profile.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../models/room_invite.dart';
import '../models/room_message.dart';
import '../models/tournament.dart';
import '../models/referral_result.dart';
import '../providers/analytics_consent_provider.dart';
import '../services/apple_revocation.dart';
import '../utils/client_round_id.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';
import '../config/category_visibility.dart';
import 'lesson_completion_store.dart';
import 'learning_lesson_aliases.dart';
import 'local_progress_scope.dart';
import 'mock_zankurd_repository.dart';
import 'xp_store.dart';
import 'zankurd_repository.dart';

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

/// Odanın gösterim adı. 2 kişilik oda eskiden olduğu gibi '1vs1'; kalabalık
/// odanın başlığı ekranda dile göre çizilir (`K.crowdRoomTitle`), burada
/// yalnız ayırt edici bir ad tutulur.
String _roomDisplayName(int maxPlayers, bool isCustom) =>
    isCustom && maxPlayers > 2 ? 'crowd' : '1vs1';

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

/// `get_my_favorite_questions` tek çağrıda en çok 200 kimlik alır; parça
/// boyutu bunun çok altında tutulur.
const _favoriteResolveChunk = 50;

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

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

/// Beklenen anahtarların hepsi VAR olmalı; fazlalıklar yok sayılır.
///
/// Sunucu cevaplarına zamanla alan eklenir (ör. kalabalık odanın `rank`,
/// `left`, `max_players`); eski bir istemcinin "bilmediğim alan var" diye
/// sonucu reddetmesi, oyuncuyu bitmiş maçın sonucundan yoksun bırakırdı.
void _requireKeys(
  Map<String, dynamic> json,
  Set<String> required,
  String field,
) {
  if (!json.keys.toSet().containsAll(required)) {
    throw FormatException('$field is missing required fields.');
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

/// Öneri INSERT politikasının istediği katkı lisansı sürümü (canlı:
/// `suggested_questions_insert_own`).
const String suggestedQuestionLicenseVersion = '2026-08-11';

class SupabaseZanKurdRepository implements ZanKurdRepository {
  SupabaseZanKurdRepository(this.client);

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
  List<QuizLevel> levelsForCategory(String category, {String? subCategory}) =>
      _offline.levelsForCategory(category, subCategory: subCategory);

  @override
  GameRoom joinRoom(String code) => _offline.joinRoom(code);

  final SupabaseClient client;
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Oda başına tek realtime kanalı; gönderme ve dinleme paylaşır.
  /// Dinleyici referans sayısı tutulur; tek abonelik iptalinde ortak kanal
  /// kapatılmaz.
  ///
  /// Kanal bilerek herkese açık (private değil; 2026-10-26 kararı): üstünden
  /// yalnız hazır bayrağı, skor/seri ipucu, ilerleme isteği ve hazır tepkiler
  /// geçer. Puan sunucuda hesaplanır, kanaldan gelen hiçbir şey sonuç
  /// yazmaz; kanala ulaşmak da odanın tahmin edilemez uuid'ini bilmeyi
  /// gerektirir. Private kanala geçmek eski derlemelerle (37/38) karışık
  /// oyunu kırar; ancak iki cihazlı sürüm-karışık test ve RLS politikasıyla
  /// birlikte yapılmalı.
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
    _profileCache.remove(user.id);
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
  ///
  /// Kullanıcıya göre ayrılır: sabit anahtarla, A'nın bekleyen değişikliği
  /// aynı cihazdaki B'nin profiline yazılabiliyordu.
  static String get _avatarIdentityDirtyKey =>
      LocalProgressScope.physical('zankurd.avatarIdentity.dirtyPending');

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
      _profileCache.remove(user.id);
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
  Future<bool> updateAvatarIdentityConfirmed(AvatarIdentity identity) async {
    await _offline.updateAvatarIdentity(identity);
    if (client.auth.currentUser == null) return false;
    return _pushAvatarIdentity(identity);
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
      throw StateError('Remote service unavailable.');
    }
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    // Her yükleme KENDİ yoluna gider (`avatar-<ms>.ext`). Eskiden hep
    // `avatar.ext` üstüne yazılıyordu: kullanıcı fotoğrafı değiştirip
    // vazgeçince temizlik, profilin hâlâ işaret ettiği kayıtlı fotoğrafı da
    // siliyordu. Sunucu regex'i bu eki `2026-10-17_profil_veri.sql` ile kabul eder.
    final path =
        '${user.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          // upsert: false — yol zaten her yüklemede benzersiz. Storage
          // upsert'te `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` yapar
          // ve RLS SELECT politikası da ister; 2026-08-01 sertleştirmesi
          // (security_advisor_hardening) avatars için SELECT politikasını
          // kaldırdığından o günden beri her fotoğraf yüklemesi 403 ile
          // düşüyordu (canlıda ağustostan sonra tek nesne yok). INSERT
          // politikası tek başına yeter.
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Genel avatar URL'sinden kovadaki nesne yolunu çıkarır; yalnız çağıranın
  /// kendi klasöründeki nesneler döner (başkasının yolu silinmeye çalışılmaz).
  @visibleForTesting
  static String? avatarObjectPath(String url, String userId) {
    const marker = '/avatars/';
    final at = url.indexOf(marker);
    if (at < 0) return null;
    var path = url.substring(at + marker.length);
    final q = path.indexOf('?');
    if (q >= 0) path = path.substring(0, q);
    if (!path.startsWith('$userId/') || path.contains('..')) return null;
    return path;
  }

  @override
  Future<void> deleteAvatarPhoto({List<String> urls = const []}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Remote service unavailable.');
    }
    // Uzantı içerik türünden seçiliyor (`uploadAvatarPhoto`), yani aynı
    // kullanıcının geçmişte hem .png hem .jpg nesnesi olabilir. İkisini de
    // kaldırmak gerekir; `remove` var olmayan yolu sorun etmez. Zaman
    // damgalı yollar listelenemediği için çağıran URL'lerini verir.
    final paths = <String>{
      '${user.id}/avatar.jpg',
      '${user.id}/avatar.png',
      for (final url in urls) ?avatarObjectPath(url, user.id),
    };
    await client.storage.from('avatars').remove(paths.toList());
  }

  @override
  Future<void> deleteAvatarPhotoObjects(List<String> urls) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Remote service unavailable.');
    }
    final paths = <String>{
      for (final url in urls) ?avatarObjectPath(url, user.id),
    };
    if (paths.isEmpty) return;
    await client.storage.from('avatars').remove(paths.toList());
  }

  /// Oturumdaki hesabın Apple kimliği var mı (testlerde geçersiz kılınır).
  @visibleForTesting
  bool get hasAppleIdentity => userHasAppleIdentity(client.auth.currentUser);

  @override
  Future<void> deleteMyAccount() async {
    try {
      // Apple ile girilmiş hesapta ÖNCE Apple bağlantısı iptal edilir
      // (Kılavuz 5.1.1(v)); hesap silindikten sonra kullanıcının JWT'si
      // geçersiz olur ve iptal edilemez. İptal başarısız olursa silme
      // YİNE DE sürer (`revokeAppleAuthorization` hiç fırlatmaz).
      if (hasAppleIdentity) {
        await revokeAppleAuthorization(client);
      }
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

  /// Sabitlenen "benim sıram" satırının dönem (Gün/Hafta/Ay) karşılığı.
  ///
  /// `get_my_leaderboard_rank` yalnız `auth.uid()` satırını, `get_leaderboard`
  /// ile BİREBİR aynı süzgeçten döndürür (biten çevrimiçi odalar, dönem
  /// puanı > 0) — yani satırda gördüğün sayı, listedeki sayıdır.
  ///
  /// Hata ya da eksik RPC `null` döner: eski `leaderboard_entries`
  /// görünümüne (toplam XP) DÜŞÜLMEZ, satır hiç çizilmez. Dönem puanı
  /// doğrulanamıyorsa yanlış iddia sessizce tercih edilir (2026-09-30).
  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    try {
      if (currentUserId == null) return null;

      final rows = await client.rpc<List<dynamic>>(
        'get_my_leaderboard_rank',
        params: {'p_days': period.days},
      );
      if (rows.isEmpty) return null;

      final row = rows.first as Map<String, dynamic>;
      final rank = (row['rank'] as num?)?.toInt() ?? 0;
      final totalScore = (row['total_score'] as num?)?.toInt() ?? 0;
      if (rank <= 0 || totalScore <= 0) return null;

      final tags = await _publicProfilesById([row['player_id'] as String?]);
      return LeaderboardEntry(
        playerTag: tags[row['player_id'] as String?]?.playerTag,
        rank: rank,
        playerId: row['player_id'] as String? ?? '',
        displayName: row['display_name'] as String? ?? 'Oyuncu',
        totalScore: totalScore,
        bestStreak: (row['best_streak'] as num?)?.toInt() ?? 0,
        roomsPlayed: (row['rooms_played'] as num?)?.toInt() ?? 0,
        avatarIcon: row['avatar_icon'] as String?,
        avatarColor: row['avatar_color'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        avatarFrame: row['avatar_frame'] as String?,
        showcaseTitle: row['showcase_title'] as String?,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'getMyLeaderboardRank failed');
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
    int? levelNumber,
    int limit = 10,
  }) async {
    return _offline.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      subCategory: subCategory,
      levelNumber: levelNumber,
      limit: limit,
    );
  }

  @override
  Future<List<QuizQuestion>> loadLearningQuizQuestions({
    required String category,
    required String learningLessonId,
    int limit = 5,
  }) async {
    return _offline.loadLearningQuizQuestions(
      category: category,
      learningLessonId: learningLessonId,
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
      // Oda soruları SUNUCUNUN sırasıyla birebir kalır; istemci soru ATMAZ.
      //
      // Oda akışı sunucunun `current_question_index`iyle ilerler, ekran
      // `_questions[index]`i gösterir, cevap `p_question_id` ile gider.
      // İstemci bir soruyu atarsa sonraki bütün sorular bir kayar: oyuncu
      // ekranda bir soruyu görür, sunucu başkasını bekler. Hepsi atılırsa
      // (ör. "Rastgele" eşleşme gizli bir kategoriye düştüyse) oyun hiç
      // başlamaz. Gizli kategori (`category_visibility.dart`) listeleme ve
      // seçim kararıdır; sunucu bir soruyu odaya koyduysa o soru oynanır.
      // Seçim süzgecinin yeri sunucudur.
      final roomQuestions = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromServerRow)
          .toList();

      if (roomQuestions.isNotEmpty) return roomQuestions;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadRoomQuestions failed');
    }

    throw StateError('Online room questions are unavailable.');
  }

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({
    int limit = 10,
    bool replay = false,
  }) async {
    return _offline.loadDailyQuestions(limit: limit, replay: replay);
  }

  @override
  Future<List<QuizQuestion>> loadDailyEventQuestions({int limit = 10}) async {
    return _offline.loadDailyEventQuestions(limit: limit);
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
    int maxPlayers = 2,
  }) async {
    try {
      if (client.auth.currentUser == null) {
        await signInAnonymously();
      }
      await ensureProfile();

      // `category` seçimi tek dizgede taşır: `Tevlihev` = Karışık (hepsi),
      // `A, B` = çoklu, `A` = tek kategori. Hepsi `create_online_room_v2`ye
      // gider (yalnız o 6 rakamlı kod üretir; boş dizi = Karışık). Eski
      // 5 parametreli RPC mağazadaki sürümler içindir.
      final isMixed = category == 'Tevlihev';
      final picked = category
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(growable: false);
      final response = await client.rpc(
        'create_online_room_v2',
        params: {
          'p_category_names': isMixed ? const <String>[] : picked,
          'p_seconds_per_question': secondsPerQuestion,
          'p_question_count': questionCount,
          'p_entry_fee': entryFee,
          // Kapasite 2 iken istek eskisiyle birebir aynı gider (sunucuda
          // 5. parametrenin varsayılanı 2); yalnız kalabalık oda gönderir.
          if (maxPlayers != 2) 'p_max_players': maxPlayers,
        },
      );
      final snapshot = _requiredJsonObject(response, 'create_online_room_v2');
      return _roomFromCreateSnapshot(
        snapshot,
        fallbackEntryFee: entryFee,
        fallbackMaxPlayers: maxPlayers,
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'createOnlineRoom failed');
      rethrow;
    }
  }

  /// `create_online_room_v2` ve `create_room_rematch` AYNI biçimde JSON döner
  /// (room_id, code, host_id, category_name, ...); ikisi de bu tek yoldan
  /// [GameRoom]a çevrilir ki alan eşlemesi iki yerde ayrışmasın.
  Future<GameRoom> _roomFromCreateSnapshot(
    Map<String, dynamic> snapshot, {
    int fallbackEntryFee = 0,
    int fallbackMaxPlayers = 2,
  }) async {
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
        : fallbackEntryFee;
    // Eski sunucu bu iki alanı hiç döndürmez: tolere edilir, 2 kişilik.
    final serverMaxPlayers =
        (snapshot['max_players'] as num?)?.toInt() ?? fallbackMaxPlayers;
    final serverIsCustom = snapshot['is_custom'] as bool? ?? true;

    final players = await _loadRoomPlayersById(roomId);
    return GameRoom(
      id: roomId,
      name: _roomDisplayName(serverMaxPlayers, serverIsCustom),
      code: roomCode,
      category: canonicalCategory,
      players: players,
      status: _roomStatusFromValue(snapshot['status'] ?? 'lobby'),
      questionCount: serverQuestionCount,
      secondsPerQuestion: serverSeconds,
      entryFee: serverEntryFee,
      hostId: hostId,
      maxPlayers: serverMaxPlayers,
      isCustom: serverIsCustom,
    );
  }

  @override
  Future<GameRoom> createRoomRematch(String roomId) async {
    client.auth.currentUser ?? await signInAnonymously();
    final dynamic response;
    try {
      response = await client.rpc(
        'create_room_rematch',
        params: {'p_room_id': roomId},
      );
    } on PostgrestException catch (error, stack) {
      // Sunucu düz metinle reddeder; sebep çevrilir (UI genel "oda
      // açılamadı" der, ama istisna türü çağırana ayrım yaptırır).
      _recordError(error, stack, reason: 'createRoomRematch rejected');
      throw RoomRematchException(
        roomRematchFailureReasonForMessage(error.message),
        error.message,
      );
    }
    final rawSnapshot = response is List ? response.firstOrNull : response;
    final snapshot = _requiredJsonObject(rawSnapshot, 'create_room_rematch');
    return _roomFromCreateSnapshot(snapshot);
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
        // v2: yanlış kod denemesini kalıcı sayar (6 haneli kod kaba kuvvet
        // sınırı) ve bulunamadığında istisna yerine JSON `error` döndürür.
        'join_room_by_code_v2',
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
      throw StateError(
        'join_room_by_code_v2 boş yanıt döndürdü: oda bulunamadı',
      );
    }
    final room = _requiredJsonObject(rawSnapshot, 'join_room_by_code_v2');
    final softError = room['error'];
    if (softError is String) {
      _recordError(
        StateError('joinOnlineRoom soft error: $softError'),
        StackTrace.current,
        reason: 'joinOnlineRoom rejected',
      );
      throw RoomJoinException(
        roomJoinFailureReasonForMessage(softError),
        softError,
      );
    }
    final roomId = _requiredString(room, const ['room_id']);
    final hostId = _requiredString(room, const ['host_id']);
    final players = await _loadRoomPlayersById(roomId);
    // Kategorisiz oda (sunucuda category_id boş) KARIŞIKTIR. Eskiden 'Ziman'a
    // düşülüyordu: karışık oda uygulama yeniden açılınca ya da katılan
    // oyuncuda "Dil" görünüyordu (2026-10-27, 4 cihazlı E2E).
    final category = room['category_name'] as String? ?? 'Tevlihev';

    final joined = createRoom(category: category).copyWith(
      id: roomId,
      // `createRoom()` yerel/solo oda için 'Hevalên Zanînê' adını taşır;
      // burada üzerine yazılmazsa katılan oyuncu aynı odayı ev sahibinin
      // gördüğü '1vs1' yerine bu adla görüyordu — aynı oda iki farklı
      // başlıkla açılıyordu. `createOnlineRoom`/`loadRoomSnapshot`
      // (ev sahibi ve sonraki yeniden-yüklemeler) zaten '1vs1' kullanıyor
      // (2026-08-14 denetimi).
      name: _roomDisplayName(
        (room['max_players'] as num?)?.toInt() ?? 2,
        room['is_custom'] as bool? ?? false,
      ),
      code: room['code'] as String,
      questionCount: room['question_count'] as int? ?? 10,
      players: players,
      hostId: hostId,
      secondsPerQuestion:
          (room['seconds_per_question'] as int?) ??
          GameRoom.defaultSecondsPerQuestion,
      entryFee: (room['entry_fee'] as num?)?.toInt() ?? 0,
      // Eski sunucu bu alanları döndürmez: 2 kişilik, eşleşme dışı sayılır.
      maxPlayers: (room['max_players'] as num?)?.toInt() ?? 2,
      isCustom: room['is_custom'] as bool? ?? false,
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
          'max_players, is_custom, categories(name)',
        )
        .eq('id', roomId)
        .single();
    final players = await _loadRoomPlayersById(roomId);
    final category = row['categories'] as Map<String, dynamic>?;
    final rowMaxPlayers = (row['max_players'] as num?)?.toInt() ?? 2;
    final rowIsCustom = row['is_custom'] as bool? ?? false;

    return GameRoom(
      id: row['id'] as String? ?? roomId,
      name: _roomDisplayName(rowMaxPlayers, rowIsCustom),
      code: row['code'] as String? ?? '',
      // Kategorisiz oda karışıktır (bkz. joinOnlineRoom).
      category: category?['name'] as String? ?? 'Tevlihev',
      players: players,
      status: _roomStatusFromValue(row['status']),
      questionCount: (row['question_count'] as num?)?.toInt() ?? 10,
      secondsPerQuestion:
          (row['seconds_per_question'] as num?)?.toInt() ??
          GameRoom.defaultSecondsPerQuestion,
      entryFee: (row['entry_fee'] as num?)?.toInt() ?? 0,
      hostId: row['host_id'] as String?,
      maxPlayers: rowMaxPlayers,
      isCustom: rowIsCustom,
    );
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    final requestWatch = Stopwatch()..start();
    final response = await client.rpc('get_my_resumable_room');
    requestWatch.stop();
    if (response == null) return null;

    final json = _requiredJsonObject(response, 'get_my_resumable_room');
    final serverNow = _requiredDateTime(json, 'server_now');
    final serverClock = ServerClock(
      serverNow: serverNow,
      roundTrip: requestWatch.elapsed,
    );
    final revealEndsAt = _optionalDateTimeFromKeys(json, const [
      'current_question_reveal_ends_at',
    ]);
    // Saati profil/oda yüklemesinden ÖNCE yakala. RTT/2 yalnız aktarım
    // tahminidir; erken ilerletme isteğini sunucunun CAS kapısı reddeder.
    final revealClock = revealEndsAt == null
        ? null
        : ServerRevealClock.fromServerClock(
            clock: serverClock,
            endsAt: revealEndsAt,
          );
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
      serverNow: serverNow,
      serverClock: serverClock,
      revealClock: revealClock,
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
    return _withResultProfiles(
      _parseRoomResultResponse(response, source: 'get_my_pending_room_result'),
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
    return _withResultProfiles(
      _parseRoomResultResponse(
        response,
        source: 'get_my_room_result',
        expectedRoomId: roomId,
      ),
    );
  }

  /// Sonuç yükü yalnız ad döndürür (boşsa 'Hevrik'); fotoğraf, simge ve
  /// oyuncu kodu herkese açık profilden tamamlanır. Profil okunamazsa
  /// sunucunun yüküyle devam edilir — sonuç ekranı bu yüzden bekletilmez.
  Future<RoomResultSnapshot?> _withResultProfiles(
    RoomResultSnapshot? snapshot,
  ) async {
    if (snapshot == null) return null;
    final profiles = await _publicProfilesById([
      for (final p in snapshot.room.players) p.id,
    ]);
    if (profiles.isEmpty) return snapshot;
    return RoomResultSnapshot(
      room: snapshot.room.copyWith(
        players: [
          for (final p in snapshot.room.players) p.withProfile(profiles[p.id]),
        ],
      ),
      ownPlayerId: snapshot.ownPlayerId,
      questionIds: snapshot.questionIds,
      answers: snapshot.answers,
      winnerId: snapshot.winnerId,
      endedReason: snapshot.endedReason,
      forfeitedBy: snapshot.forfeitedBy,
      finishedAt: snapshot.finishedAt,
    );
  }

  RoomResultSnapshot? _parseRoomResultResponse(
    Object? response, {
    required String source,
    String? expectedRoomId,
  }) {
    if (response == null) return null;

    final json = _requiredJsonObject(response, source);
    _requireKeys(json, const {
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
    _requireKeys(roomJson, const {
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
    // Eski sunucu bu ikisini göndermez: 2 kişilik, eşleşme/1v1 sayılır.
    final maxPlayers = (roomJson['max_players'] as num?)?.toInt() ?? 2;
    final isCustom = roomJson['is_custom'] as bool? ?? false;
    final crowd = isCustom && maxPlayers > 2;
    // Kalabalık odada kalan aktif sayısı 2'nin altına düşünce oda erken
    // biter: soru dizini sondan önce kalır ve oyuncunun cevapları eksik
    // olabilir. 1v1/2 kişilik odada bitiş her zaman tam olmalıdır.
    final terminalIndexOk = crowd
        ? currentQuestionIndex >= 0 && currentQuestionIndex <= questionCount
        : currentQuestionIndex == questionCount;
    if (statusValue != 'finished' ||
        questionCount < 1 ||
        !terminalIndexOk ||
        !GameRoom.allowedSecondsPerQuestion.contains(secondsPerQuestion)) {
      throw const FormatException('Room result is not terminal and complete.');
    }

    final ownPlayerId = _requiredString(json, const ['own_player_id']);
    final rawPlayers = json['players'];
    if (rawPlayers is! List ||
        (crowd
            ? rawPlayers.length < 2 || rawPlayers.length > maxPlayers
            : rawPlayers.length != 2)) {
      throw FormatException(
        crowd
            ? 'players must contain 2..$maxPlayers players.'
            : 'players must contain exactly two players.',
      );
    }
    final players = rawPlayers
        .map((rawPlayer) {
          final player = _requiredJsonObject(rawPlayer, 'players[]');
          _requireKeys(player, const {
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
          int? rank;
          var left = false;
          if (crowd) {
            left = _requiredBool(player, 'left');
            final rawRank = player['rank'];
            rank = rawRank == null
                ? null
                : _requiredInt(player, const ['rank']);
            // Ayrılan sıralamaya girmez; aktif oyuncunun sırası 1'den başlar.
            if (left ? rank != null : (rank == null || rank < 1)) {
              throw const FormatException('Player rank and left disagree.');
            }
          }
          return Player(
            id: _requiredString(player, const ['player_id']),
            name: _requiredString(player, const ['display_name']),
            score: score,
            state: Player.readyState,
            streak: streak,
            rank: rank,
            left: left,
          );
        })
        .toList(growable: false);
    final playerIds = players.map((player) => player.id!).toSet();
    if (playerIds.length != players.length ||
        !playerIds.contains(ownPlayerId)) {
      throw const FormatException(
        'Result players are not distinct members including the owner.',
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
    if (rawAnswers is! List ||
        (crowd
            ? rawAnswers.length > questionCount
            : rawAnswers.length != questionCount)) {
      throw const FormatException('answers must contain every own answer.');
    }
    final answers = <ResumedAnswer>[];
    for (var index = 0; index < rawAnswers.length; index++) {
      final answer = _requiredJsonObject(rawAnswers[index], 'answers[]');
      _requireKeys(answer, const {
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
    // Seri sunucuda yalnız AÇIKLANMIŞ sorulardan sayılır; erken biten
    // kalabalık odada son cevap açıklanmamış kalabilir. Skor ise sunucuda
    // cevap puanlarının toplamıyla eşitlenmiş olmak zorundadır.
    if (ownPlayer.score != ownScore ||
        (!crowd && ownPlayer.streak != ownStreak)) {
      throw const FormatException('Own final score does not match answers.');
    }

    final endedReason = _requiredString(json, const ['ended_reason']);
    final forfeitedBy = _requiredNullableString(json, 'forfeited_by');
    if (endedReason != 'completed' || forfeitedBy != null) {
      throw const FormatException('Room result is not a normal completion.');
    }
    final winnerId = _requiredNullableString(json, 'winner_id');
    // Kalabalıkta kazanan, AKTİF oyuncular içinde tek başına en yüksek
    // skorlu kişidir (ayrılanlar hesaba girmez); tepede eşitlik varsa null.
    final contenders = crowd
        ? players.where((player) => !player.left).toList()
        : [...players];
    contenders.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0 ? scoreOrder : a.id!.compareTo(b.id!);
    });
    final expectedWinner =
        contenders.isEmpty ||
            (contenders.length > 1 &&
                contenders[0].score == contenders[1].score)
        ? null
        : contenders.first.id;
    if (winnerId != expectedWinner) {
      throw const FormatException('winner_id does not match final scores.');
    }

    final room = GameRoom(
      id: roomId,
      name: _roomDisplayName(maxPlayers, isCustom),
      code: _requiredString(roomJson, const ['code']),
      category: _requiredString(roomJson, const ['category_name']),
      players: List.unmodifiable(players),
      status: RoomStatus.finished,
      questionCount: questionCount,
      secondsPerQuestion: secondsPerQuestion,
      hostId: hostId,
      maxPlayers: maxPlayers,
      isCustom: isCustom,
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

    final response = await client.rpc(
      'mark_room_client_ready',
      params: {'p_room_id': roomId},
    );
    // Kalabalık odada hazır süresi dolunca hazır olmayan oyuncu oyundan
    // düşer ve `status: 'left'` alır. Sürdürülebilir oda artık onu
    // döndürmeyeceğinden bunu ayrıca bildirmezsek istemci sonsuza dek
    // "hazırlanıyor" ekranında beklerdi.
    if (response is Map && response['status'] == 'left') {
      throw const RoomMemberLeftException();
    }
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
    // Kalabalık lobide host çıkınca cevap `new_host_id` da taşır; üç temel
    // alan zorunlu, fazlalık yok sayılır.
    _requireKeys(json, const {
      'status',
      'reason',
      'forfeited_by',
    }, 'leave_room');
    return RoomLeaveOutcome(
      status: _requiredString(json, const ['status']),
      reason: _requiredString(json, const ['reason']),
      forfeitedBy: _requiredNullableString(json, 'forfeited_by'),
      newHostId: _optionalString(json, 'new_host_id'),
    );
  }

  bool _answerProgressSupported = true;

  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async {
    final roomId = room.id;
    // Göç uygulanmamış sunucuda RPC yok: oturum boyunca bir daha sorma,
    // başlık "Diğer oyuncular bekleniyor" metninde kalır.
    if (roomId == null || !_answerProgressSupported) return null;
    try {
      final response = await client.rpc(
        'get_room_answer_progress',
        params: {'p_room_id': roomId},
      );
      return RoomAnswerProgress.tryParse(response);
    } catch (error, stack) {
      if (isMissingRpcError(error)) {
        _answerProgressSupported = false;
        return null;
      }
      _recordError(error, stack, reason: 'loadRoomAnswerProgress failed');
      rethrow;
    }
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
        // Akış `order`ının varsayılanı AZALAN (`ascending: false`); sohbet
        // listesi eski üstte/yeni altta bekler (2026-10-21 ters sohbet).
        .order('created_at', ascending: true)
        .asyncMap(
          (rows) => _withSenderProfiles([
            for (final row in rows)
              RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)),
          ]),
        );
  }

  /// Sohbet satırı yalnız gönderim anındaki adı/rengi taşır; fotoğraf ve
  /// güncel ad herkese açık profilden gelir. Aynı oyuncu için yeniden
  /// sorulmaz (oda ömrü boyunca önbellek).
  final Map<String, PublicProfile> _chatProfiles = {};

  Future<List<RoomMessage>> _withSenderProfiles(
    List<RoomMessage> messages,
  ) async {
    final missing = {
      for (final m in messages)
        if (!_chatProfiles.containsKey(m.senderId)) m.senderId,
    };
    if (missing.isNotEmpty) {
      _chatProfiles.addAll(await _publicProfilesById(missing));
    }
    return [for (final m in messages) m.withProfile(_chatProfiles[m.senderId])];
  }

  @override
  Future<List<RoomMessage>> loadRoomMessages(String roomId) async {
    try {
      final rows = await client
          .from('room_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('created_at');
      return _withSenderProfiles([
        for (final row in rows)
          RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)),
      ]);
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
  Future<bool> kickRoomPlayer({
    required String roomId,
    required String playerId,
  }) async {
    try {
      await client.rpc(
        'kick_room_player',
        params: {'p_room_id': roomId, 'p_player_id': playerId},
      );
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'kickRoomPlayer failed');
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
      final profiles = await _fetchPublicProfiles(ids.toList());
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
        .asyncMap((rawRows) async {
          // Kurul C12 (Sol + Opus turu, 2026-10-29): gerçek zamanlı akış
          // satırları belirli bir sırayla vermez; aynı lobi cihazdan cihaza
          // farklı sırada çiziliyordu. İlk yükleme gibi katılma zamanına
          // (eşitlikte oyuncu kimliğine) göre sıralanır.
          final rows = [...rawRows]..sort(compareRoomPlayerRows);
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
              final profiles = await _fetchPublicProfiles(missingProfileIds);
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
                tag: cachedProfile?['player_tag'] as String?,
                left: row['left_at'] != null,
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

  /// Sunucu `question_reports.reason` için 500 karakter üst sınırı koyar
  /// (2026-10-02_report_hardening.sql); sınırı aşan serbest metin reddedilmek
  /// yerine burada kırpılır.
  static String _clampReportReason(String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return 'Kontrol edilmeli';
    return trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;
  }

  @override
  Future<void> rateQuestion(QuizQuestion question, int rating) async {
    if (rating != 1 && rating != -1) {
      throw ArgumentError.value(rating, 'rating', 'must be -1 or 1');
    }
    // Hata yutulmaz: arayüz seçimi geri alır ve kullanıcıya söyler.
    try {
      await client.rpc(
        'rate_question',
        params: {'p_question_id': question.id, 'p_rating': rating},
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'rateQuestion rpc failed');
      rethrow;
    }
  }

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    await ensureProfile();
    try {
      await client.from('question_reports').insert({
        'question_id': question.id,
        'reporter_id': user.id,
        'reason': _clampReportReason(reason),
      });
    } on PostgrestException catch (error, stack) {
      // (reporter_id, question_id) tekil: aynı soruyu ikinci kez bildirmek
      // zaten kayıtlı demektir. Hata göstermek kullanıcıya "bildirim
      // başarısız" dedirtiyordu; sayaç RPC'si de ikinci kez çağrılmaz.
      if (error.code == '23505') return;
      _recordError(error, stack, reason: 'reportQuestion insert failed');
      rethrow;
    }

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
      // Paketli bankada bulunmayan kimlikler çevrimiçi oda maçında
      // kaydedilmiş gerçek `questions.id` uuid'leridir.
      //
      // Eskiden `quiz_public_questions` görünümünden okunuyordu; görünüm
      // `security_invoker` idi ve altındaki `questions` tablosunda istemciye
      // SELECT verilmediği için her çağrı "permission denied" ile düşüyor,
      // hata yutulup bu favoriler hiç görünmüyordu. Görünüm 2026-10-15
      // göçüyle silindi; çözüm artık `get_my_favorite_questions` RPC'sidir
      // (`2026-10-16_son_bosluklar.sql`): yalnız çağıranın favorilerindeki
      // onaylı soruların gösterim verisini döndürür, doğru şıkkı ASLA.
      // Çözülen soru `hasHiddenAnswer` taşır; yeniden oynatma onları dışarıda
      // bırakır (favorite_questions_screen.dart).
      final unresolvedIds = <String>{
        for (final id in orderedIds)
          if (!byId.containsKey(id) && _uuidPattern.hasMatch(id)) id,
      }.toList();
      if (unresolvedIds.isNotEmpty) {
        byId.addAll(await _resolveServerFavoriteQuestions(unresolvedIds));
      }

      final questions = orderedIds
          .map((id) => byId[id])
          .whereType<QuizQuestion>()
          .toList();
      if (questions.isNotEmpty) return questions;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadFavoriteQuestions failed');
      if (isLikelyOfflineError(error)) rethrow;
      return const [];
    }
    return const [];
  }

  /// Paketli bankada olmayan favori kimliklerini sunucudan çözer.
  ///
  /// RPC çağrısı başına en çok 200 kimlik kabul eder; 50'lik parçalar hem
  /// bunun altında kalır hem de tek isteği küçük tutar. Göç henüz uygulanmamışsa
  /// (`PGRST202`) sessizce atlanır: o favoriler eskiden de görünmüyordu.
  /// Taşıma hatası ise YUKARI çıkar: ekran yarım liste ya da yalan bir boş
  /// durum yerine hata + yeniden dene gösterir. Başka sunucu hataları
  /// kaydedilir, çözülemeyen favoriler atlanır.
  Future<Map<String, QuizQuestion>> _resolveServerFavoriteQuestions(
    List<String> ids,
  ) async {
    final resolved = <String, QuizQuestion>{};
    for (var start = 0; start < ids.length; start += _favoriteResolveChunk) {
      final chunk = ids.sublist(
        start,
        min(start + _favoriteResolveChunk, ids.length),
      );
      try {
        final response = await client.rpc(
          'get_my_favorite_questions',
          params: {'p_ids': chunk},
        );
        if (response is! List) continue;
        for (final row in response.whereType<Map>()) {
          final question = QuizQuestion.fromServerRow(
            Map<String, dynamic>.from(row),
          );
          resolved[question.id] = question;
        }
      } catch (error, stack) {
        if (error is PostgrestException && error.code == 'PGRST202') {
          // Göç henüz uygulanmadı: kalan parçalar da aynı yanıtı verir.
          return resolved;
        }
        _recordError(
          error,
          stack,
          reason: 'loadFavoriteQuestions server resolve failed',
        );
        if (isLikelyOfflineError(error)) rethrow;
      }
    }
    return resolved;
  }

  @override
  Future<int> loadCoinBalance() async {
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      try {
        final response = await client.rpc('get_my_coin_balance');
        if (response is num) return response.toInt();
      } catch (error, stack) {
        // Göç (2026-10-15_jeton_bakiyesi.sql) henüz uygulanmamış olabilir.
        if (!_isMissingFunction(error)) {
          _recordError(error, stack, reason: 'get_my_coin_balance failed');
          Error.throwWithStackTrace(error, stack);
        }
      }
      // Yedek yol: PostgREST 1000 satırda keser, çok işlemli hesapta eksik
      // toplar.
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
  Future<StreakRepairResult> spendStreakRepair({
    required String monthKey,
    required String breakDay,
    required bool premium,
  }) async {
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'spend_streak_repair',
        params: {
          'p_month': monthKey,
          'p_break_day': breakDay,
          // Sunucu p_premium'u yok sayar (2.2'ye kadar); imza için gönderilir.
          'p_premium': false,
        },
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          if (response['already_repaired'] == true) {
            return const StreakRepairResult(
              StreakRepairOutcome.alreadyRepaired,
            );
          }
          return StreakRepairResult(
            response['paid'] == true
                ? StreakRepairOutcome.charged
                : StreakRepairOutcome.free,
          );
        }
        return StreakRepairResult(switch (response['error']) {
          'insufficient balance' => StreakRepairOutcome.insufficient,
          'monthly_limit' => StreakRepairOutcome.monthlyLimit,
          _ => StreakRepairOutcome.failed,
        });
      }
      return const StreakRepairResult(StreakRepairOutcome.failed);
    } catch (error, stack) {
      // Göç uygulanmamışsa onarım sunulmaz: idempotent olmayan yedek yol
      // YOK (çift çekim riski). Çağıran "şu an kullanılamıyor" gösterir.
      if (!_isMissingFunction(error)) {
        _recordError(error, stack, reason: 'spendStreakRepair failed');
      }
      return const StreakRepairResult(StreakRepairOutcome.failed);
    }
  }

  @override
  Future<AccountFlags?> loadAccountFlags() async {
    try {
      if (client.auth.currentUser == null) return null;
      final response = await client.rpc('get_my_account_flags');
      if (response is Map<String, dynamic> && response['success'] == true) {
        return AccountFlags(
          pushDuel: response['push_duel'] != false,
          pushSocial: response['push_social'] != false,
          emailVerifiedAt: DateTime.tryParse(
            (response['email_verified_at'] as String?) ?? '',
          ),
          emailVerifiedAddress: response['email_verified_address'] as String?,
        );
      }
      return null;
    } catch (error, stack) {
      if (!_isMissingFunction(error) && !isLikelyOfflineError(error)) {
        _recordError(error, stack, reason: 'loadAccountFlags failed');
      }
      return null;
    }
  }

  @override
  Future<bool> setPushPreferences({bool? duel, bool? social}) async {
    try {
      if (client.auth.currentUser == null) return false;
      final response = await client.rpc(
        'set_my_push_prefs',
        params: {'p_duel': duel, 'p_social': social},
      );
      return response is Map<String, dynamic> && response['success'] == true;
    } catch (error, stack) {
      if (!_isMissingFunction(error) && !isLikelyOfflineError(error)) {
        _recordError(error, stack, reason: 'setPushPreferences failed');
      }
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

  /// [awardSoloQuizCoins]ın bir sonraki [awardQuizCoins] çağrısına taşıdığı
  /// tur kimliği. Senkron okunup temizlenir (ilk `await`ten önce); böylece
  /// başka bir çağrıya sızmaz ve `awardQuizCoins`ı geçersiz kılan testler/alt
  /// sınıflar aynı yoldan geçer.
  String? _nextSoloRoundId;

  @override
  Future<QuizRewardClaim> awardSoloQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    required String clientRoundId,
  }) {
    _nextSoloRoundId = isClientRoundId(clientRoundId) ? clientRoundId : null;
    try {
      return awardQuizCoins(
        score: score,
        correctCount: correctCount,
        bestStreak: bestStreak,
        totalQuestions: totalQuestions,
      );
    } finally {
      _nextSoloRoundId = null;
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
    final soloRoundId = _nextSoloRoundId;
    _nextSoloRoundId = null;
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
          ? await _claimSolo(
              correctCount: correctCount,
              totalQuestions: totalQuestions,
              bestStreak: bestStreak,
              clientRoundId: soloRoundId,
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
        dailyCapReached: response is Map && response['cap_reached'] == true,
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

  /// `claim_solo_reward`: tur kimliği varsa tekil (4 argümanlı) imza, yoksa
  /// ya da sunucuda henüz yoksa (göç uygulanmamış: `PGRST202`/`42883`) eski
  /// 3 argümanlı imza. Eski imza yayındaki sürümlerle aynı davranır.
  Future<dynamic> _claimSolo({
    required int correctCount,
    required int totalQuestions,
    required int bestStreak,
    required String? clientRoundId,
  }) async {
    final legacy = {
      'p_correct_count': correctCount,
      'p_total_questions': totalQuestions,
      'p_best_streak': bestStreak,
    };
    if (clientRoundId == null) {
      return client.rpc('claim_solo_reward', params: legacy);
    }
    try {
      return await client.rpc(
        'claim_solo_reward',
        params: {...legacy, 'p_client_round_id': clientRoundId},
      );
    } on PostgrestException catch (error, stack) {
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      _recordError(
        error,
        stack,
        reason: 'claim_solo_reward round-id signature missing — legacy call',
      );
      return client.rpc('claim_solo_reward', params: legacy);
    }
  }

  static final _lessonUuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  bool get xpAwardIsServerTotal => true;

  @override
  Future<DurableCoinSpend> spendCoinsDurable(
    int amount,
    String reason,
    String idempotencyKey,
  ) async {
    final key = idempotencyKey.trim();
    if (key.isEmpty) {
      return DurableCoinSpend(
        success: await spendCoins(amount, reason),
        retryable: false,
      );
    }
    try {
      final response = await client.rpc(
        'spend_coins_once',
        params: {
          'p_amount': amount,
          'p_reason': reason,
          'p_idempotency_key': key,
        },
      );
      return coinSpendFromRpc(response);
    } on PostgrestException catch (error, stack) {
      if (_isMissingFunction(error)) {
        return DurableCoinSpend(
          success: await spendCoins(amount, reason),
          retryable: false,
        );
      }
      _recordError(error, stack, reason: 'spend_coins_once failed');
      throw RetryableWriteException(error);
    } catch (error, stack) {
      if (error is RetryableWriteException) rethrow;
      _recordError(error, stack, reason: 'spend_coins_once failed');
      throw RetryableWriteException(error);
    }
  }

  @override
  Future<int?> loadServerXp() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;
      final profile = await client
          .from('profiles')
          .select('xp')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) return null;
      return (profile['xp'] as num?)?.toInt() ?? 0;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadServerXp failed');
      return null;
    }
  }

  /// `award_xp_delta` `authenticated` rolünden geri alındı (canlıda
  /// doğrulandı, 2026-10-25); istemci solo deltayı sunucuya yazamaz. Hiçbir
  /// çağıran yok — ölü RPC çağrısı yerine onaylanmamış yazım olarak fırlatır.
  @Deprecated('Solo XP sunucuya yazılmaz; oda XP için awardRoomXp.')
  @override
  Future<int> awardXp(int delta) async {
    throw StateError('Solo XP award is not accepted by the server.');
  }

  @override
  Future<int> awardRoomXp(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) return 0;
    try {
      final user = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      if (currentUserId?.trim() != user.id) {
        throw StateError('Room XP award user changed before the write.');
      }
      final response = await client.rpc<dynamic>(
        'award_room_xp',
        params: {'p_room_id': id},
      );
      if (response is int) return response;
      if (response is num) return response.toInt();
      throw StateError('award_room_xp returned an unreadable total.');
    } on PostgrestException catch (error, stack) {
      _recordError(
        error,
        stack,
        reason: error.code == '42883'
            ? 'award_room_xp missing — migration not applied yet'
            : 'award_room_xp failed',
      );
      rethrow;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'award_room_xp failed');
      rethrow;
    }
  }

  void _recordError(Object error, StackTrace stack, {String? reason}) {
    ErrorReporter.record(error, stack, reason: reason);
  }

  Future<List<Map<String, dynamic>>> _fetchPublicProfiles(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    try {
      final response = await client.rpc(
        'get_public_profiles',
        params: {'p_ids': ids},
      );
      if (response is List) {
        return response.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } on PostgrestException catch (error, stack) {
      if (error.code != '42883') {
        _recordError(error, stack, reason: 'get_public_profiles failed');
        rethrow;
      }
      return await client
          .from('profiles')
          .select(
            'id, display_name, player_tag, avatar_icon, avatar_color, avatar_url, avatar_frame, showcase_title',
          )
          .inFilter('id', ids);
    }
  }

  /// id'ye göre herkese açık kimlik (taze; önbelleğe bakmaz — fotoğraf/ad
  /// değişmiş olabilir). Hata ve eksik RPC boş harita döner: çağıran eski
  /// davranışa (baş harf, yer tutucu ad) düşer, ekran bozulmaz.
  Future<Map<String, PublicProfile>> _publicProfilesById(
    Iterable<String?> ids,
  ) async {
    final unique = <String>{
      for (final id in ids)
        if (id != null && id.trim().isNotEmpty) id,
    }.toList();
    if (unique.isEmpty) return const {};
    try {
      final rows = await _fetchPublicProfiles(unique);
      return {
        for (final row in rows)
          if (row['id'] is String)
            row['id'] as String: PublicProfile.fromJson(row),
      };
    } catch (error, stack) {
      _recordError(error, stack, reason: 'public profiles lookup failed');
      return const {};
    }
  }

  @override
  Future<Map<String, PublicProfile>> loadPublicProfiles(Iterable<String> ids) =>
      _publicProfilesById(ids);

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

    // Oda tamamlanmadan KAPANDIYSA (rakip ayrıldı, hükmen bitti, oda
    // terk edildi) sunucu `already_claimed` olmadan `amount: 0` ve
    // `room_not_completed` döner: kalıcı, geçerli bir sıfırdır. Eskiden
    // aşağıdaki "tam alan" denetimi bunu StateError sayıp talebi kuyruğa
    // alıyordu ve sonuç ekranı bağlantı olduğu hâlde "Bağlantı yok. Ödülün
    // kaydedildi…" diyordu (iki simülatör turu, 2026-10-21: oyun ortasında
    // rakip çıkınca). `room_not_finished` / `answers_incomplete` GEÇİCİ
    // durumlardır (oda henüz kapanmadı); onlar kuyruğa girmeye devam eder.
    //
    // `room_progress_incomplete` da kalıcıdır: iki kişilik odada biri oyun
    // ortasında çıkınca `crowd_room_member_leave` odayı bilerek
    // `completed` kapatır ama indeksi ilerletmez (havuz yarım oyunda
    // dağıtılmaz). Kapanmış odanın indeksi bir daha ilerlemez; bu sıfır
    // kuyruğa girerse kalan oyuncu yine "Bağlantı yok" görüyordu (iki
    // simülatör turu, 2026-10-22: 10 sorunun 3'ünde rakip çıktı).
    if (json != null &&
        json['amount'] == 0 &&
        (json['room_not_completed'] == true ||
            json['room_progress_incomplete'] == true)) {
      return 0;
    }

    // Zorunlu iki alan yeter; fazlası yok sayılır. 2026-10-02'de sunucu
    // `daily_cap`/`cap_reached` ekleyince "tam iki alan" kuralı her oda
    // turunun ilk talebini reddediyordu: jeton sunucuda ödeniyor, istemci
    // "bağlantı yok" deyip kuyruğa alıyor, sonuç onayı hiç gitmiyor ve biten
    // oda her soğuk açılışta geri geliyordu (simülatör denemesi 2026-10-16).
    if (json == null ||
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
  /// `award_spin_coins` RPC'leri `public.app_today()` (`Europe/Istanbul`,
  /// kalıcı UTC+3) ile gün sınırı çizer (`2026-10-15_ilerleme_esitleme.sql`).
  /// Cihaz saat diliminden bağımsız olarak sunucuyla aynı UTC+3 gün sınırını
  /// kullanır; ekrandaki geri sayım da aynı gece yarısını hedefler.
  static String spinDayKey(DateTime now) {
    final istanbul = now.toUtc().add(const Duration(hours: 3));
    return '${istanbul.year}-${istanbul.month}-${istanbul.day}';
  }

  @override
  Future<int> unusedExtraSpins() async {
    try {
      return (await _unusedExtraSpinCount()).clamp(0, 1 << 30);
    } catch (error, stack) {
      _recordError(error, stack, reason: 'unusedExtraSpins failed');
      return 0;
    }
  }

  Future<bool> _hasUnusedExtraSpin() async => await _unusedExtraSpinCount() > 0;

  Future<int> _unusedExtraSpinCount() async {
    final user = client.auth.currentUser ?? await signInAnonymously();
    final purchased = await client
        .from('shop_purchases')
        .count(CountOption.exact)
        .eq('player_id', user.id)
        .eq('item_id', 'spin_wheel_extra');
    final used = await client
        .from('coin_transactions')
        .count(CountOption.exact)
        .eq('player_id', user.id)
        .inFilter('reason', ['extra_spin:server', 'daily_spin:extra_purchase']);
    return purchased - used;
  }

  static String get _lastSpinKey =>
      LocalProgressScope.physical('zankurd.last_spin_date');

  /// Yerel "bugün çevirdim" işareti; hesaba bağlıdır. Oturum yoksa null.
  String? _spinMarker(String day) {
    final uid = currentUserId;
    return uid == null ? null : '$uid|$day';
  }

  @override
  Future<bool> canSpinToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSpinStr = prefs.getString(_lastSpinKey);
      // Değer `<uid>|<gün>` biçimindedir: eski sabit anahtardan ya da başka
      // hesaptan kalan kayıt eşleşmez, o durumda sunucuya sorulur.
      final todayStr = _spinMarker(spinDayKey(DateTime.now()));
      if (todayStr != null && lastSpinStr == todayStr) {
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
          final marker = _spinMarker(spinDayKey(DateTime.now()));
          if (marker != null) await prefs.setString(_lastSpinKey, marker);
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
      final tags = await _publicProfilesById([
        for (final row in rows) (row as Map)['player_id'] as String?,
      ]);
      return rows.indexed.map((item) {
        final index = item.$1;
        final row = item.$2 as Map<String, dynamic>;
        return LeaderboardEntry(
          playerTag: tags[row['player_id'] as String?]?.playerTag,
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
      // Eski leaderboard_entries görünümü profiles.xp'ye dayanabilir ve
      // geçmişte istemci deltasından etkilenmiş olabilir. Yetkili RPC
      // okunamıyorsa güvenilir olmayan rekabetçi puanı göstermeyiz.
      //
      // Boş liste de dönmeyiz: ekran boş listeyi "Henüz puan yok" diye
      // çiziyordu; okunamayan sıralama boş sıralama değildir. Hata yukarı
      // taşınır, ekran kendi hata durumunu (K.boardLoadFailed) gösterir.
      rethrow;
    }
  }

  Future<List<Player>> _loadRoomPlayersById(String roomId) async {
    final rows = await client
        .from('room_players')
        .select(
          'player_id, score, streak, is_ready, left_at, '
          'profiles(display_name, player_tag, avatar_icon, avatar_color, '
          'avatar_url, avatar_frame, showcase_title)',
        )
        .eq('room_id', roomId)
        // Eşit katılma zamanında oyuncu kimliği: gerçek zamanlı akışla
        // (`compareRoomPlayerRows`) aynı kararlı sıra.
        .order('joined_at')
        .order('player_id');

    // `profiles` RLS yalnız kendi satırını okutur: gömülü profil öteki
    // oyuncular için null gelir ve lobide herkes "Oyuncu" görünüyordu.
    // Adı bilinmeyenler herkese açık profil RPC'siyle tamamlanır.
    final missing = [
      for (final row in rows)
        if (row['profiles'] == null &&
            !_profileCache.containsKey(row['player_id'] as String))
          row['player_id'] as String,
    ];
    if (missing.isNotEmpty) {
      try {
        for (final profile in await _fetchPublicProfiles(missing)) {
          final id = profile['id'] as String?;
          if (id != null) _profileCache[id] = profile;
        }
      } catch (error, stack) {
        _recordError(error, stack, reason: 'room players public profiles');
      }
    }

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
        tag: profile?['player_tag'] as String?,
        left: row['left_at'] != null,
      );
    }).toList();
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

  bool _touchMatchmakingSupported = true;

  @override
  Future<MatchmakingTouch> touchMatchmaking() async {
    // Göç uygulanmadan yayınlanan derleme: RPC yok, eski yola (akış + 20 sn
    // zamanlayıcı) sessizce düş ve oturum boyunca bir daha sorma.
    if (!_touchMatchmakingSupported) return const MatchmakingTouch.unknown();
    try {
      final response = await client.rpc('touch_matchmaking');
      return MatchmakingTouch.fromJson(response);
    } catch (error, stack) {
      if (isMissingRpcError(error)) {
        _touchMatchmakingSupported = false;
        return const MatchmakingTouch.unknown();
      }
      _recordError(error, stack, reason: 'touchMatchmaking failed');
      rethrow;
    }
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
          controller.add(decodeRoomBroadcast(payload));
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
      await channel.sendBroadcastMessage(
        event: 'game_event',
        payload: encodeRoomBroadcast(payload),
      );
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
  Future<bool> submitDailyEventResult({
    required int correct,
    required int total,
    required int seconds,
  }) async {
    try {
      final res = await client
          .rpc(
            'submit_daily_event_result',
            params: {
              'p_correct': correct,
              'p_total': total,
              'p_seconds': seconds,
            },
          )
          .timeout(const Duration(seconds: 8));
      return res == true;
    } catch (e, s) {
      // Sıralama yalnız gösterimdir: yazılamayan sonuç turu bozmaz.
      _recordError(e, s, reason: 'submitDailyEventResult failed');
      return false;
    }
  }

  @override
  Future<DailyEventBoard?> loadDailyEventBoard() async {
    try {
      if (client.auth.currentUser == null) return null;
      final res = await client
          .rpc('get_daily_event_board')
          .timeout(const Duration(seconds: 8));
      return DailyEventBoard.tryParse(res);
    } catch (e, s) {
      _recordError(e, s, reason: 'loadDailyEventBoard failed');
      return null;
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

  Future<String?> _canonicalLessonId(String lessonId) async {
    final id = lessonId.trim();
    if (id.isEmpty) return null;
    if (_lessonUuid.hasMatch(id)) return id;
    try {
      final row = await client
          .from('lessons')
          .select('id')
          .eq('slug', id)
          .maybeSingle();
      final resolved = row?['id'];
      if (resolved is String && _lessonUuid.hasMatch(resolved)) return resolved;
      final alias = LearningLessonAliases.completionSlugFor(id);
      if (alias != null && alias != id) {
        final aliasRow = await client
            .from('lessons')
            .select('id')
            .eq('slug', alias)
            .maybeSingle();
        final aliasId = aliasRow?['id'];
        if (aliasId is String && _lessonUuid.hasMatch(aliasId)) return aliasId;
      }
    } catch (error, stack) {
      _recordError(error, stack, reason: 'lesson slug lookup failed');
    }
    return null;
  }

  @override
  Future<bool> markLessonCompleted(String lessonId) async {
    try {
      final canonicalId = await _canonicalLessonId(lessonId);
      if (canonicalId == null) return false;
      await client.rpc(
        'mark_lesson_completed',
        params: {'p_lesson_id': canonicalId},
      );
      return true;
    } catch (e, s) {
      _recordError(e, s, reason: 'markLessonCompleted failed');
      // SUNUCUYA YAZILAMADIYSA BAŞARI BİLDİRME (addFriend'deki aynı kural).
      //
      // `false` "sunucu onaylamadı" demektir. Çağıran (ders ekranı)
      // `SyncManager.queueLessonCompletion` ile dersi önce yerele yazar,
      // sonra sunucu kuyruğuna alır; kilit durumu yerel ∪ sunucu okunur.
      return false;
    }
  }

  @override
  Future<Set<String>> loadCompletedLessonIds() async {
    // Yerel (bekleyen ∪ eşitlenmiş) kümeyi hep ekle: çevrimdışı tamamlanan
    // ders sunucuya ulaşana kadar sonraki dersleri açık tutar.
    final local = await LessonCompletionStore.loadLocal();
    try {
      final rows = await client
          .from('user_lesson_progress')
          .select('lesson_id')
          .eq('completed', true);
      final server = rows
          .map((row) => row['lesson_id'] as String?)
          .whereType<String>()
          .toSet();
      await LessonCompletionStore.cacheServer(server);
      return {...server, ...(await LessonCompletionStore.loadLocal())};
    } catch (e, s) {
      _recordError(e, s, reason: 'loadCompletedLessonIds failed');
      return local;
    }
  }

  @override
  Future<AddFriendOutcome> addFriend(String friendId, String friendName) async {
    try {
      final response = await client.rpc<dynamic>(
        'add_friend',
        params: {'p_friend_id': friendId, 'p_friend_name': friendName},
      );
      final row = _firstRow(response);
      return AddFriendOutcome.fromServer(
        success: (row?['success'] as bool?) ?? false,
        message: row?['message'] as String?,
      );
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
      return AddFriendOutcome.failed;
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
  Future<void> clearFcmToken() async {
    try {
      await client.rpc<void>('clear_my_fcm_token');
    } catch (e, s) {
      // Göç uygulanmamışsa (PGRST202) ya da ağ yoksa çıkış yine sürer.
      if (!isMissingRpcError(e)) {
        _recordError(e, s, reason: 'clearFcmToken failed');
      }
    }
  }

  @override
  Future<List<SentFriendRequest>?> loadSentFriendRequests() async {
    try {
      final res = await client.rpc<List<dynamic>>('list_sent_friend_requests');
      final sent = res
          .map(
            (row) => SentFriendRequest.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      final profiles = await _publicProfilesById([
        for (final r in sent) r.toUserId,
      ]);
      return [
        for (final r in sent)
          profiles[r.toUserId] == null
              ? r
              : SentFriendRequest(
                  id: r.id,
                  toUserId: r.toUserId,
                  toUserName: profiles[r.toUserId]!.nameOr(r.toUserName),
                  createdAt: r.createdAt,
                  toProfile: profiles[r.toUserId],
                ),
      ];
    } catch (e, s) {
      if (isMissingRpcError(e)) return null;
      _recordError(e, s, reason: 'loadSentFriendRequests failed');
      return const [];
    }
  }

  @override
  Future<bool> removeFriend(String friendId) async {
    try {
      final response = await client.rpc<dynamic>(
        'remove_friend',
        params: {'p_friend_id': friendId},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'removeFriend failed');
      // Sunucuya yazılamadıysa başarı bildirme (addFriend ile aynı kural).
      return false;
    }
  }

  @override
  Future<bool> cancelFriendRequest(String targetUserId) async {
    try {
      final response = await client.rpc<dynamic>(
        'cancel_friend_request',
        params: {'p_target_id': targetUserId},
      );
      return (_firstRow(response)?['success'] as bool?) ?? false;
    } catch (e, s) {
      _recordError(e, s, reason: 'cancelFriendRequest failed');
      return false;
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
      final found = res
          .map(
            (row) => PlayerSearchResult.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      // `search_profiles` fotoğraf/simge döndürmez; arama sonucu da aynı
      // avatarla çizilsin diye herkese açık profille tamamlanır.
      final profiles = await _publicProfilesById([for (final f in found) f.id]);
      return [
        for (final f in found)
          profiles[f.id] == null
              ? f
              : PlayerSearchResult(
                  id: f.id,
                  displayName: f.displayName,
                  avatarColor: f.avatarColor,
                  playerTag: f.playerTag,
                  profile: profiles[f.id],
                ),
      ];
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
      // `list_friends` çağıranın yetkisiyle çalışır: `profiles` RLS'si
      // arkadaşın satırını gizler, ad ve renk `friends` tablosuna yazılmış
      // eski kopyadan gelir (fotoğraf hiç gelmez). Güncel kimlik herkese
      // açık profilden tamamlanır.
      final profiles = await _publicProfilesById([
        for (final row in res) (row as Map)['friend_id'] as String?,
      ]);
      return res.map((row) {
        var friend = Friend.fromJson(Map<String, dynamic>.from(row as Map));
        final profile = profiles[friend.friendId];
        if (profile != null) {
          friend = friend.copyWith(
            friendName: profile.nameOr(friend.friendName),
            friendAvatarColor: profile.avatar.colorHex,
            profile: profile,
          );
        }
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
      // Hata "arkadaşın yok" DEĞİLDİR: boş liste dönmek ekranın hata +
      // "tekrar dene" durumunu hiç tetiklemiyordu (bkz.
      // test/friend_read_errors_test.dart).
      rethrow;
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
      rethrow;
    }
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    try {
      final res = await client.rpc<List<dynamic>>(
        'list_pending_friend_requests',
      );
      final pending = res
          .map(
            (row) =>
                FriendRequest.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      final profiles = await _publicProfilesById([
        for (final r in pending) r.fromUserId,
      ]);
      return [
        for (final r in pending)
          profiles[r.fromUserId] == null
              ? r
              : FriendRequest(
                  id: r.id,
                  fromUserId: r.fromUserId,
                  fromUserName: profiles[r.fromUserId]!.nameOr(r.fromUserName),
                  toUserId: r.toUserId,
                  createdAt: r.createdAt,
                  status: r.status,
                  fromProfile: profiles[r.fromUserId],
                ),
      ];
    } catch (e, s) {
      _recordError(e, s, reason: 'loadPendingFriendRequests failed');
      // Bkz. loadFriends: hata "bekleyen istek yok" anlamına gelmez.
      rethrow;
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
      return false;
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
      return false;
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
      // Yalnız "sunucu tarafı henüz yok" null döner (bot benzetimine izin
      // verir). Geçici ağ hatası artık sahte bot şemasına düşürmez: çağıran
      // hatayı görür ve yeniden dener.
      if (_isMissingFunction(e)) return null;
      _recordError(e, s, reason: 'joinRealTournament failed');
      rethrow;
    }
  }

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async {
    try {
      final response = await client.rpc('get_tournament_bracket');
      if (response == null) return null;
      final bracket = TournamentBracket.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      // Bracket yalnız ad döndürür; fotoğraf/simge/kod herkese açık profilden.
      final profiles = await _publicProfilesById([
        for (final round in bracket.rounds)
          for (final m in round.matches) ...[m.playerOneId, m.playerTwoId],
      ]);
      if (profiles.isEmpty) return bracket;
      return bracket.copyWith(
        rounds: [
          for (final round in bracket.rounds)
            round.copyWith(
              matches: [
                for (final m in round.matches)
                  m.copyWith(
                    playerOneProfile: profiles[m.playerOneId],
                    playerTwoProfile: profiles[m.playerTwoId],
                  ),
              ],
            ),
        ],
      );
    } catch (e, s) {
      // `null` yalnız "turnuvada değilsin / sunucu tarafı yok" demektir.
      // Ağ hatası eskiden de null dönüp çevrimdışı bot şemasına düşüyordu;
      // şimdi fırlar, ekran hata + yeniden dene gösterir.
      if (_isMissingFunction(e)) return null;
      _recordError(e, s, reason: 'loadRealTournamentBracket failed');
      rethrow;
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
    final standings = tournamentStandingsFromBracket(bracket);
    if (standings.isEmpty) {
      return _offline.loadTournamentStandings(limit: limit);
    }
    return standings.take(limit).toList();
  }

  @override
  Future<ChampionRewardClaim> claimChampionRewardStatus() async {
    try {
      final response = await client.rpc<dynamic>('claim_tournament_reward');
      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final alreadyClaimed = json['already_claimed'] == true;
      return ChampionRewardClaim(
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        // Eski sunucu `paid_amount` göndermez: zaten alındıysa sabit ödül.
        alreadyPaid: alreadyClaimed
            ? (json['paid_amount'] as num?)?.toInt() ??
                  TournamentConfig.coinBonusChampion
            : 0,
      );
    } catch (e, s) {
      if (_isMissingFunction(e)) {
        _recordError(e, s, reason: 'claimChampionRewardStatus missing');
        return const ChampionRewardClaim(amount: 0);
      }
      _recordError(e, s, reason: 'claimChampionRewardStatus failed');
      rethrow;
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
      // Ödül yalnız sunucu tarafından doğrulanabilir. RPC eksik olsa bile
      // mock depoya düşmek 500 coin uydurur ve ekranın dürüst `unverified`
      // durumunu atlatır. Eksik fonksiyon ödül verilmedi anlamına gelir.
      if (_isMissingFunction(e)) {
        _recordError(e, s, reason: 'claimTournamentChampionReward missing');
        return 0;
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
        // INSERT politikası `license_version = '2026-08-11'` ister;
        // `accepted_at`i tetikleyici sunucu saatiyle damgalar.
        'license_version': suggestedQuestionLicenseVersion,
        'attribution_requested': false,
        'do_not_publish': false,
      });
      return true;
    } catch (e, stack) {
      _recordError(e, stack, reason: 'submitSuggestedQuestion failed');
      return false;
    }
  }

  @override
  Future<List<MySuggestion>?> loadMySuggestions() async {
    try {
      final userId = currentUserId;
      if (userId == null) return const [];
      // `suggested_questions_read_own` yalnız kendi satırlarını okutur;
      // `eq` yine de yazılır ki sorgu politikaya yaslanmadan doğru olsun.
      final rows = await client
          .from('suggested_questions')
          .select('id, category, prompt, status, created_at, review_note')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return [for (final row in rows) MySuggestion.fromRow(row)];
    } catch (e, stack) {
      _recordError(e, stack, reason: 'loadMySuggestions failed');
      return null;
    }
  }

  @override
  Future<ReferralResult> redeemReferralCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return const ReferralResult(
        status: ReferralStatus.notFound,
        message: 'Invalid code',
      );
    }
    try {
      final response = await client.rpc(
        'redeem_referral_code',
        params: {'p_code': clean},
      );
      if (response is Map<String, dynamic>) {
        final result = ReferralResult.fromMap(response);
        if (result.isSuccess) {
          unawaited(loadCoinBalance());
        }
        return result;
      }
      return const ReferralResult(
        status: ReferralStatus.networkError,
        message: 'Unexpected response format',
      );
    } catch (e, stack) {
      _recordError(e, stack, reason: 'redeemReferralCode failed');
      final msg = e.toString();
      if (msg.contains('own_code') || msg.contains('Cannot use own code')) {
        return const ReferralResult(status: ReferralStatus.ownCode);
      }
      if (msg.contains('already_redeemed') || msg.contains('already used')) {
        return const ReferralResult(status: ReferralStatus.alreadyRedeemed);
      }
      if (msg.contains('code_not_found') ||
          msg.contains('Invalid referral code')) {
        return const ReferralResult(status: ReferralStatus.notFound);
      }
      return const ReferralResult(status: ReferralStatus.networkError);
    }
  }

  // ─── Sırayla düello (async 1v1) ──────────────────────────────────────
  //
  // Rakibin aynı anda çevrimiçi olmasını gerektirmeyen 1v1: oyuncu 7 soruyu
  // hemen oynar, rakip (varsa açık bir düello alarak, yoksa sonradan
  // katılarak) kendi zamanında oynar. Sözleşme `sirayla_duello_tasarim.md`de
  // sabittir; burası yalnız RPC çağrısı + JSON ayrıştırmadır, iş kuralları
  // (kazanan, XP, süre) sunucudadır.

  Future<AsyncDuelStart> _withDuelProfiles(AsyncDuelStart start) async {
    final profiles = await _publicProfilesById([
      start.opponentId,
      start.invitedId,
    ]);
    if (profiles.isEmpty) return start;
    return start.withProfiles(
      opponent: profiles[start.opponentId],
      invited: profiles[start.invitedId],
    );
  }

  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async {
    try {
      if (client.auth.currentUser == null) {
        await signInAnonymously();
      }
      await ensureProfile();
      final response = await client.rpc(
        'start_async_duel',
        params: {'p_category': category},
      );
      return _withDuelProfiles(
        AsyncDuelStart.fromJson(
          _requiredJsonObject(response, 'start_async_duel'),
        ),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'startAsyncDuel failed');
      rethrow;
    }
  }

  @override
  Future<int?> presentAsyncDuelQuestion(
    String duelId,
    int questionIndex,
  ) async {
    try {
      final response = await client.rpc(
        'present_async_duel_question',
        params: {'p_duel_id': duelId, 'p_question_index': questionIndex},
      );
      final json = _requiredJsonObject(response, 'present_async_duel_question');
      return (json['elapsed_ms'] as num?)?.toInt() ?? 0;
    } catch (error, stack) {
      // Göç uygulanmamış sunucu: cevap eski ölçümle sürer, hata değil.
      if (isMissingRpcError(error)) return null;
      _recordError(error, stack, reason: 'presentAsyncDuelQuestion failed');
      rethrow;
    }
  }

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    try {
      final response = await client.rpc(
        'answer_async_duel',
        params: {
          'p_duel_id': duelId,
          'p_question_index': questionIndex,
          'p_choice': choice,
          'p_response_ms': responseMs,
        },
      );
      return AsyncDuelAnswer.fromJson(
        _requiredJsonObject(response, 'answer_async_duel'),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'answerAsyncDuel failed');
      rethrow;
    }
  }

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    try {
      final response = await client.rpc<List<dynamic>>('list_my_async_duels');
      final duels = response
          .map(
            (row) => AsyncDuelSummary.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      // Rakip/davetli kimliği `2026-10-21_oyuncu_kimligi.sql` uygulanınca
      // gelir; gelmediyse harita boş kalır ve eski çizim sürer.
      final profiles = await _publicProfilesById([
        for (final d in duels) ...[d.opponentId, d.invitedId],
      ]);
      if (profiles.isEmpty) return duels;
      return [
        for (final d in duels)
          d.withProfiles(
            opponent: profiles[d.opponentId],
            invited: profiles[d.invitedId],
          ),
      ];
    } catch (error, stack) {
      // Boş listeye düşülmez: "hiç düellon yok" demek, rakibini bekleyen ya
      // da sonucu hazır bir düelloyu oyuncudan gizlemek olurdu. Ekran hatayı
      // "yeniden dene" olarak gösterir.
      _recordError(error, stack, reason: 'loadMyAsyncDuels failed');
      rethrow;
    }
  }

  @override
  Future<void> markAsyncDuelSeen(String duelId) async {
    try {
      await client.rpc('mark_async_duel_seen', params: {'p_duel_id': duelId});
    } catch (error, stack) {
      _recordError(error, stack, reason: 'markAsyncDuelSeen failed');
      rethrow;
    }
  }

  @override
  Future<DateTime> nudgeAsyncDuel(String duelId) async {
    try {
      final response = await client.rpc(
        'nudge_async_duel',
        params: {'p_duel_id': duelId},
      );
      final json = _requiredJsonObject(response, 'nudge_async_duel');
      return DateTime.parse(json['nudged_at'] as String);
    } catch (error, stack) {
      // Bekleme/engel gibi BEKLENEN retler hata raporuna düşmez; ekran
      // sınıflandırıp oyuncuya söyler (classifyAsyncDuelNudgeError).
      if (classifyAsyncDuelNudgeError(error) == AsyncDuelNudgeError.other) {
        _recordError(error, stack, reason: 'nudgeAsyncDuel failed');
      }
      rethrow;
    }
  }

  @override
  Future<List<RecentMatch>> loadMyRecentMatches({int limit = 10}) async {
    try {
      final response = await client.rpc<List<dynamic>>(
        'list_my_recent_matches',
        params: {'p_limit': limit},
      );
      return [
        for (final row in response)
          ?RecentMatch.tryParse(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadMyRecentMatches failed');
      rethrow;
    }
  }

  @override
  Future<ServerRecords> loadMyServerRecords() async {
    try {
      final response = await client.rpc('get_my_records');
      return ServerRecords.fromJson(
        _requiredJsonObject(response, 'get_my_records'),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadMyServerRecords failed');
      rethrow;
    }
  }

  @override
  Future<int> claimAsyncDuelXp(String duelId) async {
    try {
      final response = await client.rpc<dynamic>(
        'claim_async_duel_xp',
        params: {'p_duel_id': duelId},
      );
      if (response is int) return response;
      if (response is num) return response.toInt();
      throw StateError('claim_async_duel_xp returned an unreadable total.');
    } catch (error, stack) {
      _recordError(error, stack, reason: 'claimAsyncDuelXp failed');
      rethrow;
    }
  }

  // ─── Arkadaşa meydan okuma (supabase/2026-10-13_friend_challenge.sql) ─

  /// `null`: henüz bilinmiyor; `false`: sunucu RPC'yi tanımıyor (göç
  /// uygulanmamış). Yalnız KESİN yanıtlar saklanır.
  bool? _challengeRpcSupported;

  @override
  Future<bool> supportsAsyncDuelChallenge() async {
    final known = _challengeRpcSupported;
    if (known != null) return known;
    // Oturum yokken (misafir henüz hesap açmadı) sormak hesap yaratırdı;
    // belirsiz = göster.
    if (client.auth.currentUser == null) return true;
    try {
      // Yan etkisiz sonda: bilinmeyen kod yeni sunucuda 'Challenge not
      // found' fırlatır (RPC var), eskisinde PGRST202/42883 (RPC yok).
      await client.rpc(
        'accept_async_duel_challenge',
        params: {'p_code': 'D00000000'},
      );
      return _challengeRpcSupported = true;
    } catch (error, stack) {
      if (isMissingRpcError(error)) return _challengeRpcSupported = false;
      if (error.toString().contains('Challenge')) {
        return _challengeRpcSupported = true;
      }
      // Ağ hatası gibi belirsiz durum: giriş noktaları görünür kalır, ilk
      // gerçek çağrı kendi hatasını gösterir.
      _recordError(error, stack, reason: 'supportsAsyncDuelChallenge failed');
      return true;
    }
  }

  // ─── Odaya arkadaş daveti (supabase/2026-10-18_oda_davet.sql) ────────

  /// `null`: henüz bilinmiyor; `false`: sunucu RPC'yi tanımıyor (göç
  /// uygulanmamış). Yalnız KESİN yanıtlar saklanır.
  bool? _roomInviteRpcSupported;

  @override
  Future<bool> supportsRoomInvites() async {
    final known = _roomInviteRpcSupported;
    if (known != null) return known;
    // Oturum yokken sormak misafir hesabı yaratırdı; belirsiz = göster.
    if (client.auth.currentUser == null) return true;
    try {
      await client.rpc<List<dynamic>>('list_my_room_invites');
      return _roomInviteRpcSupported = true;
    } catch (error, stack) {
      if (isMissingRpcError(error)) return _roomInviteRpcSupported = false;
      _recordError(error, stack, reason: 'supportsRoomInvites failed');
      return true;
    }
  }

  @override
  Future<int> inviteFriendsToRoom(GameRoom room, List<String> friendIds) async {
    final roomId = room.id;
    if (roomId == null || friendIds.isEmpty) return 0;
    try {
      final res = await client.rpc(
        'invite_friends_to_room',
        params: {'p_room_id': roomId, 'p_friend_ids': friendIds},
      );
      return (res as num?)?.toInt() ?? 0;
    } on PostgrestException catch (error, stack) {
      _recordError(error, stack, reason: 'inviteFriendsToRoom rejected');
      throw RoomInviteException(
        RoomInviteException.reasonForMessage(error.message),
        error.message,
      );
    }
  }

  @override
  Future<Set<String>> loadRoomInvitedIds(GameRoom room) async {
    final roomId = room.id;
    if (roomId == null) return const {};
    try {
      final rows = await client
          .from('room_invites')
          .select('invitee_id')
          .eq('room_id', roomId)
          .eq('status', 'pending');
      return {for (final row in rows) (row as Map)['invitee_id'] as String};
    } catch (error, stack) {
      _recordError(error, stack, reason: 'loadRoomInvitedIds failed');
      return const {};
    }
  }

  @override
  Future<List<RoomInvite>> loadMyRoomInvites({
    bool throwOnError = false,
  }) async {
    if (_roomInviteRpcSupported == false) return const [];
    if (client.auth.currentUser == null) return const [];
    try {
      final res = await client.rpc<List<dynamic>>('list_my_room_invites');
      _roomInviteRpcSupported = true;
      final invites = [
        for (final row in res)
          RoomInvite.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
      final profiles = await _publicProfilesById([
        for (final i in invites) i.inviterId,
      ]);
      return [
        for (final i in invites)
          profiles[i.inviterId] == null
              ? i
              : RoomInvite(
                  id: i.id,
                  roomId: i.roomId,
                  roomCode: i.roomCode,
                  inviterId: i.inviterId,
                  inviterName: profiles[i.inviterId]!.nameOr(i.inviterName),
                  categoryName: i.categoryName,
                  playerCount: i.playerCount,
                  maxPlayers: i.maxPlayers,
                  createdAt: i.createdAt,
                  inviterProfile: profiles[i.inviterId],
                ),
      ];
    } catch (error, stack) {
      if (isMissingRpcError(error)) _roomInviteRpcSupported = false;
      _recordError(error, stack, reason: 'loadMyRoomInvites failed');
      if (throwOnError) rethrow;
      return const [];
    }
  }

  @override
  Future<String?> respondRoomInvite(
    String inviteId, {
    required bool accept,
  }) async {
    try {
      final res = await client.rpc(
        'respond_room_invite',
        params: {'p_invite_id': inviteId, 'p_accept': accept},
      );
      return res as String?;
    } on PostgrestException catch (error, stack) {
      _recordError(error, stack, reason: 'respondRoomInvite rejected');
      throw RoomInviteException(
        RoomInviteException.reasonForMessage(error.message),
        error.message,
      );
    }
  }

  @override
  Future<AsyncDuelStart> createAsyncDuelChallenge({
    String? category,
    String? friendId,
  }) async {
    try {
      if (client.auth.currentUser == null) {
        await signInAnonymously();
      }
      await ensureProfile();
      final response = await client.rpc(
        'create_async_duel_challenge',
        params: {'p_category': category, 'p_friend_id': friendId},
      );
      return _withDuelProfiles(
        AsyncDuelStart.fromJson(
          _requiredJsonObject(response, 'create_async_duel_challenge'),
        ),
      );
    } catch (error, stack) {
      if (isMissingRpcError(error)) _challengeRpcSupported = false;
      _recordError(error, stack, reason: 'createAsyncDuelChallenge failed');
      rethrow;
    }
  }

  @override
  Future<AsyncDuelStart> resumeAsyncDuel(String duelId) async {
    try {
      final response = await client.rpc(
        'resume_my_async_duel',
        params: {'p_duel_id': duelId},
      );
      return _withDuelProfiles(
        AsyncDuelStart.fromJson(
          _requiredJsonObject(response, 'resume_my_async_duel'),
        ),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'resumeAsyncDuel failed');
      rethrow;
    }
  }

  @override
  Future<int?> loadJokerStock() async {
    if (client.auth.currentUser == null) return null;
    try {
      final response = await client.rpc<dynamic>('get_joker_stock');
      return (response as num?)?.toInt();
    } catch (error, stack) {
      if (isMissingRpcError(error)) return null;
      _recordError(error, stack, reason: 'loadJokerStock failed');
      return null;
    }
  }

  @override
  Future<bool> consumeJokerStock() async {
    if (client.auth.currentUser == null) return true;
    try {
      final response = await client.rpc<dynamic>('consume_joker_stock');
      // `-1` = kalan hak yok, düşüş reddedildi.
      return !(response is num && response < 0);
    } catch (error, stack) {
      if (isMissingRpcError(error)) return true;
      _recordError(error, stack, reason: 'consumeJokerStock failed');
      rethrow;
    }
  }

  @override
  Future<AsyncDuelStart> startTournamentMatch(String matchId) async {
    try {
      final response = await client.rpc(
        'start_tournament_match',
        params: {'p_match_id': matchId},
      );
      return _withDuelProfiles(
        AsyncDuelStart.fromJson(
          _requiredJsonObject(response, 'start_tournament_match'),
        ),
      );
    } catch (error, stack) {
      // Eski kupa ya da göç uygulanmamış sunucu: çağıran eski yola düşer.
      if (!isMissingRpcError(error) &&
          !error.toString().contains('Not server scored')) {
        _recordError(error, stack, reason: 'startTournamentMatch failed');
      }
      rethrow;
    }
  }

  @override
  Future<TournamentPresent> presentTournamentQuestion(
    String matchId,
    int questionIndex,
  ) async {
    try {
      final response = await client.rpc(
        'present_tournament_question',
        params: {'p_match_id': matchId, 'p_question_index': questionIndex},
      );
      return TournamentPresent.fromJson(
        _requiredJsonObject(response, 'present_tournament_question'),
      );
    } catch (error, stack) {
      _recordError(error, stack, reason: 'presentTournamentQuestion failed');
      rethrow;
    }
  }

  @override
  Future<AsyncDuelAnswer> answerTournamentQuestion({
    required String matchId,
    required int questionIndex,
    required String choice,
  }) async {
    try {
      final response = await client.rpc(
        'answer_tournament_question',
        params: {
          'p_match_id': matchId,
          'p_question_index': questionIndex,
          'p_choice': choice,
        },
      );
      return AsyncDuelAnswer.fromJson(
        _requiredJsonObject(response, 'answer_tournament_question'),
      );
    } catch (error, stack) {
      if (!error.toString().contains('Already answered')) {
        _recordError(error, stack, reason: 'answerTournamentQuestion failed');
      }
      rethrow;
    }
  }

  @override
  Future<AsyncDuelReview?> loadAsyncDuelReview(String duelId) async {
    try {
      final response = await client.rpc(
        'get_async_duel_review',
        params: {'p_duel_id': duelId},
      );
      return AsyncDuelReview.fromJson(
        _requiredJsonObject(response, 'get_async_duel_review'),
      );
    } catch (error, stack) {
      // Göç uygulanmamış sunucuda RPC yok: bölüm gizlenir, hata sayılmaz.
      if (isMissingRpcError(error)) return null;
      // "Henüz bitmedi / katılımcı değilsin" beklenen reddir, rapora düşmez.
      if (classifyAsyncDuelReviewError(error) == AsyncDuelReviewError.other) {
        _recordError(error, stack, reason: 'loadAsyncDuelReview failed');
      }
      rethrow;
    }
  }

  @override
  Future<bool> cancelAsyncDuel(String duelId) async {
    try {
      final response = await client.rpc(
        'cancel_my_async_duel',
        params: {'p_duel_id': duelId},
      );
      return response == true;
    } catch (error, stack) {
      if (!isMissingRpcError(error)) {
        _recordError(error, stack, reason: 'cancelAsyncDuel failed');
      }
      return false;
    }
  }

  @override
  Future<AsyncDuelStart> acceptAsyncDuelChallenge(String code) async {
    try {
      if (client.auth.currentUser == null) {
        await signInAnonymously();
      }
      await ensureProfile();
      final response = await client.rpc(
        'accept_async_duel_challenge',
        params: {'p_code': code},
      );
      return _withDuelProfiles(
        AsyncDuelStart.fromJson(
          _requiredJsonObject(response, 'accept_async_duel_challenge'),
        ),
      );
    } catch (error, stack) {
      if (isMissingRpcError(error)) _challengeRpcSupported = false;
      // Beklenen iş hataları (süresi dolmuş, başkası almış…) çökme kaydı
      // değildir; yalnız beklenmeyenler kaydedilir.
      if (classifyAsyncDuelChallengeError(error) ==
          AsyncDuelChallengeError.other) {
        _recordError(error, stack, reason: 'acceptAsyncDuelChallenge failed');
      }
      rethrow;
    }
  }
}

/// Yayın yükünde `type` anahtarı kütüphane tarafından ezilir.
///
/// `RealtimeChannel.send` (realtime_client 2.13) verilen haritanın kendisine
/// `payload['type'] = 'broadcast'` ve `payload['event'] = 'game_event'`
/// yazar. Ekranların gönderdiği `{'type': 'reaction', ...}` bu yüzden telden
/// `type: 'broadcast'` olarak gidiyor, alıcıdaki `payload['type'] ==
/// 'reaction'` denetimi hiç tutmuyor ve hazır mesajlar/tepkiler karşıya
/// ulaşmıyordu. Gönderim hatası yoktu, bu yüzden kusur sessizdi.
/// `kind` anahtarı ezilmez; alıcı [decodeRoomBroadcast] ile geri yazar.
@visibleForTesting
Map<String, dynamic> encodeRoomBroadcast(Map<String, dynamic> payload) {
  final copy = Map<String, dynamic>.of(payload);
  final type = copy['type'];
  if (type != null) copy['kind'] = type;
  return copy;
}

/// [encodeRoomBroadcast]ın tersi. Sunucu yükü düz ya da `payload` altında
/// iç içe (REST yedeği böyle taşır) verebilir; ikisi de düzleştirilir.
@visibleForTesting
Map<String, dynamic> decodeRoomBroadcast(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.of(raw);
  final inner = raw['payload'];
  if (inner is Map) {
    out.addAll(Map<String, dynamic>.from(inner));
  }
  final kind = out['kind'];
  if (kind != null) out['type'] = kind;
  return out;
}

/// Bracket'teki maçlardan sıralama türetir. Final oynandıysa kazanan
/// `champion`, kaybeden `finalist`; erken turda kaybeden `eliminated`.
///
/// Tur 1 (I9, 2026-10-29): yarı finali KAZANAN da `finalist`tir (finale
/// çıktı). Sunucu final turunu ancak iki yarı final bitince kurar; o ana
/// kadar bracket'te tek maçlık tur yoktu ve yarı final galibi "Bekliyor"
/// (`active`) görünüyordu (simülatör, 4 kişilik kupa). Final turunun numarası
/// artık ilk turdaki oyuncu sayısından da çıkarılır.
List<TournamentStandings> tournamentStandingsFromBracket(
  TournamentBracket bracket,
) {
  final names = <String, String>{};
  final profiles = <String, PublicProfile>{};
  final scores = <String, int>{};
  final status = <String, String>{};

  int? finalRound;
  for (final round in bracket.rounds) {
    if (round.matches.length == 1) finalRound = round.roundNumber;
  }
  if (finalRound == null && bracket.rounds.isNotEmpty) {
    // Final henüz kurulmadı: ilk turdaki maç sayısından tur sayısı (2^k).
    final first = bracket.rounds.reduce(
      (a, b) => a.roundNumber <= b.roundNumber ? a : b,
    );
    var matches = first.matches.length;
    var number = first.roundNumber;
    while (matches > 1) {
      matches = (matches + 1) ~/ 2;
      number += 1;
    }
    finalRound = number;
  }

  void touch(String id, String name) {
    if (id.isEmpty) return;
    names[id] = name;
    scores.putIfAbsent(id, () => 0);
    status.putIfAbsent(id, () => 'active');
  }

  // Turlar artan sırayla: final sonucu yarı final galibinin `finalist`ini ezer.
  final ordered = [...bracket.rounds]
    ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
  for (final round in ordered) {
    for (final match in round.matches) {
      touch(match.playerOneId, match.playerOneName);
      touch(match.playerTwoId, match.playerTwoName);
      final p1 = match.playerOneProfile;
      final p2 = match.playerTwoProfile;
      if (p1 != null) profiles[match.playerOneId] = p1;
      if (p2 != null) profiles[match.playerTwoId] = p2;
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
      } else {
        if (loserId.isNotEmpty) status[loserId] = 'eliminated';
        // Finalden önceki turun galibi finale çıktı (final bitince yukarıda
        // `champion`/`finalist` olarak yeniden yazılır; turlar sırayla gezilir).
        if (finalRound != null && round.roundNumber == finalRound - 1) {
          status[match.winnerId] = 'finalist';
        }
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
      profile: profiles[ids[i]],
    ),
  );
}

/// Oda oyuncu satırlarının kararlı sırası: `joined_at` (ISO metin, yoksa en
/// sona), eşitlikte `player_id`. Lobi her cihazda aynı sırada çizilir.
int compareRoomPlayerRows(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aj = DateTime.tryParse(a['joined_at']?.toString() ?? '');
  final bj = DateTime.tryParse(b['joined_at']?.toString() ?? '');
  if (aj != null && bj != null) {
    final byJoin = aj.compareTo(bj);
    if (byJoin != 0) return byJoin;
  } else if (aj != null || bj != null) {
    return aj == null ? 1 : -1;
  }
  return (a['player_id']?.toString() ?? '').compareTo(
    b['player_id']?.toString() ?? '',
  );
}
