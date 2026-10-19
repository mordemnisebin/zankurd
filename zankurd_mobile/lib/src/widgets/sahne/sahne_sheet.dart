// Kurul 3. tur 2026-10-20: tek alt sayfa kabuğu.
import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_page.dart';

/// Ortak alt sayfa (bottom sheet) kabuğu: tutamaç + başlık satırı + kapat.
///
/// Kusur (kurul 3. tur, ekran 90 / 249): bir sayfada tutamaç ve kapat
/// düğmesi vardı, ötekinde (meydan okuma) ikisi de yoktu ve şeffaf zemin
/// yüzünden arka planla karışıyordu. NİÇİN SESSİZ: her sayfa kendi
/// `showModalBottomSheet` çağrısını yazıyordu; ortak bir kabuk olmadığı için
/// tutarsızlık hiçbir testte görünmüyordu. Artık sayfalar [showSahneSheet]
/// ile açılır: aynı tutamaç, aynı başlık satırı, aynı kapat düğmesi, görünür
/// karartma ve kenar çizgisi.
Future<T?> showSahneSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Key? chromeKey,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Başlık satırı ve tutamacı kabuk çizer; Material'inki çift olmasın.
    showDragHandle: false,
    // Görünür karartma: sayfa arka planla karışmaz.
    barrierColor: Colors.black.withValues(alpha: 0.6),
    barrierLabel: context.t(K.close),
    elevation: 12,
    builder: (sheetContext) => SahneSheetChrome(
      key: chromeKey,
      title: title,
      child: Builder(builder: builder),
    ),
  );
}

/// [showSahneSheet]in içeriği saran kabuğu.
class SahneSheetChrome extends StatelessWidget {
  const SahneSheetChrome({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  /// Tutamacın boyutu (Material varsayılanıyla aynı).
  static const Size handleSize = Size(32, 4);

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // Üst kenarda 1 px çizgi: koyu zeminde bile sayfanın sınırı okunur.
        border: Border(top: BorderSide(color: t.edge)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: SahneSpace.x2),
                  child: DecoratedBox(
                    key: const ValueKey('sahne-sheet-handle'),
                    decoration: BoxDecoration(
                      color: t.tx3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: SizedBox.fromSize(size: handleSize),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x1,
                  SahneSpace.page - SahneIconButton.inset,
                  SahneSpace.x2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.headline.copyWith(color: t.tx),
                        ),
                      ),
                    ),
                    SahneIconButton(
                      key: const ValueKey('sahne-sheet-close'),
                      icon: AppIcons.xmark,
                      semanticLabel: sahneCloseLabel(context),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  0,
                  SahneSpace.page,
                  SahneSpace.page,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
