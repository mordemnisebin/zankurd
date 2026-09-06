import 'package:flutter/widgets.dart';

/// Web ve paylaşım `https://www.zankurd.com/join/{code}` yolunu açar.
class JoinDeepLink {
  JoinDeepLink._();

  static String? pendingCode;

  static String shareUrl(String code) =>
      'https://www.zankurd.com/join/${code.trim().toUpperCase()}';

  static String? parse(String? route) {
    if (route == null || route.isEmpty || route == '/') return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2 && segs.first == 'join') {
      final code = segs[1].trim().toUpperCase();
      return code.isEmpty ? null : code;
    }
    return null;
  }

  static String? consumeInitialRoute() {
    pendingCode ??= parse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    final code = pendingCode;
    pendingCode = null;
    return code;
  }
}
