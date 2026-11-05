import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/zankurd_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/repository_holder.dart';
import '../utils/error_reporter.dart';

/// Boot'da çevrimdışı kalan oturumu, sonradan açılan Supabase ile UZAK
/// oturuma geçirir — ağaç tazelenmeden, yalnız depo takasıyla.
///
/// ## Niçin bu işlev var
///
/// Eski kurtarma (`_rebuildWithRemote`) kök widget'ı yeni bir `key` ile
/// yeniden `runApp` ediyordu ve "eski ağaç sökülür" diye-varsayıyordu.
/// Oysa `GlobalKey` durumunda Flutter eski `MaterialApp` elementini
/// ağaç sökmeden geri alır (`FrameworkElement._retakeInactiveElement`);
/// yani rota yığını DEĞİŞMEZ ve açık rotalar eski `OfflineZanKurdRepository`
/// örneğiyle kalırdı. Aynı zamanda yeni bir `AuthProvider` açılıp
/// `signInAnonymously` yoluna düşebiliyordu — bu da misafirin yerel
/// ilerlemesini başka bir oturuma taşımak demekti.
///
/// ## Sözleşme
///
/// 1. **Yeni anonim oturum AÇILMAZ.** [AuthProvider.attachSupabase]
///    cihazda ZATEN kayıtlı kalıcı oturum varsa bağlanır; kayıtlı oturum
///    yoksa yalnız kullanıcı çevrimdışı misafir OLMAMIŞSA oturumsuz
///    bağlanır (G-06: yeni kullanıcı hesap açabilsin); aksi halde hiçbir
///    şey yapmaz ve `false` döner. Böylece kurtarma, çevrimdışı
///    misafiri kendi ilerlemesinden etmez ve `SharedPreferences`
///    silinmez.
/// 2. **Tek takas.** Depo [RepositoryHolder] üzerinden değişir; rota
///    yığını, navigator geçmişi ve açık ekranlar korunur.
/// 3. **Başarısızlık sessiz ve geri alınabilirdir.** Sağlayıcı
///    değiştirilmeden `false` döner; kurtarma kararı
///    (`RemoteAvailability`) geri alınır ve geri çekilmeli yeniden
///    deneme kendi takviminde sürer.
Future<bool> upgradeOfflineBootToRemote({
  required SupabaseClient client,
  required AuthProvider authProvider,
  required RepositoryHolder repositoryHolder,
  required ZanKurdRepository Function(SupabaseClient client) createRepository,
  Future<void> Function(ZanKurdRepository repository)? onRepositoryReady,
}) async {
  // 1. Bağlanılamayacaksa (kayıtlı oturum yok VE çevrimdışı misafir var)
  //    KURTARMA YOK — hiçbir şey kurulmaz, bkz. sözleşmenin 1. maddesi.
  if (!authProvider.canAttachSupabase(client)) return false;

  // 2. Yeni depo örneği — kimlik sağlayıcısı değiştirilmeden ÖNCE.
  //    (2026-11-06, G-04: depo kurulamazsa sağlayıcı yarı geçmiş
  //    [`_offlineMode=false`, istemci bağlı] kalıyordu.)
  final ZanKurdRepository repository;
  try {
    repository = createRepository(client);
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'remote upgrade repository');
    return false;
  }

  // 3. Kimlik sağlayıcısını bağla.
  if (!await authProvider.attachSupabase(client)) return false;

  // Bundan sonraki her başarısızlık bağlamayı GERİ ALIR: yarım geçiş
  // (sağlayıcı uzak, depo/senkron çevrimdışı) hiçbir zaman kalmaz.
  Future<bool> rollBack(Object error, StackTrace stack, String reason) async {
    ErrorReporter.record(error, stack, reason: reason);
    authProvider.detachSupabase(client);
    if (onRepositoryReady != null) {
      try {
        // Senkron yöneticisi başarısız kurulumda boşalmış olabilir:
        // çevrimdışı depoya yeniden bağla.
        await onRepositoryReady(repositoryHolder.repository);
      } catch (restoreError, restoreStack) {
        ErrorReporter.record(
          restoreError,
          restoreStack,
          reason: 'remote upgrade rollback sync',
        );
      }
    }
    return false;
  }

  // 4. Kuyruk yeni depoya aksın (SyncManager aynı örnekte erken döner,
  //    farklıysa eskisini kapatıp yeniden kurar). Kurulamazsa geçiş
  //    BAŞARILI SAYILMAZ (G-07): ödül/ders kuyruğu uzak depoyla
  //    boşalmayacak, kullanıcının ilerlemesi sessizce birikecekti.
  if (onRepositoryReady != null) {
    try {
      await onRepositoryReady(repository);
    } catch (error, stack) {
      return rollBack(error, stack, 'remote upgrade sync init');
    }
  }

  // 5. Yerel ilerleme kapsamını yeni oturuma bağla. Bu çağrı
  //    YALNIZ mevcut oturumun kullanıcısını bağlar; silme yapmaz
  //    (bkz. `AuthProvider._resetLocalProgressIfForeignUser`).
  try {
    await authProvider.bindLocalProgressScope();
  } catch (error, stack) {
    return rollBack(error, stack, 'remote upgrade local progress scope');
  }

  // 6. Tek takas — dinleyiciler (AppShell) bir sonraki çizimde okur.
  repositoryHolder.switchTo(repository);
  return true;
}
