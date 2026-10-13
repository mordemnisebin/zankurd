import 'dart:convert';
import 'dart:io';

const requiredFlutterFrameworkVersion = '3.44.7';

String? releaseToolchainProblem(String actualFrameworkVersion) {
  if (actualFrameworkVersion == requiredFlutterFrameworkVersion) return null;
  return 'Release Flutter sürümü $requiredFlutterFrameworkVersion olmalı; '
      'mevcut sürüm $actualFrameworkVersion.';
}

Future<void> main() async {
  final result = await Process.run('flutter', ['--version', '--machine']);
  if (result.exitCode != 0) {
    stderr.writeln('Flutter sürümü okunamadı.');
    exitCode = 2;
    return;
  }

  final decoded = jsonDecode(result.stdout as String);
  final actual = decoded['frameworkVersion'];
  if (actual is! String || actual.isEmpty) {
    stderr.writeln('Flutter frameworkVersion okunamadı.');
    exitCode = 2;
    return;
  }

  final problem = releaseToolchainProblem(actual);
  if (problem != null) {
    stderr.writeln(problem);
    exitCode = 1;
    return;
  }

  stdout.writeln('Release toolchain geçerli: Flutter $actual.');
}
