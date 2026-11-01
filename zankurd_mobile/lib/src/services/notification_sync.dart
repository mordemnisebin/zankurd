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
      final started = service.pushPrefsSnapshot;
      await service.waitForPushPrefsWrites();
      final sent = service.pushPrefsSnapshot;
      final owner = sent.owner;
      if (owner == null ||
          started.owner != owner ||
          started.generation != sent.generation ||
          repository.currentUserId != owner ||
          repository is OfflineZanKurdRepository) {
        return false;
      }
      // Başarısız ilk gönderim de kalıcı bekler; sahip/oturum değişirse
      // yeni hesabın kuyruğuna dokunulmaz.
      await service.markServerPrefsPending(sent);
      return await service.serializePush(owner, () async {
        if (repository.currentUserId != owner ||
            !service.isCurrentPushPrefs(sent)) {
          return false;
        }
        final ok = await repository.setPushPreferences(
          duel: sent.enabled && sent.duel,
          social: sent.enabled && sent.social,
          expectedUserId: owner,
        );
        if (repository.currentUserId != owner ||
            !service.isCurrentPushPrefs(sent)) {
          return false;
        }
        if (ok) await service.markServerPrefsSynced(sent);
        return ok;
      });
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
      final started = service.pushPrefsSnapshot;
      await service.waitForPushPrefsWrites();
      final requested = service.pushPrefsSnapshot;
      if (requested.owner == null ||
          started.owner != requested.owner ||
          started.generation != requested.generation ||
          repository.currentUserId != requested.owner ||
          repository is OfflineZanKurdRepository) {
        return;
      }
      // Eski sürümün kuyruğa alınmamış kapalı anahtarını da sunucuya taşı.
      if (requested.dirty || !requested.enabled) {
        await push(service, repository);
        return;
      }
      final flags = await repository.loadAccountFlags();
      if (flags == null ||
          repository.currentUserId != requested.owner ||
          !service.isCurrentPushPrefs(requested)) {
        return;
      }
      await service.adoptServerPrefs(
        requested: requested,
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
