import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'package:flutter/widgets.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';

/// Yalnız izin verilmiş last_seen_at varlığı gösterir; eski XP zamanı
/// yedek değildir. Veri gizliyse/yoksa/geçersizse satır boş kalır.
String? friendActivityLabel(BuildContext context, Friend friend) {
  if (friend.isOnline) return context.t(K.online);
  final days = friend.daysSinceActive();
  if (days == null) return null;
  if (days == 0) return context.t(K.friendPlayedToday);
  return context.t(K.friendPlayedDaysAgo, {'n': groupThousands(days)});
}
