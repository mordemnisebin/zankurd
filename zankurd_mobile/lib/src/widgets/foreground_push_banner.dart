import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/foreground_push_center.dart';
import '../services/push_messaging_gateway.dart';
import '../services/push_tap_router.dart';

/// Uygulama açıkken gelen push'u üstte kısa bir bant olarak gösterir.
///
/// Sistem, ön plandaki uygulamaya bildirimi kendiliğinden göstermez; bu bant
/// o boşluğu kapatır (iOS'ta ayrıca `setForegroundNotificationPresentationOptions`
/// AÇILMAZ: sistem afişi + bant çift gösterim olurdu). Metin "KU · TR"
/// biçiminde gelir; arayüz diline göre ayrılır. "Aç", dokunuşla AYNI hedefe
/// [PushTapRouter.offer] üzerinden götürür.
class ForegroundPushBanner extends StatefulWidget {
  const ForegroundPushBanner({
    required this.child,
    this.events,
    this.visibleFor = const Duration(seconds: 6),
    super.key,
  });

  final Widget child;

  /// Test için akış; varsayılan [ForegroundPushCenter.events].
  final Stream<ForegroundPush>? events;
  final Duration visibleFor;

  @override
  State<ForegroundPushBanner> createState() => _ForegroundPushBannerState();
}

class _ForegroundPushBannerState extends State<ForegroundPushBanner> {
  StreamSubscription<ForegroundPush>? _subscription;
  ForegroundPush? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _subscription = (widget.events ?? ForegroundPushCenter.events).listen(
      _onPush,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _onPush(ForegroundPush push) {
    final hasText =
        (push.title?.trim().isNotEmpty ?? false) ||
        (push.body?.trim().isNotEmpty ?? false);
    // Yalnız veri taşıyan ileti (görünür metni yok) bant açmaz.
    if (!hasText || !mounted) return;
    _timer?.cancel();
    setState(() => _current = push);
    _timer = Timer(widget.visibleFor, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted && _current != null) setState(() => _current = null);
  }

  void _open(ForegroundPush push) {
    _dismiss();
    PushTapRouter.offer(push.data);
  }

  @override
  Widget build(BuildContext context) {
    final push = _current;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        if (push != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _Banner(
              key: const ValueKey('foreground-push-banner'),
              push: push,
              onOpen: () => _open(push),
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.push,
    required this.onOpen,
    required this.onDismiss,
    super.key,
  });

  final ForegroundPush push;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  String? _localized(BuildContext context, String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return splitBilingualPushText(text, ku: context.isKu);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _localized(context, push.title);
    final body = _localized(context, push.body);
    final canOpen = PushTapRouter.targetForKind(push.kind) != null;
    final textColor = scheme.onInverseSurface;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (body != null)
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                  ],
                ),
              ),
              if (canOpen)
                TextButton(
                  key: const ValueKey('foreground-push-open'),
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.inversePrimary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(context.t(K.pushBannerOpen)),
                ),
              // Tooltip yok: bant `MaterialApp.builder`da, Navigator'ın
              // Overlay'inin ÜSTÜNDE durur; Tooltip Overlay arar ve düşerdi.
              Semantics(
                label: context.t(K.pushBannerDismiss),
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  key: const ValueKey('foreground-push-dismiss'),
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, color: textColor, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
