import 'package:flutter/widgets.dart';

import '../l10n/strings.dart';
import '../l10n/lang.dart';

/// Oyuncu adının ve baş harfinin TEK kaynağı.
///
/// 2026-07-25 canlı denetimi: aynı oturumda ana ekran "ZanKurd", profil
/// "Lîstikvanê ZanKurd" yazıyordu; avatar da bu yüzden bir ekranda "Z",
/// diğerinde "L" harfini ve farklı rengi gösteriyordu. Ad hem sunucudan
/// gelen Türkçe varsayılanı (`ZanKurd Oyuncusu`) hem de ekran-yerel
/// yedekleri barındırdığı için her ekran kendi yorumunu üretiyordu.
///
/// Kural: sunucudan gelen ad boş ya da bilinen varsayılanlardan biriyse
/// dile göre TEK kelimelik yedek kullanılır (`Lîstikvan` / `Oyuncu`).
/// Baş harf ve renk her zaman [resolveName] sonucundan türetilir.
class PlayerIdentity {
  const PlayerIdentity._();

  /// Sunucu/mock tarafında üretilen, gerçek bir seçim olmayan adlar.
  static const _placeholderNames = <String>{
    'ZanKurd Oyuncusu',
    'Lîstikvanê ZanKurd',
    'ZanKurd',
    'Oyuncu',
    'Lîstikvan',
  };

  /// Gösterilecek adı çözer. Boş/varsayılan adlarda dile göre yedek döner.
  static String resolveName(String? rawName, {required bool isKu}) {
    final name = rawName?.trim() ?? '';
    if (name.isEmpty || _placeholderNames.contains(name)) {
      return Tr.forKu(K.playerWord, isKu);
    }
    return name;
  }

  /// Selamlamada kullanılan kısa ad (ilk kelime).
  static String resolveShortName(String? rawName, {required bool isKu}) {
    final resolved = resolveName(rawName, isKu: isKu);
    final first = resolved.split(RegExp(r'\s+')).first;
    return first.isEmpty ? resolved : first;
  }

  /// Avatar baş harfi — daima [resolveName] sonucundan türetilir.
  static String resolveInitial(String? rawName, {required bool isKu}) {
    final resolved = resolveName(rawName, isKu: isKu);
    return resolved.isEmpty ? '?' : resolved.characters.first.toUpperCase();
  }
}

extension PlayerIdentityContext on BuildContext {
  String playerDisplayName(String? rawName) =>
      PlayerIdentity.resolveName(rawName, isKu: isKu);

  String playerShortName(String? rawName) =>
      PlayerIdentity.resolveShortName(rawName, isKu: isKu);

  String playerInitial(String? rawName) =>
      PlayerIdentity.resolveInitial(rawName, isKu: isKu);
}
