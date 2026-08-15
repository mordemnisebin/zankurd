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

  test('yazıma açık terimin okunmuş bir kanıt zinciri olmalı', () {
    // Dilbilimsel kanıt ile proje izni AYRI alanlardır (v2). Ama izin,
    // kanıtsız verilemez: en az bir evidencePage gerçekten OKUNMUŞ olmalı.
    final offenders = <String>[];
    for (final c in concepts) {
      if (c['approvedForQuestionAuthoring'] != true) continue;
      final chain = (c['evidenceChain'] as List?) ?? const [];
      final anyRead = chain.any(
        (e) => (e as Map)['originalEntryReadDirectly'] == true,
      );
      if (!anyRead) {
        offenders.add(
          '${c['conceptId']}: authoring açık ama okunmuş kanıt yok',
        );
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('yazıma açık terimin izinli anlamı belirtilmeli', () {
    final offenders = <String>[];
    for (final c in concepts) {
      if (c['approvedForQuestionAuthoring'] != true) continue;
      final senses = (c['allowedSenses'] as List?) ?? const [];
      if (senses.isEmpty) {
        offenders.add('${c['conceptId']}: izinli anlam listesi boş');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('bloke authoring durumu ile izin çelişemez', () {
    final offenders = <String>[];
    for (final c in concepts) {
      final auth = c['projectAuthoringStatus'] as String;
      final approved = c['approvedForQuestionAuthoring'] == true;
      if (auth.startsWith('AUTHORING_BLOCKED') && approved) {
        offenders.add('${c['conceptId']}: $auth ama authoring=true');
      }
      if (auth.startsWith('AUTHORING_ALLOWED') && !approved) {
        offenders.add('${c['conceptId']}: $auth ama authoring=false');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('çözülmemiş çok-anlamlılık yazıma açılamaz', () {
    // `şîfre` (password/encryption) ve `tor` (network/internet/Tor) gibi.
    final offenders = <String>[];
    for (final c in concepts) {
      if (c['linguisticEvidenceStatus'] == 'MULTIPLE_SENSES_UNRESOLVED' &&
          c['approvedForQuestionAuthoring'] == true) {
        offenders.add('${c['conceptId']}: anlam ayrımı çözülmeden açılmış');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('dolaylı atıf doğrudan okuma gibi gösterilemez', () {
    final offenders = <String>[];
    for (final c in concepts) {
      for (final e in (c['evidenceChain'] as List?) ?? const []) {
        final m = e as Map;
        if (m['evidenceChainStatus'] == 'INDIRECT_NAMED_SOURCE_CITATION' &&
            m['originalEntryReadDirectly'] == true) {
          offenders.add(
            '${c['conceptId']}: dolaylı atıf doğrudan okundu denmiş',
          );
        }
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
    final statuses = concepts.map(
      (c) => '${c['linguisticEvidenceStatus']}${c['projectAuthoringStatus']}',
    );
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
