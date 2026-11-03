import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/error_reporter.dart';
import 'push_messaging_gateway.dart';

/// Ön planda gelen push iletilerinin uygulama içi yayını.
///
/// Tek yayın akışı iki tüketiciye gider: üstteki bant
/// (`ForegroundPushBanner`) iletiyi gösterir, [AppShell] ilgili sekmenin
/// sayacını/listesini tazeler. Akış olay taşır; son ileti kimlikleri sınırlı
/// bir bellekte tutulur, gönderim tekrarları ikinci bant açmaz.
class ForegroundPushCenter {
  ForegroundPushCenter._();

  static StreamController<ForegroundPush> _controller =
      StreamController<ForegroundPush>.broadcast();
  static StreamSubscription<ForegroundPush>? _subscription;

  static final Set<String> _seenIds = <String>{};
  static const _maxSeenIds = 256;

  static Stream<ForegroundPush> get events => _controller.stream;

  /// Bir iletiyi yayınlar (test ve [wire] kullanır).
  static void emit(ForegroundPush push) {
    if (_controller.isClosed) return;
    final jobId = push.data['job_id'];
    final messageId = push.messageId;
    final key = jobId is String && jobId.trim().isNotEmpty
        ? 'job:$jobId'
        : messageId != null && messageId.trim().isNotEmpty
        ? 'fcm:$messageId'
        : null;
    if (key != null) {
      if (!_seenIds.add(key)) return;
      if (_seenIds.length > _maxSeenIds) _seenIds.remove(_seenIds.first);
    }
    _controller.add(push);
  }

  /// [PushMessaging.gateway]in ön plan iletilerini yayına bağlar. İkinci
  /// çağrı eski aboneliği değiştirir (çift gösterim olmaz).
  static void wire() {
    if (kIsWeb) return;
    try {
      unawaited(_subscription?.cancel());
      _subscription = PushMessaging.gateway.onForegroundMessage.listen(
        emit,
        onError: (Object error, StackTrace stack) => ErrorReporter.record(
          error,
          stack,
          reason: 'foreground push stream',
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'foreground push wiring');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _seenIds.clear();
    unawaited(_controller.close());
    _controller = StreamController<ForegroundPush>.broadcast();
  }
}

/// İki dilli bildirim metnini ("KU · TR") arayüz diline göre böler.
///
/// Sunucu başlığı/gövdeyi `KU · TR` olarak yollar. İki parça çıkarsa dile
/// uygun yarı. Oyuncu adı da " · " içerebilir ("A · B ji te … · A · B sana
/// …"): ad iki yarıda da geçtiğinden parça sayısı ÇİFT olur ve ortadan
/// bölmek doğru yarıları verir. Tek sayıda parça ya da boş yarı varsa
/// (ayrılamaz) metnin tamamı döner.
String splitBilingualPushText(String text, {required bool ku}) {
  final parts = text.split(' · ');
  if (parts.length < 2 || parts.length.isOdd) return text;
  final mid = parts.length ~/ 2;
  final half = (ku ? parts.sublist(0, mid) : parts.sublist(mid))
      .join(' · ')
      .trim();
  return half.isEmpty ? text : half;
}
