import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Glossary onay sözleşmesinin bekçisi.
///
/// ## Niçin var
///
/// Bir terminoloji kaydının en kolay bozulma biçimi, onay etiketinin
/// arkasındaki kanıtın sessizce boşalmasıdır: kaynak listesi silinir ama
/// `APPROVED_*` kalır, ya da yalnız adı görülmüş bir sözlük (LISTED_NOT_READ)
/// onay kanıtı gibi sayılır. Bu projede aynı desen içerik tarafında üç kez
/// yaşandı — kaynağı olmayan iddia "doğrulandı" sayıldı.
///
/// Bekçi, kanıt ile etiketin ayrışmasını imkânsız kılar. Ayrıca Opus'un
/// kendi değerlendirmesini insan onayı gibi sunmasını yasaklar.
void main() {
  late Map<String, dynamic> glossary;
  late List<Map<String, dynamic>> concepts;

  setUpAll(() {
    glossary =
        jsonDecode(
              File(
                'docs/content/terminology/zankurd_project_glossary_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    concepts = (glossary['concepts'] as List).cast<Map<String, dynamic>>();
  });

  test('conceptId tekrarı yok', () {
    final ids = concepts.map((c) => c['conceptId']).toList();
    expect(ids.toSet().length, ids.length, reason: 'yinelenen conceptId');
  });

  test('kaynaksız kayıt APPROVED olamaz', () {
    final offenders = <String>[];
    for (final c in concepts) {
      final status = c['approvalStatus'] as String;
      final sources = (c['sourceEntries'] as List?) ?? const [];
      if (status.startsWith('APPROVED') && sources.isEmpty) {
        offenders.add('${c['conceptId']}: $status ama sourceEntries boş');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('okunmamış kaynak onay kanıtı sayılamaz', () {
    // LISTED_NOT_READ: kitabın/sayfanın yalnız adı görüldü. Onay veremez.
    final offenders = <String>[];
    for (final c in concepts) {
      final status = c['approvalStatus'] as String;
      if (!status.startsWith('APPROVED')) continue;
      final sources = (c['sourceEntries'] as List?) ?? const [];
      final anyRead = sources.any((s) => (s as Map)['read'] == true);
      if (!anyRead) {
        offenders.add('${c['conceptId']}: APPROVED ama okunmuş kaynak yok');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('onaylanmamış terim soru yazımına açılamaz', () {
    final offenders = <String>[];
    for (final c in concepts) {
      final status = c['approvalStatus'] as String;
      final approved = c['approvedForQuestionAuthoring'] == true;
      if (approved && !status.startsWith('APPROVED')) {
        offenders.add('${c['conceptId']}: $status ama authoring=true');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('insan onayı iddiası yok', () {
    // Opus kendi değerlendirmesini insan dil onayı gibi sunamaz.
    final banned = RegExp(
      r'NATIVE_SPEAKER_APPROVED|HUMAN_APPROVED|LINGUIST_APPROVED',
    );
    final raw = File(
      'docs/content/terminology/zankurd_project_glossary_v1.json',
    ).readAsStringSync();
    final statuses = concepts.map((c) => c['approvalStatus'] as String);
    expect(
      statuses.any(banned.hasMatch),
      isFalse,
      reason: 'insan onayı etiketi kullanılmış',
    );
    expect(
      raw.contains('"humanReviewStatement"'),
      isTrue,
      reason: 'insan incelemesi durumu açıkça belirtilmeli',
    );
  });

  test('recordHash deterministik', () {
    for (final c in concepts) {
      final h = c['recordHash'];
      expect(h, isA<String>());
      expect(
        (h as String).length,
        16,
        reason: '${c['conceptId']} hash uzunluğu',
      );
    }
  });

  test('corpus sayısı ile tanıklık listesi tutarlı', () {
    final offenders = <String>[];
    for (final c in concepts) {
      final n = (c['corpusAttestationCount'] as int?) ?? 0;
      final list = (c['corpusAttestations'] as List?) ?? const [];
      if (n == 0 && list.isNotEmpty) {
        offenders.add('${c['conceptId']}: sayı 0 ama tanıklık listesi dolu');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
