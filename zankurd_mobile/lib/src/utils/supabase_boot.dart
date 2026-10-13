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
///   atar: karar veren şey artık ağa erişilebilirliktir, başlatma
///   değil. Böylece başlatma patlamış olsa bile sunucu gerçekten
///   erişilebiliyorsa kurtarma yolu açık kalır; tersi (ping başarısız)
///   kilit yerinde kalır.
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
    try {
      await boot;
    } catch (_) {
      // Başlatma hatası kararı VERMEZ; aşağıda ping denenecek.
    }
    return _ping();
  }
}
