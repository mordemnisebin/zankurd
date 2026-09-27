part of '../quiz_screen.dart';

// A8 (2026-09-02): duruma dokunmayan diyalog göyvdeleri ana dosyadan ayrıldı.
// Çağrı yerleri aynı; yalnız widget'ın yeri değişti.

// 2026-09-25: Her diyalogda elle yazılan `backgroundColor` + `shape` +
// `BorderSide` üçlüsü kaldırıldı. Zemin, tipografi, yarıçap ve kenarlık
// artık `AppTheme._dialogTheme`ten geliyor; ekranlar arasında krom farkı
// kalmıyor ve bu dosyada üç kopya silindi.

class _QuizExitDialog extends StatelessWidget {
  const _QuizExitDialog({
    required this.isLearning,
    required this.isMultiplayer,
  });

  final bool isLearning;
  final bool isMultiplayer;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Kopya akışa göre değişir: öğrenme akışında kullanıcı "yarış"
      // başlatmamıştı, ders başlatmıştı.
      title: Text(
        isLearning ? context.t(K.leaveLessonQ) : context.t(K.leaveRaceQ),
      ),
      content: Text(
        isMultiplayer
            ? context.t(K.leaveOnlineMatchBody)
            : isLearning
            ? context.t(K.leaveLessonBody)
            : context.t(K.leaveRaceBody),
      ),
      // Vurgu güvenli eylemdedir. Önceden "Çık" dolgulu birincil buton,
      // "Devam Et" ise düz metindi: ilerlemeyi silen yıkıcı eylem, göz
      // en çok oraya gittiği için varsayılan gibi duruyordu
      // (2026-07-25 canlı denetimi).
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.t(K.leaveAction)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.t(K.continueAction)),
        ),
      ],
    );
  }
}

class _QuizForfeitDialog extends StatelessWidget {
  const _QuizForfeitDialog({required this.bodyKey});

  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t(K.matchForfeitedTitle)),
      content: Text(context.t(bodyKey)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t(K.ok)),
        ),
      ],
    );
  }
}

class _QuizReportDialog extends StatelessWidget {
  const _QuizReportDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t(K.reportQuestion)),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: context.t(K.reasonLabel),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t(K.cancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(context.t(K.sendAction)),
        ),
      ],
    );
  }
}
