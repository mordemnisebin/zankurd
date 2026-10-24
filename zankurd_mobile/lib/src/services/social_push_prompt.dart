import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/error_reporter.dart';
import '../widgets/dialog_action_pair.dart';
import 'push_messaging_gateway.dart';
import 'push_token_sync.dart';

/// Sosyal bir eylemin hemen ardından bildirim iznini ister.
///
/// Arkadaşlık isteği göndermek/kabul etmek, oda kurmak, arkadaşı odaya
/// çağırmak ve düello başlatmak, kullanıcının "karşı taraf cevap verince
/// haber gelsin" dediği anlardır: izin en çok burada anlamlıdır. Eylem
/// çağrı yeri tarafından BAŞARIYLA tamamlandıktan sonra [maybeAsk] çağrılır.
///
/// Kurallar:
/// - İzin zaten verilmişse ya da push bu oturumda kullanılamıyorsa
///   ([PushMessagingGateway.isAvailable]) sormaz.
/// - Açıklama diyaloğu bir kez gösterilir. "Şimdi değil" (ya da diyaloğu
///   kapatmak) en erken 7 gün sonra yeniden sorar.
/// - "Bildirimleri aç" sistem iznini ister. Sistem reddederse bir daha
///   sorulmaz: iOS aynı istemi ikinci kez göstermez, kullanıcı Ayarlar'dan
///   açar.
/// - Aynı oturumda tek soru: sonuç ekranındaki günlük hatırlatıcı kartı
///   ([markPromptedThisSession]) ile bu diyalog birbirini bastırır.
/// - İzin verilince FCM token'ı hemen sunucuya yazılır ([tokenSync]); aksi
///   halde ilk bildirim bir sonraki uygulama açılışına kadar gitmezdi.
class SocialPushPrompt {
  SocialPushPrompt._();

  static const laterAtKey = 'zankurd.socialPushPrompt.laterAt';
  static const doneKey = 'zankurd.socialPushPrompt.done';
  static const cooldown = Duration(days: 7);

  /// İzin verilince token'ı yazan senkronizasyon ([AppShell] bağlar).
  static PushTokenSync? tokenSync;

  static bool _promptedThisSession = false;

  /// Bu oturumda bir bildirim sorusu (bu diyalog ya da sonuç ekranı kartı)
  /// zaten gösterildi mi?
  static bool get promptedThisSession => _promptedThisSession;

  static void markPromptedThisSession() => _promptedThisSession = true;

  /// Şu an sorulabilir mi? (Diyalog göstermez.)
  static Future<bool> shouldAsk({DateTime? now}) async {
    if (_promptedThisSession) return false;
    final gateway = PushMessaging.gateway;
    if (!gateway.isAvailable) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(doneKey) ?? false) return false;
    final laterMs = prefs.getInt(laterAtKey);
    if (laterMs != null) {
      final elapsed = (now ?? DateTime.now()).millisecondsSinceEpoch - laterMs;
      if (elapsed < cooldown.inMilliseconds) return false;
    }
    return !await gateway.hasPermission();
  }

  /// Koşullar uygunsa açıklama diyaloğunu gösterir ve gerekirse sistem
  /// iznini ister. Hiçbir koşulda çağıran akışı bozmaz (hatalar kaydedilir).
  static Future<void> maybeAsk(BuildContext context) async {
    try {
      if (!await shouldAsk()) return;
      if (!context.mounted) return;
      _promptedThisSession = true;
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t(K.socialPushTitle)),
          content: Text(ctx.t(K.socialPushBody)),
          actions: [
            DialogActionPair(
              cancel: TextButton(
                key: const ValueKey('social-push-later'),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.t(K.notifPromptLater)),
              ),
              confirm: FilledButton(
                key: const ValueKey('social-push-enable'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(ctx.t(K.notifPromptEnable)),
              ),
            ),
          ],
        ),
      );
      if (accepted != true) {
        await prefs.setInt(laterAtKey, DateTime.now().millisecondsSinceEpoch);
        return;
      }
      final granted = await PushMessaging.gateway.requestPermission();
      await prefs.setBool(doneKey, true);
      if (granted) await tokenSync?.sync();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'social push prompt');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _promptedThisSession = false;
    tokenSync = null;
  }
}
