import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Kategori ve seviye görünen adları K tablosundan okunur.
void main() {
  test('kategori kimlikleri defterdeki K.cat* anahtarlarıyla eşleşir', () {
    const ids = {
      'Ziman': K.catZiman,
      'Çand': K.catCand,
      'Dîrok': K.catDirok,
      'Edebiyat': K.catEdebiyat,
      'Cografya': K.catCografya,
      'Muzîk': K.catMuzik,
      'Siyaset': K.catSiyaset,
      'Paradigma': K.catParadigma,
      'Teknolojî': K.catTeknoloji,
      'Sînema': K.catSinema,
      'Tevlihev': K.catTevlihev,
    };
    for (final entry in ids.entries) {
      expect(Tr.keys, contains(entry.value), reason: entry.key);
      expect(CategoryNames.localized(entry.key, true), isNotEmpty);
      expect(CategoryNames.localized(entry.key, false), isNotEmpty);
    }
  });

  test('seviye adları defterdeki K.level* anahtarlarıyla eşleşir', () {
    const ids = {
      'Destpêk': K.levelDestpek,
      'Bingeh': K.levelBingeh,
      'Navîn': K.levelNavin,
      'Pêşketî': K.levelPesketi,
      'Mamoste': K.levelMamoste,
    };
    for (final entry in ids.entries) {
      expect(Tr.keys, contains(entry.value), reason: entry.key);
      expect(LevelNames.localized(entry.key, true), isNotEmpty);
      expect(LevelNames.localized(entry.key, false), isNotEmpty);
    }
  });
}
