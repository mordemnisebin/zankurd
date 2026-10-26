import 'package:record/record.dart';

/// Telaffuz atölyesinin mikrofon kaydı. Testler sahte uygulama verir.
///
/// Kayıt yalnız cihazdaki geçici bir dosyaya yazılır; hiçbir yere
/// gönderilmez. Dosyayı silmek sayfanın işidir (bkz. `PronunciationSheet`).
abstract class PronunciationRecorder {
  /// Mikrofon izni var mı; yoksa sistemden ister.
  Future<bool> hasPermission();

  /// [path]e kaydetmeye başlar.
  Future<void> start(String path);

  /// Kaydı durdurur; yazılan dosyanın yolu (kayıt yoksa `null`).
  Future<String?> stop();

  Future<void> dispose();
}

/// `record` paketiyle gerçek kayıt: tek kanallı AAC (m4a).
class RecordPronunciationRecorder implements PronunciationRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
