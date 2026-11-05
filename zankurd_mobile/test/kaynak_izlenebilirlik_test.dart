import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Yeni eklenen soru bankalarında kaynak izlenebilirliği (alan 6 #8, W6).
///
/// ## Kusur
///
/// `yeni_2026_11_07` / `yeni2_2026_11_10` / `yeni3_2026_11_14` (1.706 soru)
/// yalnız parti etiketi (`sourceTitle`) taşıyor; hangi olgunun hangi kaynağa
/// dayandığı kayıtlı değil. Sunucuya giderken `source_url` / `source_reference`
/// NULL kalıyor; sonradan "bu bilgi nereden" sorusu ya da düzeltme gerektiğinde
/// tek tek yeniden araştırma gerekiyor.
///
/// ## Kural
///
/// Aşağıdaki liste BU TARİHE KADAR eklenmiş bankalardır (dondurulmuş; geçmiş
/// göçlere ve verilere dokunulmaz). `questionBankAssets`e SONRADAN eklenen her
/// banka, her soruda `metadata.sourceReference` (URL ya da künye) taşımak
/// zorundadır. Sunucu üreticileri (`tool/sync_*_to_server.py`) bu alanı
/// `source_reference` / (URL ise) `source_url` olarak zaten aktarır.
const _gecmisBankalar = <String>{
  'sentence_building_questions.json',
  'fill_in_blank_2026_08_questions.json',
  'community_questions.json',
  'editorial_questions.json',
  'offline_questions.json',
  'expansion_2026_08_questions.json',
  'source_first_2026_08_questions.json',
  'visual_2026_08_07_questions.json',
  'restore_2026_08_07_questions.json',
  'expansion_2026_08_19_questions.json',
  'expansion_2026_09_28_questions.json',
  'deepseek_verified_2026_09_30_questions.json',
  'bilim_2026_09_30_questions.json',
  'altkonu_2026_10_01_questions.json',
  'ders_2026_10_01_questions.json',
  'bosluk_2026_10_02_questions.json',
  'ders_2026_10_02_questions.json',
  'baslangic_2026_10_06_questions.json',
  'dersler2_2026_10_08_questions.json',
  'hat_2026_10_07_questions.json',
  'dersler3_2026_10_08_questions.json',
  'kolay_2026_10_19_questions.json',
  'dersler4_2026_10_25_questions.json',
  'yeni_2026_11_07_questions.json',
  'yeni2_2026_11_10_questions.json',
  'yeni3_2026_11_14_questions.json',
};

void main() {
  test('geçmiş banka listesi gerçek assetlerle tutarlı (yazım hatası yok)', () {
    final adlar = {for (final a in questionBankAssets) a.split('/').last};
    expect(
      _gecmisBankalar.difference(adlar),
      isEmpty,
      reason: 'listede olup questionBankAssets içinde olmayan banka',
    );
  });

  test('sonradan eklenen her banka her soruda sourceReference taşır', () {
    final eksik = <String>[];
    for (final asset in questionBankAssets) {
      if (_gecmisBankalar.contains(asset.split('/').last)) continue;
      final rows = jsonDecode(File(asset).readAsStringSync()) as List<dynamic>;
      for (final raw in rows) {
        final q = raw as Map<String, dynamic>;
        final meta = q['metadata'] as Map<String, dynamic>?;
        final ref = (meta?['sourceReference'] as String?)?.trim() ?? '';
        if (ref.isEmpty) eksik.add('${asset.split('/').last}:${q['id']}');
      }
    }
    expect(
      eksik,
      isEmpty,
      reason:
          'Yeni bankada kaynaksız soru. Her soruya metadata.sourceReference '
          '(URL ya da künye) ekle; geçmiş bankalar _gecmisBankalar listesinde '
          'dondurulmuştur: $eksik',
    );
  });
}
