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
///    yalnız cihazda ZATEN kayıtlı kalıcı oturum varsa bağlanır; yoksa
///    hiçbir şey yapmaz ve `false` döner. Böylece kurtarma, çevrimdışı
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
  // 1. Oturum yoksa KURTARMA YOK — bkz. sözleşmenin 1. maddesi.
  if (!await authProvider.attachSupabase(client)) return false;

  // 2. Yeni depo örneği.
  final ZanKurdRepository repository;
  try {
    repository = createRepository(client);
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'remote upgrade repository');
    return false;
  }

  // 3. Kuyruk yeni depoya aksın (SyncManager aynı örnekte erken döner,
  //    farklıysa eskisini kapatıp yeniden kurar).
  if (onRepositoryReady != null) {
    try {
      await onRepositoryReady(repository);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'remote upgrade sync init');
    }
  }

  // 4. Yerel ilerleme kapsamını yeni oturuma bağla. Bu çağrı
  //    YALNIZ mevcut oturumun kullanıcısını bağlar; silme yapmaz
  //    (bkz. `AuthProvider._resetLocalProgressIfForeignUser`).
  try {
    await authProvider.bindLocalProgressScope();
  } catch (error, stack) {
    ErrorReporter.record(
      error,
      stack,
      reason: 'remote upgrade local progress scope',
    );
  }

  // 5. Tek takas — dinleyiciler (AppShell) bir sonraki çizimde okur.
  repositoryHolder.switchTo(repository);
  return true;
}
