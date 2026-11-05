import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase başlatmasını ÖMÜR BOYU tek future'da tutar ve ulaşılabiliğer
/// yoklamasını (ping) bu başlatmanın ÜSTÜNDE çalıştırır.
///
/// ## Niçin var
///
/// `main()`te başlatma bir kez olur, ama onu bekleyen iki yol vardır:
/// ilk kare kararı (`bootStep`) ve sonradan yapılan probe. Eski düzenle
/// ikinci yol zaman aşımında `Supabase.initialize`ı BİR DAHA çağırıyordu
/// (`_probeSupabase`). `Supabase.initialize` kendi içinde idempotent
/// olsa da, başlatma ilk denemede hata fırlattıysa ikinci deneme aynı
/// hatayı üretir ve `Supabase.instance` hiç kurulmaz — uygulama kalıcı
/// çevrimdışı kalırdı (başlatma hâlâ sürerken ikinci bir çağrı ayrıca
/// "already initialized" düşebilir).
///
/// ## Sözleşme
///
/// * [boot] her zaman AYNI future'ı döndürür; `start` en fazla BİR KEZ
///   çağrılır (senkron fırlatma dâhil — `Future.sync` ile).
/// * [probe] başlatmayı bitirmeyi bekler, başarısız olsa bile ping'i
///   atar. Başlatma patlamışsa ve ping geçerse başlatma BİR KEZ daha
///   denenir (her yoklamada en çok bir); `true` yalnız `Supabase.instance`
///   gerçekten kullanılabilirken döner (2026-11-06, G-03). Ping başarısız
///   ya da yeniden başlatma da patlarsa kilit yerinde kalır.
/// * [probe] AYNI anda çağrılsa da TEK yolculuk başlatır (in-flight
///   paylaşımı). `RemoteAvailability` zaman aşınca denemeyi bırakıp
///   yenisini başlatır; her deneme ayrı bir probe future'ı
///   oluştursa da hepsi bu tek yolculuğu bekler — başlatma bittiğinde
///   sunucuya TEK bir ping gider, onlarca istek değil.
class SupabaseBoot {
  SupabaseBoot({
    required Future<Supabase> Function() start,
    required Future<bool> Function() ping,
  }) : _start = start, // ignore: prefer_initializing_formals
       _ping = ping; // ignore: prefer_initializing_formals

  final Future<Supabase> Function() _start;
  final Future<bool> Function() _ping;

  Future<Supabase>? _boot;

  /// Uçuştaki tek (başlatma + ping) yolculuğu.
  ///
  /// `Future.timeout` yalnız BEKLEYENİN dönmesini bitirir; alttaki
  /// yolculuk yaşamaya devam eder. Bu alan sayesinde bekleyen kaç
  /// deneme olursa olsun başlatma tek kez koşar ve ping tek atılır.
  Future<bool>? _probeInFlight;

  /// Başlatma future'ı — ilk erişimde başlar, sonrakiler aynı future'ı
  /// verir.
  Future<Supabase> get boot {
    final existing = _boot;
    if (existing != null) return existing;
    // `Future.sync`: `start` senkron fırlatsa bile hata bir future'a
    // dönüşür ve ÖMÜR BOYU aynı future'da kalır (yeniden denenmez).
    return _boot = Future<Supabase>.sync(_start);
  }

  /// Başlatmayı bekle (başarısızlığı yut) sonra sunucuya tek hafif
  /// istek at — EŞZAMANLI ÇAĞRILARDA TEK YOLCULUK.
  Future<bool> probe() {
    final running = _probeInFlight;
    if (running != null) return running;
    late final Future<bool> journey;
    journey = _journey().whenComplete(() {
      if (identical(_probeInFlight, journey)) _probeInFlight = null;
    });
    _probeInFlight = journey;
    return journey;
  }

  Future<bool> _journey() async {
    var bootFailed = false;
    try {
      await boot;
    } catch (_) {
      // Başlatma hatası tek başına kararı VERMEZ: önce ping denenir.
      bootFailed = true;
    }
    final reachable = await _ping();
    if (!bootFailed || !reachable) return reachable;
    // G-03: başlatma patlamıştı ama sunucu artık erişilebilir. Başlatma
    // başarılı olmadan "ulaşılabilir" demek, kurtarmayı (`Supabase.instance
    // .client`) ömür boyu başarısız bırakırdı: ping geçer, istemci alınamaz,
    // karar geri alınır, döngü sonsuza dek sürer. `Supabase.initialize`
    // kısmen kurulmuş örnekte "already initialized" ile örneği döndürür,
    // hiç kurulmamışsa baştan dener; ikisi de güvenlidir. Başarısızsa
    // `false` döner ve geri çekilmeli deneme sürer.
    try {
      final retry = _boot = Future<Supabase>.sync(_start);
      await retry;
      return true;
    } catch (_) {
      return false;
    }
  }
}
