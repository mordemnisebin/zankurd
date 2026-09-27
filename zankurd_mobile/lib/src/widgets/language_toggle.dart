import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';

/// İki parçalı KU | TR dil seçici — seçili taraf dolu (Forest gradyanı),
/// öteki soluk durur.
///
/// ## Neden ortak
///
/// Giriş ekranı bu görünümü zaten kullanıyordu. Tanıtım turu ise ayrı,
/// tek yuvarlak bir hapla (yalnız o anki dili yazan) aynı işi yapıyordu —
/// hangi dile NASIL geçileceği görünmüyordu, yalnız hangi dilde
/// OLDUĞUN yazıyordu (2026-09-27 canlı gezinti). İki ayrı bileşen aynı
/// kararı iki kez (ve farklı) uygulamasın diye kod tek yerde durur;
/// çağıran ekran yalnız her çipin `ValueKey`'ini verir.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({required this.kuKey, required this.trKey, super.key});

  /// "KU" çipinin test/erişilebilirlik anahtarı.
  final Key kuKey;

  /// "TR" çipinin test/erişilebilirlik anahtarı.
  final Key trKey;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      // `alignment` KASITLI verilmez: bu kap bazı ekranlarda Stack/Align'ın
      // gevşek ama sınırlı kısıtı altında durur; `alignment` orada kabı
      // koyduğu alanın TAMAMINA yayar ve küçük hap yerine devasa boş bir
      // panel çizer (onboarding_screen.dart 2026-09-10 notuyla aynı tuzak).
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageChip(
            chipKey: kuKey,
            label: 'KU',
            active: isKu,
            onTap: () => context.langProvider.setLang('ku'),
          ),
          _LanguageChip(
            chipKey: trKey,
            label: 'TR',
            active: !isKu,
            onTap: () => context.langProvider.setLang('tr'),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.chipKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik ağacında bu iki buton etiketsiz görünüyordu
    // (yalnız "button"); ekran okuyucu hangi dile geçildiğini
    // söyleyemiyordu (2026-07-22 canlı UX denetimi).
    return Semantics(
      button: true,
      selected: active,
      label: label == 'KU' ? 'Kurmancî' : 'Türkçe',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          key: chipKey,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          // `alignment` KULLANILMAZ: Container'ın kendi `alignment`'ı içeride
          // bir `Align` kurar ve o `Align`, SINIRLI (bounded) ama gevşek bir
          // üst kısıtta kendini EN BÜYÜK boyuta genişletir — giriş ekranında
          // (yükseklik sınırsız Column) bu hiç görünmüyordu, ama tanıtım
          // turunda (yükseklik sabit `SizedBox` içindeki `Stack`) çipi
          // 48dp yerine başlık kutusunun tam yüksekliğine (~170dp) yayıyordu
          // (2026-09-27, bu dosya iki ekranda ortak kullanılınca ortaya
          // çıktı). `Center(widthFactor/heightFactor: 1)` içeriğe göre
          // boyutlanır — yalnız üstteki minWidth/minHeight fazladan yer
          // açarsa onu ortalar, asla kendisi o yeri doldurmaya çalışmaz.
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.identityHeaderGradient : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.culturalBrandBg.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: active ? Colors.white : AppTheme.textMutedColor(context),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
