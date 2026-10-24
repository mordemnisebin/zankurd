import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/error_reporter.dart';
import 'push_messaging_gateway.dart';

/// Ön planda gelen push iletilerinin uygulama içi yayını.
///
/// Tek yayın akışı iki tüketiciye gider: üstteki bant
/// (`ForegroundPushBanner`) iletiyi gösterir, [AppShell] ilgili sekmenin
/// sayacını/listesini tazeler. Global durum yok: akış yalnız olay taşır.
class ForegroundPushCenter {
  ForegroundPushCenter._();

  static StreamController<ForegroundPush> _controller =
      StreamController<ForegroundPush>.broadcast();
  static StreamSubscription<ForegroundPush>? _subscription;

  static Stream<ForegroundPush> get events => _controller.stream;

  /// Bir iletiyi yayınlar (test ve [wire] kullanır).
  static void emit(ForegroundPush push) {
    if (!_controller.isClosed) _controller.add(push);
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
    unawaited(_controller.close());
    _controller = StreamController<ForegroundPush>.broadcast();
  }
}

/// İki dilli bildirim metnini ("KU · TR") arayüz diline göre böler.
///
/// Sunucu başlığı/gövdeyi `KU · TR` olarak yollar. Tam olarak iki yarı
/// çıkarsa dile uygun yarı; ayrılamazsa (ayraç yok ya da ikiden fazla parça)
/// metnin tamamı döner.
String splitBilingualPushText(String text, {required bool ku}) {
  final parts = text.split(' · ');
  if (parts.length != 2) return text;
  final half = (ku ? parts[0] : parts[1]).trim();
  return half.isEmpty ? text : half;
}
