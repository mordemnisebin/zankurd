import 'package:flutter/widgets.dart';

import '../l10n/lang.dart';

/// Yüzde değerlerinin dile göre tek biçimde yazımı.
///
/// 2026-07-25 canlı denetimi: aynı ekranda iki farklı biçim yan yana
/// görünüyordu — kategori satırları `%0` (Türkçe önek), görev kartı `0%`
/// (sonek). Üstelik önek biçimi Kurmancî arayüzde de kullanılıyordu.
///
/// Kural:
/// * Türkçe → önek, boşluksuz: `%42`
/// * Kurmancî → sonek, boşluksuz: `42%`
class PercentFormat {
  const PercentFormat._();

  /// 0–100 aralığındaki bir yüzde değerini biçimlendirir.
  static String value(int percent, {required bool isKu}) {
    // BİLEREK satır içi: bu sınıf yüzde biçiminin TEK kaynağıdır ve
    // `percent_and_identity_test` başka hiçbir yerde elle biçim
    // yazılmadığını doğrular. Metni anahtar defterine taşımak o bekçiyi
    // kör eder — biçim bir "ekran metni" değil, bir sayı biçimidir.
    return isKu ? '$percent%' : '%$percent';
  }

  /// 0.0–1.0 aralığındaki bir oranı yuvarlayıp biçimlendirir.
  static String ratio(double ratio, {required bool isKu}) {
    final percent = (ratio.clamp(0.0, 1.0) * 100).round();
    return value(percent, isKu: isKu);
  }
}

extension PercentFormatContext on BuildContext {
  /// Dil sağlayıcısı ağaçta yoksa uygulamanın varsayılan diline (Kurmancî)
  /// düşer. `KilimProgressBar` gibi düşük seviyeli bileşenler sağlayıcısız
  /// ağaçlarda da (widget testleri, izole önizlemeler) kullanılabiliyor;
  /// biçimlendirme yüzünden fırlatmamalı.
  bool get _percentIsKu {
    try {
      return isKu;
    } on Object {
      return true;
    }
  }

  /// Bağlamdaki dile göre yüzde metni üretir.
  String percent(int value) => PercentFormat.value(value, isKu: _percentIsKu);

  /// Bağlamdaki dile göre 0.0–1.0 oranını yüzde metnine çevirir.
  String percentRatio(double ratio) =>
      PercentFormat.ratio(ratio, isKu: _percentIsKu);
}
