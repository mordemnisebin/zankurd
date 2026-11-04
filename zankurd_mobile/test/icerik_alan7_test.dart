import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GPT-6 Pro ALAN 7 içerik bulguları (soru ve ders içeriği, 2026-11-07).
///
/// ## Kusur
///
/// Denetim yanlış cevap anahtarı (Evdalê Zeynikê: yaşadığı yüzyıl sorusunda
/// 19. ve 20. yüzyıl ikisi de doğruydu), yanlış olgu (Mervanî merkezi Amed
/// diye öğretiliyordu; Beethoven'ın vaftiz tarihi doğum günü diye; Cannes'ın
/// "1946'dan beri her mayıs" düzenlendiği; Büyük Zap'ın kaynağı), bozuk
/// Türkçe çeviri (TR görünümünde `Qelem` → "Kalem" olunca q harfi sorusu
/// çözülemiyordu), yanlış öğretici kural cümleleri ("fiil daima sonda",
/// "ay adı -ê alır") ve cevabı ele veren şıklar (tek kişi şıkkı, tek
/// parantezli şık, soru sözcüğünü tekrar eden doğru şık) buldu.
///
/// ## Niçin sessiz kalıyordu
///
/// Hiçbir araç anlamı denetlemez: bu metinler biçim, uzunluk ve dil
/// taramalarından geçiyordu; yanlış kural ya da yanlış olgu derleme ve
/// analizden geçer, öğrenen yanlışı ezberler.
///
/// ## Bekçi
///
/// `test/icerik_alan7_beklenen.json` her düzeltilen (soru kimliği, alan)
/// için eski ve yeni değeri tutar. Etkin soru dosyalarında alan YENİ değerde
/// ve ESKİ değerde olmamalı; Dart kaynağındaki ders/sözlük metinleri için
/// yeni parça bulunmalı, eski parça bulunmamalı. Sunucu göçü
/// `supabase/2026-11-07_icerik_alan7.sql` ve geri alması dosyada, ⏳ kaydı
/// `applied.md`de durur. Karar her satırda ≥2 bağımsız modelin AYNI metinde
/// uyuşmasıdır; reddedilenler (Mem û Zîn tamamlanma yılı gibi tartışmalı
/// olgular) bilerek DEĞİŞMEDİ.
const _karantina = {'deepseek_2026_08_18_questions.json'};

Map<String, Map<String, dynamic>> _etkinSorular() {
  final out = <String, Map<String, dynamic>>{};
  for (final f in Directory('assets/data').listSync().whereType<File>()) {
    final ad = f.uri.pathSegments.last;
    if (!ad.endsWith('.json') || _karantina.contains(ad)) continue;
    final d = jsonDecode(f.readAsStringSync());
    if (d is! List) continue;
    for (final q in d) {
      if (q is Map<String, dynamic> && q['id'] is String) {
        out.putIfAbsent(q['id'] as String, () => q);
      }
    }
  }
  return out;
}

dynamic _oku(Map<String, dynamic> q, String alan) {
  final m = RegExp(r'^(\w+)\[(\d+)\]$').firstMatch(alan);
  if (m != null) return (q[m.group(1)] as List)[int.parse(m.group(2)!)];
  if (alan.endsWith('+')) {
    return (q[alan.substring(0, alan.length - 1)] as List?) ?? const [];
  }
  if (alan == 'explanationTr' && !q.containsKey('explanationTr')) {
    return q['explanation'];
  }
  return q[alan];
}

void main() {
  final beklenen =
      (jsonDecode(File('test/icerik_alan7_beklenen.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final sorular = _etkinSorular();

  test('düzeltilen soru alanları yeni değerde, eski değerde değil', () {
    final hatalar = <String>[];
    for (final b in beklenen.where((b) => b['t'] == 'json')) {
      final q = sorular[b['id']];
      if (q == null) {
        hatalar.add('${b['id']}: soru yok');
        continue;
      }
      final alan = b['field'] as String;
      final yeni = b['yeni'];
      if (alan.endsWith('+')) {
        if (!(_oku(q, alan) as List).contains(yeni)) {
          hatalar.add('${b['id']} $alan: $yeni eksik');
        }
        continue;
      }
      // Şık sırası dengeleme aracıyla değişebilir: tek şık alanları SIRADAN
      // bağımsız, listede yeni metin var / eski metin yok diye denetlenir.
      final sik = RegExp(r'^(answers(?:Tr)?)\[\d+\]$').firstMatch(alan);
      if (sik != null) {
        final liste = (q[sik.group(1)] as List).cast<String>();
        if (!liste.contains(yeni)) hatalar.add('${b['id']} $alan: $yeni yok');
        if (liste.contains(b['eski'])) {
          hatalar.add('${b['id']} $alan: eski şık geri gelmiş');
        }
        continue;
      }
      final simdi = _oku(q, alan);
      if (jsonEncode(simdi) != jsonEncode(yeni)) {
        hatalar.add('${b['id']} $alan: beklenen $yeni, bulunan $simdi');
      }
      if (jsonEncode(simdi) == jsonEncode(b['eski'])) {
        hatalar.add('${b['id']} $alan: eski değer geri gelmiş');
      }
    }
    expect(hatalar, isEmpty);
  });

  test('doğru cevap anahtarı şıklardan biri olarak kalır (KU ve TR)', () {
    final hatalar = <String>[];
    for (final id
        in beklenen
            .where((b) => b['t'] == 'json')
            .map((b) => b['id'] as String)
            .toSet()) {
      final q = sorular[id]!;
      for (final (cevap, siklar) in [
        ('correctAnswer', 'answers'),
        ('correctAnswerTr', 'answersTr'),
      ]) {
        if (q[cevap] is! String || q[siklar] is! List) continue;
        final list = (q[siklar] as List).cast<String>();
        final acik =
            (q['acceptedAnswers'] as List?)?.cast<String>() ?? const [];
        if (list.length > 1 && !list.contains(q[cevap])) {
          hatalar.add('$id: $cevap şıklarda yok');
        }
        if (list.toSet().length != list.length && acik.isEmpty) {
          hatalar.add('$id: $siklar tekrar eden şık');
        }
      }
    }
    expect(hatalar, isEmpty);
  });

  test('ders, sözlük ve kod içindeki düzeltmeler yerinde', () {
    final hatalar = <String>[];
    for (final b in beklenen.where((b) => b['t'] == 'dart')) {
      final metin = File(b['file'] as String).readAsStringSync();
      if (!metin.contains(b['yeni'] as String)) {
        hatalar.add('${b['id']}: yeni parça yok');
      }
      if (metin.contains(b['eski'] as String)) {
        hatalar.add('${b['id']}: eski parça geri gelmiş');
      }
    }
    expect(hatalar, isEmpty);
  });

  test('göç ve geri alma dosyası var, applied.md kaydı var', () {
    final gocYolu = File('supabase/2026-11-07_icerik_alan7.sql');
    final geriYolu = File('supabase/geri_al/2026-11-07_icerik_alan7_geri.sql');
    expect(gocYolu.existsSync(), isTrue);
    expect(geriYolu.existsSync(), isTrue);
    final goc = gocYolu.readAsStringSync();
    expect(goc, contains('begin;'));
    expect(goc, contains('commit;'));
    // Her güncelleme eski değere bağlı ve sonda etkilenen sayı denetlenir.
    expect(goc, contains('is not distinct from \$3'));
    expect(goc, contains('etkilenen'));
    expect(goc, contains('correct_option degisti'));
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-11-07_icerik_alan7.sql'),
    );
  });
}
