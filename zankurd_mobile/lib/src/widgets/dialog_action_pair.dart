import 'package:flutter/material.dart';

/// Diyalog eylem çifti: iptal + onay. İki eylemli her `AlertDialog` bunu
/// `actions: [DialogActionPair(...)]` olarak kullanır (profil hesap
/// diyalogları, soru ekranı çıkış diyaloğu, ayarlar, sıralama, eşleşme...).
///
/// `cancel` ikincil (vazgeç / yıkıcı) eylemdir, `confirm` birincil eylemdir.
///
/// 2026-09-30 simülatör: `AlertDialog.actions` iki düğmeyi kendi
/// içeriği kadar genişlikte, sağa yaslı diziyordu; büyük yazıda "Betal
/// bike" ile "Tomar bike" farklı genişlikte ve hizasız alt alta düşüyordu.
/// Normal yazıda yan yana eşit genişlikte; büyük yazıda tam genişlikte alt
/// alta, birincil (onay) üstte. Tur ve testler 1.0 ölçekte koştuğu için
/// kusur sessiz kaldı.
class DialogActionPair extends StatelessWidget {
  const DialogActionPair({
    required this.cancel,
    required this.confirm,
    super.key,
  });

  final Widget cancel;
  final Widget confirm;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 15;
    return SizedBox(
      width: double.infinity,
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [confirm, const SizedBox(height: 8), cancel],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 8),
                  Expanded(child: confirm),
                ],
              ),
            ),
    );
  }
}
