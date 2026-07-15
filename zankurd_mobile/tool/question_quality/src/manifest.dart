import 'dart:convert';

import 'models.dart';

class ManifestConflictException implements Exception {
  ManifestConflictException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ManifestResolution {
  const ManifestResolution({required this.source, required this.overlaps});
  final SourceDefinition? source;
  final List<SourceDefinition> overlaps;
  bool get isUnknown => source == null;
}

class SourceManifest {
  const SourceManifest({required this.version, required this.sources});

  factory SourceManifest.fromJsonString(String value) {
    final root = jsonDecode(value) as Map<String, Object?>;
    final sources = (root['sources']! as List<Object?>)
        .map((item) => SourceDefinition.fromJson(item! as Map<String, Object?>))
        .toList();
    return SourceManifest(
      version: (root['version']! as num).toInt(),
      sources: List.unmodifiable(sources),
    );
  }

  final int version;
  final List<SourceDefinition> sources;

  ManifestResolution resolve(String path) {
    final normalized = path.replaceAll('\\', '/');
    final matches = sources.where((source) {
      if (source.path != null) {
        return source.path!.replaceAll('\\', '/') == normalized;
      }
      return _globMatches(source.glob!, normalized);
    }).toList()..sort((a, b) => b.precedence.compareTo(a.precedence));
    if (matches.isEmpty) {
      return const ManifestResolution(source: null, overlaps: []);
    }
    if (matches.length > 1 && matches[0].precedence == matches[1].precedence) {
      throw ManifestConflictException(
        'Equal-precedence source manifest conflict for $normalized: '
        '${matches.where((m) => m.precedence == matches[0].precedence).map((m) => m.id).join(', ')}',
      );
    }
    return ManifestResolution(
      source: matches.first,
      overlaps: matches.skip(1).toList(),
    );
  }
}

bool _globMatches(String pattern, String path) {
  final normalized = pattern.replaceAll('\\', '/');
  final buffer = StringBuffer('^');
  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];
    if (char == '*') {
      final doubleStar = i + 1 < normalized.length && normalized[i + 1] == '*';
      if (doubleStar) {
        i++;
        buffer.write('.*');
      } else {
        buffer.write('[^/]*');
      }
    } else if (char == '?') {
      buffer.write('[^/]');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString()).hasMatch(path);
}
