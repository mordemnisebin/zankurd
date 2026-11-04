import 'package:zankurd_mobile/src/config/app_config.dart';

/// Yerel-arka uç cihaz testleri anonim kullanıcı, profil, oda ve ödül
/// YAZAR. `--dart-define-from-file` unutulursa `AppConfig.supabaseUrl`
/// gömülü üretim projesine düşer ve test canlı veritabanına yazardı
/// (GPT-6 Pro alan 8 denetimi). Bu koruma, kimlik doğrulamadan ÖNCE adresin
/// yerel/özel ağ olduğunu zorunlu kılar; `*.supabase.co` her koşulda reddedilir.
void requireLocalBackend() {
  final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? '';
  if (!isLocalBackendHost(host)) {
    throw StateError(
      'Bu test yalnız yerel Supabase yığınına karşı koşar; SUPABASE_URL '
      'ana makinesi "$host". --dart-define-from-file=.env.mobile.local.json '
      'ver. Üretim projesine yazılmaz.',
    );
  }
}

/// Yerel geliştirme adresi mi? (loopback, Android emülatör takma adı,
/// özel IPv4 blokları, `.local`/`.localhost`.)
bool isLocalBackendHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty || h.endsWith('.supabase.co') || h.endsWith('.supabase.in')) {
    return false;
  }
  if (h == 'localhost' ||
      h == '127.0.0.1' ||
      h == '::1' ||
      h == '10.0.2.2' ||
      h.endsWith('.localhost') ||
      h.endsWith('.local')) {
    return true;
  }
  final m = RegExp(r'^(\d+)\.(\d+)\.\d+\.\d+$').firstMatch(h);
  if (m == null) return false;
  final a = int.parse(m.group(1)!);
  final b = int.parse(m.group(2)!);
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}
