import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sînema ve Teknolojî kategorileri profil analiz panellerinin hiçbirinde
/// görünmüyordu.
///
/// ## Kusur
///
/// `profile_widgets.dart` içindeki ustalık paneli (`_MasterySection`) ve
/// "en güçlü/en zayıf konu" hesabı (`_PedagogicalAnalyticsSection`) aynı
/// sekiz kategorilik listenin İKİ AYRI kopyasını taşıyordu — `Sînema`
/// (2026-07'de eklendi) ve `Teknolojî` (2026-07-26'da içerikle dolduruldu)
/// hiçbirinde yoktu. Sonuç: bu iki kategoride ne kadar oynanırsa
/// oynansın ustalık paneli göstermiyor, "en güçlü/en zayıf konu" hesabı
/// bu kategorileri aday olarak hiç görmüyordu (2026-08-14 denetimi).
///
/// ## Bekçi
///
/// İki kopyanın TEK bir paylaşılan sabite (`_kProfileAnalysisCategories`)
/// indirgendiğini ve o sabitin gerçek 10 kategoriyi taşıdığını doğrular —
/// bundan sonra bir kategori eklenip burası güncellenmezse bekçi kırılır.
void main() {
  test(
    'ustalık ve en güçlü/en zayıf paneli aynı, TAM kategori listesini kullanır',
    () {
      final src = File(
        'lib/src/screens/profile/profile_widgets.dart',
      ).readAsStringSync();

      final constMatch = RegExp(
        r'const List<String> _kProfileAnalysisCategories = \[(.*?)\];',
        dotAll: true,
      ).firstMatch(src);
      expect(
        constMatch,
        isNotNull,
        reason: 'paylaşılan kategori sabiti bulunamadı',
      );
      final listBody = constMatch!.group(1)!;
      for (final category in [
        'Ziman',
        'Çand',
        'Dîrok',
        'Edebiyat',
        'Cografya',
        'Muzîk',
        'Siyaset',
        'Paradigma',
        'Sînema',
        'Teknolojî',
      ]) {
        expect(
          listBody,
          contains("'$category'"),
          reason: '$category paylaşılan listede yok',
        );
      }

      // İki kullanım yeri de kendi hardcoded kopyasını DEĞİL, paylaşılan
      // sabiti referans almalı — yoksa aynı kusur ilk düzeltmenin
      // yanından dolanarak geri gelir.
      expect(
        src,
        contains('static const _categories = _kProfileAnalysisCategories;'),
        reason: '_MasterySection kendi kopyasına dönmüş olabilir',
      );
      expect(
        src,
        contains('const categories = _kProfileAnalysisCategories;'),
        reason: '_PedagogicalAnalyticsSection kendi kopyasına dönmüş olabilir',
      );
    },
  );
}
