import '../data/offline_zankurd_repository.dart';
import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';
import 'notification_service.dart';

/// Bildirim tercihlerinin sunucuyla eşitlenmesi.
///
/// Düello ve arkadaş/oda daveti push'ları SUNUCUDAN gelir; süzgeç
/// `claim_push_outbox`tadır (profiles.push_duel / push_social). Tercih
/// yerelde de tutulur ki ekran çevrimdışıyken de doğru görünsün. Çevrimdışı
/// yapılan değişiklik "kirli" işaretlenir ve bir sonraki açılışta yazılır;
/// kirli değilken sunucudaki değer yerele alınır (başka cihazdaki değişiklik
/// de gelir).
abstract final class PushPrefsSync {
  /// Yerel düello/arkadaş tercihini sunucuya yazar; başarırsa kirli
  /// işaretini kaldırır. Başarıyı döner.
  static Future<bool> push(
    NotificationService service,
    ZanKurdRepository repository,
  ) async {
    try {
      if (repository.currentUserId == null) return false;
      final ok = await repository.setPushPreferences(
        duel: service.duelOn,
        social: service.socialOn,
      );
      if (ok) await service.markServerPrefsSynced();
      return ok;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'push_prefs_push');
      return false;
    }
  }

  /// Kirli yerel değişiklik varsa yazar, yoksa sunucudaki değeri yerele alır.
  static Future<void> reconcile(
    NotificationService service,
    ZanKurdRepository repository,
  ) async {
    try {
      if (repository.currentUserId == null ||
          repository is OfflineZanKurdRepository) {
        return;
      }
      if (service.serverPrefsDirty) {
        await push(service, repository);
        return;
      }
      final flags = await repository.loadAccountFlags();
      if (flags == null) return;
      await service.adoptServerPrefs(
        duel: flags.pushDuel,
        social: flags.pushSocial,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'push_prefs_reconcile');
    }
  }
}

/// Açılışta ve öne gelişte çalışan bildirim eşitlemesi: tercihler + günün
/// yarışması hatırlatması. Servis kurulu değilse (web, test, henüz yüklenmedi)
/// sessizce hiçbir şey yapmaz.
abstract final class NotificationSync {
  static Future<void> run(ZanKurdRepository repository, {DateTime? now}) async {
    final service = NotificationService.instance;
    if (service == null) return;
    await PushPrefsSync.reconcile(service, repository);
    await NotificationService.syncContestReminder(
      contestAvailable: () => _contestToday(repository),
      now: now,
    );
  }

  /// Bugünün yarışması VAR ise true; yok ya da ulaşılamıyorsa `null`
  /// (bilinmiyor). Yokluk "yarışma yok" kanıtı sayılmaz: depo ağ hatasında
  /// da boş döner ve kurulu hatırlatma bir kesinti yüzünden silinmemeli.
  static Future<bool?> _contestToday(ZanKurdRepository repository) async {
    try {
      if (repository is OfflineZanKurdRepository) return null;
      final contest = await repository.loadTodayContest();
      return contest == null ? null : true;
    } catch (_) {
      return null;
    }
  }
}
