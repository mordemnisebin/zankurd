import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'progress_sync.dart';

import '../services/notification_service.dart';
import '../utils/error_reporter.dart';

/// Günlük oyun serisini (streak) yerelde izler.
///
/// Kurallar: gün yerel saate göre hesaplanır; aynı gün içinde ikinci
/// oyun seriyi artırmaz; bir gün atlanırsa seri 1'den başlar. En iyi
/// seri ayrıca saklanır. SharedPreferences yoksa bellek-içi çalışır.
class StreakStore {
  StreakStore._(
    this._preferences,
    this._current,
    this._best,
    this._lastDay,
    this._freeze,
    this._playedDays,
    this._frozenDays,
    this._repairMonth,
    this._lostValue,
    this._lostLastDay,
    this._offerSeenFor,
    this._firstSeen,
  ) {
    // Takvim geçmişi bu sürümde eklendi: eski kurulumda yalnız son gün var.
    final last = _lastDay;
    if (last != null && !_playedDays.contains(last)) _playedDays.add(last);
  }

  static String get _currentKey =>
      LocalProgressScope.physical('zankurd.streak.current');
  static String get _bestKey =>
      LocalProgressScope.physical('zankurd.streak.best');
  static String get _lastDayKey =>
      LocalProgressScope.physical('zankurd.streak.lastDay');
  static String get _freezeKey =>
      LocalProgressScope.physical('zankurd.streak.freeze');

  /// Jeton sayısının son değiştiği an; eşitleme en yeniyi seçer
  /// (bkz. `SnapshotStreak.merge`).
  static String get _freezeAtKey =>
      LocalProgressScope.physical('zankurd.streak.freezeAt');
  // Takvim geçmişi ve onarım durumu (2026-10-24). `zankurd.streak.` öneki
  // [LocalProgressScope.prefixes]te olduğundan kullanıcı kapsamına ve eski
  // kurulum taşımasına kendiliğinden girer.
  static String get _playedDaysKey =>
      LocalProgressScope.physical('zankurd.streak.playedDays');
  static String get _frozenDaysKey =>
      LocalProgressScope.physical('zankurd.streak.frozenDays');
  static String get _repairMonthKey =>
      LocalProgressScope.physical('zankurd.streak.repairMonth');
  static String get _lostValueKey =>
      LocalProgressScope.physical('zankurd.streak.lostValue');
  static String get _lostLastDayKey =>
      LocalProgressScope.physical('zankurd.streak.lostLastDay');
  static String get _firstSeenKey =>
      LocalProgressScope.physical('zankurd.streak.firstSeen');
  static String get _offerSeenKey =>
      LocalProgressScope.physical('zankurd.streak.repairOfferSeenFor');

  /// Takvimde tutulan en fazla gün sayısı (≈ 13 ay); sonsuz büyümesin.
  static const maxHistoryDays = 400;

  /// Seri onarımının jeton bedeli (sunucudaki `spend_streak_repair` ile
  /// aynı; bekçi: `streak_repair_contract_test.dart`).
  static const repairCost = 100;

  /// Aynı anda tutulabilecek en fazla dondurma jetonu.
  static const maxFreeze = 2;
  static StreakStore? _instance;
  static Future<StreakStore>? _loading;
  static int _loadGeneration = 0;

  static Future<StreakStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh().then((store) {
      if (_loadGeneration == generation) {
        return _instance ??= store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<StreakStore> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_store');
      preferences = null;
    }
    return StreakStore._(
      preferences,
      preferences?.getInt(_currentKey) ?? 0,
      preferences?.getInt(_bestKey) ?? 0,
      preferences?.getString(_lastDayKey),
      preferences?.getInt(_freezeKey) ?? 0,
      preferences?.getStringList(_playedDaysKey)?.toSet() ?? <String>{},
      preferences?.getStringList(_frozenDaysKey)?.toSet() ?? <String>{},
      preferences?.getString(_repairMonthKey),
      preferences?.getInt(_lostValueKey) ?? 0,
      preferences?.getString(_lostLastDayKey),
      preferences?.getString(_offerSeenKey),
      preferences?.getString(_firstSeenKey),
    );
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  final SharedPreferences? _preferences;
  int _current;
  int _best;
  String? _lastDay;
  int _freeze;
  final Set<String> _playedDays;
  final Set<String> _frozenDays;
  String? _repairMonth;
  int _lostValue;
  String? _lostLastDay;
  String? _offerSeenFor;
  String? _firstSeen;

  int get best => _best;
  String? get lastDay => _lastDay;

  /// Elde tutulan dondurma jetonu sayısı (0..[maxFreeze]).
  int get freezeCount => _freeze;

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Takvim günü aritmetiği: `now.subtract(24 saat)` yaz/kış saati
  /// geçişinde günü kaçırır (saat ileri alınan gecenin ertesi sabahı 24 saat
  /// önce, iki gün önceye düşebilir) ve seri sessizce kırılırdı.
  /// `DateTime(y, m, d - 1)` yerel takvimde gün sayar, saat farkından
  /// etkilenmez.
  static bool _isYesterday(String lastDay, DateTime now) {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return lastDay == _dayKey(yesterday);
  }

  /// Bugün (yerel takvim günü) zaten oynandı mı?
  bool playedToday({DateTime? now}) =>
      _lastDay == _dayKey(now ?? DateTime.now());

  /// [lastDay] bugünden SONRA mı? Cihaz saati geri alınınca ya da saat
  /// dilimi batıya kayınca kayıtlı gün gelecekte kalır. Anahtarlar
  /// `yyyy-MM-dd` olduğundan sözlük sırası takvim sırasıdır. Böyle bir gün
  /// "bugün" sayılır; yoksa seri hiç atlanmamış bir günden dolayı kırılırdı
  /// (bkz. test/streak_clock_backward_test.dart).
  static bool _isFuture(String lastDay, DateTime now) =>
      lastDay.compareTo(_dayKey(now)) > 0;

  /// Görünen seri: bugün ya da dün oynanmışsa sürer, yoksa 0'dır.
  int effectiveStreak({DateTime? now}) {
    final today = now ?? DateTime.now();
    final lastDay = _lastDay;
    if (lastDay == null) return 0;
    if (lastDay == _dayKey(today) ||
        _isYesterday(lastDay, today) ||
        _isFuture(lastDay, today)) {
      return _current;
    }
    return 0;
  }

  /// Şu an oynanırsa mevcut bir serinin (>0) kırılıp kırılmayacağını söyler.
  /// Yani seri sürüyordu ama bir (veya daha fazla) gün atlandı.
  bool willBreakOnPlay({DateTime? now}) {
    final today = now ?? DateTime.now();
    final lastDay = _lastDay;
    if (lastDay == null || _current <= 0) return false;
    return lastDay != _dayKey(today) &&
        !_isYesterday(lastDay, today) &&
        !_isFuture(lastDay, today);
  }

  /// Kırılacak seri elde jeton varken dondurulabilir mi?
  bool canFreeze({DateTime? now}) => _freeze > 0 && willBreakOnPlay(now: now);

  /// Bir dondurma jetonu ekler (mağaza alımı). Üst sınır [maxFreeze].
  Future<int> addFreeze() async {
    if (_freeze >= maxFreeze) return _freeze;
    _freeze += 1;
    await _stampFreeze();
    await _persist();
    return _freeze;
  }

  /// Bir jeton harcayarak seriyi korur ve bugünkü oyunu işler.
  /// Atlanan gün(ler) köprülenir; seri +1 devam eder. Jeton yoksa ya da
  /// seri zaten kırılmayacaksa normal [recordPlay] davranışına düşer.
  Future<int> freezeAndRecordPlay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    if (!canFreeze(now: today)) {
      return recordPlay(now: today);
    }
    _freeze -= 1;
    await _stampFreeze();
    _current += 1;
    if (_current > _best) _best = _current;
    _markBridgedDays(_lastDay, today);
    _lastDay = _dayKey(today);
    _playedDays.add(_lastDay!);
    await _persist();
    await NotificationService.noteStreakActivity();
    return _current;
  }

  /// Quiz sonucu dışındaki oyun anları (ders bitirme, sırayla düello turu)
  /// için seriyi işler; hata oyunu bozmaz, yalnız raporlanır.
  ///
  /// Seri eskiden yalnız quiz sonuç ekranından yazılıyordu: her gün yalnız
  /// ders bitiren ya da düello oynayan oyuncunun serisi sıfırlanıyor, akşam
  /// "Bugün hiç oynamadın" uyarısı da yanlış yere gidiyordu (2026-10-16).
  static Future<void> recordActivity() async {
    try {
      final store = await StreakStore.load();
      await store.recordPlay();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_record_activity');
    }
  }

  /// Tamamlanan bir oyunu işler ve güncel seriyi döner.
  Future<int> recordPlay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = _dayKey(today);
    final lastDay = _lastDay;
    await markFirstSeen(now: today);

    if (lastDay == todayKey) {
      if (_playedDays.add(todayKey)) {
        try {
          await _persist();
        } catch (_) {
          _playedDays.remove(todayKey);
          rethrow;
        }
      }
      // Bugün zaten işlenmişti; uyarı o zaman susturuldu. Yine de ucuzdur ve
      // uyarının sonradan (bildirim açılınca) bugüne kurulmuş olmasına karşı
      // güvenceyi korur.
      await NotificationService.noteStreakActivity();
      return _current;
    }
    if (lastDay != null && _isFuture(lastDay, today)) {
      // Saat geri alınmış: seri korunur ve `lastDay` ASLA geriye taşınmaz.
      // Geriye yazmak 24→23→24'te aynı gerçek günde seriyi iki kez
      // artırır, 24→22→24'te kırardı (bkz. test/streak_clock_backward_test).
      return _current;
    }
    if (lastDay != null && _isYesterday(lastDay, today)) {
      _current += 1;
    } else {
      // Seri kırıldı: değeri onarım için sakla (son 24 saatte geri alınabilir).
      if (lastDay != null && _current > 0) {
        _lostValue = _current;
        _lostLastDay = lastDay;
      }
      _current = 1;
    }
    if (_current > _best) _best = _current;
    _lastDay = todayKey;
    _playedDays.add(todayKey);
    await _persist();
    await NotificationService.noteStreakActivity();
    return _current;
  }

  // ── Takvim ──────────────────────────────────────────────────────────

  /// Oynanan günlerin anahtarları (`yyyy-MM-dd`), değiştirilemez görünüm.
  Set<String> get playedDays => Set.unmodifiable(_playedDays);

  /// Dondurma ya da onarımla korunan günler.
  Set<String> get frozenDays => Set.unmodifiable(_frozenDays);

  /// Bilinen en eski oynanmış gün; öncesi takvimde boş bırakılır (veri
  /// yokken "kaçırdı" uydurulmaz).
  String? get firstDay {
    if (_playedDays.isEmpty) return null;
    return _playedDays.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  }

  /// Bu kullanıcının uygulamayı ilk gördüğü gün (`yyyy-MM-dd`); yoksa null.
  String? get firstSeenDay => _firstSeen;

  /// İlk görülen günü bir kez yazar (varsa dokunmaz).
  ///
  /// Yeni hesapta takvimin geçmiş günleri "kaçırıldı ✕" çiziliyordu: hiç
  /// oynamamış kişiye ayın önceki günleri için başarısızlık işareti hem
  /// yanlış hem moral bozucu. Oyun/yükleme günü bu kayıtla sınır olur.
  Future<void> markFirstSeen({DateTime? now}) async {
    if (_firstSeen != null) return;
    _firstSeen = _dayKey(now ?? DateTime.now());
    await _persist();
  }

  /// Takvimde "kaçırıldı" sayılabilecek ilk gün: ilk görülen gün ile en
  /// eski oynanan günden eskisi; ikisi de yoksa null (hepsi boş).
  String? get _missedFrom {
    final a = _firstSeen;
    final b = firstDay;
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) <= 0 ? a : b;
  }

  /// Verilen günün takvim işareti. Saf okuma; saat [now] ile enjekte edilir.
  StreakCalendarMark markFor(DateTime day, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final key = _dayKey(day);
    final todayKey = _dayKey(today);
    if (key == todayKey) {
      return _playedDays.contains(key)
          ? StreakCalendarMark.played
          : StreakCalendarMark.today;
    }
    if (key.compareTo(todayKey) > 0) return StreakCalendarMark.upcoming;
    if (_playedDays.contains(key)) return StreakCalendarMark.played;
    if (_frozenDays.contains(key)) return StreakCalendarMark.frozen;
    final first = _missedFrom;
    if (first != null && key.compareTo(first) >= 0) {
      return StreakCalendarMark.missed;
    }
    return StreakCalendarMark.blank;
  }

  /// Dondurmayla köprülenen günleri (son oynanan ile bugün arası) işaretler.
  void _markBridgedDays(String? lastDay, DateTime today) {
    if (lastDay == null) return;
    final from = DateTime.tryParse(lastDay);
    if (from == null) return;
    var day = DateTime(from.year, from.month, from.day + 1);
    final end = DateTime(today.year, today.month, today.day);
    var guard = 0;
    while (day.isBefore(end) && guard++ < 31) {
      _frozenDays.add(_dayKey(day));
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }

  // ── Seri onarımı ────────────────────────────────────────────────────

  /// Ay anahtarı (`yyyy-MM`): onarım hakkı ve sunucu tekilliği bununla.
  static String monthKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}';

  /// Şu an sunulabilecek onarım; yoksa null.
  ///
  /// Kural: seri SON 24 SAATTE kırıldı (son oynanan gün = iki gün önce, yani
  /// kırılma bu sabah gece yarısı), değeri en az 2 gün, bu takvim ayında
  /// onarım hakkı kullanılmamış. İki durum vardır: bugün henüz oynanmadı
  /// (değer `_current`te durur) ya da bugün oynandı ve seri 1'e düştü (değer
  /// [recordPlay]in sakladığı `_lostValue`da).
  StreakRepairOffer? repairOffer({DateTime? now}) {
    final today = now ?? DateTime.now();
    if (_repairMonth == monthKey(today)) return null;
    final lastDay = _lastDay;
    if (lastDay == null) return null;
    final twoAgo = _dayKey(DateTime(today.year, today.month, today.day - 2));
    final todayKey = _dayKey(today);
    int lost;
    String breakDay;
    bool playedToday;
    // Kırılan gün = kaçırılan gün (dün). Sunucu bunu bugünden en çok 1 gün
    // önce kabul eder (24 saat kuralı) ve ayı kendi saatiyle belirler.
    breakDay = _dayKey(DateTime(today.year, today.month, today.day - 1));
    if (lastDay == twoAgo && _current > 0) {
      lost = _current;
      playedToday = false;
    } else if (lastDay == todayKey &&
        _lostLastDay == twoAgo &&
        _lostValue > 0) {
      lost = _lostValue;
      playedToday = true;
    } else {
      return null;
    }
    if (lost < 2) return null;
    return StreakRepairOffer(
      lostStreak: lost,
      breakDay: breakDay,
      monthKey: monthKey(today),
      playedToday: playedToday,
    );
  }

  /// Bu kırılma için açılış sayfası daha önce gösterildi mi?
  bool repairOfferSeen(StreakRepairOffer offer) =>
      _offerSeenFor == offer.breakDay;

  /// Açılış sayfasını bu kırılma için bir daha gösterme.
  Future<void> markRepairOfferSeen(StreakRepairOffer offer) async {
    _offerSeenFor = offer.breakDay;
    await _persist();
  }

  /// Sunucu onarımı onayladıktan SONRA seriyi geri yükler ve hakkı işler.
  ///
  /// Aradaki (kaçırılan) gün dondurulmuş sayılır; seri kırılmamış gibi
  /// sürer. Hak işlendiği için [repairOffer] bu ay artık null döner.
  Future<int> applyRepair(StreakRepairOffer offer, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    _frozenDays.add(_dayKey(yesterday));
    if (offer.playedToday) {
      _current = offer.lostStreak + 1;
      _lastDay = _dayKey(today);
    } else {
      _current = offer.lostStreak;
      _lastDay = _dayKey(yesterday);
    }
    if (_current > _best) _best = _current;
    _repairMonth = offer.monthKey;
    _lostValue = 0;
    _lostLastDay = null;
    _offerSeenFor = offer.breakDay;
    await _persist();
    // Uyarıyı yeni duruma göre kur (bugün oynandıysa yarına).
    await NotificationService.syncStreakWarning(now: today);
    return _current;
  }

  Future<void> _stampFreeze() async {
    await _preferences?.setInt(
      _freezeAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setInt(_currentKey, _current);
    await preferences.setInt(_bestKey, _best);
    await preferences.setInt(_freezeKey, _freeze);
    final lastDay = _lastDay;
    if (lastDay != null) {
      await preferences.setString(_lastDayKey, lastDay);
    }
    await preferences.setStringList(_playedDaysKey, _trimmed(_playedDays));
    await preferences.setStringList(_frozenDaysKey, _trimmed(_frozenDays));
    await _setOrRemove(preferences, _repairMonthKey, _repairMonth);
    await _setOrRemove(preferences, _lostLastDayKey, _lostLastDay);
    await _setOrRemove(preferences, _offerSeenKey, _offerSeenFor);
    await _setOrRemove(preferences, _firstSeenKey, _firstSeen);
    await preferences.setInt(_lostValueKey, _lostValue);
    ProgressSyncService.markDirty();
  }

  static Future<void> _setOrRemove(
    SharedPreferences preferences,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  /// En yeni [maxHistoryDays] gün, sıralı (anahtarlar `yyyy-MM-dd`).
  static List<String> _trimmed(Set<String> days) {
    final sorted = days.toList()..sort();
    return sorted.length <= maxHistoryDays
        ? sorted
        : sorted.sublist(sorted.length - maxHistoryDays);
  }

  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [
      _currentKey,
      _bestKey,
      _lastDayKey,
      _freezeKey,
      _freezeAtKey,
      _playedDaysKey,
      _frozenDaysKey,
      _repairMonthKey,
      _lostValueKey,
      _lostLastDayKey,
      _offerSeenKey,
      _firstSeenKey,
    ]);
    _current = 0;
    _best = 0;
    _lastDay = null;
    _freeze = 0;
    _playedDays.clear();
    _frozenDays.clear();
    _repairMonth = null;
    _lostValue = 0;
    _lostLastDay = null;
    _offerSeenFor = null;
    _firstSeen = null;
  }
}

/// Takvimdeki bir günün durumu. Renk tek kanal değildir: oynanan dolu
/// turuncu, dondurulan mavi, kaçırılan kesik çizgi (bkz. StreakCalendar).
enum StreakCalendarMark { played, frozen, missed, today, upcoming, blank }

/// Sunulabilir seri onarımı: ne kaybedildi, hangi gün kırıldı, hangi ay.
class StreakRepairOffer {
  const StreakRepairOffer({
    required this.lostStreak,
    required this.breakDay,
    required this.monthKey,
    required this.playedToday,
  });

  /// Geri alınacak seri değeri.
  final int lostStreak;

  /// Kaçırılan (kırılan) gün, dün (`yyyy-MM-dd`); sunucu tekilliği.
  final String breakDay;

  /// Onarım hakkının ayı (`yyyy-MM`); idempotency anahtarı parçası.
  final String monthKey;

  /// Bugün oynandı mı (seri 1'e düşmüştü; onarım `lostStreak + 1` yapar).
  final bool playedToday;

  /// Onarım sonrası seri değeri.
  int get restoredStreak => playedToday ? lostStreak + 1 : lostStreak;
}
