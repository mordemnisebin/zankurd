import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../providers/sound_provider.dart';

/// Haptic (titreşim) geri bildirim yardımcıları.
///
/// Tüm haptics `SoundProvider.enabled` ile birlikte kapatılır — ses kapalıysa
/// titreşim de kapalıdır. Bu, sessiz modda cihazın.ImageLayout unexpectedly
/// titrememesini sağlar (ör. toplantı/okul ortamı).
///
/// Kullanım:
/// ```dart
/// await Haptics.light(context);  // hafif tıklama
/// await Haptics.success(context); // doğru cevap
/// await Haptics.error(context);   // yanlış cevap
/// ```
class Haptics {
  const Haptics._();

  /// Hafif tıklama — butonlara basışta.
  static Future<void> tap(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Bazı platformlarda titreşim donanımı yok — sessizce geç.
    }
  }

  /// Orta düzey — seçim onayı, kart açma.
  static Future<void> medium(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Donanım desteği yok.
    }
  }

  /// Güçlü — rekabet ciddi anları, turnuva açılışı.
  static Future<void> heavy(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Donanım desteği yok.
    }
  }

  /// Başarı geri bildirimi — doğru cevap, rozet kazancı.
  static Future<void> success(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Donanım desteği yok.
    }
  }

  /// Hata geri bildirimi — yanlış cevap, başarısız işlem.
  static Future<void> error(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Donanım desteği yok.
    }
  }

  /// Seçim tekeri — kaydırma/aralarında geçiş.
  static Future<void> selectionClick(SoundProvider? sound) async {
    if (sound == null || !sound.enabled) return;
    if (kIsWeb) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Donanım desteği yok.
    }
  }
}
