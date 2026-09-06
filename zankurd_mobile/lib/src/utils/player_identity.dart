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

  /// Gösterilen ad yer tutucu mu? Avatar harfi O/L 0 gibi okunmasın.
  static bool isPlaceholderDisplayName(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty || _placeholderNames.contains(trimmed);
  }

  /// Avatar baş harfi — daima [resolveName] sonucundan türetilir.
  static String resolveInitial(String? rawName, {required bool isKu}) {
    final resolved = resolveName(rawName, isKu: isKu);
    return resolved.isEmpty ? '?' : resolved.characters.first.toUpperCase();
  }

  /// Avatar renginin DİLDEN BAĞIMSIZ tohumu.
  ///
  /// ## Kusur
  ///
  /// 2026-08-10'da simülatörde görüldü: dili değiştiren oyuncunun avatar
  /// rengi turuncudan maviye dönüyordu. Sebep bu sınıfın kendi kuralıydı —
  /// "renk daima `resolveName` sonucundan türetilir". `resolveName` yer
  /// tutucu adlarda dile göre farklı bir metin döndürüyor («Oyuncu» /
  /// «Lîstikvan»), renk de isim hash'inden geldiği için birlikte kayıyordu.
  ///
  /// Baş harf ile renk burada AYRILIYOR ve bu bilinçli: harf bir etikettir,
  /// gösterilen adı izlemeli — adı «Oyuncu» yazarken «L» göstermek daha
  /// kötü olurdu. Renk ise kimliktir ve dil değiştirince oynamamalı.
  ///
  /// Adını gerçekten seçmiş oyuncu zaten etkilenmiyordu (ad dilden bağımsız);
  /// kusur yalnız ad kapısını atlayanlarda görünüyordu. Tohum orada sabit
  /// bir dizeye düşer, yani o oyuncuların hepsi aynı rengi paylaşır — dil
  /// değiştikçe renk değiştirmesinden iyidir.
  static String resolveColorSeed(String? rawName) {
    final name = rawName?.trim() ?? '';
    if (name.isEmpty || _placeholderNames.contains(name)) {
      return _defaultColorSeed;
    }
    return name;
  }

  /// Yer tutucu adlı oyuncuların ortak renk tohumu. Değeri anlamlı değil;
  /// yalnız SABİT olması önemli.
  static const _defaultColorSeed = 'zankurd.player.default';
}

extension PlayerIdentityContext on BuildContext {
  String playerDisplayName(String? rawName) =>
      PlayerIdentity.resolveName(rawName, isKu: isKu);

  String playerShortName(String? rawName) =>
      PlayerIdentity.resolveShortName(rawName, isKu: isKu);

  String playerInitial(String? rawName) =>
      PlayerIdentity.resolveInitial(rawName, isKu: isKu);
}
