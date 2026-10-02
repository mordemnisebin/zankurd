import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import 'error_reporter.dart';

/// Uygulama dışına açılan her bağlantının tek kapısı.
///
/// ## Niçin ortak
///
/// `launchUrl` iki ayrı yoldan sessizce başarısız olur ve ikisi de kolay
/// kaçırılır:
///
/// 1. Cihazda o şemayı açacak bir uygulama yoksa **istisna fırlatmaz**,
///    yalnız `false` döner. Dönen değer okunmazsa dokunuş hiçbir şey yapmaz.
/// 2. `Uri.parse` bozuk bir adreste fırlatır. `try` yoksa dokunuş çöker.
///
/// Bu kusur 2026-08-14'te yasal bağlantılarda bulunup düzeltildi, ama
/// düzeltme `LegalLinksRow`un içinde özel bir metot olarak kaldı. 2026-08-17
/// taramasında aynı kusurun ikinci örneği çıktı: görsel künye ekranındaki
/// kaynak bağlantısı `launchUrl`ı `await` etmeden, dönen değeri okumadan ve
/// hiçbir `try` olmadan çağırıyordu. Künye bir lisans metnidir — CC
/// görsellerin atfı çalışan bir kaynak bağlantısı ister; ölü bağlantı atfı
/// zayıflatır.
///
/// İki örnek bir desendir; üçüncüsü olmasın diye düzeltme buraya taşındı.
/// Çağıranın hiçbir şeyi hatırlaması gerekmiyor: başarısızlık her iki yolda
/// da aynı görünür SnackBar'a çıkar, istisna ayrıca telemetriye gider.
Future<void> openExternalLink(
  BuildContext context,
  String url, {
  String reason = 'external link',
}) async {
  final failed = context.t(K.linkOpenFailed);
  final Uri uri;
  try {
    // Ayrıştırma çağrının İÇİNDE: künye adresleri bir asset dosyasından
    // gelir ve oradaki tek bozuk satır dokunuşu çökertmemeli.
    uri = Uri.parse(url);
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: '$reason (parse): $url');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  await openExternalUri(context, uri, reason: reason);
}

/// Adresi hazır olan çağıranlar için ([openExternalLink]'in Uri hâli).
///
/// `mailto:` bağlantıları böyle kurulur: konu/gövde parametreleri
/// [AppConfig] içinde `Uri` olarak üretilir ve dizeye çevirip yeniden
/// ayrıştırmak kaçış kurallarını bozabilir.
Future<void> openExternalUri(
  BuildContext context,
  Uri uri, {
  String reason = 'external link',
}) async {
  final failed = context.t(K.linkOpenFailed);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed)));
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: '$reason: $uri');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed)));
  }
}
