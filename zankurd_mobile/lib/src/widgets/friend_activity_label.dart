import 'package:flutter/widgets.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';

/// Arkadaş satırının durum sözü: "Çevrimiçi" yalnız son 5 dakikada etkinse;
/// yoksa en son ne zaman etkin olduğu (bkz. [Friend.daysSinceActive]).
///
/// Etkinlik zamanı BİLİNMİYORSA `null` döner ve satırda hiçbir şey yazmaz.
/// Kurul 1 (C22/C35, 2026-10-29): `last_active_at` = `profiles.updated_at`
/// ve bu alan her oyunda güncellenmiyor (ör. misafir hesap az önce çok oyun
/// oynadığı hâlde boş geldi); "Henüz oynamadı" demek yanlış bir iddiaydı.
/// Alan oyun dışında da (ad değişikliği) değiştiği için söz "oynadı" değil
/// "etkin" der.
String? friendActivityLabel(BuildContext context, Friend friend) {
  if (friend.isOnline) return context.t(K.online);
  final days = friend.daysSinceActive();
  if (days == null) return null;
  if (days == 0) return context.t(K.friendPlayedToday);
  return context.t(K.friendPlayedDaysAgo, {'n': '$days'});
}
