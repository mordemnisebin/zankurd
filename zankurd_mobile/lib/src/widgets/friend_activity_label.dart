import 'package:flutter/widgets.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';

/// Arkadaş satırının durum sözü: "Çevrimiçi" yalnız son 5 dakikada oynadıysa;
/// yoksa en son ne zaman oynadığı (bkz. [Friend.daysSinceActive]).
String friendActivityLabel(BuildContext context, Friend friend) {
  if (friend.isOnline) return context.t(K.online);
  final days = friend.daysSinceActive();
  if (days == null) return context.t(K.friendNeverPlayed);
  if (days == 0) return context.t(K.friendPlayedToday);
  return context.t(K.friendPlayedDaysAgo, {'n': '$days'});
}
