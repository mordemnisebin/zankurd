/// Soru görseli kaynağını ağ isteği yapmadan doğrular.
///
/// Uzak URL'nin erişilebilirliğini kanıtlamaz. [allowedHosts] yalnız ayrıca
/// denetlenmiş alan adlarını içerir; varsayılan olarak uzak kaynak yoktur.
String? validateImageReference(
  Object? value, {
  required bool Function(String) assetExists,
  required bool Function(String) assetIsBundled,
  Set<String> allowedHosts = const {},
}) {
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.trim() != value) {
    return 'Görsel kaynağı boş ya da geçersiz türde';
  }
  if (RegExp(r'\s').hasMatch(value)) return 'URL boşluk içeriyor';
  if (value.startsWith('asset://')) {
    final path = value.substring('asset://'.length);
    if (!RegExp(
          r'^assets/[A-Za-z0-9_./-]+\.(webp|png|jpg|jpeg|gif)$',
        ).hasMatch(path) ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      return 'Geçersiz yerel görsel yolu: $value';
    }
    if (!assetExists(path)) return 'Görsel dosyası yok: $path';
    if (!assetIsBundled(path)) return 'Görsel pakete bildirilmemiş: $path';
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      uri.hasFragment ||
      uri.path.isEmpty ||
      uri.path.endsWith('/')) {
    return 'Geçersiz HTTPS görsel URL biçimi: $value';
  }
  if (!allowedHosts.contains(uri.host)) {
    return 'Onaylanmamış görsel alan adı: ${uri.host}';
  }
  return null;
}

/// JSON dışa aktarımı ve yeni alan adları da aynı bekçiden geçer.
/// Bilinen görsel alanları dışında kalan düz asset yolları kanonikleştirilir.
Iterable<({String id, Object? value})> questionImageReferences(
  Object? data, {
  String id = '',
}) sync* {
  if (data is Map) {
    final owner = data['id']?.toString() ?? id;
    for (final entry in data.entries) {
      if (entry.key == 'imageUrl' || entry.key == 'image_url') {
        yield (id: owner, value: entry.value);
      } else {
        yield* questionImageReferences(entry.value, id: owner);
      }
    }
  } else if (data is List) {
    for (final item in data) {
      yield* questionImageReferences(item, id: id);
    }
  } else if (data is String) {
    if (data.startsWith('asset://')) {
      yield (id: id, value: data);
    } else if (data.startsWith('assets/')) {
      yield (id: id, value: 'asset://$data');
    }
  }
}
