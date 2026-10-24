import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/lesson_listening_speaker.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Sözlük maddesi ya da kelime balonu için ses düğmesi.
///
/// Yalnız [text] için gerçekten ses varsa (kayıt ya da `ku` TTS) çizilir;
/// yoksa yer kaplamaz, ekran bugünkü hâliyle aynı kalır. Seslendirici
/// yüklenene dek de görünmez. [speaker] verilmezse paylaşılan
/// [LessonAudio] kullanılır.
class LexiconSpeakButton extends StatefulWidget {
  const LexiconSpeakButton({required this.text, this.speaker, super.key});

  final String text;
  final LessonListeningSpeaker? speaker;

  @override
  State<LexiconSpeakButton> createState() => _LexiconSpeakButtonState();
}

class _LexiconSpeakButtonState extends State<LexiconSpeakButton> {
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
      // Ses yüklenemezse düğme yalnız görünmez; hata TtsService'te yazılır.
    }
  }

  @override
  Widget build(BuildContext context) {
    final speaker = widget.speaker ?? _speaker;
    if (speaker == null || !speaker.availableFor(widget.text)) {
      return const SizedBox.shrink();
    }
    return SahneIconButton(
      key: const ValueKey('lexicon-speak'),
      icon: AppIcons.volumeHigh,
      semanticLabel: context.t(K.lessonListeningPlay),
      onPressed: () => speaker.speak(widget.text),
    );
  }
}
