import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/sound_provider.dart';
import 'app_haptics.dart';

/// Cevap anının ses + dokunsal geri bildirimi — ana soru ekranıyla aynı
/// (`QuizScreen`: doğruda orta titreşim + `playCorrect`, yanlışta titreşim +
/// `playWrong`).
///
/// Kapışma U18 (2026-10-29): sırayla düello ve seviye sınavı cevapta hiç ses
/// ve titreşim vermiyordu; aynı uygulamada bir mod "sessiz" kalınca oyuncu
/// cevabın alınıp alınmadığından emin olamıyordu. Olay başına TEK çağrı.
///
/// Ses sağlayıcısı ağaçta yoksa (ör. sağlayıcısız widget testi) yalnız
/// titreşim verilir; geri bildirim hiçbir zaman ekranı kırmaz.
void playAnswerFeedback(BuildContext context, {required bool correct}) {
  if (correct) {
    AppHaptics.medium();
  } else {
    AppHaptics.vibrate();
  }
  SoundProvider? sound;
  try {
    sound = Provider.of<SoundProvider>(context, listen: false);
  } on ProviderNotFoundException {
    sound = null;
  }
  if (sound == null) return;
  if (correct) {
    sound.playCorrect();
  } else {
    sound.playWrong();
  }
}
