import 'dart:io';

class DiscoveredSource {
  const DiscoveredSource({
    required this.path,
    required this.format,
    required this.signal,
  });
  final String path;
  final String format;
  final String signal;
}

List<DiscoveredSource> discoverPotentialQuestionSources(Directory root) {
  final results = <DiscoveredSource>[];
  const supported = {'.csv', '.json', '.sql', '.dart', '.md'};
  final rootPath = root.absolute.path.replaceAll('\\', '/');
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final absolute = entity.absolute.path.replaceAll('\\', '/');
    final relative = absolute
        .substring(rootPath.length)
        .replaceFirst(RegExp(r'^/+'), '');
    final lower = relative.toLowerCase();
    if (_excluded(lower)) continue;
    final dot = lower.lastIndexOf('.');
    final extension = dot < 0 ? '' : lower.substring(dot);
    if (!supported.contains(extension)) continue;
    final pathSignal = RegExp(
      r'(question|soru|pirs|quiz|import|seed|candidate|quarantine|review)',
    ).hasMatch(lower);
    String sample = '';
    if (!pathSignal || extension == '.dart' || extension == '.sql') {
      sample = _sample(entity, 16384).toLowerCase();
    }
    final contentSignal = switch (extension) {
      '.dart' => sample.contains('quizquestion('),
      '.sql' =>
        sample.contains('insert into public.questions') ||
            sample.contains('copy public.questions'),
      '.csv' =>
        sample.contains('prompt') &&
            (sample.contains('correct_option') ||
                sample.contains('correctanswer')),
      '.json' => sample.contains('"prompt"') || sample.contains('"question"'),
      _ => false,
    };
    if (pathSignal || contentSignal) {
      results.add(
        DiscoveredSource(
          path: relative,
          format: extension.replaceFirst('.', ''),
          signal: pathSignal ? 'path' : 'content',
        ),
      );
    }
  }
  results.sort((a, b) => a.path.compareTo(b.path));
  return results;
}

bool _excluded(String path) =>
    path.startsWith('.git/') ||
    path.startsWith('.dart_tool/') ||
    path.startsWith('build/') ||
    path.startsWith('docs/audit/question_quality/') ||
    path.startsWith('test/question_quality/') ||
    path.startsWith('tool/question_quality/') ||
    path.contains('/.tmp/');

String _sample(File file, int limit) {
  try {
    final bytes = file.openSync()..setPositionSync(0);
    try {
      return String.fromCharCodes(bytes.readSync(limit));
    } finally {
      bytes.closeSync();
    }
  } on FileSystemException {
    return '';
  }
}
