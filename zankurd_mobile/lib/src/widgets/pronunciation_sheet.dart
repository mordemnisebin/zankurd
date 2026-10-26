import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/lesson_listening_speaker.dart';
import '../services/pronunciation_recorder.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import 'sahne/sahne.dart';

/// Kendi kaydını çalmak için ince bir arayüz; testler sahte verir.
abstract class PronunciationPlayback {
  Future<void> play(String path);
  Future<void> stop();
  Future<void> dispose();
}

class _AudioplayersPlayback implements PronunciationPlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Telaffuz atölyesi (2026-10-26, ücretsiz): referans sesi dinle, kendi
/// sesini en çok [maxRecording] kaydet, ikisini dinleyip karşılaştır.
///
/// Gizlilik: kayıt yalnız cihazdaki geçici dosyadadır, hiçbir yere
/// gönderilmez; yeni kayıtta ve sayfa kapanınca silinir. Otomatik puanlama
/// yoktur: Kurmancî için güvenilir bir ölçüm kanıtı yok, yanlış "doğru/
/// yanlış" demek öğrenene zarar verir.
class PronunciationSheet extends StatefulWidget {
  const PronunciationSheet({
    required this.text,
    required this.speaker,
    this.recorder,
    this.playback,
    super.key,
  });

  final String text;
  final LessonListeningSpeaker speaker;
  final PronunciationRecorder? recorder;
  final PronunciationPlayback? playback;

  static const maxRecording = Duration(seconds: 4);

  /// Kayıt bu sürede başlamazsa (ses girişi açılmadı) düğme dönmekte
  /// kalmasın: vazgeçilir ve hata söylenir.
  static const startTimeout = Duration(seconds: 5);

  static Future<void> show(
    BuildContext context, {
    required String text,
    required LessonListeningSpeaker speaker,
    PronunciationRecorder? recorder,
    PronunciationPlayback? playback,
  }) {
    return showSahneSheet<void>(
      context: context,
      title: context.t(K.pronunciationTitle),
      builder: (_) => PronunciationSheet(
        text: text,
        speaker: speaker,
        recorder: recorder,
        playback: playback,
      ),
    );
  }

  @override
  State<PronunciationSheet> createState() => _PronunciationSheetState();
}

class _PronunciationSheetState extends State<PronunciationSheet> {
  late final PronunciationRecorder _recorder =
      widget.recorder ?? RecordPronunciationRecorder();
  late final PronunciationPlayback _playback =
      widget.playback ?? _AudioplayersPlayback();

  bool _recording = false;
  bool _busy = false;
  bool _permissionDenied = false;
  bool _startFailed = false;
  String? _path;
  Timer? _autoStop;

  static const _filePrefix = 'zankurd_telaffuz_';

  @override
  void initState() {
    super.initState();
    _sweepStale();
  }

  /// Önceki oturumdan kalan kayıtları siler (uygulama kayıt sırasında
  /// kapatıldıysa dispose hiç çalışmaz). "Kayıt cihazda kalmaz" sözü
  /// yalnız mutlu yolda değil, her yolda tutulsun.
  void _sweepStale() {
    try {
      for (final entity in Directory.systemTemp.listSync()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith(_filePrefix)) {
          entity.deleteSync();
        }
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pronunciation_sweep');
    }
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    if (_recording) {
      unawaited(_recorder.stop().then(_deletePath));
    } else {
      _deletePath(_path);
    }
    unawaited(_recorder.dispose());
    unawaited(_playback.dispose());
    super.dispose();
  }

  /// Kayıt dosyasını siler. Küçük geçici dosya: eşzamanlı silme, sayfa
  /// kapanırken (dispose) beklenmeden de kesin biter.
  Future<void> _deleteCurrent() async => _deletePath(_path);

  void _deletePath(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pronunciation_delete');
    }
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;
    if (_recording) {
      await _stop();
      return;
    }
    setState(() => _busy = true);
    String? pending;
    try {
      final allowed = await _recorder.hasPermission();
      if (!mounted) return;
      if (!allowed) {
        setState(() {
          _permissionDenied = true;
          _busy = false;
        });
        return;
      }
      await _playback.stop();
      await _deleteCurrent();
      final path =
          '${Directory.systemTemp.path}/$_filePrefix'
          '${DateTime.now().microsecondsSinceEpoch}.m4a';
      pending = path;
      await _recorder.start(path).timeout(PronunciationSheet.startTimeout);
      pending = null;
      if (!mounted) return;
      setState(() {
        _permissionDenied = false;
        _startFailed = false;
        _recording = true;
        _busy = false;
        _path = null;
      });
      _autoStop = Timer(PronunciationSheet.maxRecording, _stop);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pronunciation_record');
      // Yarım başlamış kayıt dosyası bırakmasın (simülatörde 2026-10-27
      // zaman aşımından sonra tmp'de 57 KB'lık dosya kaldı).
      if (pending != null) {
        try {
          await _recorder.stop().timeout(const Duration(seconds: 2));
        } catch (_) {}
        _deletePath(pending);
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _startFailed = true;
        });
      }
    }
  }

  Future<void> _stop() async {
    _autoStop?.cancel();
    if (!_recording) return;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _path = path;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pronunciation_stop');
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _playMine() async {
    final path = _path;
    if (path == null || _recording) return;
    try {
      await _playback.play(path);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pronunciation_play');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x2,
        SahneSpace.page,
        SahneSpace.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.text,
            key: const ValueKey('pronunciation-term'),
            style: SahneType.title.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.pronunciationHint),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x4),
          SahneButton.secondary(
            key: const ValueKey('pronunciation-listen'),
            label: context.t(K.lessonListeningPlay),
            icon: AppIcons.volumeHigh,
            expand: true,
            onPressed: () => widget.speaker.speak(widget.text),
          ),
          const SizedBox(height: SahneSpace.x2),
          SahneButton.primary(
            key: const ValueKey('pronunciation-record'),
            label: context.t(_recording ? K.stopAction : K.save),
            icon: AppIcons.microphone,
            arrow: false,
            expand: true,
            loading: _busy,
            onPressed: _busy ? null : _toggleRecording,
          ),
          if (_recording) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.pronunciationRecording),
              key: const ValueKey('pronunciation-recording'),
              style: SahneType.captionStrong.copyWith(color: t.errTx),
            ),
          ],
          const SizedBox(height: SahneSpace.x2),
          SahneButton.secondary(
            key: const ValueKey('pronunciation-play-mine'),
            label: context.t(K.pronunciationPlayMine),
            icon: AppIcons.volumeHigh,
            expand: true,
            onPressed: _path != null && !_recording ? _playMine : null,
          ),
          if (_startFailed) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.genericError),
              key: const ValueKey('pronunciation-start-failed'),
              style: SahneType.bodyStrong.copyWith(color: t.errTx),
            ),
          ],
          if (_permissionDenied) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.pronunciationMicDenied),
              key: const ValueKey('pronunciation-denied'),
              style: SahneType.bodyStrong.copyWith(color: t.errTx),
            ),
          ],
          const SizedBox(height: SahneSpace.x4),
          Text(
            context.t(K.pronunciationPrivacy),
            key: const ValueKey('pronunciation-privacy'),
            style: SahneType.caption.copyWith(color: t.tx3),
          ),
        ],
      ),
    );
  }
}

/// Sözcük kartındaki mikrofon düğmesi. Yalnız referans ses varsa çizilir;
/// yoksa yer kaplamaz (karşılaştırılacak bir şey yoktur).
class PronunciationButton extends StatefulWidget {
  const PronunciationButton({required this.text, this.speaker, super.key});

  final String text;
  final LessonListeningSpeaker? speaker;

  @override
  State<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends State<PronunciationButton> {
  LessonListeningSpeaker? _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = widget.speaker ?? LessonAudio.loaded;
    if (_speaker == null) _load();
  }

  Future<void> _load() async {
    try {
      final speaker = await LessonAudio.shared();
      if (!mounted) return;
      setState(() => _speaker = speaker);
    } catch (_) {
      // Ses yüklenemezse düğme görünmez; hata TtsService'te yazılır.
    }
  }

  @override
  Widget build(BuildContext context) {
    final speaker = widget.speaker ?? _speaker;
    if (speaker == null || !speaker.availableFor(widget.text)) {
      return const SizedBox.shrink();
    }
    return SahneIconButton(
      key: const ValueKey('pronunciation-open'),
      icon: AppIcons.microphone,
      semanticLabel: context.t(K.pronunciationTry),
      onPressed: () =>
          PronunciationSheet.show(context, text: widget.text, speaker: speaker),
    );
  }
}
